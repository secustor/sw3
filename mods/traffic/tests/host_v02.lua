-- v0.2 scenarios (design/v02-spec.md 10.5) for host_stubs.lua: TRF_SCEN=v02-a..v02-n, run by run_host.sh.
-- Loaded after host_traffic.lua, whose helpers (T_Begin, T_Enter, T_Jump, T_Tick, T_Spawn, T_SaveLoad, ...)
-- are used here; the v0.2 features keep their defaults unless a scenario sets a key.
-- a migrate, b cycle-200, c clamps, d sweeps, e bands and tiers, f anti-farm, g queue and seed, h lane raid,
-- i help and pay, j staged raid, k hail and contract, l dock wrappers, m trader shop and news, n size and lint.

-- Helpers ---------------------------------------------------------------------------

-- Config with the v0.2 defaults (v1 features off, T_V1Off) plus t; hail_start 1 (the focus path) unless t sets it.
function T_Cfg2(t)
	local c = {exp=0, log=1, traffic=1, hail_start=1};
	for k, v in T_V1Off() do c[k] = v; end;
	if t then for k, v in t do c[k] = v; end; end;
	HOST().cfg = c;
end;

function V_Begin(sys, t)
	T_Cfg2(t);
	HOST().logs = {};
	T_Begin(sys or "gredos");
end;

-- Mod log lines containing pat (plain find) since the scenario start.
-- Death bus handler of the test module Hv (records kind|group|ship|pfire in HOST().dead).
function TRF_Hv_OnDeath(kind, rec, ship, pf) tinsert(HOST().dead, kind.."|"..tostring(rec.g).."|"..tostring(rec.j).."|"..tostring(pf)); end;

function V_Logs(pat)
	local n, q = 0, HOST().logs or {};
	for i = 1, getn(q) do if strfind(q[i], pat, 1, 1) then n = n + 1; end; end;
	return n;
end;

function V_Idx(name) return TRF_Map().by[name]; end;

