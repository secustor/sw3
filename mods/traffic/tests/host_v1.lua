-- v1 scenarios (design/v1-spec.md 10.6) for host_stubs.lua: TRF_SCEN=v1-a..v1-n, run by run_host.sh.
-- Loaded after host_traffic.lua and host_v02.lua, whose helpers (T_Begin, T_Enter, T_Jump, T_Tick, T_Spawn,
-- T_SaveLoad, V_Logs, V_Idx, V_Slot, V_N, ...) are used here. The v1 features keep their defaults (W_Cfg)
-- unless a scenario sets a key. a migrate, b tracked pool, c supply/demand/heat, d clans and salvage,
-- e carriers, f strength and ladder, g sweeps, h offers and payouts, i TT4 and bands 8-9, j equipment
-- convoys, k danger convoys and slot, l bases, m localisation and deny, n 200 legs, clamps and size.

-- Helpers ---------------------------------------------------------------------------

-- Config with the v1 defaults (repo config.script values) plus t.
function W_Cfg(t)
	local c = {exp=0, log=1, traffic=1};
	if t then for k, v in t do c[k] = v; end; end;
	HOST().cfg = c;
end;

function W_Begin(sys, t)
	W_Cfg(t);
	HOST().logs = {};
	T_Begin(sys or "gredos");
end;

-- Map fixture: the base allow-list of v1 9.1 (ba = 1) with sites (bs) away from the host scene objects,
-- until gen_map.py emits them. Applied after every MapInitialization (the map cache is rebuilt).
function W_MapFix()
	if type(TRF_Map) ~= "function" then return; end;
	local m = TRF_Map();
	if not m or m.w_fix then return; end;
	m.w_fix = 1;
	local al = {"altair", "escaflon", "fiasar", "fort_russ", "kitaro", "xb13"};
	for i = 1, getn(al) do
		local k = m.by[al[i]];
		if k then m.sys[k].ba = 1; m.sys[k].bs = {x=1500, y=0, z=1500}; end;
	end;
end;
W_MapInit0 = HOST_MapInit;
function HOST_MapInit()
	local ok = W_MapInit0();
	W_MapFix();
	return ok;
end;

-- Number of entries 1..getn(t) of list t matching f(v).
function W_Count(t, f)
	local n = 0;
	if type(t) == "table" then for i = 1, getn(t) do if f(t[i]) then n = n + 1; end; end; end;
	return n;
end;

-- Region slots and home system idx.
function W_Home(slot) return TRF_RgMap()[slot].home; end;

-- A system idx of region slot s other than its home (first member), or nil.
function W_Member(slot, not_idx)
	local m = TRF_RgMap();
	local ss = m[slot].sys;
	for i = 1, getn(ss) do if ss[i] ~= not_idx then return ss[i]; end; end;
	return nil;
end;

-- Teams of every system of region slot s (GetLocationTeam reads HOST().teams).
function W_Teams(slot, team)
	local m = TRF_RgMap();
	local e = m[slot];
	for i = 1, getn(e.sys) do HOST().teams[TRF_SysName(e.sys[i])] = team; end;
	HOST().teams[TRF_SysName(e.home)] = team;
end;

-- Every system's team from the vanilla Location_SideList (FloodTradeStations.script) for GetLocationTeam.
function W_SideTeams()
	local h = HOST();
	h.teams = {};
	if type(Location_SideList) == "table" then for k, v in Location_SideList do h.teams[k] = v; end; end;
end;

-- Function globals defined by a v1 file (chunk source ends in trf_<m>.script).
function W_V1Names()
	return {"trf_loc", "trf_track", "trf_faction", "trf_clan", "trf_convoy", "trf_danger", "trf_supply", "trf_base"};
end;
function W_DropV1()
	local ns = W_V1Names();
	local del = {};
	for k, v in globals() do
		if type(v) == "function" and type(k) == "string" then
			local src = getinfo(v, "S").source or "";
			for i = 1, getn(ns) do
				if strfind(src, ns[i]..".script", 1, 1) then tinsert(del, k); end;
			end;
		end;
	end;
	for i = 1, getn(del) do setglobal(del[i], nil); end;
	return getn(del);
end;

-- Live ships of a list of carcasses.
function W_Alive(l)
	local n = 0;
	for i = 1, getn(l or {}) do if l[i] and l[i].alive then n = n + 1; end; end;
	return n;
end;

-- a: migration v3 -> v4, repair, unknown version, mid-campaign add, v1 files missing (spec 3.3) ---------

function T_V1_A()
	local h = HOST();
	h.labels.CurrentQuest = "5_1";
	W_Begin("gredos");
	local m = TRF_RgMap();
	local ok = TRF.version == 4 and TRF.std.fst == "55555" and V_N(TRF.tp) == 0 and V_N(TRF.lr) == 0 and V_N(TRF.base) == 0
		and TRF.feq == nil and TRF.offer == nil;
	for s = 1, m.n do
		if TRF.fs[s] ~= "33333" or TRF.rg[s].ct ~= 0 or TRF.clan[s].sv ~= 0 or TRF.clan[s].sf ~= 0 then ok = nil; end;
	end;
	HOST_Check(ok, "new game: v4 fields and defaults (fs 33333 per slot, fst 55555, empty tp/lr/base, no feq/offer)");
	-- v3 save of v0.2 (no v4 field); phases, pro, shortages and shops stay.
	local g = V_Idx("gredos");
	local sg = TRF_RgOf(g);
	T_SaveLoad(function()
		TRF.version = 3; TRF.fs = nil; TRF.std.fst = nil; TRF.tp = nil; TRF.lr = nil; TRF.base = nil;
		for s, r in TRF.rg do r.ct = nil; r.sr = nil; end;
		for s, c in TRF.clan do c.sv = nil; c.sf = nil; end;
		TRF.rg[%sg].ph = 2; TRF.sys[%g] = {pro=6, dis=3};
		TRF.shops = {{s=%g, sh="gredos", c=2}};
		TRF.short = {{s=%g, c=2, t=TRF.clock.legs + 6}};
	end);
	ok = TRF.version == 4 and TRF.std.fst == "55555" and V_N(TRF.tp) == 0 and V_N(TRF.lr) == 0 and V_N(TRF.base) == 0;
	for s = 1, m.n do
		if TRF.fs[s] ~= "33333" or TRF.rg[s].ct ~= 0 or TRF.clan[s].sv ~= 0 or TRF.clan[s].sf ~= 0 then ok = nil; end;
	end;
	HOST_Check(ok and V_Logs("event=migrate from_version=3 to_version=4") == 1, "v3 save -> v4 defaults, logged once");
	HOST_Check(TRF.rg[sg].ph == 2 and TRF_Pro(g) == min(6, TRF_ProCap(g)) and TRF_Dis(g) == 3 and getn(TRF.shops) == 1 and getn(TRF.short) == 1,
		"v3 -> v4 keeps phases, pro, dis, shortages and shops");
	-- Repair: each wrong entry dropped or clamped on its own.
	local al = V_Idx("kitaro");
	local na = V_Idx("gredos");
	T_SaveLoad(function()
		TRF.fs[1] = "3x333"; TRF.fs[2] = "44444"; TRF.std.fst = "123";
		TRF.tp = {"1,2,3,4,5,6,7,8,9,10,11,12,13,14", "1,2,3,4,5,6,7,8,9,10,11,12,13,14,15", "abc", 7};
		TRF.lr = {{s=1, t=5, e=10}, {s=99, t=5, e=1}, "x", {s=2, t=6, e=3}, {s=3, t=7, e=4}};
		TRF.base = {{s=%al, k=2, h=12, t=1}, {s=%na, k=1, h=9, t=1, w=0}, {s=%al, k=7}, "y"};
		TRF.feq = {k=5, f=1, s=1, t=1};
		TRF.offer = {k=2, s=3, t=5};
		TRF.rg[1].ct = 99; TRF.rg[1].sr = 5; TRF.clan[1].sv = 30; TRF.clan[1].sf = 9;
	end);
	HOST_Check(TRF.fs[1] == "33333" and TRF.fs[2] == "44444" and TRF.std.fst == "55555", "repair: bad digit strings reset, good kept");
	HOST_Check(getn(TRF.tp) == 1 and TRF.tp[1] == "1,2,3,4,5,6,7,8,9,10,11,12,13,14", "repair: 15-number and non-numeric pool strings dropped");
	HOST_Check(getn(TRF.lr) == 2 and TRF.lr[1].s == 1 and TRF.lr[2].s == 2, "repair: lr with a bad slot or type dropped, <= 2 kept");
	HOST_Check(getn(TRF.base) == 1 and TRF.base[1].s == al and TRF.base[1].h == 9 and TRF.base[1].w == 0,
		"repair: base off the allow-list and k 7 dropped, h clamped to 9");
	HOST_Check(TRF.feq == nil and TRF.offer and TRF.offer.k == 2 and TRF.offer.p == 0, "repair: feq k 5 dropped, offer kept (p 0)");
	HOST_Check(TRF.rg[1].ct == 0 and TRF.rg[1].sr == nil and TRF.clan[1].sv == 9 and TRF.clan[1].sf == 5,
		"repair: ct outside 0..7 reset to 0, sr outside 1..2 dropped, sv clamped to 9, sf to 5");
	-- Unknown version: heat, help, shops kept, base cleared.
	T_SaveLoad(function()
		TRF = {version=9, gen=8, std={heat=4, help=7}, shops={{s=46, sh="gredos", c=1}}, base={{s=%al, k=2, h=9, t=1, w=0}}, foo=1};
	end);
	HOST_Check(TRF.version == 4 and TRF.std.heat == 4 and TRF.std.help == 7 and getn(TRF.shops) == 1 and getn(TRF.base) == 0
		and TRF.foo == nil and TRF.fs[1] == "33333", "unknown version: v4 reset, heat/help/shops kept, base cleared");
	-- Mid-campaign add: a save without TRF.
	T_SaveLoad(function() TRF = nil; end);
	HOST_Check(TRF.version == 4 and TRF.fs[1] == "33333" and TRF.std.fst == "55555" and getn(TRF.rg) == m.n, "save without TRF: fresh v4");
	HOST_Check(HOST_Reserved(TRF, "TRF") == "", "no reserved key in TRF");
	-- Every v1 file missing: the v0.2 modules run, the v4 fields stay at their defaults.
	h.hide = {};
	local ns = W_V1Names();
	for i = 1, getn(ns) do h.hide[ns[i]..".script"] = 1; end;
	local nd = W_DropV1();
	h.logs = {};
	T_Jump("aurora");
	HOST_Check(nd > 100 and type(TRF_TrackEntry) ~= "function" and type(TRF_Fs) ~= "function" and type(TRF_BaseOf) ~= "function"
		and V_Logs(" module_count=10 ") >= 1, "v1 files missing: "..nd.." v1 functions gone, 10 modules loaded");
	local ids = {};
	for k = 1, 6 do local id = T_Spawn(); if id then tinsert(ids, id); end; TRF.live.port = {}; end;
	T_Tick(40, 0.5);
	TRF_AddLeg("test"); TRF_AddLeg("test");
	HOST_Check(getn(ids) >= 2 and TRF.version == 4 and getn(TRF.tp) == 0 and TRF.feq == nil and getn(TRF.base) == 0
		and TRF.std.fst == "55555", "v1 files missing: traders spawn, legs run, v4 fields unchanged ("..getn(ids).." traders)");
	T_Jump("gredos");
	HOST_Check(h.errors == 0 and V_Logs(" ERROR") == 0 and V_Logs(" event=error ") == 0, "v1 files missing: no script error, no ERROR line");
	h.hide = nil;
	T_Jump("aurora");
	HOST_Check(type(TRF_TrackEntry) == "function" and V_Logs(" module_count=18 ") >= 1, "v1 files back: 18 modules loaded");
end;

-- b: tracked pool (spec 4) ---------------------------------------------------------------------------

-- The exit trigger of trader id (armed at its spawn or when it leaves), fired; 1 when one ran.
function W_Exit(id)
	local pre = "TRF_OnExit("..id..","..TRF.gen..")--";
	if HOST_Count("f_object_inside", pre) == 0 then HOST_FireAll(nil, "TRF_ArmExit("..id..","); end;
	return HOST_Fire("f_object_inside", pre);
end;

-- Live trader records not gone.
function W_Live()
	local n = 0;
	for id, r in TRF.live.tr do if r.st ~= "gone" then n = n + 1; end; end;
	return n;
end;

function T_V1_B()
	local h = HOST();
	h.labels.CurrentQuest = "5_1";
	h.st_label = "TRADE STATION";
	-- Other v1 events off: carriers, sweeps, convoys and bases would take the seed or the arrival slots.
	W_Begin("gredos", {staged=0, seed=0, raids=0, queue=0, parked=0, carriers=0, sweeps=0, feq=0, bases=0, dconv=0, conv=0, tt4=0});
	local cur = TRF_CurIdx();
	TRF_SetDis(cur, 0);
	-- Focus tracks; the exit portal writes the record behind it.
	local a = T_Spawn("C");
	local r = TRF.live.tr[a];
	HOST_Check(a and r and TRF_Bit(r.tb, 1) == 0 and TRF_TrackMark(a, "focus") == 1 and TRF_Bit(r.tb, 1) == 1, "focus tracks (tb bit 1)");
	local dest = TRF_TkPortalDest(cur, r.ext);
	r.cnt = 1;
	local nm, cls = r.nm, r.cls;
	W_Exit(a);
	local i, rec = TRF_TpFind(a);
	HOST_Check(i and rec.s == dest and rec.fr == cur and rec.d == 1 and rec.nm == nm and rec.c == cls and TRF_Bit(rec.fl, 16) == 1
		and TRF.live.tr[a].st == "gone", "exit portal write: record in "..TRF_SysName(dest)..", from here, identity, attacked bit");
	-- Chase: the player jumps through the same portal within T_chase.
	T_Tick(20, 0.5);
	T_Jump(TRF_SysName(dest));
	i, rec = TRF_TpFind(a);
	local tk = TRF_TrackEntry();
	HOST_Check(i and TRF_Bit(rec.fl, 8) == 1 and tk.chase == a, "jump within 60 s through that portal: chased bit, entry plan chase");
	HOST_Check(TRF.live.ent ~= "staged", "chase suppresses the staged raid (entry "..tostring(TRF.live.ent)..")");
	local t0 = TRF.clock.gt;
	local t1 = nil;
	for k = 1, 40 do
		T_Tick(1, 0.5);
		if not t1 and TRF_Rec(a) then t1 = TRF.clock.gt - t0; end;
	end;
	r = TRF_Rec(a);
	HOST_Check(r and t1 and t1 >= 5 and t1 <= 15.5 and r.nm == nm and r.cls == cls and TRF_TpFind(a) == nil,
		"chased arrival at "..tostring(t1).." s with the same id, name and class; record left the pool");
	HOST_Check(r and r.fl ~= nil and V_Logs("module=raid event=flee trader_id="..a.." reason=chased") == 1 and V_Logs(TRF_TkTxt("chased")) >= 1, "chased trader flees and says so");
	-- Late chase (beyond T_chase): no chased bit.
	V_ClearTr();
	local b = T_Spawn("C");
	TRF_TrackMark(b, "hail");
	local rb = TRF.live.tr[b];
	rb.cnt = 1;
	local db = TRF_TkPortalDest(TRF_CurIdx(), rb.ext);
	W_Exit(b);
	T_Tick(130, 0.5);
	local y = V_Idx("aurora");
	if y == db or y == TRF_CurIdx() then y = V_Idx("altair"); end;
	TeleportToLocation(TRF_SysName(db));
	i, rec = TRF_TpFind(b);
	HOST_Check(i and TRF_Bit(rec.fl, 8) == 0, "jump to its system after 65 s: no chased bit");
	-- e = 1 at a portal arrival 60-120 s (one leg elsewhere first).
	T_Enter(TRF_SysName(y));
	T_Jump(TRF_SysName(db));
	TRF.tp = {TRF.tp[TRF_TpFind(b)]};
	i, rec = TRF_TpFind(b);
	local tp = TRF_TrackEntry().port;
	HOST_Check(i and TRF_TkElapsed(rec) <= 1 and getn(tp) == 1 and tp[1] == b, "e "..TRF_TkElapsed(rec)..": portal arrival planned");
	t0 = TRF.clock.gt; t1 = nil;
	for k = 1, 250 do
		T_Tick(1, 0.5);
		if not t1 and TRF_Rec(b) then t1 = TRF.clock.gt - t0; end;
	end;
	HOST_Check(t1 and t1 >= 60 and t1 <= 120.5 and TRF_Rec(b).nm == rb.nm, "portal arrival at "..tostring(t1).." s, same name");
	-- e 2..8: a docked-state record seeds the station with the same name, class and hull row.
	V_ClearTr();
	TRF.tp = {};
	h.cfg.seed = 1;
	local c = T_Spawn("B") or T_Spawn("A");
	local rc = TRF.live.tr[c];
	TRF_TrackMark(c, "contract");
	local here = TRF_CurIdx();
	HOST_Check(TRF_TrackWrite(c, here, 2) and TRF_TpFind(c), "docked write (d = 2)");
	local _, rr = TRF_TpFind(c);
	local nmc, clc, pwc = rr.nm, rr.c, rr.pw;
	V_ClearTr();
	local away = V_Idx("aurora");
	if here == away then away = V_Idx("gredos"); end;
	T_Jump(TRF_SysName(away)); T_Jump(TRF_SysName(away == V_Idx("aurora") and V_Idx("elio") or V_Idx("aurora")));
	T_Jump(TRF_SysName(here));
	i, rec = TRF_TpFind(c);
	tk = TRF_TrackEntry();
	HOST_Check(i and TRF_TkElapsed(rec) >= 2 and getn(tk.dock) == 1 and tk.dock[1] == c, "e "..TRF_TkElapsed(rec)..": docked seed planned");
	T_Tick(80, 0.5);
	local rs = TRF_Rec(c) or (TRF.live.tr[c] and TRF.live.tr[c].st ~= "gone" and TRF.live.tr[c]);
	local fd = nil;
	for id, x in TRF.live.tr do if x.st ~= "gone" and x.pi == c then fd = x; end; end;
	rs = rs or fd;
	HOST_Check(rs and rs.nm == nmc and rs.cls == clc and rs.seed == 1 and TRF_TpFind(c) == nil,
		"docked seed with the same name and class (pw "..tostring(pwc)..")");
	h.cfg.seed = 0;
	-- Expiry at e > 8, at most 2 arrivals, eviction, bound 16.
	TRF.tp = {};
	local L = TRF.clock.legs;
	for k = 1, 4 do
		TRF_TkPut({id=7000 + k, nm=k, o=0, c=1, tt=1, pw=8, n=4, e=1, s=V_Idx("altair"), fr=here, d=1, dm=0, fl=1, t=L - 1});
	end;
	TRF_TkPut({id=7100, nm=9, o=0, c=1, tt=1, pw=8, n=4, e=1, s=V_Idx("altair"), fr=here, d=1, dm=0, fl=1, t=L - 10});
	T_Jump("altair");
	local pl = TRF_TrackEntry();
	HOST_Check(getn(pl.port) + getn(pl.dock) + (pl.chase and 1 or 0) == 2 and TRF_TpFind(7100) == nil, "4 records here: 2 arrivals planned; e > 8 expired");
	TRF.tp = {};
	for k = 1, 16 do
		local fl = 1;
		if k == 1 then fl = 9; end;
		TRF_TkPut({id=7200 + k, nm=k, o=0, c=1, tt=1, pw=8, n=4, e=1, s=1, fr=2, d=1, dm=0, fl=fl, t=L + k});
	end;
	TRF_TkPut({id=7300, nm=99, o=0, c=1, tt=1, pw=8, n=4, e=1, s=1, fr=2, d=1, dm=0, fl=1, t=L + 20});
	HOST_Check(getn(TRF.tp) == 16 and TRF_TpFind(7201) and TRF_TpFind(7202) == nil and TRF_TpFind(7300),
		"full pool: the oldest non-chased record evicted, the chased one kept, never above 16");
	for k = 1, 30 do TRF_TkPut({id=7400 + k, nm=k, o=0, c=1, tt=1, pw=8, n=4, e=1, s=1, fr=2, d=1, dm=0, fl=1, t=L + 30 + k}); end;
	HOST_Check(getn(TRF.tp) == 16, "pool bound 16 after 30 more writes");
	-- OutMissionEscort set: nothing written or spawned.
	TRF.tp = {};
	T_Jump("gredos");
	local d = T_Spawn("C");
	h.labels.OutMissionEscort = "1";
	TRF_TrackMark(d, "focus");
	local wd = TRF_TrackWrite(d, TRF_CurIdx(), 2);
	TRF_Track_BeforeJump("gredos", nil);
	HOST_Check(wd == nil and getn(TRF.tp) == 0, "OutMissionEscort: no write");
	h.labels.OutMissionEscort = nil;
	TRF_TrackWrite(d, V_Idx("gredos"), 1, TRF_CurIdx());
	h.labels.OutMissionEscort = "1";
	T_Jump("aurora");
	T_Jump("gredos");
	HOST_Check(V_N(TRF_TrackEntry().port) == 0 and TRF_TpFind(d), "OutMissionEscort: no arrival, record kept");
	h.labels.OutMissionEscort = nil;
	-- A killed tracked trader drops its record; a custom jump writes nothing.
	V_ClearTr();
	local e = T_Spawn("C");
	TRF_TrackMark(e, "focus");
	TRF_TrackWrite(e, TRF_CurIdx(), 2);
	local xe = TRF_H().tr[e];
	for k = 1, getn(xe.sh) do xe.sh[k].alive = nil; end;
	HOST_FireAll("died", "TRF_OnShipDied("..e..",");
	HOST_FireAll("f_died", "TRF_OnShipDied("..e..",");
	T_Tick(2, 0.5);
	HOST_Check(TRF_TpFind(e) == nil, "killed trader: record dropped");
	local f = T_Spawn("C");
	TRF_TrackMark(f, "focus");
	local n0 = getn(TRF.tp);
	CustomTeleportate("gredos", "aurora", "long_jump");
	HOST_Check(getn(TRF.tp) == n0, "CustomTeleportate: no pool write");
	T_Enter("aurora");
	TRF_Track_Dump();
	HOST_Check(V_Logs("module=track event=dump part=pool pool_count=") >= 1 and HOST_Reserved(TRF, "TRF") == "", "dump line, no reserved key");
