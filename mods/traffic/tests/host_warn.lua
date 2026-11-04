-- Lethal-system warnings scenarios (design/warnings-spec.md 14, A12 step 1) under stock Lua 4.0.1: TRF_WN=a..g, run by
-- run_host.sh as its own entry point. a the list and the pure functions (arming mirror of every row, note bits, the
-- dock order, the texts), b the dock warning at Avalon (dispatcher order, wn_dock, visit and cooldown, inactive, a
-- system without a trade station), c the gates (latch, strict gate, a quest naming the listed system, the flags, a
-- scene, cfg warn 0, wn_ch), d the first-visit notes (due call, arrival queue, seen, cap, load, latch, jump, wn_note 0,
-- an armed kill system, the bits after a save and load), e the save size at its bound and TRF_Wn_Fix, f the jump log
-- (TRF_Wn_BeforeJump) and the portal jump warning (the PORTAL_<X>_Action wrapper: before the box, the original's
-- arguments and result, once, after a load, dest_location, a mod error, a scene, a quest redefinition, wn_jump 0),
-- g trf_warn missing and cfg warn 0.
-- Loads host_station.lua up to its first scenario (stubs of host_stubs.lua, the helpers of host_traffic.lua and
-- host_v02.lua, the DockStation.script stubs and the S_* helpers), as host_survive.lua does. No new native stub:
-- GetQuestLabel reads HOST().labels, GetTeamRelation HOST().rel_team; the portal actions of functions.script are
-- emulated here (W_Portals).

local f = openfile((getenv("TRF_TESTS") or "./").."host_station.lua", "r");
if not f then print("HOST FAIL host_warn.lua: cannot open host_station.lua"); exit(1); end;
local src = read(f, "*a");
closefile(f);
local cut = strfind(src, "\n-- a: install (12.1, 6.1)", 1, 1);
if not cut then print("HOST FAIL host_warn.lua: marker '-- a: install (12.1, 6.1)' missing in host_station.lua"); exit(1); end;
dostring(strsub(src, 1, cut), "host_station.lua");

-- Helpers ----------------------------------------------------------------------------------

-- Config of these runs: the repo defaults with the entry events that would claim lines or slots on their own turned off,
-- plus t.
function W_Cfg(t)
	local c = {sweeps=0, feq=0, staged=0, seed=0, queue=0, parked=0, voice_events=0, dconv=0, carriers=0, po=0,
		enable_survivors=0, enable_scars=0, enable_stashes=0, enable_freight=0};
	if t then for k, v in t do c[k] = v; end; end;
	return c;
end;

-- Relation of team to the player (HOST().rel_team; the stub answers FRIEND for an unknown pair).
function W_Rel(team, rel)
	local h = HOST();
	if type(h.rel_team) ~= "table" then h.rel_team = {}; end;
	h.rel_team[team.."|"..PLAYER_TEAM] = rel;
end;

-- Scenario start in sys at chapter label ch with the relations of the start (Kfni, Vks, Uss, Inoco, Patrol neutral).
function W_Begin(sys, ch, t)
	local h = HOST();
	h.labels = {CurrentQuest=ch or "1"};
	h.quests = {};
	h.rel_team = {};
	W_Rel("Kfni", RELATION_NEUTRAL); W_Rel("Vks", RELATION_NEUTRAL); W_Rel("Uss", RELATION_NEUTRAL);
	W_Rel("Inoco", RELATION_NEUTRAL); W_Rel("Patrol", RELATION_NEUTRAL);
	S_Begin(sys, W_Cfg(t));
end;

-- Trade approach at the first trade station of the current system (dock array rebuilt), any box answered Cancel.
function W_Dock()
	local h = HOST();
	local D = S_Setup();
	if not D.trade[1] then return nil; end;
	local b0 = getn(h.boxes);
	local r = S_Trade(D.trade[1]);
	for i = b0 + 1, getn(h.boxes) do if not h.boxes[i].done then HOST_Press("cancel", h.boxes[i]); end; end;
	return r;
end;

-- Visit flags of trf_warn cleared (a new visit without an entry).
function W_NewVisit()
	local wv = TRF_WnWV();
	wv.w = {}; wv.pr = {}; wv.jw = {}; wv.q = nil;
	S_NewVisit();
end;

-- Per-visit caches of the strict gate (as V_QuestOff), after a change of HOST().quests or qs.
function W_QCache()
	TRF.live.qa = nil; TRF.live.qai = nil; TRF_H().loc = nil; TRF.live.gl = nil;
end;

-- First quest id of system nm in QUEST_PROCESS (a quest naming it), or all off with nil.
function W_Quest(nm, on)
	local h = HOST();
	h.quests = {};
	if on then
		local qi = TRF_Map().sys[V_Idx(nm)].qi;
		h.quests[qi[1]] = QUEST_PROCESS;
	end;
	W_QCache();
end;

-- Row of map name s.
function W_Row(s)
	local by = TRF_WnRows();
	return by[s];
end;

-- Note bit of system nm: 1 or 0.
function W_Bit(nm)
	local t = TRF.wn;
	if type(t) ~= "table" then return 0; end;
	local w, b = TRF_WnBitOf(V_Idx(nm));
	return TRF_Bit(t["v"..w], b);
end;

-- Screen lines after index s0 joined by "|".
function W_Scr(s0)
	local q, s = HOST().screen, "";
	for i = s0 + 1, getn(q) do s = s..q[i].t.."|"; end;
	return s;
end;

function W_Has(s, sub) return strfind(s, sub, 1, 1) ~= nil; end;

-- Index of the first mod log line after n0 matching pat (plain), or nil.
function W_At(n0, pat)
	local q = HOST().logs;
	for i = n0 + 1, getn(q) do if strfind(q[i], pat, 1, 1) then return i; end; end;
	return nil;
end;

