-- Dynamic nests scenarios (design/nest-spec.md 9) under stock Lua 4.0.1: TRF_NE=a..f, run by run_host.sh as its own
-- entry point. a registration, toggles, tune, the static table (58 systems, 547 flights, pins) and the pure rules (plan
-- per phase and tier, pins, caches, refill, lines), b the wrapper at entry (substituted flights in TRF_Nest_1 with the
-- nest power and the vanilla globals, stubs, pinned signs, pass-through of quest and unlisted calls, conditional
-- signs, Pandora's gone flights, the arrival line, nest_mode 2), c pass-through and gates (nest 0, the X297 and El
-- Ariash denies, nest_off, the chapter guard, sys_off, an in-process quest, a system without data), d kill memory and
-- feeds (died, mine, clan score, dis, nk, scars, the last flight, refill at the region step, the Hurt and Clear lines,
-- stale triggers, the ship-level fallback, the pirate watch, the relation mirror, sweeps), e jump delete, orphan delete,
-- nest_keep_on_jump, load re-arm, f repair, dump, the ship-cap group, the save bound.
-- Loads host_station.lua up to its first scenario, as host_stash.lua does. Stub added in host_stubs.lua: NewPirateFlight
-- and NewPiratesFlight (Create_flight_2.script 671-689) in HOST_Includes.

local f = openfile((getenv("TRF_TESTS") or "./").."host_station.lua", "r");
if not f then print("HOST FAIL host_nest.lua: cannot open host_station.lua"); exit(1); end;
local src = read(f, "*a");
closefile(f);
local cut = strfind(src, "\n-- a: install (12.1, 6.1)", 1, 1);
if not cut then print("HOST FAIL host_nest.lua: marker '-- a: install (12.1, 6.1)' missing in host_station.lua"); exit(1); end;
dostring(strsub(src, 1, cut), "host_station.lua");

-- Helpers ----------------------------------------------------------------------------------

-- Config of these runs: the repo defaults with nests on, the entry events and the other worldbuilding features off,
-- log 2, plus t.
function NE_Cfg(t)
	local c = {nest=1, cap_enable=0, sweeps=0, sweep_ct=0, feq=0, staged=0, seed=0, queue=0, parked=0, voice_events=0,
		dconv=0, carriers=0, po=0, enable_survivors=0, lad_enabled=0, enable_stashes=0, enable_freight=0, charter=0, log=2, tune={}};
	if t then for k, v in t do c[k] = v; end; end;
	return c;
end;

function NE_Set(k, v) HOST().cfg[k] = v; end;

function NE_Tune(k, v)
	local h = HOST();
	local o = {};
	for a, b in h.cfg.tune do o[a] = b; end;
	o[k] = v;
	h.cfg.tune = o;
end;

-- Scenario start in sys (not a nest system) at chapter label ch; every region in phase ph (default Build-up) with clan
-- score sc (default 62, T3), no sweep, no nest state.
function NE_Begin(sys, ch, t)
	local h = HOST();
	h.labels.CurrentQuest = ch or "9_1";
	h.quests = {}; h.qlog = {};
	h.qs = FALSE;
	h.rel_team = nil;
	S_Begin(sys or "gaoba", NE_Cfg(t));
	for s = 1, TRF_RgMap().n do NE_Phase(s, 2, 62); end;
	TRF.nest = nil; TRF.nv = nil; TRF.nst = nil;
end;

function NE_Phase(slot, ph, sc)
	local rg = TRF.rg[slot];
	rg.ph = ph; rg.pt = TRF.clock.legs; rg.sl = 0; rg.sn = 0; rg.sw = 0; rg.sr = nil;
	local c = TRF.clan[slot];
	if sc then c.sc = sc; end;
	c.nk = nil; c.nl = nil; c.ns = nil;
end;

function NE_Slot(name) return TRF_RgOf(V_Idx(name)); end;
function NE_Data(name) return TRF_NeData(name); end;
function NE_V() return TRF_NeNE().v; end;

