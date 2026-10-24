-- Charter goals scenarios (design/charter-spec.md 9) under stock Lua 4.0.1: TRF_CH=a..h, run by run_host.sh as its own
-- entry point. a install, registrations, unlock (chapter 5, help 3), pure pay, rank, seed and dues functions; b
-- generation per type (eligibility rows of TRF_ChCandOf), the pick rules of TRF_ChGenOf, the live dock with the
-- deterministic seed across a simulated reload, the free-roam, heat, Trade and chapter gates, the deny list, slot and
-- region cooldowns; c deed notes (oldest match, visit cap, one Break deed, entry reset, deny list, step 2 kind, the
-- Break world test, raid and base pay points); d close reasons (phase, base, heat 5 and 7, kill with pk and its
-- clear, s41, deadline, mission, chapter 19 suspension) and the close line at the next dock; e pay through the owed
-- payer with the real-time gap, the feeds, rank points, rank up, the rank 2 heat-3 contract perk, the third slot; f the
-- dues box (paid, declined, poor, mission, a higher box first, stale answer) and overdue dues; g logbook reconcile after
-- a simulated ClearQuests (entry, mission, load), stale entry, dump, save/load, repair, TRF.ch at its bound, charter
-- 0; h the 200-leg run of EC.6 (no impossible deadline, no Relief after a forced Bust).
-- Loads host_station.lua up to its first scenario (stubs of host_stubs.lua, the helpers of host_traffic.lua and
-- host_v02.lua, the S_* helpers), as host_ladder.lua does. New stubs in host_stubs.lua: AddQuest, SetQuestState,
-- RemoveQuest, ClearQuests (HOST().quests, HOST().qlog).

local f = openfile((getenv("TRF_TESTS") or "./").."host_station.lua", "r");
if not f then print("HOST FAIL host_charter.lua: cannot open host_station.lua"); exit(1); end;
local src = read(f, "*a");
closefile(f);
local cut = strfind(src, "\n-- a: install (12.1, 6.1)", 1, 1);
if not cut then print("HOST FAIL host_charter.lua: marker '-- a: install (12.1, 6.1)' missing in host_station.lua"); exit(1); end;
dostring(strsub(src, 1, cut), "host_station.lua");

-- Helpers ----------------------------------------------------------------------------------

-- Config: the repo defaults with the entry events that claim slots or spawn on their own off, log 2, plus t.
function C_Cfg(t)
	local c = {sweeps=0, sweep_ct=0, feq=0, staged=0, seed=0, queue=0, parked=0, voice_events=0, dconv=0, carriers=0, po=0, conv=0, log=2};
	if t then for k, v in t do c[k] = v; end; end;
	return c;
end;

-- Scenario start in sys at chapter label ch; help = n unlocks the board at once (an entry hook run).
function C_Begin(sys, ch, help, t)
	local h = HOST();
	h.labels.CurrentQuest = ch or "9_1";
	h.quests = {}; h.qlog = {};
	h.qs = FALSE;
	S_Begin(sys, C_Cfg(t));
	h.credits = 1000000;
	if help then TRF.std.help = help; TRF_Ch_OnActivate(); end;
end;

function C_Slot(name) return TRF_RgOf(V_Idx(name)); end;

-- Every region Quiet at this leg with clan score 10 and no sweep or base, then w = {name = {ph, sc, sl, pt}}.
function C_World(w)
	local L = TRF.clock.legs;
	local m = TRF_RgMap();
	for s = 1, m.n do
		local r = TRF.rg[s];
		r.ph = 0; r.pt = L; r.sl = 0; r.sn = 0; r.sw = 0; r.ct = 0; r.sr = nil;
		TRF.clan[s].sc = 10;
	end;
	TRF.base = {};
	if w then
		for nm, v in w do
			local s = C_Slot(nm);
			TRF.rg[s].ph = v[1]; TRF.clan[s].sc = v[2] or 10; TRF.rg[s].sl = v[3] or 0;
			if v[4] then TRF.rg[s].pt = v[4]; end;
		end;
	end;
end;

-- pro v in every trader system of the region of name (R = v within the caps).
function C_SetR(name, v)
	local m = TRF_RgMap();
	local s = C_Slot(name);
	for i = 1, getn(m[s].sys) do
		local k = m[s].sys[i];
		if m.pc[k] > 0 then TRF_SetPro(k, min(v, m.pc[k])); end;
	end;
end;

-- Trade docking through the wrapper chain (trf_shop thunk -> trf_plumb dispatcher -> vanilla): screen lines (joined
-- by "|"), boxes opened, the newest box.
function C_Dock()
	local h = HOST();
	local s0, b0 = getn(h.screen), getn(h.boxes);
	_param = GetCurrentLocation();
	__TradeStationDock_Ok();
	local r = {scr="", nb=getn(h.boxes) - b0, s0=s0};
	for i = s0 + 1, getn(h.screen) do r.scr = r.scr..h.screen[i].t.."|"; end;
	if r.nb > 0 then r.box = h.boxes[getn(h.boxes)]; end;
	return r;
end;

-- Answer the box of docking r (which = "ok" or "cancel"); screen lines since the docking, joined.
function C_Press(r, which)
	local h = HOST();
	if r.nb > 0 then HOST_Press(which, r.box); end;
	local s = "";
	for i = r.s0 + 1, getn(h.screen) do s = s..h.screen[i].t.."|"; end;
	return s;
end;

function C_Has(s, t) return strfind(s or "", t, 1, 1); end;

-- Posting fixture in slot i: type t in the region of name, posted at leg a, deadline e, fields x; logbook entry added.
function C_Post(i, t, name, a, e, x)
	local C = TRF.ch;
	local ty = TRF_ChTypes()[t];
	local p = {t=t, r=C_Slot(name), f=0, d=0, k=ty.k, p=0, w=0, a=a or TRF.clock.legs, e=e or TRF.clock.legs + 30, st=0, pay=5000,
		rq=ty.rq, l=10};
	if t <= 3 then p.d = 1; end;
	if x then for k, v in x do p[k] = v; end; end;
	C.g[i] = p;
	TRF_ChQAdd(i, p);
	return p;
end;

-- "type:d:e," of a candidate list.
function C_Ts(l)
	local s = "";
	for i = 1, getn(l) do s = s..TRF_ChTypes()[l[i].t].n..":"..l[i].d..":"..l[i].e..","; end;
	return s;
end;

-- Region info fixture for TRF_ChCandOf (phase maxima 10, 20, 14, 18, 10, 10), with the fields of x.
function C_Ri(x, del)
	local r = {r=4, ph=0, pt=0, mx={20, 14, 18, 10, 10; [0]=10}, R=5, L=10, tk=1.5, tier=3, sc=60, ok=1, near=1, swf=0, fst=5,
		dconv=0, dk=1, cap_pay=30000};
	if x then for k, v in x do r[k] = v; end; end;
	if del then for i = 1, getn(del) do r[del[i]] = nil; end; end;
	return r;
end;

-- Postings as "slot:type:region:pay:deadline;".
function C_Board()
	local s = "";
	for i = 1, 3 do
		local p = TRF.ch.g[i];
		if type(p) == "table" then s = s..i..":"..TRF_ChTypes()[p.t].n..":"..p.r..":"..p.pay..":"..p.e..":"..p.st..";"; end;
	end;
	return s;
end;

function C_Open()
	local n = 0;
	for i = 1, 3 do if type(TRF.ch.g[i]) == "table" then n = n + 1; end; end;
	return n;
end;

-- One FTU trader on path A in the current system without a raid, or nil.
function C_Trader()
	V_ClearTr();
	local cur = TRF_CurIdx();
	TRF_SetDis(cur, 0);
	if TRF_Pro(cur) < 4 then TRF_SetPro(cur, 4); end;
	TRF.live.port = {};
	TRF.live.kills = 0;
	local id = T_Spawn("A");
	if id then V_NoRaid(id); end;
	return id;
end;

function C_Rel(team, rel)
	local h = HOST();
	if type(h.rel_team) ~= "table" then h.rel_team = {}; end;
	h.rel_team[team.."|"..PLAYER_TEAM] = rel;
	h.rel_team[PLAYER_TEAM.."|"..team] = rel;
end;

