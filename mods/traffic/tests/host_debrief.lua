-- Debrief pool and the quest "Report in" scenarios (design/debrief-spec.md 11, B02) under stock Lua 4.0.1: TRF_DB=a..h,
-- run by run_host.sh as its own entry point. a registration, defaults and clamps, the texts, the pure rules (size, refill,
-- packing), the repair, the shared dialog gate, the dump; b inert with debrief_xp 0 and debrief 0, then switched on; c the
-- settlement hook at the six pay points; d the offer (gates, box 420, OK, Cancel, card, Office row, D1 and its fallbacks,
-- the files); e the quest (count, hand-in by line and by D2, the patrol dock, the lapse, the repair, the logbook, a load);
-- f the pool (draw at a patrol dock, pay at the trade dock in one call, the empty note, the caps, the waits, the points
-- lines); g the chapters (refills, bank, bands, difficulty, an off period); h db_gate 0 and the size.
-- Loads host_parcel.lua up to its first scenario (host_station.lua's prefix with the stubs of host_stubs.lua, the helpers
-- of host_traffic.lua and host_v02.lua, then the PC_* helpers). Stubs added in host_stubs.lua: the AddPlayerExperience
-- call count (HOST().xpn) and HOST_CrewPilot (GetPilot with GetPoints).

local f = openfile((getenv("TRF_TESTS") or "./").."host_parcel.lua", "r");
if not f then print("HOST FAIL host_debrief.lua: cannot open host_parcel.lua"); exit(1); end;
local src = read(f, "*a");
closefile(f);
local cut = strfind(src, "\n-- a: registration, toggles, tune, texts, pure rules, static data", 1, 1);
if not cut then print("HOST FAIL host_debrief.lua: marker '-- a: registration, toggles, ...' missing in host_parcel.lua"); exit(1); end;
dostring(strsub(src, 1, cut), "host_parcel.lua");

-- Helpers ----------------------------------------------------------------------------------

-- Config of these runs (spec 11 DB_Cfg): the pool and the quest on (debrief_xp 1), the dialogs off, charter, parcels,
-- captains (their board and informant off) and contracts on; the freight quest, temperaments, corp, warnings, remarks off;
-- the box path of the jobs UI; log 2; plus t.
function DB_Cfg(t)
	local c = {debrief=1, debrief_xp=1, db_gate=1, db_dialog=0, charter=1, enable_parcels=1, pcl_prize_gap=0, cap_enable=1, cap_board=0,
		cap_intel=0, cap_chase=0, enable_wq=0, temper=0, corp=0, warn=0, remarks=0, jobs_ui=0, log=2};
	if t then for k, v in t do c[k] = v; end; end;
	return c;
end;

-- Scenario start in sys at chapter label ch (default 5_1): the parcel world, no pool, no intro quest, NORMAL, no XP yet;
-- jl 1 installs the Job log natives first.
function DB_Begin(sys, ch, t, jl)
	local h = HOST();
	h.jl = {}; h.jl_off = nil;
	HOST_JobLogOn(jl or 0);
	h.jc = {}; h.jq = {}; h.jc_open = nil; h.jc_off = nil; h.jc_why = nil;
	TRF_MissionCard = nil; TRF_JobBoard = nil; TRF_JobBoardMark = nil;
	h.diff = NORMAL;
	PC_Begin(sys, ch or "5_1", DB_Cfg(t));
	h.xp = nil; h.xpn = nil;
	TRF.iq = nil; TRF.db = nil; TRF.claim = nil; TRF.ch = nil;
	TRF_DbKeepThunk = nil;
	TRF_DbVisit();
end;

function DB_Has(s, t) return strfind(s or "", t, 1, 1); end;
function DB_N(t) local n = 0; for k, v in t do n = n + 1; end; return n; end;

-- debrief log lines after mark n0 holding pat (plain).
function DB_Logs(n0, pat)
	local n, q = 0, HOST().logs;
	for i = n0 + 1, getn(q) do if strfind(q[i], "module=debrief ", 1, 1) and strfind(q[i], pat, 1, 1) then n = n + 1; end; end;
	return n;
end;

-- debrief log lines after n0 other than the dump and the settle lines with reason r (the inert run).
function DB_Other(n0, r)
	local n, q = 0, HOST().logs;
	for i = n0 + 1, getn(q) do
		if strfind(q[i], "module=debrief ", 1, 1) and not strfind(q[i], "event=dump ", 1, 1) and not strfind(q[i], "result=none reason="..r, 1, 1) then
			n = n + 1;
		end;
	end;
	return n;
end;

-- Every line said after the screen mark s0 joined by "|".
function DB_Scr(s0)
	local h, s = HOST(), "";
	for i = (s0 or 0) + 1, getn(h.screen) do s = s..h.screen[i].t.."|"; end;
	return s;
end;

-- The pool record as a string "ch,p,pd,n", or "nil".
function DB_Rec()
	if type(TRF.db) ~= "number" then return "nil"; end;
	local u = TRF_DbUnpack(TRF.db);
	return u.ch..","..u.p..","..u.pd..","..u.n;
end;

-- The pool opened by the quest's done bit (TRF.iq d bit 2) and synced now.
function DB_Open()
	TRF.iq = {a=0, d=2, r=0};
	TRF_DbSync("test");
end;

-- The charter office unlocked (help 3) with p paid postings (default 1).
function DB_Office(p)
	TRF.std.help = max(TRF.std.help or 0, 3);
	local C = TRF_ChUnlock("test");
	if C then C.tot.d = p or 1; end;
	return C;
end;

-- A completed posting of region slot of the current system in charter slot 1 (paid by the owed payer at a trade dock).
function DB_Posting()
	local C = DB_Office(0);
	local cur = TRF_CurIdx();
	C.g[1] = {t=1, r=TRF_RgOf(cur) or 1, f=0, d=1, k=1, p=1, w=0, a=TRF.clock.legs, e=TRF.clock.legs + 20, st=1, pay=1000, rq=1, l=1};
	C.pt = nil;
	return C;
end;

-- Trade and patrol dockings at the current location (r.scr the lines, r.nb boxes, r.box the newest).
function DB_Dock() return PC_Dock(); end;
function DB_PatDock()
	local h = HOST();
	local s0, b0 = getn(h.screen), getn(h.boxes);
	_param = GetCurrentLocation();
	__PatrolStationDock_Ok();
	local r = {scr="", nb=getn(h.boxes) - b0, s0=s0};
	for i = s0 + 1, getn(h.screen) do r.scr = r.scr..h.screen[i].t.."|"; end;
	if r.nb > 0 then r.box = h.boxes[getn(h.boxes)]; end;
	return r;
end;

-- A new visit without a jump (the visit state and the plumbing box lock start again).
function DB_Visit()
	TRF_DbVisit();
	PC_Visit();
end;

-- A parcel from Altair delivered at Taira (full, or n of 3 units; held 1: inside the shared prize gap). Returns the job
-- and the delivery docking.
function DB_Parcel(n, held)
	local h = HOST();
	if TRF_SysName(TRF_CurIdx()) ~= "altair" then T_Jump("altair"); end;
	-- A fresh parcel record (no gap after the last job), as PC_Begin.
	TRF.pcl = nil; TRF.job = nil;
	h.ms.inv = {};
	PC_Short("taira", 1);
	local J = PC_Take();
	if n then h.ms.inv[1][2] = n; end;
	if held == 1 then h.cfg.pcl_prize_gap = 1; TRF.clock.pz = TRF.clock.rs; end;
	T_Jump("taira");
	local r = PC_Dock();
	h.cfg.pcl_prize_gap = 0;
	return J, r;
end;

-- A wanted-captain claim paid (or waiting, wait 1) at a patrol dock of the current system.
function DB_Claim(wait, amt)
	local L = TRF.clock.legs;
	TRF.claim = {{slot=3, gen=7, nm=1, amt=amt or 5000, kind=1, leg=L}};
	if wait == 1 then TRF.clock.pz = TRF.clock.rs; else TRF.clock.pz = nil; end;
	return DB_PatDock();
end;

-- A sweep join pay (TRF_SweepEnd with the join contract done), the faction internals stubbed.
function DB_Sweep()
	local s = TRF_RgOf(TRF_CurIdx()) or 1;
	TRF.live.sw = {st="on", s=s, roll=1, f=1, k=1, pk=9, hit=9, nf=0, kf=0, nc=0, kc=0};
	local o = {TRF_FcH, TRF_RgCt, TRF_FcClanLeft, TRF_FcLeave, TRF_RgSweepOut, TRF_RgCtClr};
	TRF_FcH = function() return {fs={}, cs={}}; end;
	TRF_RgCt = function() return 1; end;
	TRF_FcClanLeft = function() return 0; end;
	TRF_FcLeave = function() end;
	TRF_RgSweepOut = function() end;
	TRF_RgCtClr = function() end;
	TRF_SweepEnd("test");
	TRF_FcH = o[1]; TRF_RgCt = o[2]; TRF_FcClanLeft = o[3]; TRF_FcLeave = o[4]; TRF_RgSweepOut = o[5]; TRF_RgCtClr = o[6];
	TRF.live.sw = nil;
end;

