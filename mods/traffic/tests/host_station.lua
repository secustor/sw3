-- Station voices scenarios (design/station-voices-spec.md 13) under stock Lua 4.0.1: TRF_STN=a..f, run by
-- run_host.sh as its own entry point. a install, b moods, c gates, d standing, e fees, f identity and save.
-- host_stubs.lua routes TRF_SCEN to the other scenario files, so this file loads its stubs and helpers only:
-- the text before the line "if H.scen then" (H1), then host_traffic.lua and host_v02.lua for T_Begin,
-- T_Enter, T_Jump, T_SaveLoad, T_Tick, V_Logs, V_Idx (H2, scenario "v1-stn": both skip their dispatch).
-- Stubs here: the DockStation.script parts the module wraps (_NoneStation_Action as vanilla, the dock array,
-- __Wait_Action reduced to the dispatch), SetNormalTimeMode (counter HOST().ntm), CreatePilot recording the
-- speaker template (HOST().spk).

-- H1: stubs and helpers of host_stubs.lua.
local f = openfile((getenv("TRF_TESTS") or "./").."host_stubs.lua", "r");
if not f then print("HOST FAIL host_station.lua: cannot open host_stubs.lua"); exit(1); end;
local src = read(f, "*a");
closefile(f);
local cut = strfind(src, "\nif H.scen then", 1, 1);
if not cut then print("HOST FAIL host_station.lua: marker 'if H.scen then' missing in host_stubs.lua"); exit(1); end;
dostring(strsub(src, 1, cut), "host_stubs.lua");

-- H2: the helpers of host_traffic.lua and host_v02.lua.
HOST().scen = "v1-stn";
HOST().spk = {};
HOST().ntm = 0;
dofile(HOST().tests.."host_traffic.lua");
dofile(HOST().tests.."host_v02.lua");

-- Stubs ------------------------------------------------------------------------------------

function SetNormalTimeMode() HOST().ntm = HOST().ntm + 1; end;

S_CreatePilot0 = CreatePilot;
function CreatePilot(tpl)
	tinsert(HOST().spk, tostring(tpl));
	return S_CreatePilot0(tpl);
end;

-- DockStation.script 98-158 (dock array, __Wait_Action reduced to the dispatch: N is an argument) and
-- 677-748 (_NoneStation_Action, vanilla).
function S_DockSrc()
	return [[
__system_Dock_array = {};
__system_Dock_current = 0;
function __Wait_Action(N)
	__system_Dock_current = N;
	if N > 0 then
		local func = __system_Dock_array[N][1];
		local param = __system_Dock_array[N][3];
		local st = __system_Dock_array[N][5];
		if (func ~= "") and (st ~= nil) and (st:IsAlive()) then
			m_func = getglobal(func);
			m_func(param);
		end;
	end;
end;
function _NoneStation_Action(param)
	local _tab_dlg_pilots = {
		{"0","#L_Dnone_univ_msg","DialogSystem"},
		{"1","#L_Dnone_live_msg","DialogSystem"},
		{"2","#L_Dnone_closed_msg","DialogSystem"},
		{"3","#L_Dnone_war_closed_msg","DialogSystem"},
		{"3_vks","#L_Dnone_war_closed_VKS_msg","DispetcherVKS"},
		{"3adm","#L_Dnone_adm_closed_msg","DialogSystem"},
		{"4","#L_Dnone_private_msg","DialogSystem"},
		{"4uss","#L_Dnone_private_uss_msg","USSDispetcher"},
		{"4tri","#L_Dnone_private_tri_msg","TriadaDispetcher"},
		{"4ino","#L_Dnone_private_ino_msg","InocoDispetcher"},
		{"4rebel","#L_Dnone_private_rebel_msg","DispetcherRebel"},
		{"5","#L_Dnone_other_msg","None"},
		{"5other","#L_Dnone_other_closed_msg","DialogSystem"},
		{"pirate","#L_Dnone_pirate_msg","PirateTough"}};
	local _tmp_dlg = "";
	local _tmp_pilot = "DialogSystem";
	local val = {};
	for i, val in _tab_dlg_pilots do
		if (val[1] == param) then
			_tmp_dlg = val[2];
			_tmp_pilot = val[3];
		end;
	end;
	StationSpeaker = CreatePilot(_tmp_pilot);
	SetNormalTimeMode();
	if (_tmp_dlg ~= "") then
		StationSpeaker:Message(_tmp_dlg, 15);
	else
		StationSpeaker:Message(param, 15);
	end;
end;
]];
end;

S_Includes0 = HOST_Includes;
function HOST_Includes()
	S_Includes0();
	dostring(S_DockSrc(), "DATA/Scripts/include/DockStation.script");
end;

-- Helpers ----------------------------------------------------------------------------------

-- Config: the repo defaults (v1 features on) plus t.
function S_Cfg(t)
	local c = {exp=0, log=1, traffic=1};
	if t then for k, v in t do c[k] = v; end; end;
	HOST().cfg = c;
end;

function S_Begin(sys, t)
	local h = HOST();
	S_Cfg(t);
	h.logs = {};
	h.credits = 100000;
	HOST_Includes();
	if type(Location_SideList) == "table" then for k, v in Location_SideList do h.teams[k] = v; end; end;
	T_Begin(sys);
end;

-- A new visit without an entry (no leg, same TRF.ve): the visit flags of SV start again.
function S_NewVisit()
	local sv = TRF_StnSV();
	sv.g = {}; sv.p = {}; sv.c = {}; sv.nw = {}; sv.up = {}; sv.dn = {}; sv.pl = {}; sv.nd = {};
	sv.mis = nil; sv.rt = nil; sv.k = nil; sv.box = nil;
	if type(TRF.live) == "table" then TRF.live.line = nil; end;
end;

-- 1 when a screen line after index s0 equals text.
function S_Screen(s0, text)
	local q = HOST().screen;
	for i = s0 + 1, getn(q) do if q[i].t == text then return 1; end; end;
	return nil;
end;

-- Mod log lines matching pat (plain) after mark n0 (getn(HOST().logs) earlier).
function S_Mark() return getn(HOST().logs); end;
function S_Logs(n0, pat)
	local n, q = 0, HOST().logs;
	for i = n0 + 1, getn(q) do if strfind(q[i], pat, 1, 1) then n = n + 1; end; end;
	return n;
end;
-- Last mod log line matching pat after n0, or "".
function S_Line(n0, pat)
	local q, r = HOST().logs, "";
	for i = n0 + 1, getn(q) do if strfind(q[i], pat, 1, 1) then r = q[i]; end; end;
	return r;
end;

-- Dock array as CreateDocking fills it: the map trade stations of the current system first (param prm or
-- ""), then the closed stations of none = {{tip, x, y, z}, ...} and extra trade docks of extra =
-- {{param, x, y, z}, ...}. Returns {trade = {N...}, none = {N...}, extra = {N...}}.
function S_Setup(none, extra)
	local m = TRF_Map();
	local s = m.sys[TRF_CurIdx()];
	local rows, o = {}, {trade={}, none={}, extra={}};
	local add = function(func, param, x, y, z, label)
		local ob = HOST_Obj(label, x, y, z);
		ob.id = 7000 + getn(%rows);
		tinsert(%rows, {func, Vector3(x + 40, y, z), param, 5, ob});
		return getn(%rows);
	end;
	for i = 1, getn(s.st or {}) do
		local e = s.st[i];
		if e.kind == "trade" then tinsert(o.trade, add("__TradeStation_Action", e.prm or "", e.x, e.y, e.z, e.label)); end;
	end;
	for i = 1, getn(none or {}) do
		local e = none[i];
		tinsert(o.none, add("_NoneStation_Action", e[1], e[2] or 0, e[3] or 0, e[4] or 900, "NONE"..i));
	end;
	for i = 1, getn(extra or {}) do
		local e = extra[i];
		tinsert(o.extra, add("__TradeStation_Action", e[1], e[2], e[3], e[4], "EXTRA"..i));
	end;
	__system_Dock_array = rows;
	return o;
end;

function S_Approach(N) __Wait_Action(N); end;

-- Closed-station approach: messages sent, last text, last speaker, SetNormalTimeMode calls.
function S_None(N)
	local h = HOST();
	local m0, n0 = getn(h.msgs), h.ntm;
	S_Approach(N);
	local q = h.msgs;
	local last = q[getn(q)] or {};
	return {n=getn(q) - m0, t=last.t, spk=h.spk[getn(h.spk)], ntm=h.ntm - n0};