end;

-- c: supply convoys, demand cargo, heat reset (spec 5) -------------------------------------------------

-- A converted trader plan of contact c (TRF_Plan, then the supply roll), or nil after n tries.
function W_SupplyPlan(c, n)
	for i = 1, n or 500 do
		local p = TRF_Plan(c, 1, nil, 20);
		if p and TRF_SupplyRoll(p) then return p; end;
		TRF.live.port = {};
	end;
	return nil;
end;

-- Kill every transport of trader id (ships dead, then their died triggers).
function W_KillTr(id)
	local x = TRF_H().tr[id];
	if not x then return; end;
	local l = x.tp or x.sh;
	for k = 1, getn(l) do l[k].alive = nil; end;
	HOST_FireAll("died", "TRF_OnShipDied("..id..",");
end;

function T_V1_C()
	local h = HOST();
	h.labels.CurrentQuest = "5_1";
	h.st_label = "TRADE STATION";
	W_Begin("gredos", {staged=0, seed=0, raids=0, queue=0, parked=0, carriers=0, sweeps=0, feq=0, bases=0, dconv=0, tt4=0});
	local cur = TRF_CurIdx();
	local sy = TRF_Map().sys[cur];
	TRF_SetDis(cur, 0);
	HOST_Check(TRF_BorderOf("Vks", {"Neutral", "Kfni"}) == 1 and not TRF_BorderOf("Kfni", {"Kfni"}) and not TRF_BorderOf("Uss", {"Vks"}), "TRF_BorderOf");
	-- Demand comply chance on the raid model: clamp(100 - 100 x br x st / sp, 5, 95), trf_raid loaded and not.
	local dl, ds, dm = TRF_DemandChanceOf(8 * 0.5, 8 * 3, 0.2), TRF_DemandChanceOf(13 * 3.5, 8 * 3, 1), TRF_DemandChanceOf(6 * 1.5, 6 * 3, 0.6);
	HOST_Check(dl == 95 and ds == 5 and dm == 70, "demand comply chance: lone timid "..dl.." (95), strong brave "..ds.." (5), 1 escort br 0.6 "..dm.." (70)");
	local oc, ob = TRF_Rd_ComplyOf, TRF_Rd_Brave;
	TRF_Rd_ComplyOf = nil; TRF_Rd_Brave = nil;
	local fbt = {};
	h.rq = {500};
	local fb = TRF_SpBrave(fbt);
	h.rq = {1000};
	local fb2 = TRF_SpBrave(fbt);
	h.rq = {};
	local fl, fs, fm = TRF_DemandChanceOf(8 * 0.5, 8 * 3, 0.2), TRF_DemandChanceOf(13 * 3.5, 8 * 3, 1), TRF_DemandChanceOf(6 * 1.5, 6 * 3, 0.6);
	TRF_Rd_ComplyOf = oc; TRF_Rd_Brave = ob;
	HOST_Check(abs(fb - 0.6) < 0.001 and fb2 == fb and fbt.br == fb and fl == 95 and fs == 5 and fm == 70,
		"demand without trf_raid: same braveness roll ("..TRF_F(fb)..", kept) and formula");
	-- Player side: hull power (GetPlayerLevel list, extortion band means) x 3 ships; start hull 1 ship; unlisted: sb x 3.
	h.ms.model = "Mothership_Arba";
	local ps1, pp1, pl1 = TRF_SpPlayerSide();
	h.ms.model = "hm_queen_pl";
	local ps2, pp2, pl2 = TRF_SpPlayerSide();
	h.ms.model = nil;
	local ps3, pp3, pl3 = TRF_SpPlayerSide();
	HOST_Check(ps1 == 24 and pp1 == 8 and pl1 == 4 and ps2 == 3 and pl2 == 1 and pl3 == 0 and pp3 == sy.sb and ps3 == 3 * sy.sb,
		"player side: arba 8 x 3 = "..ps1..", start hull 3 x 1 = "..ps2..", unlisted sb "..tostring(sy.sb).." x 3 = "..ps3);
	HOST_Check(TRF_HeatCostOf(3, 100000, 950000) == 300000 and TRF_HeatCostOf(9, 100000, 950000) == 900000 and TRF_HeatCostOf(12, 100000, 950000) == 950000,
		"heat offer cost min(100000 x heat, 950000)");
	-- Border from GetLocationTeam.
	h.teams = {gredos="Vks"};
	h.teams[sy.portals[1].to] = "Kfni";
	TRF.live.bd = nil;
	HOST_Check(TRF_Border(cur) == 1, "border: Vks system with a Kfni neighbour");
	TRF.live.bd = nil;
	h.teams[sy.portals[1].to] = "Neutral";
	HOST_Check(not TRF_Border(cur), "no border without an enemy neighbour");
	h.teams[sy.portals[1].to] = "Kfni";
	TRF.live.bd = nil;
	TRF_GnValidateAll();
	-- Conversion rate over 2000 plans: 15 % +- 3.
	local c = TRF_GnContacts()[1];
	local n, conv = 0, 0;
	for i = 1, 2000 do
		local p = TRF_Plan(c, 1, nil, 20);
		if p and p.st and p.np then
			n = n + 1;
			if TRF_SupplyRoll(p) then conv = conv + 1; end;
		end;
		TRF.live.port = {};
	end;
	print("HOST info supply conversion "..conv.."/"..n);
	HOST_Check(n > 1000 and abs(conv / n - 0.15) <= 0.03, "conversion rate 15 % +- 3 ("..conv.."/"..n..")");
	-- Composition: Walrus transport, 2-4 faction escorts escorting it, convoy slot.
	local p = W_SupplyPlan(c);
	local id = TRF_SupplySpawn(p);
	local r = id and TRF.live.tr[id];
	local hs = id and TRF_H().sp[id];
	local ht = id and TRF_H().tr[id];
	HOST_Check(r and r.own == 1 and hs and getn(hs.es) >= 2 and getn(hs.es) <= 4 and strfind(ht.tp[1].tpl, "^Walrus_nav")
		and TRF.live.cvs and TRF.live.cvs.id == id and TRF.live.cvs.k == 2,
		"supply convoy: own 1, "..tostring(hs and getn(hs.es)).." escorts, "..tostring(ht and ht.tp[1].tpl)..", slot rank 2");
	HOST_Check(hs.ef and hs.ef.esc == ht.tp[1], "escorts follow the transport (Flight:Escort)");
	HOST_Check(r.hold and getn(r.hold) >= 1, "Walrus hold filled ("..getn(r.hold or {}).." stacks)");
	-- Kill without player fire: salvage +1 for the local clan, at most 2 per visit; no heat.
	local slot = TRF_RgOf(cur);
	TRF.clan[slot].sv = 0; TRF.clan[slot].sf = 0; TRF.live.fsv = 0;
	local heat0 = TRF.std.heat;
	W_KillTr(id);
	T_Tick(2, 0.5);
	HOST_Check(TRF.clan[slot].sv == 1 and TRF.clan[slot].sf == 1 and TRF.std.heat == heat0 and TRF.live.cvs == nil,
		"supply convoy lost without player fire: sv +1 (sf 1), no heat, slot free");
	for k = 1, 2 do
		local q = W_SupplyPlan(c);
		local x = q and TRF_SupplySpawn(q);
		if x then W_KillTr(x); T_Tick(2, 0.5); end;
	end;
	HOST_Check(TRF.clan[slot].sv == 2, "salvage from flight losses <= 2 per visit (sv "..TRF.clan[slot].sv..")");
	V_ClearTr();
	TRF.live.cvs = nil;
	h.teams = {};
	TRF.live.bd = nil;
	-- Demand cargo on a plain trader: comply moves containers to the mothership, heat +2. The answer as a line
	-- (cfg demand_page 0); host_demand.lua runs the result page.
	h.cfg.demand_page = 0;
	local tid = T_Spawn("A") or T_Spawn("B");
	local tr = TRF.live.tr[tid];
	tr.hold = {{i="Cargo_01", n=4, s=1}, {i="Cargo_04", n=2, s=1}};
	TRF.std.heat = 3;
	h.ms.inv = {};
	local o = TRF_Supply_HailOpts(tid);
	HOST_Check(getn(o) == 1 and o[1] == "demand", "demand offered at heat 3 ("..tostring(o[1] or TRF_Dump({TRF_DemandOk(tid)}))..")");
	-- Lone transport (escorts dead), pw 8 against the arba (8 x 3); br 0.2 rolled by trf_raid and read here.
	h.ms.model = "mothership_arba";
	tr.pw = 8;
	tr.br = nil;
	h.rq = {0};
	TRF_Rd_Brave(tr);
	local ht = TRF_H().tr[tid];
	local dead = {};
	for i = 1, getn(ht.sh) do
		local s, tp = ht.sh[i], nil;
		for j = 1, getn(ht.tp) do if ht.tp[j] == s then tp = 1; end; end;
		if not tp and s.alive then s.alive = nil; tinsert(dead, s); end;
	end;
	h.rq = {94, 1};
	local res = TRF_DemandDo(tid);
	for i = 1, getn(dead) do dead[i].alive = 1; end;
	HOST_Check(V_Logs("module=supply event=demand trader_id="..tid.." trader_strength=4.000 player_strength=24.000 player_level=4 strength_ratio=0.167 braveness=0.200 chance=95.000 roll=94 result=comply") == 1,
		"demand: lone transport, timid trader (br from the raid roll) complies at p 95, roll 94");
	local got = 0;
	for i = 1, getn(h.ms.inv) do got = got + h.ms.inv[i][2]; end;
	HOST_Check(res == "comply" and got >= 1 and TRF.std.heat == 5 and tr.dq == 1, "comply: "..got.." containers to the mothership, heat +2");
	HOST_Check(not TRF_DemandOk(tid), "demanded once only");
	local tid2 = T_Spawn("C") or T_Spawn("A");
	TRF.std.heat = 7;
	HOST_Check(not TRF_DemandOk(tid2), "no demand at heat 7");
	TRF.std.heat = 4;
	-- Strong escort, brave trader: br rolled by the demand (1.0) and kept for a later raid; p 5 refuses roll 50.
	local tr2 = TRF.live.tr[tid2];
	tr2.br = nil;
	local ne = TRF_SpEscAlive(tr2, TRF_H().tr[tid2]);
	h.rq = {1000, 50};
	HOST_Check(ne >= 2 and TRF_DemandDo(tid2) == "refuse" and V_Logs("braveness=1.000 chance=5.000 roll=50 result=refuse") == 1, "demand: "..ne.." escorts, brave trader refuses at p 5, roll 50");
	local nr = h.rand;
	HOST_Check(tr2.br == 1 and TRF_Rd_Brave(tr2) == 1 and h.rand == nr, "braveness from the demand kept as r.br and read by trf_raid without a roll");
	h.ms.model = nil;
	h.cfg.demand_page = nil;
	-- Heat offer at a relation station (CStation_Action wrapped at load): cost, credits, original once.
	HOST_Check(TRF_InstallRelDock() == 0 and CStation_Action ~= TRF_orig_CStation, "relation dock wrapped at load, not twice");
	TRF.std.heat = 4;
	h.credits = 1000000;
	h.cst = {};
	local nb = getn(h.boxes);
	CStation_Action("2");
	HOST_Check(getn(h.boxes) == nb + 1 and getn(h.cst) == 0, "heat offer box first, original waits");
	HOST_Press("ok");
	T_Tick(2, 0.5);
	HOST_Check(getn(h.cst) == 1 and h.cst[1] == "2" and h.credits == 600000 and TRF.std.heat == 0, "paid 400000, heat 0, original once ("..h.credits..")");
	CStation_Action("2");
	HOST_Check(getn(h.cst) == 2 and HOST_Box().title == "#UI_StationC_confirm", "heat 0: the original at once");
	TRF.std.heat = 6;
	h.credits = 100;
	CStation_Action("3");
	HOST_Press("ok");
	T_Tick(2, 0.5);
	HOST_Check(getn(h.cst) == 3 and TRF.std.heat == 6 and h.credits == 100 and TRF.live.box == nil, "too poor: nothing changes, the original runs, box lock free");
	-- The heat offer takes the shared box lock: while another mod box is open the original runs at once.
	TRF_BoxTake("hail");
	nb = getn(h.boxes);
	CStation_Action("4");
	HOST_Check(getn(h.boxes) == nb + 1 and getn(h.cst) == 4 and HOST_Box().title == "#UI_StationC_confirm" and TRF.live.box == "hail", "heat offer: lock held, the original at once");
	TRF_BoxFree("hail");
	-- Vanilla reset through _temp_change: Trade -> heat 0; a faction: with the faction ladder on its sync rule
	-- (design/ladder-spec.md 5.7: a free reset changes nothing), with lad_enabled 0 the v1 rule (fst at least 5).
	TRF.std.heat = 5;
	h.credits = 1000000;
	_param = "3";
	_temp_change("Trade");
	HOST_Check(TRF.std.heat == 0 and h.credits == 50000, "vanilla FTU reset (950000): heat 0");
	TRF.std.fst = "22222";
	_param = "1";
	_temp_change("Kfni");
	HOST_Check(TRF_Fst(2) == 2 and TRF_Fst(1) == 2, "free Kfni reset with the ladder: New Empire fst unchanged "..TRF_Fst(2));
	h.cfg.lad_enabled = 0;
	_temp_change("Kfni");
	h.cfg.lad_enabled = nil;
	HOST_Check(TRF_Fst(2) >= 5 and TRF_Fst(1) == 2, "free Kfni reset, ladder off (v1 rule): New Empire fst "..TRF_Fst(2));
	_param = nil;
	-- Strict gate option 1 with quest ids.
	local s0 = {mode=1, qs=1, q=1, qa=0, f="seed"};
	HOST_Check(TRF_StrictOkOf(s0) == 1, "q system, ids, none active: open during a mission");
	s0.qa = 1; s0.qs = nil;
	HOST_Check(not TRF_StrictOkOf(s0), "q system, an id active: denied");
	s0.qa = nil; s0.qs = 1;
	HOST_Check(not TRF_StrictOkOf(s0), "q system without ids: v0.2 rule");
	-- Spawn kinds with event bounds.
	local base = {supp=0, gate=1, gov=nil, n=4, ntr=0, nsh=0, capt=5, caps=20, kills=0, kcap=3, nrf=0, nrs=0, rf=1, rs=8, npk=0, cp=0};
	local k = function(t) local x = {}; for a, b in %base do x[a] = b; end; for a, b in t do x[a] = b; end; if x.ng then x.gate = nil; end; return TRF_CanSpawnKindOf(x); end;
	HOST_Check(k({kind="sweep", ecap=14, ev=10}) == 1 and not k({kind="sweep", ecap=14, ev=11}), "sweep event ships <= 14");
	HOST_Check(not k({kind="feq", ecap=14, ev=0, gov=1}) and k({kind="base", ecap=16, ev=12, gov=1}) == 1, "governor stops events except the base");
	HOST_Check(not k({kind="conv", gov=1}) and k({kind="conv"}) == 1 and not k({kind="dconv", ng=1}), "conv: governor and gate");
	HOST_Check(TRF_CanSpawn(2, "carrier", 7) == nil and TRF_CanSpawn(1, "carrier", 7) == 1, "carrier bound 8 through TRF_CanSpawn");
	-- Shop lists and hold value.
	TRF_Map().it = {Cargo_01=1000, SRM3=20000};
	local items = TRF_ShopItems();
	local found = nil;
	for i = 1, getn(items) do if items[i] == "SRM3" then found = 1; end; end;
	local v, miss = TRF_ShopHoldValue({{i="Cargo_01", n=3}, {i="SRM3", n=2}, {i="XX_none", n=1}});
	TRF_Map().it = nil;
	HOST_Check(found and v == 43000 and miss == 1, "shop items include the faction cargo lists; hold value 43000, one unknown ("..v..")");
	TRF_Supply_Dump();
	HOST_Check(V_Logs("module=supply event=dump ") >= 1, "dump line");
	TRF_Supply_BeforeJump();
	HOST_Check(TRF.live.sp == nil, "jump clears the visit state");
end;

-- d: clans T3-T4 and salvage (spec 6.1, 6.3) -------------------------------------------------------

-- Hulls of rows lo..hi of getglobal(p.."_Fighters") and p.."_Bombers", as a set.
function W_Rows(p, lo, hi)
	local s = {};
	foreachi({"_Fighters", "_Bombers"}, function(i, k)
		local t = getglobal(%p..k);
		if type(t) == "table" then
			for r = %lo, %hi do for j = 1, getn(t[r] or {}) do %s[t[r][j][1]] = 1; end; end;
		end;
	end);
	return s;
end;