-- A fresh trader 40 from the mothership with an escort contract (TRF.live.ct); how "paid" (TRF_CtArrive near), "far"
-- (the trader 5000 away at the arrival) or "lost" (TRF_CtLost). Returns the contract.
function DB_Escort(how)
	local h = HOST();
	V_ClearTr();
	TRF.live.cbt = nil;
	TRF.live.ct = nil;
	local id = T_Spawn("C");
	if not id then id = T_Spawn(nil); end;
	T_MoveTr(id, h.ms.pos.x + 40, h.ms.pos.y, h.ms.pos.z);
	-- The contract as the hail's escort offer leaves it (trf_hail TRF.live.ct).
	TRF.live.ct = {id=id, n=1000, t=10};
	local ct = TRF.live.ct;
	if how == "lost" then TRF_CtLost(id); return ct; end;
	if how == "far" then T_MoveTr(id, h.ms.pos.x + 5000, h.ms.pos.y, h.ms.pos.z); end;
	TRF_CtArrive(id, "dock");
	return ct;
end;

-- A danger convoy n ended: paid (ok 1) or far (ok 0, far 1).
function DB_Convoy(n, how)
	if type(TRF.live.dc) ~= "table" then TRF.live.dc = {}; end;
	local dc = {id={}, a={}, st="go", n=2, ns=2, ok=1, ct=1000, e=3, m=1, k=1};
	if how == "far" then dc.ok = 0; dc.far = 1; end;
	TRF.live.dc[n] = dc;
	TRF_DcEnd(n);
end;

-- plumb settle lines after n0 of kind (result dup excluded).
function DB_Settles(n0, kind)
	local n, q = 0, HOST().logs;
	for i = n0 + 1, getn(q) do
		if strfind(q[i], "module=plumb event=settle kind="..kind.." ", 1, 1) and not strfind(q[i], "result=dup", 1, 1) then n = n + 1; end;
	end;
	return n;
end;

-- The open dialog: name, page, pilot, message text, visible answers ({} when none is open).
function DB_Dlg()
	local d = HOST().dlg;
	if not d or not d.open then return {}; end;
	return {name=d.name, cur=d.cur, pilot=HOST_DlgPilot(), text=HOST_DlgText(), vis=HOST_DlgVis()};
end;
function DB_Picks(...) for i = 1, arg.n do HOST_DlgPick(arg[i]); end; end;
function DB_DlgUi(u)
	TRF_UiState = HOST_UiState;
	HOST().ui = u or 0;
end;

function DB_Read(rel)
	local f = openfile(HOST().dir..rel, "r");
	if not f then return nil; end;
	local s = read(f, "*a");
	closefile(f);
	return s;
end;

-- Near equality of two numbers (the debrief sizes are rounded to 0.1).
function DB_Eq(a, b) return type(a) == "number" and type(b) == "number" and abs(a - b) < 1e-6; end;

-- A strict deny entry {<feature> = 0} (default debrief) for system name (TRF_DenyEntry stubbed); nil restores the original.
function DB_Deny(name, feat)
	if not DB_OrigDeny then DB_OrigDeny = TRF_DenyEntry; end;
	if not name then TRF_DenyEntry = DB_OrigDeny; DB_OrigDeny = nil; DB_DenyName = nil; DB_DenyF = nil; return; end;
	DB_DenyName = name;
	DB_DenyF = feat or "debrief";
	TRF_DenyEntry = function(n)
		if type(n) == "string" and strlower(n) == DB_DenyName then local e = {}; e[DB_DenyF] = 0; return e; end;
		return DB_OrigDeny(n);
	end;
end;

-- a: registration, defaults, texts, pure rules, repair, the dialog gate (10, 8, 7, 5.5, 5.3, 3.1, D23) -----------------