-- Test box candidate at trade prio 300 (the #8 purchase place): a box once per HOST().cb300 = 1.
function C_Box300(kind)
	local h = HOST();
	if h.cb300 ~= 1 then return nil; end;
	h.cb300 = 0;
	return {text="C offer 300", ok="C_BoxOk", own="c300"};
end;
function C_BoxOk(a) return nil; end;

-- a: install, unlock, pure functions ------------------------------------------------------------------

function T_CH_A()
	local h = HOST();
	C_Begin("golkonda", "4_1");
	HOST_Check(S_Logs(0, "module=core event=loaded map=true module_count=18 extra_count=12") >= 1, "trf_charter loads after trf_ladder (extra_count=12 with trf_scar, trf_captain, trf_stash, trf_freight, trf_nest, trf_parcel and trf_merc)");
	local P = TRF_PlReg();
	local lo, bo, ow = "", "", "";
	for i = 1, getn(P.dock.trade.line) do lo = lo..P.dock.trade.line[i].o..","; end;
	for i = 1, getn(P.dock.trade.box) do bo = bo..P.dock.trade.box[i].o..":"..tostring(P.dock.trade.box[i].f)..","; end;
	for i = 1, getn(P.owe) do ow = ow..tostring(P.owe[i].f)..","; end;
	HOST_Check(lo == "10,20,30,60,70,90," and bo == "400:TRF_Pc_DockBox,300:TRF_Fr_DockBox,200:TRF_Ch_DockBox," and C_Has(ow, "TRF_Ch_Owe,"),
		"trade line 70 (between the freight 60 and the rating 80 places), box 200 (after the parcel offer 400 and the freight 300), one owed payer ("..lo.." "..bo.." "..ow..")");
	-- Unlock: chapter 5 and help 3 (design 4).
	TRF.std.help = 9;
	local n0 = S_Mark();
	T_Enter("golkonda");
	HOST_Check(TRF.ch == nil and S_Logs(n0, "module=charter event=unlock chapter=4 help=9 result=locked reason=enter") == 1, "chapter 4: locked");
	h.labels.CurrentQuest = "5_1";
	TRF.std.help = 2;
	T_Enter("golkonda");
	local r = C_Dock();
	HOST_Check(TRF.ch == nil and not C_Has(r.scr, "charter"), "chapter 5, help 2: locked, no charter line");
	TRF.std.help = 3;
	n0 = S_Mark();
	T_Enter("golkonda");
	local L = TRF.clock.legs;
	HOST_Check(type(TRF.ch) == "table" and TRF.ch.on == 1 and TRF.ch.rk == 0 and TRF.ch.sd == L + 7
		and S_Logs(n0, "module=charter event=unlock chapter=5 help=3 seed="..(L + 7).." result=unlocked reason=enter") == 1,
		"chapter 5, help 3: unlocked, seed legs + 7");
	h.cfg.charter = 0;
	HOST_Check(not TRF_ChOn() and TRF_Ch_Note(1, TRF_CurIdx(), 0) == nil and TRF_Ch_Heat3() == nil, "charter 0: module off");
	h.cfg.charter = nil;
	-- Pay (design 2, 5): Golkonda Lanes 0.4 x 900 x 10 x 1.5 x 1.3 = 7020 -> 7000; Kadi 4500; early Lanes 1.4k; late
	-- Break 14.0k; HARD; cap.
	HOST_Check(TRF_ChPayOf(0.4, 10, 8, 1.5, 6, 1, 30000) == 7000 and TRF_ChPayOf(0.4, 10, 8, 1.0, 5, 1, 30000) == 4500
		and TRF_ChPayOf(0.4, 5, 8, 1.0, 5, 1, 30000) == 1400 and TRF_ChPayOf(0.4, 15, 8, 2.0, 6, 1, 30000) == 14000
		and TRF_ChPayOf(0.4, 10, 8, 1.0, 5, 0.7, 30000) == 3200 and TRF_ChPayOf(5, 16, 8, 2.0, 9, 1.25, 30000) == 30000,
		"pay: 7000, 4500, 1400 (L_r / 8 = 0.625), 14000, HARD 3200, capped at pay_cap");
	HOST_Check(TRF_ChRankOf(1, {2, 6, 12, 20, 30}, 3) == 0 and TRF_ChRankOf(9, {2, 6, 12, 20, 30}, 3) == 2 and TRF_ChRankOf(12, {2, 6, 12, 20, 30}, 3) == 3
		and TRF_ChRankOf(30, {2, 6, 12, 20, 30}, 3) == 3 and TRF_ChRankOf(30, {2, 6, 12, 20, 30}, 5) == 5, "rank: thresholds 2, 6, 12, 20, 30, step 1 cap 3");
	HOST_Check(TRF_ChStepOf(1) == 16807 and TRF_ChStepOf(16807) == 282475249 and TRF_ChStepOf(282475249) == 1622650073
		and TRF_ChStepOf(1622650073) == 984943658 and TRF_ChStepOf(2147483646) == 2147466840, "Park-Miller steps exact in doubles");
	HOST_Check(TRF_ChDuesOf(100, {10, 8, 6}, 2) == 2000 and TRF_ChDuesOf(100, {10, 8, 6}, 3) == 3000 and TRF_ChDuesOf(100, {}, 2) == 600
		and TRF_ChDuesOf(100, {16}, 1) == 0, "dues: 100 x L_h x rank, L_h 3 without paid postings, none below rank 2");
	HOST_Check(TRF_ChDuesOf(100, {10, 8, 6}, 2, 0.7) == 1400 and TRF_ChDuesOf(100, {10, 8, 6}, 2, 1.25) == 2500 and TRF_ChDuesOf(100, {}, 3, 0.7) == 630,
		"dues: d_k on the dues (00 A2), HARD 1400, EASY 2500");
	local T = TRF_ChTune();
	HOST_Check(T.ch_pay_gap_rs == 1800 and T.ch_slots[1] == 2 and T.ch_slots[2] == 3 and T.ch_k[2] == 0.3 and T.ch_rank_pts[5] == 30 and T.ch_dues_legs == 24,
		"tune defaults (design 6)");
	h.cfg.tune = {ch_pay_gap_rs=-5, ch_k={0.4, 9}, ch_rank_pts={5, 4, 3, 2, 1}, ch_slots={1, 3}};
	T = TRF_ChTune();
	HOST_Check(T.ch_pay_gap_rs == 0 and T.ch_k[1] == 0.4 and getn(T.ch_k) == 6 and T.ch_rank_pts[1] == 2 and T.ch_slots[1] == 1,
		"tune clamps: gap >= 0, a short list reads the default, thresholds must ascend");
	h.cfg.tune = nil;
	local nt, nd = 0, 0;
	for k, v in TRF_Ch_Text() do
		if strfind(k, "^cht") then nt = nt + 1; end;
		if strfind(k, "^chd%d") then nd = nd + 1; end;
	end;
	HOST_Check(nt == 11 and nd == 13, "11 logbook titles, 13 descriptions ("..nt..", "..nd..")");
end;

-- b: generation ------------------------------------------------------------------------------------------

function T_CH_B()
	local h = HOST();
	C_Begin("golkonda", "9_1", 3);
	local T = TRF_ChTune();
	-- Eligibility rows (design 4 table) with the deadlines of 6.9.
	local w = "";
	local function_rows = {
		{"boom lanes", C_Ri({ph=1}), 0, 0, "lanes:1:34,"},
		{"boom R 3", C_Ri({ph=1, R=3}), 0, 0, ""},
		{"boom heat 3", C_Ri({ph=1}), 0, 3, ""},
		{"boom pk", C_Ri({ph=1, pk=0}), 0, 0, ""},
		{"build-up T3", C_Ri({ph=2}), 0, 0, "lanes:2:14,break:1:36,"},
		{"build-up T2", C_Ri({ph=2, tier=2}), 0, 0, "lanes:2:14,"},
		{"build-up #4 open", C_Ri({ph=2, cap=1}), 0, 0, "lanes:2:14,"},
		{"build-up rb 5 legs", C_Ri({ph=2, rb=-5}), 0, 0, "lanes:2:14,"},
		{"build-up rb 28 legs", C_Ri({ph=2, rb=-28}), 0, 0, "lanes:2:14,break:1:36,"},
		{"raids all", C_Ri({ph=3, tier=4, sw=1, swf=1, fst=4, dconv=1}), 0, 0, "break:2:22,convoy:0:18,sweep:1:18,"},
		{"raids fst 3", C_Ri({ph=3, sw=1, swf=1, fst=3}), 0, 0, "break:2:22,"},
		{"raids FTU sweep", C_Ri({ph=3, sw=1, swf=0}), 0, 0, "break:2:22,"},
		{"raids no attempt", C_Ri({ph=3, swf=2}), 0, 0, "break:2:22,"},
		{"bust", C_Ri({ph=4}), 0, 0, "relief:1:20,"},
		{"recovery", C_Ri({ph=5}), 0, 0, "relief:2:10,"},
		{"recovery heat 3", C_Ri({ph=5}), 0, 3, ""},
		{"base", C_Ri({base=1, bok=1}), 0, 0, "base:0:30,"},
		{"base denied", C_Ri({base=1}), 0, 0, ""},
		{"base rb", C_Ri({base=1, bok=1, rb=0}), 0, 0, ""},
		{"region cooldown", C_Ri({ph=1, rs=-5}), 0, 0, ""},
		{"region cooldown over", C_Ri({ph=1, rs=-20}), 0, 0, "lanes:1:34,"},
		{"all denied", C_Ri({ph=1}, {"ok"}), 0, 0, ""},
		{"deadline 11 legs", C_Ri({ph=2, tier=1}), 3, 0, ""},
		{"deadline 12 legs", C_Ri({ph=2, tier=1}), 2, 0, "lanes:2:14,"}};
	for i = 1, getn(function_rows) do
		local q = function_rows[i];
		local got = C_Ts(TRF_ChCandOf(q[2], T, q[3], q[4]));
		if got ~= q[5] then w = w.." ["..q[1].."] "..got; end;
	end;
	HOST_Check(w == "", "eligibility rows of the six types (design 4 table)"..w);
	local c = TRF_ChCandOf(C_Ri({ph=1}), T, 0, 0)[1];
	local cf = TRF_ChCandOf(C_Ri({ph=1}, {"near"}), T, 0, 0)[1];
	HOST_Check(c.pay == 6800 and c.k == 3 and c.rq == 2 and c.fam == 1 and c.wt == 3 and cf.wt == 1 and c.l == 10,
		"candidate: pay fixed at posting (0.4 x 900 x 10 x 1.5 x 1.25 = 6750 -> 6800), K 3, 2 rank points, weight 3 near, 1 far");
	-- Picks (design 4 steps 1, 3, 4).
	local cs = {{t=1, r=1, fam=1, wt=3}, {t=2, r=2, fam=1, wt=1}, {t=3, r=3, fam=2, wt=3}, {t=6, r=4, fam=2, wt=1}, {t=5, r=5, fam=3, wt=1}};
	local p1, s1 = TRF_ChGenOf(cs, {}, 3, 12345);
	local p2, s2 = TRF_ChGenOf(cs, {}, 3, 12345);
	local fs, rs, same = {}, {}, s1 == s2;
	for i = 1, getn(p1) do fs[p1[i].fam] = (fs[p1[i].fam] or 0) + 1; rs[p1[i].r] = 1; if p1[i] ~= p2[i] then same = nil; end; end;
	HOST_Check(getn(p1) == 3 and fs[1] == 1 and fs[2] == 1 and fs[3] == 1 and same and s1 == TRF_ChStepOf(TRF_ChStepOf(TRF_ChStepOf(12345))),
		"three picks: one per family, distinct regions, same inputs give the same picks and seed");
	local p3 = TRF_ChGenOf(cs, {{r=3, fam=2}}, 2, 777);
	HOST_Check(getn(p3) == 2 and p3[1].fam ~= 2 and p3[2].fam ~= 2 and p3[1].r ~= 3 and p3[2].r ~= 3, "a pirate-family posting open: no second one, its region not posted");
	local p4 = TRF_ChGenOf(cs, {}, 5, 99);
	local np = 0;
	for i = 1, getn(p4) do if p4[i].fam == 2 then np = np + 1; end; end;
	HOST_Check(getn(p4) == 4 and np == 1, "five free slots: four picks, one pirate family");
	local near = 0;
	for sd = 1, 400 do
		local pk = TRF_ChGenOf({{t=1, r=1, fam=1, wt=3}, {t=2, r=2, fam=1, wt=1}}, {}, 1, sd * 7919);
		if pk[1].r == 1 then near = near + 1; end;
	end;
	HOST_Check(near >= 260 and near <= 340, "weights 3 near, 1 far: the near region about 3 in 4 picks ("..near.." of 400)");
	-- Live dock: Golkonda in Build-up (T4), Moscowia in Bust; the other regions Quiet.
	C_World({golkonda={2, 80}, moscowia={4, 20}});
	C_SetR("golkonda", 5);
	local snap = HOST_SaveCopy(TRF);
	local n0 = S_Mark();
	local r = C_Dock();
	local b1 = C_Board();
	HOST_Check(C_Open() == 2 and C_Has(b1, ":"..C_Slot("moscowia")..":") and C_Has(b1, ":"..C_Slot("golkonda")..":") and S_Logs(n0, "module=charter event=post slot=") == 2,
		"dock: two postings, one per region ("..b1..")");
	local g1 = TRF.ch.g[1];
	HOST_Check(h.quests.trf_ch_1 == QUEST_PROCESS and h.quests.trf_ch_2 == QUEST_PROCESS and h.qlog.trf_ch_1.t == TRF_ChTitleKey(g1)
		and h.qlog.trf_ch_1.d == "#TRF_chd"..g1.t..g1.d and h.qlog.trf_ch_3 == nil, "logbook: trf_ch_1 and trf_ch_2 in process, title and description keys");
	HOST_Check(C_Has(r.scr, "FTU charter office: Wolves, Unlisted.|") and C_Has(r.scr, "New posting: Golkonda region.") and C_Has(r.scr, "New posting: Moscowia region.")
		and C_Has(r.scr, " Pays "..TRF.ch.g[1].pay.." cr.|"), "dock lines: office line, two new-posting lines with the fixed pay ("..r.scr..")");
	-- Reload before the dock: the same postings at the same dock (saved seed).
	TRF = HOST_SaveCopy(snap);
	h.quests = {};
	C_Dock();
	HOST_Check(C_Board() == b1, "simulated reload before the dock: the same postings ("..C_Board()..")");
	r = C_Dock();
	HOST_Check(C_Has(r.scr, "|Golkonda region: ") and C_Has(r.scr, " of ") and not C_Has(r.scr, "Moscowia region: "),
		"board line: '<home> region: <deeds> n of k.' for the dock's region at rank 0 ("..r.scr..")");
	-- Gates of the generation: mission (quest_Help not in process), heat 5, Trade W, chapter 19; deny list.
	local gate = "";
	local tries = {{"mission", "qs"}, {"heat", "heat"}, {"trade", "trade"}, {"chapter", "ch"}};
	for i = 1, getn(tries) do
		TRF = HOST_SaveCopy(snap);
		h.quests = {};
		local k = tries[i][2];
		if k == "qs" then h.qs = TRUE; end;
		if k == "heat" then TRF.std.heat = 5; end;
		if k == "trade" then C_Rel("Trade", RELATION_WAR); end;
		if k == "ch" then h.labels.CurrentQuest = "19a"; end;
		C_Dock();
		if C_Open() ~= 0 then gate = gate.." "..tries[i][1]; end;
		h.qs = FALSE; h.rel_team = nil; h.labels.CurrentQuest = "9_1";
	end;
	HOST_Check(gate == "", "no posting during a mission, at heat 5, with Trade at war, in chapter 19"..gate);
	TRF = HOST_SaveCopy(snap);
	h.quests = {quest_Help=QUEST_PROCESS};
	h.qs = TRUE;
	C_Dock();
	HOST_Check(C_Open() == 2, "a Free time window (quest_Help in process) during a mission: postings");
	h.qs = FALSE;
	TRF = HOST_SaveCopy(snap);
	h.quests = {};
	T_Enter("x297");
	n0 = S_Mark();
	r = C_Dock();
	HOST_Check(C_Open() == 0 and not C_Has(r.scr, "charter") and S_Logs(n0, "module=charter event=dock result=none reason=deny") >= 1,
		"denied system (x297): no posting, no line");
	-- Slot and region cooldowns.
	T_Enter("golkonda");
	C_World({golkonda={2, 80}, moscowia={4, 20}});
	C_SetR("golkonda", 5);
	TRF.ch.g = {}; TRF.ch.rs = {}; TRF.ch.rb = {}; TRF.ch.cd = {};
	C_Dock();
	local gs = C_Slot("golkonda");
	local gi = 1;
	if TRF.ch.g[2].r == gs then gi = 2; end;
	local L = TRF.clock.legs;
	TRF_ChClose(TRF.ch, gi, 3, "phase");
	r = C_Dock();
	HOST_Check(TRF.ch.g[gi] == nil and TRF.ch.cd[gi] == L + 4 and C_Open() == 1 and C_Has(r.scr, "FTU charter office: Golkonda posting closed."),
		"closed: line at the next dock, record removed, slot free again 4 legs later, not refilled now");
	TRF.clock.legs = L + 4;
	C_World({golkonda={2, 80}, moscowia={4, 20}});
	n0 = S_Mark();
	C_Dock();
	HOST_Check(C_Open() == 1 and S_Logs(n0, "module=charter event=post candidate_count=0 free_slots=1 result=none") == 1,
		"slot free after 4 legs; Golkonda not posted within ch_region_cd legs, Moscowia already posted: no posting");
	TRF.clock.legs = L + 20;
	C_World({golkonda={2, 80}, moscowia={4, 20}});
	C_Dock();
	HOST_Check(C_Open() == 2 and TRF.ch.g[gi].r == gs and TRF.ch.rs[gs] == L + 20, "20 legs later: Golkonda posted again");
	-- Live region info: L_r, tier_k, pk, rb, base; a #4 entry is never open in step 1.
	TRF.ch.rs[gs] = nil;
	local ri = TRF_ChInfo(TRF.ch, gs, {});
	local ty = C_Ts(TRF_ChCandOf(ri, T, TRF.clock.legs, 0));
	HOST_Check(ri.L >= 3 and ri.L <= 16 and ri.tk == 2.0 and ri.tier == 4 and ri.cap == nil and ri.near == nil and C_Has(ty, "lanes:2:"),
		"region info: L_r "..ri.L..", T4 tier_k 2.0, no #4 entry, far from an empty set ("..ty..")");
	TRF.ch.rb[gs] = TRF.clock.legs;
	TRF.ch.rs[gs] = nil;
	ty = C_Ts(TRF_ChCandOf(TRF_ChInfo(TRF.ch, gs, {}), T, TRF.clock.legs, 0));
	HOST_Check(C_Has(ty, "lanes") and not C_Has(ty, "break"), "a pirate-family posting in the region within 28 legs: no Break ("..ty..")");
	TRF.ch.rb[gs] = nil;
	TRF.base = {{s=V_Idx("xb13"), k=2}};
	ri = TRF_ChInfo(TRF.ch, gs, {});
	ty = C_Ts(TRF_ChCandOf(ri, T, TRF.clock.legs, 0));
	HOST_Check(ri.base == 1 and ri.bok and C_Has(ty, "base:0:"), "active base of the clan: Base candidate ("..ty..")");
	TRF.base = {};
	-- Never posted: the region holding xt23 / xt24 (xt27 on the generated map); Kadi (xk16 a member) is posted.
	HOST_Check(TRF_ChInfo(TRF.ch, C_Slot("xt24"), {}) == nil and C_Slot("xt24") == C_Slot("xt27") and TRF_ChInfo(TRF.ch, C_Slot("kadi"), {}) ~= nil,
		"region of xt23 / xt24 never posted, Kadi with xk16 posted");
	-- The posting text of each type in the dock line comes from its logbook description.
	HOST_Check(TRF_ChTxt("chd60") == TRF_Ch_Text().chd60 and TRF_ChTitleKey({r=gs}) == "#TRF_chtgolkonda", "description and title keys");
end;

-- c: deeds ---------------------------------------------------------------------------------------------

function T_CH_C()
	local h = HOST();
	C_Begin("golkonda", "9_1", 3);
	C_World({golkonda={2, 80}});
	local cur = TRF_CurIdx();
	local gs = C_Slot("golkonda");
	local L = TRF.clock.legs;
	local C = TRF.ch;
	C_Post(1, 3, "golkonda", L - 2);
	C_Post(2, 1, "golkonda", L);
	local n0 = S_Mark();
	TRF_Ch_Note(2, cur, 500);
	HOST_Check(C.g[1].p == 1 and C.g[2].p == 0 and C.vd == 1 and C.vb == 1
		and S_Logs(n0, "module=charter event=note kind=raid system=golkonda region="..gs.." slot=1 done=1 needed=3 visit_deeds=1 amount=500") == 1,
		"raid answered: the oldest matching posting (Break) advances");
	TRF_Ch_Note(2, cur, 500);
	HOST_Check(C.g[1].p == 1 and C.g[2].p == 1 and C.vd == 2, "second raid answer: Break deed used this visit, Lanes advances");
	n0 = S_Mark();
	TRF_Ch_Note(1, cur, 900);
	HOST_Check(C.g[2].p == 1 and S_Logs(n0, "event=note kind=escort system=golkonda region="..gs.." visit_deeds=2 result=none reason=visit_cap") == 1,
		"visit cap: at most ch_visit_deeds (2) deeds per visit");
	T_Enter("golkonda");
	C = TRF.ch;
	HOST_Check(C.vd == 0 and C.vb == 0, "entry resets the visit counters");
	TRF_Ch_Note(4, cur, 0);
	TRF_Ch_Note(1, cur, 0);
	HOST_Check(C.g[1].p == 2 and C.g[2].p == 2, "clan flight -> Break, escort -> Lanes");
	T_Enter("golkonda");
	C = TRF.ch;
	local s0 = getn(h.screen);
	TRF_Ch_Note(1, cur, 0);
	HOST_Check(C.g[2].st == 1 and h.quests.trf_ch_2 == QUEST_DONE and S_Screen(s0, "Charter, Golkonda region: 3 of 3. Collect at any FTU dock."),
		"Lanes 3 of 3: pay owed (st 1), logbook done, completion line");
	s0 = getn(h.screen);
	TRF_Ch_Note(4, cur, 0);
	HOST_Check(C.g[1].p == 3 and C.g[1].st == 0 and S_Screen(s0, "Charter, Golkonda region: 3 of 3. The clan still holds; its strength must break."),
		"Break 3 of 3 without the world test: not complete");
	n0 = S_Mark();
	T_Enter("golkonda");
	C = TRF.ch;
	TRF_Ch_Note(2, cur, 0);
	HOST_Check(C.g[1].p == 3 and S_Logs(n0, "result=none reason=full") == 1, "a full Break takes no more deeds; a done posting none either");
	n0 = S_Mark();
	TRF_Ch_Note(1, V_Idx("x297"), 0);
	TRF_Ch_Note(10, cur, 3000);
	TRF_Ch_Note(1, V_Idx("pandora"), 0);
	HOST_Check(S_Logs(n0, "event=note kind=escort system=x297 result=none reason=deny") == 1 and S_Logs(n0, "event=note kind=10 system=golkonda amount=3000 result=none reason=step2") == 1
		and S_Logs(n0, "event=note kind=escort system=pandora region="..C_Slot("pandora").." visit_deeds=0 result=none reason=nomatch") == 1,
		"deny list, step 2 kind (no change), a region without a posting");
	-- Break world test at the region tick: clan score < 50.
	TRF.clan[gs].sc = 60;
	TRF_Ch_RegionTick(gs, TRF.clock.legs);
	HOST_Check(C.g[1].w == 0 and C.g[1].st == 0, "clan score 60: world test not met");
	TRF.clan[gs].sc = 40;
	n0 = S_Mark();
	TRF_Ch_RegionTick(gs, TRF.clock.legs);
	HOST_Check(C.g[1].w == 1 and C.g[1].st == 1 and h.quests.trf_ch_1 == QUEST_DONE and S_Logs(n0, "event=world slot=1 region="..gs.." clan_score=40") == 1,
		"clan score 40 at a region tick: world test met, Break complete");
	-- World test before the deeds: Break completes with its last deed.
	C.g = {}; C.vd = 0; C.vb = 0;
	C_Post(1, 3, "golkonda", nil, nil, {p=2, w=1});
	TRF_Ch_Note(4, cur, 0);
	HOST_Check(C.g[1].st == 1, "world test met first: the third deed completes the Break");
	-- Pay points of traffic: an answered raid that the player group shot down (8.5 and the clan flight proxy), in
	-- gredos (a system with raid points).
	T_Enter("gredos");
	C = TRF.ch;
	C.g = {}; C.vd = 0; C.vb = 0;
	C_Post(1, 1, "gredos");
	C_Post(2, 3, "gredos", TRF.clock.legs + 1);
	local id = C_Trader();
	local rn = id and V_Raid(id);
	HOST_Check(rn ~= nil, "raid armed on a trader");
	if rn then
		local rd = V_Rd(rn);
		rd.hit = 1;
		rd.st = "fight";
		n0 = S_Mark();
		TRF_Rd_End(rn, "killed");
		HOST_Check(S_Logs(n0, "module=raid event=paid") == 1 and C.g[1].p == 1 and C.g[2].p == 1
			and S_Logs(n0, "event=note kind=raid system=gredos") == 1 and S_Logs(n0, "event=note kind=clan system=gredos") == 1,
			"raid answered (trf_raid TRF_Rd_Pay) -> Lanes, raid flight downed with player fire (TRF_Rd_End) -> Break");
	end;
	-- Base destroyed by the player (trf_base TRF_BaseDestroyed, S39).
	T_Enter("golkonda");
	C = TRF.ch;
	C.g = {}; C.vd = 0; C.vb = 0;
	TRF.base = {{s=V_Idx("xb13"), k=2, t=0, h=0, w=0}};
	C_Post(3, 6, "golkonda");
	n0 = S_Mark();
	TRF_BaseDestroyed(V_Idx("xb13"), "player");
	HOST_Check(C.g[3].st == 1 and S_Logs(n0, "event=note kind=base system=xb13 region="..gs.." slot=3 done=1 needed=1") == 1,
		"base destroyed by the player: Base posting complete");
	TRF.base = {};
end;

-- d: close reasons --------------------------------------------------------------------------------------

function T_CH_D()
	local h = HOST();
	C_Begin("golkonda", "9_1", 3);
	C_World({golkonda={2, 80}, moscowia={4, 20}, kadi={3, 95}});
	local C = TRF.ch;
	local gs, ms, ks = C_Slot("golkonda"), C_Slot("moscowia"), C_Slot("kadi");
	local L = TRF.clock.legs;
	-- Phase: Lanes when Golkonda enters Raids (through trf_region's region tick), Relief at Quiet, Convoy and Sweep
	-- after Raids, Base without an active base.
	C_Post(1, 1, "golkonda");
	C_Post(2, 2, "moscowia");
	C_Post(3, 4, "kadi");
	TRF.rg[gs].ph = 3;
	TRF.rg[ms].ph = 5;
	local n0 = S_Mark();
	TRF_RegionTick(TRF.clock.legs);
	HOST_Check(C.g[1].st == 3 and C.g[1].c == "phase" and h.quests.trf_ch_1 == QUEST_FAILED and C.cd[1] == L + 4 and C.tot.w == 1
		and C.g[2].st == 0 and C.g[3].st == 0 and S_Logs(n0, "module=charter event=close slot=1 type=lanes region="..gs.." done=0 needed=3 state=3 reason=phase") == 1,
		"Golkonda in Raids (TRF_RegionTick -> TRF_Ch_RegionTick): Lanes withdrawn; Relief in Recovery and Convoy in Raids stay");
	TRF.rg[ms].ph = 0;
	TRF.rg[ks].ph = 4;
	TRF_Ch_RegionTick(ms, L);
	TRF_Ch_RegionTick(ks, L);
	HOST_Check(C.g[2].st == 3 and C.g[3].st == 3, "Relief at Quiet, Convoy after Raids: withdrawn");
	local r = C_Dock();
	HOST_Check(C_Has(r.scr, "FTU charter office: Golkonda posting closed. The clan is raiding now.|") and C_Has(r.scr, "Moscowia posting closed. Trade there is back on its feet.|")
		and C_Has(r.scr, "Kadi posting closed. The raids there are over.|") and C_Open() == 0 and h.quests.trf_ch_1 == nil and h.quests.trf_ch_3 == nil,
		"close lines at the next trade dock, records and logbook entries removed ("..r.scr..")");
	C.cd = {};
	C_World({golkonda={2, 80}, kadi={3, 95}});
	C_Post(1, 6, "golkonda");
	C_Post(2, 5, "kadi", nil, nil, {f=1, d=1});
	TRF.rg[ks].ph = 4;
	TRF_Ch_RegionTick(gs, L);
	TRF_Ch_RegionTick(ks, L);
	HOST_Check(C.g[1].st == 3 and C.g[1].c == "base" and C.g[2].st == 3, "Base without an active base, Sweep after Raids: withdrawn");
	C.g = {}; C.cd = {};
	-- Heat 5: trade family closes (failed), Break stays; heat 7: rank -1 once per blacklisting and every posting closes.
	C_World({golkonda={2, 80}, kadi={3, 95}});
	C_Post(1, 1, "golkonda");
	C_Post(2, 3, "kadi");
	C.rk = 2; C.rp = 7; C.du = L + 24;
	TRF.std.heat = 5;
	TRF_Ch_RegionTick(1, L);
	HOST_Check(C.g[1].st == 2 and C.g[1].c == "heat" and C.g[2].st == 0 and C.rk == 2 and C.tot.f == 1, "heat 5: Lanes failed, Break stays, rank kept");
	TRF.std.heat = 7;
	n0 = S_Mark();
	TRF_Ch_RegionTick(1, L);
	TRF_Ch_RegionTick(1, L);
	HOST_Check(C.g[2].st == 2 and C.rk == 1 and C.rp == 2 and C.du == 0 and C.hx == 1 and S_Logs(n0, "event=rank rank_before=2 rank=1 rank_points=2 dues_leg=0 result=down reason=heat") == 1,
		"heat 7: Break failed, rank -1 once (points to the rank-1 threshold, no dues below rank 2)");
	TRF.std.heat = 4;
	TRF_Ch_RegionTick(1, L);
	TRF.std.heat = 7;
	TRF_Ch_RegionTick(1, L);
	HOST_Check(C.rk == 0 and C.hx == 1, "heat back below 7 and up again: a second blacklisting, rank -1 again");
	TRF.std.heat = 0;
	TRF_Ch_RegionTick(1, L);
	C.g = {}; C.cd = {};
	-- Player trader kill in Golkonda (trf_events heat kill event): Lanes there fails, pk[r] set, Break stays; no Lanes or
	-- Relief there until a Quiet entered after the stamp and ch_pk_legs legs.
	C_World({golkonda={2, 80}});
	C_SetR("golkonda", 5);
	C_Post(1, 1, "golkonda");
	C_Post(2, 3, "golkonda");
	C_Post(3, 2, "moscowia");
	local id = C_Trader();
	HOST_Check(id ~= nil, "FTU trader spawned");
	if id then
		n0 = S_Mark();
		V_PlayerKill(id);
		HOST_Check(C.g[1].st == 2 and C.g[1].c == "kill" and C.g[2].st == 0 and C.g[3].st == 0 and C.pk[gs] == TRF.clock.legs
			and S_Logs(n0, "event=note kind=kill system=golkonda region="..gs.." player_kill_leg="..TRF.clock.legs.." closed_count=1 result=marked") == 1,
			"player trader kill: Lanes in that region failed, Break and other regions stay, pk set");
	end;
	local pk = C.pk[gs] or L;
	local ty = C_Ts(TRF_ChCandOf(TRF_ChInfo(C, gs, {}), TRF_ChTune(), TRF.clock.legs, 0));
	HOST_Check(not C_Has(ty, "lanes"), "pk set: no Lanes in the region ("..ty..")");
	TRF.rg[gs].ph = 0; TRF.rg[gs].pt = pk - 1;
	TRF_Ch_RegionTick(gs, pk + 30);
	HOST_Check(C.pk[gs] == pk, "Quiet entered before the stamp: pk kept");
	TRF.rg[gs].pt = pk + 2;
	TRF_Ch_RegionTick(gs, pk + 27);
	HOST_Check(C.pk[gs] == pk, "Quiet after the stamp, 27 legs: pk kept");
	n0 = S_Mark();
	TRF_Ch_RegionTick(gs, pk + 28);
	HOST_Check(C.pk[gs] == nil and S_Logs(n0, "event=player_kill_clear region="..gs) == 1, "Quiet after the stamp and 28 legs: pk cleared");
	-- S41 (trf_convoy TRF_ForcedBust): rank -1, every posting closes, pk set.
	C.g = {}; C.cd = {};
	C.rk = 2; C.rp = 7; C.du = TRF.clock.legs + 24;
	C_World({golkonda={1, 40}});
	C_Post(1, 1, "golkonda");
	C_Post(2, 2, "moscowia");
	n0 = S_Mark();
	TRF_ForcedBust(V_Idx("golkonda"), "test");
	HOST_Check(C.g[1].st == 2 and C.g[1].c == "s41" and C.g[2].st == 2 and C.rk == 1 and C.pk[gs] == TRF.clock.legs
		and S_Logs(n0, "event=note kind=s41 system=golkonda region="..gs) == 1, "forced Bust flag (S41): all postings failed, rank -1, pk set");
	-- Deadlines: failed in free roam, withdrawn while a mission runs ("FTU withdrew ..." at the dock).
	C.g = {}; C.cd = {};
	C_World({golkonda={2, 80}, moscowia={4, 20}});
	L = TRF.clock.legs;
	C_Post(1, 1, "golkonda", L, L + 1);
	C_Post(2, 2, "moscowia", L, L + 1);
	TRF_Ch_RegionTick(1, L);
	HOST_Check(C.g[1].st == 0, "before the deadline: open");
	h.qs = TRUE;
	TRF_Ch_RegionTick(1, L + 1);
	h.qs = FALSE;
	HOST_Check(C.g[1].st == 3 and C.g[1].c == "mission" and C.g[2].c == "mission", "deadline during a mission: withdrawn, no failure");
	r = C_Dock();
	HOST_Check(C_Has(r.scr, "FTU withdrew the Golkonda posting while you were on contract elsewhere.|"), "mission withdrawal line");
	C.cd = {};
	C_Post(1, 1, "golkonda", L, L + 1);
	local f0 = C.tot.f;
	TRF_Ch_RegionTick(1, L + 1);
	HOST_Check(C.g[1].st == 2 and C.g[1].c == "deadline" and C.tot.f == f0 + 1, "deadline in free roam: failed");
	C.g = {}; C.cd = {};
	-- Chapter 19: open postings withdrawn, owed pay still paid, no dues, perks on, no new posting.
	C_Post(1, 1, "golkonda");
	C_Post(2, 2, "moscowia", nil, nil, {p=2, st=1, pay=3400});
	C.rk = 2; C.du = TRF.clock.legs - 30;
	h.labels.CurrentQuest = "19a";
	TRF_Ch_RegionTick(1, TRF.clock.legs);
	HOST_Check(C.g[1].st == 3 and C.g[1].c == "chapter" and C.g[2].st == 1 and C.rk == 2 and TRF_ChPaid(C) and TRF_Ch_Heat3() == 1,
		"chapter 19: open posting withdrawn, owed pay kept, no dues rank loss, perks on");
	local c0 = h.credits;
	r = C_Dock();
	HOST_Check(h.credits == c0 + 3400 and r.nb == 0 and C_Open() == 0 and C_Has(r.scr, "The office closed the board.") and not C_Has(r.scr, "FTU charter office: Wolves"),
		"chapter 19 dock: owed pay paid, no dues box, no new posting, no office line ("..r.scr..")");
	h.labels.CurrentQuest = "9_1";
end;

-- e: pay, rank, perks -----------------------------------------------------------------------------------

function T_CH_E()
	local h = HOST();
	C_Begin("golkonda", "9_1", 3);
	C_World({});
	local C = TRF.ch;
	local L = TRF.clock.legs;
	C.rk = 2; C.rp = 7; C.du = L + 24;
	C_Post(1, 1, "golkonda", L - 2, nil, {p=3, st=1, pay=7000, l=10});
	C_Post(2, 2, "moscowia", L - 1, nil, {p=2, st=1, pay=3400, l=12});
	TRF_ChQSet(1, QUEST_DONE); TRF_ChQSet(2, QUEST_DONE);
	TRF.rg[C_Slot("moscowia")].ph = 5;
	local c0, h0 = h.credits, TRF.std.help;
	local rs0 = TRF_RealSecs();
	local n0 = S_Mark();
	local r = C_Dock();
	HOST_Check(h.credits == c0 + 7000 and C.g[1] == nil and h.quests.trf_ch_1 == nil and C.g[2].st == 1 and C.rp == 9 and C.pt == rs0 and C.lh[1] == 10
		and TRF.std.help == h0 + 1, "first owed posting paid (oldest): 7000 cr, removed, 2 rank points, lh, help +1");
	HOST_Check(C_Has(r.scr, "FTU charter office: Golkonda posting complete. 7000 cr to the Wolves.|Charter standing: 9 of 12 to Bonded carrier.|FTU charter office: Moscowia posting complete. Payment is being processed.|")
		and C_Has(r.scr, "FTU charter office: Wolves, Contracted carrier. Dues are paid up.|"), "pay, standing and wait lines, then the office line ("..r.scr..")");
	HOST_Check(S_Logs(n0, "module=charter event=pay slot=1 type=lanes region="..C_Slot("golkonda").." amount=7000 rank=2 rank_points=9 help=1") == 1
		and S_Logs(n0, "module=charter event=pay_wait slot=2 real_seconds="..floor(rs0).." paid_real_seconds="..floor(rs0).." gap=1800") == 1
		and S_Logs(n0, "module=region event=pay reason=charter amount=7000") == 1, "pay and pay_wait log lines, TRF_Pay reason charter");
	-- Real time: game time and legs do not count, only dt_real while unpaused (TRF.clock.rs).
	TRF_OnTick(4.0, 0.5); TRF_OnTick(4.0, 0.5); TRF_OnTick(0, 30);
	HOST_Check(TRF_RealSecs() == rs0 + 1, "8x ticks add real seconds only, a paused tick adds none");
	TRF.clock.rs = rs0 + 1799;
	c0 = h.credits;
	C_Dock();
	HOST_Check(h.credits == c0 and C.g[2].st == 1, "1799 s later: still waiting");
	TRF.clock.rs = rs0 + 1800;
	h0 = TRF.std.help;
	C_Dock();
	HOST_Check(h.credits == c0 + 3400 and C.g[2] == nil and C.rp == 11 and C.rk == 2 and TRF.std.help == h0 + 2 and C.lh[1] == 12 and C.lh[2] == 10,
		"1800 s after the last payment: second posting paid, help +2 (Recovery)");
	-- Rank up to 3: line, third slot.
	C_Post(1, 3, "kadi", nil, nil, {p=3, w=1, st=1, pay=9000, l=14});
	local ks = C_Slot("kadi");
	TRF.clan[ks].sc = 60;
	TRF.clock.rs = TRF.clock.rs + 1800;
	n0 = S_Mark();
	r = C_Dock();
	HOST_Check(C.rk == 3 and C.rp == 14 and TRF_ChSlots(C) == 3 and C_Has(r.scr, "Charter standing: Bonded carrier. The board holds three postings for you.|")
		and TRF.clan[ks].sc == 57 and S_Logs(n0, "event=rank rank_before=2 rank=3 rank_points=14") == 1,
		"Break paid: clan score -3, 3 rank points, rank 3 (Bonded carrier) and the third slot");
	-- Rank points are not given while the dues are unpaid; the third slot needs the dues too.
	C.du = TRF.clock.legs;
	HOST_Check(not TRF_ChPaid(C) and TRF_ChSlots(C) == 2 and TRF_ChPoints(C, 3) == nil and C.rp == 14, "dues unpaid: no points, two slots");
	C.du = TRF.clock.legs + 24;
	-- Rank 0 -> 1 -> 2 from points; dues start at rank 2 with the first period included.
	C.rk = 0; C.rp = 0; C.du = 0;
	TRF_ChPoints(C, 2);
	HOST_Check(C.rk == 1 and C.du == 0, "2 points: Listed carrier, no dues");
	TRF_ChPoints(C, 4);
	HOST_Check(C.rk == 2 and C.du == TRF.clock.legs + 24, "6 points: Contracted carrier, dues due in 24 legs");
	-- No pay under the flags or at a denied system.
	C_Post(1, 1, "golkonda", nil, nil, {p=3, st=1, pay=7000});
	TRF.clock.rs = TRF.clock.rs + 1800;
	c0 = h.credits;
	__sys_SOS = TRUE;
	C_Dock();
	__sys_SOS = FALSE;
	T_Enter("x297");
	C_Dock();
	HOST_Check(h.credits == c0 and C.g[1].st == 1, "no payment under __sys_SOS or at a denied system (owed pay waits)");
	T_Enter("golkonda");
	C = TRF.ch;
	C.g = {};
	-- Rank 2 perk: an FTU trader offers its escort contract at heat 3; not without the perk, not at heat 4.
	local id = C_Trader();
	HOST_Check(id ~= nil, "FTU trader on path A");
	if id then
		TRF.live.tr[id].co = 1;
		TRF.std.heat = 3;
		C.rk = 2; C.du = TRF.clock.legs + 24;
		local o1 = TRF_CtOffer(id);
		local opts = TRF_HlCh3Opts(id, TRF.live.tr[id]);
		C.du = TRF.clock.legs;
		local o2, w2 = TRF_CtOffer(id);
		C.du = TRF.clock.legs + 24;
		C.rk = 1;
		local o3 = TRF_CtOffer(id);
		C.rk = 2;
		TRF.std.heat = 4;
		local o4, w4 = TRF_CtOffer(id);
		TRF.std.heat = 2;
		local o5 = TRF_CtOffer(id);
		HOST_Check(type(o1) == "string" and type(opts) == "table" and getn(opts) == 1 and opts[1] == "esc" and o2 == nil and w2 == "heat" and o3 == nil
			and o4 == nil and w4 == "heat" and type(o5) == "string", "rank 2 perk: contract at heat 3 (only the escort option), not with dues unpaid, not at rank 1 or heat 4");
		TRF.std.heat = 3;
		local s0 = getn(h.screen);
		local res = TRF_HailOpen(id, "test");
		HOST_Check(res == "menu" and S_Screen(s0, "Your charter papers check out. Fine.") and TRF.live.hl.o[1] == "esc" and getn(TRF.live.hl.o) == 1,
			"heat 3 hail with the perk: the papers line, the contract menu only");
		TRF_HlClose("test");
		TRF.std.heat = 0;
		TRF_Remove(id, "test");
	end;
end;

-- f: dues ----------------------------------------------------------------------------------------------

function T_CH_F()
	local h = HOST();
	C_Begin("golkonda", "9_1", 3);
	C_World({});
	local C = TRF.ch;
	local L = TRF.clock.legs;
	C.rk = 2; C.rp = 6; C.du = L; C.lh = {10, 8, 6};
	local t0 = h.trade_ok;
	local n0 = S_Mark();
	local r = C_Dock();
	HOST_Check(r.nb == 1 and r.box.text == "FTU charter office: dues for the Wolves, Contracted carrier: 2000 cr. Pay now?" and h.trade_ok == t0
		and C_Has(r.scr, "FTU charter office: Wolves, Contracted carrier. Dues of 2000 cr are due.|")
		and S_Logs(n0, "module=charter event=dues rank=2 dues_leg="..L.." leg="..L.." amount=2000 result=offered") == 1,
		"dues due: box (100 x L_h 10 x rank 2), office line, trade dialog after the answer");
	local c0 = h.credits;
	local s = C_Press(r, "ok");
	HOST_Check(h.credits == c0 - 2000 and C.du == L + 24 and h.trade_ok == t0 + 1 and C_Has(s, "Dues paid. The charter is in good standing.|"),
		"OK: 2000 cr paid, dues through 24 legs, the trade dialog follows");
	r = C_Dock();
	HOST_Check(r.nb == 0, "paid up: no box");
	-- Cancel: not again this visit; again after an entry.
	C.du = TRF.clock.legs;
	r = C_Dock();
	C_Press(r, "cancel");
	local r2 = C_Dock();
	HOST_Check(r.nb == 1 and r2.nb == 0, "Cancel: no second dues box in this visit");
	T_Enter("golkonda");
	C = TRF.ch;
	r = C_Dock();
	HOST_Check(r.nb == 1, "next visit: the dues box again");
	-- Poor.
	h.credits = 100;
	local du0 = C.du;
	s = C_Press(r, "ok");
	HOST_Check(h.credits == 100 and C.du == du0 and C_Has(s, "Not enough credits for the dues."), "not enough credits: nothing paid");
	h.credits = 1000000;
	-- Never during a mission.
	T_Enter("golkonda");
	C = TRF.ch;
	h.qs = TRUE;
	n0 = S_Mark();
	r = C_Dock();
	h.qs = FALSE;
	HOST_Check(r.nb == 0 and S_Logs(n0, "event=dues rank=2 dues_leg="..C.du.." leg="..TRF.clock.legs.." result=none reason=mission") == 1, "mission active: no dues box");
	-- A higher box (the #8 purchase place, 300) wins; the dues wait for the next docking.
	TRF_DockBox("trade", 300, "C_Box300");
	h.cb300 = 1;
	r = C_Dock();
	HOST_Check(r.nb == 1 and r.box.text == "C offer 300", "prio 300 box first, one box per docking");
	C_Press(r, "ok");
	r = C_Dock();
	HOST_Check(r.nb == 1 and C_Has(r.box.text, "dues for the Wolves"), "next docking: the dues box");
	-- Stale answer after a load.
	T_SaveLoad();
	C = TRF.ch;
	c0 = h.credits;
	n0 = S_Mark();
	C_Press(r, "ok");
	HOST_Check(h.credits == c0 and S_Logs(n0, "module=charter event=dues result=stale") == 1, "answer from before a load: nothing paid");
	-- Overdue: rank -1 at 24 legs past due, then per further 24 legs; below rank 2 no dues.
	T_Enter("golkonda");
	C = TRF.ch;
	L = TRF.clock.legs;
	C.rk = 3; C.rp = 14; C.du = L;
	TRF_Ch_RegionTick(1, L + 23);
	HOST_Check(C.rk == 3, "23 legs past due: rank kept, perks suspended");
	n0 = S_Mark();
	TRF_Ch_RegionTick(1, L + 24);
	HOST_Check(C.rk == 2 and C.rp == 6 and C.du == L + 24 and S_Logs(n0, "event=dues rank=3 dues_leg="..(L + 24).." leg="..(L + 24).." result=overdue") == 1
		and S_Logs(n0, "result=down reason=dues") == 1, "24 legs past due: rank -1, points to the rank-2 threshold");
	TRF_Ch_RegionTick(1, L + 47);
	HOST_Check(C.rk == 2, "47 legs: no second loss yet");
	TRF_Ch_RegionTick(1, L + 48);
	HOST_Check(C.rk == 1 and C.du == 0 and C.rp == 2, "48 legs: rank 1, no dues");
end;

-- g: reconcile, dump, save/load, repair, bound ------------------------------------------------------------

function T_CH_G()
	local h = HOST();
	C_Begin("golkonda", "9_1", 3);
	C_World({golkonda={2, 80}, moscowia={4, 20}});
	C_SetR("golkonda", 5);
	C_Dock();
	local C = TRF.ch;
	C.g[2].st = 1;
	TRF_ChQSet(2, QUEST_DONE);
	-- ClearQuests (EC.3): entries gone; the next free-roam entry adds them again, the done state too.
	ClearQuests();
	local n0 = S_Mark();
	T_Enter("golkonda");
	C = TRF.ch;
	HOST_Check(h.quests.trf_ch_1 == QUEST_PROCESS and h.quests.trf_ch_2 == QUEST_DONE and h.qlog.trf_ch_1.t == TRF_ChTitleKey(C.g[1])
		and S_Logs(n0, "module=charter event=reconcile id=trf_ch_1 quest_state=3 readd=1 reason=enter") == 1, "reconcile at entry after ClearQuests: entries added again");
	-- During a mission: logged, added at the next free-roam entry.
	ClearQuests();
	h.qs = TRUE;
	n0 = S_Mark();
	T_Enter("golkonda");
	HOST_Check(h.quests.trf_ch_1 == nil and S_Logs(n0, "event=reconcile id=trf_ch_1 quest_state=3 readd=0 reason=enter") == 1, "mission: no re-add");
	h.qs = FALSE;
	T_Enter("golkonda");
	C = TRF.ch;
	HOST_Check(h.quests.trf_ch_1 == QUEST_PROCESS, "next free-roam entry: re-added");
	-- Load: reconcile, no generation; a stale entry without a record is removed.
	ClearQuests();
	h.quests.trf_ch_3 = QUEST_PROCESS;
	local b0 = C_Board();
	n0 = S_Mark();
	T_SaveLoad();
	C = TRF.ch;
	HOST_Check(C_Board() == b0 and h.quests.trf_ch_1 == QUEST_PROCESS and h.quests.trf_ch_3 == nil and S_Logs(n0, "event=reconcile id=trf_ch_1 quest_state=3 readd=1 reason=load") == 1
		and S_Logs(n0, "event=reconcile id=trf_ch_3 quest_state=2 removed=1 reason=load") == 1 and S_Logs(n0, "module=charter event=post") == 0 and TRF_ChCV().dk == 0,
		"load: postings kept, entries re-added, stale trf_ch_3 removed, no generation, visit state reset");
	-- Dump.
	C.pk[4] = 180; C.lh = {10, 8, 6}; C.pt = 13100;
	n0 = S_Mark();
	TRF_DumpState("test");
	HOST_Check(S_Logs(n0, "module=charter event=dump on=1 rank=0 rank_points=0 dues_leg=0 real_seconds=") == 1 and S_Logs(n0, " paid_real_seconds=13100 lh=10/8/6 visit_deeds=0 visit_break=0 count=2 seed=") == 1
		and S_Logs(n0, " slots=2 done=0 failed=0 withdrawn=0 player_kill=4:180 region_posted=") == 1 and S_Logs(n0, "module=charter event=dump_post slot=1 type=") == 1
		and S_Logs(n0, "module=charter event=dump_post slot=2 type=") == 1, "dump: one line, one per posting");
	-- Repair.
	TRF.ch = {rk=9, rp=-1, du="x", lh={20, 10, "a"}, vd=99, sd=0, cnt=1, g={{t=99}, {t=1, r=4, f=0, d=1, k=3, p=9, w=0, a=TRF.clock.legs + 50, e=99, st=2, pay=500, rq=2, l=10, c="phasephasephase"}},
		cd={TRF.clock.legs + 999}, rs={[4]=1, [99]=2, x=3}, rb=7, pk={[2]="a"}, tot={d=5, f=-1}, nw=7, hx=2, junk=1};
	TRF_Repair();
	local R = TRF.ch;
	HOST_Check(R.rk == 0 and R.rp == 0 and R.du == 0 and getn(R.lh) == 1 and R.lh[1] == 10 and R.vd == 0 and R.sd == TRF.clock.legs + 7 and R.g[1] == nil
		and R.g[2].p == 3 and R.g[2].a == TRF.clock.legs and R.g[2].c == "deadline" and R.cd[1] == TRF.clock.legs + 100 and R.rs[4] == 1 and R.rs[99] == nil
		and R.rs.x == nil and R.pk[2] == nil and R.tot.d == 5 and R.tot.f == 0 and R.nw == nil and R.hx == nil and R.junk == nil,
		"repair: bounds, bad posting dropped, stamps clamped, other keys dropped");
	TRF.ch = {rk=2, du=0};
	TRF_Repair();
	HOST_Check(TRF.ch.rk == 2 and TRF.ch.du == TRF.clock.legs, "repair: rank 2 without a dues leg is due now");
	local hp = {t=1, r=4, f=0, d=1, k=3, p=0, w=0, a=TRF.clock.legs, e=TRF.clock.legs + 30, st=1, pay=40000, rq=2, l=10};
	local tune0 = TRF_RgTune;
	TRF_RgTune = function() return {pay_cap=50000}; end;
	local q1 = TRF_ChFixG(hp, 11, TRF.clock.legs);
	TRF_RgTune = tune0;
	local q2 = TRF_ChFixG(hp, 11, TRF.clock.legs);
	HOST_Check(q1 and q1.pay == 40000 and q2 and q2.pay == 30000, "repair: pay bounded by the live pay_cap (50000 kept, 30000 clamps), posting kept");
	TRF.ch = 7;
	TRF_Repair();
	HOST_Check(TRF.ch == nil, "repair: a non-table TRF.ch becomes absent");
	TRF_Repair();
	HOST_Check(TRF.ch == nil, "repair leaves an absent TRF.ch absent");
	-- Worst case (spec 3.3): 3 postings with every field, 11 stamps each in rs, rb and pk.
	local big = 99999;
	TRF.ch = {on=1, rk=3, rp=99, du=big, pt=999999999, lh={16, 16, 16}, vd=9, vb=1, sd=2147483646, cnt=9999, g={}, cd={big, big, big},
		rs={}, rb={}, pk={}, tot={d=9999, f=9999, w=9999}, nw=5, hx=1};
	for k = 1, 3 do TRF.ch.g[k] = {t=6, r=11, f=5, d=5, k=3, p=3, w=1, a=big, e=big, st=3, pay=30000, rq=3, l=16, c="deadline"}; end;
	for k = 1, 11 do TRF.ch.rs[k] = big; TRF.ch.rb[k] = big; TRF.ch.pk[k] = big; end;
	local sz = HOST_SaveSize(TRF.ch) + 8 + strlen("ch");
	print("HOST info TRF.ch worst case "..sz.." bytes");
	HOST_Check(sz <= 2400, "TRF.ch at its bound: "..sz.." bytes <= 2400 (spec 3.3)");
	HOST_Check(HOST_Reserved(TRF, "TRF") == "", "no reserved key in TRF");
	TRF.ch = nil;
	-- charter 0: no line, no posting, no payer, no unlock.
	h.cfg.charter = 0;
	T_Enter("golkonda");
	local r = C_Dock();
	HOST_Check(not C_Has(r.scr, "charter") and TRF.ch == nil, "charter 0: nothing at the dock");
	h.cfg.charter = nil;
end;

-- h: 200 legs (EC.6) -----------------------------------------------------------------------------------

-- First system of region slot that is off the charter deny list.
function C_RegSys(slot)
	local m = TRF_RgMap();
	for i = 1, getn(m[slot].sys) do
		if not TRF_ChDeny(m[slot].sys[i]) then return m[slot].sys[i]; end;
	end;
	return nil;
end;

function T_CH_H()
	local h = HOST();
	C_Begin("golkonda", "9_1", 3);
	local C = TRF.ch;
	local kinds = {1, 1, 4, 3, 5, 6};
	local R = {posts=0, bad=0, relief=0, paid=0, closes=0, msg="", blocked=0};
	local bust, bl = nil, nil;
	local n0 = S_Mark();
	for leg = 1, 200 do
		TRF_AddLeg("test");
		if leg == 60 then
			-- Forced Bust in the first region in Quiet, Boom or Build-up.
			for s = 1, TRF_RgMap().n do
				if not bust and TRF_Phase(s) <= 2 and C_RegSys(s) then bust = s; bl = TRF.clock.legs; TRF_ForcedBust(C_RegSys(s), "test"); end;
			end;
		end;
		if mod(leg, 4) == 0 then
			C.vd = 0; C.vb = 0;
			TRF.clock.rs = TRF.clock.rs + 480;
			local b0 = {};
			for i = 1, 3 do b0[i] = C.g[i]; end;
			if bust and C.pk[bust] and TRF_Phase(bust) >= 4 then R.blocked = R.blocked + 1; end;
			local r = C_Dock();
			if r.nb > 0 then C_Press(r, "ok"); end;
			for i = 1, 3 do
				local p = C.g[i];
				if type(p) == "table" and p ~= b0[i] then
					R.posts = R.posts + 1;
					if p.e - p.a < p.k * 4 then R.bad = R.bad + 1; R.msg = R.msg.." "..p.t..":"..p.a..":"..p.e; end;
					if p.t == 2 and p.r == bust and C.pk[bust] then R.relief = R.relief + 1; end;
				end;
			end;
			-- The scripted player: one deed per 4 legs in each posted region.
			for i = 1, 3 do
				local p = C.g[i];
				if type(p) == "table" and p.st == 0 then
					local k = kinds[p.t];
					if p.t == 3 then TRF.clan[p.r].sc = min(TRF.clan[p.r].sc, 60); end;
					TRF_Ch_Note(k, C_RegSys(p.r), 1000);
				end;
			end;
		end;
	end;
	R.paid = S_Logs(n0, "module=charter event=pay slot=");
	R.closes = S_Logs(n0, "module=charter event=close slot=");
	print("HOST info ch host gen ok="..R.posts.." impossible="..R.bad.." relief_after_kill="..R.relief.." paid="..R.paid.." closed="..R.closes
		.." rank="..C.rk.." bust_region="..tostring(bust).." bust_leg="..tostring(bl).." docks_in_trough_with_pk="..R.blocked);
	HOST_Check(R.posts >= 10 and R.bad == 0 and R.relief == 0 and R.paid >= 3 and bust ~= nil and R.blocked > 0,
		"200 legs (EC.6): "..R.posts.." postings, none with a deadline shorter than K x 4 legs"..R.msg..", no Relief after the forced Bust, "..R.paid.." paid");
	HOST_Check(R.paid <= floor((TRF.clock.rs - 0) / 1800) + 1, "real-time gate: at most one payment per 1800 s");
end;

-- Dispatch ---------------------------------------------------------------------------------

local sc = getenv("TRF_CH") or "";
local fn = getglobal("T_CH_"..strupper(sc));
print("HOST ==== charter scenario ch-"..sc.." dir="..HOST().dir);
if type(fn) == "function" then
	fn();
	HOST_Check(T_LeftGlobals() == "", "no handle globals left at the end"..T_LeftGlobals());
else
	HOST_Check(nil, "unknown charter scenario "..sc);
end;
HOST_Check((HOST().gpm_tick or 0) == 0, "no GetPlayerMotherShip from a tick (n="..tostring(HOST().gpm_tick or 0)..")");
print("HOST errors="..HOST().errors.." fails="..HOST().fails);
if HOST().errors > 0 or HOST().fails > 0 then exit(1); end;
exit(0);
