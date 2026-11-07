-- Survey layer and the quest "Chart the frontier" scenarios (design/survey-spec.md 13, A12 step 2) under stock Lua 4.0.1:
-- TRF_SY=a..h, run by run_host.sh as its own entry point. a install (loader, lists, texts, cfg and tune defaults and clamps,
-- the generated table and the rules the host sees, the module body, the pure rules, survey 0); b the offer and the quest
-- record (every TRF_SyOfferWhy reason, the picks, box 410 against the debrief 420, card, Office row, OK, Cancel, Esc,
-- markers); c readings (1x and 8x holds, leaving, holds paused, dt 0, the random portal bound, fees, payoffs P0-P4, the near
-- line, the quest mask and the step change, thresholds); d gates (R1-R7, TRF_Wn_Armed); e the dock (hand-in, logbook with
-- the Job log on and off, the chart sale, the value, sy_sell_max, ring kind 14 and harbour news); f save and repair (corrupt
-- TRF.sy, quest fields, lapse, size); g absent and off (module missing, survey 0, sy_quest 0, sy_gate 0, survey_at); h
-- neighbours (TRF_Sg_SlotRec, TRF_Wn_Armed, TRF_IqOwners, TRF_IqStale with q 3).
-- Loads host_debrief.lua up to its first scenario (host_parcel.lua's prefix: host_station.lua's prefix with the stubs of
-- host_stubs.lua, the helpers of host_traffic.lua and host_v02.lua, the PC_* helpers; then the DB_* helpers).

local f = openfile((getenv("TRF_TESTS") or "./").."host_debrief.lua", "r");
if not f then print("HOST FAIL host_survey.lua: cannot open host_debrief.lua"); exit(1); end;
local src = read(f, "*a");
closefile(f);
local cut = strfind(src, "\n-- a: registration, defaults, texts, pure rules, repair, the dialog gate", 1, 1);
if not cut then print("HOST FAIL host_survey.lua: marker '-- a: registration, defaults, ...' missing in host_debrief.lua"); exit(1); end;
dostring(strsub(src, 1, cut), "host_debrief.lua");

-- Helpers ----------------------------------------------------------------------------------

-- Config of these runs: the survey and the charter on; the debrief inert (debrief_xp 0), parcels, the freight quest,
-- temperaments, corp, warnings, remarks, captains, stashes, survivors, freight and scars off; no signal light (sg_pct 0);
-- the box path of the jobs UI; log 2; plus t.
function SY_Cfg(t)
	local c = {survey=1, sy_quest=1, sy_gate=1, charter=1, debrief=1, debrief_xp=0, enable_parcels=0, enable_wq=0, temper=0, corp=0,
		warn=0, remarks=0, signals=1, tips=1, cap_enable=0, sweeps=0, sweep_ct=0, feq=0, staged=0, seed=0, queue=0, parked=0,
		voice_events=0, dconv=0, carriers=0, po=0, enable_stashes=0, enable_survivors=0, enable_freight=0, enable_scars=0, jobs_ui=0,
		log=2, tune={sg_pct=0}};
	if t then for k, v in t do c[k] = v; end; end;
	return c;
end;

-- Scenario start in sys at chapter label ch (default 6): no intro quest, no survey state, no Job log (jl 1 installs it).
function SY_Begin(sys, ch, t, jl)
	local h = HOST();
	h.jl = {}; h.jl_off = nil;
	HOST_JobLogOn(jl or 0);
	h.jc = {}; h.jq = {}; h.jc_open = nil; h.jc_off = nil; h.jc_why = nil;
	TRF_MissionCard = nil; TRF_JobBoard = nil; TRF_JobBoardMark = nil;
	h.labels.OnRandomPortal_all = nil;
	h.syhook = nil;
	h.diff = NORMAL;
	PC_Begin(sys, ch or "6", SY_Cfg(t));
	-- The entry of PC_Begin may have restored an entry of the run before (the reconcile of 7.5).
	h.quests = {}; h.qlog = {}; h.jl = {};
	TRF.iq = nil; TRF.sy = nil; TRF.sg = nil; TRF.ti = nil; TRF.base = {}; TRF.ch = nil;
	TRF_SyKeepThunk = nil;
	TRF.clock.legs = 100;
	if type(TRF_SyVisit) == "function" then TRF_SyVisit(); end;
end;

-- The scene of an entry runs HOST().syhook after the module files are loaded and before TRF_OnEnter.
SY_Scene0 = T_Scene;
function T_Scene(sys)
	SY_Scene0(sys);
	local h = HOST();
	if h.syhook then h.syhook(); end;
end;