function T_DB_A()
	local h = HOST();
	DB_Begin("altair", "5_1");
	HOST_Check(S_Logs(0, "module=core event=loaded map=true module_count=18 extra_count=22") >= 1, "trf_debrief loads before trf_tips and trf_spec (extra_count=22)");
	local ml, pm, tf, uf = TRF_ModList(), TRF_PlMods(), TRF_Loc_TextFns(), TRF_UI_TextFns();
	HOST_Check(ml[getn(ml) - 2] == "Db" and pm[getn(pm)] == "Db" and tf[getn(tf) - 3] == "TRF_Db_Text" and tf[getn(tf)] == "TRF_Loc_Text"
		and uf[getn(uf) - 2] == "TRF_Db_Text" and TRF_PlCounts().stl == 1 and TRF_IqOwners()[2] == "TRF_Db_IqLapse",
		"Db last in TRF_PlMods and before Ti in TRF_ModList, TRF_Db_Text before TRF_Ti_Text in both text lists, one settlement handler, the lapse owner of quest 2");
	-- cfg and tune defaults, clamps (8).
	local d, e = TRF_Db_OptDef(), TRF_OptEnum();
	HOST_Check(d.debrief == 1 and d.debrief_xp == 0 and d.db_gate == 1 and d.db_dialog == 1 and e.debrief == 1 and e.debrief_xp == 1
		and e.db_gate == 1 and e.db_dialog == 1 and DB_Has(DB_Read("config.script"), "debrief=1, debrief_xp=0, db_gate=1, db_dialog=1"), "cfg defaults: debrief 1, debrief_xp 0 (inert), db_gate 1, db_dialog 1; enumerations 0..1; config.script ships debrief_xp 0");
	h.cfg.db_gate = 3;
	HOST_Check(TRF_DbOpt("db_gate") == 1 and TRF_DbOpt("debrief_xp") == 1, "cfg db_gate outside 0..1 reads as the default; the runs set debrief_xp 1");
	h.cfg.db_gate = nil;
	h.cfg.db_gate = 1;
	local T = TRF_DbTune();
	HOST_Check(T.db_pool == 5 and T.db_bank == 2 and T.db_shares == 1.5 and T.db_thr1 == 1.7 and T.db_thr2 == 2.8 and T.db_thr3 == 4.5 and T.db_ch == 5
		and T.db_last == 20 and T.db_help == 3 and T.db_dc == 2 and TRF_Tune().db_pool == 5, "tune defaults (10 db_* keys merged into TRF_Tune)");
	h.cfg.tune = {db_pool=12, db_bank=3, db_shares=9, db_thr1=-1, db_ch=12, db_last=8, db_help=200, db_dc=-3};
	T = TRF_DbTune();
	HOST_Check(T.db_pool == 9 and T.db_bank == 2 and T.db_shares == 4 and T.db_thr1 == 0 and T.db_ch == 12 and T.db_last == 12 and T.db_help == 99 and T.db_dc == 0,
		"tune clamps: db_bank 3 -> 2, db_last below db_ch raised to it");
	h.cfg.tune = {db_ch=3};
	HOST_Check(TRF_DbTune().db_ch == 5, "tune clamp: db_ch 3 -> 5 (the repair range 5..20)");
	h.cfg.tune = {};
	T = TRF_DbTune();
	-- Texts (7): every key plain and in TRF_Loc_EN.
	local tx, en = TRF_Db_Text(), TRF_Loc_EN();
	local bad = "";
	for k, v in tx do
		if strlen(v) >= 480 or strfind(v, "[%%#\n]") or strsub(v, 1, 1) == "#" or en[TRF_LocKey(k)] ~= v or strsub(k, 1, 2) ~= "db" then bad = bad.." "..k; end;
	end;
	HOST_Check(DB_N(tx) == 41 and bad == "", "41 text keys below 480 characters, no %, # or newline, all in TRF_Loc_EN"..bad);
	HOST_Check(TRF_Txt("dbpay1", 1, "1.8", 4) == "Debrief filed: +1.8 experience for each pilot. Debriefs left this chapter: 4."
		and TRF_Txt("dbnew", 7) == "Charter office: a new chapter, new questions. Debriefs this chapter: 7.", "text forms: the pay line, the refill line");
	-- The size of one debrief (2.1): nine cells, unknown difficulty as NORMAL, 2 shares.
	local want = {{2.2, 1.8, 1.0}, {2.9, 2.3, 1.3}, {3.9, 3.2, 1.7}};
	local chs, dfs = {5, 9, 15}, {EASY, NORMAL, HARD};
	bad = "";
	for b = 1, 3 do for j = 1, 3 do
		local x, bb = TRF_DbXpOf(chs[b], dfs[j], T);
		if not DB_Eq(x, want[b][j]) or bb ~= b then bad = bad.." "..b.."/"..j.."="..x; end;
	end; end;
	local T2 = {};
	for k, v in T do T2[k] = v; end;
	T2.db_shares = 2;
	local s1, s2, s3 = TRF_DbXpOf(5, NORMAL, T2), TRF_DbXpOf(9, NORMAL, T2), TRF_DbXpOf(13, NORMAL, T2);
	HOST_Check(bad == "" and DB_Eq(TRF_DbXpOf(6, 99, T), 1.8) and DB_Eq(TRF_DbXpOf(7, nil, T), 2.3) and DB_Eq(TRF_DbXpOf(12, NORMAL, T), 2.3)
		and DB_Eq(TRF_DbXpOf(13, NORMAL, T), 3.2) and DB_Eq(s1, 2.4) and DB_Eq(s2, 3.1) and DB_Eq(s3, 4.2),
		"debrief sizes as 2.1 (EASY/NORMAL/HARD by band, bands at 6/7 and 12/13, unknown = NORMAL; db_shares 2: 2.4/3.1/4.2)"..bad);
	-- Refill (5.3) and packing (3.1).
	HOST_Check(TRF_DbRefillOf(0, 5, 2, 1) == 5 and TRF_DbRefillOf(3, 5, 2, 1) == 8 and TRF_DbRefillOf(5, 5, 2, 1) == 10 and TRF_DbRefillOf(10, 5, 2, 1) == 10
		and TRF_DbRefillOf(0, 5, 2, 2) == 10 and TRF_DbRefillOf(9, 5, 1, 1) == 5 and TRF_DbRefillOf(0, 5, 1, 3) == 5,
		"refill: 0 -> 5, 3 -> 8, 5 -> 10, 10 -> 10, two steps from 0 -> 10, db_bank 1 always 5");
	local u = TRF_DbUnpack(TRF_DbPack(20, 18, 9, 1));
	local u0 = TRF_DbUnpack(TRF_DbPack(5, 0, 0, 0));
	HOST_Check(TRF_DbPack(20, 18, 9, 1) == 201891 and u.ch == 20 and u.p == 18 and u.pd == 9 and u.n == 1 and u0.ch == 5 and u0.p == 0 and u0.pd == 0 and u0.n == 0,
		"pack round trip at the bounds (201891)");
	TRF.db = 201891;
	HOST_Check(HOST_SaveSize(TRF.db) == 12, "TRF.db is one number: 12 bytes");
	-- Repair (3.1).
	local n0 = S_Mark();
	local cases = {{"x", "nil", "field=db result=dropped"}, {50000.5, "nil", "field=db result=dropped"}, {40500, "nil", "field=ch result=dropped"},
		{210500, "nil", "field=db result=dropped"}, {73000, "7,10,0,0", "field=p result=clamped"}, {70305, "7,3,0,0", "field=n result=clamped"},
		{70321, "7,3,2,1", nil}};
	bad = "";
	for i = 1, getn(cases) do
		local c = cases[i];
		TRF.db = c[1];
		local m = S_Mark();
		TRF_Db_Fix();
		if DB_Rec() ~= c[2] or (c[3] and DB_Logs(m, "event=fix "..c[3]) ~= 1) or (not c[3] and DB_Logs(m, "event=fix") ~= 0) then bad = bad.." "..i..":"..DB_Rec(); end;
	end;
	HOST_Check(bad == "", "repair: a string, a float, ch 4 and 21 dropped; p 30 -> 10, n 5 -> 0; a good record kept"..bad);
	-- Quest 2 in TRF.iq (3.1): s 1 with t, s 2 with t 7, s 3, an active run with the done bit: dropped.
	local qc = {{1, 3, 0, 0, "t"}, {2, 7, 0, 0, "t"}, {3, 0, 0, 0, "s"}, {1, 0, 0, 2, "done"}};
	bad = "";
	for i = 1, getn(qc) do
		TRF.iq = {a=TRF_IqPack(2, qc[i][1], qc[i][2], qc[i][3], 0), d=qc[i][4], r=0, l=TRF.clock.legs};
		local m = S_Mark();
		TRF_Db_Fix();
		if TRF_IqGet().q ~= 0 or DB_Logs(m, "event=fix field="..qc[i][5].." result=dropped") ~= 1 then bad = bad.." "..i; end;
	end;
	TRF.iq = {a=TRF_IqPack(2, 2, 3, 0, 0), d=0, r=0, l=TRF.clock.legs};
	TRF_Db_Fix();
	HOST_Check(bad == "" and TRF_IqGet().q == 2 and TRF_IqGet().t == 3, "repair of quest 2: bad step, kind, count or done bit dropped; s 2 with kind 3 kept"..bad);
	TRF.iq = nil;
	-- The shared dialog gate (D23): TRF_PlDlgWhy and the two callers answer alike.
	h.cfg.wq_dialog = 1; h.cfg.te_dialog = 1; h.cfg.db_dialog = 1; h.cfg.hail_xml = 1;
	DB_DlgUi(0);
	local gw = function(x) return tostring(TRF_PlDlgWhy(1, nil, "dock")).."/"..tostring(TRF_WqDlgWhy("dock")).."/"..tostring(TRF_TeDlgWhy()).."/"..tostring(TRF_DbDlgWhy("dock")); end;
	local r0 = gw();
	h.cfg.hail_xml = 0;
	local rx = gw();
	h.cfg.hail_xml = 1;
	local std = StartTradeDialog;
	StartTradeDialog = nil;
	local rn = gw();
	StartTradeDialog = std;
	h.ui = 4;
	local ru = gw();
	local rus = tostring(TRF_PlDlgWhy(1, nil, "space")).."/"..tostring(TRF_WqDlgWhy("space"));
	h.ui = 2;
	local ru2 = tostring(TRF_PlDlgWhy(1, nil, "dock")).."/"..tostring(TRF_PlDlgWhy(1, nil, "space"));
	h.ui = 0;
	TRF_InMovie = function() return 1; end;
	local rm = gw();
	TRF_InMovie = nil;
	h.qs = TRUE;
	local rq = gw();
	h.qs = FALSE;
	local rb = tostring(TRF_PlDlgWhy(1, {}, "dock")).."/"..tostring(TRF_PlDlgWhy(0, nil, "dock"));
	h.cfg.wq_dialog = 0; h.cfg.te_dialog = 0; h.cfg.db_dialog = 0;
	local ro = gw();
	HOST_Check(r0 == "nil/nil/nil/nil" and rx == "xml/xml/xml/xml" and rn == "native/native/native/native" and ru == "ui=4/ui=4/ui=4/ui=4"
		and rus == "ui=4/ui=4" and ru2 == "nil/ui=2" and rm == "movie/movie/movie/movie" and rq == "mission/mission/mission/mission" and rb == "busy/off"
		and ro == "nil/off/off/off", "shared dialog gate: open, xml, native, ui (dock and space), movie, mission, busy, off; trf_wq, trf_temper and trf_debrief answer the same ("
		..r0.." "..rx.." "..rn.." "..ru.." "..rus.." "..ru2.." "..rm.." "..rq.." "..rb.." "..ro..")");
	h.cfg.hail_xml = nil; h.ui = 0; TRF_UiState = nil;
	-- The dump.
	TRF.db = TRF_DbPack(7, 3, 1, 0);
	h.labels.CurrentQuest = "7_1";
	n0 = S_Mark();
	TRF_Db_Dump();
	HOST_Check(DB_Logs(n0, "event=dump on=1 xp=1 gate=1 dialog=0 chapter=7 stamp=7 pool_left=3 pending=1 refill_due=0 step=0 done=0 xp_each=2.3") == 1,
		"the dump line");
	TRF.db = nil;
end;

-- b: inert with debrief_xp 0 and debrief 0, then switched on (D14, D15) ------------------------------------------

-- Every pay point once in the current game (spec 5.1): parcel, charter (paid at a trade dock), claim, sweep, escort, danger
-- convoy.
function DB_All()
	DB_Parcel();
	DB_Posting();
	DB_Visit();
	local r = DB_Dock();
	if r.nb > 0 then PC_Press(r, "cancel"); end;
	DB_Claim();
	DB_Sweep();
	DB_Escort("paid");
	DB_Convoy(7, "paid");
end;

function T_DB_B()
	local h = HOST();
	local runs = {{{debrief_xp=0}, "xp"}, {{debrief=0}, "off"}};
	for i = 1, getn(runs) do
		DB_Begin("altair", "5_1", runs[i][1]);
		local n0 = S_Mark();
		DB_All();
		local ns = DB_Settles(n0, "parcel") + DB_Settles(n0, "charter") + DB_Settles(n0, "claim") + DB_Settles(n0, "sweep") + DB_Settles(n0, "escort");
		local bad = "";
		local chs = {"5_1", "7_1", "13_1"};
		for c = 1, 3 do
			h.labels.CurrentQuest = chs[c];
			T_Jump("altair");
			DB_Office(1);
			DB_Visit();
			local r = DB_Dock();
			if r.nb > 0 and r.box.text == TRF_Txt("dbbox") then bad = bad.." box"..c; end;
			if r.nb > 0 then PC_Press(r, "cancel"); end;
		end;
		HOST_Check(ns == 6 and TRF.db == nil and h.xp == nil and h.qlog.trf_db == nil and TRF.iq == nil and bad == "" and DB_Other(n0, runs[i][2]) == 0
			and DB_Logs(n0, "event=settle kind=parcel system=taira result=none reason="..runs[i][2]) == 1 and DB_Logs(n0, "event=dump ") >= 1,
			"inert ("..runs[i][2].."): six plumb settle lines, no record, no XP, no offer, no logbook, only dump and settle reason="..runs[i][2].." lines ("..ns..")"..bad);
	end;
	-- Switched on in the running save: the next entry, a trade dock with a paid posting offers.
	h.cfg.debrief = 1; h.cfg.debrief_xp = 1;
	T_Jump("altair");
	DB_Office(1);
	DB_Visit();
	local n0 = S_Mark();
	local r = DB_Dock();
	HOST_Check(r.nb == 1 and r.box.text == TRF_Txt("dbbox") and DB_Logs(n0, "postings=1 result=shown via=box") == 1,
		"debrief_xp 1 after the entry: the offer at the next trade dock (postings paid before count)");
	PC_Press(r, "cancel");