end;

-- Trade approach: boxes opened, the box, radio lines, screen lines (texts joined by "|").
function S_Trade(N)
	local h = HOST();
	local b0, m0, s0 = getn(h.boxes), getn(h.msgs), getn(h.screen);
	S_Approach(N);
	local r = {nb=getn(h.boxes) - b0, nm=getn(h.msgs) - m0, ns=getn(h.screen) - s0, scr="", msg=""};
	if r.nb > 0 then r.box = h.boxes[getn(h.boxes)]; end;
	for i = m0 + 1, getn(h.msgs) do r.msg = r.msg..h.msgs[i].t.."|"; end;
	for i = s0 + 1, getn(h.screen) do r.scr = r.scr..h.screen[i].t.."|"; end;
	r.spk = h.spk[getn(h.spk)];
	return r;
end;

function S_Vanilla(r) return r.nb == 1 and r.box.text == "#UI_TradeStationDockRequest"; end;

-- Region record of the current system's slot and the station key of map station j.
function S_Rg() return TRF.rg[TRF_RgOf(TRF_CurIdx())]; end;
function S_Key(j) return TRF_Stn_Key(TRF_CurIdx(), j or 1); end;

-- Entry of a fresh visit with the fixture: chapter label, pro of the current system.
function S_Visit(sys, ch, pro)
	local h = HOST();
	h.labels.CurrentQuest = ch;
	T_Enter(sys);
	if pro then TRF_SetPro(TRF_CurIdx(), pro); end;
end;

-- Runs f with a mod log that records but does not count ERROR lines (expected errors); returns their number.
function S_Expect(f)
	local lg = TRF_Log;
	TRF_Log = function(s)
		tinsert(HOST().logs, s);
		print("traffic: lua: "..tostring(s).." (expected)");
	end;
	local n0 = S_Mark();
	f();
	TRF_Log = lg;
	return S_Logs(n0, " ERROR ");
end;

-- a: install (12.1, 6.1) ---------------------------------------------------------------------

function T_STN_A()
	local h = HOST();
	S_Begin("gaoba");
	HOST_Check(V_Logs("stn: install none=1 trade=1 mine=1/1") >= 1, "install: both wrapped, mine=1/1");
	local src = function(f) return getinfo(f, "S").source or ""; end;
	local van = function()
		return strfind(%src(TRF_orig_NoneSt), "DockStation.script", 1, 1) and strfind(%src(TRF_orig_TradeSt), "DockStation.script", 1, 1);
	end;
	HOST_Check(TRF_StnIsMine(_NoneStation_Action) and TRF_StnIsMine(__TradeStation_Action) and van(),
		"install: thunks are mine, originals are the vanilla chunk's");
	local r = TRF_InstallStation();
	HOST_Check(r.none == 0 and r.trade == 0, "install again without an include: no double wrap");
	-- voice 0: both pass, vanilla line and box.
	local D = S_Setup({{"1"}});
	h.cfg.voice = 0;
	local n0 = S_Mark();
	local a = S_None(D.none[1]);
	local b = S_Trade(D.trade[1]);
	HOST_Check(a.n == 1 and a.t == "#L_Dnone_live_msg" and a.spk == "DialogSystem" and a.ntm == 1 and S_Vanilla(b)
		and S_Logs(n0, "stn: pass reason=off sys=gaoba at=none") == 1 and S_Logs(n0, "stn: pass reason=off sys=gaoba at=dock") == 1,
		"voice 0: vanilla line DialogNone_live (DialogSystem) and the vanilla box");
	HOST_Press("cancel");
	h.cfg.voice = nil;
	-- voice 1: exactly one Message and one box per approach; OK reaches trf_shop's wrapper and vanilla.
	n0 = S_Mark();
	local ok0 = h.trade_ok;
	a = S_None(D.none[1]);
	b = S_Trade(D.trade[1]);
	HOST_Check(a.n == 1 and a.ntm == 1 and S_Logs(n0, "stn: none sys=gaoba(42) tip=1") <= 1 and S_Vanilla(b)
		and S_Logs(n0, "stn: dock k=42 ") == 1, "voice 1: one Message, one box, dock line");
	HOST_Press("ok");
	HOST_Check(h.trade_ok == ok0 + 1 and S_Logs(n0, "stn: docked k=42 up=0") == 1, "OK: trf_shop wrapper (docked line) and vanilla dock");
	-- Every MapInitialization installs again over the fresh vanilla originals.
	local o1, o2 = TRF_orig_NoneSt, TRF_orig_TradeSt;
	n0 = S_Mark();
	T_Enter("gaoba");
	HOST_Check(TRF_orig_NoneSt ~= o1 and TRF_orig_TradeSt ~= o2 and van() and TRF_StnIsMine(_NoneStation_Action)
		and S_Logs(n0, "stn: install none=1 trade=1 mine=1/1") == 1, "entry: installed again over the new originals");
	o1 = TRF_orig_NoneSt;
	n0 = S_Mark();
	T_SaveLoad();
	HOST_Check(TRF_orig_NoneSt ~= o1 and van() and TRF_StnIsMine(__TradeStation_Action) and S_Logs(n0, "stn: install none=1 trade=1 mine=1/1") >= 1
		and S_Logs(n0, "stn: load latch=0") == 1, "load: installed again, load line");
	D = S_Setup({{"1"}});
	a = S_None(D.none[1]);
	HOST_Check(a.n == 1 and a.ntm == 1, "after load: one Message per approach");
	-- Error in the mood body: vanilla line and an ERROR line, no script error.
	local mo = TRF_StnMoodOf;
	a = {};
	TRF_StnMoodOf = function(s) error("injected"); end;
	n0 = S_Mark();
	local ne = S_Expect(function() local t = %a; t.r = S_None(%D.none[1]); end);
	a = a.r;
	TRF_StnMoodOf = mo;
	HOST_Check(a.n == 1 and a.t == "#L_Dnone_live_msg" and ne == 1 and S_Logs(n0, "stn: pass reason=error") == 1,
		"error in the body: vanilla line, one ERROR line ("..ne..")");
	-- Error in the dock body: vanilla box.
	local to = TRF_StnTradeBody;
	TRF_StnTradeBody = function(p) error("injected"); end;
	b = {};
	ne = S_Expect(function() local t = %b; t.r = S_Trade(%D.trade[1]); end);
	b = b.r;
	TRF_StnTradeBody = to;
	HOST_Check(S_Vanilla(b) and ne == 1, "error in the dock body: vanilla box");
	HOST_Press("cancel");
end;

-- b: moods (5) ---------------------------------------------------------------------------------

-- Fixture reset: Quiet, no disruption, no shortage, no heat, no owner change, no sweep, clan tier 1.
function S_MoodReset(sl0)
	local h = HOST();
	local idx = TRF_CurIdx();
	local r = S_Rg();
	r.ph = 0;
	r.sl = sl0;
	TRF.clan[TRF_RgOf(idx)].sc = 0;
	TRF_SetDis(idx, 0);
	TRF.short = {};
	TRF.std.heat = 0;
	TRF.vo = {};
	h.cfg.voice_force = nil;
end;