-- Distance of two {x, y, z} tables.
function SY_D(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z;
	return sqrt(dx * dx + dy * dy + dz * dz);
end;

function SY_Has(s, t) return strfind(s or "", t, 1, 1); end;
function SY_N(t) local n = 0; for k, v in t do n = n + 1; end; return n; end;

-- survey log lines after mark n0 holding pat (plain).
function SY_Logs(n0, pat)
	local n, q = 0, HOST().logs;
	for i = n0 + 1, getn(q) do if strfind(q[i], "module=survey ", 1, 1) and strfind(q[i], pat, 1, 1) then n = n + 1; end; end;
	return n;
end;

-- Last survey log line after n0 holding pat, or "".
function SY_Line(n0, pat)
	local q, r = HOST().logs, "";
	for i = n0 + 1, getn(q) do if strfind(q[i], "module=survey ", 1, 1) and strfind(q[i], pat, 1, 1) then r = q[i]; end; end;
	return r;
end;

-- Screen lines after index s0 joined by "|".
function SY_Scr(s0)
	local q, s = HOST().screen, "";
	for i = (s0 or 0) + 1, getn(q) do s = s..q[i].t.."|"; end;
	return s;
end;

function SY_Row(id) return TRF_SyData()[id]; end;
function SY_Idx(id) return V_Idx(TRF_SyData()[id].s); end;

-- Row id of system name and kind k (first match).
function SY_Find(name, k)
	local d = TRF_SyData();
	for i = 1, getn(d) do if d[i].s == name and (k == nil or d[i].k == k) then return i; end; end;
	return nil;
end;

-- The mothership at the reading point of row id, dx units off in x.
function SY_At(id, dx)
	local r = SY_Row(id);
	HOST().ms.pos = Vector3(r.x + (dx or 0), r.y, r.z);
end;

function SY_Far() HOST().ms.pos = Vector3(9000, 0, 9000); end;

-- secs of game time in ticks of dt (default 0.5).
function SY_Run(secs, dt)
	dt = dt or 0.5;
	T_Tick(floor(secs / dt + 0.5), dt);
end;

-- The survey open for every region (the done bit of quest 4).
function SY_Open() TRF.iq = {a=0, d=8, r=0}; end;

-- Rows ids set read in TRF.sy (others kept).
function SY_SetRead(...)
	local bits, bl, nrg = TRF_SyState();
	for i = 1, arg.n do bits = TRF_SySetOf(bits, arg[i], getn(TRF_SyData())); end;
	TRF_SyStore(bits, bl, nrg);
end;

function SY_Read(id) return TRF_SyBitOf(TRF_SyBits(), id); end;

-- Block of region slot b, "" when empty.
function SY_Blk(b)
	local bits, bl = TRF_SyState();
	return bl[b] or "";
end;

function SY_SetBlk(b, x)
	local bits, bl, nrg = TRF_SyState();
	bl[b] = x;
	TRF_SyStore(bits, bl, nrg);
end;

-- Quest 4 taken with rows a, b, c (s 1, mask 0).
function SY_Take(a, b, c)
	TRF.iq = nil;
	return TRF_IqTake(4, a, b * 100 + c);
end;

function SY_Read0(p)
	local fh = openfile(p, "rb");
	if not fh then return nil; end;
	local s = read(fh, "*a");
	closefile(fh);
	return s;
end;

-- Counts AddQuest and TRF_JobAdd calls (HOST().aq, HOST().ja) from now on.
function SY_CountLog()
	local h = HOST();
	h.aq = 0; h.ja = 0;
	if not SY_AQ0 then SY_AQ0 = AddQuest; end;
	AddQuest = function(id, t, d, s) local h = HOST(); h.aq = (h.aq or 0) + 1; return SY_AQ0(id, t, d, s); end;
	if type(TRF_JobAdd) == "function" then
		local ja = TRF_JobAdd;
		-- The plumbing's probe TRF_JobAdd() (no argument) is not a write.
		TRF_JobAdd = function(...) local h = HOST(); if arg.n > 0 then h.ja = (h.ja or 0) + 1; end; return call(%ja, arg); end;
	end;
end;

function SY_Uncount()
	if SY_AQ0 then AddQuest = SY_AQ0; SY_AQ0 = nil; end;
end;

-- a: install and table (12.1, 4.1, 10, 9) --------------------------------------------------------------

function T_SY_A()
	local h = HOST();
	SY_Begin("gredos");
	HOST_Check(S_Logs(0, "module=core event=loaded map=true module_count=18 extra_count=24") >= 1, "trf_survey loads last (extra_count=24)");
	local ml, pm, tf, uf = TRF_ModList(), TRF_PlMods(), TRF_Loc_TextFns(), TRF_UI_TextFns();
	HOST_Check(ml[getn(ml)] == "Sy" and ml[getn(ml) - 1] == "Sg" and pm[getn(pm)] == "Sy" and tf[getn(tf) - 1] == "TRF_Sy_Text"
		and tf[getn(tf) - 2] == "TRF_Sg_Text" and tf[getn(tf)] == "TRF_Loc_Text" and uf[getn(uf)] == "TRF_Sy_Text",
		"Sy last in TRF_ModList and TRF_PlMods; TRF_Sy_Text after TRF_Sg_Text in both text lists");
	-- Registration: line 75 between the charter 70 and the debrief 80, box 410 between the debrief 420 and the parcel 400,
	-- row 410; not an offer owner of the marker registry.
	local P = TRF_PlReg();
	local lo, bo, ro = "", "", "";
	for i = 1, getn(P.dock.trade.line) do lo = lo..P.dock.trade.line[i].o..","; end;
	for i = 1, getn(P.dock.trade.box) do bo = bo..P.dock.trade.box[i].o..":"..TRF_PlName(P.dock.trade.box[i].f)..","; end;
	for i = 1, getn(P.dock.trade.row) do ro = ro..P.dock.trade.row[i].o..":"..TRF_PlName(P.dock.trade.row[i].f)..","; end;
	HOST_Check(SY_Has(lo, "70,75,80,") and SY_Has(bo, "420:TRF_Db_DockBox,410:TRF_Sy_DockBox,400:TRF_Pc_DockBox,")
		and SY_Has(ro, "420:TRF_Db_JobRow,410:TRF_Sy_JobRow,400:") and P.off.survey == nil, "trade line 75, box 410 and row 410 in their places; survey is no offer owner ("..lo.." "..bo..")");
	-- 44 keys; each resolves; no %, #, line break; "gate" only in "an old gate"; tichart in TRF_Ti_Text; the scaffold has them.
	local tx, bad, n = TRF_Sy_Text(), "", 0;
	for k, v in tx do
		n = n + 1;
		if strsub(k, 1, 2) ~= "sy" or TRF_Txt(k) == k or SY_Has(v, "%") or SY_Has(v, "#") or SY_Has(v, "\n") or strlen(v) >= 480
			or (k ~= "sykgr" and SY_Has(strlower(v), "gate")) then
			bad = bad.." "..k;
		end;
	end;
	HOST_Check(n == 44 and bad == "" and tx.sykgr == "an old gate"
		and TRF_Ti_Text().tichart == "$1 say the Star Wolves sold the FTU a fresh chart of the $2 region at $3 $4.",
		"44 sy keys, each resolves, no %, #, line break, 'gate' only for the ruins; tichart"..bad);
	local en = SY_Read0(h.dir.."../../../../loc/trf_en.loc");
	local miss = "";
	for k, v in tx do if not SY_Has(en, "#TRF_"..k.." = ") then miss = miss.." "..k; end; end;
	if not SY_Has(en, "#TRF_tichart = ") then miss = miss.." tichart"; end;
	HOST_Check(en and miss == "", "loc/trf_en.loc holds the 45 keys (the logbook keys syqt, syqd*, sylt, syld among them)"..miss);
	-- cfg and tune defaults, clamps.
	HOST_Check(TRF_Opt("survey") == 1 and TRF_Sy_OptDef().survey == 1 and TRF_OptEnum().survey == 1 and TRF_OptEnum().sy_quest == 1
		and TRF_OptEnum().sy_gate == 1 and TRF_SyOpt("sy_quest") == 1 and TRF_SyOpt("sy_gate") == 1 and TRF_SyOpt("survey_at") == "",
		"cfg survey, sy_quest, sy_gate 1, survey_at empty; enumerated");
	h.cfg.tune = {};
	local T = TRF_SyTune();
	HOST_Check(SY_N(TRF_Sy_TuneDef()) == 17 and T.sy_ch == 5 and T.sy_ch_end == 20 and T.sy_read_r == 250 and T.sy_rp_min == 70 and T.sy_hold == 20
		and T.sy_near_r == 800 and T.sy_fee_k == 5 and T.sy_chart_k == 8 and T.sy_chart_drop == 15 and T.sy_chart_lo == 25 and T.sy_chart_old == 40
		and T.sy_thr1 == 30 and T.sy_thr2 == 60 and T.sy_thr_k == 10 and T.sy_sell_max == 2 and T.sy_dc == 2 and T.sy_secs == 8,
		"17 tune keys with the defaults of spec 10");
	h.cfg.tune = {sy_read_r=120, sy_rp_min=300, sy_near_r=50, sy_hold=1, sy_thr1=40, sy_thr2=10, sy_sell_max=9, sy_fee_k=7.9, sy_chart_old=0};
	T = TRF_SyTune();
	HOST_Check(T.sy_rp_min == 120 and T.sy_near_r == 120 and T.sy_hold == 5 and T.sy_thr2 == 40 and T.sy_sell_max == 8 and T.sy_fee_k == 7
		and T.sy_chart_old == 1, "clamps: sy_rp_min <= sy_read_r, sy_near_r >= sy_read_r, sy_hold >= 5, sy_thr2 >= sy_thr1, sy_sell_max <= 8, whole");
	h.cfg.tune = {sy_rp_min=10};
	HOST_Check(TRF_SyTune().sy_rp_min == 60, "sy_rp_min >= 60");
	h.cfg.tune = {sg_pct=0};
	h.cfg.sy_gate = 3;
	HOST_Check(TRF_SyOpt("sy_gate") == 1, "sy_gate 3 reads as the default");
	h.cfg.sy_gate = nil;
	-- The generated table (4.1): N <= 60 (46), every region with >= 2 rows, ids in the 4.1 order, the rules the host sees.
	local d = TRF_SyData();
	local rows = TRF_SyRows();
	local m = TRF_Map();
	local N = getn(d);
	local ko = {rp=1, gr=2, sr=3, hk=4, wf=5, cs=6};
	local out = {gideon=1, eridan=1, xt86=1, vulcan=1, xt24=1, zebos=1, fronn=1, elio=1, x297=1, gefest=1, nk=1};
	local bad2, W = "", 0;
	for id = 1, N do
		local r = d[id];
		local s = rows.ix[id];
		W = W + r.w;
		if not s or not rows.sl[id] or out[r.s] or not ko[r.k] or r.w < 1 or r.w > 3 then bad2 = bad2.." row"..id; end;
		if s then
			local e = m.sys[s];
			for j = 1, getn(e.st or {}) do
				local q = e.st[j];
				if type(q.x) == "number" and SY_D(q, r) < 400 then bad2 = bad2.." dock"..id; end;
			end;
			for j = 1, getn(e.portals or {}) do
				local q = e.portals[j];
				if SY_D(q, r) < 300 then bad2 = bad2.." portal"..id; end;
			end;
			if type(r.p) ~= "number" or r.p < 1 or r.p > getn(e.portals or {}) then bad2 = bad2.." p"..id; end;
		end;
		if id > 1 then
			local o = d[id - 1];
			local a = {rows.sl[id - 1] or 0, rows.ix[id - 1] or 0, ko[o.k] or 0, o.x, o.z};
			local b = {rows.sl[id] or 0, rows.ix[id] or 0, ko[r.k] or 0, r.x, r.z};
			local lt = nil;
			for j = 1, 5 do if a[j] ~= b[j] then lt = a[j] < b[j]; break; end; end;
			if not lt then bad2 = bad2.." order"..id; end;
		end;
		for j = 1, id - 1 do
			local o = d[j];
			if o.s == r.s and SY_D(o, r) < 600 then bad2 = bad2.." sep"..id; end;
		end;
	end;
	local few = "";
	for b = 1, TRF_RgMap().n do if getn(rows.rg[b] or {}) < 2 then few = few.." "..b; end; end;
	HOST_Check(N == 46 and N <= TRF_SyK().nmax and W == 106 and bad2 == "" and few == "" and rows.W[1] == 18 and rows.W[5] == 23 and rows.W[8] == 3,
		"46 rows (at most 60), weight 106, every region with >= 2 rows, ids in the 4.1 order, >= 400 from docks, >= 300 from portals, 600 apart, no excluded system"..bad2..few);
	-- The module body: no GetPlayerQuestState call, no name of the TRF_Sys family.
	local fs = openfile(h.dir.."trf_survey.script", "rb");
	local body = read(fs, "*a");
	closefile(fs);
	HOST_Check(not SY_Has(body, "GetPlayerQuestState(") and not SY_Has(body, "function TRF_Sys") and SY_Has(body, "function TRF_SyE(")
		and SY_Has(body, "-- BEGIN gen_survey.py"), "trf_survey: no GetPlayerQuestState call, no TRF_Sys name, the generated block");
	-- Pure rules.
	local bits = TRF_SySetOf("", 0, 46);
	HOST_Check(bits == "000000000000" and TRF_SySetOf(bits, 1, 46) == "100000000000" and TRF_SySetOf(bits, 4, 46) == "800000000000"
		and TRF_SySetOf(TRF_SySetOf(bits, 5, 46), 8, 46) == "090000000000" and TRF_SySetOf(bits, 47, 46) == bits and TRF_SyHexOf("f") == 15
		and TRF_SyHexOf("g") == nil and TRF_SyBitOf("090000000000", 8) == 1 and TRF_SyBitOf("090000000000", 6) == nil and TRF_SyBitOf("0", 9) == nil,
		"bits: ceil(N / 4) hex characters, bit mod(id - 1, 4) of character floor((id - 1) / 4) + 1");
	local b0, bl0, nb0 = TRF_SySplitOf("100000000000/s//0123/////", 8, 46);
	HOST_Check(b0 == "100000000000" and bl0[1] == "s" and bl0[2] == "" and bl0[3] == "0123" and nb0 == 8
		and TRF_SyJoinOf(b0, bl0) == "100000000000/s//0123/////" and TRF_SyJoinOf("000000000000", {"", "", ""}) == nil,
		"split and join round trip, nil when empty");
	local B = TRF_SyBlockOf("2995", 1003);
	HOST_Check(TRF_SyBlockOf("", 0).st == 0 and TRF_SyBlockOf("s", 0).st == 2 and B.st == 1 and B.ph == 2 and B.g == 995 and B.age == 8
		and TRF_SyBlockOf("6000", 0) == nil and TRF_SyBlockOf("12a4", 0) == nil and TRF_SyBlockOf("123", 0) == nil, "blocks: empty, sold, complete (age across the leg wrap), bad");
	T = TRF_SyTune();
	local v0 = TRF_SyValueOf(9000, 18, 2, 2, 0, 0, T);
	local v3, s3 = TRF_SyValueOf(9000, 18, 2, 5, 0, 0, T);
	local v5 = TRF_SyValueOf(9000, 18, 4, 3, 0, 0, T);
	local vo, so = TRF_SyValueOf(9000, 18, 2, 2, 41, 0, T);
	HOST_Check(v0 == 12960 and v3 == 7128 and s3 == 3 and v5 == 3240 and vo == 3240 and so == 5 and TRF_SyValueOf(9000, 3, 0, 0, 0, 0, T) == 2160
		and TRF_SyValueOf(9000, 18, 2, 2, 0, 1, T) == 14256 and TRF_SyValueOf(9000, 18, 2, 2, 40, 0, T) == 12960,
		"chart value: Dosis 12,960 fresh, 7,128 after 3 steps, 3,240 at the floor and past sy_chart_old, XT-27 2,160, +10 % per threshold");
	HOST_Check(TRF_SyFeeOf(9000, 3, 0, T) == 1350 and TRF_SyFeeOf(9000, 1, 0, T) == 450 and TRF_SyFeeOf(9000, 2, 2, T) == 1080
		and TRF_SyThrOf(29, T) == 0 and TRF_SyThrOf(30, T) == 1 and TRF_SyThrOf(60, T) == 2, "fee 5 % of PayN per weight point, the thresholds 30 and 60");
	local h1, st1 = TRF_SyHoldOf(0, 0.5, 100, nil, T);
	local h2, st2 = TRF_SyHoldOf(19.5, 0.5, 250, nil, T);
	local h3, st3 = TRF_SyHoldOf(10, 0.5, 251, nil, T);
	local h4, st4 = TRF_SyHoldOf(0, 2, 60, 1, T);
	local h5, st5 = TRF_SyHoldOf(4, 2, 75, 1, T);
	HOST_Check(h1 == 0.5 and st1 == "start" and h2 == 20 and st2 == "done" and h3 == 0 and st3 == "reset" and h4 == 0 and st4 == "out" and h5 == 6
		and st5 == "hold", "hold: start, done at sy_hold, reset outside sy_read_r, a random portal row only from sy_rp_min");
	local adj = {[1]={2}, [2]={1, 3}, [3]={2, 4}, [4]={3}, [5]={}};
	local n1, f1 = TRF_SyRouteOf(adj, 1, 4);
	local n2, f2 = TRF_SyRouteOf(adj, 1, 2);
	HOST_Check(n1 == 3 and f1 == 2 and n2 == 1 and f2 == 2 and TRF_SyRouteOf(adj, 3, 3) == 0 and TRF_SyRouteOf(adj, 1, 5) == nil, "route: jumps and the first hop");
	local pk = TRF_SyPickOf({{id=1, s=10}, {id=2, s=10}, {id=3, s=11}, {id=4, s=12}, {id=5, s=13}}, {[10]=1, [11]=2, [12]=0, [13]=1}, {[1]=5, [2]=3, [3]=1, [4]=9, [5]=1}, {[5]="armed"});
	local pr = TRF_SyPickOf({{id=1, s=10}, {id=2, s=10}, {id=3, s=11}}, {}, {}, {});
	local pn, pw = TRF_SyPickOf({{id=1, s=10}, {id=2, s=11}}, {}, {}, {});
	HOST_Check(pk[1] == 4 and pk[2] == 2 and pk[3] == 3 and pr[1] == 1 and pr[2] == 3 and pr[3] == 2 and pn == nil and pw == "few",
		"picks: jumps, then the hash, distinct systems first, repeats when the region has fewer systems, few below three");
	local all = {signal="S", base="B", route="R"};
	local k1 = TRF_SyPayoffOf(3, all);
	local k2 = TRF_SyPayoffOf(4, all);
	local k3 = TRF_SyPayoffOf(5, all);
	local k4 = TRF_SyPayoffOf(4, {signal="S"});
	HOST_Check(k1 == "signal" and k2 == "base" and k3 == "route" and k4 == "signal" and TRF_SyPayoffOf(5, {chart="C", route="R"}) == "chart"
		and TRF_SyPayoffOf(5, {trail="T", chart="C"}) == "trail" and TRF_SyPayoffOf(7, {}) == "none", "payoff: trail, chart, then from 1 + mod(id, 3) round signal, base, route");
	local q = TRF_SyIqOf(17, 1819);
	HOST_Check(q[1] == 17 and q[2] == 18 and q[3] == 19, "quest record: t and sd = id2 x 100 + id3");
	-- survey 0: nothing over 50 ticks at an open row, TRF.sy stays nil.
	h.cfg.survey = 0;
	SY_Open();
	T_Jump("xt20");
	SY_At(4);
	local n0 = S_Mark();
	SY_Run(50);
	HOST_Check(TRF.sy == nil and SY_Logs(n0, "module=survey ") == 0, "survey 0: no line, no reading over 50 s at the point, TRF.sy nil");
	h.cfg.survey = 1;
	-- The dump.
	n0 = S_Mark();
	TRF_Sy_Dump();
	HOST_Check(SY_Logs(n0, "event=dump on=1 row_count=46 read_count=0 points=0 charts=nil quest=nil") == 1, "dump line");
end;

-- b: the offer and the quest record (7.1, 4.3, 3.3) ----------------------------------------------------

function T_SY_B()
	local h = HOST();
	SY_Begin("dalled");
	local cur = TRF_CurIdx();
	local w = {};
	w.nooffice = TRF_SyOfferWhy(cur);
	DB_Office(1);
	local ok, ids = TRF_SyOfferWhy(cur);
	w.ok = ok;
	h.labels.CurrentQuest = "4_1";
	w.ch4 = TRF_SyOfferWhy(cur);
	h.labels.CurrentQuest = "6";
	h.qs = TRUE;
	w.mission = TRF_SyOfferWhy(cur);
	h.qs = FALSE;
	TRF_SyCV().q = 1;
	w.latch = TRF_SyOfferWhy(cur);
	TRF_SyCV().q = nil;
	h.cfg.charter = 0;
	w.charter = TRF_SyOfferWhy(cur);
	h.cfg.charter = 1;
	DB_Deny("dalled", "charter");
	w.deny = TRF_SyOfferWhy(cur);
	DB_Deny(nil);
	DB_Deny("dalled", "survey");
	w.sdeny = TRF_SyOfferWhy(cur);
	DB_Deny(nil);
	TRF_IqTake(1, 21, 1);
	w.busy = TRF_SyOfferWhy(cur);
	TRF.iq = {a=0, d=8, r=0};
	w.done = TRF_SyOfferWhy(cur);
	TRF.iq = nil;
	h.cfg.sy_gate = 0;
	w.gate = TRF_SyOfferWhy(cur);
	h.cfg.sy_gate = 1;
	h.cfg.sy_quest = 0;
	w.noq = TRF_SyOfferWhy(cur);
	h.cfg.sy_quest = 1;
	h.cfg.survey = 0;
	w.off = TRF_SyOfferWhy(cur);
	h.cfg.survey = 1;
	TRF_IqDecline(4);
	w.dec = TRF_SyOfferWhy(cur);
	TRF.clock.legs = TRF.clock.legs + 2;
	w.dec2 = TRF_SyOfferWhy(cur);
	TRF.iq = nil;
	TRF_SyCV().v.dec = 1;
	w.visit = TRF_SyOfferWhy(cur);
	TRF_SyCV().v.dec = nil;
	w.nomap = TRF_SyOfferWhy(nil);
	w.region = TRF_SyOfferWhy(V_Idx("earth"));
	w.few = TRF_SyOfferWhy(V_Idx("xt23"));
	local s = "";
	local ks = {"nooffice", "ok", "ch4", "mission", "latch", "charter", "deny", "sdeny", "busy", "done", "gate", "noq", "off", "dec", "dec2", "visit", "nomap", "region", "few"};
	for i = 1, getn(ks) do s = s..ks[i].."="..tostring(w[ks[i]]).." "; end;
	HOST_Check(w.nooffice == "office:locked" and w.ok == nil and w.ch4 == "chapter" and w.mission == "mission" and w.latch == "latch" and w.charter == "office:off"
		and w.deny == "office:strict" and w.sdeny == "strict:deny_survey" and w.busy == "busy" and w.done == "done" and w.gate == "gate" and w.noq == "off"
		and w.off == "off" and w.dec == "declined" and w.dec2 == nil and w.visit == "declined" and w.nomap == "nomap" and w.region == "region" and w.few == "few",
		"offer gates of 7.1: "..s);
	-- Picks (4.3): three rows of Dosis in distinct systems by jumps from the dock, no random portal before chapter 8.
	local rows = TRF_SyRows();
	local dist = TRF_SyDistFrom(cur);
	local pk = TRF_SyPicks(cur, 1);
	local sys, okp = {}, pk and getn(pk) == 3;
	if okp then
		for i = 1, 3 do
			local r = SY_Row(pk[i]);
			if sys[r.s] or r.k == "rp" or rows.sl[pk[i]] ~= 1 then okp = nil; end;
			sys[r.s] = 1;
			if i > 1 and dist[SY_Idx(pk[i])] < dist[SY_Idx(pk[i - 1])] then okp = nil; end;
		end;
	end;
	HOST_Check(okp, "picks: three Dosis rows in distinct systems by jumps, no random portal ("..tostring(TRF_SyIds(pk or {}))..")");
	-- An armed row and a strict-denied system are left out.
	local s1 = SY_Row(pk[1]).s;
	local wa = TRF_Wn_Armed;
	TRF_Wn_Armed = function(i) if i == V_Idx(%s1) then return 1, "test"; end; return nil; end;
	local pa = TRF_SyPicks(cur, 1);
	TRF_Wn_Armed = wa;
	DB_Deny(s1, "survey");
	local pd = TRF_SyPicks(cur, 1);
	DB_Deny(nil);
	local noa, nod = 1, 1;
	for i = 1, 3 do
		if SY_Row(pa[i]).s == s1 then noa = nil; end;
		if SY_Row(pd[i]).s == s1 then nod = nil; end;
	end;
	HOST_Check(noa and nod, "an armed row ("..s1..") and a strict-denied system are never named");
	HOST_Check(TRF_SyPicks(V_Idx("xt23"), 8) == nil, "XT-27: fewer than three rows, no card (owner decision 12)");
	-- The box at the dock: 410 with the three places, the shown line; OK takes quest 4 with the three ids.
	SY_Begin("dalled");
	DB_Office(1);
	local n0 = S_Mark();
	local r = DB_Dock();
	local o = TRF_SyCV().offer;
	HOST_Check(r.nb == 1 and SY_Has(r.box.text, "FTU clerk: The survey office needs fresh readings for the Dosis chart.") and S_Logs(n0, "box=sy priority=410 result=box") == 1
		and SY_Logs(n0, "event=offer system=dalled region=1 landmarks="..TRF_SyIds(o.ids).." result=shown via=box") == 1 and strlen(r.box.text) < 480,
		"box 410: the Dosis chart, three places, the shown line");
	local s0 = getn(h.screen);
	HOST_Press("ok", r.box);
	local I = TRF_IqGet();
	HOST_Check(I.q == 4 and I.s == 1 and I.t == o.ids[1] and I.sd == o.ids[2] * 100 + o.ids[3] and I.c == 0 and h.qlog.trf_sy and h.qlog.trf_sy.t == "#TRF_syqt"
		and h.qlog.trf_sy.d == "#TRF_syqd0" and SY_Has(SY_Scr(s0), TRF_Txt("syok")) and SY_Logs(n0, "event=accept system=dalled landmarks=") == 1,
		"OK: TRF.iq q 4 s 1 t id1 sd id2 x 100 + id3 c 0; logbook syqd0; the reply syok");
	HOST_Check(TRF_PlMkCount() == 0, "no named row in dalled: no marker");
	-- Markers of the named rows in their system: job class, not counted as offers.
	local tid = o.ids[1];
	local ts = SY_Row(tid).s;
	n0 = S_Mark();
	T_Jump(ts);
	local nm = 0;
	for i = 1, 3 do if SY_Row(o.ids[i]).s == ts then nm = nm + 1; end; end;
	HOST_Check(TRF_MarkerHeld("TRF_SY_NP_"..tid) == 1 and TRF_PlMkCount() == nm and TRF_PlOfferCount() == 0
		and S_Logs(n0, "module=plumb event=marker owner=survey label=TRF_SY_NP_"..tid.." result=added") == 1, "markers: the named rows of "..ts..", owner survey, no offer marker");
	-- The debrief offer 420 wins over the survey 410; the survey's offer at the next docking.
	SY_Begin("dalled", "6", {debrief_xp=1});
	DB_Office(1);
	r = DB_Dock();
	HOST_Check(r.nb == 1 and r.box.text == TRF_Txt("dbbox"), "the debrief offer 420 first");
	PC_Press(r, "cancel");
	DB_Visit();
	r = DB_Dock();
	HOST_Check(r.nb == 1 and SY_Has(r.box.text, "survey office needs fresh readings"), "the survey offer 410 at the next docking (one box per docking)");
	PC_Press(r, "cancel");
	-- Cancel: the decline stamp, none in the visit, none for sy_dc legs.
	SY_Begin("dalled");
	DB_Office(1);
	r = DB_Dock();
	n0 = S_Mark();
	PC_Press(r, "cancel");
	local r2 = DB_Dock();
	HOST_Check(TRF.iq and TRF.iq.l == TRF.clock.legs * 10 + 4 and SY_Logs(n0, "event=decline system=dalled leg=") == 1 and r2.nb == 0, "Cancel: the decline stamp, no offer again in the visit");
	TRF.clock.legs = TRF.clock.legs + 1;
	DB_Visit(); TRF_SyVisit();
	r = DB_Dock();
	local no1 = r.nb == 0;
	TRF.clock.legs = TRF.clock.legs + 1;
	DB_Visit(); TRF_SyVisit();
	r = DB_Dock();
	HOST_Check(no1 and r.nb == 1, "the decline wait: none 1 leg later, the offer 2 legs later");
	PC_Press(r, "cancel");
	-- The card (jobs_ui 1): id sy; OK accepts; Esc does nothing.
	SY_Begin("dalled", "6", {jobs_ui=1});
	DB_Office(1);
	TRF_MissionCard = HOST_MissionCard;
	n0 = S_Mark();
	r = DB_Dock();
	local c = h.jc[1];
	HOST_Check(r.nb == 0 and c and c.id == "sy" and c.header == "Chart the frontier" and c.title == "Charter office" and SY_Has(c.text, "for the Dosis chart")
		and S_Logs(n0, "box=sy priority=410 result=card") == 1, "card: id sy, header Chart the frontier, title Charter office");
	HOST_Check(HOST_JobTick() == "open" and SY_Logs(n0, "result=shown via=card") == 1, "card open: via=card");
	HOST_JobPress("ok");
	HOST_JobTick();
	HOST_Check(TRF_IqGet().q == 4, "card OK: accepted");
	SY_Begin("dalled", "6", {jobs_ui=1});
	DB_Office(1);
	TRF_MissionCard = HOST_MissionCard;
	n0 = S_Mark();
	r = DB_Dock();
	HOST_JobTick();
	HOST_JobPress("esc");
	HOST_JobTick();
	HOST_Check(TRF.iq == nil and SY_Logs(n0, "event=decline system=dalled leg=") == 1 and SY_Logs(n0, "result=closed") == 1 and TRF_SyOfferWhy(TRF_CurIdx()) == nil,
		"card Esc: nothing, offered again");
	TRF_MissionCard = nil;
	-- The Office row (jobs_ui 2).
	SY_Begin("dalled", "6", {jobs_ui=2});
	DB_Office(1);
	local row = TRF_Sy_JobRow("trade");
	HOST_Check(row and row.id == "sy" and row.header == "Chart the frontier" and row.short == TRF_Txt("syjobs", "Dosis") and row.ok == "TRF_Sy_BoxOk"
		and row.no == "TRF_Sy_BoxNo" and row.took == "TRF_Sy_JobTook" and TRF_Sy_JobTook(row.a) == nil, "Office row 410: id, header, short text, handlers");
	TRF_PlReg().jb = {k="trade", rows={}, g=TRF.gen};
	HOST_Check(TRF_Sy_DockBox("trade") == nil, "no box after the board was set at this docking");
	TRF_PlReg().jb = nil;
	local rep = TRF_Sy_BoxOk(row.a);
	HOST_Check(TRF_IqGet().q == 4 and TRF_Sy_JobTook(row.a) == 1 and rep == TRF_Txt("syok"), "row OK: taken, took answers 1, the reply");
	-- A stale OK (another generation): nothing taken.
	SY_Begin("dalled");
	DB_Office(1);
	r = DB_Dock();
	TRF.gen = TRF.gen + 1;
	n0 = S_Mark();
	HOST_Press("ok", r.box);
	HOST_Check(TRF.iq == nil and SY_Logs(n0, "event=accept system=dalled result=stale") == 1, "a stale OK takes nothing");
end;

-- c: readings (6.2-6.4) ---------------------------------------------------------------------------

function T_SY_C()
	local h = HOST();
	SY_Begin("gredos");
	SY_Open();
	T_Jump("xt20");
	local idx = TRF_CurIdx();
	local T = TRF_SyTune();
	HOST_Check(getn(TRF_SyCV().lm) == 2 and TRF_SyCV().ok == "ok", "xt20: rows 4 and 5 open");
	-- The near line once per visit.
	SY_Far();
	local n0, s0 = S_Mark(), getn(h.screen);
	SY_Run(3);
	SY_At(4, 700);
	SY_Run(3);
	SY_At(4, 600);
	SY_Run(3);
	HOST_Check(SY_Logs(n0, "event=near system=xt20 landmark=4 kind=hk distance=700") == 1 and SY_Logs(n0, "event=near ") == 1
		and SY_Has(SY_Scr(s0), "Survey scope: a dead capital ship about 700 units out. Hold within 250 units for 20 seconds to log it."), "near line at 800 units, once per visit");
	-- 1x: 19.5 s nothing, 20 s the reading; the hold line once; the fee paid; one line.
	SY_At(4, 100);
	local c0 = h.credits;
	n0, s0 = S_Mark(), getn(h.screen);
	SY_Run(19.5);
	local mid = SY_Read(4);
	SY_Run(0.5);
	local F = TRF_SyFeeOf(TRF_PayN(idx), 3, 0, T);
	HOST_Check(not mid and SY_Read(4) == 1 and h.credits - c0 == F and F > 0 and SY_Logs(n0, "event=hold system=xt20 landmark=4 kind=hk distance=100 hold=0.000 result=start") == 1
		and SY_Logs(n0, "event=read system=xt20 system_index="..idx.." landmark=4 kind=hk weight=3 points=3 threshold_count=0 fee="..F) == 1
		and S_Logs(n0, "module=region event=pay reason=survey amount="..F) == 1, "1x: the reading at 20 s of game time, fee "..F.." paid once");
	local sc = SY_Scr(s0);
	HOST_Check(SY_Has(sc, "Survey scope locked on a dead capital ship. Hold position.|") and SY_Has(sc, "Survey reading logged: a dead capital ship in XT-20. The FTU survey office credits "..F.." cr.")
		and SY_Has(SY_Line(n0, "event=read "), "payoff=route payoff_system=xt20 quest_mask=nil result=logged")
		and SY_Has(sc, "Next for the Dosis chart: "..TRF_SyPlace(5)..", in this system."), "the hold line, the reading line with the route note to row 5 in this system");
	HOST_Check(getn(TRF_SyCV().lm) == 1 and TRF_SyCV().lm[1] == 5, "row 4 left the open rows");
	SY_Run(25);
	HOST_Check(SY_Logs(n0, "event=read ") == 1, "one reading per row");
	-- 8x (dt 2): row 5 after 10 ticks; the route note two jumps on.
	SY_At(5, -50);
	n0, s0 = S_Mark(), getn(h.screen);
	T_Tick(9, 2);
	mid = SY_Read(5);
	T_Tick(1, 2);
	local nj, hop = TRF_SyRouteOf(TRF_SyAdj(), idx, V_Idx("xt39"));
	HOST_Check(not mid and SY_Read(5) == 1 and nj == 2 and SY_Has(SY_Scr(s0), TRF_Txt("syjn", 2, TRF_SysEn(hop))), "8x: 20 game seconds in 10 ticks; the route note two jumps on through the "..TRF_SysEn(hop).." portal");
	-- Leaving resets; dt 0 adds nothing.
	SY_Begin("gredos");
	SY_Open();
	T_Jump("xt39");
	SY_At(6);
	SY_Run(10);
	n0 = S_Mark();
	SY_At(6, 300);
	SY_Run(0.5);
	HOST_Check(SY_Logs(n0, "event=hold system=xt39 landmark=6 kind=hk distance=300 hold=10.") == 1 and SY_Logs(n0, "result=reset") == 1, "leaving the radius resets the hold");
	SY_At(6);
	TRF_Sy_Tick(0);
	SY_Run(19.5);
	HOST_Check(not SY_Read(6), "after the reset the hold starts again (19.5 s: none)");
	SY_Run(0.5);
	HOST_Check(SY_Read(6) == 1, "20 s after the reset: read");
	-- __disableAction pauses the hold (kept), a scene too; TRF_Supp too.
	SY_At(7);
	SY_Run(10);
	__disableAction = TRUE;
	n0 = S_Mark();
	SY_Run(20);
	__disableAction = FALSE;
	HOST_Check(not SY_Read(7) and SY_Logs(n0, "event=hold system=xt39 reason=disable_action result=paused") == 1 and TRF_SyCV().h[7] == 10, "__disableAction pauses the hold, 10 s kept");
	SY_Run(10);
	HOST_Check(SY_Read(7) == 1, "the paused hold completes 10 s later");
	SY_Begin("gredos");
	SY_Open();
	T_Jump("kitaro");
	local im = TRF_InMovie;
	TRF_InMovie = HOST_InMovie; h.mov = 1;
	SY_At(2);
	n0 = S_Mark();
	SY_Run(25);
	TRF_InMovie = im; h.mov = nil;
	HOST_Check(not SY_Read(2) and SY_Logs(n0, "reason=scene result=paused") == 1, "a scene pauses the hold");
	-- The random portal (xt54, row 8): closed before OnRandomPortal_all is "yes"; at 60 no count; 75 counts.
	SY_Begin("gredos");
	SY_Open();
	T_Jump("xt54");
	SY_At(8, 75);
	n0 = S_Mark();
	SY_Run(25);
	HOST_Check(not SY_Read(8) and getn(TRF_SyCV().lm) == 0 and SY_Logs(n0, "module=survey event=read ") == 0, "random portal row closed before OnRandomPortal_all");
	h.labels.OnRandomPortal_all = "yes";
	SY_At(8, 60);
	n0 = S_Mark();
	SY_Run(25);
	HOST_Check(not SY_Read(8) and getn(TRF_SyCV().lm) == 1 and SY_Logs(n0, "event=skip system=xt54 reason=rp_near") == 1, "60 units: no count (rp_near)");
	SY_At(8, 75);
	SY_Run(20.5);
	HOST_Check(SY_Read(8) == 1, "75 units: read");
	SY_Begin("gredos");
	SY_Open();
	h.labels.OnRandomPortal_all = "yes";
	T_Jump("proserpina");
	SY_At(SY_Find("proserpina", "rp"), 240);
	SY_Run(20.5);
	HOST_Check(SY_Read(SY_Find("proserpina", "rp")) == 1, "240 units: read");
	h.labels.OnRandomPortal_all = nil;
	-- Payoffs: P1 signal (row 6: mod(6, 3) = 0, signal first), P2 base (row 4: base first), P4 chart, P0 trail.
	SY_Begin("gredos");
	SY_Open();
	T_Jump("xt39");
	TRF.sg = TRF_SgJoinOf({{s=V_Idx("kitaro"), p=1, g=TRF.clock.legs, t=0}}, TRF_RgMap().n);
	SY_At(6);
	n0, s0 = S_Mark(), getn(h.screen);
	SY_Run(20.5);
	HOST_Check(SY_Has(SY_Line(n0, "event=read "), "payoff=signal payoff_system=kitaro") and SY_Has(SY_Scr(s0), "The scope also logs a looping distress call from Kitaro."),
		"P1: the lit, unheard signal of the region in another system");
	TRF.sg = nil;
	T_Jump("xt20");
	TRF.base = {{s=V_Idx("xt39"), k=2, c=1, a=TRF.clock.legs}};
	SY_At(4);
	n0, s0 = S_Mark(), getn(h.screen);
	SY_Run(20.5);
	HOST_Check(SY_Has(SY_Line(n0, "event=read "), "payoff=base payoff_system=xt39") and SY_Has(SY_Scr(s0), "Survey traffic places a pirate base in XT-39."), "P2: a pirate base's system");
	TRF.base = {};
	-- P4: Torr's last row completes the chart.
	SY_SetRead(41, 42, 43);
	T_Jump("llanovar2");
	TRF.rg[7].ph = 3;
	SY_At(44);
	n0, s0 = S_Mark(), getn(h.screen);
	SY_Run(20.5);
	HOST_Check(SY_Blk(7) == format("3%03d", mod(TRF.clock.legs, 1000)) and SY_Has(SY_Line(n0, "event=read "), "payoff=chart")
		and SY_Logs(n0, "event=chart region=7 landmark_count=4 weight=7 phase=3 leg="..TRF.clock.legs.." result=complete") == 1
		and SY_Has(SY_Scr(s0), "That completes the Torr chart. It sells once to an FTU office outside the region."), "P4: the chart block with the phase and leg, the line");
	-- P0: the A07 hook first.
	TRF_Tr_SurveyFrag = function(id) return "A trail fragment."; end;
	SY_At(43);
	SY_SetRead(41);
	T_Jump("xt52");
	T_Jump("kitaro");
	TRF_Tr_SurveyFrag = function(id) return "A trail fragment."; end;
	SY_At(3);
	n0 = S_Mark();
	SY_Run(20.5);
	TRF_Tr_SurveyFrag = nil;
	HOST_Check(SY_Has(SY_Line(n0, "event=read "), "payoff=trail"), "P0: the trail fragment first (A07 hook)");
	-- The threshold crossing at 30 points: one line, the bonus on the next fee.
	SY_Begin("gredos");
	SY_Open();
	SY_SetRead(9, 10, 11, 12, 13, 14, 15, 16, 20, 21, 22, 23);
	HOST_Check(TRF_SyPtsOf(TRF_SyBits(), TRF_SyData()) == 30 - 3, "fixture: 27 points");
	T_Jump("xt20");
	SY_At(4);
	n0, s0 = S_Mark(), getn(h.screen);
	SY_Run(20.5);
	HOST_Check(SY_Logs(n0, "event=threshold points=30 threshold=30 bonus=10 result=passed") == 1 and SY_Has(SY_Scr(s0), "Survey points: 30. The FTU office now pays 10 percent more for your readings and charts.")
		and SY_Has(SY_Line(n0, "event=read "), "threshold_count=0 fee="..TRF_SyFeeOf(TRF_PayN(TRF_CurIdx()), 3, 0, T)), "threshold 30: one line, the fee of this reading without the bonus");
	SY_At(5);
	n0 = S_Mark();
	SY_Run(20.5);
	HOST_Check(SY_Has(SY_Line(n0, "event=read "), "threshold_count=1 fee="..TRF_SyFeeOf(TRF_PayN(TRF_CurIdx()), 3, 1, T)), "the next fee +10 %");
	-- The quest: three named rows (4, 5, 6), the mask, the step change; other rows closed.
	SY_Begin("gredos");
	SY_Take(4, 5, 6);
	T_Jump("xt20");
	HOST_Check(getn(TRF_SyCV().lm) == 2 and TRF_MarkerHeld("TRF_SY_NP_4") == 1 and TRF_MarkerHeld("TRF_SY_NP_5") == 1, "quest: rows 4 and 5 open and marked");
	SY_At(4);
	n0, s0 = S_Mark(), getn(h.screen);
	SY_Run(20.5);
	local I = TRF_IqGet();
	HOST_Check(I.s == 1 and I.c == 1 and SY_Has(SY_Scr(s0), "Chart the frontier: 1 of 3 readings logged.") and SY_Has(SY_Line(n0, "event=read "), "quest_mask=1")
		and TRF_MarkerHeld("TRF_SY_NP_4") == nil and TRF_MarkerHeld("TRF_SY_NP_5") == 1 and SY_Has(SY_Scr(s0), TRF_SyPlace(5)), "first named reading: mask 1, the count clause, marker 4 gone, the route to row 5");
	SY_At(5);
	SY_Run(20.5);
	HOST_Check(TRF_IqGet().c == 3 and TRF_IqGet().s == 1, "second: mask 3");
	T_Jump("xt39");
	HOST_Check(getn(TRF_SyCV().lm) == 1 and TRF_SyCV().lm[1] == 6, "xt39: only the named row 6 open (row 7 closed)");
	SY_At(6);
	s0 = getn(h.screen);
	SY_Run(20.5);
	I = TRF_IqGet();
	HOST_Check(I.s == 2 and I.c == 7 and SY_Has(SY_Scr(s0), "Chart the frontier: all three readings logged. Hand them in at any FTU trade station.") and TRF_PlMkCount() == 0,
		"third: step 20, mask 7, the hand-in clause, no marker");
	SY_At(7);
	n0 = S_Mark();
	SY_Run(25);
	HOST_Check(not SY_Read(7) and SY_Logs(n0, "event=read ") == 0, "an unnamed row stays closed before the hand-in");
	HOST_Check(h.qlog.trf_sy and h.qlog.trf_sy.d == "#TRF_syqd0", "no logbook write from space (the entry still syqd0 until a trade dock)");
end;

-- d: gates (5) ----------------------------------------------------------------------------------------

function T_SY_D()
	local h = HOST();
	SY_Begin("gredos");
	SY_Open();
	local x20 = V_Idx("xt20");
	-- R1: cfg off.
	h.cfg.survey = 0;
	HOST_Check(TRF_SyGateR(x20, "space") == "off", "R1: survey 0 -> off");
	h.cfg.survey = 1;
	-- R2: chapter 4 and after sy_ch_end.
	h.labels.CurrentQuest = "4_1";
	local n0 = S_Mark();
	T_Jump("xt20");
	SY_At(4);
	SY_Run(25);
	HOST_Check(not SY_Read(4) and SY_Logs(n0, "event=skip system=xt20 reason=chapter") == 1, "R2: chapter 4 -> skip chapter");
	h.labels.CurrentQuest = "6";
	h.cfg.tune = {sg_pct=0, sy_ch_end=5};
	n0 = S_Mark();
	T_Jump("xt20");
	SY_At(4);
	SY_Run(25);
	h.cfg.tune = {sg_pct=0};
	HOST_Check(not SY_Read(4) and SY_Logs(n0, "event=skip system=xt20 reason=chapter") == 1, "R2: chapter 6 after sy_ch_end 5 -> skip chapter");
	-- R3: no map entry.
	HOST_Check(TRF_SyGateR(nil, "space") == "nomap" and TRF_SyGateR(9999, "dock") == "nomap", "R3: nomap");
	-- R4: sys_off.
	h.cfg.sys_off = {"xt20"};
	n0 = S_Mark();
	T_Jump("xt20");
	SY_At(4);
	SY_Run(25);
	h.cfg.sys_off = nil;
	HOST_Check(not SY_Read(4) and SY_Logs(n0, "event=skip system=xt20 reason=mode:sys_off") == 1, "R4: sys_off -> skip mode:sys_off");
	-- R5: a quest naming the system in process; a deny entry survey = 0.
	local qi = TRF_Map().sys[x20].qi;
	h.syhook = function() local h = HOST(); h.quests = {}; h.quests[%qi[1]] = QUEST_PROCESS; end;
	n0 = S_Mark();
	T_Jump("xt20");
	h.syhook = nil;
	SY_At(4);
	SY_Run(25);
	h.quests = {};
	HOST_Check(not SY_Read(4) and SY_Logs(n0, "event=skip system=xt20 reason=gate:quest") == 1, "R5: a quest naming xt20 -> skip gate:quest");
	h.syhook = function() local d0 = TRF_DenyEntry; TRF_DenyEntry = function(n) if n == "xt20" then return {survey=0}; end; return %d0(n); end; end;
	n0 = S_Mark();
	T_Jump("xt20");
	h.syhook = nil;
	SY_At(4);
	SY_Run(25);
	HOST_Check(not SY_Read(4) and SY_Logs(n0, "event=skip system=xt20 reason=gate:deny_survey") == 1, "R5: deny entry survey = 0 -> skip gate:deny_survey");
	-- R6: the latch, set at the entry and cleared after it: no reading for the visit.
	h.syhook = function() HOST().qs = TRUE; end;
	n0 = S_Mark();
	T_Jump("xt20");
	h.syhook = nil; h.qs = FALSE;
	SY_At(4);
	SY_Run(25);
	HOST_Check(not SY_Read(4) and SY_Logs(n0, "event=skip system=xt20 reason=latch") == 1, "R6: the visit latch holds for the visit");
	-- R7: the flags and TRF_Supp pause; the near line waits.
	T_Jump("xt20");
	SY_At(4, 500);
	__sys_SOS = TRUE;
	n0 = S_Mark();
	SY_Run(3);
	HOST_Check(SY_Logs(n0, "event=near ") == 0, "R7: __sys_SOS: no near line");
	__sys_SOS = FALSE;
	SY_Run(1.5);
	HOST_Check(SY_Logs(n0, "event=near ") == 1, "the near line once the flag is gone");
	T_Jump("xt52");
	T_Jump("xt20");
	SY_At(4);
	local sp = TRF_Supp;
	TRF_Supp = function() return 1; end;
	n0 = S_Mark();
	SY_Run(25);
	TRF_Supp = sp;
	HOST_Check(not SY_Read(4) and SY_Logs(n0, "reason=suppressed result=paused") == 1, "R7: TRF_Supp() ~= 0 pauses");
	SY_Run(20.5);
	HOST_Check(SY_Read(4) == 1 and TRF.sy ~= nil, "read after the suppression");
	-- Nothing changed by the gated runs: only row 4 read.
	local bits = TRF_SyBits();
	HOST_Check(bits == TRF_SySetOf(TRF_SySetOf("", 0, 46), 4, 46), "the gated runs read nothing else");
	-- R7 holds the quest markers too: after TRF_Sy_WindDown under __disableAction the steps place none, nor does an
	-- entry under the flag; the step after the flag clears places them again.
	SY_Begin("gredos");
	SY_Take(4, 5, 6);
	T_Jump("xt20");
	HOST_Check(TRF_MarkerHeld("TRF_SY_NP_4") == 1, "R7 markers: row 4 marked");
	__disableAction = TRUE;
	n0 = S_Mark();
	TRF_Sy_WindDown();
	SY_Run(5);
	HOST_Check(TRF_MarkerHeld("TRF_SY_NP_4") == nil and SY_Logs(n0, "event=skip system=xt20 reason=hold:disable_action") == 1,
		"R7: no marker after the wind-down while __disableAction is set, the skip line once");
	-- An entry clears the system's globals: the scene sets the flag again before TRF_OnEnter.
	h.syhook = function() __disableAction = TRUE; end;
	T_Jump("xt52");
	T_Jump("xt20");
	h.syhook = nil;
	SY_Run(3);
	HOST_Check(__disableAction == TRUE and TRF_MarkerHeld("TRF_SY_NP_4") == nil, "R7: an entry under the flag places no marker");
	__disableAction = FALSE;
	SY_Run(1.5);
	HOST_Check(TRF_MarkerHeld("TRF_SY_NP_4") == 1, "the marker returns at the step after the flag clears");
	-- TRF_Wn_Armed: an armed system's rows count, the card and the route skip them.
	SY_Begin("gredos");
	SY_Open();
	T_Jump("xt39");
	TRF_Wn_Armed = function(i) if i == V_Idx("xt20") then return 1, "test"; end; return nil; end;
	SY_At(6);
	n0 = S_Mark();
	local s0 = getn(h.screen);
	SY_Run(20.5);
	local why4 = TRF_SyLmWhy(4, "name");
	HOST_Check(SY_Read(6) == 1 and why4 == "armed" and not SY_Has(SY_Scr(s0), "in XT-20 by the"), "armed: xt20 never named in the route note (route from xt39 to row 7)");
	T_Jump("xt20");
	TRF_Wn_Armed = function(i) if i == V_Idx("xt20") then return 1, "test"; end; return nil; end;
	SY_At(4);
	SY_Run(20.5);
	HOST_Check(SY_Read(4) == 1, "armed: a reading there still counts");
end;

-- e: the dock (7.3, 8) -------------------------------------------------------------------------------

function T_SY_E()
	local h = HOST();
	-- Hand-in at a trade dock of another region (AddQuest fallback): done bit 8, the Survey log once, the count line.
	SY_Begin("gredos");
	SY_Take(4, 5, 6);
	TRF_IqSet(4, 2, 4, 7);
	SY_SetRead(4, 5, 6);
	T_Jump("xt52");
	T_Jump("gredos");
	SY_CountLog();
	local n0 = S_Mark();
	local r = DB_Dock();
	HOST_Check(TRF_IqDone(4) == 1 and TRF_IqGet().q == 0 and SY_Has(r.scr, TRF_Txt("syhand")) and SY_Logs(n0, "event=handin system=gredos leg=") == 1
		and h.qlog.trf_sy and h.qlog.trf_sy.t == "#TRF_sylt" and h.qlog.trf_sy.d == "#TRF_syld" and h.aq == 1
		and SY_Has(r.scr, TRF_Txt("sycount", 3, 46, 9, "none")), "hand-in: done bit, the Survey log by AddQuest once, the count line");
	DB_Visit(); TRF_SyVisit();
	n0 = S_Mark();
	r = DB_Dock();
	HOST_Check(h.aq == 1 and not SY_Has(r.scr, "Survey log:") and SY_Logs(n0, "event=logbook ") == 0, "the next dock: no AddQuest, no count line (unchanged)");
	SY_SetRead(7);
	DB_Visit(); TRF_SyVisit();
	r = DB_Dock();
	HOST_Check(h.aq == 1 and SY_Has(r.scr, TRF_Txt("sycount", 4, 46, 12, "none")), "a changed count: the count line again, no AddQuest");
	SY_Uncount();
	-- The hand-in's own docking sells no chart (7.4); the next trade dock does.
	SY_Begin("gredos");
	SY_Take(4, 5, 6);
	TRF_IqSet(4, 2, 4, 7);
	SY_SetRead(4, 5, 6, 41, 42, 43, 44);
	SY_SetBlk(7, format("1%03d", mod(TRF.clock.legs, 1000)));
	T_Jump("xt52");
	T_Jump("gredos");
	n0 = S_Mark();
	DB_Dock();
	HOST_Check(TRF_IqDone(4) == 1 and SY_Logs(n0, "event=handin ") == 1 and SY_Logs(n0, "event=sell ") == 0 and SY_Blk(7) ~= "s", "the hand-in docking sells no chart");
	DB_Visit(); TRF_SyVisit();
	n0 = S_Mark();
	DB_Dock();
	HOST_Check(SY_Logs(n0, "event=sell region=7 ") == 1 and SY_Blk(7) == "s", "the next trade dock sells it");
	-- The Job log on: the quest entry with plain text at the accept (sylog), kept at an unchanged dock, rewritten when the
	-- count changed, the Survey log at the hand-in; nothing written from space.
	SY_Begin("dalled", "6", {jobs_log=1}, 1);
	DB_Office(1);
	r = DB_Dock();
	local o = TRF_SyCV().offer;
	local s0 = getn(h.screen);
	n0 = S_Mark();
	HOST_Press("ok", r.box);
	local e = h.jl[1];
	HOST_Check(e and e.id == "trf_sy" and e.t == "Chart the frontier" and SY_Has(e.d, "Survey readings for the FTU charter office: ") and SY_Has(e.d, " (open)")
		and strlen(e.d) < 480 and SY_Has(SY_Scr(s0), TRF_Txt("sylog")) and SY_Logs(n0, "event=logbook id=trf_sy entry=quest list=jobs result=added") == 1,
		"Job log: the quest entry with plain text, sylog");
	DB_Visit(); TRF_SyVisit();
	n0 = S_Mark();
	r = DB_Dock();
	HOST_Check(SY_Logs(n0, "event=logbook ") == 0 and getn(h.jl) == 1, "an unchanged dock: no rewrite");
	SY_CountLog();
	local tid = o.ids[1];
	T_Jump(SY_Row(tid).s);
	SY_At(tid);
	SY_Run(20.5);
	HOST_Check(h.ja == 0 and h.aq == 0 and SY_Read(tid) == 1, "a reading in space writes nothing to the logbook");
	SY_Uncount();
	T_Jump("dalled");
	n0 = S_Mark();
	r = DB_Dock();
	HOST_Check(SY_Logs(n0, "event=logbook id=trf_sy entry=quest list=jobs result=rewritten") == 1 and SY_Has(h.jl[1].d, " (logged)"), "the next trade dock rewrites the entry once");
	DB_Visit(); TRF_SyVisit();
	n0 = S_Mark();
	r = DB_Dock();
	HOST_Check(SY_Logs(n0, "event=logbook ") == 0, "then no rewrite");
	TRF_IqSet(4, 2, TRF_IqGet().t, 7);
	DB_Visit(); TRF_SyVisit();
	n0, s0 = S_Mark(), getn(h.screen);
	r = DB_Dock();
	e = h.jl[1];
	HOST_Check(TRF_IqDone(4) == 1 and e and e.t == "Survey log" and SY_Has(e.d, "Survey points ") and SY_Has(e.d, "Dosis ") and strlen(e.d) < 480
		and SY_Logs(n0, "event=logbook id=trf_sy entry=quest list=jobs result=removed") == 1 and SY_Logs(n0, "entry=log list=jobs result=added") == 1
		and SY_Has(SY_Scr(s0), TRF_Txt("sylog")) and not SY_Has(r.scr, "Survey log:"), "hand-in with the Job log: the Survey log entry, sylog, no count line");
	-- A load drops the keep table: the first trade dock rewrites the Job log once.
	T_SaveLoad();
	n0 = S_Mark();
	r = DB_Dock();
	HOST_Check(SY_Logs(n0, "entry=log list=jobs result=rewritten") == 1, "after a load the first trade dock rewrites once");
	-- The sale (8.1): a complete Torr chart waits at a Torr dock, sells outside; the value; the ring push.
	SY_Begin("gredos");
	SY_Open();
	SY_SetRead(41, 42, 43, 44);
	SY_SetBlk(7, format("1%03d", mod(TRF.clock.legs, 1000)));
	TRF.rg[7].ph = 1;
	T_Jump("torr");
	n0 = S_Mark();
	r = DB_Dock();
	HOST_Check(SY_Blk(7) ~= "s" and SY_Logs(n0, "event=sell region=7 dock_system=torr dock_region=7 result=wait reason=region") == 1, "a dock of the chart's own region: wait");
	TRF.rg[7].ph = 3;
	TRF.clock.legs = TRF.clock.legs + 5;
	T_Jump("gredos");
	local c0 = h.credits;
	local age = TRF_SyBlockOf(SY_Blk(7), TRF.clock.legs).age;
	local V = TRF_SyValueOf(TRF_PayN(TRF_CurIdx()), 7, 1, 3, age, 0, TRF_SyTune());
	n0 = S_Mark();
	r = DB_Dock();
	local rr = TRF_RingRead(TRF_RgOf(TRF_CurIdx()), {k=14});
	HOST_Check(SY_Blk(7) == "s" and h.credits - c0 == V and V > 0 and SY_Logs(n0, "event=sell region=7 dock_system=gredos dock_region=3 weight=7 phase=3 steps=2 age="..age.." value="..V.." result=sold") == 1 and age >= 5
		and S_Logs(n0, "module=region event=pay reason=survey_chart amount="..V) == 1 and SY_Has(r.scr, TRF_Txt("sysell", "Torr", 7, V))
		and getn(rr) == 1 and rr[1].s == TRF_CurIdx() and rr[1].a == 7 and rr[1].l == 7, "sold outside the region: value "..V.." (2 phase steps), block s, ring kind 14 with a = 7");
	DB_Visit(); TRF_SyVisit();
	n0 = S_Mark();
	r = DB_Dock();
	HOST_Check(SY_Logs(n0, "event=sell ") == 0, "sold once");
	-- Harbour news in the buyer's region tells it once.
	local t1 = TRF_Ti_News(TRF_CurIdx(), nil, 1);
	TRF_Ti_DockEnd();
	local t2 = TRF_Ti_News(TRF_CurIdx(), nil, 1);
	HOST_Check(SY_Has(t1, "FTU haulers say the Star Wolves sold the FTU a fresh chart of the Torr region at Gredos") and not SY_Has(t2 or "", "Star Wolves"),
		"harbour news names the Star Wolves once ("..tostring(t1)..")");
	-- sy_sell_max 2: three charts, two at the first dock, the third at the next.
	SY_Begin("gredos");
	SY_Open();
	for b = 1, 8 do if b ~= 3 then SY_SetBlk(b, ""); end; end;
	SY_SetRead(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 41, 42, 43, 44);
	local lg = format("0%03d", mod(TRF.clock.legs, 1000));
	SY_SetBlk(1, lg); SY_SetBlk(2, lg); SY_SetBlk(7, lg);
	T_Jump("gredos");
	n0 = S_Mark();
	r = DB_Dock();
	HOST_Check(SY_Logs(n0, "result=sold") == 2 and SY_Blk(1) == "s" and SY_Blk(2) == "s" and SY_Blk(7) ~= "s", "sy_sell_max 2: the two lowest slots first");
	DB_Visit(); TRF_SyVisit();
	n0 = S_Mark();
	r = DB_Dock();
	HOST_Check(SY_Logs(n0, "result=sold") == 1 and SY_Blk(7) == "s", "the third at the next docking");
	-- A mission at the dock: no hand-in, no sale.
	SY_Begin("gredos");
	SY_Open();
	SY_SetRead(41, 42, 43, 44);
	SY_SetBlk(7, lg);
	T_Jump("gredos");
	h.qs = TRUE;
	n0 = S_Mark();
	r = DB_Dock();
	h.qs = FALSE;
	HOST_Check(SY_Blk(7) ~= "s" and SY_Logs(n0, "event=sell ") == 0, "a mission at the dock: no sale");
end;

-- f: save and repair (3, 6.5) ---------------------------------------------------------------------------

function T_SY_F()
	local h = HOST();
	SY_Begin("gredos");
	local rows = TRF_SyRows();
	local n = rows.n;
	local reg = rows.sl;
	local ph = {0, 1, 2, 3, 4, 5, 0, 1};
	local fx = function(s) local o, ch = TRF_SyFixOf(s, %n, 8, %reg, 1234, %ph); return o, ch; end;
	local o, ch = fx(17);
	HOST_Check(o == nil and ch[1][1] == "bits" and ch[1][2] == "dropped", "F1: a number is dropped");
	o = fx("1g0000000000////////");
	HOST_Check(o == "100000000000////////", "F2: a bad character reads 0");
	o = fx("1////////");
	HOST_Check(o == "100000000000////////", "F2: short bits padded");
	o = fx("1000000000001234////////");
	HOST_Check(o == "100000000000////////", "F2: long bits cut");
	o = fx("00000000000f////////");
	HOST_Check(o == "000000000003////////1234", "F2: bits above N (46) cleared (rows 45, 46 complete XT-27: F4 rebuilds its block) "..tostring(o));
	o = fx("100000000000///////");
	HOST_Check(o == "100000000000////////", "F3: 7 blocks padded to 8");
	o = fx("100000000000/////////s");
	HOST_Check(o == "100000000000////////", "F3: 9 blocks cut to 8");
	o, ch = fx("100000000000/x12//////");
	HOST_Check(o == "100000000000////////" and ch[1][1] == "block", "F3: a bad block reset");
	-- F4: Torr complete with "" rebuilt (phase 0 of slot 7, leg 234); Dosis incomplete with a block reset.
	local b = TRF_SySetOf("", 0, n);
	for id = 41, 44 do b = TRF_SySetOf(b, id, n); end;
	o = fx(b.."//////////");
	local bb, bl = TRF_SySplitOf(o, 8, n);
	HOST_Check(bl[7] == "0234" and bl[1] == "", "F4: a complete region gets its block (phase, leg)");
	o = fx(TRF_SySetOf(b, 1, n).."/1222//////");
	bb, bl = TRF_SySplitOf(o, 8, n);
	HOST_Check(bl[1] == "" and bl[7] == "0234", "F4: an incomplete region loses its block");
	o = fx("000000000000/s///////");
	HOST_Check(o == "000000000000/s///////", "a sold block is kept");
	HOST_Check(fx("000000000000////////") == nil and fx(nil) == nil, "F5: nil when empty");
	-- TRF_Sy_Fix on TRF.sy with the log line.
	TRF.sy = "zz";
	local n0 = S_Mark();
	TRF_Sy_Fix();
	HOST_Check(TRF.sy == nil and SY_Logs(n0, "event=fix field=bits result=reset reason=char") == 1, "TRF_Sy_Fix: the fix line");
	-- Quest 4 with each bad field; the done bit with an active run; the step made to agree.
	local qs = {
		{TRF_IqPack(4, 3, 4, 0, 506), "s"}, {TRF_IqPack(4, 1, 4, 0, 406), "t"}, {TRF_IqPack(4, 1, 4, 0, 541), "t"},
		{TRF_IqPack(4, 1, 99, 0, 506), "t"}, {TRF_IqPack(4, 1, 4, 8, 506), "c"}};
	local bad = "";
	for i = 1, getn(qs) do
		TRF.iq = {a=qs[i][1], d=0, r=0, l=TRF.clock.legs};
		n0 = S_Mark();
		TRF_Sy_Fix();
		if TRF.iq ~= nil or SY_Logs(n0, "event=fix field=quest result=dropped reason="..qs[i][2]) ~= 1 then bad = bad.." "..i; end;
	end;
	HOST_Check(bad == "", "quest 4: a bad step, row, region mix, row id or mask is dropped"..bad);
	TRF.iq = {a=TRF_IqPack(4, 1, 4, 0, 506), d=8, r=0, l=TRF.clock.legs};
	n0 = S_Mark();
	TRF_Sy_Fix();
	HOST_Check(TRF_IqGet().q == 0 and SY_Logs(n0, "reason=done") == 1, "the done bit with an active run: dropped");
	TRF.iq = {a=TRF_IqPack(4, 1, 4, 7, 506), d=0, r=0, l=TRF.clock.legs};
	TRF_Sy_Fix();
	HOST_Check(TRF_IqGet().s == 2 and TRF_IqGet().c == 7, "step 1 with mask 7 -> step 2");
	TRF.iq = {a=TRF_IqPack(4, 2, 4, 3, 506), d=0, r=0, l=TRF.clock.legs};
	TRF_Sy_Fix();
	HOST_Check(TRF_IqGet().s == 2 and TRF_IqGet().c == 7, "step 2 with mask 3 -> mask 7");
	-- The lapse after iq_stale: the run ends, the entry and the markers go, the rows read stay read.
	SY_Begin("gredos");
	SY_Take(4, 5, 6);
	TRF_SyLogbook("accept");
	SY_SetRead(4);
	HOST_Check(h.qlog.trf_sy ~= nil, "fixture: the quest entry");
	TRF.clock.legs = TRF.clock.legs + 41;
	n0 = S_Mark();
	T_Jump("xt20");
	HOST_Check(TRF_IqGet().q == 0 and h.qlog.trf_sy == nil and SY_Logs(n0, "event=lapse step=1 quest_mask=0 leg=") == 1 and SY_Read(4) == 1 and TRF_PlMkCount() == 0,
		"lapse after 40 legs: the run ends, the entry goes, row 4 stays read");
	-- Save and load keep TRF.sy; no fix line.
	SY_Open();
	SY_SetRead(1, 9);
	SY_SetBlk(4, "s");
	local keep = TRF.sy;
	n0 = S_Mark();
	T_SaveLoad();
	HOST_Check(TRF.sy == keep and SY_Logs(n0, "event=fix ") == 0, "TRF.sy survives a save and load");
	-- Size (3.5): 60 fixture rows read and every chart unsold: 73 bytes with the key; the 46-row table 70.
	local d60 = {};
	for i = 1, 60 do d60[i] = {s="xt20", k="hk", w=1, x=0, y=0, z=0, p=1}; end;
	local b60 = TRF_SySetOf("", 0, 60);
	for i = 1, 60 do b60 = TRF_SySetOf(b60, i, 60); end;
	local s60 = TRF_SyJoinOf(b60, {"5999", "5999", "5999", "5999", "5999", "5999", "5999", "5999"});
	local b46 = TRF_SySetOf("", 0, 46);
	for i = 1, 46 do b46 = TRF_SySetOf(b46, i, 46); end;
	local s46 = TRF_SyJoinOf(b46, {"5999", "5999", "5999", "5999", "5999", "5999", "5999", "5999"});
	HOST_Check(HOST_SaveSize(s60) + 10 == 73 and HOST_SaveSize(s46) + 10 == 70 and strlen(b60) == 15, "TRF.sy: 73 bytes worst case at 60 rows, 70 with the 46 rows");
	TRF.sy = s46;
	local size = 8 + 3 + HOST_SaveSize(TRF);
	print("HOST info TRF save size (survey run) "..size.." bytes, sy="..HOST_SaveSize(TRF.sy));
	HOST_Check(size < 100000, "full state of this run "..size.." < 100000");
end;

-- g: absent and off (D1, 10) ---------------------------------------------------------------------------

function T_SY_G()
	local h = HOST();
	-- The module missing: the trade chain as built.
	h.hide = {["trf_survey.script"]=1};
	SY_Begin("dalled");
	HOST_Check(S_Logs(0, "module=core event=loaded map=true module_count=18 extra_count=23") >= 1 and type(TRF_Sy_TradeLine) ~= "function",
		"trf_survey missing: extra_count=23, no module");
	DB_Office(1);
	local n0 = S_Mark();
	local r = DB_Dock();
	HOST_Check(S_Logs(n0, "module=charter event=dock ") == 1 and S_Logs(n0, "module=survey") == 0 and S_Logs(n0, "module=plumb event=dock kind=trade") == 1,
		"the trade chain without trf_survey: the charter line and the plumbing, no survey line");
	h.hide = nil;
	-- cfg survey 0: no offer, no line; no TRF.sy.
	SY_Begin("dalled", "6", {survey=0});
	DB_Office(1);
	n0 = S_Mark();
	r = DB_Dock();
	HOST_Check(r.nb == 0 and S_Logs(n0, "module=survey") == 0 and S_Logs(n0, "module=charter event=dock ") == 1 and TRF.sy == nil, "survey 0: the charter line, no survey offer or line");
	-- sy_quest 0: no offer; a named row is not counted.
	SY_Begin("dalled", "6", {sy_quest=0});
	DB_Office(1);
	r = DB_Dock();
	HOST_Check(r.nb == 0 and TRF_SyOfferWhy(TRF_CurIdx()) == "off", "sy_quest 0: no offer");
	SY_Take(4, 5, 6);
	T_Jump("xt20");
	SY_At(4);
	SY_Run(25);
	HOST_Check(not SY_Read(4) and TRF_IqGet().c == 0 and getn(TRF_SyCV().lm) == 0, "sy_quest 0: a named row is not counted");
	-- sy_gate 0: the survey open from chapter 5 without the quest, no offer.
	SY_Begin("dalled", "6", {sy_gate=0});
	DB_Office(1);
	HOST_Check(TRF_SyOfferWhy(TRF_CurIdx()) == "gate", "sy_gate 0: no offer");
	T_Jump("xt20");
	SY_At(4);
	SY_Run(20.5);
	HOST_Check(SY_Read(4) == 1 and TRF.iq == nil, "sy_gate 0: a reading without the quest");
	h.labels.CurrentQuest = "4_1";
	T_Jump("xt20");
	SY_At(5);
	SY_Run(25);
	h.labels.CurrentQuest = "6";
	HOST_Check(not SY_Read(5), "sy_gate 0: nothing before chapter 5");
	-- survey_at: the named system counts as open (debug line); another system does not.
	SY_Begin("gredos", "6", {survey_at="xt20"});
	n0 = S_Mark();
	T_Jump("xt20");
	SY_At(4);
	SY_Run(20.5);
	HOST_Check(SY_Logs(n0, "event=debug system=xt20 result=open") == 1 and SY_Read(4) == 1 and TRF_SyOpen(V_Idx("xt39")) == nil, "survey_at xt20: open there, a reading");
	T_Jump("xt39");
	SY_At(6);
	SY_Run(25);
	HOST_Check(not SY_Read(6), "survey_at: xt39 stays closed");
	-- No TRF.sy without a reading.
	SY_Begin("gredos");
	SY_Open();
	T_Jump("xt20");
	SY_Run(30);
	HOST_Check(TRF.sy == nil, "no TRF.sy without a reading");
end;

-- h: neighbours (12.3) --------------------------------------------------------------------------------

function T_SY_H()
	local h = HOST();
	SY_Begin("gredos");
	-- TRF_Sg_SlotRec per block.
	local ki, ta = V_Idx("kitaro"), V_Idx("tarrot");
	local bs = {};
	bs[1] = {s=ki, p=1, g=TRF.clock.legs - 2, t=0};
	bs[6] = {s=ta, p=2, g=TRF.clock.legs, t=1};
	TRF.sg = TRF_SgJoinOf(bs, TRF_RgMap().n);
	local r1, r6, r2 = TRF_Sg_SlotRec(1), TRF_Sg_SlotRec(6), TRF_Sg_SlotRec(2);
	HOST_Check(r1 and r1.s == ki and r1.t == 0 and r1.age == 2 and r6 and r6.s == ta and r6.t == 1 and r2 == nil and TRF_Sg_SlotRec("x") == nil,
		"TRF_Sg_SlotRec: the decoded record of a block, nil for an empty one");
	TRF.sg = nil;
	HOST_Check(TRF_Sg_SlotRec(1) == nil, "TRF_Sg_SlotRec: nil without TRF.sg");
	-- TRF_Wn_Armed: kassilia armed while Kfni is at war, disarmed otherwise; an unlisted system nil.
	local ka = V_Idx("kassilia");
	PC_Rel("Kfni", RELATION_WAR);
	local a1, c1 = TRF_Wn_Armed(ka);
	PC_Rel("Kfni", RELATION_NEUTRAL);
	local a2 = TRF_Wn_Armed(ka);
	HOST_Check(a1 == 1 and SY_Has(c1, "Kfni=war") and a2 == nil and TRF_Wn_Armed(V_Idx("gredos")) == nil and TRF_Wn_Armed(nil) == nil,
		"TRF_Wn_Armed: an armed and a disarmed row, an unlisted system");
	-- The intro-quest owners and the lapse of quest 3 without an owner.
	local ow = TRF_IqOwners();
	HOST_Check(getn(ow) == 4 and ow[1] == "TRF_Te_IqLapse" and ow[2] == "TRF_Db_IqLapse" and ow[3] == "" and ow[4] == "TRF_Sy_IqLapse", "TRF_IqOwners: {Te, Db, \"\", Sy}");
	TRF.iq = nil;
	TRF_IqTake(3, 0, 0);
	TRF.clock.legs = TRF.clock.legs + 41;
	local n0 = S_Mark();
	TRF_IqStale();
	HOST_Check(TRF_IqGet().q == 0 and S_Logs(n0, "module=plumb event=iq quest=3 ") >= 1, "TRF_IqStale: quest 3 has no owner and lapses there");
	-- Kind 14 in trf_tips: history, ti_ch, replace key k and a, always current, chart after signal in the tie order.
	local e = TRF_TiKindOf(14);
	HOST_Check(e and e.nm == "chart" and e.cl == "h" and e.ch == "ti_ch" and e.rk == "ka" and e.tx == "tichart" and TRF_TiKindOf(15) == nil
		and TRF_TiLiveOf({k=14, s=1}, {}) == "current" and TRF_TiRankOf(14) == TRF_TiRankOf(13) + 1, "ring kind 14 chart: the kind row of 8.3");
	-- The A08 signal payoff and the survey markers stay apart from the offer cap (job markers).
	HOST_Check(TRF_PlReg().off.survey == nil and TRF_PlReg().off.signal == 1, "survey markers are job markers (not an offer owner)");
end;

-- Dispatch ------------------------------------------------------------------------------------

local sc = getenv("TRF_SY") or "";
local fn = getglobal("T_SY_"..strupper(sc));
print("HOST ==== survey scenario sy-"..sc.." dir="..HOST().dir);
if type(fn) == "function" then
	fn();
	HOST_Check(T_LeftGlobals() == "", "no handle globals left at the end"..T_LeftGlobals());
else
	HOST_Check(nil, "unknown survey scenario "..sc);
end;
HOST_Check((HOST().gpm_tick or 0) == 0, "no GetPlayerMotherShip from a tick (n="..tostring(HOST().gpm_tick or 0)..")");
print("HOST errors="..HOST().errors.." fails="..HOST().fails);
if HOST().errors > 0 or HOST().fails > 0 then exit(1); end;
exit(0);