end;

-- c: the settlement hook (5.1) ---------------------------------------------------------------------------

function T_DB_C()
	local h = HOST();
	DB_Begin("altair", "9_1");
	DB_Open();
	local n0 = S_Mark();
	-- Parcels: full, partial, pay held by the prize gap.
	DB_Parcel();
	local a1 = DB_Settles(n0, "parcel");
	DB_Parcel(2);
	local a2 = DB_Settles(n0, "parcel");
	DB_Parcel(nil, 1);
	local a3 = DB_Settles(n0, "parcel");
	HOST_Check(a1 == 1 and a2 == 2 and a3 == 3 and S_Logs(n0, "module=plumb event=settle kind=parcel system=taira amount=14400 handler_count=1") >= 1
		and S_Logs(n0, "units=3 units_found=2 pay=9200 paid=9200") == 1 and S_Logs(n0, "module=plumb event=settle kind=parcel system=taira amount=9200 handler_count=1") == 1
		and S_Logs(n0, "module=plumb event=settle kind=parcel system=taira amount=13800 handler_count=1") == 1,
		"parcel: full, partial (2 of 3) and held (paid 0, held 13,800) each settle once with paid + held ("..a1..","..a2..","..a3..")");
	-- Charter: the posting paid by the owed payer at a trade dock.
	n0 = S_Mark();
	DB_Posting();
	DB_Visit();
	local r = DB_Dock();
	if r.nb > 0 then PC_Press(r, "cancel"); end;
	HOST_Check(DB_Settles(n0, "charter") == 1 and S_Logs(n0, "module=charter event=pay slot=1") == 1, "charter: one settle per paid posting");
	-- Claims: a claim waiting for the prize gap settles nothing; the paid one once.
	n0 = S_Mark();
	DB_Claim(1);
	local c1 = DB_Settles(n0, "claim");
	DB_Claim();
	HOST_Check(c1 == 0 and DB_Settles(n0, "claim") == 1 and S_Logs(n0, "module=plumb event=settle kind=claim system=taira amount=5000") == 1,
		"claim: none while waiting for the prize gap, one when paid");
	-- Sweep join pay.
	n0 = S_Mark();
	DB_Sweep();
	HOST_Check(DB_Settles(n0, "sweep") == 1, "sweep: the join pay settles once");
	-- Escorts: paid once; void (far) and lost none; a danger convoy paid once, dcfar none.
	n0 = S_Mark();
	local ct = DB_Escort("paid");
	local e1 = DB_Settles(n0, "escort");
	DB_Escort("far");
	DB_Escort("lost");
	local e2 = DB_Settles(n0, "escort");
	DB_Convoy(7, "paid");
	local e3 = DB_Settles(n0, "escort");
	DB_Convoy(8, "far");
	HOST_Check(ct and e1 == 1 and e2 == 1 and e3 == 2 and DB_Settles(n0, "escort") == 2, "escort: paid once, void and lost none; danger convoy paid once, dcfar none ("..e1..","..e2..","..e3..")");
	-- The same key twice in one generation: dup.
	n0 = S_Mark();
	local k1 = TRF_Settle("escort", nil, 10, "ct:test");
	local k2 = TRF_Settle("escort", nil, 10, "ct:test");
	local k3 = TRF_Settle(5, nil, 10, "x");
	HOST_Check(k1 == 1 and k2 == 0 and k3 == 0 and S_Logs(n0, "module=plumb event=settle kind=escort system=taira amount=10 key=ct:test result=dup") == 1,
		"a repeated key in the generation: result=dup, no handler; a kind that is not a string: nothing");
	T_Jump("altair");
	HOST_Check(TRF_Settle("escort", nil, 10, "ct:test") == 1, "a new generation forgets the keys");
	-- At most 16 keys kept.
	for i = 1, 17 do TRF_Settle("escort", nil, 1, "k"..i); end;
	HOST_Check(TRF_Settle("escort", nil, 1, "k1") == 1 and TRF_Settle("escort", nil, 1, "k17") == 0 and getn(TRF_PlReg().stk) == 16, "16 keys kept, the oldest dropped");
	-- trf_debrief hidden: the six callers run unchanged (no handler, handler_count=0).
	n0 = S_Mark();
	local hs = TRF_Db_Settle;
	TRF_Db_Settle = nil;
	DB_Escort("paid");
	DB_Convoy(9, "paid");
	TRF_Db_Settle = hs;
	HOST_Check(S_Logs(n0, "module=plumb event=settle kind=escort system=altair amount=") == 2 and S_Logs(n0, "handler_count=0") == 2
		and S_Logs(n0, "module=hail event=contract") >= 1, "trf_debrief hidden: the pay points pay as before, the hook runs no handler");
end;

-- d: the offer (4.5, 6.1, 6.7) ---------------------------------------------------------------------------