function T_STN_B()
	local h = HOST();
	S_Begin("gaoba", {log=2});
	local idx = TRF_CurIdx();
	local slot = TRF_RgOf(idx);
	local sl0 = S_Rg().sl;
	local tips = {"0", "1", "3adm", "5other", "4ino", "pirate", "5", "3", "3_vks", "2", "quest_dialog"};
	local none = {};
	for i = 1, getn(tips) do tinsert(none, {tips[i], 100 * i, 0, 900}); end;
	local D = S_Setup(none);
	local N = {};
	for i = 1, getn(tips) do N[tips[i]] = D.none[i]; end;
	-- Expected vanilla text of a key.
	local tx = {};
	tx["0"] = "#L_Dnone_univ_msg"; tx["1"] = "#L_Dnone_live_msg"; tx["2"] = "#L_Dnone_closed_msg";
	tx["3"] = "#L_Dnone_war_closed_msg"; tx["3_vks"] = "#L_Dnone_war_closed_VKS_msg"; tx["3adm"] = "#L_Dnone_adm_closed_msg";
	tx["4ino"] = "#L_Dnone_private_ino_msg"; tx["5"] = "#L_Dnone_other_msg"; tx["5other"] = "#L_Dnone_other_closed_msg";
	tx["pirate"] = "#L_Dnone_pirate_msg"; tx["quest_dialog"] = "quest_dialog";
	local bad = {s=""};
	-- want: {tip -> key or "=text" for a variant} under the current fixture; spk optional {tip -> template}.
	local case = function(name, want, spk)
		for tip, k in want do
			local a = S_None(%N[tip]);
			local t = %tx[k];
			if strsub(k, 1, 1) == "=" then t = TRF_Txt(strsub(k, 2)); end;
			local okk = a.n == 1 and a.ntm == 1 and a.t == t;
			if spk and spk[tip] and a.spk ~= spk[tip] then okk = nil; end;
			if not okk then %bad.s = %bad.s.." "..name..":"..tip.."->"..tostring(a.t).."/"..tostring(a.spk).."/n"..a.n.."/ntm"..a.ntm; end;
		end;
	end;
	-- row 8: vanilla everywhere.
	S_MoodReset(0);
	local v8 = {};
	for i = 1, getn(tips) do v8[tips[i]] = tips[i]; end;
	case("r8", v8);
	-- row 0: debug key for every class, never for a quest dialog key.
	h.cfg.voice_force = "2";
	case("r0", {["0"]="2", pirate="2", ["5"]="2", ["4ino"]="2", quest_dialog="quest_dialog"});
	S_MoodReset(0);
	-- row 2: sweep open with the system owner as sweep owner.
	local own = TRF_FacTeam(TRF_SweepOwner(slot));
	h.teams.gaoba = own;
	S_Rg().sl = TRF.clock.legs;
	local k3 = "3";
	if own == "Vks" then k3 = "3_vks"; end;
	case("r2sw", {["0"]=k3, ["5other"]=k3, ["4ino"]=k3, pirate="pirate", ["5"]="5", ["3_vks"]="3_vks"});
	HOST_Check(own ~= nil, "fixture: sweep owner of gaoba's region is a faction ("..tostring(own)..")");
	h.teams.gaoba = "Inoco";
	S_MoodReset(0);
	-- row 3: disruption 7.
	TRF_SetDis(idx, 7);
	case("r3", {["0"]="5", ["1"]="5", ["5other"]="=stndepot", ["4ino"]="4ino", pirate="pirate", ["2"]="2"},
		{["5other"]="DialogSystem", ["0"]="None"});
	h.cfg.voice_moods = 1;
	case("r3m1", {["5other"]="5"});
	h.cfg.voice_moods = nil;
	S_MoodReset(0);
	-- row 4: raids at disruption 5.
	S_Rg().ph = 3; TRF_SetDis(idx, 5);
	case("r4", {["0"]="2", ["3adm"]="2", ["1"]="1", ["5other"]="5other", pirate="pirate", ["3"]="3"});
	S_MoodReset(0);
	-- row 5: bust; pirate den dead at clan tier 1, vanilla at tier 2.
	S_Rg().ph = 4;
	case("r5", {["0"]="1", ["3adm"]="1", ["4ino"]="4ino", pirate="=stnpirdead", ["5"]="5"}, {pirate="None"});
	TRF.clan[slot].sc = 30;
	case("r5t2", {pirate="pirate"});
	S_MoodReset(0);
	-- row 5 by a shortage.
	tinsert(TRF.short, {s=idx, c=1, t=TRF.clock.legs + 5});
	case("r5sh", {["0"]="1"});
	S_MoodReset(0);
	-- row 6: recovery.
	S_Rg().ph = 5;
	case("r6", {["1"]="0", ["3adm"]="0", pirate="=stnpirdead", ["5other"]="5other"});
	S_MoodReset(0);
	-- row 7: boom.
	S_Rg().ph = 1;
	case("r7", {["0"]="3adm", ["1"]="1", ["3adm"]="3adm", pirate="pirate"});
	S_MoodReset(0);
	-- row 7b: friendly den at heat 5 (voice_moods 2 only).
	TRF.std.heat = 5;
	TRF.clan[slot].sc = 30;
	case("r7b", {pirate="=stnpirheat", ["0"]="0"}, {pirate="PirateTough"});
	h.cfg.voice_moods = 1;
	case("r7bm1", {pirate="pirate"});
	h.cfg.voice_moods = 0;
	local n0 = S_Mark();
	case("off", {pirate="pirate", ["0"]="0"});
	HOST_Check(S_Logs(n0, "stn: pass reason=off") == 1, "voice_moods 0: moods pass");
	h.cfg.voice_moods = nil;
	S_MoodReset(sl0);
	HOST_Check(bad.s == "", "mood rows 0-8 and 7b, one Message and one SetNormalTimeMode per approach"..bad.s);
	-- Pure rows not reachable with this fixture: USS martial law, provider.
	local T = TRF_StnTune();
	local k, ru, v = TRF_StnMoodOf({tip="0", dis=0, sw=1, own="Uss", tier=1, heat=0, moods=2, t=T});
	local k2, ru2, v2 = TRF_StnMoodOf({tip="1", dis=0, prov="4", own="Neutral", tier=1, heat=0, moods=2, t=T});
	local k3, ru3 = TRF_StnMoodOf({tip="pirate", dis=0, prov="4", tier=1, heat=0, moods=2, t=T});
	HOST_Check(k == "3" and ru == "2" and v == "stnmluss" and k2 == "4" and ru2 == "1" and v2 == nil and k3 == "pirate" and ru3 == "8",
		"pure: USS martial law variant, provider row (not for pirates)");
	-- Owner change: hafa now Vks (static Inoco) -> 3_vks for own_legs legs, recorded once.
	h.teams.hafa = "Vks";
	n0 = S_Mark();
	T_Enter("hafa");
	local hi = TRF_CurIdx();
	local vo = TRF.vo[hi];
	D = S_Setup({{"0"}});
	local a = S_None(D.none[1]);
	HOST_Check(vo == TRF.ve and S_Logs(n0, "stn: owner sys=hafa static=Inoco now=Vks vo=") == 1 and a.t == "#L_Dnone_war_closed_VKS_msg"
		and a.spk == "DispetcherVKS", "owner change hafa: TRF.vo set, martial law 3_vks");
	TRF.clock.legs = TRF.clock.legs + 20;
	T_Enter("hafa");
	S_Rg().ph = 0;
	D = S_Setup({{"0"}});
	a = S_None(D.none[1]);
	HOST_Check(TRF.vo[hi] == vo and S_Logs(n0, "stn: owner ") == 1 and a.t == "#L_Dnone_univ_msg", "after own_legs legs: vanilla again, vo kept");
	-- moscowia now Kfni (static Vks): New Empire martial law variant with its speaker.
	h.teams.moscowia = "Kfni";
	T_Enter("moscowia");
	D = S_Setup({{"0"}, {"5"}});
	a = S_None(D.none[1]);
	local b = S_None(D.none[2]);
	HOST_Check(a.t == TRF_Txt("stnmlkfni") and a.spk == "DispetcherKFNI" and a.ntm == 1 and b.t == "#L_Dnone_other_msg",
		"owner change moscowia: stnmlkfni by DispetcherKFNI, silent key unchanged");
	h.cfg.voice_moods = 1;
	a = S_None(D.none[1]);
	HOST_Check(a.t == "#L_Dnone_war_closed_msg", "voice_moods 1: vanilla key 3");
	h.cfg.voice_moods = nil;
end;

-- c: gates (4) ----------------------------------------------------------------------------------