function T_V1_D()
	local h = HOST();
	h.labels.CurrentQuest = "5_1";
	W_Begin("gredos", {staged=0, seed=0, carriers=0, sweeps=0, feq=0, bases=0, dconv=0});
	local cur = TRF_CurIdx();
	local slot = V_Slot("gredos");
	local c = TRF.clan[slot];
	-- Gains and caps.
	c.sv = 0; c.sf = 0; TRF.live.fsv = 0;
	HOST_Check(TRF_SalvAdd(slot, 1, 0, "conv") == 0, "no salvage without a faction");
	HOST_Check(TRF_SalvAdd(slot, 1, 1, "conv") == 1 and TRF_SalvAdd(slot, 1, 1, "resp") == 1 and TRF_SalvAdd(slot, 1, 1, "conv") == 0,
		"flight losses: +1 each, at most +2 per visit");
	HOST_Check(TRF_SalvAdd(slot, 3, 2, "feqt") == 3 and c.sv == 5 and c.sf == 2 and TRF_SalvStage(slot) == 2, "equipment convoy taken +3 outside the visit cap, stage 2, sf 2");
	HOST_Check(TRF_SalvAdd(slot, 9, 2, "sweep") == 4 and c.sv == 9 and TRF_SalvStage(slot) == 3, "clamp 9, stage 3");
	TRF_SalvUse(slot, "kill");
	HOST_Check(c.sv == 8, "consumption: a salvaged flight killed uses 1");
	TRF_SalvUse(slot, "base");
	HOST_Check(c.sv == 0 and c.sf == 0, "base destroyed: sv 0, sf 0");
	-- Decay -1 every 8 legs with an odd tick leg (crossing rule).
	c.sv = 3; c.sf = 1;
	local m = TRF_RgMap();
	local dec = 0;
	for L = 101, 141, 2 do
		local b = c.sv;
		TRF_Cl_Decay(L, m);
		if c.sv < b then dec = dec + 1; end;
	end;
	HOST_Check(dec == 3 and c.sv == 0 and c.sf == 0, "decay -1 at every 8-leg crossing with odd ticks ("..dec.."), sf 0 at sv 0");
	-- Stage hulls of the losing faction (rung 0-1 rows 5-14); stage 1 fallback replaces the last wing.
	local okv = W_Rows("Vks", 5, 14);
	local grp = CreateTeam("Pirates"):CreateGroup("TRF_Test_S");
	TRF_GTestS = grp;
	c.sv = 5; c.sf = 1;
	local bad, n2 = "", 0;
	for k = 1, 40 do
		local fl, st, sh = TRF_SalvFlight(slot, "TRF_GTestS", "trf_ts"..k, Vector3(0, 0, 1000 + 40 * k), Vector3(0, 0, 1), 10, 3, 1, 4);
		if fl and st == 2 then
			n2 = n2 + 1;
			for i = 1, getn(sh) do if not okv[sh[i].tpl] then bad = bad.." "..sh[i].tpl; end; end;
			fl:Delete();
		end;
		TRF_Rd_ClearSign("trf_ts"..k);
	end;
	HOST_Check(n2 == 40 and bad == "", "stage 2: 40 flights of captured Vks fighters from rows 5-14"..strsub(bad, 1, 120));
	c.sv = 8; c.sf = 3;
	local fl, st, sh = TRF_SalvFlight(slot, "TRF_GTestS", "trf_tsb", Vector3(0, 0, 3000), Vector3(0, 0, 1), 10, 4, 1, 4);
	HOST_Check(fl and st == 3 and sh[1].tpl == "Butcher_tri1" and strfind(sh[2].tpl, "_tri", 1, 1), "stage 3: Butcher_tri1 leads Triada fighters");
	local fl2, st2 = TRF_SalvFlight(slot, "TRF_GTestS", "trf_tsc", Vector3(0, 0, 3100), Vector3(0, 0, 1), 10, 4, 1, 4);
	HOST_Check(fl2 and st2 == 2, "a second stage-3 flight while one lives -> stage 2");
	c.sv = 2; c.sf = 4;
	local fl3, st3, sh3 = TRF_SalvFlight(slot, "TRF_GTestS", "trf_tsd", Vector3(0, 0, 3200), Vector3(0, 0, 1), 10, 3, 1, 4);
	HOST_Check(fl3 and st3 == 1 and sh3[getn(sh3)].tpl == "Stormcrow_uss1" and strfind(sh3[1].tpl, "_pir", 1, 1),
		"stage 1 with salv_addmod 0: last wing Stormcrow_uss1, the rest pirate");
	h.cfg.salv_addmod = 1;
	h.mods = {};
	local fl4, st4 = TRF_SalvFlight(slot, "TRF_GTestS", "trf_tse", Vector3(0, 0, 3300), Vector3(0, 0, 1), 10, 3, 1, 4);
	HOST_Check(fl4 and st4 == 1 and getn(h.mods) >= 1, "stage 1 with salv_addmod 1: modules on the leader ("..getn(h.mods)..")");
	h.cfg.salv_addmod = nil;
	foreachi({fl, fl2, fl3, fl4}, function(i, f) if f then f:Delete(); end; end);
	foreachi({"trf_tsb", "trf_tsc", "trf_tsd", "trf_tse"}, function(i, x) TRF_Rd_ClearSign(x); end);
	TRF_GTestS = nil;
	-- Raid compositions T3 / T4 (tier_cap 4 default): ship bounds, Butcher_pir1 at score >= 90.
	c.sv = 0; c.sf = 0;
	TRF_Rd_Live();
	local rd = {n=901, tier=4, st="armed", t=0};
	TRF.live.rd[901] = rd;
	c.sc = 95;
	h.rq = {0, 0, 0, 0, 0, 0, 0, 0};
	local okb = TRF_Rd_Spawn(901, rd, Vector3(500, 0, 500), Vector3(0, 0, 1));
	h.rq = {};
	local hr = TRF_H().rd[901];
	local but = 0;
	for i = 1, getn(hr.sh) do if hr.sh[i].tpl == "Butcher_pir1" then but = 1; end; end;
	HOST_Check(okb and getn(hr.fls) >= 2 and getn(hr.sh) <= 8 and but == 1, "T4 at score 95: "..getn(hr.fls).." flights, "..getn(hr.sh).." ships <= 8, Butcher_pir1");
	TRF_Rd_End(901, "test");
	rd = {n=902, tier=3, st="armed", t=0};
	TRF.live.rd[902] = rd;
	c.sc = 70;
	okb = TRF_Rd_Spawn(902, rd, Vector3(600, 0, 600), Vector3(0, 0, 1));
	hr = TRF_H().rd[902];
	but = 0;
	for i = 1, getn(hr.sh) do if hr.sh[i].tpl == "Butcher_pir1" then but = 1; end; end;
	HOST_Check(okb and getn(hr.fls) == 2 and getn(hr.sh) <= 7 and but == 0, "T3: 2 flights, "..getn(hr.sh).." ships <= 7, no Butcher");
	TRF_Rd_End(902, "test");
	-- War news: salv2 / salv3 once per faction and stage.
	TRF.newsx[slot] = {};
	c.sv = 5; c.sf = 3;
	TRF_NewsCheck("war", slot);
	local v1 = TRF.newsx[slot].war and TRF.newsx[slot].war.v;
	local np = getn(h.posts);
	TRF_NewsCheck("war", slot);
	local same = getn(h.posts) == np;
	c.sv = 8;
	TRF_NewsCheck("war", slot);
	local v2 = TRF.newsx[slot].war and TRF.newsx[slot].war.v;
	HOST_Check(v1 == "salv2_3" and same and v2 == "salv3_3", "news war: salv2_3 once, then salv3_3 ("..tostring(v1).." / "..tostring(v2)..")");
	c.sv = 0; c.sf = 0;
	TRF_Clan_Dump();
	HOST_Check(V_Logs("module=clan event=dump") >= 1, "clan dump line");
end;

-- e: carriers (spec 6.2) ---------------------------------------------------------------------------

-- n steps of dt: tick, carrier tick, 1 s steps.
function W_CStep(n, dt)
	dt = dt or 0.25;
	for i = 1, n do T_Tick(1, dt); end;
end;

function T_V1_E()
	local h = HOST();
	h.labels.CurrentQuest = "5_1";
	h.st_label = "TRADE STATION";
	W_Begin("gredos", {staged=0, seed=0, sweeps=0, feq=0, bases=0, dconv=0, conv=0, tt4=0});
	local cur = TRF_CurIdx();
	local slot = V_Slot("gredos");
	local c = TRF.clan[slot];
	local m = TRF_RgMap();
	-- Records: a T4 clan creates one 2-3 jumps from home at the roll; <= 2 records.
	TRF.lr = {};
	for s = 1, m.n do TRF.clan[s].sc = 10; end;
	c.sc = 99;
	h.rq = {0};
	TRF_Clan_Tick(200);
	h.rq = {};
	HOST_Check(getn(TRF.lr) == 1 and TRF.lr[1].s == slot and TRF.lr[1].e == 206, "T4 clan: record created, e = L + 6");
	local tg = TRF.lr[1].t;
	local home = m[slot].home;
	local near = TRF_RgNear(home, 3);
	local jj = nil;
	for i = 1, getn(near) do if near[i].idx == tg then jj = near[i].j; end; end;
	HOST_Check(jj and jj >= 2 and jj <= 3 and tg ~= home, "target "..jj.." jumps from the home");
	for s = 1, m.n do TRF.clan[s].sc = 99; end;
	for L = 202, 260, 2 do h.rq = {0}; TRF_Clan_Tick(L); end;
	h.rq = {};
	HOST_Check(getn(TRF.lr) <= 2, "never more than 2 records ("..getn(TRF.lr)..")");
	for s = 1, m.n do TRF.clan[s].sc = 10; end;
	c.sc = 99;
	TRF.lr = {{s=slot, t=tg, e=266}};
	local d0 = TRF_Dis(tg);
	TRF_Clan_Tick(262);
	HOST_Check(TRF_Dis(tg) == min(9, d0 + 1) and getn(TRF.lr) == 1, "off-screen tick: target dis +1");
	c.sc = 50;
	local d1 = TRF_Dis(tg);
	TRF_Clan_Tick(266);
	HOST_Check(W_Count(TRF.lr, function(e) return e.t == %tg and e.e == 266; end) == 0 and c.sc == 53 and TRF_Dis(tg) == min(9, d1 + 2),
		"expiry: removed, score +3, target dis "..d1.." -> "..TRF_Dis(tg));
	-- On-screen: the carrier arrives 30-90 s after entry at the home-facing portal, with escorts.
	c.sc = 99;
	TRF.lr = {{s=slot, t=cur, e=TRF.clock.legs + 6}};
	TRF.live.ent = nil;
	TRF.live.cr = nil;
	HOST_Check(TRF_CarrierEntry() == 1 and TRF.live.cr.st == "due", "carrier entry scheduled");
	HOST_Check(TRF_StagedRoll() == nil, "no staged raid while the carrier plays");
	local t0, ta = TRF.clock.gt, nil;
	for i = 1, 400 do
		T_Tick(1, 0.25);
		if not ta and TRF_H().cr and TRF_H().cr.car then ta = TRF.clock.gt - t0; end;
	end;
	local cr = TRF.live.cr;
	local car = TRF_H().cr and TRF_H().cr.car;
	HOST_Check(car and ta and ta >= 30 and ta <= 90.5 and (car.tpl == "Mothership_pirate2" or car.tpl == "Arba_pir1"),
		"carrier "..tostring(car and car.tpl).." arrives after "..tostring(ta).." s");
	HOST_Check(getn(TRF_H().cr.esh) >= 1 and getn(TRF_H().cr.esh) <= 3 and TRF_H().cr.efl.esc == car, "escort flight of <= 3 escorting the carrier");
	HOST_Fire("f_inside", "TRF_OnCarrierHold(");
	HOST_Check(cr.st == "hold", "carrier holds");
	-- Launches: a trader near the carrier; every launched ship spawns at HANGAROUT, 2 s apart, <= 2 waves.
	local id = T_Spawn("C") or T_Spawn("A");
	if id then T_MoveTr(id, car.pos.x + 200, car.pos.y, car.pos.z); end;
	car.ori = Vector3(1, 0, 0);
	local spawned = {};
	local cc = CreateCarcass;
	CreateCarcass = function(tpl, pos, dir)
		local s = %cc(tpl, pos, dir);
		if s then tinsert(%spawned, {s=s, gt=HOST().gt}); end;
		return s;
	end;
	W_CStep(600, 0.25);
	CreateCarcass = cc;
	local ws = TRF_Cl_Waves();
	local X = TRF_HangarPos(car, "out");
	local okx, nw, gaps = 1, 0, "";
	local last = nil;
	for k = 1, getn(spawned) do
		local s = spawned[k].s;
		if s.flight and s.flight.group and strfind(s.flight.group.name or "", "^TRF_Raid_") then
			nw = nw + 1;
			if HOST_Dist(s.spawn, X) > 0.01 and not s.mv then okx = nil; end;
			if last and spawned[k].gt - last < 2 and spawned[k].gt ~= last then gaps = gaps.." "..(spawned[k].gt - last); end;
			last = spawned[k].gt;
		end;
	end;
	HOST_Check(getn(ws) >= 1 and getn(ws) <= 2 and nw >= 1, "waves launched: "..getn(ws).." (<= 2), "..nw.." ships");
	HOST_Check(okx and gaps == "", "launched ships at HANGAROUT (8 below the hull) then Move, >= 2 s apart"..gaps);
	local alive = 0;
	for k = 1, getn(ws) do alive = alive + W_Alive(TRF_H().rd[ws[k]].sh); end;
	HOST_Check(alive <= 8, "<= 8 wave ships alive ("..alive..")");
	-- Recovery inside rec_d deletes; no Dock call on a carrier.
	local wn = ws[1];
	local whr = TRF_H().rd[wn];
	TRF_RaidLeave(wn, "test");
	local Y = TRF_HangarPos(car, "in");
	for i = 1, getn(whr.sh) do whr.sh[i].pos = Vector3(Y.x, Y.y, Y.z); end;
	W_CStep(8, 0.25);
	HOST_Check(TRF.live.rd[wn].st == "end" and TRF.live.rd[wn].how == "rec" and W_Alive(whr.sh) == 0, "recovered wave deleted at HANGARIN ("..tostring(TRF.live.rd[wn].how)..")");
	HOST_Check(car.Dock == nil, "no Dock call (the carcass stub has no Dock)");
	-- HANGAROUT / HANGARIN rotate with the heading (8 orientations).
	local okr = 1;
	for a = 0, 315, 45 do
		car.ori = Vector3(sin(a), 0, cos(a));
		local P = car:GetPosition();
		local Xo, Yi = TRF_HangarPos(car, "out"), TRF_HangarPos(car, "in");
		if abs(Xo.x - P.x) > 0.01 or abs(Xo.y - (P.y - 8)) > 0.01 or abs(Xo.z - P.z) > 0.01 then okr = nil; end;
		if abs(Yi.x - (P.x + sin(a) * 3)) > 0.01 or abs(Yi.y - (P.y - 10)) > 0.01 or abs(Yi.z - (P.z + cos(a) * 3)) > 0.01 then okr = nil; end;
	end;
	HOST_Check(okr, "hgo (0, -8, 0) and hgi (0, -10, 3) rotate with the heading (8 headings)");
	-- Kill: record removed, score -8, bounty paid after a player hit.
	c.sc = 90;
	h.credits = 0;
	HOST_Fire("attack", "TRF_OnCarrierHit(");
	car.alive = nil;
	HOST_Fire("died", "TRF_OnCarrierDied(");
	HOST_Check(cr.st == "dead" and getn(TRF.lr) == 0 and c.sc == 82 and h.credits > 0 and h.credits <= 30000,
		"carrier killed: record removed, score -8, bounty "..h.credits);
	W_CStep(40, 0.25);
	-- A second carrier exits at 25 % HP.
	c.sc = 99;
	TRF.lr = {{s=slot, t=cur, e=TRF.clock.legs + 6}};
	TRF.live.cr = nil;
	TRF.live.cbt = nil;  -- the carrier hit above marked combat (combat-state.md); a new carrier would wait 25 s
	TRF_CarrierEntry();
	for i = 1, 400 do if not (TRF_H().cr and TRF_H().cr.car and TRF_H().cr.car.alive) then T_Tick(1, 0.25); end; end;
	cr = TRF.live.cr;
	car = TRF_H().cr.car;
	local hp0 = cr.hp0 or car.hp;
	car.hp = hp0 * 0.2;
	W_CStep(8, 0.25);
	HOST_Check(car.cp ~= nil and W_Count(TRF.lr, function(e) return e.t == %cur; end) == 0, "second carrier leaves below 25 % HP ("..tostring(cr.st)..")");
	-- RaidOn: no-demand raid on a convoy ship (T3 at least; nothing in a guard system).
	local tgt = CreateCarcass("Walrus_nav1", Vector3(0, 0, 300), Vector3(0, 0, 1));
	local og = TRF_Rd_Guard;
	TRF_Rd_Guard = function(i) return 1; end;
	HOST_Check(TRF_RaidOn({{g="TRF_Feq_1", o=tgt}}, 3, "fq", 0) == nil, "RaidOn fq: none in a guard system");
	TRF_Rd_Guard = function(i) return nil; end;
	local rn = TRF_RaidOn({{g="TRF_Feq_1", o=tgt}}, 3, "fq", 0);
	TRF_Rd_Guard = og;
	HOST_Check(rn and TRF.live.rd[rn].st == "fight" and TRF.live.rd[rn].kind == "fq" and TRF.live.rd[rn].tier >= 3 and TRF_H().rd[rn].fl.att == tgt,
		"RaidOn fq: spawned now, attacks the convoy ship, tier >= 3");
	TRF_Clan_BeforeJump();
	HOST_Check(TRF_H().cr.car == nil and (TRF.live.cr == nil or TRF.live.cr.st == "done"), "jump clears the carrier visit state");
end;

-- f: faction strength, standing, tech ladder (spec 7.1, 7.2, 7.6) ---------------------------------------

-- Every credit payment is recorded (HOST().pays) for the pay cap checks.
W_AddCredits0 = AddPlayerCredits;
function AddPlayerCredits(n)
	local h = HOST();
	h.pays = h.pays or {};
	tinsert(h.pays, n);
	W_AddCredits0(n);
end;
function W_PayMax()
	local m = 0;
	for i = 1, getn(HOST().pays or {}) do if HOST().pays[i] > m then m = HOST().pays[i]; end; end;
	return m;
end;