function T_DB_D()
	local h = HOST();
	DB_Begin("altair", "5_1");
	local cur = TRF_CurIdx();
	-- Gates of 4.5.
	local why = {};
	why.nooffice = TRF_DbOfferWhy(cur);
	DB_Office(0);
	TRF.std.help = 2;
	why.help = TRF_DbOfferWhy(cur);
	TRF.std.help = 3;
	why.posting = TRF_DbOfferWhy(cur);
	TRF.ch.tot.d = 1;
	why.ok = TRF_DbOfferWhy(cur);
	h.labels.CurrentQuest = "4_1";
	why.ch4 = TRF_DbOfferWhy(cur);
	h.labels.CurrentQuest = "19_1";
	why.ch19 = TRF_DbOfferWhy(cur);
	h.labels.CurrentQuest = "5_1";
	h.qs = TRUE;
	why.mission = TRF_DbOfferWhy(cur);
	h.qs = FALSE;
	h.cfg.charter = 0;
	why.charter = TRF_DbOfferWhy(cur);
	h.cfg.charter = 1;
	DB_Deny("altair", "charter");
	why.deny = TRF_DbOfferWhy(cur);
	DB_Deny(nil);
	DB_Deny("altair");
	why.sdeny = TRF_DbOfferWhy(cur);
	DB_Deny(nil);
	TRF_IqTake(1, 21, 1);
	why.busy = TRF_DbOfferWhy(cur);
	TRF.iq = {a=0, d=2, r=0};
	why.done = TRF_DbOfferWhy(cur);
	TRF.iq = nil;
	h.cfg.db_gate = 0;
	why.gate = TRF_DbOfferWhy(cur);
	h.cfg.db_gate = 1;
	TRF_IqDecline(2);
	why.dec = TRF_DbOfferWhy(cur);
	TRF.clock.legs = TRF.clock.legs + 2;
	why.dec2 = TRF_DbOfferWhy(cur);
	TRF.iq = nil;
	TRF_DbSH().v.dec = 1;
	why.visit = TRF_DbOfferWhy(cur);
	TRF_DbSH().v.dec = nil;
	h.cfg.debrief_xp = 0;
	why.xp = TRF_DbOfferWhy(cur);
	h.cfg.debrief_xp = 1;
	local s = "";
	local ks = {"nooffice", "help", "posting", "ok", "ch4", "ch19", "mission", "charter", "deny", "sdeny", "busy", "done", "gate", "dec", "dec2", "visit", "xp"};
	for i = 1, getn(ks) do s = s..ks[i].."="..tostring(why[ks[i]]).." "; end;
	HOST_Check(why.nooffice == "office:locked" and why.help == "help" and why.posting == "posting" and why.ok == nil and why.ch4 == "chapter"
		and why.ch19 == "office:chapter" and why.mission == "mission" and why.charter == "office:off" and why.deny == "office:strict" and why.sdeny == "strict:deny_debrief"
		and why.busy == "busy" and why.done == "done" and why.gate == "gate" and why.dec == "declined" and why.dec2 == nil and why.visit == "declined"
		and why.xp == "xp", "offer gates of 4.5: "..s);
	-- The first paid posting and the offer in the same docking; box 420 below the freight quest's 450.
	DB_Begin("altair", "5_1");
	DB_Posting();
	local n0 = S_Mark();
	local r = DB_Dock();
	HOST_Check(r.nb == 1 and r.box.text == TRF_Txt("dbbox") and S_Logs(n0, "box=db priority=420 result=box") == 1 and DB_Has(r.scr, "posting complete")
		and DB_Logs(n0, "event=offer system=altair help=4 postings=1 result=shown via=box") == 1, "the first posting paid at line 50, the offer box 420 in the same docking");
	local s0 = getn(h.screen);
	HOST_Press("ok", r.box);
	HOST_Check(TRF_IqGet().q == 2 and TRF_IqGet().s == 1 and TRF_IqGet().t == 0 and h.qlog.trf_db and h.qlog.trf_db.t == "#TRF_dbt" and h.qlog.trf_db.d == "#TRF_dbd10"
		and DB_Has(DB_Scr(s0), TRF_Txt("dbok")) and DB_Logs(n0, "event=accept system=altair leg=") == 1, "OK: TRF.iq q 2 s 1, logbook dbd10, the reply dbok");
	-- With the freight quest's offer due: it first (450), the debrief offer at the next docking.
	DB_Begin("debris6", "5_1", {enable_wq=1, enable_freight=1, fw_prize_gap=0});
	TRF.std.help = 5; TRF.co = nil; TRF.wq = nil;
	DB_Office(1);
	n0 = S_Mark();
	r = DB_Dock();
	HOST_Check(r.nb == 1 and r.box.text ~= TRF_Txt("dbbox") and S_Logs(n0, "box=wq priority=450") == 1, "freight quest offer 450 wins over 420");
	PC_Press(r, "cancel");
	DB_Visit();
	r = DB_Dock();
	HOST_Check(r.nb == 1 and r.box.text == TRF_Txt("dbbox"), "the debrief offer at the next docking");
	PC_Press(r, "cancel");
	-- Cancel: the decline stamp, none in this visit, none for 2 legs.
	DB_Begin("altair", "5_1");
	DB_Office(1);
	r = DB_Dock();
	n0 = S_Mark();
	PC_Press(r, "cancel");
	local r2 = DB_Dock();
	HOST_Check(TRF.iq and TRF.iq.l == TRF.clock.legs * 10 + 2 and DB_Logs(n0, "event=decline system=altair leg=") == 1 and (r2.nb == 0 or r2.box.text ~= TRF_Txt("dbbox")),
		"Cancel: the decline stamp, no offer again in the visit");
	if r2.nb > 0 then PC_Press(r2, "cancel"); end;
	TRF.clock.legs = TRF.clock.legs + 1;
	DB_Visit();
	r = DB_Dock();
	local no1 = r.nb == 0 or r.box.text ~= TRF_Txt("dbbox");
	if r.nb > 0 then PC_Press(r, "cancel"); end;
	TRF.clock.legs = TRF.clock.legs + 1;
	DB_Visit();
	r = DB_Dock();
	HOST_Check(no1 and r.nb == 1 and r.box.text == TRF_Txt("dbbox"), "the decline wait: none 1 leg later, the offer 2 legs later");
	PC_Press(r, "cancel");
	-- The card (jobs_ui 1): id db, header, title; OK accepts; Esc does nothing.
	DB_Begin("altair", "5_1", {jobs_ui=1});
	DB_Office(1);
	TRF_MissionCard = HOST_MissionCard;
	n0 = S_Mark();
	r = DB_Dock();
	local c = h.jc[1];
	HOST_Check(r.nb == 0 and c and c.id == "db" and c.header == "Report in" and c.title == "Charter office" and c.text == TRF_Txt("dbbox")
		and S_Logs(n0, "box=db priority=420 result=card") == 1, "card: id db, header Report in, title Charter office, the box text");
	HOST_Check(HOST_JobTick() == "open" and DB_Logs(n0, "result=shown via=card") == 1, "card open: via=card");
	HOST_JobPress("ok");
	HOST_JobTick();
	HOST_Check(TRF_IqGet().q == 2, "card OK: accepted");
	DB_Begin("altair", "5_1", {jobs_ui=1});
	DB_Office(1);
	TRF_MissionCard = HOST_MissionCard;
	n0 = S_Mark();
	r = DB_Dock();
	HOST_JobTick();
	HOST_JobPress("esc");
	HOST_JobTick();
	HOST_Check(TRF.iq == nil and DB_Logs(n0, "event=decline system=altair result=closed") == 1 and TRF_DbOfferWhy(TRF_CurIdx()) == nil, "card Esc: nothing, offered again");
	TRF_MissionCard = nil;
	-- The Office row (jobs_ui 2): the row, no box after the board was set, OK through TRF_Db_CardOk.
	DB_Begin("altair", "5_1", {jobs_ui=2});
	DB_Office(1);
	local row = TRF_Db_JobRow("trade");
	HOST_Check(row and row.id == "db" and row.header == "Report in" and row.short == TRF_Txt("dbjobs") and row.text == TRF_Txt("dbbox") and row.ok == "TRF_Db_CardOk"
		and row.no == "TRF_Db_BoxNo" and row.took == "TRF_Db_JobTook" and TRF_Db_JobTook(row.a) == nil, "Office row 420: id, header, short text, handlers");
	TRF_PlReg().jb = {k="trade", rows={}, g=TRF.gen};
	HOST_Check(TRF_Db_DockBox("trade") == nil, "no box after the board was set at this docking");
	TRF_PlReg().jb = nil;
	TRF_Db_CardOk(row.a);
	HOST_Check(TRF_IqGet().q == 2 and TRF_Db_JobTook(row.a) == 1, "row OK: taken, took answers 1");
	-- The Office row with D1 (db_dialog 1): the dialog over the board; accept, decline and Esc call the handlers directly.
	local brd = {{"a_acc2", "accept"}, {"a_dec", "decline"}, {nil, "esc"}};
	local bad = "";
	for i = 1, getn(brd) do
		DB_Begin("altair", "5_1", {db_dialog=1, hail_xml=1, jobs_ui=2});
		DB_Office(1);
		DB_DlgUi(0);
		row = TRF_Db_JobRow("trade");
		n0 = S_Mark();
		TRF_Db_CardOk(row.a);
		local ok = DB_Dlg().name == "TRF_Db1" and DB_Logs(n0, "event=dialog dialog=1 via=board result=opened") == 1 and TRF_IqGet().q == 0;
		if brd[i][1] == "a_acc2" then DB_Picks("a_what", "a_why", "a_acc2"); elseif brd[i][1] then DB_Picks("a_what", brd[i][1]); else HOST_DlgEsc(); end;
		T_Tick(4, 0.5);
		if brd[i][2] == "accept" then ok = ok and TRF_IqGet().q == 2 and DB_Logs(n0, "result=ok") == 1;
		elseif brd[i][2] == "decline" then ok = ok and TRF_IqGet().q == 0 and TRF.iq and TRF.iq.l == TRF.clock.legs * 10 + 2;
		else ok = ok and TRF.iq == nil and DB_Logs(n0, "event=decline system=altair result=closed") == 1; end;
		if not ok then bad = bad.." "..brd[i][2]; end;
	end;
	HOST_Check(bad == "", "Office row with D1 via board: accept starts the run, decline stamps, Esc closes"..bad);
	-- D1 (db_dialog 1, hail_xml 1): three pages, the tokens, accept.
	DB_Begin("altair", "5_1", {db_dialog=1, hail_xml=1});
	DB_Office(1);
	DB_DlgUi(0);
	n0 = S_Mark();
	r = DB_Dock();
	local w = DB_Dlg();
	HOST_Check(r.nb == 0 and w.name == "TRF_Db1" and w.pilot == "TRF_WqP_clerk" and w.vis == "a_what" and w.text == "FTU clerk: "..TRF_Txt("db1p1")
		and DB_Logs(n0, "result=shown via=dialog") == 1, "D1: the clerk's first page ("..tostring(w.text)..")");
	DB_Picks("a_what");
	w = DB_Dlg();
	HOST_Check(w.vis == "a_acc a_why a_dec" and DB_Has(w.text, "Call it a debrief"), "D1 page 2: accept, why, decline");
	DB_Picks("a_why");
	w = DB_Dlg();
	HOST_Check(w.vis == "a_acc2 a_dec2" and DB_Has(w.text, "old hands have their own work"), "D1 page 3");
	DB_Picks("a_acc2");
	T_Tick(2, 0.5);
	HOST_Check(TRF_IqGet().q == 2 and h.qlog.trf_db and h.qlog.trf_db.d == "#TRF_dbd10" and DB_Logs(n0, "event=dialog dialog=1 via=dock answer=acc result=done") == 1
		and h.trade_ok >= 1, "D1 accept: the run, the entry, the trade window after it");
	-- D1 decline.
	DB_Begin("altair", "5_1", {db_dialog=1, hail_xml=1});
	DB_Office(1);
	DB_DlgUi(0);
	r = DB_Dock();
	DB_Picks("a_what", "a_dec");
	T_Tick(2, 0.5);
	HOST_Check(TRF_IqGet().q == 0 and TRF.iq and TRF.iq.l == TRF.clock.legs * 10 + 2, "D1 decline: the decline stamp");
	-- D1 Esc: nothing, the offer again.
	DB_Begin("altair", "5_1", {db_dialog=1, hail_xml=1});
	DB_Office(1);
	DB_DlgUi(0);
	n0 = S_Mark();
	r = DB_Dock();
	HOST_DlgEsc();
	T_Tick(4, 0.5);
	HOST_Check(DB_Logs(n0, "event=decline system=altair result=closed") == 1 and DB_Logs(n0, "result=declined") == 0, "D1 Esc at the dock: decline result=closed, no stamp");
	DB_Visit();
	r = DB_Dock();
	HOST_Check(TRF.iq == nil and DB_Dlg().name == "TRF_Db1", "D1 Esc: no record, the offer again at the next docking");
	HOST_DlgEsc();
	T_Tick(4, 0.5);
	-- Fallbacks: db_dialog 0 (box, no fallback line), hail_xml 0, no StartTradeDialog, ui=4.
	local fb = {{{db_dialog=0, hail_xml=1}, nil}, {{db_dialog=1, hail_xml=0}, "xml"}, {{db_dialog=1, hail_xml=1}, "native"}, {{db_dialog=1, hail_xml=1}, "ui=4", '"ui=4"'}};
	bad = "";
	for i = 1, getn(fb) do
		DB_Begin("altair", "5_1", fb[i][1]);
		DB_Office(1);
		DB_DlgUi(0);
		local std = StartTradeDialog;
		if fb[i][2] == "native" then StartTradeDialog = nil; end;
		local oq = TRF_Quiet;
		if fb[i][2] == "ui=4" then h.ui = 4; TRF_Quiet = function() return nil; end; end;
		n0 = S_Mark();
		r = DB_Dock();
		StartTradeDialog = std;
		TRF_Quiet = oq;
		h.ui = 0;
		local ok = r.nb == 1 and r.box.text == TRF_Txt("dbbox");
		if fb[i][2] then ok = ok and DB_Logs(n0, "event=dialog_fallback dialog=1 reason="..(fb[i][3] or fb[i][2])) == 1; else ok = ok and DB_Logs(n0, "dialog_fallback") == 0; end;
		if not ok then bad = bad.." "..tostring(fb[i][2]); end;
		if r.nb > 0 then HOST_Press("cancel", r.box); end;
	end;
	HOST_Check(bad == "", "fallbacks: db_dialog 0, hail_xml 0, no StartTradeDialog, ui=4 give the box"..bad);
	-- The files: CRLF, ASCII, plain-text messages, the answers and tokens of TRF_DbDlgFiles, the speaker in merge/Pilots.xml.
	local px = DB_Read("../../../../merge/Pilots.xml") or "";
	local b0 = strfind(px, "<!--sw3-traffic speakers begin", 1, 1);
	local e0 = strfind(px, "<!--sw3-traffic speakers end-->", 1, 1);
	if b0 and e0 then px = strsub(px, b0, e0); else px = ""; end;
	bad = "";
	for k, fi in TRF_DbDlgFiles() do
		local raw = DB_Read("../../Trade/"..fi.f..".xml") or "";
		local x = HOST_DlgXml(fi.f);
		if raw == "" or not x then bad = bad.." "..fi.f..":missing"; else
			local _, nn = gsub(raw, "\n", "");
			local _, nc = gsub(raw, "\r\n", "");
			if nn ~= nc or strfind(raw, "[\128-\255]") or strfind(raw, "<message>#", 1, 1) then bad = bad.." "..fi.f..":format"; end;
			if getn(x.order) ~= getn(fi.an) then bad = bad.." "..fi.f..":answer_count"; end;
			local an = {};
			for i = 1, getn(fi.an) do an[fi.an[i]] = 1; end;
			for i = 1, getn(x.order) do
				local a = x.ans[x.order[i]];
				local _, _, tk = strfind(a.t or "", "^%- #(%w+)#$");
				if not an[x.order[i]] or not tk or not fi.tk[tk] then bad = bad.." "..fi.f..":"..x.order[i]; end;
				if a.fn and a.fn ~= "" and type(getglobal(a.fn)) ~= "function" then bad = bad.." "..fi.f..":"..a.fn; end;
				if a.go and a.go ~= "" and not x.pages[a.go] then bad = bad.." "..fi.f..":go"; end;
			end;
			for pn, pg in x.pages do
				local _, _, tk = strfind(pg.msg or "", "^FTU clerk: #(%w+)#$");
				if not tk or not fi.tk[tk] or pg.pilot ~= "TRF_WqP_clerk" then bad = bad.." "..fi.f..":"..pn; end;
			end;
		end;
	end;
	HOST_Check(bad == "" and DB_Has(px, '<GamePilot name="TRF_WqP_clerk">'), "dialog files: CRLF, ASCII, answers, tokens, links, the speaker TRF_WqP_clerk in the speakers block"..bad);