function T_STN_C()
	local h = HOST();
	S_Begin("gaoba", {log=2});
	local D = nil;
	-- One pass: closed station "0" and the trade station both vanilla with the reason line.
	local pass = function(why, sys)
		local D = S_Setup({{"0"}}, {{"", 5000, 0, 5000}});
		local n0 = S_Mark();
		local a = S_None(D.none[1]);
		local b = S_Trade(D.trade[1] or D.extra[1]);
		HOST_Press("cancel");
		local ok = a.t == "#L_Dnone_univ_msg" and S_Vanilla(b) and b.nm == 0 and S_Logs(n0, "stn: dock ") == 0
			and S_Logs(n0, "stn: pass reason="..why.." sys="..sys.." at=none") == 1 and S_Logs(n0, "stn: pass reason="..why.." sys="..sys.." at=dock") == 1;
		HOST_Check(ok, "gate "..why.." in "..sys..": vanilla line and box");
	end;
	T_Enter("elio"); pass("deny", "elio");
	-- nk is a campaign teleport target (tq): with no nk quest in process G3 lets it through, the voice list closes it.
	T_Enter("nk"); pass("vdeny", "nk");
	T_Enter("x203"); pass("vdeny", "x203");
	-- G3 transit rule: taira (teleport target, tq), no taira quest in process: moods and greeting run.
	T_Enter("taira");
	local Dt = S_Setup({{"0"}});
	local t0 = S_Mark();
	local at = S_None(Dt.none[1]);
	local bt = S_Trade(Dt.trade[1]);
	HOST_Press("cancel");
	HOST_Check(S_Logs(t0, "stn: pass") == 0 and S_Logs(t0, "stn: none sys=taira(") == 1 and S_Logs(t0, "stn: dock k="..TRF_CurIdx().." ") == 1
		and at.n >= 1 and bt.nb >= 1, "transit: taira without a taira quest in process: mood line and dock line");
	-- A quest naming taira in process: deny_tq on both paths; elio (authored) stays deny.
	h.quests.quest_6c_01 = QUEST_PROCESS;
	T_Enter("taira"); pass("deny_tq", "taira");
	h.quests.quest_6c_01 = nil;
	-- A mission active, no taira quest in process (chapter 9, so the fee rule F4 holds): G3 passes and the visit
	-- latch (G6) only stops the fee: mood line, dock line with the greeting, nofee=latch and its pass line.
	local cq0 = h.labels.CurrentQuest;
	h.labels.CurrentQuest = "9_01";
	h.qs = TRUE; T_Enter("taira");
	TRF_SetPro(TRF_CurIdx(), 8); TRF.std.heat = 0;
	TRF_Stn_Deed(TRF_CurIdx(), 1, "test", nil, 2);
	Dt = S_Setup({{"0"}});
	t0 = S_Mark();
	bt = S_Trade(Dt.trade[1]);
	HOST_Press("cancel");
	at = S_None(Dt.none[1]);
	local dl = S_Line(t0, "stn: dock k=");
	HOST_Check(S_Logs(t0, "stn: none sys=taira(") == 1 and at.n >= 1 and strfind(dl, "m=1 nofee=latch", 1, 1) and strfind(dl, "greet=stnr1 ", 1, 1)
		and S_Vanilla(bt) and S_Logs(t0, "stn: pass reason=latch sys=taira at=dock") == 1 and S_Logs(t0, "at=none") == 0
		and TRF_StnSV().mis == 1, "transit: taira during a mission: mood, greeting, nofee=latch ("..dl..")");
	-- The mission ends in the same visit: the latch still stops the fee; the next entry charges again.
	h.qs = FALSE;
	t0 = S_Mark();
	bt = S_Trade(Dt.trade[1]);
	HOST_Press("cancel");
	HOST_Check(S_Vanilla(bt) and S_Logs(t0, "nofee=latch") == 1, "mission ended in the same visit: the latch still stops the fee");
	T_Jump("taira");
	TRF_SetPro(TRF_CurIdx(), 8);
	Dt = S_Setup({});
	t0 = S_Mark();
	bt = S_Trade(Dt.trade[1]);
	HOST_Press("cancel");
	HOST_Check(bt.nb == 1 and bt.box.text ~= "#UI_TradeStationDockRequest" and S_Logs(t0, "nofee=-") == 1,
		"next entry: latch cleared, fee box");
	h.labels.CurrentQuest = cq0;
	T_Enter("elio"); pass("deny", "elio");
	T_Enter("gaoba");
	__disableAction = TRUE; pass("flag", "gaoba"); __disableAction = FALSE;
	h.rel_team = {["Trade|PlayerTeam"] = RELATION_WAR};
	T_Enter("gaoba"); pass("trade_war", "gaoba");
	h.rel_team = nil;
	-- Quest id of the system in process: gate:quest, and the dock gate latches the visit.
	h.quests["quest_7a"] = QUEST_PROCESS;
	T_Enter("kadenoa"); pass("gate:quest", "kadenoa");
	HOST_Check(TRF_StnSV().mis == 1, "gate:quest at the dock sets the visit latch");
	h.quests["quest_7a"] = nil;
	-- Story mission active in a never-named system: the latch is set, moods and the dock line run (gaoba: m 0).
	T_Enter("gaoba");
	h.qs = TRUE;
	D = S_Setup({{"0"}});
	local n0 = S_Mark();
	local a = S_None(D.none[1]);
	local b = S_Trade(D.trade[1]);
	HOST_Press("cancel");
	h.qs = FALSE;
	HOST_Check(TRF_StnSV().mis == 1 and S_Logs(n0, "stn: pass") == 0 and S_Logs(n0, "stn: none sys=gaoba(") == 1
		and S_Logs(n0, "stn: dock k=42 ") == 1 and S_Vanilla(b), "story mission in gaoba: latch set, mood and dock lines");
	T_Jump("gaoba");
	HOST_Check(TRF_StnSV().mis == nil, "next entry: latch cleared");
	-- voice_gate 2 (light gate): a mission_q denial changes moods but not the dock; the dock latches.
	h.cfg.voice_gate = 2;
	T_Enter("gaoba");
	TRF.std.heat = 0;
	local so = TRF_StrictOk;
	TRF_StrictOk = function(idx, feat) return nil, "mission_q"; end;
	D = S_Setup({{"0"}});
	n0 = S_Mark();
	a = S_None(D.none[1]);
	local an = S_Logs(n0, "stn: pass");
	b = S_Trade(D.trade[1]);
	HOST_Press("cancel");
	local a2 = S_None(D.none[1]);
	TRF_StrictOk = so;
	HOST_Check(an == 0 and S_Logs(n0, "stn: pass reason=gate:mission_q sys=gaoba at=dock") == 1 and S_Vanilla(b)
		and TRF_StnSV().mis == 1 and S_Logs(n0, "stn: pass reason=latch") == 0 and S_Logs(n0, "stn: none sys=gaoba(") == 2 and a2.n >= 1,
		"voice_gate 2: moods open under mission_q, dock denied and latched, moods stay open after the latch");
	h.cfg.voice_gate = nil;
	-- voice_gate 1: the same denial closes the moods.
	T_Enter("gaoba");
	TRF_StrictOk = function(idx, feat) return nil, "mission_q"; end;
	D = S_Setup({{"0"}});
	n0 = S_Mark();
	a = S_None(D.none[1]);
	TRF_StrictOk = so;
	HOST_Check(S_Logs(n0, "stn: pass reason=gate:mission_q sys=gaoba at=none") == 1, "voice_gate 1: mission_q closes the moods");
	-- strict 0: the dock is open, but no fee (stn-e checks the fee).
	h.cfg.strict = 0;
	T_Enter("gaoba");
	D = S_Setup({});
	n0 = S_Mark();
	b = S_Trade(D.trade[1]);
	HOST_Press("cancel");
	HOST_Check(S_Logs(n0, "stn: dock k=42 ") == 1, "strict 0: dock line (gate open)");
	h.cfg.strict = nil;
	-- G1: TRF_Traffic() false.
	T_Enter("gaoba");
	local tf = TRF_Traffic;
	TRF_Traffic = function() return nil; end;
	pass("off", "gaoba");
	TRF_Traffic = tf;
	-- G4: the suppression level (TRF_Supp() ~= 0); G4b: quiet (TRF_Quiet: __sys_SOS or a visible scene), no
	-- mood, greeting or fee box, the vanilla box runs. sos_mode 2: __sys_SOS raises the level (flag).
	T_Enter("gaoba");
	__sys_SOS = TRUE; pass("quiet", "gaoba"); __sys_SOS = FALSE;
	T_Enter("gaoba");
	-- A movie raises the level too (TRF_Supp 1), so G4 reports it first.
	TRF_InMovie = HOST_InMovie; h.mov = 1;
	pass("flag", "gaoba");
	TRF_InMovie = nil; h.mov = nil;
	T_Enter("gaoba");
	h.cfg.sos_mode = 2;
	__sys_SOS = TRUE; pass("flag", "gaoba"); __sys_SOS = FALSE;
	h.cfg.sos_mode = nil;
	T_Enter("gaoba");
	local su = TRF_Supp;
	TRF_Supp = function() return 1; end;
	pass("flag", "gaoba");
	TRF_Supp = su;
	-- G7: voice_gate 2 still closes the moods for quest and deny_voice.
	h.cfg.voice_gate = 2;
	local gws = {"quest", "deny_voice"};
	for i = 1, getn(gws) do
		local w = gws[i];
		T_Enter("gaoba");
		TRF_StrictOk = function(idx, feat) return nil, %w; end;
		pass("gate:"..w, "gaoba");
		TRF_StrictOk = so;
	end;
	h.cfg.voice_gate = nil;
	-- G9: sys_off, and the start-system guard (first start system with a trade station and no deny entry,
	-- chapter 3): vanilla, no greeting, news, tip or record.
	h.cfg.sys_off = {"gaoba"};
	T_Enter("gaoba"); pass("mode:sys_off", "gaoba");
	h.cfg.sys_off = nil;
	local gs = nil;
	local ms = TRF_Map().sys;
	for i = 1, getn(ms) do
		local de = TRF_DenyEntry(ms[i].name);
		if not gs and ms[i].start == 1 and getn(TRF_StnTl(i)) > 0 and not (type(de) == "table" and de.m == 1) then gs = ms[i].name; end;
	end;
	HOST_Check(gs ~= nil, "fixture: a start system with a trade station ("..tostring(gs)..")");
	local cq = h.labels.CurrentQuest;
	h.labels.CurrentQuest = "3_01";
	T_Enter(gs); pass("mode:guard", gs);
	HOST_Check(TRF.stn == nil or TRF.stn[TRF_Stn_Key(TRF_CurIdx(), 1)] == nil, "guard: no record written");
	h.labels.CurrentQuest = "5_01";
	T_Enter(gs);
	D = S_Setup({});
	n0 = S_Mark();
	b = S_Trade(D.trade[1]);
	HOST_Press("cancel");
	HOST_Check(S_Logs(n0, "stn: dock k="..TRF_CurIdx().." ") == 1, gs.." at chapter 5: guard off, dock line");
	h.labels.CurrentQuest = cq;
	-- G10: the current dock row is not __TradeStation_Action: reason=row, vanilla box.
	T_Enter("gaoba");
	D = S_Setup({});
	__system_Dock_array[D.trade[1]][1] = "QuestDock";
	__system_Dock_current = D.trade[1];
	n0 = S_Mark();
	local nb0 = getn(h.boxes);
	TRF_Stn_Trade("");
	HOST_Check(getn(h.boxes) == nb0 + 1 and h.boxes[getn(h.boxes)].text == "#UI_TradeStationDockRequest"
		and S_Logs(n0, "stn: pass reason=row sys=gaoba at=dock") == 1, "G10: row of another function: reason=row, vanilla box");
	HOST_Press("cancel");
	T_Enter("gaoba");
	-- Unknown system: nomap.
	local loc0 = h.loc;
	h.loc = "nowhere";
	HOST_Check(TRF_CurIdx() == nil, "fixture: unknown system");
	local n1 = S_Mark();
	__system_Dock_array = {};
	local o = HOST_Obj("Q", 0, 0, 0);
	__system_Dock_array[1] = {"__TradeStation_Action", Vector3(0, 0, 0), "", 5, o};
	b = S_Trade(1);
	HOST_Press("cancel");
	h.loc = loc0;
	HOST_Check(S_Vanilla(b) and S_Logs(n1, "stn: pass reason=nomap") == 1, "unknown system: nomap");