function T_V1_F()
	local h = HOST();
	h.labels.CurrentQuest = "5_1";
	W_Begin("gredos", {staged=0, seed=0, carriers=0, feq=0, bases=0, dconv=0});
	local s = V_Slot("kadi");
	TRF.fs = nil; TRF.std.fst = nil;
	TRF_Fs_Init();
	HOST_Check(TRF.fs[s] == "33333" and TRF.std.fst == "55555" and TRF_Fs(s, 2) == 3 and TRF_Rung(s, 2) == 1, "fs init 33333, fst 55555, rung 1");
	TRF.fs[s] = "3x333";
	TRF_Fs_Init();
	HOST_Check(TRF.fs[s] == "33333", "broken fs string repaired");
	HOST_Check(TRF_FsAdd(s, 1, 10, "t") == 9 and TRF_Rung(s, 1) == 3 and TRF_FsAdd(s, 1, -20, "t") == 0 and TRF_Rung(s, 1) == 0,
		"fs clamps 0..9; rungs 3 at 9, 0 at 0");
	local rt = "";
	for v = 0, 9 do TRF.fs[s] = strrep(tostring(v), 5); rt = rt..TRF_Rung(s, 1); end;
	HOST_Check(rt == "0001122233", "rung table fs 0-2 / 3-4 / 5-7 / 8-9 -> 0 / 1 / 2 / 3: "..rt);
	TRF.fs[s] = "33333";
	TRF_FstAdd(2, -3, "t");
	HOST_Check(TRF_Fst(2) == 2 and TRF_FstRel(2) == RELATION_WAR and TRF_FstRel(1) == RELATION_NEUTRAL, "fst 2 -> WAR seed, 5 -> NEUTRAL");
	TRF.std.fst = "55555";
	TRF_FstHit(3, nil, "t"); TRF_FstHit(3, nil, "t"); TRF_FstHit(4, 1, "t");
	HOST_Check(TRF_Fst(3) == 4 and TRF_Fst(4) == 5, "fst -1 once per visit; return fire on a hostile-seeded group costs nothing");
	TRF.std.fst = "55555";
	-- Drift with an odd and an even tick leg: fs toward 3 every 12 legs, fst toward 5 every 10 legs.
	TRF.fs[s] = "99990";
	TRF_Faction_Tick(13);
	HOST_Check(TRF.fs[s] == "88881", "fs drift at the crossing of 12 (odd leg 13): "..TRF.fs[s]);
	TRF_Faction_Tick(15);
	HOST_Check(TRF.fs[s] == "88881", "no fs drift without a crossing");
	TRF_Faction_Tick(24);
	HOST_Check(TRF.fs[s] == "77772", "fs drift at the crossing of 24 (even leg): "..TRF.fs[s]);
	TRF.std.fst = "09555";
	TRF_Faction_Tick(21);
	HOST_Check(TRF.std.fst == "18555", "fst drift at the crossing of 20: "..TRF.std.fst);
	TRF_Faction_Tick(29);
	HOST_Check(TRF.std.fst == "18555", "no fst drift without a crossing");
	TRF_Faction_Tick(30);
	HOST_Check(TRF.std.fst == "27555", "fst drift at 30: "..TRF.std.fst);
	TRF.std.fst = "55555"; TRF.fs[s] = "33333";
	-- Ladder: 500 flights per faction and rung (fighters and bombers) from the rung's rows only.
	local pre = TRF_FcPrefix();
	local bands = TRF_FcRungRows();
	local bad, nb = "", 0;
	h.diff = NORMAL;
	for f = 1, 5 do
		for r = 0, 3 do
			local ok = W_Rows(pre[f], bands[r + 1][1], bands[r + 1][2]);
			for n = 1, 500 do
				local k = 1 + mod(n, 2);
				TRF_GTest = HOST_Group("TRF_Test", "X");
				local fl, sh = TRF_FacFlight(f, r, k, "TRF_GTest", "trf_t", Vector3(0, 0, 20 * n), Vector3(0, 0, 1), 6);
				if not fl then bad = bad.." nil"..f..r..k; else
					nb = nb + 1;
					for i = 1, getn(sh) do if not ok[sh[i].tpl] then bad = bad.." "..sh[i].tpl.."@"..f..r..k; end; end;
					fl:Delete();
				end;
				h.ships = {};
			end;
		end;
	end;
	TRF_GTest = nil;
	TRF_Rd_ClearSign("trf_t");
	HOST_Check(nb == 10000 and bad == "", nb.." faction flights, every hull from its rung's rows"..strsub(bad, 1, 200));
	h.diff = EASY;
	bad = "";
	local ok0 = W_Rows("Vks", bands[1][1], bands[1][2]);
	for n = 1, 50 do
		TRF_GTest = HOST_Group("TRF_Test", "X");
		local fl, sh = TRF_FacFlight(1, 1, 1, "TRF_GTest", "trf_t", Vector3(5000, 0, 20 * n), Vector3(0, 0, 1), 6);
		for i = 1, getn(sh or {}) do if not ok0[sh[i].tpl] then bad = bad.." "..sh[i].tpl; end; end;
		if fl then fl:Delete(); end;
		h.ships = {};
	end;
	TRF_GTest = nil;
	TRF_Rd_ClearSign("trf_t");
	h.diff = NORMAL;
	HOST_Check(bad == "", "EASY lowers the rung (rung 1 builds rung 0 rows)"..bad);
	HOST_Check(TRF_FacBig(2, 1) == "Butcher_kfni1" and TRF_Ladder(5, 2).lo == 15 and TRF_Ladder(5, 2).hi == 17, "big ship and ladder rows");
	-- Strength events and clamps: a won sweep +2, a failed one -1 with salvage +2 for the clan.
	W_Teams(s, "Vks");
	local c = TRF.clan[s];
	c.sv = 0; c.sf = 0;
	TRF_RgSweepOut(s, TRF.clock.legs, nil, 1, "test", 10);
	HOST_Check(TRF_Fs(s, 1) == 2 and c.sv == 2 and c.sf == 1, "failed sweep: fs -1, sv +2, sf 1");
	TRF.rg[s].ph = 3;
	TRF_RgSweepOut(s, TRF.clock.legs, 1, 2, "test", 25);
	HOST_Check(TRF_Fs(s, 1) == 4, "won sweep: fs +2");
	TRF.fs[s] = "33333"; c.sv = 0; c.sf = 0;
	TRF_Faction_Dump();
	HOST_Check(V_Logs("module=faction event=dump ") >= 1, "faction dump line");
end;

-- g: sweeps as attempts (spec 7.3, 7.4) ----------------------------------------------------------------

-- Region slot s of kadi with its member teams on Vks, the player in its home, an attempt due; returns slot.
function W_SweepSetup(sc)
	local h = HOST();
	local s = V_Slot("kadi");
	W_Teams(s, "Vks");
	local home = TRF_SysName(TRF_RgMap()[s].home);
	if TRF_SysName(TRF_CurIdx()) ~= home then T_Jump(home); end;
	local r, c = TRF.rg[s], TRF.clan[s];
	r.ph = 3; r.pt = TRF.clock.legs; r.sn = 0; r.sl = TRF.clock.legs + 1; r.sr = nil; r.sw = 0; r.ct = 0;
	c.sc = sc or 99; c.sv = 0; c.sf = 0;
	TRF.fs[s] = "33333";
	return s;
end;