end;

-- e: the quest (6.2-6.5) ---------------------------------------------------------------------------------

-- "Report in" taken at step 10 with its logbook entry.
function DB_Take()
	TRF_IqTake(2, 0, 0);
	TRF_DbRcn("accept");
end;

function T_DB_E()
	local h = HOST();
	-- A parcel delivered at a trade dock: step 20 and the hand-in in the same docking (no dialog).
	DB_Begin("altair", "5_1");
	DB_Take();
	HOST_Check(h.qlog.trf_db and h.qlog.trf_db.d == "#TRF_dbd10" and TRF.db == nil, "taken: dbd10, no pool yet");
	local n0 = S_Mark();
	local J, r = DB_Parcel();
	local I = TRF_IqGet();
	HOST_Check(I.q == 0 and TRF_IqDone(2) == 1 and DB_Rec() == "5,4,0,0" and DB_Eq(h.xp, 1.8) and h.xpn == 1
		and DB_Logs(n0, "event=count kind=parcel system=taira amount=14400 result=counted") == 1 and DB_Logs(n0, "event=step step_before=10 step_after=20 reason=count") == 1
		and DB_Logs(n0, "event=done system=taira kind=1 leg=") == 1 and DB_Logs(n0, "via=line result=done") == 1
		and DB_Logs(n0, "event=pay via=quest jobs=1 xp_each=1.8 xp_total=1.8 pool_left=4 chapter=5 band=1 difficulty=normal result=paid") == 1,
		"parcel at a trade dock: counted, step 20, the hand-in at once: done, TRF.db (5,4,0,0), +1.8 in one call");
	local p0 = strfind(r.scr, "Parcel received", 1, 1);
	local p1 = strfind(r.scr, TRF_Txt("dbcnt"), 1, 1);
	local p2 = strfind(r.scr, TRF_Txt("dbrep"), 1, 1);
	local p3 = strfind(r.scr, "Debrief filed: +1.8 experience for each pilot. Debriefs left this chapter: 4.", 1, 1);
	HOST_Check(p0 and p1 and p2 and p3 and p0 < p1 and p1 < p2 and p2 < p3, "lines in order: the parcel's, dbcnt, dbrep, the pay line with 4 left ("..r.scr..")");
	HOST_Check(h.qlog.trf_db and h.qlog.trf_db.d == "#TRF_dbd30" and h.quests.trf_db == QUEST_DONE, "the entry done (dbd30)");
	-- The done entry goes 10 legs later.
	T_Jump("altair");
	HOST_Check(h.qlog.trf_db and h.qlog.trf_db.d == "#TRF_dbd30", "the done entry stays at the next entry");
	TRF.clock.legs = TRF.clock.legs + 10;
	T_Jump("taira");
	HOST_Check(h.qlog.trf_db == nil, "the done entry removed 10 legs later");
	-- With D2: the talk box 455, the job word, $2 4, the pay after the final answer.
	DB_Begin("altair", "5_1", {db_dialog=1, hail_xml=1});
	DB_DlgUi(0);
	DB_Take();
	T_Jump("taira");
	DB_Escort("paid");
	HOST_Check(TRF_IqGet().s == 2 and TRF_IqGet().t == 5 and h.qlog.trf_db.d == "#TRF_dbd20k5", "an escort in space: step 20, kind 5, dbd20k5");
	n0 = S_Mark();
	r = DB_PatDock();
	if r.nb > 0 then HOST_Press("cancel", r.box); end;
	HOST_Check(TRF_IqGet().s == 2 and DB_Logs(n0, "event=done") == 0 and h.xp == nil, "not at a patrol dock");
	DB_Visit();
	n0 = S_Mark();
	local s0 = getn(h.screen);
	r = DB_Dock();
	local w = DB_Dlg();
	HOST_Check(r.nb == 0 and w.name == "TRF_Db2" and w.text == "FTU clerk: "..TRF_Txt("db2p1", "the escort") and S_Logs(n0, "box=db_talk priority=455") == 1
		and TRF_IqGet().s == 2, "D2 at the trade dock: talk box 455, the job named");
	DB_Picks("a_go");
	w = DB_Dlg();
	HOST_Check(DB_Has(w.text, "4 left this time"), "D2 page 2: 4 left");
	DB_Picks("a_end");
	T_Tick(2, 0.5);
	HOST_Check(TRF_IqDone(2) == 1 and DB_Rec() == "5,4,0,0" and DB_Eq(h.xp, 1.8) and DB_Logs(n0, "via=dialog result=done") == 1
		and DB_Has(DB_Scr(s0), "Debriefs left this chapter: 4."), "D2 final answer: done, the first debrief paid, the line after the window");
	-- The talk box passes the dialog gate but D2 cannot open (TRF_Due refused): TRF_Db_TalkFail says the line, the done, the pay.
	DB_Begin("altair", "5_1", {db_dialog=1, hail_xml=1});
	DB_DlgUi(0);
	DB_Take();
	T_Jump("taira");
	DB_Escort("paid");
	DB_Visit();
	local due = TRF_Due;
	TRF_Due = function(dt, f, a, b) if f == "TRF_Db_DlgCheck" then return nil; end; return %due(dt, f, a, b); end;
	n0 = S_Mark();
	local t0 = h.trade_ok;
	r = DB_Dock();
	TRF_Due = due;
	local q1 = strfind(r.scr, TRF_Txt("dbrep"), 1, 1);
	local q2 = strfind(r.scr, "Debriefs left this chapter: 4.", 1, 1);
	HOST_Check(r.nb == 0 and DB_Dlg().name == nil and DB_Logs(n0, "event=dialog_fallback dialog=2 reason=due") == 1 and TRF_IqDone(2) == 1
		and DB_Rec() == "5,4,0,0" and DB_Eq(h.xp, 1.8) and DB_Logs(n0, "via=line result=done") == 1 and q1 and q2 and q1 < q2 and h.trade_ok == t0 + 1,
		"D2 cannot open: TalkFail says dbrep, the done, the pay line after it, the trade window follows ("..r.scr..")");
	-- A settlement during a mission or in a denied system: no count.
	DB_Begin("altair", "5_1");
	DB_Take();
	h.qs = TRUE;
	n0 = S_Mark();
	TRF_Settle("escort", nil, 100);
	h.qs = FALSE;
	DB_Deny("altair");
	TRF_Settle("escort", nil, 100);
	DB_Deny(nil);
	HOST_Check(TRF_IqGet().s == 1 and DB_Logs(n0, "event=count kind=escort system=altair result=none reason=mission") == 1
		and DB_Logs(n0, "event=count kind=escort system=altair result=none reason=strict:deny_debrief") == 1, "no count during a mission or in a denied system");
	-- Reconcile after ClearQuests at steps 10 and 20; a load mid-quest keeps the step.
	h.quests = {}; h.qlog = {};
	TRF_Db_OnActivate();
	HOST_Check(h.qlog.trf_db and h.qlog.trf_db.d == "#TRF_dbd10", "reconcile after ClearQuests (step 10)");
	TRF_Settle("sweep", nil, 100);
	h.quests = {}; h.qlog = {};
	TRF_Db_OnActivate();
	HOST_Check(h.qlog.trf_db and h.qlog.trf_db.d == "#TRF_dbd20k4", "reconcile after ClearQuests (step 20, the sweep)");
	n0 = S_Mark();
	T_SaveLoad();
	HOST_Check(TRF_IqGet().s == 2 and TRF_IqGet().t == 4 and DB_Logs(n0, "result=added") == 0, "a load at step 20: kept, the entry not rewritten");
	-- The lapse after 40 legs: the entry removed, the offer again.
	local l0 = TRF_IqGet().l;
	TRF.clock.legs = TRF.clock.legs + 38;
	T_Jump("taira");
	HOST_Check(TRF_IqGet().q == 2 and TRF.clock.legs - l0 == 39, "39 legs: still active");
	n0 = S_Mark();
	T_Jump("altair");
	DB_Office(1);
	HOST_Check(TRF_IqGet().q == 0 and DB_Logs(n0, "event=lapse step=20 leg=") == 1 and h.qlog.trf_db == nil and TRF_DbOfferWhy(TRF_CurIdx()) == nil,
		"40 legs without progress: lapsed, the entry removed, the offer again");
	-- The owner missing: trf_plumb lapses it.
	DB_Take();
	local lf = TRF_Db_IqLapse;
	TRF_Db_IqLapse = nil;
	TRF.clock.legs = TRF.clock.legs + 40;
	n0 = S_Mark();
	TRF_IqStale();
	TRF_Db_IqLapse = lf;
	HOST_Check(TRF_IqGet().q == 0 and S_Logs(n0, "module=plumb event=iq quest=2 step=1 target=0 count=0 result=lapsed") == 1 and DB_Logs(n0, "event=lapse") == 0,
		"without TRF_Db_IqLapse: trf_plumb lapses the run itself");
	-- The Job log (jobs_log 1 with the natives, dialogs off): the entry there and the dblog line.
	DB_Begin("altair", "5_1", {jobs_log=1}, 1);
	DB_Office(1);
	r = DB_Dock();
	s0 = getn(h.screen);
	HOST_Press("ok", r.box);
	HOST_Check(HOST_JlFind("trf_db") and h.jl[HOST_JlFind("trf_db")].d == "#TRF_dbd10" and h.qlog.trf_db == nil and DB_Has(DB_Scr(s0), TRF_Txt("dblog")),
		"jobs_log 1: the entry in the Job log, the dblog line");