end;

-- d: standing (7, 8.2-8.4) ----------------------------------------------------------------------

function T_STN_D()
	local h = HOST();
	h.labels.CurrentQuest = "9_01";
	S_Begin("gaoba");
	local idx = TRF_CurIdx();
	local k = S_Key(1);
	local sp = TRF_Map().sys[idx].st[1];
	local ms = function(d) HOST().ms.pos = Vector3(%sp.x + d, %sp.y, %sp.z); end;
	S_Rg().ph = 2;
	local st = function() local e = TRF.stn[%k]; if e then return e.st; end; return 0; end;
	ms(500);
	local n0 = S_Mark();
	TRF_AddHelp(1, "contract");
	TRF_AddHelp(1, "sesc");
	HOST_Check(st() == 1 and S_Logs(n0, "stn: deed k=42 d=+1 why=contract st=0->1 cap=-") == 1
		and S_Logs(n0, "stn: deed k=42 d=0 why=sesc st=1->1 cap=gv") == 1, "gain +1, second gain in the visit capped (gv)");
	T_SaveLoad();
	n0 = S_Mark();
	TRF_AddHelp(1, "dc");
	HOST_Check(st() == 1 and S_Logs(n0, "cap=gv") == 1, "after a load: no second gain in the same visit");
	T_Enter("gaoba");
	ms(4000);
	n0 = S_Mark();
	TRF_AddHelp(1, "raid 3");
	ms(1000);
	TRF_AddHelp(1, "raid 3");
	HOST_Check(st() == 2 and S_Logs(n0, "why=raid 3 st=1->1 cap=far dist=4000") == 1 and S_Logs(n0, "d=+1 why=raid 3 st=1->2 cap=- dist=1000") == 1,
		"raid deed only within stn_near of the station");
	T_Enter("gaoba");
	n0 = S_Mark();
	TRF_Stn_Deed(idx, 1, "test", nil, 2);
	TRF_AddHelp(1, "join");
	HOST_Check(st() == 2 and S_Logs(n0, "why=test st=2->2 cap=ceil") == 1, "ceiling respected");
	local h0 = TRF.std.heat;
	n0 = S_Mark();
	TRF_AddHeat(1, "kill 7");
	TRF_AddHeat(1, "attack 7");
	TRF_AddHeat(1, "demand 7");
	TRF_AddHeat(-1, "contract");
	HOST_Check(st() == 0 and S_Logs(n0, "d=-1 why=kill 7 st=2->1") == 1 and S_Logs(n0, "d=-1 why=attack 7 st=1->0") == 1
		and S_Logs(n0, "why=demand 7 st=0->0 cap=dn") == 1, "losses: at most two per visit");
	TRF.std.heat = 0;
	-- Lazy decay: 4 -> 2 after 24 legs.
	TRF.stn[k] = {st=4, lg=TRF.clock.legs};
	for i = 1, 24 do TRF_AddLeg("test"); end;
	local s1, e1 = TRF_Stn_Rung(idx, 1);
	TRF.std.heat = 5;
	local s5, e5 = TRF_Stn_Rung(idx, 1);
	TRF.std.heat = 7;
	local s7, e7 = TRF_Stn_Rung(idx, 1);
	TRF.std.heat = 0;
	HOST_Check(s1 == 2 and e1 == 2 and e5 == 0 and e7 == -2, "decay 2 rungs after 24 legs; heat 5 caps e at 0, heat 7 at -2");
	-- Greetings by rung, speaker by owner (gaoba: Inoco).
	h.teams.gaoba = "Inoco";
	local bad = "";
	local gks = {"stnrm3", "stnrm2", "stnrm1", "", "stnr1", "stnr2", "stnr3", "stnr4", "stnr5"};
	for s = -3, 5 do
		T_Enter("gaoba");
		TRF.stn[k] = {st=s, lg=TRF.clock.legs};
		local D = S_Setup({});
		local r = S_Trade(D.trade[1]);
		if r.nb > 0 then HOST_Press("cancel"); end;
		local want = "";
		if s ~= 0 then want = TRF_Txt(gks[s + 4]).."|"; end;
		if r.msg ~= want or (s ~= 0 and r.spk ~= "InocoDispetcher") then bad = bad.." "..s..":"..r.msg.."/"..tostring(r.spk); end;
		local r2 = S_Trade(D.trade[1]);
		if r2.nb > 0 then HOST_Press("cancel"); end;
		if r2.nm ~= 0 then bad = bad.." "..s..":again"; end;
	end;
	HOST_Check(bad == "", "greeting per rung, InocoDispetcher, once per visit"..bad);
	-- News at e >= 2 from chapter 4, once per visit.
	local news = function(ch, s)
		HOST().labels.CurrentQuest = ch;
		T_Enter("gaoba");
		TRF_SetDis(V_Idx("lidau"), 5);
		TRF.stn[%k] = {st=s, lg=TRF.clock.legs};
		local D = S_Setup({});
		local r = S_Trade(D.trade[1]);
		if r.nb > 0 then HOST_Press("cancel"); end;
		local r2 = S_Trade(D.trade[1]);
		if r2.nb > 0 then HOST_Press("cancel"); end;
		return r, r2;
	end;
	local r3 = news("3_01", 2);
	local r4, r4b = news("4_01", 2);
	local r1 = news("4_01", 1);
	HOST_Check(not strfind(r3.scr, "Harbour news", 1, 1) and strfind(r4.scr, "Harbour news: ", 1, 1) and r4b.ns == 0
		and not strfind(r1.scr, "Harbour news", 1, 1), "news only at e >= 2 from chapter 4, once per visit");
	-- Ambient lines by chapter at e 1 (no news).
	local amb = "";
	local chs = {"3_01", "6_01", "8_01", "10_01", "12_01"};
	for i = 1, getn(chs) do
		local r = news(chs[i], 1);
		local a = "-";
		if strfind(r.scr, TRF_Txt("stnamb1"), 1, 1) then a = "1"; end;
		if strfind(r.scr, TRF_Txt("stnamb2"), 1, 1) then a = "2"; end;
		if strfind(r.scr, TRF_Txt("stnamb3"), 1, 1) then a = "3"; end;
		amb = amb..a;
	end;
	HOST_Check(amb == "1-23-", "ambient lines for ch 0-5, 7-9, 10-11 only ("..amb..")");
	-- Supply-run tip at e >= 4, then the convoy killed: -3 and the tip ban until the region is Quiet.
	h.labels.CurrentQuest = "9_01";
	T_Enter("gaoba");
	S_Rg().ph = 2;
	S_Rg().sl = 0;
	TRF.feq = {k=1, f=1, s=idx, r=1, t=TRF.clock.legs};
	TRF.stn[k] = {st=4, lg=TRF.clock.legs};
	local D = S_Setup({});
	n0 = S_Mark();
	local r = S_Trade(D.trade[1]);
	if r.nb > 0 then HOST_Press("cancel"); end;
	HOST_Check(strfind(r.scr, TRF_Txt("stntipfeq", "gaoba"), 1, 1) and TRF.stn[k].ts == idx and TRF.stn[k].tf == TRF.clock.legs
		and S_Logs(n0, "stn: tip k=42 kind=feq sys=gaoba") == 1, "supply-run tip at e 4 records tf/ts");
	n0 = S_Mark();
	TRF_AddHeat(1, "feq kill");
	TRF.std.heat = 0;
	HOST_Check(TRF.stn[k].st == -3 and TRF.stn[k].nt == 1 and TRF.stn[k].tf == nil and S_Logs(n0, "stn: rob k=42 st=-3 nt=1") == 1,
		"feq kill: the tipping station sets -3 and the tip ban");
	S_NewVisit();
	r = S_Trade(D.trade[1]);
	if r.nb > 0 then HOST_Press("cancel"); end;
	HOST_Check(r.msg == TRF_Txt("stntiprob").."|", "greeting after the rob: stntiprob");
	S_NewVisit();
	TRF.stn[k].st = 4;
	r = S_Trade(D.trade[1]);
	if r.nb > 0 then HOST_Press("cancel"); end;
	HOST_Check(not strfind(r.scr, "supply run", 1, 1) and TRF.stn[k].nt == 1, "tip ban: no tip while the region is not Quiet");
	S_NewVisit();
	S_Rg().ph = 0;
	TRF.stn[k].st = 4;
	r = S_Trade(D.trade[1]);
	if r.nb > 0 then HOST_Press("cancel"); end;
	HOST_Check(TRF.stn[k].nt == nil and strfind(r.scr, "supply run", 1, 1), "region Quiet: ban cleared, tip again");
	TRF.feq = nil;
	-- Tip order (8.3): an announced sweep before the supply run; a pirate base when neither exists.
	local slot = TRF_RgOf(idx);
	T_Enter("gaoba");
	S_Rg().ph = 2;
	S_Rg().sl = TRF.clock.legs + 3;
	TRF.feq = {k=1, f=1, s=idx, r=1, t=TRF.clock.legs};
	TRF.stn[k] = {st=4, lg=TRF.clock.legs};
	D = S_Setup({});
	n0 = S_Mark();
	r = S_Trade(D.trade[1]);
	if r.nb > 0 then HOST_Press("cancel"); end;
	local tsw = TRF_Txt("stntipsweep", TRF_SweepInfo(slot).fac, TRF_ClanName(slot), TRF_StnName(TRF_RgMap()[slot].home));
	HOST_Check(strfind(r.scr, tsw, 1, 1) and not strfind(r.scr, "supply run", 1, 1) and TRF.stn[k].tf == nil
		and S_Logs(n0, "stn: tip k=42 kind=sweep") == 1, "sweep tip first, before the supply run");
	TRF.feq = nil;
	local base0 = TRF.base;
	T_Enter("gaoba");
	S_Rg().ph = 2;
	S_Rg().sl = 0;
	TRF.base = {{s=idx, k=2, h=9, t=0, w=0}};
	TRF.stn[k] = {st=4, lg=TRF.clock.legs};
	D = S_Setup({});
	n0 = S_Mark();
	r = S_Trade(D.trade[1]);
	if r.nb > 0 then HOST_Press("cancel"); end;
	TRF.base = base0;
	HOST_Check(strfind(r.scr, TRF_Txt("stntipbase", TRF_StnName(idx)), 1, 1) and S_Logs(n0, "stn: tip k=42 kind=base sys=gaoba") == 1,
		"base tip without sweep and supply run");
	-- Radio spacing (stn_gap): a greeting within 6 s of another TRF line waits for the next approach.
	T_Enter("gaoba");
	TRF.stn[k] = {st=1, lg=TRF.clock.legs};
	TRF.live.line = TRF.clock.gt - 2;
	D = S_Setup({});
	n0 = S_Mark();
	r = S_Trade(D.trade[1]);
	if r.nb > 0 then HOST_Press("cancel"); end;
	TRF.clock.gt = TRF.clock.gt + 10;
	local rg2 = S_Trade(D.trade[1]);
	if rg2.nb > 0 then HOST_Press("cancel"); end;
	HOST_Check(r.nm == 0 and S_Logs(n0, "greet=stnr1(gap)") == 1 and rg2.msg == TRF_Txt("stnr1").."|",
		"radio spacing: greeting skipped inside stn_gap, sent on the next approach");
	-- parked kill: -1.
	T_Enter("gaoba");
	TRF.stn[k] = {st=2, lg=TRF.clock.legs};
	n0 = S_Mark();
	TRF_AddHeat(1, "parked kill");
	TRF.std.heat = 0;
	HOST_Check(TRF.stn[k].st == 1 and S_Logs(n0, "d=-1 why=parked kill st=2->1") == 1, "parked kill: -1");
	-- Rise this visit: result line after docking.
	T_Enter("gaoba");
	TRF.stn[k] = {st=1, lg=TRF.clock.legs};
	ms(500);
	TRF_AddHelp(1, "contract");
	D = S_Setup({});
	n0 = S_Mark();
	r = S_Trade(D.trade[1]);
	local s0 = getn(h.screen);
	HOST_Press("ok");
	HOST_Check(S_Screen(s0, TRF_Txt("stnnoted")) and S_Logs(n0, "stn: docked k=42 up=1") == 1, "noted line after docking");
	-- Entry prune: st 0 entries without tf/nt are dropped.
	TRF.stn[k] = {st=0, lg=TRF.clock.legs};
	T_Enter("gaoba");
	HOST_Check(TRF.stn[k] == nil, "entry prunes rung-0 entries");