-- Starts the on-screen attempt (entry, then ticks until it runs; roll: the start's RAND draw); returns sw.
function W_SweepOn(roll)
	TRF.live.sw = nil;
	if not TRF_SweepEntry() then return nil; end;
	if roll then HOST().rq = {roll}; end;
	for i = 1, 100 do
		T_Tick(1, 0.5);
		if TRF.live.sw and TRF.live.sw.st ~= "wait" then break; end;
	end;
	return TRF.live.sw;
end;

function T_V1_G()
	local h = HOST();
	h.labels.CurrentQuest = "5_1";
	W_Begin("gredos", {staged=0, seed=0, carriers=0, feq=0, bases=0, dconv=0, conv=0, tt4=0});
	local s = W_SweepSetup(99);
	local r, c = TRF.rg[s], TRF.clan[s];
	-- Odds of the attempts (7.3 example): T4 at fs 3 10 %, fs 2 + sv 2 25 %, fs 1 + sv 4 55 %, attempt 4 certain.
	local p1 = TRF_RgSweepP(s, 1);
	TRF.fs[s] = "23333"; c.sv = 2;
	local p2 = TRF_RgSweepP(s, 2);
	TRF.fs[s] = "13333"; c.sv = 4;
	local p3 = TRF_RgSweepP(s, 3);
	HOST_Check(TRF_SweepOwner(s) == 1 and p1 == 10 and p2 == 25 and p3 == 55 and TRF_RgSweepP(s, 4) == 100,
		"attempt odds 10/25/55/100: a sweep succeeds within 4 attempts ("..p1.."/"..p2.."/"..p3..")");
	-- Off-screen: a raid region always ends its sweeps by the 4th attempt (200 seeds).
	local over = 0;
	for k = 1, 200 do
		h.seed = 1000 + k;
		TRF.fs[s] = "33333"; c.sv = 0; c.sc = 99;
		r.ph = 3; r.sn = 0; r.sw = 0; r.sr = nil;
		local n = 0;
		while r.sw == 0 and n < 6 do
			n = n + 1;
			TRF_RgSweepRoll(s, TRF.clock.legs, r, c, TRF_RgTune());
		end;
		if r.sw ~= 1 or n > 4 then over = over + 1; end;
	end;
	HOST_Check(over == 0, "200 seeded off-screen runs: every sweep won by attempt 4 ("..over.." over)");
	-- On-screen first attempt against a T4 clan at rung 1: fails in >= 80 % of 100 seeded runs (no kills).
	local fails, ran = 0, 0;
	for k = 1, 100 do
		h.seed = 2000 + k;
		s = W_SweepSetup(99);
		local sw = W_SweepOn();
		if sw and sw.st == "on" then
			ran = ran + 1;
			if sw.roll == 2 then fails = fails + 1; end;
		end;
		TRF_Faction_BeforeJump();
		TRF.live.sw = nil;
		TRF_H().sw = nil;
		h.ships = {};
	end;
	print("HOST info sweep first attempts failed on-screen "..fails.."/"..ran);
	HOST_Check(ran == 100 and fails >= 80, "first attempt fails on-screen in "..fails.." of "..ran.." seeded runs (>= 80)");
	-- Withdrawal at 40 % faction losses (failed roll).
	s = W_SweepSetup(99);
	local sw = W_SweepOn(99);
	local H = TRF_H().sw;
	for i = 1, 90 do T_Tick(1, 0.5); end;
	HOST_Check(sw and sw.st == "on" and sw.roll == 2 and r.sr == 2 and sw.nc >= 1 and sw.nf >= 1, "attempt on: roll failed and stored (sr 2), clan "..tostring(sw and sw.nc).." faction "..tostring(sw and sw.nf));
	local kill = ceil(0.4 * getn(H.fs));
	for j = 1, kill do H.fs[j].alive = nil; TRF_SwDied(TRF.gen, 100 + j, TRF.gen); end;
	local sv0 = c.sv;
	TRF_Sweep_Step();
	HOST_Check(sw.st == "out" and sw.won == 0 and r.sn == 1 and TRF_Fs(s, 1) == 2 and c.sv == sv0 + 2 and c.sf == 1,
		"withdrawal at 40 % losses: failed, fs -1, sv +2 with sf 1 ("..sw.st..")");
	for i = 1, 3 do TRF_Sweep_Step(); end;
	TRF_Faction_BeforeJump();
	-- Clan side down to <= 25 %: success (kills by the player count, no pay without a contract).
	s = W_SweepSetup(99);
	sw = W_SweepOn(99);
	H = TRF_H().sw;
	for i = 1, 90 do T_Tick(1, 0.5); end;
	local cr0 = h.credits;
	local nk = getn(H.cs) - floor(0.25 * getn(H.cs));
	for j = 1, nk do H.cs[j].alive = nil; TRF_SwDied(TRF.gen, j, TRF.gen); end;
	TRF_SweepEnd("test");
	HOST_Check(sw.won == 1 and r.sw == 1 and h.credits == cr0, "clan side at <= 25 %: success, no pay without a contract");
	TRF_Faction_BeforeJump();
	-- Join contract: part done -> success, pay min(2000 x L_w x lk x d_k x tier_k, 30000), fs +1 on top of the win.
	s = W_SweepSetup(99);
	r.ct = 1;
	sw = W_SweepOn(99);
	H = TRF_H().sw;
	for i = 1, 90 do T_Tick(1, 0.5); end;
	for j = 1, 2 do
		for q = 1, 6 do h.gt = h.gt + 1; TRF.clock.gt = TRF.clock.gt + 1; TRF_CtJoinPart(TRF.gen, j, TRF.gen); end;
		H.cs[j].alive = nil;
		TRF_SwDied(TRF.gen, j, TRF.gen);
	end;
	cr0 = h.credits;
	local f0, st0 = TRF_Fs(s, 1), TRF_Fst(1);
	local want = min(2000 * TRF_LPayK(TRF_CurIdx()) * TRF_TierK(TRF_CurIdx()), 30000);
	TRF_SweepEnd("test");
	HOST_Check(sw.won == 1 and r.sw == 1 and h.credits - cr0 == floor(want) and TRF_Fs(s, 1) == f0 + 3 and TRF_Fst(1) == st0 + 1
		and TRF_Bit(r.ct, 1) == 0, "contract part done: success despite roll 2, pay "..(h.credits - cr0).." = "..floor(want)..", fs +3, fst +1");
	for i = 1, 3 do TRF_Sweep_Step(); end;
	HOST_Check(sw.st == "done", "faction ships removed at the portal");
	TRF_Faction_BeforeJump();
	HOST_Check(TRF.live.sw == nil and TRF_H().sw == nil, "jump clears the sweep");
	-- sr replaces the off-screen roll after a jump. The join hits above marked combat (TRF_CtJoinPart through
	-- TRF_Cb); a new sweep does not enter during combat, so the hold is cleared here.
	TRF.live.cbt = nil;
	s = W_SweepSetup(99);
	sw = W_SweepOn(0);
	HOST_Check(sw and r.sr == 1, "roll 0 -> success stored (sr 1)");
	TRF_RgSweepRoll(s, TRF.clock.legs, r, c, TRF_RgTune());
	HOST_Check(r.sn == 0 and r.sw == 0 and r.sr == 1, "off-screen roll deferred while the attempt plays");
	T_Jump("aurora");
	r = TRF.rg[s]; c = TRF.clan[s];
	HOST_Check(r.sw == 1 or (r.sr == nil and r.sw == 1) or (r.sr == 1), "after the jump: stored roll kept ("..tostring(r.sr)..")");
	TRF_RgSweepRoll(s, TRF.clock.legs, r, c, TRF_RgTune());
	HOST_Check(r.sw == 1 and r.sr == nil, "resolved off-screen with the stored roll");
	-- Target denied (deny entry m = 1 / strict gate): off-screen only.
	s = W_SweepSetup(99);
	local cur = TRF_CurIdx();
	local qi = TRF_SafeQIds(cur, TRF_Map().sys[cur]);
	if type(qi) == "table" and qi[1] then h.quests[qi[1]] = QUEST_PROCESS; else h.qs = TRUE; end;
	TRF.live.qa = nil; TRF.live.qai = nil; TRF_H().loc = nil;
	local ok, why = TRF_SweepEntry();
	HOST_Check(not ok and why == "strict", "target with a running quest: no on-screen attempt ("..tostring(why)..")");
	TRF_RgSweepRoll(s, TRF.clock.legs, r, c, TRF_RgTune());
	HOST_Check(r.sn == 1 or r.sw == 1, "the attempt resolves off-screen (sn "..r.sn.." sw "..r.sw..")");
	h.qs = FALSE; h.quests = {};
	TRF.live.sw = nil;
end;

-- h: pirate-side offers and payouts (spec 7.5, 7.7) -------------------------------------------------------

-- The vanilla pirate dock Ok as __PirDock_Action leaves it (_param = the shop).
function W_PirDock()
	_param = "pirate1";
	__PirStationDock_Ok();
end;

function T_V1_H()
	local h = HOST();
	h.labels.CurrentQuest = "5_1";
	W_Begin("gredos", {staged=0, seed=0, carriers=0, feq=0, bases=0, dconv=0, conv=0, tt4=0});
	local s = V_Slot("kadi");
	W_Teams(s, "Vks");
	local m = TRF_RgMap();
	for i = 1, getn(m[s].sys) do if m.pc[m[s].sys[i]] > 0 then TRF_SetPro(m[s].sys[i], m.pc[m[s].sys[i]]); end; end;
	T_Jump(TRF_SysName(m[s].home));
	-- Gate: heat too low, then pirates not at war with the player: the offer box first.
	h.rel_team = {}; h.rel_team["Pirates|"..PLAYER_TEAM] = RELATION_NEUTRAL;
	h.credits = 5000;
	TRF.offer = nil;
	TRF.std.heat = 0;
	h.pir_ok = 0;
	_param = "pirate1";
	local nb = getn(h.boxes);
	W_PirDock();
	HOST_Check(h.pir_ok == 1 and getn(h.boxes) == nb, "heat 0: no offer, the original dock at once");
	TRF.std.heat = 5;
	h.rel_team["Pirates|"..PLAYER_TEAM] = RELATION_WAR;
	W_PirDock();
	HOST_Check(h.pir_ok == 2 and getn(h.boxes) == nb, "pirates at war with the player: no offer");
	h.rel_team["Pirates|"..PLAYER_TEAM] = RELATION_NEUTRAL;
	W_PirDock();
	HOST_Check(getn(h.boxes) == nb + 1 and h.pir_ok == 2, "heat 5, R high, pirates neutral: offer box first (R="..TRF_RgR(s)..")");
	HOST_Press("ok");
	T_Tick(2, 0.5);
	local o = TRF.offer;
	HOST_Check(h.pir_ok == 3 and type(o) == "table" and (o.k == 1 or o.k == 2), "accepted: offer k "..tostring(o and o.k)..", the original once");
	HOST_Check((o.k == 2 and h.credits == 3000) or (o.k == 1 and h.credits == 5000), "intel costs po_intel_cost 2000, a paid raid nothing (credits "..h.credits..")");
	W_PirDock();
	HOST_Check(h.pir_ok == 4, "pending offer: the original at once");
	-- Paid raid: tip-off seed in the target system, kill -> pay owed, paid at the next docking.
	if o.k == 2 then TRF.offer = {k=1, s=o.s, t=o.t}; o = TRF.offer; end;
	T_Jump(TRF_SysName(o.s));
	local pe = TRF_PoEntry();
	TRF_PoDone(77, "spawn");
	TRF_PoDone(77, "kill");
	HOST_Check(pe and pe.k == 1 and TRF.offer.k == 3 and TRF.offer.p > 0 and TRF.offer.p <= 30000, "paid raid: entry seed, kill -> pay owed "..tostring(TRF.offer.p));
	local c1, p = h.credits, TRF.offer.p;
	local nbp = getn(h.boxes);
	W_PirDock();
	HOST_Check(h.credits == c1 + p and TRF.offer == nil and getn(h.boxes) == nbp, "pay owed paid at the next pirate docking, offer cleared, no offer box");
	-- Expiry after po_legs (8).
	TRF.offer = {k=1, s=3, t=TRF.clock.legs - 1};
	TRF_Faction_Tick(TRF.clock.legs);
	HOST_Check(TRF.offer == nil, "expired offer dropped");
	-- Pay sources: each payment <= 30000.
	TRF_Pay(99999, "test");
	HOST_Check(W_PayMax() <= 30000 and W_PayMax() > 0, "every payment <= 30000 (max "..W_PayMax()..")");
	-- Shared helpers of the mercenary clans (design/merc-spec.md 4): packing over a key list of 28 integers at the
	-- 32-bit bound, the old 14-key wrappers unchanged, charges.
	local ks, r0 = {}, {};
	for i = 1, 28 do ks[i] = "k"..i; r0["k"..i] = i * 1000 - 14000; end;
	r0.k1 = 2147483647; r0.k2 = -2147483647; r0.k3 = 0; r0.k28 = 2147483647;
	local ps = TRF_TpPackK(r0, ks);
	local r1 = TRF_TpUnpackK(ps, ks);
	local same = r1 ~= nil;
	for i = 1, 28 do if not r1 or r1["k"..i] ~= r0["k"..i] then same = nil; end; end;
	HOST_Check(same and strlen(ps) > 80 and strsub(ps, 1, 22) == "2147483647,-2147483647" and TRF_TpUnpackK(ps, ks, 80) == nil and TRF_TpUnpack(ps) == nil,
		"TRF_TpPackK/TRF_TpUnpackK: 28 integers round-trip at the 2^31-1 bound ("..strlen(ps).." chars); the 80-char and 14-key limits refuse it");
	local rn = {};
	for i = 1, 28 do rn["k"..i] = -2147483647; end;
	local pn = TRF_TpPackK(rn, ks);
	local un = TRF_TpUnpackK(pn, ks);
	HOST_Check(strlen(pn) == 12 * 28 - 1 and un and un.k1 == -2147483647 and un.k28 == -2147483647,
		"the default length admits every key at the negative bound ("..strlen(pn).." chars)");
	HOST_Check(TRF_TpPackK({a=1e12, b=-1e12, c=2.7}, {"a", "b", "c"}) == "2147483647,-2147483647,2" and TRF_TpPackK(nil, ks) == nil and TRF_TpPackK({}, nil) == nil,
		"the pack clamps to the bound itself (the game would wrap, the host saturates)");
	HOST_Check(TRF_TpUnpackK("1,2", {"a", "b", "c"}) == nil and TRF_TpUnpackK("1,,2", {"a", "b", "c"}) == nil and TRF_TpUnpackK("1,x,2", {"a", "b", "c"}) == nil
		and TRF_TpUnpackK(nil, ks) == nil and TRF_TpUnpackK("1,2,3", nil) == nil and TRF_TpUnpackK("1,-2,3", {"a", "b", "c"}).b == -2, "unpack refuses a wrong count, an empty field, a letter, no key list");
	local tr0 = {id=7, nm=3, o=12, c=1, tt=2, pw=14, n=3, e=0, s=99, fr=5, d=2, dm=1, fl=0, t=-12};
	local tp0 = TRF_TpPack(tr0);
	local tr1 = TRF_TpUnpack(tp0);
	HOST_Check(tp0 == "7,3,12,1,2,14,3,0,99,5,2,1,0,-12" and tr1 and tr1.t == -12 and tr1.pw == 14 and TRF_TpOk(tp0) == 1 and TRF_TpUnpack(tp0..",1") == nil,
		"TRF_TpPack/TRF_TpUnpack (14 pool keys, 80 chars) give the same strings as before");
	h.credits = 10000;
	local tk, why = TRF_Charge(4000.7, "test");
	HOST_Check(tk == 4000 and why == nil and h.credits == 6000 and T_Stat("charge_test") == 4000, "TRF_Charge: floor, SubPlayerCredits, stat charge_<why>");
	tk, why = TRF_Charge(7000, "test");
	HOST_Check(tk == 0 and why == "short" and h.credits == 6000, "refused while the wallet is below the amount (default reserve)");
	tk, why = TRF_Charge(7000, "test", 0);
	HOST_Check(tk == 6000 and h.credits == 0, "reserve 0: what the wallet holds, never negative");
	tk, why = TRF_Charge(100, "test", 0);
	HOST_Check(tk == 0 and why == "short" and h.credits == 0, "empty wallet: nothing taken");
	h.credits = 50000;
	local tk1 = TRF_Charge(1000, "test", 20000);
	local tk2, why2 = TRF_Charge(1000, "test", 60000);
	HOST_Check(tk1 == 1000 and tk2 == 0 and why2 == "short" and h.credits == 49000, "reserve 2 x (fee + owe): refused below it");
	HOST_Check(TRF_Charge(-5, "test") == 0 and TRF_Charge(nil, "test") == 0 and h.credits == 49000, "a negative or missing amount charges nothing");
	h.credits = 400000;
	tk = TRF_Charge(300000, "test", 0);
	HOST_Check(tk == 250000 and h.credits == 150000 and TRF_RgTune().charge_cap == 250000, "capped at tune charge_cap 250,000");
	HOST_Check(V_Logs("module=region event=charge reason=test amount=4000 taken=4000 credits=10000") == 1
		and V_Logs("module=region event=charge reason=test amount=7000 credits=6000 reserve=7000 result=short") == 1, "charge log lines");
	HOST_Check(abs(TRF_LChargeK(TRF_CurIdx()) - TRF_LPay(TRF_CurIdx()) * TRF_DK()) < 0.001, "charge level term L_w x d_k, no lk");
end;

-- i: TT4 convoys and bands 8-9 (spec 8.1-8.3) ---------------------------------------------------------

-- A flight of n transports tpl in group Z for the hold builders.
function W_TpFlight(n, tpl, x)
	local fl = HOST_Group("Z"):CreateFlight("z");
	for j = 1, n do
		local s = CreateCarcass(tpl, Vector3(x, 0, 30 * j), Vector3(0, 0, 1));
		s:AssignPilot(CreatePilot("Trader"));
		fl:AddShip(s);
	end;
	return fl;
end;

function T_V1_I()
	local h = HOST();
	h.labels.CurrentQuest = "5_1";
	h.st_label = "TRADE STATION";
	W_Begin("gredos", {raids=0, staged=0, seed=0, queue=0, parked=0, carriers=0, sweeps=0, feq=0, bases=0, dconv=0, conv=0});
	local idx = TRF_CurIdx();
	local slot = TRF_RgOf(idx);
	TRF_SetDis(idx, 0);
	V_Pro(8);
	local c = TRF_BandCaps(idx);
	local ct, cs, cp = TRF_SafeCaps();
	HOST_Check(c.sf == 1.75 and c.ct == 5 and c.cs == 20 and c.cp == 2 and c.band == 3 and ct == 5 and cs == 20 and cp == 2, "pro 8: band 3, sf 1.75, caps 5/20, parked 2");
	V_Pro(9);
	c = TRF_BandCaps(idx);
	HOST_Check(c.sf == 2.00 and c.ct == 5 and c.cs == 20 and c.cp == 2 and c.band == 4, "pro 9: band 4, sf 2.00, caps 5/20, parked 2");
	-- TT4 roll rates over 2000 picks: 25 % at pro 8, 40 % at pro 9 (RAND draws, no forced roll).
	local rate = function(p)
		V_Pro(p);
		local n4 = 0;
		for k = 1, 2000 do if TRF_TierPick(%idx, 8, 20) == 4 then n4 = n4 + 1; end; end;
		return n4 / 2000;
	end;
	local r8, r9 = rate(8), rate(9);
	print("HOST info TT4 rate pro 8 "..r8.." pro 9 "..r9);
	HOST_Check(abs(r8 - 0.25) <= 0.03 and abs(r9 - 0.40) <= 0.03, "TT4 rolls 25 / 40 % (+- 3): "..r8.." / "..r9);
	local t, why = nil, nil;
	TRF.std.heat = 3; h.rq = {0};
	t, why = TRF_TierPick(idx, 8, 20);
	HOST_Check(t == 3 and why == "tt4_heat", "heat 3 blocks TT4 -> TT3 ("..tostring(why)..")");
	TRF.std.heat = 0;
	TRF_SetDis(idx, 4); h.rq = {0};
	t, why = TRF_TierPick(idx, 8, 20);
	HOST_Check(t ~= 4, "no TT4 in a danger system (dis 4): "..t.." "..tostring(why));
	TRF_SetDis(idx, 0);
	-- Composition at pro 8 / 9: 3 / 4 transports, 4 / 6 escorts.
	local c8, c9 = TRF_TierComp(4, 10, 8), TRF_TierComp(4, 10, 9);
	HOST_Check(c8.tp == 3 and c8.ne == 4 and c9.tp == 4 and c9.ne == 6, "TT4 composition 3+4 / 4+6");
	local tp0 = TRF_TierPick;
	TRF_TierPick = function() return 4, "test"; end;
	local id = T_Spawn("B");
	TRF_TierPick = tp0;
	local r = TRF.live.tr[id];
	local C = TRF_CvH();
	local e = C.e[id];
	HOST_Check(r and r.tier == 4 and r.nt == 4 and TRF.live.cvs and TRF.live.cvs.k == 3 and e and getn(e.sh) == 6 and e.fl[1].esc == TRF_H().tr[id].tp[1],
		"TT4 spawn at pro 9: 4 transports, 6 escorts escorting the lead, convoy slot rank 3");
	h.rq = {0};
	t, why = TRF_TierPick(idx, 8, 20);
	HOST_Check(t == 3 and why == "tt4_slot", "a second TT4 waits for the slot ("..tostring(why)..")");
	-- 1000 TT4 holds inside 45k-95k (or tt4_value_miss logged).
	local inw, miss0 = 0, T_Stat("tt4_value_miss");
	for k = 1, 1000 do
		local fl = W_TpFlight(3, "Btransport", 5000 + 50 * k);
		C.b = {f=0};
		local out = TRF_Tt4Hold(fl, 16, "B");
		local v = TRF_CvValue(out);
		if v >= 45000 and v <= 95000 then inw = inw + 1; end;
		fl:Delete();
		h.ships = {};
	end;
	local miss = T_Stat("tt4_value_miss") - miss0;
	print("HOST info TT4 holds in window "..inw.."/1000, misses logged "..miss);
	HOST_Check(inw + miss == 1000, "1000 TT4 holds: "..inw.." in 45000-95000, "..miss.." logged tt4_value_miss");
	-- Player kill of the TT4 convoy: ct bit 4, Bust at the next region tick from Boom; ignored in Raids and for T4.
	r.cnt = 1;
	W_KillTr(id);
	T_Tick(2, 0.5);
	HOST_Check(TRF.live.cvs == nil and TRF_Bit(TRF.rg[slot].ct, 4) == 1, "TT4 player kill: slot free, ct bit 4");
	local rg = TRF.rg[slot];
	rg.ph = 1; rg.pt = TRF.clock.legs; TRF.clan[slot].sc = 50;
	TRF_RegionTick(TRF.clock.legs + 1);
	HOST_Check(rg.ph == 4 and TRF_Bit(rg.ct, 4) == 0, "forced Bust from Boom at the next tick, bit cleared ("..rg.ph..")");
	rg.ph = 3; rg.pt = TRF.clock.legs; rg.ct = 4; TRF.clan[slot].sc = 60;
	TRF_RegionTick(TRF.clock.legs + 2);
	HOST_Check(rg.ph == 3 and TRF_Bit(rg.ct, 4) == 0, "ignored in Raids, bit cleared");
	rg.ph = 1; rg.pt = TRF.clock.legs; rg.ct = 4; TRF.clan[slot].sc = 99;
	TRF_RegionTick(TRF.clock.legs + 3);
	HOST_Check(rg.ph ~= 4 and TRF_Bit(rg.ct, 4) == 0, "ignored for a T4 clan (score 99), bit cleared ("..rg.ph..")");
	-- Kill cap 3 still stops spawns (a TT4 convoy counts once).
	TRF.live.kills = 3;
	local n0 = TRF.seq;
	h.rq = {0, 0}; T_Gen(); h.rq = {};
	HOST_Check(TRF.seq == n0, "kill cap 3: no spawn");
	TRF.live.kills = 0;
end;

-- j: faction equipment convoys (spec 8.4) ----------------------------------------------------------------

function T_V1_J()
	local h = HOST();
	h.labels.CurrentQuest = "5_1";
	h.st_label = "TRADE STATION";
	W_Begin("gredos", {raids=0, staged=0, seed=0, queue=0, parked=0, carriers=0, sweeps=0, bases=0, dconv=0, conv=0, tt4=0});
	local al = V_Idx("altair");
	local sl = TRF_RgOf(al);
	W_SideTeams();
	TRF_SetPro(al, 7);
	-- 200 legs of the full cycle: never two scheduled records, the 20-leg cooldown between them.
	h.logs = nil;
	local two, cool, made, lastend = 0, 0, 0, nil;
	local prev = nil;
	for i = 1, 200 do
		local had = TRF.feq and TRF.feq.k == 1 and TRF.feq.t;
		TRF_AddLeg("test");
		local f = TRF.feq;
		if f and f.k == 1 and f.t ~= had then
			made = made + 1;
			if had then two = two + 1; end;
			if lastend and f.t < lastend + 20 then cool = cool + 1; end;
		end;
		if f and f.k == 2 then lastend = f.t; end;
	end;
	h.logs = {};
	HOST_Check(made >= 1 and two == 0 and cool == 0, "200 legs: "..made.." records, never two scheduled, cooldown 20 kept");
	-- 2000 legs of region ticks (every 2 legs): mean interval 25-45 legs.
	TRF.feq = nil;
	local L0 = TRF.clock.legs;
	made = 0;
	for L = L0 + 2, L0 + 2000, 2 do
		local had = TRF.feq and TRF.feq.k == 1 and TRF.feq.t;
		TRF_Convoy_Tick(L);
		if TRF.feq and TRF.feq.k == 1 and TRF.feq.t == L and TRF.feq.t ~= had then made = made + 1; end;
	end;
	local mi = 2000 / max(1, made);
	print("HOST info equipment convoys in 2000 legs: "..made.." (mean "..mi..")");
	HOST_Check(mi >= 25 and mi <= 45, "mean interval "..mi.." legs (25-45)");
	-- Eligibility: owner, station, pro >= 6, fs >= 2, not border, not Fronn.
	TRF.fs[sl] = "33333";
	TRF_SetPro(al, 7);
	local has = function(idx) local cs = TRF_CvFeqCand(nil); for i = 1, getn(cs) do if cs[i][1] == idx then return 1; end; end; return nil; end;
	HOST_Check(has(al), "altair (Vks, station, pro 7, fs 3) eligible");
	TRF_SetPro(al, 5);
	HOST_Check(not has(al), "pro 5: not eligible");
	TRF_SetPro(al, 7);
	local fs0 = TRF.fs[sl];
	TRF.fs[sl] = "13333";
	HOST_Check(not has(al), "fs 1: not eligible");
	TRF.fs[sl] = fs0;
	HOST_Check(not has(V_Idx("fronn")), "Fronn never eligible");
	-- Hold value inside the rung window for 1000 holds per rung (or feq_value_miss logged).
	local C = TRF_CvH();
	local ok = "";
	for rr = 0, 3 do
		local lo, hi = TRF_CvT("feq_v"..rr.."lo"), TRF_CvT("feq_v"..rr.."hi");
		local inw, m0 = 0, T_Stat("feq_value_miss");
		for k = 1, 1000 do
			local fl = W_TpFlight(2, "Walrus_nav"..(rr + 1), 6000 + 40 * k);
			local out = TRF_CvFeqHold(fl, {f=1, r=rr});
			local v = TRF_CvValue(out);
			if v >= lo and v <= hi then inw = inw + 1; end;
			fl:Delete();
			h.ships = {};
		end;
		local miss = T_Stat("feq_value_miss") - m0;
		ok = ok.." r"..rr.."="..inw.."+"..miss;
		if inw + miss ~= 1000 then ok = ok.."!"; end;
	end;
	print("HOST info equipment holds in window (+ logged misses):"..ok);
	HOST_Check(not strfind(ok, "!", 1, 1), "1000 holds per rung inside the window or feq_value_miss logged:"..ok);
	-- Visit: due, appears, counted player attack -> wave 1 at 20-30 s, wave 2 below 50 % HP at rung + 1.
	TRF.feq = {k=1, f=1, s=al, r=1, t=TRF.clock.legs};
	T_Jump("altair");
	TRF.feq = {k=1, f=1, s=al, r=1, t=TRF.clock.legs};
	TRF_SetPro(al, 7);
	HOST_Check(TRF_FeqEntry() == 1 and TRF.live.fq.st == "due" and TRF.live.cvs.k == 4, "equipment convoy due: slot rank 4 reserved");
	T_Tick(100, 0.5);
	local fq = TRF.live.fq;
	local hf = TRF_CvH().fq;
	HOST_Check(fq.st == "live" and getn(hf.tp) >= 2 and hf.tp[1].tpl == "Walrus_nav2" and getn(hf.esh) >= 2, "convoy appears: Walrus_nav2 transports, faction escorts");
	HOST_Check(getn(TRF_Feq_HailOpts(fq.id)) == 1, "defence offer in the hail");
	local ta, heat0 = nil, TRF.std.heat;
	-- The player's fire hits the convoy ships' trader triggers (trf_events) and the convoy's own (trf_convoy).
	for k = 1, 6 do
		HOST_FireAll("attack", "TRF_FeqAttack");
		HOST_FireAll("attack", "TRF_OnAttack("..fq.id..",");
		T_Tick(2, 0.5);
		if fq.atk and not ta then ta = fq.atk; end;
	end;
	HOST_Check(fq.atk and fq.src == "p", "counted player attack starts the fight");
	local tw = nil;
	for k = 1, 80 do T_Tick(1, 0.5); if fq.w1d and not tw then tw = TRF.clock.gt - fq.atk; end; end;
	HOST_Check(tw and tw >= 20 and tw <= 31 and getn(hf.wsh) > 0, "wave 1 at "..tostring(tw).." s after the first counted attack (20-30)");
	-- The first escorts die in the fight, so wave 2 fits the 14-ship event cap.
	for i = 1, getn(hf.esh) do hf.esh[i].alive = nil; end;
	local n1 = getn(hf.wsh);
	local okw2 = W_Rows("Vks", TRF_FcRungRows()[3][1], TRF_FcRungRows()[3][2]);
	for i = 1, getn(hf.tp) do hf.tp[i].hp = 450; end;
	T_Tick(4, 0.5);
	local bad = "";
	for i = n1 + 1, getn(hf.wsh) do if not okw2[hf.wsh[i].tpl] and not strfind(hf.wsh[i].tpl, "Butcher", 1, 1) then bad = bad.." "..hf.wsh[i].tpl; end; end;
	HOST_Check(fq.w2d == 1 and getn(hf.wsh) > n1 and bad == "", "wave 2 below 50 % HP at rung 2 (rung + 1)"..bad);
	local nw = getn(hf.wsh);
	for i = 1, getn(hf.tp) do hf.tp[i].hp = 100; end;
	T_Tick(20, 0.5);
	HOST_Check(getn(hf.wsh) == nw and TRF_CvFeqShips(hf) <= 14, "no third wave, <= 14 event ships ("..TRF_CvFeqShips(hf)..")");
	-- Player kill: forced Bust bit, fst -3, heat +3, record k 2.
	local fst0 = TRF_Fst(1);
	local rr = TRF.live.tr[fq.id];
	for i = 1, getn(hf.tp) do hf.tp[i].alive = nil; end;
	rr.pa = TRF.clock.gt;
	HOST_FireAll("died", "TRF_OnShipDied");
	T_Tick(2, 0.5);
	HOST_Check(fq.st == "end" and TRF.feq.k == 2 and TRF_Bit(TRF.rg[sl].ct, 4) == 1 and TRF.live.cvs == nil, "player kill: record k 2, forced Bust bit, slot free");
	HOST_Check(TRF_Fst(1) == max(0, fst0 - 3), "player kill: fst "..fst0.." -> "..TRF_Fst(1));
	HOST_Check(TRF.std.heat == min(9, heat0 + 3), "attack and kill: heat +3 in total ("..heat0.." -> "..TRF.std.heat..")");
	TRF.rg[sl].ct = 0;
	-- Taken by pirates (HP drop without player fire): sv +3, score +5.
	T_Jump("altair");
	TRF.feq = {k=1, f=1, s=al, r=0, t=TRF.clock.legs};
	TRF_FeqEntry();
	T_Tick(100, 0.5);
	local fq2, hf2 = TRF.live.fq, TRF_CvH().fq;
	local sc0, sv0 = TRF.clan[sl].sc, TRF.clan[sl].sv;
	for i = 1, getn(hf2.tp) do hf2.tp[i].hp = 900; end;
	T_Tick(2, 0.5);
	HOST_Check(fq2.atk and fq2.src == "o", "HP drop without player fire: attacked by others");
	for i = 1, getn(hf2.tp) do hf2.tp[i].alive = nil; end;
	HOST_FireAll("died", "TRF_OnShipDied");
	T_Tick(2, 0.5);
	HOST_Check(fq2.st == "end" and TRF.clan[sl].sc == min(99, sc0 + 5) and TRF.clan[sl].sv == min(9, sv0 + 3) and TRF.clan[sl].sf == 1,
		"taken by pirates: score +5, sv +3, sf 1 ("..sc0.." -> "..TRF.clan[sl].sc..")");
	-- Defence contract: completed -> min(4 x N_eff, 30000), help +2.
	T_Jump("altair");
	TRF.feq = {k=1, f=1, s=al, r=0, t=TRF.clock.legs};
	TRF_FeqEntry();
	T_Tick(100, 0.5);
	local fq3 = TRF.live.fq;
	HOST_Check(TRF_FeqAccept(fq3.id) == 1, "defence contract accepted");
	local cr0, hp0 = h.credits, TRF.std.help;
	h.ms.pos = TRF_CvH().fq.tp[1]:GetPosition();
	T_Tick(2, 0.5);
	TRF_Remove(fq3.id, "exit");
	T_Tick(2, 0.5);
	HOST_Check(fq3.st == "end" and h.credits - cr0 == min(30000, 4 * TRF_PayN(al)) and TRF.std.help == min(99, hp0 + 2),
		"defence pay "..(h.credits - cr0).." = min(4 x N_eff, 30000), help +2");
	TRF_Convoy_Dump();
	HOST_Check(V_Logs("module=convoy event=dump") >= 1, "convoy dump line");
end;

-- k: danger convoys and the convoy slot (spec 8.5, 8.6) -------------------------------------------------

-- A fresh trader plan of contact 1 (no spawn).
function W_Plan()
	TRF.live.port = {};
	TRF_GnValidateAll();
	return TRF_Plan(TRF_GnContacts()[1], 1, nil, 20);
end;

-- A danger convoy started through TRF_DcPlan / TRF_DcStart (plan redrawn until "convoy"), or nil.
function W_DcConvoy(path)
	for k = 1, 200 do
		local p = W_Plan();
		if p and (not path or p.path == path) then
			p.dcp = nil;
			if TRF_DcPlan(p) == "convoy" then return TRF_DcStart(p), p; end;
		end;
	end;
	return nil;
end;

function T_V1_K()
	local h = HOST();
	h.labels.CurrentQuest = "5_1";
	h.st_label = "TRADE STATION";
	W_Begin("gredos", {raids=0, staged=0, seed=0, queue=1, parked=0, carriers=0, sweeps=0, feq=0, bases=0, conv=0, tt4=0});
	local cur = TRF_CurIdx();
	local slot = TRF_RgOf(cur);
	-- Gating: dis >= 4 or the region in Raids; gates (Fronn and deny entries, governor, flags).
	TRF_SetDis(cur, 0);
	TRF.rg[slot].ph = 1;
	HOST_Check(not TRF_DangerSys(cur), "dis 0, Boom: not a danger system");
	TRF.rg[slot].ph = 3;
	HOST_Check(TRF_DangerSys(cur) == 1, "region in Raids: danger system");
	TRF.rg[slot].ph = 1;
	TRF_SetDis(cur, 4);
	HOST_Check(TRF_DangerSys(cur) == 1 and TRF_DcGate(cur) == 1, "dis 4: danger system, gates open");
	HOST_Check(not TRF_DcGate(V_Idx("fronn")), "Fronn: no danger convoy");
	__disableAction = TRUE;
	HOST_Check(not TRF_DcGate(cur), "flag set: no convoy");
	__disableAction = FALSE;
	h.extra_carcass = 50; TRF_Governor();
	HOST_Check(not TRF_DcGate(cur), "governor: no convoy");
	h.extra_carcass = nil; TRF_Governor();
	-- 5000 plans: expected transports per accepted roll within +- 5 % of 1 (chance 1/N per convoy), ~20 % solo.
	local tp, solo, conv, none, n = 0, 0, 0, 0, 0;
	for k = 1, 5000 do
		local p = W_Plan();
		if p then
			n = n + 1;
			local s0 = T_Stat("dc_solo");
			p.dcp = nil;
			local d = TRF_DcPlan(p);
			if d == "convoy" then conv = conv + 1; tp = tp + p.dcn;
			elseif d == nil then none = none + 1;
			else tp = tp + 1; if T_Stat("dc_solo") > s0 then solo = solo + 1; end; end;
		end;
	end;
	print("HOST info danger plans n="..n.." transports/plan="..(tp / n).." solo="..(solo / n).." convoy="..conv.." none="..none);
	HOST_Check(n > 4000 and abs(tp / n - 1) <= 0.05, "transports per plan "..(tp / n).." (1 +- 5 %)");
	HOST_Check(abs(solo / n - 0.20) <= 0.03, "risk takers "..(solo / n).." (~20 %)");
	-- Station convoy: escorts 3-5 of mid / cheap hulls, never Puma_merc1 or Gunslinger_merc1.
	local bad, ne = "", "";
	for k = 1, 20 do
		local id = W_DcConvoy();
		if id then
			local e = TRF_H().dc[id];
			ne = ne.." "..getn(e.sh);
			if getn(e.sh) < 3 or getn(e.sh) > 5 then bad = bad.." n"..getn(e.sh); end;
			for i = 1, getn(e.sh) do
				if e.sh[i].tpl == "Puma_merc1" or e.sh[i].tpl == "Gunslinger_merc1" then bad = bad.." "..e.sh[i].tpl; end;
			end;
			TRF_Danger_BeforeJump();
			V_ClearTr();
			TRF.live.cvs = nil; TRF.live.dc = {};
			h.ships = {};
		end;
	end;
	HOST_Check(bad == "" and ne ~= "", "20 convoys: escorts 3-5 ("..ne.."), no Puma_merc1 / Gunslinger_merc1"..bad);
	-- Forming at the station's hold points: leaves when complete.
	local id, p = W_DcConvoy("B");
	local dc = TRF.live.dc[id];
	HOST_Check(dc and dc.st == "form" and TRF.live.cvs and TRF.live.cvs.id == -id and TRF.live.cvs.k == 1, "convoy forms: slot rank 1 held by -n");
	for k = 1, 200 do
		T_Tick(1, 0.5);
		HOST_FireAll("f_inside", "TRF_DcAtPoint("..id..",");
		if dc.st ~= "form" then break; end;
	end;
	HOST_Check(dc.st ~= "form" and W_Count(dc.a, function(v) return v == 1; end) == dc.n, "complete convoy leaves ("..dc.st..", "..dc.n.." members)");
	TRF_Danger_BeforeJump(); V_ClearTr(); TRF.live.cvs = nil; TRF.live.dc = {};
	-- Leaves 120 s after the first arrival when a member is missing.
	id = W_DcConvoy("B");
	dc = TRF.live.dc[id];
	HOST_FireAll("f_inside", "TRF_DcAtPoint("..id..",1,");
	local t0 = TRF.clock.gt;
	local tl = nil;
	for k = 1, 300 do
		T_Tick(1, 0.5);
		if dc.st ~= "form" and not tl then tl = TRF.clock.gt - t0; end;
	end;
	HOST_Check(tl and tl >= 119 and tl <= 122, "member missing: leaves "..tostring(tl).." s after the first arrival (120)");
	TRF_Danger_BeforeJump(); V_ClearTr(); TRF.live.cvs = nil; TRF.live.dc = {};
	-- Inbound convoy (lead path A): one queue slot.
	id = W_DcConvoy("A");
	dc = id and TRF.live.dc[id];
	if dc then
		local nq = 0;
		for i = 1, getn(dc.id) do
			local r = TRF.live.tr[dc.id[i]];
			if r and HOST_Count("f_inside", "TRF_OnArrive("..dc.id[i]..",") > 0 then nq = nq + 1; end;
		end;
		HOST_Check(dc.st == "in" and nq == 1, "inbound convoy of "..getn(dc.id)..": one arrival trigger ("..nq..")");
	else
		HOST_Check(nil, "inbound convoy built");
	end;
	-- Wind-down dissolves the convoy.
	TRF_Danger_WindDown();
	T_Tick(4, 0.5);
	HOST_Check(V_N(TRF.live.dc) == 0 or (dc and dc.st ~= "form" and dc.st ~= "in"), "wind-down dissolves the convoy");
	TRF_Danger_BeforeJump(); V_ClearTr(); TRF.live.cvs = nil; TRF.live.dc = {};
	-- Slot ranking: an equipment convoy due reserves the slot; TT4 > supply > danger; a live convoy is kept.
	TRF.live.fq = {st="due"};
	HOST_Check(TRF_ConvTake(4, 0) == 1 and TRF.live.cvs.k == 4, "equipment convoy due reserves the slot (rank 4)");
	local q = W_Plan(); q.dcp = nil;
	local s0 = T_Stat("dc_skip_slot");
	local d = TRF_DcPlan(q);
	TRF_SetDis(cur, 0);
	TRF_SetPro(cur, 9);
	h.cfg.tt4 = 1;
	h.rq = {0};
	local t, why = TRF_TierPick(cur, 8, 20);
	local sp = W_Plan();
	HOST_Check(d == "single" and T_Stat("dc_skip_slot") == s0 + 1 and t ~= 4 and why == "tt4_slot" and not TRF_SupplyRoll(sp) and TRF.live.cvs.k == 4,
		"slot held by rank 4: no danger convoy, no TT4 ("..tostring(why).."), no supply conversion");
	TRF.live.fq = {st="end"};
	HOST_Check(TRF_ConvSlot() == nil, "equipment event over: slot released");
	TRF.live.fq = nil;
	h.cfg.tt4 = 0;
	local sid = T_Spawn("B") or T_Spawn("A");
	HOST_Check(TRF_ConvTake(2, sid) == 1 and TRF_ConvTake(3, 7) == nil and TRF_ConvTake(1, -8) == nil and TRF.live.cvs.id == sid,
		"a live supply convoy is never replaced (TT4 and danger refused)");
	TRF_Remove(sid, "test");
	HOST_Check(TRF.live.cvs == nil, "slot free with its holder gone");
	h.cfg.tt4 = 0;
	TRF_SetDis(cur, 4);
	-- 300 generator ticks in the danger system: never two convoys, the slot always held while one forms.
	local two, unheld = 0, 0;
	for k = 1, 300 do
		h.rq = {0, 0}; T_Gen(); h.rq = {};
		T_Tick(2, 0.5);
		HOST_FireAll("f_inside", "TRF_DcAtPoint(");
		local open = 0;
		for n, x in TRF.live.dc do if type(x) == "table" then open = open + 1; end; end;
		if open > 1 then two = two + 1; end;
		if open == 1 and not TRF.live.cvs then unheld = unheld + 1; end;
		if mod(k, 20) == 0 then V_ClearTr(); end;
	end;
	HOST_Check(two == 0 and unheld == 0, "300 ticks: never two convoys, slot held while one is open ("..two.."/"..unheld..")");
	TRF_Danger_Dump();
	HOST_Check(V_Logs("module=danger event=dump") >= 1, "danger dump line");
end;

-- l: pirate bases (spec 9) --------------------------------------------------------------------------------

function W_Base(name) return TRF_BaseOf(V_Idx(name)); end;

-- dis of idx at 9 for n legs (TRF_AddLeg after each set), the founding roll forced to rq.
function W_HoldDis(idx, n, rq)
	for i = 1, n do
		TRF_SetDis(idx, 9);
		if i == n and rq then HOST().rq = rq; end;
		TRF_AddLeg("test");
		HOST().rq = {};
	end;
end;

function T_V1_L()
	local h = HOST();
	h.labels.CurrentQuest = "5_1";
	h.st_label = "TRADE STATION";
	W_Begin("gredos", {raids=1, staged=0, seed=0, queue=0, parked=0, carriers=0, sweeps=0, feq=0, dconv=0, conv=0, tt4=0});
	local m = TRF_Map();
	local kit, xb = V_Idx("kitaro"), V_Idx("xb13");
	HOST_Check(getn(TRF_Ba_Allow()) == 6, "allow-list of 6 systems (map fixture ba = 1)");
	-- Founding: dis >= 6 on 3 legs in a row and the roll; never with the player present.
	W_HoldDis(kit, 2, nil);
	HOST_Check(W_Base("kitaro") == nil and TRF.sys[kit].bh == 2, "no founding before 3 legs (bh "..tostring(TRF.sys[kit].bh)..")");
	W_HoldDis(kit, 1, {99});
	HOST_Check(W_Base("kitaro") == nil, "roll 99: no founding");
	W_HoldDis(kit, 1, {0});
	local r = W_Base("kitaro");
	HOST_Check(r and r.k == 1 and r.h == 9, "dis >= 6 held, roll 0: P record founded");
	-- Not adjacent: a portal neighbour of a P/A record cannot found.
	local nb = TRF_Ba_Nb(kit);
	local adj = nil;
	for i = 1, getn(nb) do if TRF_BaseAllowed(nb[i]) and m.sys[nb[i]].ba == 1 then adj = nb[i]; end; end;
	-- P -> A after 2 legs at dis >= 4; news war/base.
	TRF_SetDis(kit, 9); TRF_AddLeg("test"); TRF_SetDis(kit, 9); TRF_AddLeg("test");
	r = W_Base("kitaro");
	local sl = TRF_RgOf(kit);
	HOST_Check(r and r.k == 2 and TRF.newsx[sl] and TRF.newsx[sl].war and TRF.newsx[sl].war.v == "base", "P -> A after found_delay, news war/base");
	-- The second base elsewhere, a third refused (max_bases 2).
	local al = V_Idx("altair");
	W_HoldDis(xb, 3, {0});
	W_HoldDis(al, 3, {0});
	local nlive = TRF_Ba_NLive();
	HOST_Check(nlive == 2 and W_Base("kitaro") and W_Base("xb13") and W_Base("altair") == nil, "cap: 2 bases, the third refused ("..nlive..")");
	-- Floors: decay keeps dis(base) >= 5, a neighbour >= 2; Fronn (deny entry) untouched; pro_cap 3 near it.
	TRF_SetDis(kit, 1); TRF_SetDis(V_Idx("kondel"), 0); TRF_SetDis(V_Idx("fronn"), 0);
	TRF_Decay();
	HOST_Check(TRF_Dis(kit) == 5 and TRF_Dis(V_Idx("kondel")) == 2 and TRF_Dis(V_Idx("fronn")) == 0, "floors 5 / 2, Fronn skipped");
	HOST_Check(TRF_BaseNear(V_Idx("kondel")) == kit and TRF_ProCap(V_Idx("kondel")) <= 3, "TRF_BaseNear and pro_cap 3 next to the base");
	-- Entry: station, nav point, dock, garrison by tier (<= 16 ships), triggers.
	TRF.clan[sl].sc = 60;
	TRF.clan[sl].sv = 2;
	T_Jump("kitaro");
	local st = h.objs["TRF_PBASE_"..kit] or GetObjectByLabel("TRF_PBASE_"..kit);
	HOST_Check(st and st.alive and st.model == "Pirate_station2_Lit", "station created and labelled");
	HOST_Check(getn(h.pdocks) >= 1 and GetNavPointByLabel("TRF_PBASE_NP_"..kit), "pirate dock row and nav point");
	HOST_Check(HOST_Count("died", "TRF_OnBaseDied") >= 1 and HOST_Count("attack", "TRF_OnBaseHit") >= 1 and HOST_Count("HP", "TRF_OnBaseHP") >= 1, "died / attack / HP armed");
	local ng = getn(TRF_BaseGarrison());
	HOST_Check(ng >= 3 and TRF_Ba_NShips() <= 16, "garrison "..ng.." flights, "..TRF_Ba_NShips().." ships <= 16 (tier "..TRF_EffTier(kit)..")");
	-- Raids from the base: danger 3, raid flights spawn at the base and return to it.
	HOST_Check(TRF_Rd_BaseDanger(kit, 1) == 3 and TRF_Rd_BaseDanger(V_Idx("kondel"), 0) == 2, "raid danger 3 at the base, >= 2 next to it");
	local id = T_Spawn("C") or T_Spawn("A");
	local rn = nil;
	if id then
		h.rq = {0, 0, 0, 0};
		rn = TRF_RaidRoll(id, "lane");
		h.rq = {};
		if not rn then rn = TRF.live.tr[id].rdn; end;
	end;
	local rd = rn and TRF.live.rd[rn];
	if rd and rd.st == "armed" then HOST_Fire("f_inside", "TRF_RaidGo("..rn..","); end;
	rd = rn and TRF.live.rd[rn];
	HOST_Check(rd and rd.bs == 1, "raid from the base (bs 1, st "..tostring(rd and rd.st)..")");
	-- Assault: attack -> war and wave 1, HP 40 % -> band saved, wave 2, cap 16.
	local n0 = TRF_Ba_NShips();
	HOST_Fire("attack", "TRF_OnBaseHit");
	HOST_Check(TRF.live.bs.atk and TRF.live.bs.w == 1 and TRF_Ba_NShips() > n0, "attack: wave 1 ("..n0.." -> "..TRF_Ba_NShips()..")");
	st.hp = 40000;
	HOST_Fire("HP", "TRF_OnBaseHP");
	r = W_Base("kitaro");
	HOST_Check(r.h == 4 and TRF.live.bs.w2 == 1 and TRF_Ba_NShips() <= 16, "HP band 4 saved, wave 2, ships <= 16 ("..TRF_Ba_NShips()..")");
	-- Load inside the system: triggers re-armed with the new gen, station reused.
	local g0 = TRF.gen;
	T_SaveLoad();
	local fresh = HOST_Count("died", "TRF_OnBaseDied("..kit..","..TRF.gen..")");
	HOST_Check(TRF.gen == g0 + 1 and fresh == 1 and getn(TRF_BaseGarrison()) >= 3, "load inside: died re-armed once with the new gen, garrison kept");
	-- Destroyed by the player: D, dis 0, neighbours -2, pay <= 30000, score -25, sv 0, news basex; raids break off.
	HOST_Fire("attack", "TRF_OnBaseHit("..kit..","..TRF.gen);
	local cr0, sc0 = h.credits, TRF.clan[sl].sc;
	local dk = TRF_Dis(V_Idx("kondel"));
	st.alive = nil;
	HOST_Fire("died", "TRF_OnBaseDied("..kit..","..TRF.gen);
	r = W_Base("kitaro");
	HOST_Check(r.k == 3 and TRF_Dis(kit) == 0 and TRF_Dis(V_Idx("kondel")) == max(0, dk - 2), "destroyed by the player: D record, dis 0, neighbour -2");
	HOST_Check(h.credits > cr0 and h.credits - cr0 <= 30000 and TRF.clan[sl].sc == max(0, sc0 - 25) and TRF.clan[sl].sv == 0
		and TRF.newsx[sl].war.v == "basex", "pay "..(h.credits - cr0)..", score -25, sv 0, news basex");
	-- Recovery: floors gone, D record dropped after the 20-leg cooldown, a new base can be founded.
	T_Jump("kondel");
	TRF_SetDis(kit, 1);
	TRF_Decay();
	HOST_Check(TRF_Dis(kit) <= 1, "no floor after the destruction");
	for i = 1, 21 do TRF_AddLeg("test"); end;
	HOST_Check(W_Base("kitaro") == nil, "D record dropped after the cooldown");
	-- Reconciliation rows: orphan deleted, w = 1 blown, A missing recreated.
	T_Jump("kitaro");
	local o = CreateStation("Pirate_station2_Lit", Vector3(1500, 0, 1500), Vector3(0, 0, 1));
	SetObjectLabel(o, "TRF_PBASE_"..kit);
	TRF_Base_OnActivate();
	HOST_Check(o.deleted == 1, "orphan object deleted");
	tinsert(TRF.base, {s=kit, k=3, h=0, t=TRF.clock.legs, w=1});
	local o2 = CreateStation("Pirate_station2_Lit", Vector3(1500, 0, 1500), Vector3(0, 0, 1));
	SetObjectLabel(o2, "TRF_PBASE_"..kit);
	TRF_Base_OnActivate();
	HOST_Check(o2.blown == 1 and W_Base("kitaro").w == 0, "D with w = 1: blown on entry");
	for i = getn(TRF.base), 1, -1 do if TRF.base[i].s == kit then tremove(TRF.base, i); end; end;
	-- Abandoned: an A base older than 60 legs in Bust, the player elsewhere.
	T_Jump("kondel");
	tinsert(TRF.base, {s=kit, k=2, h=9, t=TRF.clock.legs - 61, w=0});
	TRF.rg[sl].ph = 4;
	TRF_AddLeg("test");
	r = W_Base("kitaro");
	HOST_Check(r and r.k == 3 and r.w == 1 and V_Logs("by=abandon") == 1, "older than 60 legs in Bust: abandoned (D, w 1)");
	-- A sweep success off-screen: w = 1.
	for i = getn(TRF.base), 1, -1 do if TRF.base[i].s == kit then tremove(TRF.base, i); end; end;
	tinsert(TRF.base, {s=kit, k=2, h=9, t=TRF.clock.legs, w=0});
	HOST_Check(TRF_BaseDestroyed(kit, "sweep") and W_Base("kitaro").w == 1, "sweep success off-screen: D with w = 1");
	-- enabled 2 removes bases.
	TRF.base = {{s=kit, k=2, h=9, t=TRF.clock.legs, w=0}};
	h.cfg.enabled = 2;
	T_Jump("kitaro");
	local o3 = GetObjectByLabel("TRF_PBASE_"..kit);
	if not o3 then
		o3 = CreateStation("Pirate_station2_Lit", Vector3(1500, 0, 1500), Vector3(0, 0, 1));
		SetObjectLabel(o3, "TRF_PBASE_"..kit);
		TRF_Base_OnActivate();
	end;
	HOST_Check(o3.deleted == 1 and getn(TRF.base) == 0 and V_Logs("module=base event=bases_removed") >= 1, "enabled 2 removes the base");
	h.cfg.enabled = nil;
	-- Never founded in front of the player: dis held and the roll forced while the player is in the system.
	TRF.base = {};
	T_Jump("kitaro");
	W_HoldDis(kit, 4, {0});
	HOST_Check(W_Base("kitaro") == nil, "no founding while the player is in the system");
	T_Jump("kondel");
	TRF_Base_Dump();
	HOST_Check(V_Logs("module=base event=dump ") >= 1, "base dump line");
end;

-- m: localisation and the deny list (spec 10.4) -------------------------------------------------------

-- Text of file path, or nil.
function W_Read(path)
	local f = openfile(path, "r");
	if not f then return nil; end;
	local s = read(f, "*a");
	closefile(f);
	return s;
end;

function T_V1_M()
	local h = HOST();
	h.labels.CurrentQuest = "5_1";
	h.st_label = "TRADE STATION";
	W_Begin("gredos", {seed=0, staged=0, raids=0, queue=0, parked=0});
	local cur = TRF_CurIdx();
	-- Every literal key passed to a text helper (TRF_Txt, TRF_<M>Txt) in the mod scripts has EN text.
	local miss, nk, seen, ms = "", 0, {}, {};
	local files = {"trf_ui", "trf_hail", "trf_raid", "trf_region", "trf_tier", "trf_shop", "trf_gen", "trf_events", "trf_safety",
		"trf_track", "trf_supply", "trf_clan", "trf_faction", "trf_convoy", "trf_danger", "trf_base", "trf_loc"};
	for i = 1, getn(files) do
		local src = W_Read(h.dir..files[i]..".script") or "";
		gsub(src, "Txt%d?%(\"([%w_]+)\"[,%)]", function(k)
			if not %seen[k] then
				%seen[k] = 1;
				if not TRF_LocTxt(k) then tinsert(%ms, k); end;
			end;
		end);
	end;
	for k, v in seen do nk = nk + 1; end;
	for i = 1, getn(ms) do miss = miss.." "..ms[i]; end;
	HOST_Check(nk > 80 and miss == "", nk.." literal text keys, each with EN text"..miss);
	local v1k = {"seenin", "metagain", "chased", "optdemand", "dmok", "dmno", "heatoffer", "heatpaid", "heatpoor", "optsweep", "ctjoin",
		"ctbounty", "ctdone", "pooffer1", "pooffer2", "popaid", "optfeq", "feqid", "optdc", "packs", "raiders", "ArriveCarrier",
		"baseradio_war", "baseradio_trade", "rgather", "rbase", "rsalv", "rcar", "rfeq", "nwarsalv2", "nwarsalv3", "nwarbase",
		"nwarbasex", "nwarcar", "nfeqkill", "nfeqlost"};
	miss = "";
	for i = 1, getn(v1k) do if not TRF_LocTxt(v1k[i]) then miss = miss.." "..v1k[i]; end; end;
	HOST_Check(miss == "", "EN text for the 10.4 v1 keys"..miss);
	-- No key with two different texts in the TRF_Loc_TextFns tables (the merge keeps the first one); keys
	-- defined twice with the same text are the accepted list below.
	local acc = {demand=1, flee=1, clan0=1, comply=1, noname=1, fleegate=1, sos=1, thanks=1, factriada=1, fackfni=1,
		facuss=1, facvks=1, facinoco=1, seenin=1, metagain=1, chased=1, popaid=1, optdc=1, optfeq=1};
	local dt, ddiff, dsame, nsame = {}, "", "", 0;
	local tf = TRF_Loc_TextFns();
	for i = 1, getn(tf) do
		local f = getglobal(tf[i]);
		if type(f) == "function" then
			for k, v in f() do
				local nk = TRF_LocKey(k);
				local p = dt[nk];
				if not p then dt[nk] = {f=tf[i], v=v};
				elseif p.v ~= v then ddiff = ddiff.." "..nk.."("..p.f.."/"..tf[i]..")";
				else
					nsame = nsame + 1;
					if not acc[nk] then dsame = dsame.." "..nk; end;
				end;
			end;
		end;
	end;
	HOST_Check(ddiff == "", "no text key defined with two different texts"..ddiff);
	HOST_Check(dsame == "" and nsame == 19, nsame.." keys defined twice with the same text, all accepted"..dsame);
	HOST_Check(TRF_FcCtOk and TRF_Txt("ctok") == "Stay close, Wolves." and TRF_LocTxt("fctok") == "$1 command: noted, Wolves."
		and TRF_LocTxt("cvfeqkill") and TRF_LocTxt("fcoptsweep") == "Sweep contracts" and TRF_CvTxt("cvrfeq", "USS", "Gredos") == "USS is moving equipment through Gredos. Pirates will want it.", "renamed keys: fctok, fcoptsweep, cvfeqkill, cvrfeq");
	local ctl = TRF_FcCtOk(1);
	HOST_Check(type(ctl) == "string" and strfind(ctl, "^%u[%w ]+ command: noted, Wolves%.$"), "sweep accept line names the faction: "..tostring(ctl));
	-- lang ru: per-key fallback to EN; loc_mode 1: #TRF_ keys.
	TRF_H().loc = nil; h.cfg.lang = "ru";
	local ru0 = TRF_Loc_RU;
	TRF_Loc_RU = function() return {focus="RUFOCUS $1"}; end;
	HOST_Check(TRF_Loc_Lang() == "ru" and TRF_Txt("focus", "a") == "RUFOCUS a" and TRF_Txt("cease") == TRF_Loc_EN().cease, "lang ru: RU key, EN fallback per key");
	TRF_Loc_RU = ru0;
	TRF_H().loc = nil; h.cfg.lang = nil; h.cfg.loc_mode = 1;
	HOST_Check(TRF_Txt("focus", 1, 2, 3) == "#TRF_focus", "loc_mode 1: #TRF_<key>");
	TRF_H().loc = nil; h.cfg.loc_mode = nil;
	-- The generated trf_en.loc matches the EN tables (TRF_Loc_LocLines).
	local ll = TRF_Loc_LocLines();
	local lf = W_Read(h.dir.."../../../../loc/trf_en.loc");
	local fl = {};
	if lf then gsub(lf, "([^\r\n]*)\r?\n", function(x) tinsert(%fl, x); end); end;
	-- Only the generated scaffold is compared: the gen_news.py block (loc/trf_en.loc, "; sw3-traffic news records begin")
	-- follows it and is checked by gen_news.py --check.
	local cut = getn(fl);
	for i = 1, getn(fl) do if cut == getn(fl) and strfind(fl[i], "^; sw3%-traffic news records begin") then cut = i - 1; end; end;
	while cut > 0 and fl[cut] == "" do cut = cut - 1; end;
	for i = getn(fl), cut + 1, -1 do tremove(fl, i); end;
	local diff = "";
	if getn(fl) ~= getn(ll) then diff = " lines "..getn(fl).."/"..getn(ll); end;
	for i = 1, min(getn(fl), getn(ll)) do if fl[i] ~= ll[i] and strlen(diff) < 200 then diff = diff.." ["..i.."] "..fl[i].." | "..ll[i]; end; end;
	HOST_Check(lf and diff == "", "loc/trf_en.loc equals the EN tables ("..getn(ll).." lines)"..diff);
	local bad = "";
	for i = 1, getn(ll) do
		if strfind(ll[i], "[\128-\255]") then bad = bad.." "..i; end;
		if strfind(ll[i], "%$%d") then bad = bad.." $"..i; end;
	end;
	HOST_Check(ll[1] == "LOCALE_FILE" and ll[2] == "FILETYPE STANDART" and bad == "", "loc lines: header, ASCII, no $n"..bad);
	-- qi fixtures: denied while one id is QUEST_PROCESS, allowed when none, the v0.2 rule without ids.
	local sy = TRF_Map().sys[cur];
	sy.qi = {"quest_hostA", "quest_hostB"};
	TRF.live.qa = nil; TRF.live.qai = nil; TRF_H().loc = nil;
	h.qs = TRUE;
	HOST_Check(TRF_QuestActive(cur) == 0 and TRF_StrictOk(cur, "seed") == 1, "ids, none in process: open during a mission");
	h.quests.quest_hostB = QUEST_PROCESS;
	TRF.live.qa = nil; TRF.live.qai = nil; TRF_H().loc = nil;
	h.qs = FALSE;
	local ok, why = TRF_StrictOk(cur, "seed");
	HOST_Check(TRF_QuestActive(cur) == 1 and not ok and why == "quest", "one id in process: denied ("..tostring(why)..")");
	h.quests = {};
	sy.qi = nil;
	-- A q system without ids (the campaign pass found none): the v0.2 rule.
	local qids = TRF_SafeQIds;
	TRF_SafeQIds = function(i, x) return nil; end;
	local dq = TRF_DenyQ;
	TRF_DenyQ = function(i) return nil; end;
	TRF.live.qa = nil; TRF.live.qai = nil; TRF_H().loc = nil;
	h.qs = TRUE;
	local a, wa = TRF_StrictOk(cur, "seed");
	h.qs = FALSE;
	TRF.live.qa = nil; TRF.live.qai = nil; TRF_H().loc = nil;
	local b = TRF_StrictOk(cur, "seed");
	TRF_SafeQIds = qids; TRF_DenyQ = dq;
	TRF.live.qa = nil; TRF.live.qai = nil; TRF_H().loc = nil;
	HOST_Check(not a and b == 1, "q system without ids: v0.2 rule, denied during a mission only ("..tostring(wa)..")");
	-- Fronn never hosts an equipment convoy, a danger convoy or a base.
	local fr = V_Idx("fronn");
	local e = TRF_DenyEntry("fronn");
	HOST_Check(e and e.feq == 0 and e.dconv == 0 and e.base == 0, "deny entry: Fronn feq 0, dconv 0, base 0");
	W_SideTeams();
	TRF_SetPro(fr, 9);
	local cs = TRF_CvFeqCand(nil);
	local hit = nil;
	for i = 1, getn(cs) do if cs[i][1] == fr then hit = 1; end; end;
	TRF_SetDis(fr, 9);
	HOST_Check(not hit and not TRF_DcGate(fr) and not TRF_BaseAllowed(fr), "Fronn: no equipment convoy candidate, no danger convoy gate, no base site");
	-- Transit rule for targets (trf_safety TRF_StrictOkOf): taira (teleport target, tq) during a mission with no
	-- taira quest in process is eligible for carrier, feq, offer, base and raid; quest 6c_01 in process closes
	-- it (deny_tq); elio (authored m = 1) stays denied (deny).
	local ta, el = V_Idx("taira"), V_Idx("elio");
	local te, ee = TRF_DenyEntry("taira"), TRF_DenyEntry("elio");
	local dh = {TRF_Cl_DenyM, TRF_CvDenyM, TRF_FcDenyM, TRF_Ba_DenyM, TRF_Rd_DenyM};
	local df = {"carrier", "feq", "offer", "base", "raid"};
	local qr = function() TRF.live.qa = nil; TRF.live.qai = nil; TRF_H().loc = nil; end;
	h.qs = TRUE; qr();
	local n1, n2, n3 = 0, 0, 0;
	for i = 1, getn(dh) do
		if dh[i](ta, te, df[i]) == nil then n1 = n1 + 1; end;
		if dh[i](el, ee, df[i]) == "deny" then n2 = n2 + 1; end;
	end;
	HOST_Check(te.tq == 1 and n1 == getn(dh) and n2 == getn(dh) and not TRF_Ba_Skip(ta) and TRF_Ba_Skip(el) == 1,
		"transit: taira (tq, qa 0) eligible "..n1.."/"..getn(dh)..", elio (authored) denied "..n2.."/"..getn(dh));
	h.quests.quest_6c_01 = QUEST_PROCESS; qr();
	for i = 1, getn(dh) do if dh[i](ta, te, df[i]) == "deny_tq" then n3 = n3 + 1; end; end;
	HOST_Check(n3 == getn(dh) and TRF_Ba_Skip(ta) == 1, "transit: taira quest 6c_01 in process -> deny_tq "..n3.."/"..getn(dh));
	h.quests.quest_6c_01 = nil; qr();
	-- Danger convoy gate in the current system: taira open during a mission, deny_tq with its quest, elio deny.
	T_Jump("taira");
	local g1, w1 = TRF_DcGate(TRF_CurIdx());
	h.quests.quest_6c_01 = QUEST_PROCESS; qr();
	local g2, w2 = TRF_DcGate(TRF_CurIdx());
	h.quests.quest_6c_01 = nil; h.qs = FALSE; qr();
	T_Jump("elio");
	local g3, w3 = TRF_DcGate(TRF_CurIdx());
	HOST_Check(g1 == 1 and not g2 and w2 == "deny_tq" and not g3 and w3 == "deny",
		"transit: danger convoy gate taira "..tostring(w1)..", with its quest "..tostring(w2)..", elio "..tostring(w3));
	TRF_Loc_Dump();
	HOST_Check(V_Logs("module=loc event=dump") >= 1, "loc dump line");
end;

-- n: 200 legs with everything on, nobody-wins clamps, save size and lint (spec 3.4, 4.7, 8.3) -----------

-- Max over slots of the faction digits and the clan scores after pushing for n legs with f(leg) each leg.
function W_Push(n, f)
	local m = TRF_RgMap();
	local hi = {};
	local R = {maxhi=0, fsmin=9, fsmax=0, scmin=99, scmax=0, ph={}};
	for s = 1, m.n do hi[s] = 0; R.ph[s] = {}; end;
	for leg = 1, n do
		TRF_AddLeg("test");
		V_NewVisit();
		TRF.live.fsv = 0; TRF.live.fstv = nil;
		if f then f(leg); end;
		for s = 1, m.n do
			local sc = TRF_ClanScore(s);
			if sc >= 75 then hi[s] = hi[s] + 1; else hi[s] = 0; end;
			if hi[s] > R.maxhi then R.maxhi = hi[s]; end;
			R.ph[s][TRF_Phase(s)] = 1;
			for fi = 1, 5 do local v = TRF_Fs(s, fi); if v < R.fsmin then R.fsmin = v; end; if v > R.fsmax then R.fsmax = v; end; end;
			if sc < R.scmin then R.scmin = sc; end;
			if sc > R.scmax then R.scmax = sc; end;
		end;
	end;
	return R;
end;

-- Mean faction digit over every slot and faction.
function W_FsMean()
	local m, t, n = TRF_RgMap(), 0, 0;
	for s = 1, m.n do for fi = 1, 5 do t = t + TRF_Fs(s, fi); n = n + 1; end; end;
	return t / n;
end;

function W_ScMean()
	local m, t = TRF_RgMap(), 0;
	for s = 1, m.n do t = t + TRF_ClanScore(s); end;
	return t / m.n;
end;

function T_V1_N()
	local h = HOST();
	h.labels.CurrentQuest = "5_1";
	h.st_label = "TRADE STATION";
	W_Begin("gredos", {log=1, seed=0, staged=0, queue=0});
	W_SideTeams();
	-- 200 legs of the v02 4.7 cycle with every v1 tick on and forced Busts from scripted kills.
	h.logs = nil;
	local add0 = TRF_AddLeg;
	TRF_AddLeg = function(w)
		local f = %add0;
		f(w);
		local L = TRF.clock.legs;
		if mod(L, 23) == 0 then
			local m = TRF_RgMap();
			local s = 1 + mod(floor(L / 23), m.n);
			TRF_ForcedBust(m[s].home, "test");
			HOST().nfb = (HOST().nfb or 0) + 1;
		end;
	end;
	local R = V_Run200("5_1", "v1-n");
	TRF_AddLeg = add0;
	print("HOST info forced Bust calls "..(h.nfb or 0).."; coverage: legs without Boom, Build-up/Raids or Bust/Recovery "..R.miss.." of 200");
	-- A forced Bust cuts Quiet, Boom or Build-up short (8.3, accepted), so only the maxima are checked here.
	HOST_Check(R.over <= TRF_RgTune().rg_hold and R.frozen == 0, "every phase ends by mx + rg_hold (max "..R.over.." past mx), none frozen");
	print("HOST info phase lengths outside mn..mx + rg_hold (forced Busts cut phases short):"..R.lenmsg);
	HOST_Check(R.maxhi <= 18, "no region at score >= 75 for more than 18 legs ("..R.maxhi..")");
	HOST_Check(R.rqmin >= 2 and R.allph and R.gap <= 120, "every region in every phase, Recovery -> Quiet >= 2 ("..R.rqmin.."), within 120 legs ("..R.gap..")");
	HOST_Check(R.miss <= 6 and R.pair <= 25, "phase groups present (miss "..R.miss.." <= 6 with forced Busts), pair run "..R.pair.." <= 25");
	-- Nobody wins: push the factions down for 300 legs (every slot fs -1 per leg); the clans stay bounded,
	-- the factions recover to fs0 after the push.
	local m = TRF_RgMap();
	local D = W_Push(300, function(leg)
		local mm = TRF_RgMap();
		for s = 1, mm.n do for fi = 1, 5 do TRF_FsAdd(s, fi, -1, "push"); end; end;
	end);
	HOST_Check(D.fsmin == 0 and D.maxhi <= 18, "factions pushed down 300 legs: fs clamps at 0, clans still never >= 75 for > 18 legs ("..D.maxhi..")");
	local A = W_Push(60, nil);
	local fm = W_FsMean();
	HOST_Check(fm >= 2.5 and fm <= 3.5, "after the push: factions drift back to fs0 3 (mean "..format("%.2f", fm)..")");
	-- Push the clans down for 300 legs (score -6 per visit); the phases keep cycling, the clans recover.
	local P = W_Push(300, function(leg)
		local mm = TRF_RgMap();
		for s = 1, mm.n do TRF_ClanAdd(s, -6, "push"); end;
	end);
	local cyc, phs = 1, "";
	for s = 1, m.n do local np = 0; for k, v in P.ph[s] do np = np + 1; end; phs = phs.." "..np; if np < 4 then cyc = nil; end; end;
	HOST_Check(cyc, "clans pushed down 300 legs: every region still cycles (phases seen per region:"..phs..")");
	local B = W_Push(120, nil);
	HOST_Check(B.scmax >= 50 and B.fsmax <= 9, "after the push: clans regain score (max "..B.scmax..")");
	-- Push the clans up (score +3 per visit) for 300 legs: sweeps cap them (<= 18 legs at >= 75).
	local U = W_Push(300, function(leg)
		local mm = TRF_RgMap();
		for s = 1, mm.n do TRF_ClanAdd(s, 3, "push"); end;
	end);
	-- 18 legs (v02 4.4) plus one 2-leg region tick: the push crosses 75 between ticks, the schedule starts at the next.
	HOST_Check(U.maxhi <= 18 + 2 and U.scmin < 50, "clans pushed up 300 legs: >= 75 for at most "..U.maxhi.." legs (18 + one tick), sweeps still win (min "..U.scmin..")");
	h.logs = {};
	print("HOST info typical TRF save size after the runs: "..(8 + 3 + HOST_SaveSize(TRF)).." bytes");
	-- Scripted player events on screen: a TT4 kill and an equipment convoy kill (forced Bust bit each).
	local cur = TRF_CurIdx();
	TRF_SetDis(cur, 0);
	TRF_SetPro(cur, 9);
	local tp0 = TRF_TierPick;
	TRF_TierPick = function() return 4, "test"; end;
	local tid = T_Spawn("B");
	TRF_TierPick = tp0;
	if tid then TRF.live.tr[tid].cnt = 1; W_KillTr(tid); T_Tick(2, 0.5); end;
	HOST_Check(tid and TRF_Bit(TRF.rg[TRF_RgOf(cur)].ct, 4) == 1, "TT4 kill on screen: forced Bust bit");
	-- Worst case of 3.4 on top of the v02-n state: every bound filled.
	for i = 1, getn(TRF_Map().sys) do TRF_SetDis(i, 1 + mod(i, 8)); if TRF_ProCap(i) > 0 then TRF_SetPro(i, TRF_ProCap(i)); end; end;
	TRF_SetDis(cur, 0);
	TRF.short = {};
	-- pk on every entry (player-caused, design/wb-plumbing-spec.md 11).
	for i = 1, 9 do TRF_ShortAdd(i * 3, 1 + mod(i, 6), TRF.clock.legs + 6, 1); end;
	TRF.shops = {};
	for i = 1, 8 do tinsert(TRF.shops, {s=i * 3, sh=TRF_SysName(i * 3), c=1 + mod(i, 6)}); end;
	TRF.std.help = 15; TRF.std.heat = 2;
	TRF_NewsPost("heat", "5"); TRF_NewsPost("help", "15"); TRF_NewsPost("short", "on");
	for sl = 1, m.n do
		foreachi({"lane", "trade", "pir", "sweep"}, function(i, t) TRF_NewsPost(t, "raid", %sl); end);
		TRF_NewsPost("war", "salv3_3", sl);
		TRF.rg[sl].ct = 7; TRF.rg[sl].sr = 2;
		TRF.clan[sl].sv = 9; TRF.clan[sl].sf = 5;
		TRF.fs[sl] = "98765";
	end;
	TRF_NewsPost("feq", "kill_1");
	for k = 1, 5 do TRF.tsh[k] = 2; end;
	TRF.std.fst = "12345";
	TRF.tp = {};
	for k = 1, 16 do
		TRF_TkPut({id=9000 + k, nm=99, o=0, c=6, tt=4, pw=20, n=99, e=6, s=100 + k, fr=100 + k, d=2, dm=3, fl=63, t=TRF.clock.legs});
	end;
	TRF.lr = {{s=1, t=100, e=TRF.clock.legs + 6}, {s=2, t=101, e=TRF.clock.legs + 6}};
	TRF.base = {};
	local al = TRF_Ba_Allow();
	for k = 1, 4 do tinsert(TRF.base, {s=al[k], k=1 + mod(k, 3), h=9, t=TRF.clock.legs, w=1}); end;
	for k = 1, getn(TRF_Map().sys) do if TRF_Map().sys[k].ba == 1 then TRF_Tab(TRF.sys, k).bh = 3; end; end;
	TRF.feq = {k=1, f=5, s=113, r=3, t=TRF.clock.legs, a=1};
	TRF.offer = {k=3, s=113, t=TRF.clock.legs + 8, p=30000};
	-- Traders up to the caps with the v02 fields and the 4 v1 fields; 8 gone records.
	for k = 1, 12 do
		local id = T_Spawn();
		if id then TRF_Remove(id, "test"); end;
		h.gt = h.gt + 1;
		TRF.live.port = {};
	end;
	TRF_LivePrune();
	local ids = {};
	for k = 1, 40 do
		local id = T_Spawn();
		if id then tinsert(ids, id); end;
		TRF.live.port = {};
	end;
	-- Copies come from a TT3 record: one convoy slot, so at most one TT4 record is open (8.6).
	local one = ids[1];
	for k = 1, getn(ids) do if (TRF.live.tr[ids[k]].tier or 1) == 3 then one = ids[k]; end; end;
	for k = 1, getn(ids) do
		local r = TRF.live.tr[ids[k]];
		r.fs = {1, 2, 3, 4, 5}; r.ha = 99999; r.hn = 1; r.hlt = 10; r.trd = 1; r.hd = 1; r.tu = 1; r.bm = 1;
		r.tb = 3; r.pi = 9999; r.cv = 9999; r.xt = 99999.5;
	end;
	local nlive = function()
		local c = 0;
		for id, r in TRF.live.tr do if r.st ~= "gone" then c = c + 1; end; end;
		return c;
	end;
	local n = 0;
	while nlive() < 8 do
		n = n + 1;
		local c = {};
		for k, v in TRF.live.tr[one] do c[k] = v; end;
		c.id = 9000 + n;
		TRF.live.tr[c.id] = c;
	end;
	-- Visit records at full size (3.2).
	local L = TRF.live;
	L.cvs = {k=4, id=9999};
	L.tq = {{i=9001, h="chase", j=1, id=9001, pw=20, fl=63, fr=113, tt=4}, {i=9002, h="port", j=2, id=9002, pw=20, fl=63, fr=113, tt=4};
		d=1, w={{id=9001, x=99999.5}, {id=9002, x=99999.5}}, m=1};
	L.sw = {s=8, k=4, st="on", t=99999.5, roll=2, nf=14, nc=8, kf=13, kc=7, hit=9, f=5, t0=99999.5, to=99999.5, pk=9, wv=4, r=3, nw=4};
	L.fq = {n=9999, id=9999, f=5, r=3, st="live", t0=99999.5, atk=99999.5, w1=99999.5, w2=99999.5, hp0=99999, raid=1, ct=30000};
	L.cr = {i=2, n=9999, st="hold", t=99999.5, w=2, lt=99999.5, hp0=99999, hit=1};
	L.dc = {}; L.dc[9999] = {id={9997, 9998, 9999}, a={1, 1, 1}, st="form", t0=99999.5, n=3, ns=3, e=5, ct=30000, ok=3, m=1, k=9, ld=9999};
	L.bs = {s=113, atk=99999.5, w=1, w2=1};
	L.pg = {};
	for k = 1, 8 do tinsert(L.pg, {n=9999, k=2, sv=1, st="on"}); end;
	L.fsv = 2; L.fstv = {1, 1, 1, 1, 1};
	-- Worldbuilding plumbing at its bounds (design/wb-plumbing-spec.md 12): one job of 6 fields of 24
	-- characters, 8 markers with 24-character labels and 8-character owners, every visit slot, the clocks.
	TRF.job = nil;
	local jf = {};
	for k = 1, 6 do jf["f"..k] = strrep("x", 24); end;
	HOST_Check(TRF_JobTake(5, jf) == 1, "plumb worst case: job taken");
	TRF.mk = "";
	for k = 1, 8 do TRF.mk = TRF.mk.."TRF_"..strrep("m", 19)..k.."="..strrep("o", 8)..";"; end;
	L.box = "dock_patrol"; L.bt = 99999.5; L.ev = "vendetta"; L.esc = "mercpack"; L.arq = 3; L.ag = 99999.5; L.bkd = ",join,bounty,";
	TRF.clock.j = 99999; TRF.clock.rs = 999999.5; TRF.clock.vl = 3; TRF.std.ht = 99999;
	TRF.clock.vc = 1;
	-- Station voices worst case (station-voices-spec 3.4, 17.7): 76 trade-station keys (the D4 cap) with a full record, every
	-- transferable system with an owner change, the visit stamp.
	TRF.stn = {};
	local skl = TRF.clock.legs;
	local skn = 0;
	for sk, sv in TRF_StnKeys() do
		if skn < 76 then TRF.stn[sk] = {st=-3, lg=skl, gv=skl, bv=skl, pv=skl, tf=skl, ts=42, nt=1, ec=skl}; skn = skn + 1; end;
	end;
	TRF.vo = {};
	for sn, so in TRF_StnOwners() do if V_Idx(sn) then TRF.vo[V_Idx(sn)] = skl; end; end;
	TRF.ve = skl;
	-- Survivors worst case (design/survivors-spec.md 3.4): 4 full records, carried survivors, totals, every region
	-- budget, 16 cooldown stamps, 4 silent systems, the rumour.
	TRF.sv = {b={}, c={n=6, cr=180000, pc=180000, s1=113, s2=112, f=5, lg=skl}, st={res=9999, sold=9999, lost=9999}, r={}, sd=9999,
		hl=skl, cd={}, x={110, 111, 112, 113}, rm={s=113, k=2, lg=skl}};
	for k = 1, 4 do
		tinsert(TRF.sv.b, {s=109 + k, si=1139, x=-99999, y=-99999, z=-99999, n=3, n0=3, f=5, nm=99, lg=skl, src=3, sl=2, pf=10000, pp=10000, bx=1});
	end;
	for k = 1, 11 do TRF.sv.r[k] = 9; end;
	for k = 1, 16 do TRF.sv.cd[97 + k] = skl; end;
	-- Faction ladder worst case (design/ladder-spec.md 3.3): 2 x 11 permits, every stamp, the step 2 fields.
	TRF.lad = {lic={{}, {}}, pg={skl, skl}, hc={skl, skl, skl, skl, skl}, sc={skl, skl, skl, skl, skl}, eb=skl,
		w={f=5, sys=113, till=skl, n=4}, wc=skl, wr=999999.5, pat=5};
	for k = 1, 11 do TRF.lad.lic[1][k] = skl; TRF.lad.lic[2][k] = skl; end;
	-- Charter goals worst case (design/charter-spec.md 3.3): 3 postings with every field, 11 stamps each in rs, rb and pk.
	TRF.ch = {on=1, rk=3, rp=99, du=skl, pt=999999999, lh={16, 16, 16}, vd=9, vb=1, sd=2147483646, cnt=9999, g={}, cd={skl, skl, skl},
		rs={}, rb={}, pk={}, tot={d=9999, f=9999, w=9999}, nw=5, hx=1};
	for k = 1, 3 do
		TRF.ch.g[k] = {t=6, r=11, f=5, d=5, k=3, p=3, w=1, a=skl, e=skl, st=3, pay=30000, rq=3, l=16, c="deadline"};
	end;
	for k = 1, 11 do TRF.ch.rs[k] = skl; TRF.ch.rb[k] = skl; TRF.ch.pk[k] = skl; end;
	-- Battle scars worst case (design/scar-spec.md 3.3): 12 records with every field at its widest, the step 2 fields
	-- (3 carried recorders, 2 payout stamps, the licence leg, bsc and bsh in every region), sk in every system, 12 scd stamps.
	TRF.scar = {};
	for k = 1, 12 do
		tinsert(TRF.scar, {sys=100 + k, k=9, kind=5, fac=5, x=-99999, y=-99999, z=-99999, leg=skl, ttl=30, on=1, mine=1, lv=4, seed=9999, nd=4,
			st=3, hid=1, scv=4, rec=1, nm=40, rf=1});
	end;
	TRF.std.slog = {};
	for k = 1, 3 do tinsert(TRF.std.slog, {sid=1139, sys=113, leg=skl, pay=30000}); end;
	TRF.std.rpay = {skl, skl};
	TRF.std.lic = skl;
	for k, rr in TRF.rg do if type(rr) == "table" then rr.bsc = skl; rr.bsh = skl; end; end;
	if type(TRF.sys) ~= "table" then TRF.sys = {}; end;
	for k = 1, getn(TRF_Map().sys) do
		if type(TRF.sys[k]) ~= "table" then TRF.sys[k] = {}; end;
		TRF.sys[k].sk = 9;
		if k <= 12 then TRF.sys[k].scd = skl + 4; end;
	end;
	-- Wanted captains worst case (design/captain-spec.md 3.3): 11 records with every field at its widest, 3 claims, the
	-- chase record, capg and the prize stamp.
	TRF.cap = {};
	for k = 1, 11 do
		TRF.cap[k] = {nm=24, gen=999, st=6, tp=5, esc=3, noto=3, gr=9, gr_t=-99999, seen=113, due=99999, lj=99999, dj=99999, born=-99999,
			met=1, last=113, ti=-99999, pv=24, q=3, ql=-99999};
	end;
	TRF.claim = {};
	for k = 1, 3 do tinsert(TRF.claim, {slot=11, gen=999, nm=24, amt=30000, kind=2, leg=-99999}); end;
	TRF.capch = {slot=11, to=113, hpb=10, leg=-99999, wn=6, cg=999};
	TRF.capg = {lc=99999, vn=11};
	TRF.clock.pz = 99999;
	-- Clan stashes worst case (design/stash-spec.md 3.3): 4 records with every field at its widest, stx with every
	-- field, so and sk in every clan record.
	TRF.stash = {};
	for k = 1, 4 do TRF.stash[k] = {sys=113, slot=4, clan=11, cls=3, v=450, seed=9999, leg=-99999, st=2, src=4, sf=11, sv=5, rf=2, pl=1}; end;
	TRF.stx = {n=9999, op=9999, opp=9999, lc=-99999, jc=99999, lo=-99999, jo=99999, pt={{f=5, s=113}, {f=5, s=113}}, ms=113, mc=11};
	for k, cc in TRF.clan do if type(cc) == "table" then cc.so = 1; cc.sk = -99999; end; end;
	-- Wolves Freight worst case (design/freight-spec.md 3.3): three ship records (the step 2 slots) with every field, four
	-- log entries with the first-loss flag, decl.
	TRF.co = {seq=99, bal=30000, vn=99999999, pg=99999999, rt=-99999, lk=-99999, vch=2000000, owe=30000, lost=99, decl={sys=113, leg=-99999},
		log={}, ships={}};
	for k = 1, 4 do TRF.co.log[k] = {k=2, s=99, nm=40, sys=113, leg=-99999, f=1}; end;
	for k = 1, 3 do
		TRF.co.ships[k] = {id=97 + k, nm=40, hull=3, rg=k, home=113, p=50, w=1, k=99999999, run=30000, st=2, till=99999999, cov=99999999,
			dmg=3, rs=2147483646, price=99999999, earned=99999999, sk=99999999, ek=99999999};
	end;
	-- Dynamic nests worst case (design/nest-spec.md 3.3): a memory record in each of the 56 nest systems (every
	-- system of the table but X297 and El Ariash) at its widest, a 31-flight visit, the counters at the cap, nk, nl
	-- and ns in every clan record.
	TRF.nest = {};
	for nm, e in TRF_NestData() do
		if nm ~= "x297" and nm ~= "el_ariash" then TRF.nest[V_Idx(nm)] = {k=getn(e.f), l=-99999, c=1}; end;
	end;
	TRF.nv = {i=94, b=strrep("1", 31)};
	TRF.nst = {n=99999, k=99999, p=99999};
	for k, cc in TRF.clan do if type(cc) == "table" then cc.nk = 99; cc.nl = 7; cc.ns = 113; end; end;
	-- Sealed parcels worst case (design/parcel-spec.md 3.3): TRF.pcl with every field at its widest and the step 2 fields
	-- (xl in every region slot, cfl), the job flag on every shortage entry; the packed job is within the plumbing's
	-- 6-field job above.
	TRF.pcl = {ok=999, fail=999, je=99999, ban=skl + 200, lsys=113, lleg=-99999, lok=1, lt=1, pm=4, pr=60000, ow=999999, pq=1,
		ll=skl, lit=4, xl={}, cfl={skl, skl, skl, skl, skl}};
	for k = 1, 11 do TRF.pcl.xl[k] = skl; end;
	for k = 1, getn(TRF.short) do TRF.short[k].job = 1; end;
	-- Mercenary clans worst case (design/merc-spec.md 3.3): every clan with every packed field at its widest bound, a hire
	-- record with 8 band digits, the call, the blacklist, the note, the elite record, the Wolves ratings and their stamp.
	TRF.mc = {s=TRF_McDefS(), t={}};
	local mtb = TRF_McTB();
	for c = 1, 12 do
		local r = {};
		for k, b in mtb do if b[1] < 0 then r[k] = b[1]; else r[k] = b[2]; end; end;
		TRF_McPutT(c, r);
	end;
	TRF.mc.h = TRF_TpPackK({c=12, sys=113, ty=2, pw=20, n=7, tr=660, fee=30000, sh=999999, bm=999999, k=99, lo=7, g=99999}, TRF_McHKeys());
	TRF.mc.hb = "99999991";
	TRF.mc.r = TRF_TpPackK({c=12, ej=-9999999, lj=-9999999}, TRF_McRKeys());
	TRF.mc.n = TRF_TpPackK({c=12, a=9999999}, TRF_McNKeys());
	TRF.mc.e = TRF_TpPackK({el=8, dj1=9999999, dc1=20, djl=9999999, dn=1}, TRF_McEKeys());
	TRF.mc.x = 9999999; TRF.mc.w = strrep("9", 11); TRF.mc.wt = -9999999;
	local mcz = HOST_SaveSize(TRF.mc);
	TRF_Mc_Fix();
	HOST_Check(HOST_SaveSize(TRF.mc) == mcz and mcz <= 6000, "merc worst case kept by the repair: "..mcz.." bytes <= 6000");
	-- Raids, due and stat at their bounds.
	for k = 1, 10 do
		local id = ids[1 + mod(k, getn(ids))];
		local r = TRF.live.tr[id];
		if r then
			for q, rd in TRF.live.rd do if rd.st ~= "end" then TRF_Rd_End(q, "cancel"); end; end;
			r.rdn = nil;
			local rn = V_Raid(id);
			if rn then TRF_Rd_End(rn, "cancel"); end;
		end;
	end;
	TRF_Raid_Step();
	TRF_H().due = {};
	for i = 1, 32 do TRF_Due(500 + i, "TRF_HostNoop", i, "x"); end;
	for i = 1, 140 do TRF_Stat("k"..i); end;
	TRF.live.hl = {id=one, g=TRF.gen, o={"trade", "head", "news", "esc", "trouble", "boom"}, k=3, t=10, w="menu"};
	TRF.live.ct = {id=one, n=30000, t=10};
	TRF.live.board = TRF_Trouble(cur).."\n"..TRF_Boom(cur);
	-- Bounds of 3.4.
	HOST_Check(getn(TRF.tp) <= 16 and getn(TRF.lr) <= 2 and getn(TRF.base) <= 4 and getn(L.pg) <= 8 and V_N(L.dc) <= 1
		and V_N(L.stat) <= 49 and getn(TRF_H().due) == 32 and L.due == nil, "bounds: tp 16, lr 2, base 4, pg 8, dc 1, stat 48 (+other), due 32 in H, not saved (stat "..V_N(L.stat)..")");
	local size = 8 + 3 + HOST_SaveSize(TRF);
	local parts, pl = "", {"sys", "rg", "clan", "short", "shops", "news", "newsx", "fs", "tp", "lr", "base", "feq", "offer", "std", "stn", "vo", "sv", "lad", "ch", "scar",
		"cap", "claim", "capch", "capg", "stash", "stx", "co", "nest", "nv", "nst", "pcl", "mc", "live"};
	for i = 1, getn(pl) do parts = parts.." "..pl[i].."="..HOST_SaveSize(TRF[pl[i]]); end;
	local lp, ll = "", {"tr", "stat", "rd", "cvs", "tq", "sw", "fq", "cr", "dc", "bs", "pg"};
	for i = 1, getn(ll) do lp = lp.." "..ll[i].."="..HOST_SaveSize(L[ll[i]]); end;
	print("HOST info TRF save size "..size.." bytes:"..parts.." | live:"..lp);
	for id, r in L.tr do
		local ks = "";
		for k, v in r do ks = ks.." "..k.."="..HOST_SaveSize(v); end;
		print("HOST info tr "..id.." "..r.st.." "..HOST_SaveSize(r)..":"..ks);
	end;
	HOST_Check(size <= 100000, "full-state TRF after 200 legs, everything on: "..size.." bytes <= 100000 (spec 3.4)");
	HOST_Check(HOST_Reserved(TRF, "TRF") == "", "no reserved key anywhere in TRF");
	-- Load: only functions and TRF are globals of the mod; no handle globals left.
	T_SaveLoad();
	HOST_Check(V_DataGlobals() == "", "after a load: no TRF_ data globals, no build globals"..V_DataGlobals());
	local tg = "";
	for k, v in globals() do
		if type(k) == "string" and not T_HandleOk(k) and (strfind(k, "^TRF_G") and type(v) ~= "function" or strfind(k, "^flight_trf_")) then tg = tg.." "..k; end;
	end;
	HOST_Check(tg == "", "no TRF_G* or flight_trf_* globals"..tg);
	TRF_DumpState("test");
	local dl = {"module=state event=dump_v4 ", "module=track event=dump", "module=faction event=dump", "module=clan event=dump", "module=convoy event=dump", "module=danger event=dump", "module=supply event=dump", "module=base event=dump", "module=loc event=dump", "module=scar event=dump ",
		"module=captain event=dump ", "module=stash event=dump ", "module=freight event=dump ", "module=nest event=dump ", "module=parcel event=dump ", "module=merc event=dump "};
	local md = "";
	for i = 1, getn(dl) do if V_Logs(dl[i]) == 0 then md = md.." "..dl[i]; end; end;
	HOST_Check(md == "", "TRF_DumpState calls every v1 dump"..md);
end;

-- Dispatch ---------------------------------------------------------------------------------

local fn = getglobal("T_V1_"..strupper(strsub(HOST().scen, 4)));
if type(fn) == "function" then
	fn();
	HOST_Check(T_LeftGlobals() == "", "no handle globals left at the end"..T_LeftGlobals());
else
	HOST_Check(nil, "unknown scenario "..tostring(HOST().scen));
end;