-- Mission in the current system: the vanilla mission flag plus one of the system's quest ids in
-- QUEST_PROCESS, so the strict gate (TRF_SafeQA over the map's qi) sees an active quest. V_QuestOff
-- clears both and the per-visit cache.
function V_QuestOn()
	local h = HOST();
	h.qs = TRUE;
	local cur = TRF_CurIdx();
	local qi = TRF_SafeQIds(cur, TRF_Map().sys[cur]);
	if type(qi) == "table" and qi[1] then h.quests[qi[1]] = QUEST_PROCESS; end;
	TRF.live.qa = nil; TRF.live.qai = nil; TRF_H().loc = nil;
end;
function V_QuestOff()
	local h = HOST();
	h.qs = FALSE; h.quests = {};
	TRF.live.qa = nil; TRF.live.qai = nil; TRF_H().loc = nil;
end;

-- Region slot of a system (trf_region), its record and clan.
function V_Slot(name) return TRF_RgOf(V_Idx(name)); end;

-- Every phase letter of the region line once at least.
function V_AllPhases(line)
	local l = {"Q", "B", "U", "R", "X", "V"};
	for i = 1, getn(l) do if not strfind(line, l[i], 1, 1) then return nil; end; end;
	return 1;
end;

-- pro <= pc everywhere, 0 for systems without a region.
function V_ProOk()
	local m = TRF_RgMap();
	for i = 1, getn(TRF_Map().sys) do
		if TRF_Pro(i) > TRF_ProCap(i) then return nil, i; end;
		if not m.of[i] and TRF_Pro(i) > 0 then return nil, i; end;
	end;
	return 1;
end;

-- Number of string-keyed or number-keyed entries.
function V_N(t)
	local n = 0;
	if type(t) == "table" then for k, v in t do n = n + 1; end; end;
	return n;
end;

-- Remove every open trader record (frees the caps for the next spawn).
function V_ClearTr()
	local ids = {};
	for id, r in TRF.live.tr do if type(r) == "table" and r.st ~= "gone" then tinsert(ids, id); end; end;
	for i = 1, getn(ids) do TRF_Remove(ids[i], "test"); end;
end;

-- A visit without an entry: the per-visit caps (clan, credits) start again.
function V_NewVisit()
	TRF.live.cl = {}; TRF.live.pv = 0; TRF.live.pc = 0; TRF.live.kills = 0;
end;

-- a: migration v1/v2/unknown -> v3, start phases, repair, mid-campaign add (spec 3.3, 4.3) ------------

function T_V02_A()
	local h = HOST();
	h.labels.CurrentQuest = "5_1";
	V_Begin("gredos");
	local m = TRF_RgMap();
	HOST_Check(TRF.version == 4 and m.n == 8 and getn(TRF.rg) == 8 and V_N(TRF.clan) == 8 and TRF.clock.legs - TRF.clock.rt < 2
		and TRF.std.help == 0, "new game: v4 with 8 regions, rt within one tick of legs, help 0");
	local want = {14, 15, 11, 17, 27, 14, 4, 8};
	local sz, tot = "", 0;
	for i = 1, m.n do sz = sz.." "..getn(m[i].sys); tot = tot + getn(m[i].sys); if getn(m[i].sys) ~= want[i] then sz = sz.."!"; end; end;
	HOST_Check(not strfind(sz, "!", 1, 1) and tot == 110, "region sizes 14 15 11 17 27 14 4 8, 110 systems (spec 4.1):"..sz);
	HOST_Check(m.of[V_Idx("earth")] == nil and m.of[V_Idx("precursors")] == nil and m.of[V_Idx("disonsphere")] == nil,
		"earth, precursors, disonsphere have no region");
	-- Static map fields (gen_map.py) against the runtime fallback on the same map without them.
	local mp, fm = TRF_Map(), {sys={}};
	fm.by = mp.by;
	for i = 1, getn(mp.sys) do
		local c = {};
		for k, v in mp.sys[i] do c[k] = v; end;
		c.rg = nil; c.dg = nil; c.pc = nil;
		fm.sys[i] = c;
	end;
	local fb, fd = TRF_RgBuild(fm), 0;
	for i = 1, getn(mp.sys) do
		if fb.of[i] ~= m.of[i] or fb.dg[i] ~= m.dg[i] or fb.pc[i] ~= m.pc[i] then fd = fd + 1; end;
	end;
	HOST_Check(type(mp.rg) == "table" and type(mp.sys[1].dg) == "number" and fb.n == m.n and fd == 0,
		"map rg/dg/pc present and equal to the runtime fallback ("..fd.." systems differ)");
	local line = TRF_RgLine();
	HOST_Check(strsub(line, 1, 8) == "QBBURXXV" and V_AllPhases(line), "start phases guard off: every phase present ("..line..")");
	local ok, bad = V_ProOk();
	HOST_Check(ok, "start pro clamped to pc, independents 0 ("..tostring(bad)..")");
	-- v2 save as v0.1 wrote it (v01 3.1).
	T_SaveLoad(function()
		TRF = {version=2, active=1, gen=4, seq=3, clock={legs=40, tleg=10, gt=500, real=400, dd=39},
			sys={[46]={dis=4}, [9]={dis=1}}, std={heat=3, heat_t=38}, live={}, exp={cnt={enter=7}}};
	end);
	local g = V_Idx("gredos");
	local sg = TRF_RgOf(g);
	local tp = TRF_PhaseTarget(sg);
	HOST_Check(TRF.version == 4 and TRF.clock.rt == 40 and TRF.std.help == 0 and V_N(TRF.short) == 0 and V_N(TRF.shops) == 0
		and type(TRF.news) == "table" and type(TRF.newsx) == "table" and type(TRF.tsh) == "table" and V_Logs("event=migrate from_version=2 to_version=3") == 1 and V_Logs("event=migrate from_version=3 to_version=4") == 1,
		"v2 -> v3: rt = legs, help 0, short/shops/news/newsx/tsh added, logged");
	HOST_Check(TRF.sys[46].dis == 4 and TRF.sys[9].dis == 1 and TRF.std.heat == 3 and TRF.gen == 5 and TRF.exp.cnt.enter == 7,
		"v2 -> v3 keeps dis, heat, gen + 1, exp");
	HOST_Check(getn(TRF.rg) == 8 and TRF_Pro(g) == min(tp, TRF_ProCap(g)) and V_ProOk(), "v2 -> v3: rg/clan initialised, pro = start target ("..TRF_Pro(g)..")");
	-- v1 save.
	T_SaveLoad(function() TRF = {version=1, active=1, gen=3, clock={game=40, real=2}, exp={cnt={enter=2}}}; end);
	HOST_Check(TRF.version == 4 and TRF.clock.gt == 40 and TRF.clock.game == nil and getn(TRF.rg) == 8 and TRF.exp.cnt.enter == 2
		and V_Logs("event=migrate from_version=1 to_version=2") == 1 and V_Logs("event=migrate from_version=2 to_version=3") == 2, "v1 -> v2 -> v3");
	-- Unknown version keeps heat, help and shops.
	T_SaveLoad(function() TRF = {version=7, gen=9, std={heat=5, help=12}, shops={{s=46, sh="gredos", c=1}}, clock={legs=3}, foo=1}; end);
	HOST_Check(TRF.version == 4 and TRF.std.heat == 5 and TRF.std.help == 12 and getn(TRF.shops) == 1 and TRF.shops[1].sh == "gredos"
		and TRF.gen == 10 and TRF.foo == nil and getn(TRF.rg) == 8, "unknown version: reset, heat, help and shops kept");
	-- Repair of wrong types on load.
	T_SaveLoad(function()
		TRF.clock.rt = "x"; TRF.rg[2] = "x"; TRF.clan[9] = {sc=3}; TRF.sys[46] = {pro=99}; TRF.std.help = 400;
		TRF.short = {1, {s=1, c=1, t=9}, {s=2, c=1, t=9}, {s=3, c=1, t=9}, {s=4, c=1, t=9}, {s=5, c=1, t=9}, {s=6, c=1, t=9},
			{s=7, c=1, t=9}, {s=8, c=1, t=9}, {s=9, c=1, t=9}};
		TRF.rg[4].pt = 999; TRF.news = 5; TRF.tsh = "y";
	end);
	HOST_Check(TRF.clock.rt == TRF.clock.legs and type(TRF.rg[2]) == "table" and TRF.clan[9] == nil and TRF.sys[46].pro == 9
		and TRF.std.help == 99 and getn(TRF.short) == 8 and TRF.short[1].s == 1 and TRF.rg[4].pt == TRF.clock.legs
		and type(TRF.news) == "table" and type(TRF.tsh) == "table", "repair: rt, broken slot, clan out of range, pro clamp, help, list of 8, pt, types");
	-- Mid-campaign add: a save made without the mod.
	T_SaveLoad(function() TRF = nil; end);
	HOST_Check(TRF.version == 4 and getn(TRF.rg) == 8 and TRF.clock.rt == 0 and V_ProOk(), "save without TRF: fresh v4 with regions");
	-- Guard on (chapter 3): the Gefest region starts in Quiet with score 0 and doubled lengths.
	h.labels.CurrentQuest = "3";
	T_SaveLoad(function() TRF = nil; end);
	local s3 = V_Slot("gefest");
	HOST_Check(strsub(TRF_RgLine(), 1, 8) == "QBQURXXV" and s3 == 3 and TRF.rg[3].gx == 1 and TRF_ClanScore(3) == 0,
		"guard on: Gefest region Quiet, score 0, gx 1 ("..strsub(TRF_RgLine(), 1, 8)..")");
	h.labels.CurrentQuest = "5_1";
	-- config.script lists the v0.2 keys with the module defaults (TRF_Opt reads the same values without them).
	local f = openfile(h.dir.."config.script", "r");
	local src = read(f, "*a");
	closefile(f);
	dostring(src);
	local rc = TRF_Config();
	h.cfg = {exp=0, log=1, traffic=1};
	dostring("function TRF_Config() return HOST().cfg; end");
	local diff = "";
	for k, v in rc do
		if type(v) == "table" then
			if type(TRF_Opt(k)) ~= "table" or V_N(TRF_Opt(k)) ~= V_N(v) then diff = diff.." "..k; end;
		elseif k ~= "exp" and k ~= "log" and k ~= "autosave" and k ~= "traffic" and TRF_Opt(k) ~= v then
			diff = diff.." "..k.."="..tostring(v).."/"..tostring(TRF_Opt(k));
		end;
	end;
	HOST_Check(diff == "" and rc.enabled == 1 and rc.meet == 2 and rc.cap_traders == 5, "config.script v0.2 and v1 keys equal the module defaults"..diff);
	HOST_Check(HOST_Reserved(TRF, "TRF") == "", "no reserved key in TRF");
end;

-- b: 200-leg desynchronisation run (spec 4.7) -------------------------------------------------

-- 200 legs of TRF_AddLeg in one visit (push nil) or one push per leg: "down" kills pirates in every region
-- (score -6 per visit, holds Boom), "up" kills a trader in the top system of every region (pro -3, dis +2,
-- holds Bust and Recovery). Returns a result table; prints one line per 10 legs.
function V_Run200(quest, label, push)
	local h = HOST();
	h.labels.CurrentQuest = quest;
	h.seed = tonumber(getenv("TRF_SEED") or "") or 1;
	TRF = nil;
	TRF_State_OnEnter(1);
	local m = TRF_RgMap();
	local n = m.n;
	local R = {miss=0, maxhi=0, lenbad=0, lenmsg="", rq={}, seen={}, pair=0, pairmsg="", maxlen={}, frozen=0, gap=0, over=0};
	local hold = TRF_RgTune().rg_hold;
	local vis = {};
	local hi, last, start, gxs, same = {}, {}, {}, {}, {};
	for s = 1, n do
		hi[s] = 0; last[s] = TRF_Phase(s); start[s] = nil; gxs[s] = TRF.rg[s].gx; R.rq[s] = 0; R.seen[s] = {};
		R.seen[s][last[s]] = 1;
		vis[s] = {};
		for p = 0, 5 do vis[s][p] = TRF.clock.legs; end;
		same[s] = {};
		for t = 1, n do same[s][t] = 0; end;
	end;
	print("HOST "..label.." init: "..TRF_RgLine());
	for leg = 1, 200 do
		TRF_AddLeg("test");
		if push then
			V_NewVisit();
			for s = 1, n do
				if push == "down" then
					TRF_ClanAdd(s, -6, "push");
				else
					local top, tp = nil, -1;
					local ss = m[s].sys;
					for i = 1, getn(ss) do if TRF_Pro(ss[i]) > tp then top = ss[i]; tp = TRF_Pro(ss[i]); end; end;
					if top then TRF_ProAdd(top, -3, "push"); TRF_AddDis(top, 2, "push"); end;
				end;
			end;
		end;
		local nb, nur, nxv = 0, 0, 0;
		for s = 1, n do
			local ph = TRF_Phase(s);
			if ph == 1 then nb = nb + 1; end;
			if ph == 2 or ph == 3 then nur = nur + 1; end;
			if ph == 4 or ph == 5 then nxv = nxv + 1; end;
			if TRF_ClanScore(s) >= 75 then hi[s] = hi[s] + 1; else hi[s] = 0; end;
			if hi[s] > R.maxhi then R.maxhi = hi[s]; end;
			if ph ~= last[s] then
				R.seen[s][ph] = 1;
				if last[s] == 5 and ph == 0 then R.rq[s] = R.rq[s] + 1; end;
				if start[s] then
					local len = TRF.rg[s].pt - start[s];
					local mn, mx = TRF_RgLen(s, last[s], gxs[s], TRF_RgTune());
					if len - mx > R.over then R.over = len - mx; end;
					if len < mn or len > mx + hold then
						R.lenbad = R.lenbad + 1;
						R.lenmsg = R.lenmsg.." s"..s.."p"..last[s].."="..len.."("..mn..".."..mx.."+"..hold..")";
					end;
					local k = s.."_"..last[s];
					if not R.maxlen[k] or len > R.maxlen[k] then R.maxlen[k] = len; end;
				end;
				start[s] = TRF.rg[s].pt;
				gxs[s] = TRF.rg[s].gx;
				last[s] = ph;
			end;
			-- A phase still running beyond its maximum + 10 (rg_hold 6, the 2-leg tick, margin) is frozen.
			local mn, mx = TRF_RgLen(s, ph, TRF.rg[s].gx, TRF_RgTune());
			if TRF.clock.legs - TRF.rg[s].pt > mx + 10 then R.frozen = R.frozen + 1; end;
			-- Legs since the region was last in each phase (start counts as a visit of the start phase only).
			vis[s][ph] = TRF.clock.legs;
			for p = 0, 5 do
				if TRF.clock.legs - vis[s][p] > R.gap then R.gap = TRF.clock.legs - vis[s][p]; end;
			end;
		end;
		for s = 1, n do
			for t = s + 1, n do
				if TRF_Phase(s) == TRF_Phase(t) then same[s][t] = same[s][t] + 1; else same[s][t] = 0; end;
				if same[s][t] > R.pair then R.pair = same[s][t]; R.pairmsg = s.."/"..t.." at leg "..TRF.clock.legs; end;
			end;
		end;
		if nb == 0 or nur == 0 or nxv == 0 then R.miss = R.miss + 1; end;
		if mod(leg, 10) == 0 then print(format("HOST %s legs=%3d %s", label, TRF.clock.legs, TRF_RgLine())); end;
	end;
	R.rqmin, R.allph = 99, 1;
	for s = 1, n do
		if R.rq[s] < R.rqmin then R.rqmin = R.rq[s]; end;
		for p = 0, 5 do if not R.seen[s][p] then R.allph = nil; end; end;
	end;
	print(format("HOST %s: legs without Boom, Build-up/Raids or Bust/Recovery %d of 200; max sc>=75 run %d; min Recovery->Quiet %d; max pair in one phase %d (%s); frozen %d; max legs between visits of a phase %d; max legs past mx %d",
		label, R.miss, R.maxhi, R.rqmin, R.pair, R.pairmsg, R.frozen, R.gap, R.over));
	return R;
end;

-- Cycle criteria (spec 4.2a, 4.7): every phase group at >= 98 % of the legs, no pair of regions in one
-- phase for more than 25 consecutive legs (longest maximum: Boom 20 at ck 1.20 -> 24), every phase again
-- within 120 legs; lengths within mn..mx + rg_hold; under constant pushing no phase past mx + 10.
function T_V02_B()
	local h = HOST();
	h.labels.CurrentQuest = "5_1";
	V_Begin("gredos", {log=1});
	local nlog = getn(h.logs);
	h.logs = nil;
	local R = V_Run200("5_1", "v02-b");
	HOST_Check(R.lenbad == 0, "guard off: every phase length within mn..mx + rg_hold"..R.lenmsg);
	HOST_Check(R.maxhi <= 18, "guard off: sc >= 75 at most 18 consecutive legs ("..R.maxhi..")");
	HOST_Check(R.rqmin >= 2 and R.allph, "guard off: every region visits every phase, Recovery -> Quiet at least twice ("..R.rqmin..")");
	HOST_Check(R.frozen == 0, "guard off: no phase runs past mx + 10");
	HOST_Check(R.miss <= 4, "guard off: Boom, Build-up/Raids and Bust/Recovery present at >= 98 % of legs ("..R.miss.." of 200 miss)");
	HOST_Check(R.pair <= 25, "guard off: no two regions in one phase > 25 legs ("..R.pair..", "..R.pairmsg..")");
	HOST_Check(R.gap <= 120, "guard off: every region in every phase within 120 legs ("..R.gap..")");
	local G = V_Run200("3", "v02-b guard");
	HOST_Check(G.lenbad == 0 and G.maxhi <= 18 and G.frozen == 0, "guard on: lengths within mn..mx + rg_hold (Gefest doubled), sc >= 75 <= 18 legs"..G.lenmsg);
	HOST_Check(G.miss <= 4 and G.pair <= 25 and G.gap <= 120,
		"guard on: groups at >= 98 % of legs ("..G.miss.."), pair run <= 25 ("..G.pair.."), every phase within 120 legs ("..G.gap..")");
	local gs = V_Slot("gefest");
	local mn3, mx3 = TRF_RgLen(gs, 3, 1, TRF_RgTune());
	HOST_Check(TRF_RgLen(gs, 1, 1, TRF_RgTune()) == 2 * TRF_RgLen(gs, 1, 0, TRF_RgTune()) and mx3 == 18,
		"guard on: Gefest minimum doubled, Raids maximum stays 18");
	local t1 = 1;
	for i = 1, getn(TRF_Map().sys) do
		if TRF_Map().sys[i].start == 1 and TRF_EffTier(i) ~= 1 then t1 = nil; end;
	end;
	HOST_Check(t1, "guard on: every start system has effective tier 1");
	-- Constant player pushing: the player shifts phases but freezes none (each ends by mx + 10).
	local D = V_Run200("5_1", "v02-b push down", "down");
	HOST_Check(D.lenbad == 0 and D.frozen == 0 and D.over <= 10 and D.allph and D.gap <= 120 and D.maxhi <= 18,
		"pirate kills every leg (score -6): no phase past mx + 10 ("..D.over.."), every phase within 120 legs ("..D.gap..")"..D.lenmsg);
	local U = V_Run200("5_1", "v02-b push up", "up");
	HOST_Check(U.lenbad == 0 and U.frozen == 0 and U.over <= 10 and U.allph and U.gap <= 120 and U.maxhi <= 18,
		"trader kills every leg (pro -3, dis +2): no phase past mx + 10 ("..U.over.."), every phase within 120 legs ("..U.gap..")"..U.lenmsg);
	print("HOST info push: legs missing a group "..D.miss.." / "..U.miss..", longest pair run "..D.pair.." / "..U.pair.." (down / up, not checked)");
	h.logs = {};
end;

-- c: clamps (spec 4.5, 9.1) ------------------------------------------------------------------

function T_V02_C()
	local h = HOST();
	h.labels.CurrentQuest = "5_1";
	V_Begin("gredos");
	-- 100 legs between two entries: 30 ticks, the rest skipped.
	TRF.clock.legs = TRF.clock.legs + 99;
	T_Jump("aurora");
	HOST_Check(V_Logs("module=region event=tick tick_count=30 legs=") == 1 and V_Logs("module=region event=catchup skipped_legs=") == 1 and TRF.clock.legs - TRF.clock.rt < 2,
		"100-leg jump: 30 ticks, older legs skipped");
	T_Jump("gredos");
	local g = V_Idx("gredos");
	local slot = TRF_RgOf(g);
	TRF.rg[slot].ph = 1;
	TRF_SetDis(g, 0);
	TRF_SetPro(g, 3);
	local up = TRF_ProCredit(24, "test");
	HOST_Check(up == 2 and TRF_Pro(g) == 5 and TRF.live.pv == 2, "credits: 24 credits give +2 (visit maximum)");
	HOST_Check(TRF_ProCredit(12, "test") == 0 and TRF_Pro(g) == 5, "credits: no more in the same visit");
	T_Jump("aurora");
	T_Jump("gredos");
	HOST_Check((TRF.live.pc or 0) == 0 and (TRF.live.pv or 0) == 0, "credits lost on leaving");
	TRF_SetDis(g, 2);
	HOST_Check(TRF_ProCredit(12, "test") == 0, "credits: none at dis 2");
	TRF_SetDis(g, 0);
	V_NewVisit();
	TRF.rg[slot].ph = 0;
	TRF_SetPro(g, 4);
	HOST_Check(TRF_ProCredit(12, "test") == 0 and TRF_Pro(g) == 4, "credits never lift pro above the phase target (Quiet 4)");
	TRF_ProCredit(5, "test");
	T_SaveLoad();
	HOST_Check((TRF.live.pc or 0) == 0, "credits lost on load");
	TRF_SetPro(g, 4);
	TRF_ProAdd(g, -3, "kill");
	HOST_Check(TRF_Pro(g) == 1, "kill: pro -3");
	TRF_ProAdd(g, -3, "kill");
	HOST_Check(TRF_Pro(g) == 0, "kill: pro stays >= 0");
	local s1 = TRF_ClanScore(slot);
	TRF.clan[slot].sc = 50;
	local a = TRF_ClanAdd(slot, 1, "t") + TRF_ClanAdd(slot, 1, "t") + TRF_ClanAdd(slot, 1, "t") + TRF_ClanAdd(slot, 1, "t");
	HOST_Check(a == 3 and TRF_ClanScore(slot) == 53, "clan +3 per visit");
	a = TRF_ClanAdd(slot, -4, "t") + TRF_ClanAdd(slot, -4, "t");
	HOST_Check(a == -6 and TRF_ClanScore(slot) == 47, "clan -6 per visit");
	-- cfg cycle 0: no ticks, rt follows legs.
	h.cfg.cycle = 0;
	local L0 = TRF_RgLine();
	TRF.clock.legs = TRF.clock.legs + 10;
	HOST_Check(TRF_RegionCatchup() == 0 and TRF.clock.rt == TRF.clock.legs and TRF_RgLine() == L0, "cycle 0: no region tick");
	h.cfg.cycle = nil;
end;

-- d: off-screen sweeps (spec 4.4) ----------------------------------------------------------------

function T_V02_D()
	local h = HOST();
	h.labels.CurrentQuest = "5_1";
	V_Begin("gredos");
	local s = V_Slot("kadi");
	local r, c = TRF.rg[s], TRF.clan[s];
	-- Raids just started (len 0), score high, no attempt yet.
	r.ph = 3; r.pt = TRF.clock.legs; r.sl = 0; r.sn = 0; r.sw = 0; c.sc = 99;
	local L0 = TRF.clock.legs;
	TRF_RgSweepPlan(s, L0, r, TRF_RgTune());
	HOST_Check(r.sl == L0 + 6 and TRF.newsx[s] and TRF.newsx[s].sweep and TRF.newsx[s].sweep.v == "gather", "attempt 1 planned at +6, news sweep/gather");
	HOST_Check(TRF_SweepOpen(s) == nil, "window not open 6 legs before");
	local rs = TRF.rg[s];
	-- Three forced failures, then the certain fourth attempt.
	local legs = {};
	for k = 1, 4 do
		h.rq = {99};
		local L = r.sl;
		TRF_RgSweepRoll(s, L, r, c, TRF_RgTune());
		h.rq = {};
		tinsert(legs, L - L0);
	end;
	HOST_Check(legs[1] == 6 and legs[2] == 12 and legs[3] == 16 and legs[4] == 18, "attempts at +6/+12/+16/+18 ("..legs[1].."/"..legs[2].."/"..legs[3].."/"..legs[4]..")");
	HOST_Check(r.sw == 1 and r.sl == 0 and c.sc <= 35 and V_Logs("chance=100 attempt=4 result=won") == 1, "attempt 4 certain: sc <= 35");
	HOST_Check(V_Logs(" attempt=1 result=failed") == 1 and V_Logs("clan_score=89 next_leg=") == 1 and TRF.newsx[s].sweep.v == "win", "failure: score -10; news fail then win");
	-- Through the tick: a won attempt ends Raids in the same tick.
	r.ph = 3; r.pt = TRF.clock.rt - 4; r.sw = 0; r.sn = 0; c.sc = 90; r.sl = TRF.clock.rt + 2;
	h.rq = {0};
	TRF_AddLeg("test"); TRF_AddLeg("test");
	h.rq = {};
	HOST_Check(TRF_Phase(s) == 4 and TRF_ClanScore(s) <= 35 and V_Logs(" attempt=1 result=won") == 1, "won attempt: Raids ends in the same tick (now "..TRF_Phase(s).." sc "..TRF_ClanScore(s)..")");
	-- Open window (2 legs before the attempt) pauses raids of that clan.
	r.ph = 3; r.pt = TRF.clock.legs; r.sw = 0; r.sl = TRF.clock.legs + 2;
	HOST_Check(TRF_SweepOpen(s) == 1, "window open 2 legs before the attempt");
	T_Jump("kadi");
	r = TRF.rg[s];
	r.sl = TRF.clock.legs + 1;
	local ok, why = TRF_Rd_Gate(TRF_CurIdx(), "raid");
	HOST_Check(not ok and why == "sweep", "open sweep: raids of the region paused ("..tostring(why)..")");
	r.sl = TRF.clock.legs + 5;
	ok, why = TRF_Rd_Gate(TRF_CurIdx(), "raid");
	HOST_Check(why ~= "sweep", "closed window: no sweep pause ("..tostring(why)..")");
	local info = TRF_SweepInfo(s);
	HOST_Check(type(info) == "table" and type(info.fac) == "string" and info.fac ~= "", "sweep info: faction "..tostring(info and info.fac));
end;

-- e: bands and tiers (spec 9.1-9.3) ---------------------------------------------------------------

-- A TT3 trader at the current pro (9): generation with rolls 0 until one spawns, others removed.
function V_SpawnT3()
	local h = HOST();
	for k = 1, 30 do
		local before = TRF.seq;
		h.rq = {0, 0};
		T_Gen();
		h.rq = {};
		if TRF.seq ~= before and TRF_Rec(TRF.seq) then
			if TRF.live.tr[TRF.seq].tier == 3 then return TRF.seq; end;
			TRF_Remove(TRF.seq, "test");
		end;
		TRF.live.port = {};
	end;
	return nil;
end;

-- Escort flight (cfg esc_flight, v01 4.5, v02 9.3): a TT3 trader as a convoy flight of its transports and an
-- escort flight of every escort with Escort on the lead transport; counts, labels, handle globals, re-route,
-- died transport, flee, removal, load adoption; esc_flight 0 builds the single flight.
function V_EscFlight()
	local h = HOST();
	TRF_SetDis(TRF_CurIdx(), 6);
	h.logs = {};
	local id = V_SpawnT3();
	HOST_Check(id ~= nil, "esc_flight: TT3 spawned (dis 6: added escorts up to the tier maximum)");
	if not id then return; end;
	local r, x = TRF.live.tr[id], TRF_H().tr[id];
	local ne = getn(x.sh) - getn(x.tp);
	local okr, okl, okg = 1, 1, 1;
	for i = 2, getn(x.ef.ships) do if x.ef.ships[i].role ~= ROLE_DEFEND then okr = nil; end; end;
	for i = 1, getn(x.sh) do
		if x.sh[i].label ~= "trf_"..id.."_"..i then okl = nil; end;
		if getglobal("TRF_ship_trf_"..id.."_"..i) ~= x.sh[i] then okg = nil; end;
	end;
	HOST_Check(x.ef and x.ef ~= x.fl and getn(x.fl.ships) == r.nt and r.nt == 2 and getn(x.ef.ships) == ne and ne >= 3
		and r.np == r.nt + ne and ne <= 5 and r.e1 == 3 and x.ef.esc == x.tp[1] and okr,
		"esc_flight: convoy flight of "..r.nt.." transports, escort flight of "..ne.." (added "..r.esc.."), Escort on the lead, wingmen ROLE_DEFEND");
	HOST_Check(okl and okg and V_Logs("event=spawn trader_id="..id.." ") == 1 and V_Logs(" escort_flight=true escort_count="..ne) == 1,
		"esc_flight: labels trf_<id>_<i> and TRF_ship_ globals across both flights, spawn line efl=1 esc="..ne);
	HOST_Check(TRF_Rd_EscAlive(r, x) == ne and TRF_SpEscAlive(r, x) == ne, "esc_flight: raid and supply escort counts "..ne);
	x.ef.esc = nil;
	TRF_GnReissue(id);
	HOST_Check(x.ef.esc == x.tp[1], "esc_flight: re-route gives Escort again");
	x.tp[1].alive = nil;
	HOST_Fire("died", "TRF_OnShipDied("..id..",1,");
	HOST_Check(TRF_Rec(id) and x.ef.esc == x.tp[2], "esc_flight: lead transport died, Escort on the next transport");
	x.ef.esc = nil;
	T_MoveTr(id, h.ms.pos.x + 60, 0, h.ms.pos.z);
	x.tp[1].alive = nil;
	TRF_Flee(id, "test");
	HOST_Check(TRF.live.tr[id].st == "flee" and x.ef.esc == x.tp[2], "esc_flight: flee gives Escort again");
	local fl, ef = x.fl, x.ef;
	TRF_Remove(id, "test");
	HOST_Check(fl.deleted and ef.deleted and getglobal("TRF_ship_trf_"..id.."_3") == nil, "esc_flight: Remove deletes both flights and the handle globals");
	-- Load: both flights adopted (escort flight from the first escort's pilot flight), Escort again.
	local b = V_SpawnT3();
	if b then
		T_MoveTr(b, h.ms.pos.x + 60, 0, h.ms.pos.z);
		local xb = TRF_H().tr[b];
		local nb, fb, eb = getn(xb.sh), xb.fl, xb.ef;
		eb.esc = nil;
		h.logs = {};
		T_SaveLoad();
		local y = TRF_H().tr[b];
		HOST_Check(TRF.live.tr[b] and TRF.live.tr[b].st == "wind" and y and y.fl == fb and y.ef == eb and getn(y.sh) == nb and getn(y.tp) == 2
			and y.tp[1] == xb.tp[1] and eb.esc == y.tp[1] and V_Logs("event=load trader_id="..b.." result=adopted ship_count="..nb.." via=global escort_flight=true state=wind") == 1,
			"esc_flight: load pass adopts the convoy and the escort flight, Escort again");
		TRF_Remove(b, "test");
		HOST_Check(fb.deleted and eb.deleted, "esc_flight: adopted trader removed with both flights");
	else
		HOST_Check(nil, "esc_flight: second TT3 for the load pass");
	end;
	-- TT1 (pro 0) at dis 6: row escorts and the added escorts in the escort flight.
	TRF_SetPro(TRF_CurIdx(), 0);
	local t1 = T_Spawn("C");
	local r1, x1 = TRF.live.tr[t1], TRF_H().tr[t1];
	local rw = TRF_Row(r1.pw);
	HOST_Check(r1.tier == 1 and r1.esc == min(2, 4 - rw.esc) and getn(x1.fl.ships) == rw.tp
		and ((rw.esc + r1.esc == 0 and x1.ef == nil) or (x1.ef and getn(x1.ef.ships) == rw.esc + r1.esc)),
		"esc_flight TT1: "..rw.tp.." transports, escort flight of "..rw.esc.." row + "..r1.esc.." added escorts");
	TRF_Remove(t1, "test");
	TRF_SetPro(TRF_CurIdx(), 9);
	-- Strict gate: a quest system during a mission keeps one flight per spawn.
	local pl = {tier=1, row=TRF_Row(8)};
	V_QuestOn();
	local den = TRF_TierSplitOn(pl);
	V_QuestOff();
	HOST_Check(den == nil and TRF_TierSplitOn(pl) == 1, "esc_flight: denied system (mission) builds one flight");
	-- esc_flight 0: today's single flight.
	h.cfg.esc_flight = 0;
	local c = V_SpawnT3();
	local xc = c and TRF_H().tr[c];
	HOST_Check(xc and xc.ef == nil and getn(xc.fl.ships) == getn(xc.sh) and TRF.live.tr[c].e1 == nil, "esc_flight 0: one flight with every ship");
	if c then TRF_Remove(c, "test"); end;
	h.cfg.esc_flight = nil;
	TRF_SetDis(TRF_CurIdx(), 0);
end;

-- pro of the current system (dis 0 kept as it is).
function V_Pro(p) TRF_SetPro(TRF_CurIdx(), p); end;

function T_V02_E()
	local h = HOST();
	h.labels.CurrentQuest = "5_1";
	h.st_label = "TRADE STATION";
	V_Begin("gredos", {raids=0, staged=0, seed=0, queue=0});
	local idx = TRF_CurIdx();
	TRF_SetDis(idx, 0);
	local want = {{0, 1.00, 2, 10, 0, 0}, {2, 1.00, 2, 10, 0, 0}, {3, 1.25, 3, 12, 0, 10}, {4, 1.25, 3, 12, 0, 10},
		{5, 1.50, 4, 16, 1, 15}, {6, 1.50, 4, 16, 1, 15}, {7, 1.50, 4, 16, 1, 20}, {8, 1.75, 5, 20, 2, 20},
		{9, 2.00, 5, 20, 2, 20}};
	for i = 1, getn(want) do
		local w = want[i];
		V_Pro(w[1]);
		local c = TRF_BandCaps(idx);
		local ct, cs, cp = TRF_SafeCaps();
		HOST_Check(c.sf == w[2] and c.ct == w[3] and c.cs == w[4] and c.cp == w[5] and c.sb == w[6] and ct == w[3] and cs == w[4] and cp == w[5],
			"band row pro "..w[1].." -> sf "..c.sf.." caps "..ct.."/"..cs.." parked "..cp.." seed bonus "..c.sb);
	end;
	h.cfg.band_half = 1;
	V_Pro(9);
	local c = TRF_BandCaps(idx);
	HOST_Check(c.sf == 1.50 and c.ct == 3 and c.cs == 15, "band_half: pro 9 -> 1.50 / 3 / 15 (v1 band 4)");
	h.cfg.band_half = nil;
	h.cfg.prosperity = 0;
	HOST_Check(TRF_Band(idx) == 0 and TRF_TierPick(idx, 8, 20) == 1, "prosperity 0: band 0, TT1");
	h.cfg.prosperity = nil;
	-- Tier rolls: pro 0-2 draw nothing.
	for p = 0, 2 do
		V_Pro(p);
		local r0 = h.rand;
		HOST_Check(TRF_TierPick(idx, 8, 20) == 1 and h.rand == r0, "pro "..p.." -> TT1 without a draw");
	end;
	-- design/strength-spec.md 4.4, 5.1 (replaces the 9.2 chances): pro 4 = score 44, TT2 band, up 45 %, down 4 %, one draw.
	V_Pro(4);
	local r0 = h.rand;
	h.rq = {0};
	local t4, w4, s4, ro4, st4 = TRF_TierPick(idx, 8, 20);
	HOST_Check(t4 == 3 and w4 == "roll" and s4 == 44 and ro4 == 0 and st4 == 1 and h.rand == r0 + 1, "pro 4, roll 0 -> TT3 (score 44, step +1, one draw)");
	h.rq = {50};
	HOST_Check(TRF_TierPick(idx, 8, 20) == 2, "pro 4, roll 50 -> TT2");
	h.rq = {99};
	HOST_Check(TRF_TierPick(idx, 8, 20) == 1, "pro 4, roll 99 -> TT1");
	-- design/strength-spec.md 4.4: pro 9 = score 99, TT4 band, no down chance: no draw; without trf_convoy TT4 gives TT3.
	V_Pro(9);
	r0 = h.rand;
	local t9, w9 = TRF_TierPick(idx, 8, 20);
	HOST_Check(t9 == 3 and strsub(w9, 1, 4) == "tt4_" and h.rand == r0, "pro 9 -> TT4 band without a draw, TT4 condition -> TT3 ("..tostring(w9)..")");
	V_Pro(5);
	h.rq = {99};
	HOST_Check(TRF_TierPick(idx, 8, 20) == 2, "pro 5, roll 99 -> TT2 (down 16 %)");
	V_Pro(9);
	-- design/strength-spec.md 5.1: the cap checks below run at pro 9 (no draw; the forced rolls stay unused).
	TRF.std.heat = 3; h.rq = {0};
	HOST_Check(TRF_TierPick(idx, 8, 20) == 3, "heat 3 keeps TT3 (the v0.2 maximum)");
	TRF.std.heat = 5; h.rq = {0};
	local t, why = TRF_TierPick(idx, 8, 20);
	HOST_Check(t == 2 and why == "heat", "heat 5 -> TT2 ("..tostring(why)..")");
	TRF.std.heat = 0;
	TRF.live.patk = 1; h.rq = {0};
	t, why = TRF_TierPick(idx, 8, 20);
	HOST_Check(t == 2 and why == "patk", "counted attack this visit -> TT2");
	TRF.live.patk = nil;
	h.extra_carcass = 50; h.rq = {0};
	TRF_Governor();
	t, why = TRF_TierPick(idx, 8, 20);
	local ct, cs = TRF_SafeCaps();
	HOST_Check(t == 2 and why == "gov" and TRF_GovActive() and ct == 4 and cs == 12, "governor (50 carcasses) -> TT2, pro 9 caps 5/20 -> 4/12 ("..tostring(why)..")");
	h.extra_carcass = nil;
	TRF_Governor();
	V_QuestOn(); h.rq = {0};
	t, why = TRF_TierPick(idx, 8, 20);
	ct, cs = TRF_SafeCaps();
	HOST_Check(t == 2 and why == "gate" and ct == 2 and cs == 10, "quest system during a mission (strict gate): band 0 caps 2/10, <= TT2 ("..tostring(why)..")");
	V_QuestOff();
	h.rq = {0};
	t, why = TRF_TierPick(idx, 8, 3);
	HOST_Check(t == 1 and why == "ships", "3 free ships -> TT1");
	-- TT1 at pro 0: the same draws, ships and hold as the v0.1 path (trf_tier functions removed).
	V_Pro(0);
	local sp = function(seed)
		local hh = HOST();
		hh.seed = seed;
		local r0 = hh.rand;
		local id = T_Spawn("C");
		local r = TRF.live.tr[id];
		local tpl, hold = "", "";
		local sh = TRF_H().tr[id].sh;
		for i = 1, getn(sh) do tpl = tpl..sh[i].tpl.." "; end;
		for i = 1, getn(r.hold or {}) do hold = hold..r.hold[i].i.."x"..r.hold[i].n.." "; end;
		local inv = "";
		for i = 1, getn(sh) do for j = 1, getn(sh[i].inv) do inv = inv..sh[i].inv[j][1].."x"..sh[i].inv[j][2].." "; end; end;
		local out = {draws=hh.rand - r0, tpl=tpl, hold=hold, inv=inv, tier=r.tier};
		TRF_Remove(id, "test");
		return out;
	end;
	local a = sp(777);
	local keep = {TRF_TierPlan, TRF_BuildTier, TRF_FillHold, TRF_BandCaps};
	TRF_TierPlan = nil; TRF_BuildTier = nil; TRF_FillHold = nil; TRF_BandCaps = nil;
	local b = sp(777);
	TRF_TierPlan = keep[1]; TRF_BuildTier = keep[2]; TRF_FillHold = keep[3]; TRF_BandCaps = keep[4];
	HOST_Check(a.draws == b.draws and a.tpl == b.tpl and a.inv == b.inv and a.tier == 1,
		"TT1 at pro 0 = v0.1 path: draws "..a.draws.."/"..b.draws..", ships "..a.tpl..", cargo "..a.inv);
	-- TT2 at pro 4: 4-7 containers per transport.
	V_Pro(4);
	local id = T_Spawn("C");
	local r = TRF.live.tr[id];
	local per, ok2, nh = {}, 1, 0;
	for i = 1, getn(r.hold) do per[r.hold[i].s] = (per[r.hold[i].s] or 0) + r.hold[i].n; end;
	for k, n in per do nh = nh + 1; if n < 4 or n > 7 then ok2 = nil; end; end;
	HOST_Check(r.tier == 2 and nh >= 1 and ok2, "TT2: holds 4-7 per transport "..TRF_Dump(per));
	TRF_Remove(id, "test");
	-- TT3 at pro 9: two transports 15 apart, 6-9 each, stack A >= 3 expensive containers.
	V_Pro(9);
	local id3 = nil;
	for k = 1, 30 do
		local before = TRF.seq;
		h.rq = {0, 0};
		T_Gen();
		h.rq = {};
		if TRF.seq ~= before and TRF_Rec(TRF.seq) then
			if TRF.live.tr[TRF.seq].tier == 3 then id3 = TRF.seq; break; end;
			TRF_Remove(TRF.seq, "test");
		end;
		TRF.live.port = {};
	end;
	HOST_Check(id3 ~= nil, "TT3 spawned at pro 9");
	if id3 then
		local r3 = TRF.live.tr[id3];
		local s3 = TRF_H().tr[id3].sh;
		local dz = s3[2].pos.z - s3[1].pos.z;
		local per3, seen, ex, okh = {}, {}, 0, 1;
		local expn = {Cargo_01=1, Cargo_05=1, Cargo_06=1, Cargo_09=1, Cargo_10=1, Uranium=1};
		for i = 1, getn(r3.hold) do per3[r3.hold[i].s] = (per3[r3.hold[i].s] or 0) + r3.hold[i].n; end;
		for k, n in per3 do if n < 6 or n > 9 then okh = nil; end; end;
		for i = 1, getn(r3.hold) do
			local e = r3.hold[i];
			if not seen[e.s] then seen[e.s] = 1; if expn[e.i] and e.n >= 3 then ex = ex + 1; end; end;
		end;
		HOST_Check(r3.nt == 2 and dz == 15 and okh and ex == 2, "TT3: 2 transports 15 apart ("..dz.."), holds 6-9 "..TRF_Dump(per3)..", >= 3 expensive each");
		TRF_Remove(id3, "test");
	end;
	-- Builder: a blocked spot is skipped, the next ship keeps its own spot, no globals left.
	local blk = CreateCarcass("Hatchet_merc1", Vector3(0, 0, 1015), Vector3(0, 0, 1));
	TRF_GTest = Trade_Group_1;
	local fl, bs, made = TRF_BuildFlight(Trad_merc_Pilots, {{"Btransport",1,"A"},{"Btransport",1,"A"},{"Tiger_merc1",3,"A"}},
		"TRF_GTest", "trf_bt", Vector3(0, 0, 1000), 10, Vector3(0, 0, 1), "shipFormation", 15, 8);
	TRF_GTest = nil;
	HOST_Check(fl and getn(bs) == 2 and made[1] == 1 and made[2] == 3 and bs[2].pos.z == 1030 and bs[2].role == ROLE_ATTACK
		and getglobal("flight_trf_bt") == nil and getglobal("ship_trf_bt_1") == nil, "TRF_BuildFlight skips a nil carcass, keeps spots, leaves no globals");
	fl:Delete(); blk.alive = nil;
	V_EscFlight();
	-- Parked ship on entry at band 2; none at band 1.
	T_Jump("aurora");
	TRF.sys[idx] = {pro=6};
	T_Jump("gredos");
	TRF_SetPro(idx, 6);
	TRF_Tier_OnActivate();
	T_Tick(8, 0.5);
	local pk = GetObjectByLabel("trf_pk_1");
	HOST_Check(TRF_ParkedN() == 1 and pk and pk.cleared and pk.flight.stopped, "band 2: one parked ship (emptied, stopped)");
	-- Load (crash-load-432500.md 10): GetObjectByLabel returns the label string for mod ships, so the
	-- parked ship is found through its handle global TRF_pk_1 (via=global).
	HOST_Check(getglobal("TRF_pk_1") == pk, "parked ship: handle global TRF_pk_1 kept for the save");
	h.ms.pos = Vector3(pk.pos.x + 80, pk.pos.y, pk.pos.z);
	h.logs = {};
	T_SaveLoad(function()
		HOST().gobl = GetObjectByLabel;
		GetObjectByLabel = function(l)
			local o = HOST().gobl(l);
			if o and strsub(l, 1, 4) == "trf_" then return l; end;
			return o;
		end;
	end);
	HOST_Check(TRF_ParkedN() == 1 and TRF_H().pk[1] and TRF_H().pk[1].sh == pk and getglobal("TRF_pk_1") == pk
		and V_Logs("event=parked_load slot=1 result=kept distance=") == 1 and V_Logs(" via=global") >= 1, "load: parked ship kept through TRF_pk_1 (via=global)");
	GetObjectByLabel = h.gobl;
	h.gobl = nil; h.logs = nil;
	local h0 = TRF.std.heat;
	pk.alive = nil;
	HOST_Fire("died", "TRF_ParkDied(1,"..TRF.gen..")--");
	HOST_Check(TRF.std.heat == h0 + 1 and TRF_ParkedN() == 0 and getglobal("TRF_pk_1") == nil, "parked ship killed: heat +1, handle global cleared");
	T_Jump("aurora");
	TRF.sys[idx] = {pro=4};
	T_Jump("gredos");
	TRF_SetPro(idx, 4);
	TRF_Tier_OnActivate();
	T_Tick(8, 0.5);
	HOST_Check(TRF_ParkedN() == 0, "band 1: no parked ship");
	TRF_Tier_Dump();
end;

-- f: anti-farm by consequence (spec 4.5, 9.1, user rule) ------------------------------------------------

-- Player kill of trader id: one attack event, then every transport dies within pk_win.
function V_PlayerKill(id)
	HOST_Fire("attack", "TRF_OnAttack("..id..",1,"..TRF.gen..")--");
	local x = TRF_H().tr[id];
	for t = 1, getn(x.tp) do
		x.tp[t].alive = nil;
		HOST_Fire("died", "TRF_OnShipDied("..id..","..t..","..TRF.gen..")--");
	end;
end;

function T_V02_F()
	local h = HOST();
	h.labels.CurrentQuest = "5_1";
	V_Begin("gredos", {raids=0, staged=0, seed=0, queue=0, parked=0});
	local idx = TRF_CurIdx();
	TRF_SetDis(idx, 0);
	V_Pro(6);
	local a = T_Spawn("C");
	HOST_Check(a and TRF.live.tr[a].tier >= 2, "pro 6: first trader TT"..tostring(a and TRF.live.tr[a].tier));
	V_PlayerKill(a);
	HOST_Check(TRF_Pro(idx) == 3 and TRF_Dis(idx) == 2 and TRF.std.heat == 1 and TRF.live.kills == 1, "player kill 1: pro 6 -> 3, dis +2, heat +1");
	local b = T_Spawn("C");
	V_PlayerKill(b);
	HOST_Check(TRF_Pro(idx) == 0 and TRF_Dis(idx) == 4 and TRF.std.heat == 2 and TRF.live.kills == 2, "player kill 2: pro 0, dis 4, heat 2");
	local c = T_Spawn("C");
	HOST_Check(c and TRF.live.tr[c].tier == 1 and TRF_Band(idx) == 0, "next spawn in the same visit: TT1, band 0");
	V_PlayerKill(c);
	HOST_Check(TRF.live.kills == 3 and TRF_Pro(idx) == 0, "player kill 3: kills 3, pro stays 0");
	local ok, why = TRF_CanSpawn(2);
	HOST_Check(not ok and why == "kills" and T_Spawn() == nil, "kill cap 3: no spawns for the rest of the visit ("..tostring(why)..")");
	-- Next visit: heat 5 caps the tier at TT2 even at pro 9.
	T_Jump("aurora");
	T_Jump("gredos");
	TRF.std.heat = 5;
	TRF_SetDis(idx, 0);
	V_Pro(9);
	local t3, t2 = 0, 0;
	for k = 1, 8 do
		local d = T_Spawn("C");
		if d then
			if TRF.live.tr[d].tier == 3 then t3 = t3 + 1; end;
			if TRF.live.tr[d].tier == 2 then t2 = t2 + 1; end;
			TRF_Remove(d, "test");
		end;
		TRF.live.port = {};
	end;
	HOST_Check(t3 == 0 and t2 >= 1, "heat 5: TT2 at pro 9, no TT3 in 8 spawns ("..t2.." TT2)");
	TRF.std.heat = 0;
end;

-- g: docking queue and arrival seed (spec 9.5) ------------------------------------------------------

function T_V02_G()
	local h = HOST();
	h.labels.CurrentQuest = "5_1"; h.st_label = "TRADE STATION";
	-- dock_mode 0 (removal at the approach point): the queue checks below predate the default 2 of 2026-10-25.
	V_Begin("gredos", {raids=0, staged=0, seed=0, parked=0, dock_mode=0});
	local idx = TRF_CurIdx();
	TRF_SetDis(idx, 0);
	V_Pro(9);
	local credits = {};
	local pc = TRF_ProCredit;
	TRF_ProCredit = function(n, why) tinsert(%credits, {n, why}); return %pc(n, why); end;
	local tp0 = TRF_TierPick;
	TRF_TierPick = function() return 1, "test"; end;
	local ids = {};
	for k = 1, 4 do
		local i = T_Spawn("A");
		if i then tinsert(ids, i); T_MoveTr(i, 100 * k, 0, -600); end;
	end;
	TRF_TierPick = tp0;
	HOST_Check(getn(ids) == 4, "4 path A traders ("..getn(ids)..")");
	local msp = h.ms.pos;
	h.ms.pos = h.station:GetDockingPosition();
	T_Tick(2, 0.5);
	h.ms.pos = msp;
	for k = 1, getn(ids) do TRF_OnArrive(ids[k], 0, TRF.gen); end;
	local q = TRF.live.q;
	HOST_Check(q and q.dk == 0 and q.hp[1] == ids[1] and q.hp[2] == ids[2] and q.hp[3] == ids[3] and TRF.live.tr[ids[1]].st == "queue",
		"player at the dock: three traders hold at the 3 hold points");
	HOST_Check(TRF.live.tr[ids[4]].st == "out" and T_Stat("q_divert_full") == 1, "fourth path A trader diverts to a portal");
	T_Tick(64, 0.5);
	HOST_Check(q.dk == ids[1] and TRF.live.tr[ids[1]].qgo == 1 and q.hp[1] == 0
		and HOST_Count("f_inside", "TRF_OnArrive("..ids[1]..",3,") == 1, "30 s after the player left: the first queued trader released");
	HOST_Fire("f_inside", "TRF_OnArrive("..ids[1]..",3,");
	HOST_Check(TRF.live.tr[ids[1]].st == "dock" and q.dk == ids[1], "released trader docks (arrival type 3), one at a time");
	T_MoveTr(ids[2], 3000, 0, 3000);
	T_Tick(44, 0.5);
	HOST_Check(TRF_Rec(ids[1]) == nil and q.dk == ids[2] and TRF.live.tr[ids[2]].qgo == 1, "first docked, second released");
	HOST_Check(getn(credits) >= 1 and credits[1][1] == 3 and credits[1][2] == "dock", "path A dock: 3 credits");
	T_Tick(200, 0.5);
	HOST_Check(TRF_Rec(ids[2]) == nil and T_Stat("remove_dock") >= 2, "released trader without the approach trigger docks after 60 s");
	T_Tick(200, 0.5);
	HOST_Check(T_Stat("q_divert_wait") + T_Stat("remove_dock") >= 3, "third: released or diverted after the 180 s queue timeout");
	TRF_ProCredit = pc;
	-- Seed: chance table, 15-30 s after entry, one path B trader from the station.
	h.cfg.seed = 1;
	T_Jump("aurora");
	TRF.sys[idx] = {pro=9};
	h.logs = {};
	T_Jump("gredos");
	-- Region systems have effective danger >= 1 (clan floor, decision 11.1 #22): base 30, + 20 at pro >= 7.
	local ch = TRF_GnSeedChance();
	HOST_Check(ch == 30 + 20 and TRF_DangerEff(idx) == 1, "seed chance at effective danger 1, pro 9: 30 + 20 ("..tostring(ch)..")");
	TRF_SetDis(idx, 5);
	local ch5, w5 = TRF_GnSeedChance();
	HOST_Check(ch5 == nil and w5 == "danger", "dis 5: no seed");
	TRF_SetDis(idx, 0);
	HOST_Check(TRF.live.ent == "seed" or TRF.live.ent == "none", "entry plan ran at activation ("..tostring(TRF.live.ent)..")");
	TRF.live.ent = nil;
	h.rq = {0, 0};
	TRF_EntryPlan();
	h.rq = {};
	local s0, g0 = TRF.seq, h.gt;
	HOST_Check(TRF.live.ent == "seed", "entry plan: seed scheduled");
	local at = nil;
	for k = 1, 70 do
		T_Tick(1, 0.5);
		if not at and TRF.seq ~= s0 then at = h.gt - g0; end;
	end;
	local r = TRF.live.tr[TRF.seq];
	HOST_Check(at and at >= 15 and at <= 30.5 and r and r.seed == 1 and r.path == "B", "seed: one path B trader after "..tostring(at).." s");
	-- A staged raid planned at entry suppresses the seed.
	local sr = TRF_StagedRoll;
	TRF_StagedRoll = function() return 1; end;
	TRF.live.ent = nil;
	HOST_Check(TRF_EntryPlan() == "staged", "entry plan: staged raid first, no seed");
	TRF_StagedRoll = sr;
	local e, run = TRF_EntryPrecOf({staged=1, seed=1});
	HOST_Check(e == "staged" and run.staged == 1 and run.seed == nil, "precedence (design 6.5): staged over seed");
end;

-- h: lane raid (spec 5.1, 5.2, 5.4) ------------------------------------------------------------------

function V_Rd(n) return TRF.live.rd[n]; end;

-- Raid on trader id: the one trf_gen armed at spawn, else a forced roll. Armed raids of traders T_Spawn
-- removed again are cancelled first (the 2 s raid step does that in the game).
function V_Raid(id)
	for k, rd in TRF.live.rd do
		if type(rd) == "table" and rd.st == "armed" and not TRF_Rec(rd.id) then TRF_Rd_End(k, "cancel"); end;
	end;
	local r = TRF.live.tr[id];
	-- Hits and demand steps of earlier raids in the scenario marked combat (combat-state.md); the gate of a
	-- new raid would wait for the 25 s hold, so the roll starts clear.
	TRF.live.cbt = nil;
	if r.rdn and V_Rd(r.rdn) and V_Rd(r.rdn).st == "armed" then return r.rdn; end;
	if r.rdn then TRF_Rd_End(r.rdn, "cancel"); r.rdn = nil; end;
	HOST().rq = {0};
	local n = TRF_RaidRoll(id, "lane");
	HOST().rq = {};
	return n;
end;

-- Trader without a raid (cancels the one trf_gen may have armed).
function V_NoRaid(id)
	local r = TRF.live.tr[id];
	if r and r.rdn then TRF_Rd_End(r.rdn, "cancel"); r.rdn = nil; end;
end;

-- Sum of the hold mirror.
function V_Hold(r)
	local n = 0;
	for i = 1, getn(r.hold or {}) do n = n + r.hold[i].n; end;
	return n;
end;

function T_V02_H()
	local h = HOST();
	h.labels.CurrentQuest = "5_1"; h.st_label = "TRADE STATION";
	V_Begin("gredos", {seed=0, staged=0, queue=0, parked=0});
	local idx = TRF_CurIdx();
	local slot = TRF_RgOf(idx);
	TRF_SetDis(idx, 0);
	-- Roll conditions.
	local ok, why = TRF_Rd_Gate(idx, "raid");
	HOST_Check(ok == 1, "gate open: mod system, Pirates at war with Trade, no raid, no sweep, governor off");
	h.rel_team = {["Pirates|Trade"]=RELATION_FRIEND};
	ok, why = TRF_Rd_Gate(idx, "raid");
	HOST_Check(not ok and why == "peace", "Pirates not at war with Trade: no raid ("..tostring(why)..")");
	h.rel_team = nil;
	V_QuestOn();
	ok, why = TRF_Rd_Gate(idx, "raid");
	HOST_Check(not ok and (why == "strict" or why == "mode"), "quest system during a mission: no raid ("..tostring(why)..")");
	V_QuestOff();
	-- combat-state.md: __sys_SOS alone only mutes chatter; combat (TRF_Combat) closes the gate.
	__sys_SOS = TRUE;
	ok, why = TRF_Rd_Gate(idx, "raid");
	HOST_Check(ok == 1, "__sys_SOS alone: raid gate open ("..tostring(why)..")");
	__sys_SOS = FALSE;
	TRF_CombatMark("raid", "test");
	ok, why = TRF_Rd_Gate(idx, "raid");
	HOST_Check(not ok and why == "combat", "combat: no raid ("..tostring(why)..")");
	TRF.live.cbt = nil;
	-- Scenery in the sphere (87 to 143 raw in the game) is the visit baseline, not an excess: gate open.
	local cs0, gv0 = h.cc_static, TRF.live.gvn0;
	h.cc_static = (h.cc_static or 0) + 120;
	TRF.live.gvn0 = TRF_Safe_Count(3000);
	ok, why = TRF_Rd_Gate(idx, "raid");
	HOST_Check(ok == 1 and TRF_GovExcess() == 0, "governor: raw count above gov but no excess -> raid gate open ("..tostring(why)..")");
	h.extra_carcass = 50;
	ok, why = TRF_Rd_Gate(idx, "raid");
	HOST_Check(not ok and why == "gov", "governor: no raid");
	h.extra_carcass = nil;
	h.cc_static = cs0; TRF.live.gvn0 = gv0;
	h.cfg.raids = 0;
	local a0 = T_Spawn("C");
	HOST_Check(TRF_RaidRoll(a0, "lane") == nil and TRF.live.tr[a0].rdn == nil, "cfg raids 0: no roll");
	h.cfg.raids = nil;
	-- Tune raid_p (lab key): 100 always raids (or skips for want of a raid point), 0 never.
	h.cfg.log = 2;
	h.cfg.tune = {raid_p=100};
	TRF.live.cbt = nil;
	local np0 = V_Logs("reason=no_raid_point");
	h.rq = {9999};
	local n1 = TRF_RaidRoll(a0, "lane");
	h.rq = {};
	HOST_Check((n1 and V_Rd(n1) and V_Rd(n1).st == "armed") or V_Logs("reason=no_raid_point") == np0 + 1,
		"tune raid_p 100: roll 9999 of 10000 still raids ("..tostring(n1)..")");
	if n1 then TRF_Rd_End(n1, "cancel"); end;
	TRF.live.tr[a0].rdn = nil;
	h.cfg.tune = {raid_p=0};
	local nr0 = V_Logs("trader_id="..a0.." source=lane");
	local z = nil;
	h.rq = {0, 0, 0};
	for k = 1, 3 do z = z or TRF_RaidRoll(a0, "lane"); end;
	h.rq = {};
	HOST_Check(z == nil and V_Logs("chance=0.000 roll=0 result=no_raid") == 3 and V_Logs("trader_id="..a0.." source=lane") == nr0 + 3,
		"tune raid_p 0: roll 0 gives no_raid at chance 0");
	h.cfg.tune = nil;
	h.cfg.log = 1;
	TRF_Remove(a0, "test");
	-- 1. Comply (path A, not docked: shortage).
	local id = T_Spawn("A");
	local r = TRF.live.tr[id];
	local x = TRF_H().tr[id];
	local n = V_Raid(id);
	HOST_Check(n and V_Rd(n).st == "armed" and r.rdn == n and HOST_Count("f_inside", "TRF_RaidGo("..n..",") == 1, "roll: armed with an f_inside trigger at the raid point");
	local ok2, w2 = TRF_Rd_Gate(idx, "raid", n);
	local ok3, w3 = TRF_Rd_Gate(idx, "raid");
	HOST_Check(ok2 == 1 and not ok3 and w3 == "busy", "an armed raid blocks a second raid ("..tostring(w3)..")");
	HOST_Fire("f_inside", "TRF_RaidGo("..n..",");
	local hr = TRF_H().rd[n];
	-- Tier from the clan (5.3): T1 <= 2 ships, rookies; T2 <= 4 ships, PirateTough lead, rookie wings.
	local T = V_Rd(n).tier;
	local nmax, lead, wing = 2, "PirateRookie", "PirateRookie";
	if T == 2 then nmax, lead = 4, "PirateTough"; end;
	local pil = 1;
	for j = 2, getn(hr.sh) do if hr.sh[j].pilot.tpl ~= wing then pil = nil; end; end;
	HOST_Check(V_Rd(n).st == "come" and hr and getn(hr.sh) >= 1 and getn(hr.sh) <= nmax and hr.sh[1].label == "trf_raid_"..n.."_1"
		and hr.sh[1].pilot.tpl == lead and pil and V_Rd(n).hp0 == 1000 and T == TRF_EffTier(idx),
		"go: T"..tostring(T).." raid flight ("..getn(hr.sh).." ships, lead "..hr.sh[1].pilot.tpl.."), labelled, hp0");
	local rn = 0;
	for i = 1, getn(h.rel) do if h.rel[i][1] == "TRF_Raid_"..n and h.rel[i][2] == PLAYER_GROUP and h.rel[i][3] == RELATION_NEUTRAL then rn = rn + 1; end; end;
	HOST_Check(rn == 1 and HOST_Count("attack", "TRF_OnRaidHit("..n..",") == getn(hr.sh) and HOST_Count("died", "TRF_OnRaidDied("..n..",") == getn(hr.sh),
		"go: raid group neutral to the player (one way), hit and died triggers per ship");
	HOST_Fire("f_object_inside", "TRF_RaidMeet("..n..",");
	HOST_Check(V_Rd(n).st == "demand" and x.fl.stopped and T_Lines("Cut your engines") == 1, "meet: demand line, trader stopped");
	local d0, c0, h0 = TRF_Dis(idx), TRF_ClanScore(slot), V_Hold(r);
	T_Tick(14, 0.5);
	HOST_Check(V_Rd(n).st == "demand", "decide waits 8 s (7 s: still demand)");
	-- A timid trader (br kept from an earlier raid): comply chance 100 - 5 x q, q = trader / raid side.
	r.br = 0.05;
	h.rq = {0, 2};
	T_Tick(4, 0.5);
	h.rq = {};
	HOST_Check(r.br == 0.05 and V_Logs("braveness=0.050 chance=") == 1 and V_Logs("roll=0 result=comply") == 1, "decide: kept br reused, roll 0 -> comply");
	HOST_Check(V_Hold(r) == h0 - 3 and x.tp[1].cleared and T_Lines("Cargo released") == 1, "comply at 8 s: 3 containers off the mirror ("..h0.." -> "..V_Hold(r).."), transport cleared and refilled");
	local inv = 0;
	for t = 1, getn(x.tp) do inv = inv + getn(x.tp[t].inv); end;
	HOST_Check(inv == getn(r.hold), "comply: re-added stacks match the mirror");
	HOST_Check(TRF_Dis(idx) == d0 + 1 and TRF_ClanScore(slot) == min(99, c0 + 1) and getn(TRF_ShortOf(idx)) >= 1, "comply: dis +1, clan +1, shortage (path A)");
	-- Comply chance by relative strength and braveness: lone transport, timid trader (p near comply_max);
	-- strong escort, brave trader (p near comply_min). Raid side: power 5 x 2 ships.
	HOST_Check(TRF_Rd_EscAlive(r, x) == getn(x.sh) - getn(x.tp) and TRF_Rd_EscAlive({np=1, nt=1}, nil) == 0, "escorts alive: ships minus transports");
	local pl = TRF_Rd_ComplyOf(5 * (TRF_Rd_EscAlive({np=1, nt=1}, nil) + 0.5), 5 * 2, 0.2);
	local ps = TRF_Rd_ComplyOf(10 * (TRF_Rd_EscAlive({np=5, nt=1}, nil) + 0.5), 5 * 2, 1);
	local pm = TRF_Rd_ComplyOf(5 * 1.5, 5 * 2, 0.6);
	HOST_Check(pl == 95 and ps == 5 and pm == 55, "comply chance: lone timid "..pl.." (95), strong brave "..ps.." (5), 1 escort br 0.6 "..pm.." (55)");
	-- Braveness: rolled once in [brave_lo, brave_hi], then kept on the record.
	local bt, nr = {}, h.rand;
	h.rq = {500};
	local b1 = TRF_Rd_Brave(bt);
	h.rq = {1000};
	local b2 = TRF_Rd_Brave(bt);
	h.rq = {};
	HOST_Check(abs(b1 - 0.6) < 0.001 and b2 == b1 and bt.br == b1 and h.rand == nr + 1, "braveness: one roll (0.2 + 0.8 x 500/1000 = "..TRF_F(b1).."), kept as r.br");
	T_Tick(12, 0.5);
	HOST_Check(V_Rd(n).st == "end" and V_Rd(n).how == "left" and V_Rd(n).tier == nil and TRF_H().rd[n] == nil and hr.fl.deleted,
		"leave 5 s after comply: out of view deleted, record ended and stripped ("..tostring(V_Rd(n).how)..")");
	TRF_Remove(id, "test");
	-- 2. Refuse: the player fired on the raiders first; flee, distress with marker; the 240 s distress rate.
	local id2 = T_Spawn("C");
	local r2 = TRF.live.tr[id2];
	local n2 = V_Raid(id2);
	HOST_Fire("f_inside", "TRF_RaidGo("..n2..",");
	local hr2 = TRF_H().rd[n2];
	HOST_Fire("attack", "TRF_OnRaidHit("..n2..",1,");
	HOST_Check(V_Rd(n2).ph == 1 and HOST_Count("attack", "TRF_OnRaidHit("..n2..",1,") == 2, "player hit on a raid ship: ph set, trigger re-armed");
	HOST_Fire("f_object_inside", "TRF_RaidMeet("..n2..",");
	T_MoveTr(id2, h.ms.pos.x + 100, 0, h.ms.pos.z);
	-- First decision on this trader: br rolled at brave_lo (forced 0) and stored; roll 0 is below p, but
	-- ph = 1 refuses.
	T_Tick(14, 0.5);
	h.rq = {0, 0};
	T_Tick(3, 0.5);
	h.rq = {};
	HOST_Check(r2.br == 0.2 and V_Logs("braveness=0.200 ") == 1 and V_Logs("roll=0 result=refuse") == 1, "decide: br rolled once and stored (0.2), ph = 1 refuses at roll 0");
	HOST_Check(V_Rd(n2).st == "fight" and V_Rd(n2).dc == "refuse" and hr2.fl.att ~= nil and r2.st == "flee" and r2.fl == "raid",
		"refuse at 8 s: raid attacks, trader flees ("..tostring(r2.st)..")");
	HOST_Check(T_Lines("pirates on us") == 1 and HOST_Navs() == 1 and h.navs[getn(h.navs)].label == "trf_nav_"..n2, "refuse: distress line and nav marker");
	HOST_Check(not TRF_Distress(id2, "raid", 1) and T_Lines("pirates on us") == 1, "distress rate: none again within 240 s");
	-- Leave at the HP threshold (T1 50 %, T2 40 % of hp0).
	hr2.sh[1].hp = 300;
	T_Tick(6, 0.5);
	HOST_Check(V_Rd(n2).st == "leave" or V_Rd(n2).st == "end", "raid leader at 30 % HP: raid leaves ("..tostring(V_Rd(n2).st)..")");
	if V_Rd(n2).st == "leave" then HOST_FireAll("f_object_inside", "TRF_RaidGone("..n2..","); end;
	HOST_Check(V_Rd(n2).st == "end" and HOST_Navs() == 0, "raid ended: nav marker deleted");
	-- 3. Player side under a live escort contract: TRF_Rd_PlayerSide adds trf_supply's power x ships proxy when
	-- the trader holds the contract and the mothership is within R_threat of its leader.
	local id3 = T_Spawn("C");
	local r3, x3 = TRF.live.tr[id3], TRF_H().tr[id3];
	local n3 = V_Raid(id3);
	HOST_Fire("f_inside", "TRF_RaidGo("..n3..",");
	HOST_Fire("f_object_inside", "TRF_RaidMeet("..n3..",");
	T_MoveTr(id3, h.ms.pos.x + 100, 0, h.ms.pos.z);
	local rd3 = V_Rd(n3);
	local p0 = TRF_Rd_PlayerSide(rd3, r3, x3);
	local octl, osps = TRF_CtLive, TRF_SpPlayerSide;
	TRF_CtLive = function() return {id=%id3, n=1, t=0}; end;
	TRF_SpPlayerSide = function() return 15, 5, 2; end;
	local p1 = TRF_Rd_PlayerSide(rd3, r3, x3);
	T_MoveTr(id3, h.ms.pos.x + 1000, 0, h.ms.pos.z);
	local p2 = TRF_Rd_PlayerSide(rd3, r3, x3);
	TRF_SpPlayerSide = nil;
	T_MoveTr(id3, h.ms.pos.x + 100, 0, h.ms.pos.z);
	local p3 = TRF_Rd_PlayerSide(rd3, r3, x3);
	TRF_SpPlayerSide = function() return 15, 5, 2; end;
	HOST_Check(p0 == 0 and p1 == 15 and p2 == 0 and p3 == 0, "player side: no contract "..p0.." (0), contract and near "..p1.." (15), far "..p2.." (0), no trf_supply "..p3.." (0)");
	-- Decide with the player near: br is set so the trader side alone stays above comply_min and the added
	-- power drives the chance to comply_min 5; roll 5 refuses.
	local pw3, ns3 = rd3.pw or 5, rd3.ns or 1;
	local st3, sr3 = (r3.pw or pw3) * (TRF_Rd_EscAlive(r3, x3) + 0.5), pw3 * ns3;
	r3.br = 0.95 * sr3 / (st3 + 7.5);
	local c3 = TRF_Rd_ComplyOf(st3, sr3, r3.br);
	h.rq = {5};
	TRF_RaidDecide(n3);
	h.rq = {};
	TRF_CtLive, TRF_SpPlayerSide = octl, osps;
	HOST_Check(c3 > 5 and V_Logs("player_strength=15.000 ") == 1 and V_Logs("chance=5.000 roll=5 result=refuse") == 1 and V_Rd(n3).dc == "refuse",
		"decide: contracted trader with the player near counts player_strength 15, chance "..TRF_F(c3).." -> 5, roll 5 refuses");
	HOST_Check(TRF_CtLive == octl and TRF_SpPlayerSide == osps, "player side stubs restored");
	TRF_Remove(id3, "test");
	HOST_Check(T_BadCallbacks() == "", "every callback carries the gen"..T_BadCallbacks());
	TRF_Raid_Dump();
end;

-- i: player help and pay (spec 5.5, 5.6 pay rule) ---------------------------------------------------------

function T_V02_I()
	local h = HOST();
	h.labels.CurrentQuest = "5_1"; h.st_label = "TRADE STATION";
	V_Begin("gredos", {seed=0, staged=0, queue=0, parked=0});
	local idx = TRF_CurIdx();
	TRF_SetDis(idx, 0);
	-- L_w (TDR 8.4) = clamp(round(0.8 sys_base), 3, 16): sys_base from the map's sb, else the trader contact level.
	local ms = TRF_Map().sys[idx];
	local sbm = ms.sb;
	HOST_Check(type(sbm) == "number" and TRF_SysBase(idx) == sbm and TRF_LPay() == TRF_Clamp(floor(0.8 * sbm + 0.5), 3, 16),
		"L_w from the map's sb "..tostring(sbm).." = "..TRF_LPay());
	ms.sb = nil;
	local sb0 = TRF_SysBase(idx);
	HOST_Check(type(sb0) == "number" and TRF_LPay() == TRF_Clamp(floor(0.8 * sb0 + 0.5), 3, 16),
		"map without sb: L_w from the trader contact level "..tostring(sb0).." = "..TRF_LPay());
	local lw = {};
	for i, v in {2, 25, 10, 5} do ms.sb = v; lw[i] = TRF_LPay(idx); end;
	HOST_Check(lw[1] == 3 and lw[2] == 16 and lw[3] == 8 and lw[4] == 4, "L_w clamp: sys_base 2/25/10/5 -> 3/16/8/4 ("..lw[1].."/"..lw[2].."/"..lw[3].."/"..lw[4]..")");
	local o = 1;
	if idx == 1 then o = 2; end;
	local mo = TRF_Map().sys[o];
	local so = mo.sb;
	mo.sb = nil;
	HOST_Check(TRF_LPay(o) == 8, "L_w 8 without sys_base (other system: no sb, no contact list)");
	mo.sb = so;
	-- N_eff = min(900 L_w lk tier_k (1 + 0.05 pro) d_k, pay_cap), lk = min(1, L_w / 8), d_k 1.25 / 1 / 0.7.
	local sl = TRF_RgOf(idx);
	TRF.clan[sl].sc = 30;
	TRF_SetPro(idx, 0);
	ms.sb = 5;
	HOST_Check(TRF_TierK(idx) == 1.0 and TRF_LK(idx) == 0.5 and TRF_PayN(idx) == 1800,
		"lk damping at L_w 4: 900 x 4 x 0.5 (T2, pro 0, NORMAL) = 1800 (tier_k "..TRF_TierK(idx)..", "..TRF_PayN(idx)..")");
	ms.sb = 10;
	local nn = TRF_PayN(idx);
	h.diff = HARD;
	local nh = TRF_PayN(idx);
	h.diff = EASY;
	local nz = TRF_PayN(idx);
	h.diff = NORMAL;
	HOST_Check(nn == 7200 and abs(nh - 5040) <= 1 and nz == 9000, "d_k at L_w 8, T2, pro 0: NORMAL 7200, HARD x 0.7 = "..nh..", EASY x 1.25 = "..nz);
	TRF.clan[sl].sc = 99;
	TRF_SetPro(idx, 9);
	ms.sb = 25;
	h.diff = EASY;
	local nu = min(30000, 900 * 16 * TRF_TierK(idx) * 1.45 * 1.25);
	HOST_Check(abs(TRF_PayN(idx) - nu) <= 1 and nu > 15000, "N_eff at L_w 16, tier_k "..TRF_TierK(idx)..", pro 9, EASY = "..TRF_PayN(idx)
		.." (no 15000 cap before tier_k)");
	h.cfg.tune = {pay_cap=20000};
	HOST_Check(TRF_PayN(idx) == 20000, "pay_cap 20000 bounds N_eff "..floor(nu).." ("..TRF_PayN(idx)..")");
	h.cfg.tune = nil;
	h.diff = NORMAL;
	ms.sb = sbm;
	TRF.clan[sl].sc = 55;
	TRF_SetPro(idx, 6);
	-- Help: 5 distinct seconds of player hits on a raid ship; all raid ships killed -> pay 50 % N_eff.
	local id = T_Spawn("C");
	local n = V_Raid(id);
	HOST_Fire("f_inside", "TRF_RaidGo("..n..",");
	local hr = TRF_H().rd[n];
	T_MoveTr(id, h.ms.pos.x + 100, 0, h.ms.pos.z);
	for i = 1, 4 do HOST_Fire("attack", "TRF_OnRaidHit("..n..",1,"); T_Tick(2, 0.5); end;
	HOST_Check(V_Rd(n).hit == nil, "4 seconds of hits: not yet help");
	HOST_Fire("attack", "TRF_OnRaidHit("..n..",1,");
	HOST_Check(V_Rd(n).hit == 1, "5th distinct second: help counts (T_deliberate)");
	TRF.std.heat = 2;
	local cr0, hp0 = h.credits, TRF.std.help;
	local want = floor(0.5 * TRF_PayN(idx));
	for j = 1, getn(hr.sh) do
		hr.sh[j].alive = nil;
		HOST_Fire("died", "TRF_OnRaidDied("..n..","..j..",");
	end;
	HOST_Check(V_Rd(n).st == "end" and V_Rd(n).how == "killed" and h.credits - cr0 == want and want > 0, "raid killed: paid 50 % N_eff = "..want.." ("..(h.credits - cr0)..")");
	HOST_Check(TRF.std.help == hp0 + 1 and TRF.std.heat == 1 and T_Lines("Thank you, Wolves") == 1 and TRF.live.tr[id].res == 1, "help +1, heat -1, thanks line, trader rescued");
	HOST_Check(T_Stat("pirate_kill") == 1, "killed raid counts once as a pirate kill");
	TRF_Remove(id, "test");
	-- A raid ship killed within 10 s of one player hit counts too; the trader killed -> no pay.
	-- Death bus (wb-plumbing-spec 2): every raid ship death reaches the registered module, pfire from the same rule.
	h.dead = {};
	TRF_DeathReg("Hv");
	local id3 = T_Spawn("C");
	local x3 = TRF_H().tr[id3];
	local n3 = V_Raid(id3);
	HOST_Fire("f_inside", "TRF_RaidGo("..n3..",");
	local hr3 = TRF_H().rd[n3];
	HOST_Fire("attack", "TRF_OnRaidHit("..n3..",1,");
	hr3.sh[1].alive = nil;
	HOST_Fire("died", "TRF_OnRaidDied("..n3..",1,");
	HOST_Check(V_Rd(n3).hit == 1, "raid ship dead within 10 s of a player hit: help counts");
	local c3 = h.credits;
	for t = 1, getn(x3.tp) do x3.tp[t].alive = nil; HOST_Fire("died", "TRF_OnShipDied("..id3..","..t..","); end;
	HOST_Check(V_Rd(n3).tk == 1 and TRF.live.tr[id3].why == "kill", "trader killed: raid marked, record stripped");
	for j = 2, getn(hr3.sh) do hr3.sh[j].alive = nil; HOST_Fire("died", "TRF_OnRaidDied("..n3..","..j..","); end;
	T_Tick(4, 0.5);
	HOST_Check(V_Rd(n3).st == "end" and h.credits == c3, "trader dead: no pay");
	-- Proximity only: the player near the fight, no hits -> nothing.
	local id4 = T_Spawn("C");
	local n4 = V_Raid(id4);
	HOST_Fire("f_inside", "TRF_RaidGo("..n4..",");
	local hr4 = TRF_H().rd[n4];
	T_MoveTr(id4, h.ms.pos.x + 50, 0, h.ms.pos.z);
	for j = 1, getn(hr4.sh) do hr4.sh[j].pos = Vector3(h.ms.pos.x + 60, 0, h.ms.pos.z); end;
	T_Tick(30, 0.5);
	local c4 = h.credits;
	for j = 1, getn(hr4.sh) do hr4.sh[j].alive = nil; HOST_Fire("died", "TRF_OnRaidDied("..n4..","..j..","); end;
	HOST_Check(V_Rd(n4).hit == nil and h.credits == c4, "proximity only: no help, no pay");
	local dd = "";
	for i = 1, getn(h.dead) do dd = dd..h.dead[i]..";"; end;
	HOST_Check(getn(h.dead) == getn(hr3.sh) + getn(hr4.sh) and h.dead[1] == "raid|TRF_Raid_"..n3.."|1|1" and h.dead[2] == "raid|TRF_Raid_"..n3.."|2|nil"
		and h.dead[getn(h.dead)] == "raid|TRF_Raid_"..n4.."|"..getn(hr4.sh).."|nil", "death bus: one call per raid ship, player fire only for the hit ship ("..dd..")");
end;

-- j: staged raid (spec 5.4) ------------------------------------------------------------------------

function T_V02_J()
	local h = HOST();
	h.labels.CurrentQuest = "5_1"; h.st_label = "TRADE STATION";
	V_Begin("elio", {seed=0, queue=0, parked=0});
	local idx = TRF_CurIdx();
	-- dis gate 3, guard system 5.
	TRF.live.ent = nil;
	TRF_SetDis(idx, 2);
	HOST_Check(not TRF_StagedRoll(), "dis 2: no staged raid");
	h.labels.CurrentQuest = "3";
	T_Jump("gredos");
	idx = TRF_CurIdx();
	TRF.live.ent = nil;
	TRF_SetDis(idx, 4);
	HOST_Check(not TRF_StagedRoll(), "guard system (gredos, chapter 3): dis 4 is not enough");
	h.labels.CurrentQuest = "5_1";
	T_Jump("elio");
	idx = TRF_CurIdx();
	TRF.live.ent = nil;
	TRF_SetDis(idx, 6);
	h.ms.pos = Vector3(-300, 30, 1500);
	TRF_CombatMark("raid", "test");
	HOST_Check(not TRF_StagedRoll(), "combat: no staged raid");
	TRF.live.cbt = nil;
	h.cfg.staged = 0;
	HOST_Check(not TRF_StagedRoll(), "cfg staged 0: no staged raid");
	h.cfg.staged = nil;
	h.rq = {0, 0, 0};
	HOST_Check(TRF_StagedRoll() == 1 and type(TRF.live.stg) == "table", "dis 6: staged raid planned (chance 55 %, roll forced)");
	h.rq = {};
	local g0 = h.gt;
	local sn, srd = nil, nil;
	for k = 1, 30 do
		T_Tick(1, 0.5);
		sn = TRF.live.nrd;
		srd = sn and V_Rd(sn);
		if srd and srd.sg == 1 and srd.st == "fight" then break; end;
	end;
	local dt = h.gt - g0;
	HOST_Check(srd and srd.sg == 1 and srd.st == "fight" and TRF_H().rd[sn] ~= nil and dt >= 5 and dt <= 10.5, "spawn 5-10 s after the plan ("..dt.." s): trader and raid fighting");
	local sid = srd.id;
	local sh = TRF_H().tr[sid].sh;
	HOST_Check(sh[1].hp == 700, "trader leader at 70 % HP");
	local rp = TRF_H().tr[sid].fl:GetPosition();
	local dm = HOST_Dist(rp, h.ms.pos);
	HOST_Check(dm > 600 and dm <= 2000, "placement: 600-2000 from the mothership ("..floor(dm)..")");
	local g1 = h.gt;
	local sd = nil;
	for k = 1, 50 do
		T_Tick(1, 0.5);
		if not sd and type(srd.we) == "number" then sd = h.gt - g1; end;
	end;
	HOST_Check(sd and sd >= 10 and sd <= 21 and HOST_Navs() == 1, "distress with marker 10-20 s after the spawn ("..tostring(sd).." s)");
	-- The fighting trader holds still (host ships do not move): the watchdog must leave it to the raid.
	local kept = 1;
	for k = 1, 370 do
		T_Tick(1, 0.5);
		if V_Rd(sn).st ~= "end" and not TRF_Rec(sid) then kept = nil; end;
	end;
	HOST_Check(kept and T_Stat("remove_stuck") == 0, "stationary staged trader not removed by the watchdog during the window");
	HOST_Check(V_Rd(sn).st == "end" and TRF.live.tr[sid].fl == "staged", "180 s window end: raid leaves, trader flees ("..tostring(V_Rd(sn).how)..")");
	-- A second roll in the same visit: at most one per entry.
	HOST_Check(not TRF_StagedRoll(), "one staged raid per entry");
	-- Trader killed in a staged raid: dis +2 and a shortage (path A) or none.
	T_Jump("aurora");
	T_Jump("elio");
	idx = TRF_CurIdx();
	TRF.live.ent = nil;
	TRF_SetDis(idx, 6);
	h.rq = {0, 0, 0};
	TRF_StagedRoll();
	h.rq = {};
	for k = 1, 30 do T_Tick(1, 0.5); if TRF.live.nrd and V_Rd(TRF.live.nrd) and V_Rd(TRF.live.nrd).st == "fight" then break; end; end;
	local k2 = TRF.live.nrd;
	local id2 = V_Rd(k2).id;
	local x2 = TRF_H().tr[id2];
	local d0 = TRF_Dis(idx);
	local path = TRF.live.tr[id2].path;
	for t = 1, getn(x2.tp) do x2.tp[t].alive = nil; HOST_Fire("died", "TRF_OnShipDied("..id2..","..t..","); end;
	HOST_Check(TRF_Dis(idx) == min(9, d0 + 2) and (path ~= "A" or getn(TRF_ShortOf(idx)) >= 1), "staged trader killed: dis +2, shortage if path A (path "..tostring(path)..")");
end;

-- k: hail menu and escort contract (spec 5.6, 6.1-6.4) -------------------------------------------------

-- Walk the open hail menu to option key (Cancel and the due call per step); 1 when it is the open box.
function V_HailTo(key)
	for i = 1, 8 do
		local hl = TRF.live.hl;
		if not hl then return nil; end;
		if hl.o[hl.k] == key and hl.w == "menu" then return 1; end;
		HOST_Press("cancel");
		T_Tick(1, 0.5);
	end;
	return nil;
end;

-- Press OK on the newest box and let the due call run.
function V_Ok() HOST_Press("ok"); T_Tick(1, 0.5); end;

-- Hail trader id: meeting (announce and arm), mothership 40 from the leader, focus. Returns the open menu.
function V_Hail(id)
	local h = HOST();
	T_MoveTr(id, h.ms.pos.x + 40, h.ms.pos.y, h.ms.pos.z);
	if not TRF.live.tr[id].ha then HOST_Fire("f_object_inside", "TRF_OnMeet("..id..","); end;
	HOST_Fire("focus", "TRF_OnHail("..id..",");
	return TRF.live.hl;
end;

-- Accept an escort contract from trader id (hail, escort option, offer OK). Returns live.ct. The offer
-- decision is set to yes (r.co = 1), so the escort option does not depend on the roll.
function V_Contract(id)
	TRF.live.tr[id].co = 1;
	V_Hail(id);
	if not V_HailTo("esc") then return nil; end;
	V_Ok();
	V_Ok();
	return TRF.live.ct;
end;

-- Breadth-first jumps from idx over the map portals: {[idx] = jumps}.
function V_Jumps(idx)
	local m = TRF_Map();
	local d, q = {[idx]=0}, {idx};
	local i = 1;
	while i <= getn(q) do
		local c = q[i];
		i = i + 1;
		local ps = m.sys[c].portals;
		for k = 1, getn(ps) do
			local t = m.by[ps[k].to];
			if t and not d[t] then d[t] = d[c] + 1; tinsert(q, t); end;
		end;
	end;
	return d;
end;

function T_V02_K()
	local h = HOST();
	h.labels.CurrentQuest = "5_1"; h.st_label = "TRADE STATION";
	V_Begin("gredos", {seed=0, staged=0, raids=0, queue=0, parked=0});
	local cur = TRF_CurIdx();
	TRF_SetDis(cur, 0);
	local a = T_Spawn("B") or T_Spawn("A");
	local r = TRF.live.tr[a];
	T_MoveTr(a, h.ms.pos.x + 40, h.ms.pos.y, h.ms.pos.z);
	local s0, m0 = getn(h.screen), h.meet;
	HOST_Fire("f_object_inside", "TRF_OnMeet("..a..",");
	HOST_Check(h.meet == m0 and getn(h.screen) == s0 + 1 and strfind(h.screen[getn(h.screen)].t, "open for trade", 1, 1) and type(r.ha) == "number",
		"meet 2: announce line with the band remark, no vanilla box ("..tostring(h.screen[getn(h.screen)].t)..")");
	-- Focus beyond 150: no box, the focus trigger re-armed.
	T_MoveTr(a, h.ms.pos.x + 200, h.ms.pos.y, h.ms.pos.z);
	local nb = getn(h.boxes);
	HOST_Fire("focus", "TRF_OnHail("..a..",");
	HOST_Check(getn(h.boxes) == nb and HOST_Count("focus", "TRF_OnHail("..a..",") == 2, "focus at 200: no menu, trigger re-armed");
	T_MoveTr(a, h.ms.pos.x + 40, h.ms.pos.y, h.ms.pos.z);
	HOST_Fire("focus", "TRF_OnHail("..a..",");
	HOST_Check(getn(h.boxes) == nb + 1 and strfind(HOST_Box().text, ": Trade?", 1, 1) and TRF.live.hl.o[1] == "trade", "focus within 150: box 1 'Trade?'");
	HOST_Press("cancel");
	HOST_Check(getn(h.boxes) == nb + 1, "Cancel: no box inside the callback");
	T_Tick(1, 0.5);
	HOST_Check(getn(h.boxes) == nb + 2 and strfind(HOST_Box().text, "headed", 1, 1), "next box after the due call");
	V_Ok();
	local ans = HOST_Box();
	HOST_Check(ans.cancel == nil and ans.text == TRF_Headed(a), "headed answer in a one-button box: "..ans.text);
	HOST_Press("ok");
	HOST_Check(TRF.live.hl == nil and r.hd == 1 and r.hn == 1, "answer OK closes the chain");
	nb = getn(h.boxes);
	HOST_Fire("focus", "TRF_OnHail("..a..",");
	HOST_Check(getn(h.boxes) == nb, "second hail within 60 s: refused (cooldown)");
	-- Second hail after the cooldown, with dis 2: the escort offer.
	T_Tick(122, 0.5);
	TRF_SetDis(cur, 2);
	h.credits = 0;
	local ct = V_Contract(a);
	HOST_Check(type(ct) == "table" and ct.id == a and r.ct == 1 and r.hn == 2 and ct.n == TRF_PayN(cur), "contract accepted from the due call, pay fixed at N_eff "..tostring(ct and ct.n));
	HOST_Check(TRF_CtArrive(a, "exit") == 1 and h.credits == ct.n and TRF.std.help == 1 and T_Lines("Safe arrival") == 1 and TRF.live.ct == nil,
		"success near the trader: paid "..h.credits..", help +1, line");
	T_Tick(130, 0.5);
	nb = getn(h.boxes);
	HOST_Fire("focus", "TRF_OnHail("..a..",");
	HOST_Check(getn(h.boxes) == nb, "third hail: refused (2 per trader)");
	-- Far at arrival: void, line.
	local b = T_Spawn("B") or T_Spawn("A");
	ct = V_Contract(b);
	HOST_Check(type(ct) == "table", "second contract accepted");
	T_MoveTr(b, h.ms.pos.x + 900, 0, h.ms.pos.z);
	local c0 = h.credits;
	HOST_Check(TRF_CtArrive(b, "dock") == nil and h.credits == c0 and T_Lines("you were not with us") == 1, "mothership 900 away at arrival: void, no pay");
	-- Kill: no pay, dis +1 on top of the kill's +2.
	local c = T_Spawn("B") or T_Spawn("A");
	V_Contract(c);
	local d0 = TRF_Dis(cur);
	local xc = TRF_H().tr[c];
	for t = 1, getn(xc.tp) do xc.tp[t].alive = nil; HOST_Fire("died", "TRF_OnShipDied("..c..","..t..","); end;
	HOST_Check(TRF.live.ct == nil and TRF_Dis(cur) == min(9, d0 + 3) and T_Lines("Contract lost") == 1, "contracted trader killed: no pay, dis +1 + 2");
	-- Jump and load void.
	local e = T_Spawn("B") or T_Spawn("A");
	V_Contract(e);
	HOST_Check(type(TRF.live.ct) == "table", "contract before the save");
	T_SaveLoad();
	HOST_Check(TRF.live.ct == nil, "load: contract void");
	-- Wind-down keeps the contract; the exit pays.
	local f = T_Spawn("B") or T_Spawn("A");
	TRF_SetDis(cur, 2);
	ct = V_Contract(f);
	T_MoveTr(f, h.ms.pos.x + 60, 0, h.ms.pos.z);
	__disableAction = TRUE;
	T_Tick(22, 0.5);
	HOST_Check(TRF.live.tr[f].st == "wind" and type(TRF.live.ct) == "table", "wind-down keeps the contract");
	c0 = h.credits;
	HOST_Fire("f_object_inside", "TRF_OnExit("..f..","..TRF.gen..")--");
	HOST_Check(ct and h.credits == c0 + ct.n and TRF.live.ct == nil, "wind-down: paid at the exit");
	__disableAction = FALSE;
	-- design/strength-spec.md 4.5: pro 7 rolls TT4/TT3 traders now, so the live ones fill the ship cap; clear them first.
	for id, rr in TRF.live.tr do if type(rr) == "table" and rr.st ~= "gone" then TRF_Remove(id, "test"); end; end;
	local g = T_Spawn("B") or T_Spawn("A");
	V_Contract(g);
	T_Jump("aurora");
	HOST_Check(TRF.live.ct == nil and V_Logs("result=void reason=jump") >= 1, "jump: contract void");
	-- The gate uses the raid roll's effective danger: nj1 and taira have map dg 0 under a clan (floor 1).
	local m = TRF_Map();
	HOST_Check(TRF_HlDanger(64, m.sys[64]) == 1 and TRF_HlDanger(79, m.sys[79]) == 1 and TRF_HlDanger(27, m.sys[27]) == 0,
		"contract danger: nj1 1, taira 1 (clan floor), earth 0 (independent)");
	local ord, ode = TRF_Rd_DangerEff, TRF_DangerEff;
	TRF_Rd_DangerEff, TRF_DangerEff = nil, nil;
	HOST_Check(TRF_HlDanger(64, m.sys[64]) == 1 and TRF_HlDanger(27, m.sys[27]) == 0 and TRF_HlDanger(27, {}) == 1,
		"contract danger without trf_raid/trf_region: map dg with the clan floor, 1 without dg");
	TRF_Rd_DangerEff, TRF_DangerEff = ord, ode;
	T_Jump("nj1");
	TRF_SetDis(TRF_CurIdx(), 0);
	local nj = T_Spawn("B") or T_Spawn("A");
	local njr = TRF.live.tr[nj];
	-- Offer roll: p = clamp(100 x min(1, (dE + 0.5 x dis) / 3) x (1.3 - br), 5, 95); dE 1, dis 0, br 0.2 -> 36.7.
	njr.br, njr.co = 0.2, nil;
	tinsert(h.rq, 0);
	local otx, own = TRF_CtOffer(nj);
	HOST_Check(TRF_CurIdx() == 64 and type(otx) == "string" and own == TRF_HlPayN(64) and njr.co == 1
		and V_Logs("event=contract_offer trader_id="..nj.." danger_eff=1 disruption=0 braveness=0.20 chance=36.7 roll=0 result=offered") == 1,
		"nj1 (map dg 0, clan region), dis 0, br 0.2: offer roll 0 < p 36.7, contract offered ("..tostring(own)..")");
	local nr0 = h.rand;
	local otx2 = TRF_CtOffer(nj);
	HOST_Check(type(otx2) == "string" and h.rand == nr0 and V_Logs("event=contract_offer trader_id="..nj.." ") == 1, "offer decision sticks: second call, no draw, no log");
	njr.co = 0;
	local otx3, why3 = TRF_CtOffer(nj);
	HOST_Check(otx3 == nil and why3 == "roll", "r.co 0: no offer, reason roll");
	HOST_Check(abs(TRF_CtOfferP(0, 0, 0.5) - 5) < 0.001 and abs(TRF_CtOfferP(3, 0, 0.2) - 95) < 0.001
		and abs(TRF_CtOfferP(1, 0, 1) - 10) < 0.001 and abs(TRF_CtOfferP(0, 2, 1) - 10) < 0.001,
		"TRF_CtOfferP: dE 0 dis 0 -> min 5, dE 3 br 0.2 -> max 95, dE 1 br 1 -> 10, dis 2 counts as dE 1");
	-- br 1 -> p 10: roll 10 declines; without trf_raid the braveness is rolled here and kept as r.br.
	local nk = T_Spawn("B") or T_Spawn("A");
	local nkr = TRF.live.tr[nk];
	nkr.br, nkr.co = 1, nil;
	tinsert(h.rq, 10);
	local otx4, why4 = TRF_CtOffer(nk);
	HOST_Check(otx4 == nil and why4 == "roll" and nkr.co == 0 and V_Logs("event=contract_offer trader_id="..nk.." danger_eff=1 disruption=0 braveness=1.00 chance=10.0 roll=10 result=declined") == 1,
		"br 1: p 10, roll 10 -> no offer, kept as r.co 0");
	local orb = TRF_Rd_Brave;
	TRF_Rd_Brave = nil;
	nkr.br = nil;
	tinsert(h.rq, 500);
	local b4 = TRF_HlBrave(nkr);
	TRF_Rd_Brave = orb;
	HOST_Check(abs(b4 - 0.6) < 0.001 and nkr.br == b4 and TRF_Rd_Brave(nkr) == b4, "braveness without trf_raid: 0.2 + 0.8 x 500/1000, kept as r.br for the raid");
	T_Jump("gredos");
	cur = TRF_CurIdx();
	-- Refusal at heat 3.
	TRF.std.heat = 3;
	local q = T_Spawn("B") or T_Spawn("A");
	nb = getn(h.boxes);
	V_Hail(q);
	HOST_Check(getn(h.boxes) == nb and T_Lines("nothing to say") == 1, "heat 3: hail refused with a line");
	TRF.std.heat = 0;
	-- meet 2 without trf_hail: the vanilla meeting box.
	local oh = TRF_OnHail;
	TRF_OnHail = nil;
	local w = T_Spawn("B") or T_Spawn("A");
	T_MoveTr(w, h.ms.pos.x + 40, 0, h.ms.pos.z);
	local m1 = h.meet;
	HOST_Fire("f_object_inside", "TRF_OnMeet("..w..",");
	TRF_OnHail = oh;
	HOST_Check(h.meet == m1 + 1, "meet 2 without trf_hail: vanilla _FTrader_Action");
	-- Trouble and boom: order and words (BFS depth 3 on the portal graph).
	for k, v in TRF.sys do if type(v) == "table" then v.dis = nil; end; end;
	local J = V_Jumps(cur);
	local by = {};
	for i, d in J do if i ~= cur and d >= 1 and d <= 4 then by[d] = by[d] or {}; tinsert(by[d], i); end; end;
	sort(by[1]); sort(by[2]); sort(by[3]);
	local nm = function(i) return TRF_UI_SysName(i); end;
	local y1, z1, x2, w3 = by[1][1], by[1][2], by[2][1], by[3][1];
	TRF_SetDis(w3, 7); TRF_SetDis(y1, 5); TRF_SetDis(x2, 5); TRF_SetDis(z1, 3);
	if by[4] then TRF_SetDis(by[4][1], 8); end;
	local tt = TRF_Trouble(cur);
	local pw, py, px = strfind(tt, nm(w3), 1, 1), strfind(tt, nm(y1), 1, 1), strfind(tt, nm(x2), 1, 1);
	HOST_Check(strsub(tt, 1, 16) == "Raids reported: " and pw and py and px and pw < py and py < px and not strfind(tt, nm(z1), 1, 1)
		and (not by[4] or not strfind(tt, nm(by[4][1]), 1, 1)), "trouble: dis desc, jumps asc, <= 3, depth 3: "..tt);
	for k, v in TRF.sys do if type(v) == "table" then v.dis = nil; end; end;
	local ts = {};
	for i, d in J do if i ~= cur and d >= 1 and d <= 3 and TRF_ProCap(i) == 9 then tinsert(ts, i); end; end;
	sort(ts, function(a, b) return %J[a] < %J[b] or (%J[a] == %J[b] and a < b); end);
	for k, v in TRF.sys do if type(v) == "table" then v.pro = nil; end; end;
	local bs = "";
	if getn(ts) >= 3 then
		TRF_SetPro(ts[1], 7); TRF_SetPro(ts[2], 9); TRF_SetPro(ts[3], 9); TRF_SetDis(ts[3], 3);
		local bt = TRF_Boom(cur);
		local p1, p2 = strfind(bt, nm(ts[1]).." (busy)", 1, 1), strfind(bt, nm(ts[2]).." (booming)", 1, 1);
		HOST_Check(strfind(bt, "Trade is good in: ", 1, 1) == 1 and p1 and p2 and p2 < p1 and not strfind(bt, nm(ts[3]), 1, 1),
			"boom: pro desc, dis < 3 only, words by pro: "..bt);
		TRF_SetDis(ts[3], 0);
	else
		HOST_Check(nil, "boom: three trade-station systems within 3 jumps");
	end;
	-- Headed rumour order: dis neighbour > shortage within 2 > pro neighbour > sweep > none.
	for k, v in TRF.sys do if type(v) == "table" then v.dis = nil; v.pro = nil; end; end;
	TRF.short = {};
	for s2 = 1, getn(TRF.rg) do TRF.rg[s2].sl = 0; end;
	V_ClearTr();
	local id = T_Spawn("B") or T_Spawn("A");
	local hd = TRF_Headed(id);
	HOST_Check(strfind(hd, "Lanes are quiet, captain.", 1, 1), "headed: nothing true -> rnone: "..hd);
	local kadi = TRF_RgOf(V_Idx("kadi"));
	local near = nil;
	for s2 = 1, TRF_RgMap().n do
		local hm = TRF_RgMap()[s2].home;
		if J[hm] and J[hm] <= 3 then near = s2; end;
	end;
	if near then
		TRF.rg[near].sl = TRF.clock.legs + 4;
		hd = TRF_Headed(id);
		HOST_Check(strfind(hd, "fleet gathering near", 1, 1), "headed: sweep scheduled near -> rsweep: "..hd);
	end;
	TRF_SetPro(y1, 7);
	hd = TRF_Headed(id);
	HOST_Check(strfind(hd, "Good trade in "..nm(y1), 1, 1), "headed: pro neighbour beats sweep: "..hd);
	TRF_ShortAdd(x2, 2, TRF.clock.legs + 6);
	hd = TRF_Headed(id);
	HOST_Check(strfind(hd, "pays well for", 1, 1), "headed: shortage within 2 jumps beats pro: "..hd);
	TRF_SetDis(z1, 4);
	hd = TRF_Headed(id);
	HOST_Check(strfind(hd, "Raids on the lane to "..nm(z1), 1, 1), "headed: dis >= 3 neighbour first: "..hd);
	V_HailDlg();
	V_HailQuiet();
	HOST_Check(h.box_nested == 0, "no ShowMsgBox inside a box callback (hail chain)");
	TRF_Hail_Dump();
end;

-- Close an open hail chain (Cancel through the boxes).
function V_HailEnd()
	for i = 1, 12 do
		if not TRF.live.hl then return; end;
		HOST_Press("cancel");
		T_Tick(1, 0.5);
	end;
end;

-- Remove the traders, spawn one 40 from the mothership; focus line (TRF_OnFocus), then the meeting (TRF_OnMeet).
-- scene 1: a TRF_UiState dialog flag is set after the spawn (a scene pauses spawning).
-- Returns id, screen lines added by the focus, then by the meeting.
function V_FocusMeet(scene)
	local h = HOST();
	V_ClearTr();
	T_Tick(8, 0.5);
	local id = T_Spawn("B") or T_Spawn("A");
	T_MoveTr(id, h.ms.pos.x + 40, h.ms.pos.y, h.ms.pos.z);
	if scene == 1 then TRF_UiState = HOST_UiState; h.ui = 4; end;
	local s0 = getn(h.screen);
	HOST_Fire("focus", "TRF_OnFocus("..id..",");
	local s1 = getn(h.screen);
	HOST_Fire("f_object_inside", "TRF_OnMeet("..id..",");
	return id, s1 - s0, getn(h.screen) - s1;
end;

-- Player-initiated contact under the quest chatter flag (cfg hail_quiet): __sys_SOS mutes the announce line
-- only (hail_quiet 0); a visible scene mutes the focus line and the meeting; hail_quiet 1 is the old rule.
function V_HailQuiet()
	local h = HOST();
	TRF.std.heat = 0;
	__sys_SOS = TRUE;
	local a, fa, ma = V_FocusMeet();
	local ra = TRF.live.tr[a];
	HOST_Check(fa == 1 and ra.met and V_Logs("module=ui event=focus trader_id="..a.." via=focus result=shown") == 1, "__sys_SOS, hail_quiet 0: focus line shown");
	HOST_Check(ma == 0 and type(ra.ha) == "number" and V_Logs("module=ui event=meet trader_id="..a.." hail_armed=true result=line_muted reason=quiet") == 1
		and V_Logs("module=ui event=say result=skipped reason=quiet message=\"FTU") >= 1, "__sys_SOS, hail_quiet 0: announce line muted, hail armed");
	local nb = getn(h.boxes);
	HOST_Fire("focus", "TRF_OnHail("..a..",");
	HOST_Check(getn(h.boxes) == nb + 1 and type(TRF.live.hl) == "table" and TRF.live.hl.id == a, "__sys_SOS, hail_quiet 0: hail box opens");
	V_HailEnd();
	HOST_Check(TRF_HlSay("host hail answer", a, nil, 1) == 1 and not TRF_HlSay("host plain line", a), "__sys_SOS: hail answer shown, plain line muted");
	-- hail_quiet 1: the old rule, everything muted by __sys_SOS.
	h.cfg.hail_quiet = 1;
	local b, fb, mb = V_FocusMeet();
	HOST_Check(fb == 0 and mb == 0 and TRF.live.tr[b].ha == nil and V_Logs("module=ui event=focus trader_id="..b.." result=skipped reason=quiet") == 1
		and V_Logs("module=ui event=meet trader_id="..b.." result=skipped reason=quiet") == 1, "__sys_SOS, hail_quiet 1: focus and meeting skipped (quiet)");
	local ok, why = TRF_HailOpen(b, "focus");
	HOST_Check(ok == nil and why == "quiet", "__sys_SOS, hail_quiet 1: hail skipped (quiet) "..tostring(why));
	h.cfg.hail_quiet = nil;
	__sys_SOS = FALSE;
	-- A visible scene (TRF_UiState dialog flag): focus and meeting skipped (quiet); the hail box closed (the
	-- pause level reads first: flag).
	local us = TRF_UiState;
	local c, fc, mc = V_FocusMeet(1);
	HOST_Check(fc == 0 and mc == 0 and TRF.live.tr[c].ha == nil and V_Logs("module=ui event=focus trader_id="..c.." result=skipped reason=quiet") == 1
		and V_Logs("module=ui event=meet trader_id="..c.." result=skipped reason=quiet") == 1, "scene, hail_quiet 0: focus and meeting skipped (quiet)");
	ok, why = TRF_HailOpen(c, "focus");
	HOST_Check(ok == nil and why == "flag", "scene: hail skipped ("..tostring(why)..")");
	TRF_UiState = us; h.ui = nil;
	-- No flag: the announce line is shown again.
	local d, fd, md = V_FocusMeet();
	HOST_Check(fd == 1 and md == 1 and type(TRF.live.tr[d].ha) == "number" and V_Logs("module=ui event=meet trader_id="..d.." hail_armed=true result=line_muted") == 0, "no flag: focus and announce lines");
	-- Default hail_start (2): the box opens at the meeting, also under __sys_SOS with the line muted; no box
	-- while a modal window is up (TRF_UiState 2); the later modal-free meeting of another trader opens one.
	h.cfg.hail_start = nil;
	__sys_SOS = TRUE;
	local nb2 = getn(h.boxes);
	local e, fe, me = V_FocusMeet();
	HOST_Check(me == 0 and getn(h.boxes) == nb2 + 1 and type(TRF.live.hl) == "table" and TRF.live.hl.id == e
		and V_Logs("module=ui event=meet trader_id="..e.." hail_armed=true result=line_muted reason=quiet") == 1
		and V_Logs("module=hail event=hail trader_id="..e.." via=meet answer_count=") == 1,
		"default hail_start, __sys_SOS: box opens at the meeting via=meet, line muted");
	V_HailEnd();
	__sys_SOS = FALSE;
	local nb3 = getn(h.boxes);
	local f2 = V_FocusMeet(1);
	h.ui = 2;
	HOST_Fire("f_object_inside", "TRF_OnMeet("..f2..",");
	HOST_Check(getn(h.boxes) == nb3 and TRF.live.hl == nil and TRF.live.tr[f2].ha == nil, "default hail_start, modal window up: no box");
	TRF_UiState = us; h.ui = nil;
end;

-- A fresh trader 40 from the mothership (other traders removed); id and record.
function V_DlgTrader()
	local h = HOST();
	V_ClearTr();
	T_Tick(2, 0.5);
	local id = T_Spawn("B") or T_Spawn("A");
	T_MoveTr(id, h.ms.pos.x + 40, h.ms.pos.y, h.ms.pos.z);
	TRF.live.tr[id].co = 1;
	return id, TRF.live.tr[id];
end;

-- Expected visible answers of the open chain: a_<key> in TRF_Hail.xml order, provider items in p slots.
function V_DlgWant(o)
	local on, np, fx = {close=1}, 0, TRF_HlDlgFixed();
	for i = 1, getn(o) do
		if fx[o[i]] then on[o[i]] = 1; else np = np + 1; on["p"..np] = 1; end;
	end;
	local ks, s = TRF_HlDlgKeys(), "";
	for i = 1, getn(ks) do if on[ks[i]] then s = s..(s ~= "" and " " or "").."a_"..ks[i]; end; end;
	return s;
end;

-- Hail menu as the trade dialog TRF_Hail (tune hail_box 2, cfg hail_xml 1; mod-research/hail-dialog.md stage A).
function V_HailDlg()
	local h = HOST();
	local us, f3, dco = TRF_UiState, __sys_FTrader_3, TRF_Dc_HailOpts;
	TRF.std.heat = 0;
	h.cfg.tune = {hail_box=2};
	h.cfg.hail_xml = 1;
	TRF_UiState = HOST_UiState; h.ui = 0;
	__sys_FTrader_3 = 0;
	local cur = TRF_CurIdx();
	TRF_SetDis(cur, 2);
	-- Five options (trade, head, escort, trouble, boom): one dialog, no box, the valid answers and the tokens.
	local a, ra = V_DlgTrader();
	local nb, nd = getn(h.boxes), getn(h.tdlgs);
	local res = TRF_HailOpen(a, "focus");
	local hl = TRF.live.hl;
	local td = h.tdlgs[nd + 1] or {};
	HOST_Check(res == "menu" and type(hl) == "table" and hl.w == "dlg" and getn(hl.o) == 5 and getn(h.boxes) == nb
		and getn(h.tdlgs) == nd + 1 and td.d == "TRF_Hail" and td.init == "TRF_HlDlgInit" and h.dlg and h.dlg.open,
		"hail_box 2: StartTradeDialog(TRF_Hail, TRF_HlDlgInit), no box ("..TRF_Dump(hl and hl.o)..")");
	local want = V_DlgWant(hl.o);
	HOST_Check(want == "a_trade a_head a_esc a_trouble a_boom a_close" and HOST_DlgVis() == want,
		"dialog shows the 5 options and close: "..HOST_DlgVis());
	HOST_Check(HOST_DlgText() == "FTU "..TRF_HlName(ra)..": What do you need, Wolves?" and not strfind(HOST_DlgText(), "#", 1, 1),
		"dialog text with #who# and #head#: "..tostring(HOST_DlgText()));
	HOST_Check(V_Logs("module=hail event=hail trader_id="..a.." via=focus answer_count=5 hail_count=1 dialog=true") == 1 and h.ui == 4, "log menu n=5 dlg=1; UI dialog flag while open");
	-- Pick trade: routed as the box OK (due call, TRF_HailDo), the trader shop opens; nothing inside the callback.
	local name = TRF_ShopName(TRF_ShopSlot(ra));
	local ndl = getn(h.dlgs);
	HOST_DlgPick("a_trade");
	HOST_Check(getn(h.dlgs) == ndl and getn(h.boxes) == nb and V_Logs("event=dialog_pick trader_id="..a.." key=trade") == 1, "pick trade: recorded, nothing opened in the callback");
	T_Tick(1, 0.5);
	HOST_Check(getn(h.dlgs) == ndl + 1 and h.dlgs[getn(h.dlgs)] == name and ra.trd == 1 and TRF.live.hl == nil
		and V_Logs("event=option trader_id="..a.." key=trade") == 1 and V_Logs("event=close trader_id="..a.." reason=trade") == 1,
		"pick trade: TradeStationDlg("..name..") as the box path, chain closed");
	T_Tick(3, 0.5);
	HOST_Check(V_Logs("event=close trader_id="..a.." reason=\"dialog closed\"") == 0, "dialog check after a pick: no second close");
	-- A provider item in slot p1 (label token) and close: the chain closes, the trader stays hailable.
	TRF_Dc_HailOpts = function(id) return {{k="xtest", t="Test label", s="Test answer"}}; end;
	local b, rb = V_DlgTrader();
	TRF_HailOpen(b, "focus");
	hl = TRF.live.hl;
	HOST_Check(type(hl) == "table" and hl.w == "dlg" and HOST_DlgVis() == V_DlgWant(hl.o) and strfind(HOST_DlgVis(), "a_p1", 1, 1)
		and not strfind(HOST_DlgVis(), "a_p2", 1, 1) and HOST_DlgText("a_p1") == "- Test label" and h.dlg.rv.p2 == "",
		"provider item in slot p1: "..HOST_DlgVis().." / "..tostring(HOST_DlgText("a_p1")));
	HOST_DlgPick("a_p1");
	T_Tick(1, 0.5);
	-- Stage B (design/hail-spec.md 2): the answer is a page of TRF_HailPg with Back and Close, no box.
	HOST_Check(getn(h.boxes) == nb and h.dlg and h.dlg.open and h.dlg.name == "TRF_HailPg" and TRF.live.hl.w == "dlg"
		and HOST_DlgText() == "FTU "..TRF_HlName(rb)..": Test answer" and HOST_DlgVis() == "a_back a_close",
		"pick p1: the item's answer as a page with Back and Close after the due call: "..tostring(HOST_DlgText()).." / "..HOST_DlgVis());
	HOST_DlgPick("a_close");
	HOST_Check(TRF.live.hl == nil, "page Close closes the chain");
	TRF_Dc_HailOpts = dco;
	local c, rc = V_DlgTrader();
	TRF_HailOpen(c, "focus");
	HOST_DlgPick("a_close");
	HOST_Check(TRF.live.hl == nil and V_Logs("event=close trader_id="..c.." reason=close") == 1 and type(rc.ha) == "number" and rc.ha > TRF_HlGt(),
		"pick close: chain closed, hail re-armed");
	-- Stale picks: after the chain is gone, and from a chain of another gen.
	nd = getn(h.dlgs);
	TRF_HlDlgA_trade();
	HOST_Check(V_Logs("event=dialog_pick trader_id=nil key=trade result=ignored reason=stale") == 1 and getn(h.dlgs) == nd, "pick without a chain: ignored");
	local e, re = V_DlgTrader();
	TRF_HailOpen(e, "focus");
	TRF.gen = TRF.gen + 1;
	HOST_DlgPick("a_trade");
	TRF.gen = TRF.gen - 1;
	T_Tick(1, 0.5);
	HOST_Check(V_Logs("event=dialog_pick trader_id="..e.." key=trade result=ignored reason=stale") == 1 and TRF.live.hl == nil and getn(h.dlgs) == nd and re.trd == nil,
		"pick after a gen change: ignored, no shop");
	-- Esc (dialog closed without an answer): the due check closes the chain.
	local g = V_DlgTrader();
	TRF_HailOpen(g, "focus");
	HOST_DlgEsc();
	T_Tick(3, 0.5);
	HOST_Check(TRF.live.hl == nil and V_Logs("event=close trader_id="..g.." reason=\"dialog closed\"") == 1, "Esc: chain closed by TRF_HlDlgCheck");
	-- Fallbacks to the box chain: hail_xml 0, StartTradeDialog missing, UI not idle.
	local fb = {{"xml", function() HOST().cfg.hail_xml = 0; end, function() HOST().cfg.hail_xml = 1; end},
		{"native", function() V_StartTD = StartTradeDialog; StartTradeDialog = nil; end, function() StartTradeDialog = V_StartTD; end},
		{"ui=-1", function() HOST().ui = -1; end, function() HOST().ui = 0; end}};
	for i = 1, getn(fb) do
		local x = V_DlgTrader();
		nb, nd = getn(h.boxes), getn(h.tdlgs);
		fb[i][2]();
		TRF_HailOpen(x, "focus");
		fb[i][3]();
		HOST_Check(getn(h.tdlgs) == nd and getn(h.boxes) == nb + 1 and strfind(HOST_Box().text, ": Trade?", 1, 1) and TRF.live.hl.w == "menu"
			and V_Logs("event=dialog_fallback reason="..TRF_KvV(fb[i][1])) == 1
			and V_Logs("event=hail trader_id="..x.." via=focus answer_count=5 hail_count=1 dialog=false") == 1
			and V_Logs("event=hail trader_id="..x.." via=focus answer_count=5 hail_count=1 dialog=true") == 0, "fallback ("..fb[i][1].."): box chain");
		V_HailEnd();
	end;
	-- Refusal at heat 3 with demand cargo: the dialog with demand and close only.
	h.cfg.demand = 1;
	TRF.std.heat = 3;
	local q, rq = V_DlgTrader();
	nb = getn(h.boxes);
	h.cfg.log = 2;
	res = TRF_HailOpen(q, "focus");
	h.cfg.log = 1;
	HOST_Check(V_Logs("module=hail event=dialog_answers trader_id="..q.." answers=demand,close ") == 1, "log 2: the answer visibility list");
	HOST_Check(res == "refuse" and type(TRF.live.hl) == "table" and TRF.live.hl.w == "dlg" and getn(h.boxes) == nb
		and HOST_DlgVis() == "a_demand a_close" and V_Logs("event=hail trader_id="..q.." heat=3 demand_via=dialog result=refused") == 1
		and HOST_DlgText() == "FTU "..TRF_HlName(rq)..": We have nothing to say to the Wolves. Keep your distance.",
		"refusal at heat 3: dialog with demand and close only: "..HOST_DlgVis());
	HOST_DlgPick("a_close");
	HOST_Check(TRF.live.hl == nil, "refusal dialog: close");
	TRF.std.heat = 0;
	h.cfg.demand = nil; h.cfg.hail_xml = nil; h.cfg.tune = nil;
	TRF_UiState = us; h.ui = nil;
	__sys_FTrader_3 = f3;
	TRF_SetDis(cur, 0);
	V_ClearTr();
end;

-- l: dock wrappers (spec 6.4, 7.2) -------------------------------------------------------------------

-- Patrol docking as DockStation.script runs it: the request box, OK -> __PatrolStationDock_Ok.
function V_PatrolDock()
	__PSDock_Action("");
	HOST_Press("ok");
end;

-- Trade docking: the request box, OK -> __TradeStationDock_Ok.
function V_TradeDock()
	__TradeStation_Action("");
	HOST_Press("ok");
end;

function V_Writes(shop)
	local o = {};
	local q = HOST().mwrites;
	for i = 1, getn(q) do if q[i].shop == shop then tinsert(o, q[i]); end; end;
	return o;
end;

function T_V02_L()
	local h = HOST();
	h.labels.CurrentQuest = "5_1"; h.st_label = "TRADE STATION";
	V_Begin("gredos", {seed=0, staged=0, raids=0, queue=0, parked=0});
	local cur = TRF_CurIdx();
	HOST_Check(TRF_HailIsMine(__PatrolStationDock_Ok) and not TRF_HailIsMine(TRF_orig_PatrolOk) and TRF_ShopIsMine(__TradeStationDock_Ok)
		and not TRF_ShopIsMine(TRF_orig_TradeOk), "both dock functions wrapped over the vanilla originals");
	HOST_Check(TRF_InstallBoard() == 0 and TRF_InstallTradeDock() == 0, "second install in the same MapInitialization: no double wrap");
	-- Board (S19 answers as dock lines, trf_plumb kind patrol, design/wb-plumbing-spec.md 4): the report and boom
	-- lines, then the original exactly once; no box without a board offer.
	TRF_SetDis(V_Idx("aurora"), 5);
	local p0, b0, s0 = h.patrol_ok, getn(h.boxes), getn(h.screen);
	V_PatrolDock();
	local rl = nil;
	for i = s0 + 1, getn(h.screen) do if strfind(h.screen[i].t, "Raids reported", 1, 1) then rl = 1; end; end;
	HOST_Check(getn(h.boxes) == b0 + 1 and rl and getn(h.screen) >= s0 + 2 and h.patrol_ok == p0 + 1 and getn(h.pdlgs) == 1,
		"board: report and boom lines, then the patrol dialog once (no box)");
	-- Same text again: one line, then the original.
	s0 = getn(h.screen);
	V_PatrolDock();
	HOST_Check(getn(h.boxes) == b0 + 2 and h.patrol_ok == p0 + 2 and getn(h.screen) == s0 + 1, "same report: screen line, then the original");
	-- New text: the full report again, the original exactly once.
	TRF_SetDis(V_Idx("argon"), 4);
	s0 = getn(h.screen);
	V_PatrolDock();
	HOST_Check(h.patrol_ok == p0 + 3 and getn(h.screen) >= s0 + 2, "new report: lines, then the original once");
	-- Flags: the original only.
	__sys_SOS = TRUE;
	b0, s0 = getn(h.boxes), getn(h.screen);
	V_PatrolDock();
	__sys_SOS = FALSE;
	HOST_Check(getn(h.boxes) == b0 + 1 and getn(h.screen) == s0 and h.patrol_ok == p0 + 4, "flag set: original only");
	-- Quest system during a mission: line, then the original (no extra box).
	V_QuestOn();
	TRF_SetDis(V_Idx("aurora"), 0);
	b0, s0 = getn(h.boxes), getn(h.screen);
	V_PatrolDock();
	V_QuestOff();
	HOST_Check(getn(h.boxes) == b0 + 1 and getn(h.screen) == s0 + 1 and h.patrol_ok == p0 + 5, "mission in a quest system: line then the original");
	-- Trade dock: shortage class 2 here -> buy x 1.5 for class-2 items, recorded in TRF.shops.
	TRF_ShortAdd(cur, 2, TRF.clock.legs + 6);
	h.mwrites = {};
	local t0 = h.trade_ok;
	V_TradeDock();
	local w = V_Writes("gredos");
	local s0b, b0b = TRF_DefCoefOf("gredos", 2);
	local okw = getn(w) >= 1;
	for i = 1, getn(w) do if abs(w[i].b - b0b * 1.5) > 1e-9 or w[i].n ~= 0 then okw = nil; end; end;
	HOST_Check(okw and getn(TRF.shops) == 1 and TRF.shops[1].sh == "gredos" and TRF.shops[1].c == 2 and h.trade_ok == t0 + 1 and h.dlgs[getn(h.dlgs)] == "gredos",
		"trade dock: buy x 1.5 on class 2 ("..getn(w).." items), recorded, original once");
	-- Expiry: restore and removal.
	TRF_AddLeg("test"); TRF_AddLeg("test"); TRF_AddLeg("test"); TRF_AddLeg("test"); TRF_AddLeg("test"); TRF_AddLeg("test");
	HOST_Check(getn(TRF_ShortOf(cur)) == 0, "shortage expired after 6 legs");
	h.mwrites = {};
	V_TradeDock();
	w = V_Writes("gredos");
	okw = getn(w) >= 1;
	for i = 1, getn(w) do if w[i].b ~= b0b or w[i].s ~= s0b then okw = nil; end; end;
	HOST_Check(okw and getn(TRF.shops) == 0, "expired: vanilla coefficients written back ("..s0b.."/"..b0b.."), entry removed");
	-- A Rare-list station restores its own 1.6 / 0.4 (NORMAL).
	T_Jump("tarrot");
	local ti = TRF_CurIdx();
	TRF_ShortAdd(ti, 3, TRF.clock.legs + 6);
	V_TradeDock();
	TRF_ShortClear(ti, nil);
	h.mwrites = {};
	V_TradeDock();
	w = V_Writes("tarrot");
	HOST_Check(getn(w) >= 1 and w[1].s == 1.6 and w[1].b == 0.4 and getn(TRF.shops) == 0, "tarrot (Rare list) restores 1.6 / 0.4");
	-- Vanilla-mode system: no apply; restore still runs.
	T_Jump("elio");
	local ei = TRF_CurIdx();
	V_QuestOn();
	TRF.shops = {{s=ei, sh="elio", c=1}};
	TRF_ShortAdd(ei, 4, TRF.clock.legs + 6);
	h.mwrites = {};
	V_TradeDock();
	w = V_Writes("elio");
	local m, why = TRF_SysMode();
	local es, eb = TRF_DefCoefOf("elio", 2);
	HOST_Check(m == "vanilla" and getn(TRF.shops) == 0 and getn(w) >= 1 and w[1].b == eb and w[1].s == es, "vanilla-mode system (deny list, mission): restore runs, nothing applied");
	V_QuestOff();
	-- enabled 2: state, safety, shop and base (v1 10.3) only; every changed station restored at the next trade dock.
	T_Jump("gredos");
	TRF_ShortAdd(cur, 1, TRF.clock.legs + 6);
	V_TradeDock();
	HOST_Check(getn(TRF.shops) == 1, "applied before enabled 2");
	h.cfg.enabled = 2;
	h.logs = {};
	T_Jump("aurora");
	T_Jump("gredos");
	h.mwrites = {};
	V_TradeDock();
	HOST_Check(V_Logs(" module_count=4 ") == 2 and getn(TRF.shops) == 0 and V_Logs("event=restore pending_count=0 result=done") >= 1 and getn(V_Writes("gredos")) >= 1,
		"enabled 2: 4 modules loaded, restored although the shortage is active, 'restore done'");
	h.cfg.enabled = nil;
	T_Jump("aurora");
	HOST_Check(TRF_ShopIsMine(__TradeStationDock_Ok) and TRF_HailIsMine(__PatrolStationDock_Ok), "next MapInitialization: re-wrapped once");
	t0 = h.trade_ok;
	V_TradeDock();
	HOST_Check(h.trade_ok == t0 + 1, "trade dock after re-install: original exactly once");
end;

-- m: trader shop and news (spec 7.1, 8.2) ---------------------------------------------------------

function T_V02_M()
	local h = HOST();
	h.labels.CurrentQuest = "5_1"; h.st_label = "TRADE STATION";
	V_Begin("gredos", {seed=0, staged=0, raids=0, queue=0, parked=0});
	local cur = TRF_CurIdx();
	TRF_SetDis(cur, 0);
	local a = T_Spawn("C");
	local r = TRF.live.tr[a];
	local name = TRF_ShopName(TRF_ShopSlot(r));
	-- The destination's shortage class gets buy x 1.2.
	local dest = TRF_ShopDest(r);
	local sc = nil;
	if dest then sc = 1; if TRF_ShopItemCls(r.hold[1].i) == 1 then sc = 2; end; TRF_ShortAdd(dest, sc, TRF.clock.legs + 6); end;
	h.mwrites = {};
	V_Hail(a);
	HOST_Check(V_HailTo("trade"), "hail: Trade option");
	V_Ok();
	HOST_Check(name == "trf_shop_"..r.k and h.dlgs[getn(h.dlgs)] == name and h.shops_made[name] == 1 and TRF.tsh[r.k] == 2 and h.trflag == TRUE,
		"Trade: CreateShop("..name..") of the trader's slot once, dialog on it");
	local mk = h.markets[name];
	local tot = {};
	for i = 1, getn(r.hold) do tot[r.hold[i].i] = (tot[r.hold[i].i] or 0) + r.hold[i].n; end;
	local okh = 1;
	for it, n in tot do if not mk.goods[it] or mk.goods[it].n ~= n then okh = nil; end; end;
	HOST_Check(okh, "shop holds the hold-mirror totals "..TRF_Dump(tot));
	local s, b = TRF_ShopCoefOf(2, TRF.std.help, TRF_Pro(cur));
	local eq, okc = 0, 1;
	for it, g in mk.goods do
		if g.n == 2 and not tot[it] then eq = eq + 1; if g.s ~= s or g.b ~= b then okc = nil; end; end;
	end;
	HOST_Check(eq >= 3 and eq <= 6 and okc, "3-6 equipment items at the NORMAL coefficients "..s.."/"..b.." ("..eq..")");
	if sc then
		local okb = 0;
		for it, g in mk.goods do
			if TRF_ShopItemCls(it) == sc and abs(g.b - b * 1.2) < 1e-9 then okb = okb + 1; end;
		end;
		HOST_Check(okb >= 1, "short class at the destination: buy x 1.2 ("..okb.." items)");
	end;
	HOST_Check(TRF_ShopOpen(a) == nil, "once per trader");
	-- A second live trader has another slot and its own shop.
	local b2 = T_Spawn("C");
	local k2 = TRF.live.tr[b2].k;
	TRF_ShopOpen(b2);
	local n2 = TRF_ShopName(k2);
	HOST_Check(k2 ~= r.k and h.shops_made[n2] == 1 and h.dlgs[getn(h.dlgs)] == n2 and h.markets[n2] ~= mk, "second live trader: own shop "..n2);
	-- Player sales to a's shop, then a new trader in a's slot: known items wiped, an unknown item stays.
	local ka = r.k;
	mk.goods["Cargo_01"] = {n=40, s=1, b=1};
	mk.goods["Trf_NotListed"] = {n=3, s=1, b=1};
	local eqa = {};
	for it, g in mk.goods do if g.n == 2 and not tot[it] then eqa[it] = 1; end; end;
	TRF_Remove(a, "test");
	local c2 = nil;
	for t = 1, 8 do
		local x = T_Spawn("C");
		if x and TRF.live.tr[x].k == ka then c2 = x; break; end;
		if x then TRF_Remove(x, "test"); end;
	end;
	h.cfg.log = 2;
	h.logs = {};
	TRF_ShopOpen(c2);
	h.cfg.log = nil;
	local rc = TRF.live.tr[c2 or 0] or {};
	local totc = {};
	for i = 1, getn(rc.hold or {}) do totc[rc.hold[i].i] = (totc[rc.hold[i].i] or 0) + rc.hold[i].n; end;
	local okw = c2 and h.shops_made[name] == 1 and h.dlgs[getn(h.dlgs)] == name;
	if okw and (mk.goods["Cargo_01"].n ~= (totc["Cargo_01"] or 0)) then okw = nil; end;
	-- design/strength-spec.md 5.1: the trader roll draws in another order, so the next trader can stock one of a's
	-- equipment items itself; its own equipment (the shop items line) is not a leftover.
	local eqc = {};
	for i = 1, getn(h.logs) do
		local x, y, q = strfind(h.logs[i], "module=shop event=items .* equip=([%w_,]*)");
		local p = 1;
		while q do
			local a, b, w = strfind(q, "([%w_]+)", p);
			if not a then break; end;
			eqc[w] = 1;
			p = b + 1;
		end;
	end;
	for it, v in eqa do
		if okw and not totc[it] and not eqc[it] and mk.goods[it].n > 1 then okw = nil; end;
	end;
	HOST_Check(okw and mk.goods["Trf_NotListed"].n == 3, "same slot, next trader: shop reused, previous stock and sales of listed items wiped, unlisted item kept");
	HOST_Check(V_Logs("module=shop event=items trader_id="..tostring(c2).." shop="..name.." hold=") == 1, "log 2: item names of the fill logged");
	-- Saved tsh: class-shop entries (tsh[cls] = 1, saves before 2026-10-22) are dropped by the repair.
	TRF.tsh = {[1]=1, [3]=2, [6]=1, [7]=2};
	TRF_TshFix();
	HOST_Check(TRF.tsh[1] == nil and TRF.tsh[3] == 2 and TRF.tsh[6] == nil and TRF.tsh[7] == nil, "tsh repair: only slot entries 1..5 = 2 stay");
	TRF.tsh[ka] = 2; TRF.tsh[k2] = 2;
	TRF_Remove(b2, "test");
	if c2 then TRF_Remove(c2, "test"); end;
	-- Coefficients: difficulty, help >= 5, pro >= 6, sell >= buy + 0.2.
	local s1, b1 = TRF_ShopCoefOf(1, 0, 0);
	local s5, b5 = TRF_ShopCoefOf(2, 5, 6);
	local s9, b9 = TRF_ShopCoefOf(1, 5, 6);
	HOST_Check(s1 == 1.2 and b1 == 0.8 and abs(s5 - 1.1) < 1e-9 and abs(b5 - 0.7) < 1e-9 and abs(s9 - (b9 + 0.2)) < 1e-9, "coefficients: EASY 1.2/0.8, help+pro 1.1/0.7, sell floor buy+0.2");
	h.cfg.shop_mode = 0;
	local c = T_Spawn("C");
	local f0 = h.ftrader;
	TRF_ShopOpen(c);
	HOST_Check(h.ftrader == f0 + 1, "shop_mode 0: vanilla On_FTrader_Start");
	h.cfg.shop_mode = nil;
	-- News: thresholds, one post per topic, bulletin once (mode 1).
	TRF.news = {};
	TRF_AddHeat(5, "test");
	HOST_Check(TRF.news.heat and TRF.news.heat.v == "5" and TRF.news.heat.n == 1, "heat 5: news heat/5");
	TRF_AddHeat(2, "test");
	HOST_Check(TRF.news.heat.v == "7" and V_N(TRF.news) == 1, "heat 7: replaces the heat post");
	local s2 = getn(h.screen);
	HOST_Check(TRF_NewsShow() == 1 and h.screen[s2 + 1].t == "FTU bulletin: FTU blacklists the Wolves" and TRF.news.heat.n == 0, "bulletin shown once");
	HOST_Check(TRF_NewsShow() == nil, "nothing unseen: no second bulletin");
	TRF.std.heat = 0;
	TRF_NewsCheck("heat");
	HOST_Check(TRF.news.heat == nil, "heat 0: heat post removed");
	TRF_AddHelp(5, "test");
	HOST_Check(TRF.news.help and TRF.news.help.v == "5", "help 5: news help/5");
	local slot = TRF_RgOf(cur);
	TRF_SetDis(cur, 5);
	TRF_NewsCheck("lane", slot);
	HOST_Check(TRF.newsx[slot].lane.v == "raid", "region system at dis 5: lane/raid");
	TRF_SetDis(cur, 0);
	for k, v in TRF.sys do if type(v) == "table" and TRF_RgOf(k) == slot then v.dis = nil; end; end;
	TRF_NewsCheck("lane", slot);
	HOST_Check(TRF.newsx[slot].lane.v == "quiet", "all below 3 after raid: lane/quiet");
	-- Bulletin 12 s after entry.
	T_Jump("aurora");
	TRF.news = {help={v="15", n=1, l=TRF.clock.legs}};
	s2 = getn(h.screen);
	T_Tick(26, 0.5);
	HOST_Check(T_Lines("^FTU bulletin: FTU names the Wolves friends of the union$") == 1 and TRF.news.help.n == 0, "bulletin 12 s after entry");
	-- news_mode 2: RemovePost then AddPost.
	h.cfg.news_mode = 2;
	h.posts = {};
	TRF_NewsPost("heat", "5");
	TRF_NewsPost("heat", "7");
	HOST_Check(getn(h.posts) == 3 and h.posts[1] == "+trf_heat_5" and h.posts[2] == "-trf_heat_5" and h.posts[3] == "+trf_heat_7", "news_mode 2: AddPost, RemovePost + AddPost "..TRF_Dump(h.posts));
	TRF_NewsPost("sweep", "win", 3);
	HOST_Check(h.posts[4] == "+trf_r3_sweep_win", "news_mode 2: regional record name");
	h.cfg.news_mode = 0;
	HOST_Check(TRF_NewsPost("heat", "5") == nil, "news_mode 0: nothing posted");
	h.cfg.news_mode = nil;
end;

-- n: save size, bounds and lint (spec 3.2, 3.4) ---------------------------------------------------------

-- Non-function TRF_ globals and leftover build globals.
-- Mod data globals other than TRF and the handle globals of open records and parked entries (T_HandleOk).
function V_DataGlobals()
	local s = "";
	for k, v in globals() do
		local ok = type(k) == "string" and T_HandleOk(k);
		if type(k) == "string" and not ok and k ~= "TRF" and strsub(k, 1, 4) == "TRF_" and type(v) ~= "function" then s = s.." "..k; end;
		if type(k) == "string" and not ok and (strfind(k, "^TRF_GRaid_") or strfind(k, "^flight_trf_") or strfind(k, "^ship_trf_") or strfind(k, "^pilot_trf_")) then
			s = s.." "..k;
		end;
	end;
	return s;
end;

function T_V02_N()
	local h = HOST();
	h.labels.CurrentQuest = "5_1"; h.st_label = "TRADE STATION";
	V_Begin("gredos", {seed=0, staged=0, queue=0, big=0});
	-- 200 legs of the regional cycle.
	h.logs = nil;
	for i = 1, 200 do TRF_AddLeg("test"); end;
	h.logs = {};
	local cur = TRF_CurIdx();
	-- Worst case of spec 3.4: dis and pro in every system, 8 shortages, 8 restore entries, every news topic.
	for i = 1, getn(TRF_Map().sys) do TRF_SetDis(i, 1 + mod(i, 8)); if TRF_ProCap(i) > 0 then TRF_SetPro(i, TRF_ProCap(i)); end; end;
	TRF_SetDis(cur, 0);
	TRF_SetPro(cur, 9);
	TRF.short = {};
	for i = 1, 9 do TRF_ShortAdd(i * 3, 1 + mod(i, 6), TRF.clock.legs + 6); end;
	TRF.shops = {};
	for i = 1, 8 do tinsert(TRF.shops, {s=i * 3, sh=TRF_SysName(i * 3), c=1 + mod(i, 6)}); end;
	TRF.std.help = 15; TRF.std.heat = 2;
	TRF_NewsPost("heat", "5"); TRF_NewsPost("help", "15"); TRF_NewsPost("short", "on");
	for sl = 1, TRF_RgMap().n do
		foreachi({"lane", "trade", "pir", "sweep"}, function(i, t) TRF_NewsPost(t, "raid", %sl); end);
	end;
	for k = 1, 5 do TRF.tsh[k] = 2; end;
	-- 12 traders removed (8 gone records stay), then live traders up to the caps (band 2), records of 8.
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
	HOST_Check(getn(ids) >= 3, "traders up to the caps ("..getn(ids)..")");
	local one = ids[1];
	for k = 1, getn(ids) do
		local r = TRF.live.tr[ids[k]];
		r.fs = {1, 2, 3, 4, 5}; r.ha = 99999; r.hn = 1; r.hlt = 10; r.trd = 1; r.hd = 1; r.tu = 1; r.bm = 1;
	end;
	local n = 0;
	local nlive = function()
		local c = 0;
		for id, r in TRF.live.tr do if r.st ~= "gone" then c = c + 1; end; end;
		return c;
	end;
	while nlive() < 8 do
		n = n + 1;
		local c = {};
		for k, v in TRF.live.tr[one] do c[k] = v; end;
		c.id = 9000 + n;
		TRF.live.tr[c.id] = c;
	end;
	local gone, bad = 0, "";
	for id, r in TRF.live.tr do
		if r.st == "gone" then
			gone = gone + 1;
			for k, v in r do if k ~= "id" and k ~= "nm" and k ~= "cls" and k ~= "st" and k ~= "why" and k ~= "gg" then bad = bad.." "..id.."."..k; end; end;
		end;
	end;
	HOST_Check(gone == 8 and bad == "", "8 gone records kept, each with only id, nm, cls, st, why, gg"..bad);
	-- Raid records: many raids, at most 6 kept (open ones first).
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
	HOST_Check(V_N(TRF.live.rd) <= 6, "at most 6 raid records ("..V_N(TRF.live.rd)..")");
	-- due: 32 accepted, the 33rd refused.
	local ok = 1;
	TRF_H().due = {};
	for i = 1, 32 do if not TRF_Due(500 + i, "TRF_HostNoop", i, "x") then ok = nil; end; end;
	HOST_Check(ok and TRF_Due(1, "TRF_HostNoop") == nil and getn(TRF_H().due) == 32 and TRF.live.due == nil, "TRF_Due: 32 entries in H (not saved), the 33rd refused");
	for i = 1, 140 do TRF_Stat("k"..i); end;
	HOST_Check(V_N(TRF.live.stat) <= 97 and TRF.live.stat.other ~= nil, "stat: keys beyond 96 counted in 'other' ("..V_N(TRF.live.stat)..")");
	TRF.live.hl = {id=one, g=TRF.gen, o={"trade", "head", "news", "esc", "trouble", "boom"}, k=3, t=10, w="menu"};
	TRF.live.ct = {id=one, n=30000, t=10};
	TRF.live.board = TRF_Trouble(cur)..TRF_UI_Br()..TRF_Boom(cur);
	-- Serialised size with the save grammar (the global key "TRF" included).
	local size = 8 + 3 + HOST_SaveSize(TRF);
	local parts, pl = "", {"sys", "rg", "clan", "short", "shops", "news", "newsx", "live"};
	for i = 1, getn(pl) do parts = parts.." "..pl[i].."="..HOST_SaveSize(TRF[pl[i]]); end;
	print("HOST info TRF save size "..size.." bytes:"..parts.." live.tr="..HOST_SaveSize(TRF.live.tr).." H.due (not saved)="..HOST_SaveSize(TRF_H().due)
		.." live.stat="..HOST_SaveSize(TRF.live.stat).." live.rd="..HOST_SaveSize(TRF.live.rd));
	HOST_Check(size <= 100000, "full-state TRF after 200 legs: "..size.." bytes <= 100000 (v1-spec 3.4)");
	HOST_Check(HOST_Reserved(TRF, "TRF") == "", "no reserved key anywhere in TRF");
	-- Load: only functions and TRF are globals of the mod; no handle globals left.
	T_SaveLoad();
	HOST_Check(V_DataGlobals() == "", "after a load: no TRF_ data globals, no build globals"..V_DataGlobals());
	TRF_DumpState("test");
	HOST_Check(V_Logs("module=region event=dump region_count=8 ") >= 1 and V_Logs("module=safety event=dump gate=") >= 1 and V_Logs("module=shop event=dump") >= 1 and V_Logs("module=raid event=dump") >= 1
		and V_Logs("module=hail event=dump") >= 1 and V_Logs("module=tier event=dump ") >= 1, "TRF_DumpState calls every module dump");
end;

function TRF_HostNoop() end;

-- Dispatch ---------------------------------------------------------------------------------

local fn = getglobal("T_V02_"..strupper(strsub(HOST().scen, 5)));
if strsub(HOST().scen, 1, 3) == "v1-" then
	-- host_v1.lua (loaded next by host_stubs.lua) runs the scenario with these helpers.
elseif type(fn) == "function" then
	fn();
	HOST_Check(T_LeftGlobals() == "", "no handle globals left at the end"..T_LeftGlobals());
else
	HOST_Check(nil, "unknown scenario "..tostring(HOST().scen));
end;