end;

-- f: the pool (5.2, 5.4, 5.6, 6.6) -----------------------------------------------------------------------

function T_DB_F()
	local h = HOST();
	DB_Begin("taira", "7_1");
	DB_Open();
	HOST_Check(DB_Rec() == "7,5,0,0", "pool opened by the done bit in chapter 7: (7,5,0,0)");
	HOST_CrewPilot("Hero", 10);
	HOST_CrewPilot("Sedoy", 4);
	HOST_CrewPilot("Validol", 2, "Neutral");
	-- A claim at a patrol dock: drawn, no line, no XP; vanilla's rescue XP alone (0.4).
	local ie = InitExpForSaved;
	InitExpForSaved = function(p) saved_expirience = 0.4; _current_location_COP = p; end;
	local n0 = S_Mark();
	local r = DB_Claim();
	InitExpForSaved = ie;
	HOST_Check(DB_Rec() == "7,4,1,0" and DB_Eq(h.xp, 0.4) and h.xpn == 1 and not DB_Has(r.scr, "Debrief")
		and DB_Logs(n0, "event=settle kind=claim system=taira amount=5000 pool_left=4 pending=1 result=drawn") == 1 and DB_Logs(n0, "event=pay") == 0,
		"claim at a patrol dock: drawn, no line, only vanilla's 0.4 there");
	-- The next trade dock pays 2.3 in one call; points before and after.
	DB_Visit();
	n0 = S_Mark();
	r = DB_Dock();
	HOST_Check(DB_Rec() == "7,4,0,0" and DB_Eq(h.xp, 2.7) and h.xpn == 2 and DB_Has(r.scr, "Debrief filed: +2.3 experience for each pilot. Debriefs left this chapter: 4.")
		and DB_Logs(n0, "event=pay via=dock jobs=1 xp_each=2.3 xp_total=2.3 pool_left=4 chapter=7 band=2 difficulty=normal result=paid") == 1
		and DB_Logs(n0, "event=points at=before pilot=Hero points=10.400") == 1 and DB_Logs(n0, "event=points at=after pilot=Hero points=12.700") == 1
		and DB_Logs(n0, "event=points at=after pilot=Sedoy points=6.700") == 1 and DB_Logs(n0, "pilot=Validol") == 0,
		"the trade dock pays 2.3 in one call; points lines before and after (crew on the player side)");
	-- Three settlements before a trade dock: one call of 3 x 2.3, dbpayn.
	TRF_Settle("escort", nil, 10);
	TRF_Settle("sweep", nil, 10);
	TRF_Settle("parcel", nil, 10);
	local x0, c0 = h.xp, h.xpn;
	DB_Visit();
	r = DB_Dock();
	HOST_Check(DB_Rec() == "7,1,0,0" and h.xpn == c0 + 1 and DB_Eq(h.xp - x0, 6.9) and DB_Has(r.scr, "Debrief filed: 3 jobs, +6.9 experience for each pilot. Debriefs left this chapter: 1."),
		"three settlements: one call of 6.9, dbpayn");
	-- The last debrief: dbpay1e, the empty note.
	TRF_Settle("escort", nil, 10);
	DB_Visit();
	n0 = S_Mark();
	r = DB_Dock();
	HOST_Check(DB_Rec() == "7,0,0,0" and DB_Has(r.scr, TRF_Txt("dbpay1e", 1, "2.3", 0)) and h.qlog.trf_db and h.qlog.trf_db.t == "#TRF_dbet" and h.qlog.trf_db.d == "#TRF_dbed"
		and DB_Logs(n0, "text=#TRF_dbed quest_state_before=") == 1, "the last debrief: dbpay1e, the empty note trf_db");
	-- A settlement with nothing left: reason=empty, no line.
	n0 = S_Mark();
	local s0 = getn(h.screen);
	TRF_Settle("claim", nil, 10);
	HOST_Check(DB_Rec() == "7,0,0,0" and DB_Logs(n0, "event=settle kind=claim system=taira result=none reason=empty") == 1 and DB_Scr(s0) == "", "empty pool: reason=empty, no line");
	-- pd at 9: pending_cap.
	TRF.db = TRF_DbPack(7, 5, 9, 0);
	n0 = S_Mark();
	TRF_Settle("claim", nil, 10);
	HOST_Check(DB_Rec() == "7,5,9,0" and DB_Logs(n0, "reason=pending_cap") == 1, "nine pending: reason=pending_cap");
	-- A trade dock during a mission or a visible scene: wait, paid at the next.
	TRF.db = TRF_DbPack(7, 4, 1, 0);
	x0 = h.xp;
	h.qs = TRUE;
	n0 = S_Mark();
	TRF_Db_TradeLine("trade");
	h.qs = FALSE;
	local oq = TRF_Quiet;
	TRF_Quiet = function() return 1; end;
	TRF_Db_TradeLine("trade");
	TRF_Quiet = oq;
	HOST_Check(DB_Rec() == "7,4,1,0" and h.xp == x0 and DB_Logs(n0, "result=wait reason=mission") == 1 and DB_Logs(n0, "result=wait reason=quiet") == 1,
		"a trade dock in a mission or a scene: the debrief waits");
	-- No draw during a mission.
	h.qs = TRUE;
	n0 = S_Mark();
	TRF_Settle("escort", nil, 10);
	h.qs = FALSE;
	HOST_Check(DB_Rec() == "7,4,1,0" and DB_Logs(n0, "reason=mission") == 1, "no draw during a story mission");
	-- AddPlayerExperience missing: the debrief stays pending (one line per visit).
	local ax = AddPlayerExperience;
	AddPlayerExperience = nil;
	n0 = S_Mark();
	TRF_Db_TradeLine("trade");
	TRF_Db_TradeLine("trade");
	AddPlayerExperience = ax;
	HOST_Check(DB_Rec() == "7,4,1,0" and DB_Logs(n0, "result=wait reason=native") == 1, "no AddPlayerExperience: pending kept, logged once");
	local l = TRF_Db_TradeLine("trade");
	HOST_Check(DB_Rec() == "7,4,0,0" and getn(l) == 1 and DB_Eq(h.xp, x0 + 2.3), "paid at the next trade dock");
	-- A pirate dock and a patrol dock: no line.
	HOST_Check(TRF_Db_TradeLine("patrol") == nil and TRF_Db_TradeLine("pir") == nil, "patrol and pirate docks: no debrief line");