end;

-- e: fees (8.5) ----------------------------------------------------------------------------------

function T_STN_E()
	local h = HOST();
	h.labels.CurrentQuest = "4_01";
	S_Begin("kadenoa");
	h.teams.kadenoa = "Uss";
	local idx = TRF_CurIdx();
	local k = S_Key(1);
	TRF_SetPro(idx, 8);
	local D = S_Setup({});
	local r = S_Trade(D.trade[1]);
	HOST_Check(S_Vanilla(r), "chapter 4: no fee");
	HOST_Press("cancel");
	local fee = function(m) return TRF_StnFeeOf(TRF_LPay(%idx), TRF_Pro(%idx), m, TRF_DK(), 200, 10000); end;
	local want = fee(1);
	S_Visit("kadenoa", "5_01", 8);
	D = S_Setup({});
	local n0 = S_Mark();
	local cr0, ok0 = h.credits, h.trade_ok;
	r = S_Trade(D.trade[1]);
	HOST_Check(r.nb == 1 and r.box.text == TRF_Txt("stnfeehub", format("%d", want)).."\n"..TRF_Txt("stnfeereq")
		and want == floor(200 * TRF_LPay(idx) * 1.8 / 100 + 0.5) * 100, "chapter 5, pro 8: hub fee box ("..want..")");
	HOST_Press("ok");
	HOST_Check(h.credits == cr0 - want and h.trade_ok == ok0 + 1 and S_Logs(n0, "stn: docked k=51") == 1
		and S_Logs(n0, "stn: fee k=51 ok=1 cr="..cr0.."->"..(cr0 - want).." credit=0 buyback=0") == 1, "OK: paid, docked through trf_shop's wrapper");
	r = S_Trade(D.trade[1]);
	HOST_Check(S_Vanilla(r), "second approach in the visit: vanilla box");
	HOST_Press("cancel");
	-- A load inside the visit: the saved pv stops a second charge.
	T_SaveLoad();
	D = S_Setup({});
	cr0 = h.credits;
	n0 = S_Mark();
	r = S_Trade(D.trade[1]);
	HOST_Check(S_Vanilla(r) and h.credits == cr0 and TRF.stn[k].pv == TRF.ve and S_Logs(n0, "nofee=pv") == 1,
		"load in the visit after paying: no second fee");
	HOST_Press("cancel");
	-- Cancel: nothing paid, no dock, the next approach asks again.
	S_Visit("kadenoa", "5_01", 8);
	D = S_Setup({});
	cr0, ok0 = h.credits, h.trade_ok;
	r = S_Trade(D.trade[1]);
	HOST_Press("cancel");
	local r2 = S_Trade(D.trade[1]);
	HOST_Check(h.credits == cr0 and h.trade_ok == ok0 and r2.nb == 1 and r2.box.text ~= "#UI_TradeStationDockRequest", "Cancel: no charge, no dock, box again");
	HOST_Press("cancel");
	-- Quiet (__sys_SOS), then a dialog flag of TRF_UiState (level 1, reason flag): no fee box and no greeting,
	-- the vanilla box; the fee is asked once the flag is clear.
	S_Visit("kadenoa", "5_01", 8);
	D = S_Setup({});
	cr0 = h.credits;
	n0 = S_Mark();
	__sys_SOS = TRUE;
	r = S_Trade(D.trade[1]);
	__sys_SOS = FALSE;
	HOST_Check(S_Vanilla(r) and r.nm == 0 and h.credits == cr0 and S_Logs(n0, "stn: pass reason=quiet sys=kadenoa at=dock") == 1
		and S_Logs(n0, "stn: dock ") == 0, "__sys_SOS: quiet, no greeting, no fee box, vanilla box");
	HOST_Press("cancel");
	TRF_UiState = HOST_UiState; h.ui = 4;
	r = S_Trade(D.trade[1]);
	HOST_Check(S_Vanilla(r) and h.credits == cr0 and S_Logs(n0, "stn: dock ") == 0, "TRF_UiState dialog flag: quiet, no fee box");
	HOST_Press("cancel");
	h.ui = -1;
	r = S_Trade(D.trade[1]);
	HOST_Check(r.nb == 1 and r.box.text ~= "#UI_TradeStationDockRequest" and S_Logs(n0, "stn: dock k=51 ") == 1, "flag clear (UiState -1 = unknown): fee box");
	HOST_Press("cancel");
	TRF_UiState = nil; h.ui = nil;
	-- Credits below the fee: docks on credit, no charge, -1.
	S_Visit("kadenoa", "5_01", 8);
	h.credits = 100;
	D = S_Setup({});
	ok0 = h.trade_ok;
	r = S_Trade(D.trade[1]);
	HOST_Check(r.box.text == TRF_Txt("stncredit").."\n"..TRF_Txt("stnfeereq"), "credits below the fee: credit box");
	HOST_Press("ok");
	HOST_Check(h.credits == 100 and h.trade_ok == ok0 + 1 and TRF.stn[k].st == -1 and TRF_StnSV().c[k] == 1, "on credit: no charge, docks, st -1");
	T_SaveLoad();
	D = S_Setup({});
	n0 = S_Mark();
	r = S_Trade(D.trade[1]);
	HOST_Check(S_Vanilla(r) and TRF.stn[k].st == -1 and S_Logs(n0, "why=credit") == 0, "load in the visit after docking on credit: no box, no second -1");
	HOST_Press("cancel");
	h.credits = 100000;
	-- Penalty: st -2 pays double and buys back once per visit, never above -1.
	S_Visit("kadenoa", "5_01", 8);
	TRF.stn[k] = {st=-2, lg=TRF.clock.legs};
	D = S_Setup({});
	cr0 = h.credits;
	r = S_Trade(D.trade[1]);
	HOST_Check(r.box.text == TRF_Txt("stnfeepen", format("%d", fee(2))).."\n"..TRF_Txt("stnfeereq"), "st -2: penalty box x2");
	HOST_Press("ok");
	HOST_Check(h.credits == cr0 - fee(2) and TRF.stn[k].st == -1 and TRF.stn[k].bv == TRF.ve, "buy-back: -2 -> -1");
	TRF.stn[k].st = -3;
	TRF.stn[k].pv = nil;
	TRF_StnSV().p = {};
	cr0 = h.credits;
	r = S_Trade(D.trade[1]);
	HOST_Press("ok");
	HOST_Check(h.credits == cr0 - fee(3) and TRF.stn[k].st == -3, "second buy-back in the visit refused (x3 fee paid)");
	S_Visit("kadenoa", "5_01", 8);
	TRF.stn[k] = {st=-3, lg=TRF.clock.legs};
	D = S_Setup({});
	r = S_Trade(D.trade[1]);
	HOST_Press("ok");
	HOST_Check(TRF.stn[k].st == -2, "buy-back from -3: -2");
	-- Rung 3: no hub fee.
	S_Visit("kadenoa", "5_01", 8);
	TRF.stn[k] = {st=3, lg=TRF.clock.legs};
	D = S_Setup({});
	r = S_Trade(D.trade[1]);
	HOST_Check(S_Vanilla(r), "rung 3: hub fee waived");
	HOST_Press("cancel");
	TRF.stn[k] = nil;
	-- EASY: d_k 1.25.
	h.diff = EASY;
	S_Visit("kadenoa", "5_01", 8);
	D = S_Setup({});
	r = S_Trade(D.trade[1]);
	HOST_Check(r.nb == 1 and r.box.text == TRF_Txt("stnfeehub", format("%d", fee(1))).."\n"..TRF_Txt("stnfeereq") and TRF_DK() == 1.25,
		"EASY: fee with d_k 1.25 ("..fee(1)..")");
	HOST_Press("cancel");
	h.diff = NORMAL;
	-- fee_cap.
	h.cfg.tune = {fee_cap=1000};
	S_Visit("kadenoa", "5_01", 8);
	D = S_Setup({});
	r = S_Trade(D.trade[1]);
	HOST_Check(r.box.text == TRF_Txt("stnfeehub", "1000").."\n"..TRF_Txt("stnfeereq"), "fee_cap 1000");
	HOST_Press("cancel");
	h.cfg.tune = nil;
	-- F2: a story mission active: no fee (latch, G6), the dock line still runs.
	S_Visit("kadenoa", "5_01", 8);
	h.qs = TRUE;
	D = S_Setup({});
	n0 = S_Mark();
	r = S_Trade(D.trade[1]);
	HOST_Check(S_Vanilla(r) and S_Logs(n0, "nofee=latch") == 1 and S_Logs(n0, "stn: pass reason=latch sys=kadenoa at=dock") == 1,
		"story mission active: no fee (nofee=latch)");
	HOST_Press("cancel");
	h.qs = FALSE;
	-- F3: strict 0: no fee.
	h.cfg.strict = 0;
	S_Visit("kadenoa", "5_01", 8);
	D = S_Setup({});
	n0 = S_Mark();
	r = S_Trade(D.trade[1]);
	HOST_Check(S_Vanilla(r) and S_Logs(n0, "nofee=strict0") == 1, "strict 0: no fee");
	HOST_Press("cancel");
	h.cfg.strict = nil;
	-- voice_fee 0.
	h.cfg.voice_fee = 0;
	S_Visit("kadenoa", "5_01", 8);
	D = S_Setup({});
	r = S_Trade(D.trade[1]);
	HOST_Check(S_Vanilla(r), "voice_fee 0: no fee");
	HOST_Press("cancel");
	h.cfg.voice_fee = nil;
	-- Stale box after a load: OK docks, charges nothing.
	S_Visit("kadenoa", "5_01", 8);
	D = S_Setup({});
	r = S_Trade(D.trade[1]);
	T_SaveLoad();
	cr0, ok0 = h.credits, h.trade_ok;
	n0 = S_Mark();
	HOST_Press("ok", r.box);
	HOST_Check(h.credits == cr0 and h.trade_ok == ok0 + 1 and S_Logs(n0, "stn: stale box") == 1, "stale box after a load: docks, no charge");