-- functions.script of the emulated system: PORTAL_<X>_Action for each map portal (as G/Locations/*/functions.script:
-- dest_location, then the confirm box), compiled under the location's chunk name (TRF_IsMine tests the chunk name),
-- recording its arguments and the screen line count when it ran; extra portal names in HOST().wextra = {{name, dest},
-- ...} (no map entry). Returns "box" as its result.
function W_Portals(sys)
	local h = HOST();
	local m = TRF_Map();
	local s = m.sys[m.by[sys]];
	local l = {};
	for i = 1, getn(s.portals or {}) do tinsert(l, {s.portals[i].name, s.portals[i].to}); end;
	for i = 1, getn(h.wextra or {}) do tinsert(l, h.wextra[i]); end;
	local src = "";
	for i = 1, getn(l) do
		src = src..format("function %s_Action(...) return W_PortalBody(%q, %q, arg); end;\n", l[i][1], l[i][1], l[i][2]);
	end;
	dostring(src, "DATA/Scripts/Locations/"..s.dir.."/functions.script");
end;

function W_PortalBody(nm, to, arg)
	local h = HOST();
	dest_location = to;
	h.wcall = {name=nm, n=arg.n, a1=arg[1], ns=getn(h.screen)};
	ShowMsgBox("#M_teleport_confirm", "#M_teleport_to_"..to, W_PortalOk, W_PortalNo);
	return "box";
end;

function W_PortalOk() HOST().wok = (HOST().wok or 0) + 1; end;
function W_PortalNo() end;

-- The scene of an entry defines the portal actions before TRF_OnEnter (T2b), as functions.script does.
W_Scene0 = T_Scene;
function T_Scene(sys)
	W_Scene0(sys);
	if HOST().wport then W_Portals(sys); end;
end;

-- Portal action global of portal name pn of the current system, or nil.
function W_PA(pn) return getglobal(pn.."_Action"); end;

-- Map portal name of the current system leading to dest, or nil.
function W_PortalTo(dest)
	local m = TRF_Map();
	local s = m.sys[TRF_CurIdx()];
	for i = 1, getn(s.portals or {}) do if s.portals[i].to == dest then return s.portals[i].name; end; end;
	return nil;
end;

-- a: the list and the pure functions (4, 3.1, 5.2, 9) ---------------------------------------

function T_WN_A()
	local h = HOST();
	W_Begin("gredos", "1");
	local d = TRF_WnData();
	local m = TRF_Map();
	local names, dup, miss = {}, "", "";
	for i = 1, getn(d) do
		if names[d[i].s] then dup = dup.." "..d[i].s; end;
		names[d[i].s] = 1;
		if not m.by[d[i].s] then miss = miss.." "..d[i].s; end;
	end;
	HOST_Check(getn(d) == 23 and dup == "" and miss == "", "23 rows, no duplicate, every name in map.script"..dup..miss);
	local cls = {};
	for i = 1, getn(d) do cls[d[i].k] = (cls[d[i].k] or 0) + 1; end;
	HOST_Check(cls.kill == 6 and cls.ambush == 13 and cls.trap == 1 and cls.garrison == 3, "classes: 6 kill, 13 ambush, 1 trap, 3 garrison");
	local W, N, F = RELATION_WAR, RELATION_NEUTRAL, RELATION_FRIEND;
	local A = function(s, lab, rel, cq)
		local q = {lab=lab or {}, rel=rel or {}, cq=cq};
		local a = TRF_WnArmedOf(W_Row(s), q);
		return a == 1;
	end;
	-- Kill rows (LS 3).
	HOST_Check(A("gideon", {}, {Kfni=N}) and not A("gideon", {GideonPermit="yes"}, {Kfni=N}) and not A("gideon", {GideonPermit="no"}, {Kfni=F})
		and A("gideon", {GideonPermit="no"}, {Kfni=W}), "gideon: armed without the permit unless Kfni is FRIEND");
	HOST_Check(A("eridan", {EridanPermit="no"}) and A("eridan", {}) and not A("eridan", {EridanPermit="yes"}), "eridan: armed while EridanPermit is not yes");
	HOST_Check(A("xt86", {}, {Vks=N}) and not A("xt86", {}, {Vks=F}) and not A("xt86", {XT86permit="yes"}, {Vks=N}),
		"xt86: XT86permit nil counts as not yes, Vks FRIEND disarms");
	HOST_Check(A("vulcan", {VulcanPermit="no"}) and not A("vulcan", {VulcanPermit="yes"}) and A("xt24", {}) and not A("xt24", {XT24Permit="yes"})
		and A("zebos", {ZebosPermit="no"}) and not A("zebos", {ZebosPermit="yes"}), "vulcan, xt24, zebos: the permit label only");
	-- USS rows (LS 4.1), El Ariash's CurrentQuest exception.
	local us = {"debris4", "xt11", "fiasar", "ergelan", "xb15", "xb13", "deosis", "el_ariash"};
	local ok = 1;
	for i = 1, getn(us) do
		if not A(us[i], {}, {Uss=W}) or A(us[i], {}, {Uss=N}) or A(us[i], {}, {Uss=F}) then ok = nil; end;
	end;
	HOST_Check(ok, "the eight USS rows: armed exactly while Uss is at war");
	HOST_Check(not A("el_ariash", {CurrentQuest="12d"}, {Uss=W}, "12d") and not A("el_ariash", {}, {Uss=W}, "11_2")
		and A("el_ariash", {}, {Uss=W}, "12") and A("fiasar", {}, {Uss=W}, "12d"),
		"el_ariash off during 12d and 11_2, on during 12; fiasar's always-true guard mirrored (armed during 12d)");
	-- InoCo rows and Hafa (LS 4.2).
	ok = 1;
	local ino = {"xk10", "danstag", "ashelon"};
	for i = 1, getn(ino) do
		if not A(ino[i], {}, {Inoco=N}) or A(ino[i], {}, {Inoco=F}) or A(ino[i], {InocoPermit="yes"}, {Inoco=W}) or not A(ino[i], {InocoPermit="no"}, {Inoco=W}) then ok = nil; end;
	end;
	HOST_Check(ok, "InoCo rows: armed while InocoPermit is not yes and Inoco is not FRIEND");
	HOST_Check(A("hafa", {HafaLife="Vks"}, {Vks=N, Inoco=F}) and not A("hafa", {HafaLife="Vks"}, {Vks=F, Inoco=W})
		and not A("hafa", {HafaLife="none"}, {Vks=W, Inoco=W}) and A("hafa", {}, {Vks=F, Inoco=N})
		and not A("hafa", {InocoPermit="yes"}, {Vks=W, Inoco=N}) and A("hafa", {HafaLife="Inoco"}, {Vks=F, Inoco=W}),
		"hafa: Vks (Vks not FRIEND), none (never), else the InoCo rule");
	-- Beta Lethera 1 (LS 4.3), X244 (LS 5), garrisons (LS 6).
	HOST_Check(not A("b_leftera1", {}, {}, "6") and A("b_leftera1", {}, {}, "5_1") and A("b_leftera1", {}, {}, nil) and A("b_leftera1", {}, {}, "6c"),
		"b_leftera1: armed except while CurrentQuest is exactly 6");
	HOST_Check(A("x244", {Block_X213="yes"}) and not A("x244", {Block_X213="no"}) and not A("x244", {}), "x244: armed only while Block_X213 is yes");
	HOST_Check(A("endoria1", {}, {Vks=W, Patrol=N}) and A("endoria1", {}, {Vks=N, Patrol=W}) and not A("endoria1", {}, {Vks=N, Patrol=F})
		and A("kron", {}, {Patrol=W}) and not A("kron", {}, {Patrol=N}) and A("kassilia", {}, {Kfni=W}) and not A("kassilia", {}, {Kfni=N}),
		"garrisons: armed while one owner team is at war");
	local a, c = TRF_WnArmedOf(W_Row("gideon"), {lab={GideonPermit="no"}, rel={Kfni=N}});
	local a2, c2 = TRF_WnArmedOf(W_Row("el_ariash"), {lab={}, rel={Uss=W}, cq="12"});
	HOST_Check(c == "GideonPermit=no,Kfni=neutral" and c2 == "Uss=war,CurrentQuest=12", "condition strings: "..tostring(c).." / "..tostring(c2));
	-- The accessor reads the labels and relations (fixtures) as the location script does.
	h.labels.GideonPermit = "no";
	local q = TRF_Wn_Q(W_Row("gideon"));
	a = TRF_WnArmedOf(W_Row("gideon"), q);
	h.labels.GideonPermit = "yes";
	local qy = TRF_Wn_Q(W_Row("gideon"));
	HOST_Check(a == 1 and q.lab.GideonPermit == "no" and q.rel.Kfni == N and TRF_WnArmedOf(W_Row("gideon"), qy) == nil,
		"TRF_Wn_Q: GetQuestLabel and GetTeamRelation fixtures");
	h.labels.GideonPermit = nil;
	local gq = GetQuestLabel;
	GetQuestLabel = nil;
	local ne = S_Expect(function() HOST().wq = TRF_Wn_Q(W_Row("gideon")); end);
	GetQuestLabel = gq;
	HOST_Check(h.wq == nil and ne >= 1, "a missing GetQuestLabel: no q (row not armed) and event=error");
	-- Note bits (3.1).
	local bits = {{1, 1, 1}, {40, 1, TRF_WnPow2(39)}, {41, 2, 1}, {80, 2, TRF_WnPow2(39)}, {81, 3, 1}, {113, 3, TRF_WnPow2(32)}};
	ok = 1;
	for i = 1, getn(bits) do
		local w, b = TRF_WnBitOf(bits[i][1]);
		if w ~= bits[i][2] or b ~= bits[i][3] then ok = nil; end;
	end;
	HOST_Check(ok and TRF_WnPow2(39) == 549755813888, "TRF_WnBitOf: idx 1, 40, 41, 80, 81, 113");
	-- Dock order (5.2).
	local cands = {{j=53, rk=4}, {j=44, rk=1}, {j=89, rk=3}, {j=21, rk=2}, {j=11, rk=2}, {j=35, rk=1}};
	local t, cu = TRF_WnPickOf(cands, 3);
	HOST_Check(getn(t) == 3 and t[1].j == 35 and t[2].j == 44 and t[3].j == 11 and getn(cu) == 3 and cu[1].j == 21 and cu[3].j == 53,
		"TRF_WnPickOf: kill, ambush, trap, garrison, then idx; the rest cut");
	HOST_Check(TRF_WnCdOf({[44]=10}, 44, 17, 8) == 1 and TRF_WnCdOf({[44]=10}, 44, 18, 8) == nil and TRF_WnCdOf(nil, 44, 18, 8) == nil,
		"TRF_WnCdOf: cooldown below 8 legs");
	local pc, pd = TRF_WnPruneOf({[44]=10, [53]=2, [7]=10, x=1}, 12, 8, {[44]=1, [53]=1});
	HOST_Check(pc[44] == 10 and pc[53] == nil and pc[7] == nil and pd == 3, "TRF_WnPruneOf: old, unlisted and bad stamps dropped");
	-- Texts (9): every key in the merged EN table, no %, # or newline, $1 only in the family texts.
	local en = TRF_Loc_EN();
	local tx = TRF_Wn_Text();
	local bad = "";
	for i = 1, getn(d) do
		local ks = {d[i].w, d[i].n};
		for k = 1, 2 do
			local s = en[TRF_LocKey(ks[k])];
			local fam = (d[i].w == "wnwuss" or d[i].w == "wnwino") and 1;
			if type(s) ~= "string" or s ~= tx[ks[k]] or strfind(s, "[%%#\n]") or strlen(s) >= 200
				or (strfind(s, "$1", 1, 1) and 1) ~= fam then
				bad = bad.." "..ks[k];
			end;
		end;
	end;
	HOST_Check(bad == "", "texts: every row's keys in TRF_Loc_EN, plain, under 200 characters, $1 only in the family texts"..bad);
	local n = 0;
	for k, v in tx do n = n + 1; end;
	HOST_Check(n == 28 and TRF_Txt("wnwuss", "Debris 4") == "Dockmaster: the USS is at war with you, and the guard in Debris 4 meets every hostile arrival with six heavy flights. Do not jump there before you make peace.",
		"28 text keys; the family text takes the caption as $1");
	-- Registration and defaults.
	HOST_Check(S_Logs(0, "module=core event=loaded map=true module_count=18 extra_count=19") >= 1, "trf_warn loads before trf_remark (extra_count=19)");
	local ml, pm = TRF_ModList(), TRF_PlMods();
	HOST_Check(ml[getn(ml) - 3] == "Wn" and ml[getn(ml) - 2] == "Rm" and pm[getn(pm) - 2] == "Wn" and TRF_Opt("warn") == 1 and TRF_Wn_OptDef().warn == 1,
		"Wn last in TRF_ModList and TRF_PlMods; cfg warn 1 by default");
	local T = TRF_WnTune();
	HOST_Check(T.wn_ch == 0 and T.wn_legs == 8 and T.wn_dock == 2 and T.wn_note == 1 and T.wn_delay == 4 and T.wn_jump == 1 and TRF_Tune().wn_legs == 8,
		"tune defaults wn_ch 0, wn_legs 8, wn_dock 2, wn_note 1, wn_delay 4, wn_jump 1, merged into TRF_Tune");
	h.cfg.tune = {wn_ch=30, wn_legs=0, wn_dock=9, wn_note=4, wn_delay=0.5, wn_jump=-1};
	T = TRF_WnTune();
	HOST_Check(T.wn_ch == 20 and T.wn_legs == 1 and T.wn_dock == 3 and T.wn_note == 1 and T.wn_delay == 1 and T.wn_jump == 0, "tune clamps");
	h.cfg.tune = nil;
	h.cfg.warn = 3;
	HOST_Check(TRF_WnOpt("warn") == 1, "cfg warn outside 0..1 reads as the default");
	h.cfg.warn = nil;
end;

-- b: dock warning (5) ------------------------------------------------------------------------

function T_WN_B()
	local h = HOST();
	W_Begin("avalon", "1");
	local nb = TRF_WnAdj()[TRF_CurIdx()];
	local ls = "";
	for i = 1, getn(nb) do if TRF_WnRows()[TRF_WnName(nb[i])] then ls = ls..TRF_WnName(nb[i]).." "; end; end;
	HOST_Check(ls == "gideon kassilia ", "avalon's listed neighbours: gideon kassilia ("..ls..")");
	-- Gideon armed (no permit, Kfni neutral), Cassily at peace: one line, after the station's greeting.
	local n0 = S_Mark();
	local r = W_Dock();
	local gid = TRF_Txt("wnwgideon");
	HOST_Check(r and r.scr == gid.."|" and S_Logs(n0, "module=warn event=warn system=gideon system_index=44 dock_system=avalon kind=kill condition=\"GideonPermit=nil,Kfni=neutral\" leg=") == 1
		and S_Logs(n0, "module=warn event=dock system=avalon neighbour_count="..getn(nb).." listed=gideon,kassilia shown=gideon skipped=kassilia:inactive") == 1,
		"avalon ch 1: one line for gideon, kassilia inactive ("..tostring(r and r.scr)..")");
	local is, iw = W_At(n0, "module=station event=dock "), W_At(n0, "module=warn event=warn ");
	HOST_Check(is and iw and is < iw and r.nb == 1, "the station's req line (order 10) runs before the warning (order 20); one box");
	local L0 = TRF.clock.legs;
	HOST_Check(TRF.wn.c[44] == L0 and TRF_WnWV().w[44] == 1, "stamp c[44] = legs, visit flag set");
	-- Second approach in the visit: none (visit).
	n0 = S_Mark();
	r = W_Dock();
	HOST_Check(r.scr == "" and S_Logs(n0, "skipped=gideon:visit,kassilia:inactive") == 1, "second approach in the visit: no line (visit)");
	-- Kfni at war: Cassily armed; Gideon still on its flag; a new visit without the stamp shows both, Gideon first.
	W_Rel("Kfni", RELATION_WAR);
	W_NewVisit();
	TRF.wn = nil;
	n0 = S_Mark();
	r = W_Dock();
	HOST_Check(r.scr == gid.."|"..TRF_Txt("wnwkassilia").."|" and S_Logs(n0, "shown=gideon,kassilia") == 1, "Kfni at war: two lines, gideon (kill) before kassilia (garrison)");
	-- wn_dock 1: Gideon only, Cassily cap.
	h.cfg.tune = {wn_dock=1};
	W_NewVisit();
	TRF.wn = nil;
	n0 = S_Mark();
	r = W_Dock();
	HOST_Check(r.scr == gid.."|" and S_Logs(n0, "shown=gideon skipped=kassilia:cap") == 1, "wn_dock 1: gideon only, kassilia cap");
	h.cfg.tune = nil;
	W_Rel("Kfni", RELATION_NEUTRAL);
	-- Jump out and back within 8 legs: cooldown.
	T_Jump("simeiz");
	T_Jump("avalon");
	n0 = S_Mark();
	r = W_Dock();
	HOST_Check(r.scr == "" and S_Logs(n0, "skipped=gideon:cooldown,kassilia:inactive") == 1 and TRF.clock.legs - TRF.wn.c[44] < 8,
		"return within 8 legs: no line (cooldown)");
	-- After 8 legs: the prune drops the stamp and the line comes again.
	TRF.clock.legs = TRF.clock.legs + 8;
	TRF.clock.rt = TRF.clock.legs;
	T_Jump("avalon");
	HOST_Check(TRF.wn == nil or TRF.wn.c == nil, "prune at the entry: the stamp of 8 legs ago is gone");
	n0 = S_Mark();
	r = W_Dock();
	HOST_Check(r.scr == gid.."|" and S_Logs(n0, "module=warn event=warn system=gideon") == 1, "after 8 legs: the line again");
	-- The permit disarms Gideon.
	h.labels.GideonPermit = "yes";
	W_NewVisit();
	TRF.wn = nil;
	n0 = S_Mark();
	r = W_Dock();
	HOST_Check(r.scr == "" and S_Logs(n0, "skipped=gideon:inactive,kassilia:inactive") == 1 and TRF.wn == nil, "GideonPermit yes: no line (inactive), nothing saved");
	h.labels.GideonPermit = nil;
	-- XT-81 has no trade station: no approach, no event=dock.
	T_Jump("xt81");
	n0 = S_Mark();
	r = W_Dock();
	HOST_Check(r == nil and S_Logs(n0, "module=warn event=dock") == 0, "xt81: no trade station, no approach");
	-- A trade dock with no listed neighbour: no event=dock line.
	T_Jump("gredos");
	n0 = S_Mark();
	r = W_Dock();
	HOST_Check(r and S_Logs(n0, "module=warn event=dock") == 0 and S_Logs(n0, "module=warn") == 0, "gredos: no listed neighbour, no warn line");
end;

-- c: gates (5.1) -------------------------------------------------------------------------------

function T_WN_C()
	local h = HOST();
	W_Begin("avalon", "1");
	-- Latch: a mission seen at the approach holds for the rest of the visit.
	h.qs = TRUE;
	local n0 = S_Mark();
	local r = W_Dock();
	h.qs = FALSE;
	local r2 = W_Dock();
	HOST_Check(r.scr == "" and r2.scr == "" and S_Logs(n0, "module=warn event=pass reason=latch at=dock") == 1 and S_Logs(n0, "module=warn event=warn") == 0,
		"latch: no line while and after GetPlayerQuestState was TRUE in the visit; one pass line");
	-- Strict gate on the dock system: a quest naming Avalon in process.
	W_NewVisit();
	W_Quest("avalon", 1);
	n0 = S_Mark();
	r = W_Dock();
	HOST_Check(r.scr == "" and S_Logs(n0, "module=warn event=pass reason=gate:quest at=dock") == 1, "a quest naming the dock system: gate:quest");
	W_Quest("avalon", nil);
	-- A quest naming Gideon (quest_7a) in process: Gideon skipped (quest), Cassily (Kfni at war) still shown.
	W_NewVisit();
	W_Rel("Kfni", RELATION_WAR);
	h.quests = {quest_7a=QUEST_PROCESS};
	W_QCache();
	n0 = S_Mark();
	r = W_Dock();
	HOST_Check(r.scr == TRF_Txt("wnwkassilia").."|" and S_Logs(n0, "shown=kassilia skipped=gideon:quest") == 1, "a quest naming gideon: gideon skipped (quest), kassilia shown");
	h.quests = {};
	W_QCache();
	W_Rel("Kfni", RELATION_NEUTRAL);
	-- Flags: the dispatcher does not call the handler (registered without always).
	TRF.wn = nil;
	W_NewVisit();
	__sys_SOS = TRUE;
	n0 = S_Mark();
	r = W_Dock();
	__sys_SOS = FALSE;
	HOST_Check(r.scr == "" and S_Logs(n0, "module=warn") == 0 and S_Logs(n0, "module=plumb event=dock kind=req") == 1, "__sys_SOS: the handler is skipped, no warn line");
	__disableAction = TRUE;
	n0 = S_Mark();
	r = W_Dock();
	__disableAction = FALSE;
	HOST_Check(r.scr == "" and S_Logs(n0, "module=warn") == 0, "__disableAction: the handler is skipped");
	-- Scene.
	W_NewVisit();
	TRF_InMovie = HOST_InMovie; h.mov = 1;
	n0 = S_Mark();
	r = W_Dock();
	TRF_InMovie = nil; h.mov = nil;
	HOST_Check(S_Logs(n0, "module=warn event=pass reason=scene at=dock") == 1 and S_Logs(n0, "module=warn event=warn") == 0, "scene: pass reason=scene");
	-- cfg warn 0.
	W_NewVisit();
	h.cfg.warn = 0;
	n0 = S_Mark();
	r = W_Dock();
	r2 = W_Dock();
	HOST_Check(r.scr == "" and S_Logs(n0, "module=warn event=pass reason=off at=dock") == 1 and S_Logs(n0, "module=warn") == 1, "cfg warn 0: one pass line, nothing else");
	h.cfg.warn = nil;
	-- wn_ch 4: chapter 3 none, chapter 4 the line.
	h.cfg.tune = {wn_ch=4};
	h.labels.CurrentQuest = "3_2";
	W_NewVisit();
	n0 = S_Mark();
	r = W_Dock();
	HOST_Check(r.scr == "" and S_Logs(n0, "module=warn event=pass reason=chapter at=dock") == 1, "wn_ch 4 in chapter 3: pass reason=chapter");
	h.labels.CurrentQuest = "4_1";
	W_NewVisit();
	n0 = S_Mark();
	r = W_Dock();
	HOST_Check(r.scr == TRF_Txt("wnwgideon").."|", "wn_ch 4 in chapter 4: the line");
	h.cfg.tune = nil;
	-- A module error ends the handler: pass reason=error, the dispatcher goes on (one box).
	W_NewVisit();
	TRF.wn = nil;
	local f0 = TRF_WnSkip;
	TRF_WnSkip = function() error("injected warn error"); end;
	local ne = 0;
	ne = S_Expect(function() HOST().wr = W_Dock(); end);
	TRF_WnSkip = f0;
	HOST_Check(ne >= 1 and h.wr.nb == 1 and h.wr.scr == "" and S_Logs(0, "module=warn event=pass reason=error at=dock") == 1, "an error: event=error, pass reason=error, the box still opens");
end;

-- d: first-visit notes (6) ------------------------------------------------------------------------

function T_WN_D()
	local h = HOST();
	W_Begin("avalon", "1");
	-- Cassily at peace: the due call at 4 s, the arrival line after the entry lines, the bit set.
	local n0 = S_Mark();
	T_Jump("kassilia");
	HOST_Check(S_Logs(n0, "module=warn event=enter system=kassilia system_index=53 listed=true note=due pruned_count=0 latch=false") == 1, "enter kassilia: note=due");
	local s0 = getn(h.screen);
	T_Tick(7, 0.5);
	HOST_Check(S_Logs(n0, "module=warn event=note") == 0, "no note before wn_delay");
	T_Tick(2, 0.5);
	local iq = W_At(n0, "module=plumb event=arrival_line owner=warn ");
	HOST_Check(S_Logs(n0, "module=warn event=note system=kassilia kind=garrison result=queued") == 1 and iq and W_Bit("kassilia") == 1,
		"due at 4 s: note queued, bit set");
	local nq = 0;
	for i = n0 + 1, (iq or 0) - 1 do
		if strfind(h.logs[i], "module=plumb event=arrival_line ", 1, 1) and strfind(h.logs[i], "result=queued", 1, 1) then nq = nq + 1; end;
	end;
	HOST_Check(iq and strfind(h.logs[iq], "line_index="..(nq + 1).." ", 1, 1), "arrival queue order: the note follows the "..nq.." lines queued at entry");
	T_Tick(30, 0.5);
	HOST_Check(W_Has(W_Scr(s0), TRF_Txt("wnnkassilia")), "the note shows as a screen line");
	-- Second entry: seen.
	T_Jump("avalon");
	n0 = S_Mark();
	T_Jump("kassilia");
	T_Tick(30, 0.5);
	HOST_Check(S_Logs(n0, "note=seen") == 1 and S_Logs(n0, "module=warn event=note") == 0, "second entry: note=seen, no note");
	-- The arrival queue full before the due: dropped (cap), bit clear; the next entry queues it.
	n0 = S_Mark();
	T_Jump("deosis");
	local k = 0;
	while TRF_ArrivalLine("host", "filler "..k) do k = k + 1; end;
	T_Tick(10, 0.5);
	HOST_Check(S_Logs(n0, "module=warn event=note system=deosis kind=ambush result=dropped reason=cap") == 1 and W_Bit("deosis") == 0,
		"queue full: dropped reason=cap, bit clear");
	T_Jump("kassilia");
	n0 = S_Mark();
	T_Jump("deosis");
	T_Tick(10, 0.5);
	HOST_Check(S_Logs(n0, "module=warn event=note system=deosis kind=ambush result=queued") == 1 and W_Bit("deosis") == 1, "next entry: queued");
	-- A load in a listed system: no note.
	n0 = S_Mark();
	T_Jump("danstag");
	T_SaveLoad();
	T_Tick(30, 0.5);
	HOST_Check(S_Logs(n0, "module=warn event=note") == 0 and W_Bit("danstag") == 0, "a load before the due: no note, bit clear");
	-- A mission at the due: skipped reason=latch.
	n0 = S_Mark();
	T_Jump("xk10");
	h.qs = TRUE;
	T_Tick(10, 0.5);
	h.qs = FALSE;
	HOST_Check(S_Logs(n0, "module=warn event=note system=xk10 kind=ambush result=skipped reason=latch") == 1 and W_Bit("xk10") == 0, "mission at the due: skipped reason=latch");
	-- A jump before the due: the call is dropped with the generation.
	n0 = S_Mark();
	T_Jump("ashelon");
	T_Tick(2, 0.5);
	T_Jump("moscowia");
	T_Tick(20, 0.5);
	HOST_Check(S_Logs(n0, "module=warn event=note") == 0 and W_Bit("ashelon") == 0, "a jump before the due: no note");
	-- wn_note 0.
	h.cfg.tune = {wn_note=0};
	n0 = S_Mark();
	T_Jump("danstag");
	T_Tick(10, 0.5);
	HOST_Check(S_Logs(n0, "note=off") == 1 and S_Logs(n0, "module=warn event=note") == 0, "wn_note 0: note=off");
	h.cfg.tune = nil;
	-- An armed kill system: the note is queued anyway (decision 4).
	n0 = S_Mark();
	T_Jump("avalon");
	T_Jump("gideon");
	T_Tick(10, 0.5);
	HOST_Check(S_Logs(n0, "module=warn event=note system=gideon kind=kill result=queued") == 1, "armed gideon: the note is queued (decision 4)");
	-- Bits after a save and load.
	local v1, v2, v3 = TRF.wn.v1, TRF.wn.v2, TRF.wn.v3;
	T_SaveLoad();
	HOST_Check(TRF.wn.v1 == v1 and TRF.wn.v2 == v2 and TRF.wn.v3 == v3 and W_Bit("kassilia") == 1 and W_Bit("deosis") == 1 and W_Bit("gideon") == 1
		and W_Bit("xk10") == 0, "bits survive a save and load");
	local w, b = TRF_WnBitOf(53);
	HOST_Check(w == 2 and TRF_Bit(TRF.wn.v2, b) == 1 and b == 4096, "kassilia (53) is word 2, bit 2^12");
end;

-- e: save and repair (3.1, 3.4) -------------------------------------------------------------------

function T_WN_E()
	local h = HOST();
	W_Begin("avalon", "1");
	TRF.clock.legs = 100;
	TRF.clock.rt = 100;
	for i = 1, 113 do TRF_WnNoteSet(i); end;
	local ls = {44, 35, 111, 85, 102, 113};
	for i = 1, 6 do TRF_WnStamp(ls[i], 90 + i); end;
	local sz = HOST_SaveSize(TRF.wn) + 8 + 2;
	print("HOST warn worst case bytes "..sz);
	HOST_Check(sz <= 253 and TRF.wn.v1 == TRF_WnPow2(40) - 1 and TRF.wn.v2 == TRF_WnPow2(40) - 1 and TRF.wn.v3 == TRF_WnPow2(33) - 1,
		"worst case: 113 bits in three words and 6 stamps, "..sz.." <= 253 bytes");
	local seen = 1;
	for i = 1, 113 do if not TRF_WnNoteSeen(i) then seen = nil; end; end;
	HOST_Check(seen, "all 113 bits read back");
	-- A 7th stamp drops the smallest leg.
	TRF_WnStamp(21, 99);
	local n = 0;
	for k, v in TRF.wn.c do n = n + 1; end;
	HOST_Check(n == 6 and TRF.wn.c[44] == nil and TRF.wn.c[21] == 99, "the 7th stamp drops the smallest leg (44 at 91)");
	-- Same legs: the new stamp stays.
	TRF.wn.c = {[44]=50, [35]=50, [111]=50, [85]=50, [102]=50, [113]=50};
	TRF_WnStamp(21, 50);
	HOST_Check(TRF.wn.c[21] == 50 and TRF.wn.c[35] == nil, "ties: the smaller idx goes, never the new one");
	-- Prune after wn_legs.
	TRF.wn.c = {[44]=92, [35]=93};
	TRF.clock.legs = 100;
	local d = TRF_WnPrune();
	HOST_Check(d == 1 and TRF.wn.c[44] == nil and TRF.wn.c[35] == 93, "prune: 92 is 8 legs old at 100 and goes, 93 stays");
	TRF.clock.legs = 101;
	TRF_WnPrune();
	HOST_Check(TRF.wn.c == nil and TRF.wn.v1 ~= nil, "prune: no stamp left, c dropped");
	TRF.wn = {c={[44]=93}};
	TRF_WnPrune();
	HOST_Check(TRF.wn == nil, "prune: an empty TRF.wn is dropped");
	-- Repair (WD4).
	local n0 = S_Mark();
	TRF.wn = "junk";
	TRF_Repair();
	HOST_Check(TRF.wn == nil and S_Logs(n0, "module=warn event=fix field=wn result=dropped") == 1, "fix: a string TRF.wn is dropped");
	n0 = S_Mark();
	TRF.wn = {v1=-1, v2=TRF_WnPow2(41), v3=5, zz=1, c={[999]=1, [44]=TRF.clock.legs + 5, [35]="x"}};
	local tl = {11, 17, 21, 23, 29, 32, 34, 38, 47, 53};
	for i = 1, 10 do TRF.wn.c[tl[i]] = 80 + i; end;
	TRF_Repair();
	local nc = 0;
	for k, v in TRF.wn.c do nc = nc + 1; end;
	HOST_Check(TRF.wn.v1 == nil and TRF.wn.v2 == nil and TRF.wn.v3 == 5 and TRF.wn.zz == nil and nc == 6 and TRF.wn.c[999] == nil
		and TRF.wn.c[44] == nil and TRF.wn.c[35] == nil and TRF.wn.c[53] == 90 and TRF.wn.c[11] == nil and TRF.wn.c[29] == 85,
		"fix: bad words, unknown keys, unlisted idx, future and bad legs dropped; 10 stamps cut to the 6 largest legs");
	HOST_Check(S_Logs(n0, "module=warn event=fix field=v1 result=dropped") == 1 and S_Logs(n0, "module=warn event=fix field=v2 result=dropped") == 1
		and S_Logs(n0, "module=warn event=fix field=zz result=dropped") == 1 and S_Logs(n0, "module=warn event=fix field=c result=dropped dropped_count=7") == 1,
		"fix: event=fix lines");
	local keep = TRF.wn;
	TRF_Repair();
	HOST_Check(TRF.wn.v3 == keep.v3 and S_Logs(n0, "module=warn event=fix") == 4, "fix: a sound TRF.wn is kept without a line");
	-- Dump (log 2).
	h.cfg.log = 2;
	n0 = S_Mark();
	TRF_Wn_Dump();
	h.cfg.log = 1;
	HOST_Check(S_Logs(n0, "module=warn event=dump note_words=0,0,5 stamps=") == 1, "dump at log 2");
	-- Full state of this run.
	local size = 8 + 3 + HOST_SaveSize(TRF);
	print("HOST info TRF save size (warn run) "..size.." bytes, wn="..HOST_SaveSize(TRF.wn));
	HOST_Check(size <= 100000, "full state "..size.." <= 100000");
end;

-- f: jump log (7.1) and the portal jump warning (owner decision 4) ---------------------------------

function T_WN_F()
	local h = HOST();
	h.wport = 1;
	h.wextra = {{"PORTAL_Z", "kassilia"}, {"PORTAL_Y", "gredos"}};
	W_Begin("avalon", "1");
	-- Jump log: TeleportToLocation into an armed Gideon.
	local n0 = S_Mark();
	local s0 = getn(h.screen);
	TeleportToLocation("Gideon");
	HOST_Check(S_Logs(n0, "module=warn event=jump_into system=gideon kind=kill armed=true condition=\"GideonPermit=nil,Kfni=neutral\" how=portal") == 1
		and getn(h.screen) == s0, "jump_into gideon armed=true how=portal; no line");
	T_Enter("gideon");
	h.labels.GideonPermit = "yes";
	n0 = S_Mark();
	TeleportToLocation("avalon");
	TeleportToLocation("gideon");
	HOST_Check(S_Logs(n0, "module=warn event=jump_into system=gideon kind=kill armed=false condition=\"GideonPermit=yes,Kfni=neutral\"") == 1, "with the permit: armed=false");
	h.labels.GideonPermit = nil;
	n0 = S_Mark();
	CustomTeleportate("gideon", "zebos", 1);
	HOST_Check(S_Logs(n0, "module=warn event=jump_into system=zebos kind=kill armed=true condition=\"ZebosPermit=nil\" how=custom") == 1, "CustomTeleportate: how=custom");
	n0 = S_Mark();
	TeleportToLocation("gredos");
	HOST_Check(S_Logs(n0, "module=warn") == 0, "an unlisted destination: nothing");
	T_Enter("avalon");
	-- Portal wrappers installed at T2b over every PORTAL_<X>_Action of avalon (the map's portals and PORTAL_Z).
	local pg = W_PortalTo("gideon");
	HOST_Check(pg ~= nil and TRF_WnIsMine(W_PA(pg)) and TRF_WnWV().pw[pg.."_Action"] == W_PA(pg) and TRF_WnIsMine(W_PA("PORTAL_Z"))
		and V_Logs("module=warn event=jump_install wrapped_count=") >= 1, "wrappers installed at T2b ("..tostring(pg)..")");
	local w0 = W_PA(pg);
	local nw, nsk = TRF_WnInstallJump();
	HOST_Check(nw == 0 and nsk >= 2 and W_PA(pg) == w0, "a second install wraps nothing (once per function)");
	-- The portal to Gideon: the line before the box, the original's arguments and result.
	n0 = S_Mark();
	s0 = getn(h.screen);
	local b0 = getn(h.boxes);
	local res = W_PA(pg)("a1");
	HOST_Check(res == "box" and h.wcall.name == pg and h.wcall.n == 1 and h.wcall.a1 == "a1" and h.wcall.ns == s0 + 1
		and h.screen[s0 + 1].t == TRF_Txt("wnwgideon") and getn(h.boxes) == b0 + 1,
		"portal to gideon: the warning shows before the original opens the box; arguments and result passed through");
	HOST_Check(S_Logs(n0, "module=warn event=jump_warn system=gideon kind=kill portal="..pg.." via=map condition=\"GideonPermit=nil,Kfni=neutral\" result=shown") == 1,
		"event=jump_warn result=shown via=map");
	HOST_Press("cancel");
	-- Again in the visit: no line (visit).
	n0 = S_Mark();
	s0 = getn(h.screen);
	W_PA(pg)();
	HOST_Press("cancel");
	HOST_Check(getn(h.screen) == s0 and S_Logs(n0, "result=skipped reason=visit") == 1, "again in the visit: skipped reason=visit");
	-- A portal without a map entry: the destination from dest_location after the original (Cassily at war).
	W_Rel("Kfni", RELATION_WAR);
	TRF_WnWV().jw = {};
	n0 = S_Mark();
	s0 = getn(h.screen);
	res = W_PA("PORTAL_Z")();
	HOST_Press("cancel");
	HOST_Check(res == "box" and h.wcall.ns == s0 and h.screen[s0 + 1] and h.screen[s0 + 1].t == TRF_Txt("wnwkassilia")
		and S_Logs(n0, "module=warn event=jump_warn system=kassilia kind=garrison portal=PORTAL_Z via=dest_location") == 1,
		"no map entry: dest_location read after the original, the line follows");
	W_Rel("Kfni", RELATION_NEUTRAL);
	-- A portal to an unlisted system: no line, no log at level 1.
	local pn = "PORTAL_Y";
	n0 = S_Mark();
	s0 = getn(h.screen);
	W_PA(pn)();
	HOST_Press("cancel");
	HOST_Check(pn and getn(h.screen) == s0 and S_Logs(n0, "module=warn") == 0, "portal to an unlisted system (gredos, by dest_location): no line");
	-- A mod error never blocks the portal.
	local f0 = TRF_WnJumpPre;
	TRF_WnJumpPre = function() error("injected portal error"); end;
	TRF_WnWV().jw = {};
	local ne = S_Expect(function() HOST().wres = W_PA(%pg)(); end);
	TRF_WnJumpPre = f0;
	HOST_Press("cancel");
	HOST_Check(ne >= 1 and h.wres == "box" and h.wcall.name == pg, "a mod error: event=error, the original still runs");
	-- A scene: skipped.
	TRF_WnWV().jw = {};
	TRF_InMovie = HOST_InMovie; h.mov = 1;
	n0 = S_Mark();
	s0 = getn(h.screen);
	W_PA(pg)();
	TRF_InMovie = nil; h.mov = nil;
	HOST_Press("cancel");
	HOST_Check(getn(h.screen) == s0 and S_Logs(n0, "result=skipped reason=scene") == 1, "a scene: skipped reason=scene");
	-- The flags: skipped.
	__sys_SOS = TRUE;
	n0 = S_Mark();
	W_PA(pg)();
	__sys_SOS = FALSE;
	HOST_Press("cancel");
	HOST_Check(S_Logs(n0, "result=skipped reason=flag") == 1, "__sys_SOS: skipped reason=flag");
	-- A quest naming Gideon in process: skipped (quest).
	h.quests = {quest_7a=QUEST_PROCESS};
	W_QCache();
	n0 = S_Mark();
	W_PA(pg)();
	HOST_Press("cancel");
	h.quests = {};
	W_QCache();
	HOST_Check(S_Logs(n0, "result=skipped reason=quest") == 1, "a quest naming gideon: skipped reason=quest");
	-- A quest script redefines the global after T2b: its function runs unwarned (the documented limit).
	local qf = function() HOST().wqf = 1; end;
	setglobal(pg.."_Action", qf);
	TRF_WnWV().jw = {};
	n0 = S_Mark();
	W_PA(pg)();
	HOST_Check(h.wqf == 1 and S_Logs(n0, "module=warn") == 0, "redefined after T2b: no warning (compared at wrap time only)");
	-- After a load: functions.script defines the vanilla actions again, T2d wraps them.
	T_SaveLoad(function() W_Portals("avalon"); end);
	HOST_Check(TRF_WnIsMine(W_PA(pg)) and TRF_WnWV().pw[pg.."_Action"] == W_PA(pg), "after a load: the actions wrapped again at T2d");
	n0 = S_Mark();
	s0 = getn(h.screen);
	W_PA(pg)();
	HOST_Press("cancel");
	HOST_Check(h.screen[s0 + 1] and h.screen[s0 + 1].t == TRF_Txt("wnwgideon") and S_Logs(n0, "result=shown") == 1, "after a load: the warning shows");
	-- A load without functions.script redefinitions keeps the earlier wrappers (no wrapper of a wrapper).
	w0 = W_PA(pg);
	h.wport = nil;
	T_SaveLoad();
	h.wport = 1;
	HOST_Check(W_PA(pg) == w0, "load: an earlier wrapper is not wrapped again");
	-- The same without a chunk name (getinfo gone): the registry TRF_WnMine still finds the wrapper.
	local gi = getinfo;
	getinfo = nil;
	h.wport = nil;
	T_SaveLoad();
	h.wport = 1;
	getinfo = gi;
	HOST_Check(W_PA(pg) == w0 and TRF_WnMine()[w0] == 1, "load without chunk names: the registry keeps the wrapper unwrapped");
	-- wn_jump 0: nothing installed at the next entry.
	h.cfg.tune = {wn_jump=0};
	T_Jump("avalon");
	HOST_Check(not TRF_WnIsMine(W_PA(pg)) and type(W_PA(pg)) == "function", "wn_jump 0: the vanilla action stays");
	n0 = S_Mark();
	W_PA(pg)();
	HOST_Press("cancel");
	HOST_Check(S_Logs(n0, "module=warn") == 0, "wn_jump 0: no warning");
	h.cfg.tune = nil;
	-- cfg warn 0: nothing installed.
	h.cfg.warn = 0;
	T_Jump("avalon");
	HOST_Check(not TRF_WnIsMine(W_PA(pg)), "warn 0: no wrapper");
	h.cfg.warn = nil;
	h.wport = nil; h.wextra = nil;
end;

-- g: module absent and off ---------------------------------------------------------------------

function T_WN_G()
	local h = HOST();
	h.hide = {["trf_warn.script"]=1};
	W_Begin("avalon", "9_1");
	TRF_SetPro(TRF_CurIdx(), 9);
	HOST_Check(S_Logs(0, "module=core event=loaded map=true module_count=18 extra_count=18") >= 1 and type(TRF_Wn_DockLine) ~= "function",
		"trf_warn missing: extra_count=18, no module");
	local n0 = S_Mark();
	local m0 = getn(h.msgs);
	local r = W_Dock();
	HOST_Check(r.nb == 1 and S_Logs(n0, "module=station event=dock ") == 1 and r.scr == "" and S_Logs(n0, "module=warn") == 0,
		"without trf_warn: the station's req chain runs (one box), no warn line ("..tostring(r.box and r.box.text)..")");
	T_Jump("kassilia");
	T_Tick(30, 0.5);
	HOST_Check(TRF.wn == nil, "without trf_warn: no TRF.wn");
	h.hide = nil;
	-- cfg warn 0.
	W_Begin("avalon", "1", {warn=0});
	n0 = S_Mark();
	r = W_Dock();
	T_Jump("kassilia");
	T_Tick(30, 0.5);
	TeleportToLocation("gideon");
	HOST_Check(TRF.wn == nil and S_Logs(n0, "module=warn event=pass reason=off at=dock") == 1 and S_Logs(n0, "module=warn") == 1,
		"cfg warn 0: no TRF.wn, only the pass line");
end;

-- Dispatch (H3) ------------------------------------------------------------------------------

local sc = getenv("TRF_WN") or "";
local fn = getglobal("T_WN_"..strupper(sc));
print("HOST ==== warn scenario wn-"..sc.." dir="..HOST().dir);
if type(fn) == "function" then
	fn();
	HOST_Check(T_LeftGlobals() == "", "no handle globals left at the end"..T_LeftGlobals());
else
	HOST_Check(nil, "unknown warn scenario "..sc);
end;
HOST_Check((HOST().gpm_tick or 0) == 0, "no GetPlayerMotherShip from a tick (n="..tostring(HOST().gpm_tick or 0)..")");
print("HOST errors="..HOST().errors.." fails="..HOST().fails);
if HOST().errors > 0 or HOST().fails > 0 then exit(1); end;
exit(0);