end;

-- g: chapters (5.3, 5.5, D15) -----------------------------------------------------------------------------

function T_DB_G()
	local h = HOST();
	DB_Begin("taira", "5_1");
	DB_Open();
	TRF.db = TRF_DbPack(5, 1, 0, 0);
	-- 5 -> 6 at the entry: p 1 -> 6, n 1; dbnew at the next trade dock, not at a patrol dock.
	h.labels.CurrentQuest = "6_1";
	local n0 = S_Mark();
	T_Jump("altair");
	HOST_Check(DB_Rec() == "6,6,0,1" and DB_Logs(n0, "event=refill chapter_before=5 chapter_after=6 carried=1 pool_before=1 pool_left=6 via=enter result=refilled") == 1,
		"chapter 5 -> 6 at the entry: p 1 -> 6, the line due");
	local r = DB_PatDock();
	if r.nb > 0 then HOST_Press("cancel", r.box); end;
	HOST_Check(DB_Rec() == "6,6,0,1" and not DB_Has(r.scr, "new chapter"), "no dbnew at a patrol dock");
	r = DB_Dock();
	if r.nb > 0 then PC_Press(r, "cancel"); end;
	local r2 = DB_Dock();
	if r2.nb > 0 then PC_Press(r2, "cancel"); end;
	HOST_Check(DB_Rec() == "6,6,0,0" and DB_Has(r.scr, TRF_Txt("dbnew", 6)) and not DB_Has(r2.scr, "new chapter"), "dbnew once at the next trade dock");
	-- 6 -> 7 with p 6: 10 (the bank cap).
	h.labels.CurrentQuest = "7_1";
	T_Jump("taira");
	HOST_Check(DB_Rec() == "7,10,0,1", "chapter 6 -> 7 with 6 left: 10 (bank of 2 pools)");
	-- 7 -> 9 in one step: two refills, still 10.
	TRF.db = TRF_DbPack(7, 0, 0, 0);
	h.labels.CurrentQuest = "9_1";
	n0 = S_Mark();
	T_Jump("altair");
	HOST_Check(DB_Rec() == "9,10,0,1" and DB_Logs(n0, "chapter_before=7 chapter_after=9 carried=5 pool_before=0 pool_left=10") == 1, "chapter 7 -> 9: two refills from 0 = 10");
	-- 20 -> 21: no refill, no draw; pending still paid.
	TRF.db = TRF_DbPack(20, 3, 1, 0);
	h.labels.CurrentQuest = "21_1";
	T_Jump("taira");
	n0 = S_Mark();
	TRF_Settle("escort", nil, 10);
	local x0 = h.xp or 0;
	local l = TRF_Db_TradeLine("trade");
	HOST_Check(DB_Rec() == "20,3,0,0" and DB_Logs(n0, "reason=chapter_end") == 1 and DB_Eq((h.xp or 0) - x0, 3.2), "chapter 21: no refill, no draw, the pending debrief paid (3.2)");
	-- A lower chapter label: clamped.
	TRF.db = TRF_DbPack(9, 3, 0, 0);
	h.labels.CurrentQuest = "8_1";
	n0 = S_Mark();
	T_Jump("altair");
	HOST_Check(DB_Rec() == "8,3,0,0" and DB_Logs(n0, "event=fix field=ch chapter=8 result=clamped") == 1, "a lower chapter label: the stamp clamped");
	-- A label below db_ch (a bad read gives 0): nothing; the next good read of the same chapter no refill.
	TRF.db = TRF_DbPack(9, 3, 0, 0);
	h.labels.CurrentQuest = "x";
	n0 = S_Mark();
	T_Jump("taira");
	HOST_Check(DB_Rec() == "9,3,0,0" and DB_Logs(n0, "event=fix") == 0, "a chapter read below db_ch: the stamp kept");
	h.labels.CurrentQuest = "9_1";
	n0 = S_Mark();
	T_Jump("altair");
	HOST_Check(DB_Rec() == "9,3,0,0" and DB_Logs(n0, "event=refill") == 0, "the next read of 9: no refill");
	-- Bands at 6/7 and 12/13; EASY and HARD.
	local xs = "";
	local labels = {"6_1", "7_1", "12_1", "13_1"};
	for i = 1, getn(labels) do h.labels.CurrentQuest = labels[i]; xs = xs..format("%.1f", TRF_Db_Xp())..","; end;
	h.diff = EASY;
	h.labels.CurrentQuest = "13_1";
	local xe = TRF_Db_Xp();
	h.diff = HARD;
	local xh = TRF_Db_Xp();
	h.diff = NORMAL;
	HOST_Check(xs == "1.8,2.3,2.3,3.2," and DB_Eq(xe, 3.9) and DB_Eq(xh, 1.7), "bands 6/7 and 12/13, EASY 3.9 and HARD 1.7 in band 3 ("..xs..")");
	-- debrief_xp 0 for chapters 8-10, then 1: one sync refills two chapters at most (cap 10), no back pay.
	h.labels.CurrentQuest = "8_1";
	TRF.db = TRF_DbPack(8, 2, 0, 0);
	h.cfg.debrief_xp = 0;
	h.labels.CurrentQuest = "10_1";
	T_Jump("taira");
	HOST_Check(DB_Rec() == "8,2,0,0", "debrief_xp 0: no sync");
	x0 = h.xp or 0;
	h.cfg.debrief_xp = 1;
	T_Jump("altair");
	HOST_Check(DB_Rec() == "10,10,0,1" and (h.xp or 0) == x0, "back on in chapter 10: two refills (cap 10), no back pay");
	-- A load keeps TRF.db.
	T_SaveLoad();
	HOST_Check(DB_Rec() == "10,10,0,1", "a load keeps TRF.db");
end;

-- h: db_gate 0, the size (O4, 3.3) ----------------------------------------------------------------------

function T_DB_H()
	local h = HOST();
	DB_Begin("altair", "4_1", {db_gate=0});
	T_Jump("taira");
	HOST_Check(TRF.db == nil, "db_gate 0 in chapter 4: no pool");
	h.labels.CurrentQuest = "5_1";
	local n0 = S_Mark();
	T_Jump("altair");
	DB_Office(1);
	HOST_Check(DB_Rec() == "5,5,0,1" and DB_Logs(n0, "event=refill chapter_after=5 pool_left=5 via=enter result=opened") == 1 and TRF_DbOfferWhy(TRF_CurIdx()) == "gate",
		"db_gate 0: the pool at the first entry in chapter 5 (5,5,0,1), no quest offer");
	local r = DB_Dock();
	HOST_Check(DB_Has(r.scr, TRF_Txt("dbnew", 5)) and (r.nb == 0 or r.box.text ~= TRF_Txt("dbbox")) and DB_Rec() == "5,5,0,0", "dbnew at the first trade dock, no offer box");
	if r.nb > 0 then PC_Press(r, "cancel"); end;
	TRF_Settle("escort", nil, 10);
	HOST_Check(DB_Rec() == "5,4,1,0" and TRF.iq == nil, "draws without the quest");
	-- The size: TRF.db at its widest, the full state of this run.
	TRF.db = TRF_DbPack(20, 18, 9, 1);
	local size = 8 + 3 + HOST_SaveSize(TRF);
	print("HOST info TRF save size (debrief run) "..size.." bytes, db="..HOST_SaveSize(TRF.db));
	HOST_Check(HOST_SaveSize(TRF.db) == 12 and size < 100000, "TRF.db 12 bytes at its widest; full state "..size.." < 100000");
end;

-- Dispatch ------------------------------------------------------------------------------------

local sc = getenv("TRF_DB") or "";
local fn = getglobal("T_DB_"..strupper(sc));
print("HOST ==== debrief scenario db-"..sc.." dir="..HOST().dir);
if type(fn) == "function" then
	fn();
	HOST_Check(T_LeftGlobals() == "", "no handle globals left at the end"..T_LeftGlobals());
else
	HOST_Check(nil, "unknown debrief scenario "..sc);
end;
HOST_Check((HOST().gpm_tick or 0) == 0, "no GetPlayerMotherShip from a tick (n="..tostring(HOST().gpm_tick or 0)..")");
print("HOST errors="..HOST().errors.." fails="..HOST().fails);
if HOST().errors > 0 or HOST().fails > 0 then exit(1); end;
exit(0);