end;

-- f: identity and save (3.3, 3.4, D4) ------------------------------------------------------------

function T_STN_F()
	local h = HOST();
	h.labels.CurrentQuest = "9_01";
	S_Begin("kadenoa");
	local idx = TRF_CurIdx();
	local D = S_Setup({}, {{"", 600, 0, 600}});
	local n0 = S_Mark();
	S_Trade(D.trade[1]); HOST_Press("cancel");
	S_Trade(D.trade[2]); HOST_Press("cancel");
	S_Trade(D.extra[1]); HOST_Press("cancel");
	HOST_Check(getn(D.trade) == 2 and S_Logs(n0, "stn: dock k=51 param= id=prm+pos d=0") == 1
		and S_Logs(n0, "stn: dock k=251 param=kadenoa_tri id=prm+pos d=0") == 1 and S_Logs(n0, "stn: pass reason=table sys=kadenoa at=dock") == 1,
		"kadenoa: keys 51 and 251 by param and position; quest dock passes");
	-- A dock with the wrong param at the other station's position: position wins.
	T_Enter("kadenoa");
	local e2 = TRF_Map().sys[idx].st[2];
	D = S_Setup({}, {{"", e2.x, e2.y, e2.z}});
	n0 = S_Mark();
	S_Trade(D.extra[1]); HOST_Press("cancel");
	HOST_Check(S_Logs(n0, "stn: idmis k=251 jp=1 jx=2") == 1 and S_Logs(n0, "stn: dock k=251 param= id=pos") == 1, "position mismatch: idmis, id=pos");
	-- Station handle whose GetPosition errors: param alone.
	T_Enter("kadenoa");
	D = S_Setup({});
	__system_Dock_array[D.trade[2]][5].GetPosition = function(self) error("dead handle"); end;
	n0 = S_Mark();
	local e0 = h.errors;
	S_Trade(D.trade[2]); HOST_Press("cancel");
	HOST_Check(h.errors == e0 and S_Logs(n0, "stn: dock k=251 param=kadenoa_tri id=prm d=-") == 1, "GetPosition error: id=prm, no error");
	-- stn_pos 0: param only.
	h.cfg.tune = {stn_pos=0};
	T_Enter("kadenoa");
	D = S_Setup({}, {{"", 600, 0, 600}});
	n0 = S_Mark();
	S_Trade(D.extra[1]); HOST_Press("cancel");
	HOST_Check(S_Logs(n0, "stn: dock k=51 param= id=prm") == 1, "stn_pos 0: param only");
	h.cfg.tune = nil;
	-- Records survive a load.
	T_Enter("kadenoa");
	TRF.stn[51] = {st=2, lg=TRF.clock.legs, gv=TRF.clock.legs};
	TRF.stn[251] = {st=-1, lg=TRF.clock.legs};
	TRF.vo = {[47]=1};
	local ve = TRF.ve;
	T_SaveLoad();
	HOST_Check(TRF.stn[51].st == 2 and TRF.stn[51].gv == TRF.clock.legs and TRF.stn[251].st == -1 and TRF.ve == ve and TRF.vo[47] == 1,
		"records, vo and ve survive the load");
	-- Repair (D4).
	local L = TRF.clock.legs;
	TRF.stn = {[51]={st=9, lg=L + 50, gv="x", bv=L + 9, pv=L + 9, tf=L, ts=9999, nt=2, junk=1}, foo={st=1}, [199]={st=1, lg=0},
		[251]={st=-7.5, lg=0, pv=L, tf=L, ts=42, nt=1}, [42]="bad"};
	TRF.vo = {[47]=1, [42]=1, [62]=L + 5};
	TRF.ve = L + 3;
	TRF_Repair();
	local a, b = TRF.stn[51], TRF.stn[251];
	local nk = 0;
	for kk, vv in TRF.stn do nk = nk + 1; end;
	HOST_Check(nk == 2 and a.st == 5 and a.lg == L and a.gv == nil and a.bv == nil and a.pv == nil and a.tf == nil and a.ts == nil and a.nt == nil and a.junk == nil
		and b.st == -3 and b.lg == 0 and b.pv == L and b.tf == L and b.ts == 42 and b.nt == 1, "Fix: clamps, drops bad keys and fields");
	HOST_Check(TRF.vo[47] == 1 and TRF.vo[42] == nil and TRF.vo[62] == nil and TRF.ve == L, "Fix: vo keys and values, ve");
	TRF.stn = "bad"; TRF.vo = 3;
	TRF_Repair();
	HOST_Check(type(TRF.stn) == "table" and type(TRF.vo) == "table", "Fix: non-table stn and vo -> {}");
	-- Size: all station keys with full records.
	local ks = TRF_StnKeys();
	local n = 0;
	TRF.stn = {};
	for kk, vv in ks do
		TRF.stn[kk] = {st=-3, lg=L, gv=L, bv=L, pv=L, tf=L, ts=42, nt=1};
		n = n + 1;
	end;
	TRF.vo = {};
	local ow = TRF_StnOwners();
	for nm, t in ow do if V_Idx(nm) then TRF.vo[V_Idx(nm)] = L; end; end;
	local ss, ts = HOST_SaveSize(TRF.stn), 8 + 3 + HOST_SaveSize(TRF);
	HOST_Check(n == 76 and ks[251] == 1 and ss <= 16000 and ts < 40000, "size: "..n.." keys, TRF.stn "..ss.." bytes, TRF "..ts.." bytes");
	HOST_Check(HOST_Reserved(TRF, "TRF") == "", "no reserved key in TRF");
	n0 = S_Mark();
	TRF_DumpState("test");
	HOST_Check(S_Logs(n0, "dump stn ve=") == 1 and S_Logs(n0, " wrapped=1/1") == 1, "dump stn line");
	-- Entry prunes nothing here (tf and nt keep the entries).
	T_Enter("kadenoa");
	local m = 0;
	for kk, vv in TRF.stn do m = m + 1; end;
	HOST_Check(m == 76, "tf/nt entries kept by the prune");
	-- D4 trim: more than 76 entries (key filter bypassed) -> the ones with the smallest lg go.
	local kf = TRF_StnKeys;
	TRF_StnKeys = function() return nil; end;
	local L0 = TRF.clock.legs;
	if TRF.clock.legs < 80 then TRF.clock.legs = 80; end;
	TRF.stn = {};
	for i = 1, 80 do TRF.stn[i] = {st=1, lg=i - 1}; end;
	TRF_Stn_Fix();
	TRF_StnKeys = kf;
	TRF.clock.legs = L0;
	local nt, low = 0, 0;
	for kk, vv in TRF.stn do nt = nt + 1; if vv.lg < 4 then low = low + 1; end; end;
	HOST_Check(nt == 76 and low == 0 and TRF.stn[5].lg == 4, "Fix: more than 76 entries, smallest lg dropped ("..nt..")");
end;

-- Dispatch (H3) ------------------------------------------------------------------------------

local sc = getenv("TRF_STN") or "";
local fn = getglobal("T_STN_"..strupper(sc));
print("HOST ==== station scenario stn-"..sc.." dir="..HOST().dir);
if type(fn) == "function" then
	fn();
	HOST_Check(T_LeftGlobals() == "", "no handle globals left at the end"..T_LeftGlobals());
else
	HOST_Check(nil, "unknown station scenario "..sc);
end;
HOST_Check((HOST().gpm_tick or 0) == 0, "no GetPlayerMotherShip from a tick (n="..tostring(HOST().gpm_tick or 0)..")");
print("HOST errors="..HOST().errors.." fails="..HOST().fails);
if HOST().errors > 0 or HOST().fails > 0 then exit(1); end;
exit(0);