-- The vanilla activate.script of system nm reduced to its pirate part (design 6): the Pirates team and the vanilla
-- group with the team relation toward the player, every static flight (conditional ones unless o.nocond) through
-- NewPirateFlight with its Patrol line, then o.extra (quest or random-contact calls, Pandora's deletions).
function NE_Activate(nm, o)
	local d = NE_Data(nm);
	if not d then return; end;
	o = o or {};
	local h = HOST();
	h.npf_stub = 0;
	local team = CreateTeam("Pirates");
	local g = team:CreateGroup(d.g);
	setglobal(d.g, g);
	SetGroupRelation(g, PLAYER_GROUP, o.rel or GetTeamRelation("Pirates", PLAYER_TEAM));
	for i = 1, getn(d.f) do
		local r = d.f[i];
		if not (r.c == 1 and o.nocond) then
			NewPirateFlight(d.g, r.s, Vector3(r.x, r.y, r.z), r.t, r.p, Vector3(0, 0, 1));
			local fl = getglobal("flight_"..r.s);
			local pts = {};
			if r.r then for k = 1, getn(r.r) do tinsert(pts, Vector3(r.r[k][1], r.r[k][2], r.r[k][3])); end; end;
			if getn(pts) == 0 then pts = {Vector3(r.x, r.y, r.z)}; end;
			fl:Patrol(pts, TRUE);
			if fl.trf_nest_stub then h.npf_stub = h.npf_stub + 1; end;
		end;
	end;
	if o.extra then o.extra(d); end;
end;

-- Entry of sys as the engine runs it (ClearGlobals, MapInitialization, functions.script, TRF_OnEnter, activate.script,
-- TRF_OnActivate); o.pre runs before TRF_OnEnter (a location snapshot), o.act = 0 skips the pirate part.
function NE_Enter(sys, o)
	local h = HOST();
	o = o or {};
	h.last = h.loc; h.loc = sys;
	h.triggers = {}; h.ships = {}; h.screen = {}; h.msgs = {};
	print("HOST ---- enter "..sys.." (cleared "..HOST_ClearWithCarry().." globals)");
	HOST_MapInit();
	T_Scene(sys);
	if o.pre then o.pre(); end;
	TRF_OnEnter();
	if o.act ~= 0 then NE_Activate(sys, o); end;
	Trade_Group_1 = HOST_Group("Trade_Group_1");
	TRF_OnActivate();
end;

-- Jump through the wrapped native, then the entry.
function NE_Jump(sys, o)
	TeleportToLocation(sys);
	NE_Enter(sys, o);
end;

-- Fielded flight of row i in this visit, or nil.
function NE_Fl(i) return NE_V().fl[i]; end;

-- Kills flight i: every ship dead, its died triggers, then f_died; hit = 1 the player's attack first.
function NE_Kill(i, hit, nofd)
	local v = NE_V();
	if hit == 1 then HOST_Fire("attack", "TRF_NeHit("..i..","); end;
	local sh = v.sh[i] or {};
	for j = 1, 6 do
		if sh[j] then
			sh[j].alive = nil;
			HOST_Fire("died", "TRF_NeShipDied("..i..","..j..",");
		end;
	end;
	if not nofd then HOST_Fire("f_died", "TRF_Nest_Died("..i..","); end;
end;

function NE_Line(n0, pat)
	local q, l = HOST().logs, nil;
	for i = n0 + 1, getn(q) do if strfind(q[i], pat, 1, 1) then l = q[i]; end; end;
	return l;
end;

function NE_Kv(line, k)
	if not line then return nil; end;
	local a, b, v = strfind(line, " "..k.."=([^ ]*)");
	return v;
end;

function NE_Scr(s0)
	local s, q = "", HOST().screen;
	for i = (s0 or 0) + 1, getn(q) do s = s..q[i].t.."|"; end;
	return s;
end;

function NE_Msgs(m0)
	local s, q = "", HOST().msgs;
	for i = (m0 or 0) + 1, getn(q) do s = s..q[i].t.."|"; end;
	return s;
end;

function NE_Has(s, t) return strfind(s or "", t, 1, 1); end;

-- Number of trigger records of kind whose action starts with pre.
function NE_Trigs(kind, pre)
	local n, q = 0, HOST().triggers;
	for i = 1, getn(q) do if q[i].kind == kind and HOST_Is(q[i], pre) then n = n + 1; end; end;
	return n;
end;

-- Last relation written for the pair (names).
function NE_Rel(a, b) return GetGroupRelation(a, b); end;

-- a: registration, toggles, tune, static table, pure rules ---------------------------------------------

function T_NE_A()
	local h = HOST();
	NE_Begin("gaoba");
	-- design/strength-spec.md 5.6: trf_str counts as an extra module (12 -> 13).
	-- design/fits-spec.md 7: trf_fits counts as an extra module (13 -> 14).
	HOST_Check(S_Logs(0, "module=core event=loaded map=true module_count=18 extra_count=14") >= 1, "trf_nest loads before trf_parcel (extra_count=14 with trf_merc)");
	local ml = TRF_ModList();
	HOST_Check(ml[getn(ml) - 2] == "Nest" and TRF_Opt("nest") == 1 and TRF_Nest_OptDef().nest == 0 and TRF_NeOpt("nest_mode") == 1
		and TRF_NeOpt("nest_trig") == 2 and TRF_NeOpt("nest_lines") == 1 and TRF_NeOpt("nest_mirror") == 1 and TRF_NeOpt("nest_grudge_war") == 0,
		"TRF_ModList has Nest; nest off by default (on in these runs), mode 1, per-ship triggers, lines and mirror on, grudge war off");
	local pm, pg = TRF_PlMods(), TRF_PlGroups();
	HOST_Check(pm[getn(pm) - 2] == "Nest" and pm[getn(pm) - 1] == "Pc" and pg[getn(pg)] == "Nest" and TRF_PlAdopt().Nest == 1, "trf_plumb: Nest registers (before Pc), its group prefix is scanned, its ships adopted at load");
	HOST_Check(NewPirateFlight ~= TRF_orig_NewPirateFlight and TRF_NeIsMine(NewPirateFlight) and type(TRF_orig_NewPirateFlight) == "function"
		and not TRF_NeIsMine(TRF_orig_NewPirateFlight), "NewPirateFlight wrapped once over this run's vanilla function");
	local w0 = NewPirateFlight;
	HOST_Check(TRF_InstallNest() == 0 and NewPirateFlight == w0, "a second install in the same run does not wrap again");
	TRF_NeE("x"); HOST_Check(S_Line(0, "module=nest event=x") ~= "", "log wrapper module=nest");
	-- Tune defaults and clamps.
	local T = TRF_NeTune();
	HOST_Check(T.nest_f[1] == 70 and T.nest_f[3] == 100 and T.nest_f[5] == 50 and T.nest_f[6] == 70 and T.nest_f_swept == 0
		and T.nest_dp[1] == -1 and T.nest_dp[2] == 0 and T.nest_dp[4] == 1 and T.nest_regen_pct == 15 and T.nest_regen_legs == 2
		and T.nest_cache_r == 600 and T.nest_cap == 0, "tune defaults of design 6");
	NE_Tune("nest_f", {200, -5, 50, 50, 50, 50}); NE_Tune("nest_regen_legs", 0);
	T = TRF_NeTune();
	HOST_Check(T.nest_f[1] == 100 and T.nest_f[2] == 0 and T.nest_regen_legs == 1, "tune clamps: f 0..100, regen legs >= 1");
	h.cfg.tune = {};
	NE_Set("nest_mode", 3); HOST_Check(TRF_NeOpt("nest_mode") == 1, "nest_mode outside 1..2 reads 1");
	NE_Set("nest_mode", 2); HOST_Check(TRF_NeOpt("nest_mode") == 2, "nest_mode 2");
	NE_Set("nest_mode", nil);
	-- Static table (gen_nest.py, design appendix A).
	local d = TRF_NestData();
	local ns, nf, np, nc = 0, 0, 0, 0;
	local pins = "";
	local gs = {};
	for nm, e in d do
		ns = ns + 1; nf = nf + getn(e.f);
		gs[e.g] = 1;
		for i = 1, getn(e.f) do
			if e.f[i].pin == 1 then np = np + 1; if nm ~= "el_ariash" and nm ~= "x297" then pins = pins.." "..nm..":"..e.f[i].s; end; end;
			if e.f[i].c == 1 then nc = nc + 1; end;
		end;
	end;
	local ng = 0; for k, v in gs do ng = ng + 1; end;
	HOST_Check(ns == 58 and nf == 547 and nc == 5 and ng == 5, "table: 58 systems, 547 flights, 5 conditional (Solncevka), 5 group spellings ("..ns.."/"..nf.."/"..nc.."/"..ng..")");
	HOST_Check(np == 26 + 9 and NE_Has(pins, "aurora:pir_1") and NE_Has(pins, "pegas:Pir02") and NE_Has(pins, "xt93:Pir01") and NE_Has(pins, "kassilia:pir07")
		and NE_Has(pins, "debris1:pir06") and NE_Has(pins, "debris1:pir11") and not NE_Has(pins, "debris1:pir04"),
		"pins: 26 signs in 8 systems (13 of Debris1 named by Mission_USS_Debris1_1/_2) plus every sign of the two class V systems"..pins);
	local gk = d.golkonda;
	HOST_Check(gk.g == "PiratesGroup_1" and getn(gk.f) == 10 and gk.f[1].s == "Pirate01" and gk.f[1].p == 12 and gk.f[6].t == 2
		and gk.f[7].s == "pir07" and gk.f[7].x == -516 and getn(gk.f[1].r) == 3 and gk.f[1].rr == 1449, "Golkonda row data (activate.script 108-149)");
	local rk = {};
	for i = 1, 10 do rk[gk.f[i].rk] = gk.f[i].s; end;
	HOST_Check(rk[1] == "Pirate03" and rk[8] == "Pirate02" and rk[9] == "pir05" and rk[10] == "pir04", "ranks from the pirate station: the outer patrols last");
	HOST_Check(d.solncevka.f[9].c == 1 and d.solncevka.f[9].s == "pir05" and d.pandora.g == "Pirates_Group_1" and d.ahilles.g == "Pirate_Group_1_1",
		"conditional pir05 of Solncevka, group spellings of Pandora and Ahilles");
	-- Pure plan: phases (count) and tiers (power).
	local P = TRF_NestPlanOf(gk.f, 70, 0, -1, {}, 600);
	HOST_Check(P.n == 7 and P.nf == 7 and not P.fl[2] and not P.fl[4] and not P.fl[5] and P.fl[3] and P.sk[2] == "count" and P.pw[1] == 11,
		"Quiet T1: 7 of 10, the three outer ranks skipped, power -1");
	P = TRF_NestPlanOf(gk.f, 100, 0, 1, {}, 600);
	HOST_Check(P.n == 10 and P.nf == 10 and P.pw[3] == 16 and P.pw[1] == 13, "Build-up T3: all 10 at power +1 (13-16)");
	P = TRF_NestPlanOf(gk.f, 50, 0, 0, {}, 600);
	HOST_Check(P.nf == 5 and P.pw[1] == 12, "Bust T2: 5 at the vanilla power");
	P = TRF_NestPlanOf(gk.f, 0, 0, 0, {}, 600);
	HOST_Check(P.nf == 0, "swept target: none");
	P = TRF_NestPlanOf(gk.f, 100, 7, 1, {}, 600);
	HOST_Check(P.n == 3 and P.nf == 3 and P.fl[3] and P.fl[7] and P.fl[8], "memory 7: 3 fielded, the core ranks");
	P = TRF_NestPlanOf(gk.f, 100, 99, 1, {}, 600);
	HOST_Check(P.n == 0 and P.nf == 0, "memory above the count: none, never negative");
	P = TRF_NestPlanOf({{s="a", p=20, rk=1}, {s="b", p=1, rk=2}}, 100, 0, 1, {}, 600);
	local P2 = TRF_NestPlanOf({{s="a", p=20, rk=1}, {s="b", p=1, rk=2}}, 100, 0, -1, {}, 600);
	HOST_Check(P.pw[1] == 20 and P2.pw[2] == 1, "power clamped to 1..20");
	local pg2 = d.pegas;
	P = TRF_NestPlanOf(pg2.f, 50, 16, 0, {}, 600);
	local pf = 0;
	for i = 1, getn(pg2.f) do if P.fl[i] and pg2.f[i].pin == 1 then pf = pf + 1; end; end;
	HOST_Check(P.n == 5 and P.nf == 5 and pf == 5, "Pegas: the five pinned signs fielded even at memory 16");
	P = TRF_NestPlanOf(gk.f, 100, 0, 0, {{x=-516, y=0, z=508}}, 600);
	HOST_Check(P.nf < 10 and not P.fl[7] and P.sk[7] == "cache", "a sign within nest_cache_r + rr of an unopened cache is skipped ("..P.nf..")");
	P = TRF_NestPlanOf(gk.f, 100, 0, 0, {{x=-516, y=0, z=508}}, 0);
	HOST_Check(not P.fl[7], "cache radius 0: the route radius still counts");
	-- Refill: 15 % of 10 rounded up per 2 legs.
	local k, l, t = TRF_NeRefillOf(7, 100, 102, 10, 15, 2);
	HOST_Check(k == 5 and l == 102 and t == 1, "refill one step: 7 -> 5");
	k, l, t = TRF_NeRefillOf(7, 100, 105, 10, 15, 2);
	HOST_Check(k == 3 and l == 104 and t == 2, "two steps (7 - 2 x 2), the stamp moves by whole steps");
	k, l, t = TRF_NeRefillOf(7, 100, 101, 10, 15, 2);
	HOST_Check(k == 7 and l == 100 and t == 0, "less than a step: unchanged");
	k = TRF_NeRefillOf(10, 0, 14, 10, 15, 2);
	HOST_Check(k == 0, "a cleared nest of 10 refills in 5 steps (10 legs, design 4)");
	k, l, t = TRF_NeRefillOf(7, 100, 110, 10, 0, 2);
	HOST_Check(k == 7 and l == 100 and t == 0, "regen pct 0: no step, the stamp stays");
	-- Ship list of a flight: the pilot list (compacted after a load), the ship_<sign>_<j> globals fill gaps, never a
	-- ship already listed.
	local sA, sB = {__obj=1, alive=1}, {__obj=1, alive=1};
	local pA = {GetShip=function(self) return %sA; end};
	local fl2 = {GetPilotCount=function(self) return 1; end, GetPilotByNumber=function(self, j) return %pA; end};
	setglobal("ship_zz_1", sA); setglobal("ship_zz_2", sA); setglobal("ship_zz_3", sB);
	local sh2 = TRF_NeShips(fl2, "zz");
	local nsh2 = 0;
	for j = 1, 6 do if sh2[j] then nsh2 = nsh2 + 1; end; end;
	HOST_Check(sh2[1] == sA and sh2[3] == sB and nsh2 == 2, "ships: a global naming a listed ship is skipped, another fills its gap ("..nsh2..")");
	setglobal("ship_zz_1", nil); setglobal("ship_zz_2", nil); setglobal("ship_zz_3", nil);
	-- Lines.
	local K = TRF_NeK();
	local a1 = TRF_NeLineOf({k=3}, 4, 2, nil, nil, K);
	local a2, n2 = TRF_NeLineOf({k=10, c=1}, 0, 2, nil, nil, K);
	local a3, n3 = TRF_NeLineOf(nil, 10, 2, nil, nil, K);
	local a4 = TRF_NeLineOf(nil, 10, 2, 3, nil, K);
	local a5 = TRF_NeLineOf(nil, 10, 1, nil, nil, K);
	local a6, n6 = TRF_NeLineOf(nil, 0, 4, 5, 1, K);
	local a7 = TRF_NeLineOf(nil, 5, 4, 7, nil, K);
	local a8 = TRF_NeLineOf(nil, 7, 0, nil, nil, K);
	local a9 = TRF_NeLineOf(nil, 10, 3, nil, nil, K);
	HOST_Check(a1 == "nesthurt" and a2 == "nestclear" and not n2 and a3 == "nestfull" and n3 == 3 and not a4 and not a5 and a6 == "nestswept"
		and n6 == 7 and not a7 and a8 == "nestquiet" and a9 == "nestraid", "lines: Hurt, Clear, the phase line once per phase, none in Boom, Swept once in Bust");
	local tx = TRF_Nest_Text();
	local nk = 0; for kx, v in tx do nk = nk + 1; end;
	HOST_Check(nk == 9 and TRF_Txt("nestfull", "Rustmen") == "The pirate nest here (Rustmen) is crowded. Ships are gathering.", "9 text keys, $1 the clan");
	HOST_Check(TRF_NeBitsOf({1, nil, 1}, 4) == "1010", "bit string");
	-- Deny entries.
	local ex = TRF_DenyEntry("x297");
	local ea = TRF_DenyEntry("el_ariash");
	HOST_Check(ex and ex.nest == 0 and ex.m == 1 and ea and ea.nest == 0 and ea.m == 1 and ea.tq == 1, "deny entries: x297 nest 0 (m 1), el_ariash nest 0 (teleport target m 1, tq 1 kept)");
	HOST_Check(TRF_StrictOk(V_Idx("x297"), "nest") == nil and TRF_StrictOk(V_Idx("golkonda"), "nest") == 1, "strict gate: deny_nest in X297, open in Golkonda");
end;

-- b: the wrapper at entry --------------------------------------------------------------------------------

function T_NE_B()
	local h = HOST();
	NE_Begin("xb13");
	local gs = NE_Slot("golkonda");
	NE_Phase(gs, 2, 62);
	local n0 = S_Mark();
	h.npf = 0;
	NE_Jump("golkonda", {extra=function(d)
		NewPirateFlight("PiratesGroup_1", "quest01", Vector3(2500, 0, 2500), 1, 5, Vector3(0, 0, 1));
		NewPirateFlight("OtherGroup_1", "pir07", Vector3(0, 0, 0), 1, 5, Vector3(0, 0, 1));
	end});
	local ml = NE_Line(n0, "module=nest event=mode ");
	HOST_Check(ml and NE_Kv(ml, "mode") == "nest" and NE_Kv(ml, "phase") == "2" and NE_Kv(ml, "tier") == "3" and NE_Kv(ml, "f") == "100"
		and NE_Kv(ml, "dp") == "1" and NE_Kv(ml, "vanilla_count") == "10" and NE_Kv(ml, "memory") == "0", "mode line: nest, Build-up T3, f 100, dp +1 "..tostring(ml));
	HOST_Check(S_Logs(n0, "module=nest event=call sign=") == 10 + 2 and S_Logs(n0, "result=substituted") == 10, "ten substituted calls, the quest and group calls passed");
	HOST_Check(S_Logs(n0, "event=call sign=quest01 result=pass reason=unlisted") == 1 and S_Logs(n0, "event=call sign=pir07 result=pass reason=group") == 1,
		"pass-through: an unlisted sign and a listed sign in another group");
	local s = S_Line(n0, "event=call sign=Pirate03 ");
	HOST_Check(NE_Kv(s, "power") == "16" and NE_Kv(s, "vanilla_power") == "15", "Pirate03 built at power 16 (vanilla 15)");
	local v = NE_V();
	local ok, bad = 1, "";
	for i = 1, 10 do
		local fl = v.fl[i];
		local sign = NE_Data("golkonda").f[i].s;
		if not fl or fl.group.name ~= "TRF_Nest_1" or fl.group.team ~= "Pirates" or getglobal("flight_"..sign) ~= fl or not getglobal("ship_"..sign.."_1")
			or not getglobal("pilot_"..sign.."_1") or not fl.patrol then ok = nil; bad = bad.." "..sign; end;
		if fl and fl.ships[1].label ~= "trf_nest_"..i.."_1" then ok = nil; bad = bad.." label"..i; end;
	end;
	HOST_Check(ok, "every flight in TRF_Nest_1 of team Pirates, flight_/ship_/pilot_ globals real, Patrol applied, ships labelled"..bad);
	local nsh = 0;
	for i = 1, 10 do nsh = nsh + getn(v.fl[i].ships); end;
	HOST_Check(NE_Trigs("f_died", "TRF_Nest_Died(") == 10 and NE_Trigs("died", "TRF_NeShipDied(") == nsh and NE_Trigs("attack", "TRF_NeHit(") == nsh
		and T_BadCallbacks() == "", "triggers: f_died per flight, died and attack per ship, with the gen ("..nsh.." ships)");
	local al = NE_Line(n0, "module=nest event=activate ");
	HOST_Check(NE_Kv(al, "fielded") == "10" and NE_Kv(al, "stub") == "0" and NE_Kv(al, "gone") == "0" and NE_Kv(al, "unknown") == "1"
		and NE_Kv(al, "missing") == "0" and NE_Kv(al, "relation") == "war", "activate line "..tostring(al));
	HOST_Check(TRF.nv and TRF.nv.i == V_Idx("golkonda") and TRF.nv.b == "1111111111" and TRF.nst.n == 10, "TRF.nv bits, counter n");
	HOST_Check(NE_Rel("TRF_Nest_1", PLAYER_GROUP) == RELATION_WAR and NE_Rel(PLAYER_GROUP, "TRF_Nest_1") == RELATION_WAR, "nest group copies the vanilla relation both ways");
	HOST_Check(getglobal("TRF_GNest_1") == nil and TRF_NeNE().a == nil, "build global cleared, wrapper disarmed");
	local n1 = S_Mark();
	local qf = NewPirateFlight("PiratesGroup_1", "pir07", Vector3(3000, 0, 3000), 1, 5, Vector3(0, 0, 1));
	HOST_Check(S_Logs(n1, "module=nest event=call ") == 0 and qf.group.name == "PiratesGroup_1", "after activate.script: a quest call of a listed sign is vanilla, no call line");
	T_Tick(40, 0.5);
	HOST_Check(NE_Has(NE_Scr(0), "is crowded") and TRF.clan[gs].nl == 3, "arrival line Full, nl = phase + 1");
	-- An error in the decision (set after the MapInitialization reload): the vanilla call, the rest of activate.script runs.
	NE_Jump("xb13");
	n1 = S_Mark();
	-- The handler is counted instead of logged, so the expected errors are not script errors of the run.
	h.ne_err = 0;
	NE_Jump("golkonda", {pre=function()
		TRF_NeDecide = function() error("decide"); end;
		TRF_NeErr = function(m) HOST().ne_err = HOST().ne_err + 1; end;
	end});
	HOST_Check(flight_pir07 and flight_pir07.group.name == "PiratesGroup_1" and h.ne_err == 10 and S_Logs(n1, "result=substituted") == 0
		and TRF_NeNE().a == nil, "decision error: every flight vanilla, the handler ran per call ("..h.ne_err..")");
	-- Same phase again: no second phase line; Quiet T1: 7 fielded, 3 stubs.
	NE_Jump("xb13");
	NE_Phase(gs, 0, 10);
	n0 = S_Mark();
	NE_Jump("golkonda");
	al = NE_Line(n0, "module=nest event=activate ");
	HOST_Check(NE_Kv(al, "fielded") == "7" and NE_Kv(al, "stub") == "3" and h.npf_stub == 3,
		"Quiet T1: 7 fielded, 3 stubs took the Patrol line, none left "..tostring(al));
	HOST_Check(flight_Pirate02 == nil and flight_pir04 == nil and flight_pir05 == nil and TRF.nv.b == "1010011111", "stub globals nil after TRF_OnActivate; bits");
	HOST_Check(S_Logs(n0, "event=call sign=pir04 result=stub reason=count") == 1, "stub logged with the reason");
	s = S_Line(n0, "event=call sign=Pirate03 ");
	HOST_Check(NE_Kv(s, "power") == "14", "T1: power -1 (14)");
	T_Tick(40, 0.5);
	HOST_Check(NE_Has(NE_Scr(0), "Only a few pirate ships"), "arrival line Quiet");
	-- Pegas at Bust: 8 of 16 with the five pins.
	local ps = NE_Slot("pegas");
	NE_Phase(ps, 4, 30);
	NE_Jump("ahilles");
	n0 = S_Mark();
	NE_Jump("pegas");
	al = NE_Line(n0, "module=nest event=activate ");
	local pin = 0;
	local pd = NE_Data("pegas");
	for i = 1, getn(pd.f) do if pd.f[i].pin == 1 and NE_V().fl[i] then pin = pin + 1; end; end;
	HOST_Check(NE_Kv(al, "fielded") == "8" and pin == 5 and S_Logs(n0, "pinned=true") == 5, "Pegas Bust: 8 of 16, the five pins fielded "..tostring(al));
	-- Pandora: activate.script deletes every flight (mission 8a): gone, no kill.
	NE_Jump("kruger");
	n0 = S_Mark();
	NE_Jump("pandora", {extra=function(d)
		for i = 1, getn(d.f) do
			local fl = getglobal("flight_"..d.f[i].s);
			if fl:IsAlive() then fl:Delete(); end;
		end;
	end});
	al = NE_Line(n0, "module=nest event=activate ");
	HOST_Check(NE_Kv(al, "fielded") == "0" and NE_Kv(al, "gone") == "15" and TRF.nest == nil and TRF.nv.b == strrep("0", 15),
		"Pandora: every fielded flight gone, no kill memory "..tostring(al));
	-- Solncevka: the conditional flights not called (old Empire).
	NE_Jump("moscowia");
	n0 = S_Mark();
	NE_Jump("solncevka", {nocond=1});
	al = NE_Line(n0, "module=nest event=activate ");
	HOST_Check(NE_Kv(al, "fielded") == "8" and NE_Kv(al, "missing") == "5", "Solncevka: 8 fielded, the 5 conditional signs missing "..tostring(al));
	-- nest_mode 2: vanilla builds, the mod deletes and replaces.
	NE_Set("nest_mode", 2);
	NE_Jump("xb13");
	NE_Phase(gs, 4, 30);
	n0 = S_Mark();
	NE_Jump("golkonda");
	local rl = NE_Line(n0, "module=nest event=replace ");
	HOST_Check(NE_Kv(rl, "deleted") == "10" and NE_Kv(rl, "spawned") == "5" and S_Logs(n0, "result=recorded") == 10, "mode 2: 10 recorded and deleted, 5 spawned (Bust) "..tostring(rl));
	v = NE_V();
	local fl = nil;
	for i = 1, 10 do if v.fl[i] then fl = v.fl[i]; end; end;
	HOST_Check(fl and fl.group.name == "TRF_Nest_1" and fl.patrol and getn(fl.patrol) >= 1 and fl.ships[1].label and strfind(fl.ships[1].label, "^trf_nest_"),
		"mode 2 flights in the nest group on the static route, labelled");
	-- nest_mode 2 in Pandora after mission 8a: activate.script deleted every vanilla flight; none built again.
	NE_Jump("kruger");
	n0 = S_Mark();
	NE_Jump("pandora", {extra=function(d)
		for i = 1, getn(d.f) do
			local fl = getglobal("flight_"..d.f[i].s);
			if fl:IsAlive() then fl:Delete(); end;
		end;
	end});
	rl = NE_Line(n0, "module=nest event=replace ");
	al = NE_Line(n0, "module=nest event=activate ");
	HOST_Check(NE_Kv(rl, "deleted") == "0" and NE_Kv(rl, "spawned") == "0" and NE_Kv(al, "fielded") == "0" and NE_Kv(al, "gone") == "15"
		and TRF_Nest_Alive() == 0, "mode 2 Pandora: no flight built again, 15 gone "..tostring(rl).." "..tostring(al));
	NE_Set("nest_mode", nil);
	NE_Jump("xb13");
	HOST_Check(T_LeftGlobals() == "", "no group global left"..T_LeftGlobals());
end;

-- c: pass-through and gates ----------------------------------------------------------------------------

function T_NE_C()
	local h = HOST();
	NE_Begin("xb13");
	-- nest 0: every flight vanilla, no call line.
	NE_Set("nest", 0);
	local n0 = S_Mark();
	NE_Jump("golkonda");
	HOST_Check(NE_Kv(NE_Line(n0, "module=nest event=mode "), "reason") == "off" and S_Logs(n0, "result=substituted") == 0
		and flight_pir07 and flight_pir07.group.name == "PiratesGroup_1" and NE_V().fl[1] == nil, "nest 0: vanilla flights in PiratesGroup_1");
	HOST_Check(S_Logs(n0, "event=call ") == 0, "nest 0: the wrapper passes every call through, no call line (E16.1)");
	-- E16.2 with nest 0: the probe at entry and after activate.script.
	TRF_Carcasses = HOST_Carcasses;
	h.carc = {};
	NE_Jump("xb13");
	n0 = S_Mark();
	NE_Jump("golkonda", {pre=function() HOST().carc = {}; end, extra=function(d) HOST().carc = {{id=1, cls=3, team="Pirates", hp=100, x=0, y=0, z=0}}; end});
	HOST_Check(S_Logs(n0, "module=nest event=probe at=enter pirates=0") == 1 and S_Logs(n0, "module=nest event=probe at=activate pirates=1") == 1,
		"nest 0: probe lines at entry and activation");
	TRF_Carcasses = nil; h.carc = nil;
	n0 = S_Mark();
	NE_Jump("xb13");
	HOST_Check(S_Logs(n0, "module=nest event=probe ") == 0, "no probe in a system without data");
	NE_Set("nest", 1);
	local function_check = function(sys, why, prev, ch)
		if ch then HOST().labels.CurrentQuest = ch; end;
		NE_Jump(prev);
		local m = S_Mark();
		NE_Jump(sys);
		local l = NE_Line(m, "module=nest event=mode ");
		local fl = getglobal("flight_"..NE_Data(sys).f[1].s);
		HOST_Check(NE_Kv(l, "mode") == "vanilla" and NE_Kv(l, "reason") == why and S_Logs(m, "result=substituted") == 0
			and fl and fl.group.name == NE_Data(sys).g, sys..": vanilla, reason "..why.." "..tostring(l));
	end;
	function_check("x297", "excluded", "xb13");
	function_check("el_ariash", "excluded", "hanoi");
	NE_Set("nest_off", {"Golkonda"});
	function_check("golkonda", "excluded", "xb13");
	NE_Set("nest_off", nil);
	function_check("golkonda", "guard", "xb13", "4_1");
	HOST().labels.CurrentQuest = "9_1";
	NE_Set("sys_off", {"golkonda"});
	function_check("golkonda", "sysmode", "xb13");
	NE_Set("sys_off", nil);
	-- A quest naming Kadi in process: vanilla for that visit; after it ends, a nest.
	local qi = TRF_DenyQ(V_Idx("kadi"));
	h.quests[qi[1]] = QUEST_PROCESS;
	function_check("kadi", "gate_quest", "hanoi");
	h.quests[qi[1]] = QUEST_DONE;
	NE_Jump("hanoi");
	n0 = S_Mark();
	NE_Jump("kadi");
	HOST_Check(NE_Kv(NE_Line(n0, "module=nest event=mode "), "mode") == "nest" and S_Logs(n0, "result=substituted") == 13, "Kadi after the quest: a nest of 13");
	-- A deny m = 1 system during a mission: vanilla (sysmode).
	NE_Jump("callipso");
	h.qs = TRUE;
	n0 = S_Mark();
	NE_Jump("elio");
	HOST_Check(NE_Kv(NE_Line(n0, "module=nest event=mode "), "mode") == "vanilla", "Elio (deny m 1) during a mission: vanilla");
	h.qs = FALSE;
	-- A system without pirate flights: no data, level 2 only.
	n0 = S_Mark();
	NE_Jump("gaoba");
	HOST_Check(NE_Kv(NE_Line(n0, "module=nest event=mode "), "reason") == "no_data", "Gaoba: no data");
	-- Suppression at entry.
	n0 = S_Mark();
	NE_Jump("golkonda", {pre=function() __disableAction = TRUE; end});
	__disableAction = nil;
	HOST_Check(NE_Kv(NE_Line(n0, "module=nest event=mode "), "reason") == "supp", "__disableAction at entry: vanilla (supp)");
	-- No line during a mission in a nest system (q = 0): the nest is fielded, the line is not shown.
	NE_Jump("xb13");
	h.qs = TRUE;
	NE_Phase(NE_Slot("golkonda"), 3, 90);
	n0 = S_Mark();
	NE_Jump("golkonda");
	T_Tick(40, 0.5);
	HOST_Check(S_Logs(n0, "result=substituted") == 10 and not NE_Has(NE_Scr(0), "restless") and S_Logs(n0, "module=nest event=arrival") == 0,
		"mission active in a never-named system: nest fielded, no arrival line");
	h.qs = FALSE;
	NE_Jump("xb13");
end;

-- d: kill memory and feeds -----------------------------------------------------------------------------------

function T_NE_D()
	local h = HOST();
	NE_Begin("xb13");
	local gs = NE_Slot("golkonda");
	local gi = V_Idx("golkonda");
	NE_Phase(gs, 2, 62);
	-- Scar feed spy.
	h.ne_sc = {};
	local sc0 = TRF_Sc_Dead;
	NE_Jump("golkonda");
	TRF_Sc_Dead = function(c, f, o, m) tinsert(HOST().ne_sc, {c=c, m=m}); end;
	TRF_SetDis(gi, 3);
	local v = NE_V();
	local sc = TRF.clan[gs].sc;
	local n0 = S_Mark();
	local m0 = getn(h.msgs);
	NE_Kill(7, 1);
	local dl = NE_Line(n0, "module=nest event=died ");
	HOST_Check(NE_Kv(dl, "index") == "7" and NE_Kv(dl, "sign") == "pir07" and NE_Kv(dl, "mine") == "true" and NE_Kv(dl, "memory") == "1",
		"died: pir07 with player fire, memory 1 "..tostring(dl));
	HOST_Check(TRF.nest[gi].k == 1 and TRF.nest[gi].l == TRF.clock.legs and TRF.clan[gs].sc == sc - 2 and TRF.clan[gs].nk == 1 and TRF.nst.k == 1
		and TRF.nst.p == 1 and strsub(TRF.nv.b, 7, 7) == "0", "memory record, clan score -2, nk 1, counters, bit cleared");
	HOST_Check(getn(h.ne_sc) == getn(v.sh[7]) and h.ne_sc[1].c == 3 and h.ne_sc[1].m == 1, "every ship fed to battle scars with mine 1");
	HOST_Check(NE_Has(NE_Msgs(m0), "don't forget a face") or NE_Has(NE_Scr(0), "don't forget a face"), "first hit: the leader's radio line");
	HOST_Check(TRF_Dis(gi) == 2 and S_Logs(n0, "module=events event=recovery ") == 1, "player kill through TRF_Ev_Recover: dis 3 -> 2");
	-- A second f_died of the same flight counts nothing.
	HOST_FireAll("f_died", "TRF_Nest_Died(7,");
	HOST_Check(TRF.nest[gi].k == 1, "a flight counts once");
	-- A kill without player fire: score -2, no nk, scars with mine nil.
	h.ne_sc = {};
	NE_Kill(1, 0);
	HOST_Check(TRF.nest[gi].k == 2 and TRF.clan[gs].nk == 1 and TRF.nst.p == 1 and h.ne_sc[1].m == nil, "kill without player fire: memory 2, nk unchanged");
	-- Ship-level fallback: every ship dead without f_died.
	n0 = S_Mark();
	NE_Kill(2, 1, 1);
	HOST_Check(NE_Kv(NE_Line(n0, "module=nest event=died "), "reason") == "ships" and TRF.nest[gi].k == 3, "every ship dead without f_died: the flight ends (reason ships)");
	-- Stale generation.
	n0 = S_Mark();
	TRF_Nest_Died(3, TRF.gen - 1);
	HOST_Check(S_Logs(n0, "module=nest event=stale index=3") == 1 and TRF.nest[gi].k == 3, "old-generation trigger: stale, nothing counted");
	-- Pirate watch leaves nest flights out.
	local pl = v.fl[4]:GetLeader();
	TRF_Ev_PirEject(pl);
	local H = TRF_H();
	local watched = nil;
	if type(H.pir) == "table" then for q = 1, getn(H.pir) do if H.pir[q] == v.fl[4] then watched = 1; end; end; end;
	HOST_Check(TRF_Nest_Owns(v.fl[4]) and not watched, "an ejecting nest pilot does not start the pirate watch");
	-- Relation mirror: a quest sets the vanilla group neutral; the 1 s step copies it, one way.
	n0 = S_Mark();
	SetGroupRelation(PiratesGroup_1, PLAYER_GROUP, RELATION_NEUTRAL);
	T_Tick(4, 0.5);
	local rl = NE_Line(n0, "module=nest event=relation ");
	HOST_Check(NE_Kv(rl, "from") == "war" and NE_Kv(rl, "to") == "neutral" and NE_Rel("TRF_Nest_1", PLAYER_GROUP) == RELATION_NEUTRAL, "mirror: vanilla war -> neutral copied "..tostring(rl));
	SetGroupRelation("TRF_Nest_1", PLAYER_GROUP, RELATION_WAR);
	n0 = S_Mark();
	T_Tick(4, 0.5);
	HOST_Check(S_Logs(n0, "module=nest event=relation ") == 0 and GetGroupRelation(PiratesGroup_1, PLAYER_GROUP) == RELATION_NEUTRAL, "one way: a nest fight does not reach the vanilla group");
	-- Jump with 7 left and back (each entry one leg: one step): 3 - 2 = 1, 9 fielded at Build-up, Hurt line.
	NE_Jump("xb13");
	n0 = S_Mark();
	NE_Jump("golkonda");
	local gl = NE_Line(n0, "module=nest event=regen ");
	HOST_Check(NE_Kv(gl, "memory_before") == "3" and NE_Kv(gl, "memory_after") == "1" and NE_Kv(gl, "ticks") == "1"
		and NE_Kv(NE_Line(n0, "module=nest event=activate "), "fielded") == "9", "refill: 3 -> 1 after one step, 9 fielded "..tostring(gl));
	T_Tick(40, 0.5);
	HOST_Check(NE_Has(NE_Scr(0), "licking its wounds"), "Hurt line with a memory record");
	-- Kill all 9 (the last with player fire): screen line, c 1; back before a step: none fielded, Clear line.
	local sc1 = TRF.clan[gs].sc;
	local s0 = getn(h.screen);
	for i = 1, 10 do if NE_V().fl[i] then NE_Kill(i, 1); end; end;
	HOST_Check(TRF.nest[gi].k == 10 and TRF.nest[gi].c == 1 and NE_Has(NE_Scr(s0), "is broken"), "the last fielded flight: screen line, c 1");
	HOST_Check(TRF.clan[gs].sc >= sc1 - 6, "clan score inside the -6 visit cap");
	NE_Tune("nest_regen_legs", 50);
	NE_Jump("xb13");
	n0 = S_Mark();
	NE_Jump("golkonda");
	T_Tick(40, 0.5);
	HOST_Check(NE_Kv(NE_Line(n0, "module=nest event=activate "), "fielded") == "0" and NE_Has(NE_Scr(0), "is empty"), "cleared nest, no step since: none fielded, Clear line");
	-- Enough steps later the record is gone.
	h.cfg.tune = {};
	NE_Jump("xb13");
	TRF.nest[gi].l = TRF.clock.legs - 30;
	NE_Jump("golkonda");
	HOST_Check(TRF.nest[gi] == nil and NE_Kv(NE_Line(0, "module=nest event=activate "), "fielded") == "10", "memory refilled to 0: record removed, 10 fielded");
	-- Sweep: success marks the home target; Bust gives 0 there with the Swept line; Recovery clears it; Quiet clears nk.
	NE_Jump("xb13");
	TRF_Nest_Sweep(gs, TRF.clock.legs, 1);
	HOST_Check(TRF.clan[gs].ns == TRF_SweepTarget(gs), "sweep won: target marked");
	-- An active base in another nest system of the region is the target: a won sweep (trf_region) destroys the base,
	-- and the target is read before that.
	local bi = nil;
	for nm, e in TRF_NestData() do
		local x = V_Idx(nm);
		if x and TRF_RgOf(x) == gs and x ~= TRF_SweepTarget(gs) and nm ~= "x297" and nm ~= "el_ariash" then bi = x; end;
	end;
	local b0 = TRF.base;
	TRF.base = {{s=bi, k=2, h=9, t=0, w=0}};
	TRF.clan[gs].ns = nil;
	TRF_RgSweepOut(gs, TRF.clock.legs, 1, 1, "on", 50);
	HOST_Check(bi and TRF.base[1].k == 3 and TRF.clan[gs].ns == bi, "sweep won over an active base: its system is the target "..tostring(bi));
	TRF.base = b0;
	NE_Phase(gs, 4, 30);
	TRF.clan[gs].ns = gi;
	n0 = S_Mark();
	h.rel = {};
	NE_Jump("golkonda");
	local nr = 0;
	for q = 1, getn(h.rel) do if h.rel[q][1] == "TRF_Nest_1" or h.rel[q][2] == "TRF_Nest_1" then nr = nr + 1; end; end;
	T_Tick(40, 0.5);
	HOST_Check(NE_Kv(NE_Line(n0, "module=nest event=mode "), "f") == "0" and NE_Kv(NE_Line(n0, "module=nest event=activate "), "fielded") == "0"
		and NE_Has(NE_Scr(0), "swept the pirate nest"), "Bust in the sweep target: f 0, none fielded, Swept line");
	HOST_Check(nr == 0, "no nest group: no relation written for it ("..nr..")");
	TRF.clan[gs].nk = 4;
	TRF_Nest_Phase(gs, 5);
	HOST_Check(TRF.clan[gs].ns == nil and TRF.clan[gs].nk == 4 and TRF.clan[gs].nl == nil, "Recovery: target cleared, the phase line open again");
	TRF.clan[gs].nl = 3;
	TRF_Nest_Phase(gs, 2);
	HOST_Check(TRF.clan[gs].nl == nil, "Build-up again in the next cycle: its line shows once more");
	TRF_Nest_Phase(gs, 0);
	HOST_Check(TRF.clan[gs].nk == nil, "Quiet: nk cleared");
	-- Sweep and Triada wave relation lists.
	NE_Phase(gs, 2, 62);
	NE_Jump("xb13");
	NE_Jump("golkonda");
	h.rel = {};
	TRF_FcSweepRel("TRF_Sweep_1", {});
	local sw = nil;
	for q = 1, getn(h.rel) do if h.rel[q][1] == "TRF_Sweep_1" and h.rel[q][2] == "TRF_Nest_1" and h.rel[q][3] == RELATION_WAR then sw = 1; end; end;
	HOST_Check(sw, "sweep owner at war with the nest group");
	h.rel = {};
	local tg = HOST_Group("TRF_Feq_1", "Triada");
	TRF_CvFeqTriada({f=3}, tg);
	local tw = nil;
	for q = 1, getn(h.rel) do if h.rel[q][1] == "TRF_Feq_1" and h.rel[q][2] == "TRF_Nest_1" then tw = 1; end; end;
	HOST_Check(tw, "Triada waves at war with the nest group");
	TRF_Sc_Dead = sc0;
	NE_Jump("xb13");
end;

-- e: jump delete, orphan delete, load re-arm ------------------------------------------------------------

function T_NE_E()
	local h = HOST();
	NE_Begin("xb13");
	local gs = NE_Slot("golkonda");
	local gi = V_Idx("golkonda");
	NE_Phase(gs, 2, 62);
	NE_Jump("golkonda");
	local v = NE_V();
	local kept = {};
	for i = 1, 10 do kept[i] = v.fl[i]; end;
	NE_Kill(5, 1);
	local n0 = S_Mark();
	NE_Jump("xb13");
	local jl = NE_Line(n0, "module=nest event=jump ");
	local alive = 0;
	for i = 1, 10 do if kept[i]:IsAlive() then alive = alive + 1; end; end;
	HOST_Check(NE_Kv(jl, "deleted") == "9" and alive == 0 and TRF.nest[gi].k == 1 and TRF.nv.i == V_Idx("xb13"), "jump: the 9 live flights deleted, no death counted, TRF.nv rewritten at the next entry "..tostring(jl));
	-- Orphan: a nest ship left by a location snapshot is deleted at the next entry.
	local orphan = HOST_Obj("trf_nest_2_1", 0, 0, 0);
	orphan.Delete = function(self) self.alive = nil; end;
	n0 = S_Mark();
	NE_Jump("golkonda", {pre=function() HOST().objs["trf_nest_2_1"] = %orphan; end});
	HOST_Check(S_Logs(n0, "module=nest event=orphan label=trf_nest_2_1") == 1 and not orphan.alive, "orphan nest ship deleted at entry");
	-- nest_keep_on_jump 1 keeps the ships (E16.2).
	NE_Set("nest_keep_on_jump", 1);
	v = NE_V();
	local f1 = v.fl[1];
	n0 = S_Mark();
	NE_Jump("xb13");
	HOST_Check(NE_Kv(NE_Line(n0, "module=nest event=jump "), "deleted") == "0" and f1:IsAlive(), "nest_keep_on_jump 1: ships kept");
	NE_Set("nest_keep_on_jump", nil);
	-- Load inside the nest system: flights adopted by their globals, triggers with the new gen, no spawn, no refill.
	NE_Jump("golkonda");
	v = NE_V();
	local nf = 0;
	for i = 1, 10 do if v.fl[i] then nf = nf + 1; end; end;
	NE_Kill(3, 1);
	local k0, g0 = TRF.nest[gi].k, TRF.gen;
	local b0 = TRF.nv.b;
	h.npf = 0;
	n0 = S_Mark();
	T_SaveLoad(function() TRF_GNest_1 = {__obj=1, kind="group"}; end);
	local ll = NE_Line(n0, "module=nest event=load ");
	HOST_Check(NE_Kv(ll, "rearmed") == tostring(nf - 1) and TRF.gen == g0 + 1 and h.npf == 0 and TRF.nv.b == b0, "load: "..(nf - 1).." flights re-armed, nothing spawned "..tostring(ll));
	HOST_Check(getglobal("TRF_GNest_1") == nil and NE_Kv(NE_Line(n0, "module=plumb event=orphan "), "deleted_count") == "0",
		"load: the build global cleared by the plumb scan, no nest ship taken as an orphan");
	v = NE_V();
	local live = 0;
	for i = 1, 10 do if v.fl[i] and v.fl[i]:IsAlive() then live = live + 1; end; end;
	HOST_Check(live == nf - 1 and NE_Trigs("f_died", "TRF_Nest_Died(1,"..TRF.gen..")") == 1, "adopted flights alive, re-armed with gen + 1");
	-- The old trigger fires: stale; the new one counts once.
	n0 = S_Mark();
	HOST_Fire("f_died", "TRF_Nest_Died(1,"..g0..")");
	HOST_Check(S_Logs(n0, "module=nest event=stale index=1") == 1 and TRF.nest[gi].k == k0, "old-generation trigger after the load: stale");
	NE_Kill(1, 1);
	HOST_Check(TRF.nest[gi].k == k0 + 1 and NE_Kv(NE_Line(n0, "module=nest event=died "), "generation") == tostring(TRF.gen), "kill after the load: memory + 1 once, new gen");
	-- A load in another system drops TRF.nv.
	NE_Jump("xb13");
	TRF.nv = {i=gi, b="1111111111"};
	T_SaveLoad();
	HOST_Check(TRF.nv == nil, "load elsewhere: TRF.nv dropped");
	NE_Jump("gaoba");
	HOST_Check(T_LeftGlobals() == "", "no group global left"..T_LeftGlobals());
end;

-- f: repair, dump, ship caps, save bound --------------------------------------------------------------------

function T_NE_F()
	local h = HOST();
	NE_Begin("xb13");
	local gs = NE_Slot("golkonda");
	local gi, ki = V_Idx("golkonda"), V_Idx("gaoba");
	NE_Phase(gs, 2, 62);
	NE_Jump("golkonda");
	-- Ship caps: registered, never trimmed; counted only with nest_cap 1.
	local n = TRF_Nest_Alive();
	HOST_Check(n > 10 and TRF_Nest_Ships("nest") == 0, "cap group: "..n.." live ships, 0 in cap_ships by default");
	NE_Tune("nest_cap", 1);
	HOST_Check(TRF_Nest_Ships("nest") == n and TRF_CapShips() >= n, "nest_cap 1: counted in cap_ships");
	local pl, left = TRF_CapTrim(5);
	local tr = nil;
	for q = 1, getn(pl) do if pl[q].g == "nest" then tr = 1; end; end;
	HOST_Check(not tr and left == 5, "the nest group is never trimmed");
	h.cfg.tune = {};
	-- E16.2 probe through TRF_Near (team Pirates, cls 3..7, alive).
	TRF_Carcasses = HOST_Carcasses;
	h.carc = {{id=1, cls=3, team="Pirates", hp=100, x=0, y=0, z=0}, {id=2, cls=6, team="Pirates", hp=50, x=1, y=0, z=0},
		{id=3, cls=3, team="Pirates", hp=0, x=2, y=0, z=0}, {id=4, cls=3, team="Trade", hp=10, x=3, y=0, z=0}, {id=5, cls=13, hp=10, x=4, y=0, z=0}};
	n0 = S_Mark();
	TRF_NeProbe("enter");
	HOST_Check(S_Logs(n0, "module=nest event=probe at=enter pirates=2") == 1, "probe: 2 live Pirates ships");
	TRF_Carcasses = nil; h.carc = nil;
	-- Dump.
	TRF.nest = {[gi]={k=3, l=TRF.clock.legs}};
	local n0 = S_Mark();
	TRF_DumpState("test");
	local dl = NE_Line(n0, "module=nest event=dump ");
	HOST_Check(dl and NE_Kv(dl, "record_count") == "1" and NE_Kv(dl, "records") == gi..":3/"..TRF.clock.legs and NE_Kv(dl, "visit") == gi..":1111111111"
		and NE_Kv(dl, "mode") == "nest" and strfind(dl, "counters=n:10,k:0,p:0", 1, 1), "dump line "..tostring(dl));
	-- Repair.
	TRF.nest = 5; TRF_Nest_Fix();
	HOST_Check(type(TRF.nest) == "table" and next(TRF.nest) == nil, "repair: a non-table TRF.nest becomes empty");
	TRF.nest = {[gi]={k=99, l=1}, [ki]={k=1, l=1}, [V_Idx("xb13")]={k=2, l=TRF.clock.legs + 50, c=7}, foo={k=1}, [V_Idx("xt27")]={k=3, l=-5, c=1}};
	TRF.nv = {i=gi, b="10x1"};
	TRF.nst = {n=-1, k=5, p="x"};
	TRF.clan[gs].nk = 500; TRF.clan[gs].nl = 9; TRF.clan[gs].ns = "golkonda";
	TRF_Nest_Fix();
	local x = TRF.nest[V_Idx("xb13")];
	HOST_Check(TRF.nest[gi] == nil and TRF.nest[ki] == nil and TRF.nest.foo == nil and x and x.k == 2 and x.l == TRF.clock.legs and x.c == nil
		and TRF.nest[V_Idx("xt27")].c == 1 and TRF.nest[V_Idx("xt27")].l == -5, "repair: k outside 1..nv, no static data, bad keys dropped; future stamps read now; c only 1");
	HOST_Check(TRF.nv == nil and TRF.nst.n == 0 and TRF.nst.k == 5 and TRF.nst.p == 0 and TRF.clan[gs].nk == nil and TRF.clan[gs].nl == nil
		and TRF.clan[gs].ns == nil, "repair: bad nv, counters, clan fields");
	-- Without map data: the records and the visit are only type-checked.
	local mp = TRF_Map;
	TRF_Map = function() return nil; end;
	TRF.nest = {[gi]={k=3, l=1}};
	TRF.nv = {i=gi, b="101"};
	TRF_Nest_Fix();
	HOST_Check(TRF.nest[gi] and TRF.nest[gi].k == 3 and TRF.nv and TRF.nv.b == "101", "repair without map data: records and visit kept");
	TRF.nest = 5; TRF.nv = 7;
	TRF_Nest_Fix();
	HOST_Check(type(TRF.nest) == "table" and TRF.nv == nil, "repair without map data: wrong types dropped");
	TRF_Map = mp;
	-- cfg enabled 2: trf_state's repair drops the nest fields.
	TRF.nest = {[gi]={k=3, l=1}}; TRF.nv = {i=gi, b="1"}; TRF.nst = {n=1, k=0, p=0};
	TRF.clan[gs].nk = 2; TRF.clan[gs].nl = 3; TRF.clan[gs].ns = gi;
	local en = h.cfg.enabled;
	h.cfg.enabled = 2;
	TRF_Repair();
	h.cfg.enabled = en;
	HOST_Check(TRF.nest == nil and TRF.nv == nil and TRF.nst == nil and TRF.clan[gs].nk == nil and TRF.clan[gs].nl == nil and TRF.clan[gs].ns == nil,
		"enabled 2: TRF.nest, nv, nst and the clan fields dropped");
	-- Save bound: 56 records at their widest (the nest systems without the two excluded ones), a 31-bit visit, the
	-- counters at the cap, nk, nl and ns in every clan record.
	TRF.nest = {};
	local cnt = 0;
	for nm, e in TRF_NestData() do
		if nm ~= "x297" and nm ~= "el_ariash" then
			local idx = V_Idx(nm);
			TRF.nest[idx] = {k=getn(e.f), l=-99999, c=1};
			cnt = cnt + 1;
		end;
	end;
	TRF.nv = {i=V_Idx("xb19"), b=strrep("1", 31)};
	TRF.nst = {n=99999, k=99999, p=99999};
	local sz = HOST_SaveSize(TRF.nest) + HOST_SaveSize(TRF.nv) + HOST_SaveSize(TRF.nst);
	local cz0 = HOST_SaveSize(TRF.clan);
	for k, c in TRF.clan do if type(c) == "table" then c.nk = 99; c.nl = 7; c.ns = 113; end; end;
	local cz = HOST_SaveSize(TRF.clan) - cz0;
	print("HOST info nest worst case: nest="..HOST_SaveSize(TRF.nest).." nv="..HOST_SaveSize(TRF.nv).." nst="..HOST_SaveSize(TRF.nst).." clan fields="..cz);
	TRF_Nest_Fix();
	HOST_Check(cnt == 56 and sz <= 5200 and cz <= 600 and HOST_SaveSize(TRF.nest) + HOST_SaveSize(TRF.nv) + HOST_SaveSize(TRF.nst) == sz,
		"worst case: 56 records, "..sz.." bytes <= 5200 (clan fields "..cz.." <= 600), kept by the repair");
	HOST_Check(HOST_Reserved(TRF, "TRF") == "", "no reserved key");
	TRF.nest = nil; TRF.nv = nil;
	NE_Jump("xb13");
	HOST_Check(T_LeftGlobals() == "" and T_BadCallbacks() == "", "no group global, every callback with the gen");
end;

-- Dispatch ---------------------------------------------------------------------------------

local sc = getenv("TRF_NE") or "";
local fn = getglobal("T_NE_"..strupper(sc));
print("HOST ==== dynamic nests scenario ne-"..sc.." dir="..HOST().dir);
if type(fn) == "function" then
	fn();
	HOST_Check(T_LeftGlobals() == "", "no handle globals left at the end"..T_LeftGlobals());
	local q = T_BadCallbacks();
	HOST_Check(q == "", "every mod callback string carries the current gen"..q);
else
	HOST_Check(nil, "unknown dynamic nests scenario "..sc);
end;
HOST_Check((HOST().gpm_tick or 0) == 0, "no GetPlayerMotherShip from a tick (n="..tostring(HOST().gpm_tick or 0)..")");
print("HOST errors="..HOST().errors.." fails="..HOST().fails);
if HOST().errors > 0 or HOST().fails > 0 then exit(1); end;
exit(0);
