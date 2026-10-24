-- Station voices scenarios (design/station-voices-spec.md 13) under stock Lua 4.0.1: TRF_STN=a..h, run by
-- run_host.sh as its own entry point. a install, b moods, c gates, d standing, e fees, f identity and save,
-- g station events (spec 17) and the RU text, h mood providers and the plumbing review carry-overs.
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

-- Config: the repo defaults (v1 features on) plus t. Wanted captains (design/captain-spec.md) are off here: their
-- board lines, informant box and staged-raid slot would change these scenarios; host_captain.lua turns them on.
-- Sealed parcels (design/parcel-spec.md) are off for the same reason (trade box 400, line 20); host_parcel.lua turns them on.
function S_Cfg(t)
	local c = {exp=0, log=1, traffic=1, cap_enable=0, enable_parcels=0};
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

-- Runs f with a mod log that records but does not count ERROR / event=error lines (expected errors); returns their number.
function S_Expect(f)
	local lg = TRF_Log;
	TRF_Log = function(s)
		tinsert(HOST().logs, s);
		print("traffic: lua: "..tostring(s).." (expected)");
	end;
	local n0 = S_Mark();
	f();
	TRF_Log = lg;
	return S_Logs(n0, " ERROR ") + S_Logs(n0, " event=error ");
end;

-- a: install (12.1, 6.1) ---------------------------------------------------------------------

function T_STN_A()
	local h = HOST();
	S_Begin("gaoba");
	HOST_Check(V_Logs("module=station event=install none_installed=true trade_installed=true none_wrapped=true trade_wrapped=true") >= 1, "install: both wrapped, mine=1/1");
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
		and S_Logs(n0, "module=station event=pass reason=off system=gaoba at=none") == 1 and S_Logs(n0, "module=station event=pass reason=off system=gaoba at=dock") == 1,
		"voice 0: vanilla line DialogNone_live (DialogSystem) and the vanilla box");
	HOST_Press("cancel");
	h.cfg.voice = nil;
	-- voice 1: exactly one Message and one box per approach; OK reaches trf_shop's wrapper and vanilla.
	n0 = S_Mark();
	local ok0 = h.trade_ok;
	a = S_None(D.none[1]);
	b = S_Trade(D.trade[1]);
	HOST_Check(a.n == 1 and a.ntm == 1 and S_Logs(n0, "module=station event=mood system=gaoba system_index=42 vanilla_key=1") <= 1 and S_Vanilla(b)
		and S_Logs(n0, "module=station event=dock station_key=42 ") == 1, "voice 1: one Message, one box, dock line");
	HOST_Press("ok");
	HOST_Check(h.trade_ok == ok0 + 1 and S_Logs(n0, "module=station event=docked station_key=42 standing_up=false") == 1, "OK: trf_shop wrapper (docked line) and vanilla dock");
	-- Every MapInitialization installs again over the fresh vanilla originals.
	local o1, o2 = TRF_orig_NoneSt, TRF_orig_TradeSt;
	n0 = S_Mark();
	T_Enter("gaoba");
	HOST_Check(TRF_orig_NoneSt ~= o1 and TRF_orig_TradeSt ~= o2 and van() and TRF_StnIsMine(_NoneStation_Action)
		and S_Logs(n0, "module=station event=install none_installed=true trade_installed=true none_wrapped=true trade_wrapped=true") == 1, "entry: installed again over the new originals");
	o1 = TRF_orig_NoneSt;
	n0 = S_Mark();
	T_SaveLoad();
	HOST_Check(TRF_orig_NoneSt ~= o1 and van() and TRF_StnIsMine(__TradeStation_Action) and S_Logs(n0, "module=station event=install none_installed=true trade_installed=true none_wrapped=true trade_wrapped=true") >= 1
		and S_Logs(n0, "module=station event=load latch=false") == 1, "load: installed again, load line");
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
	HOST_Check(a.n == 1 and a.t == "#L_Dnone_live_msg" and ne == 1 and S_Logs(n0, "module=station event=pass reason=error") == 1,
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
	HOST_Check(S_Logs(n0, "module=station event=pass reason=off") == 1, "voice_moods 0: moods pass");
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
	HOST_Check(vo == TRF.ve and S_Logs(n0, "module=station event=owner system=hafa static_owner=Inoco owner=Vks owner_visit=") == 1 and a.t == "#L_Dnone_war_closed_VKS_msg"
		and a.spk == "DispetcherVKS", "owner change hafa: TRF.vo set, martial law 3_vks");
	TRF.clock.legs = TRF.clock.legs + 20;
	T_Enter("hafa");
	S_Rg().ph = 0;
	D = S_Setup({{"0"}});
	a = S_None(D.none[1]);
	HOST_Check(TRF.vo[hi] == vo and S_Logs(n0, "module=station event=owner ") == 1 and a.t == "#L_Dnone_univ_msg", "after own_legs legs: vanilla again, vo kept");
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
		local ok = a.t == "#L_Dnone_univ_msg" and S_Vanilla(b) and b.nm == 0 and S_Logs(n0, "module=station event=dock ") == 0
			and S_Logs(n0, "module=station event=pass reason="..why.." system="..sys.." at=none") == 1 and S_Logs(n0, "module=station event=pass reason="..why.." system="..sys.." at=dock") == 1;
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
	HOST_Check(S_Logs(t0, "module=station event=pass") == 0 and S_Logs(t0, "module=station event=mood system=taira ") == 1 and S_Logs(t0, "module=station event=dock station_key="..TRF_CurIdx().." ") == 1
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
	local dl = S_Line(t0, "module=station event=dock station_key=");
	HOST_Check(S_Logs(t0, "module=station event=mood system=taira ") == 1 and at.n >= 1 and strfind(dl, "fee_multiplier=1 no_fee_reason=latch", 1, 1) and strfind(dl, "greeting=stnr1 ", 1, 1)
		and S_Vanilla(bt) and S_Logs(t0, "module=station event=pass reason=latch system=taira at=dock") == 1 and S_Logs(t0, "at=none") == 0
		and TRF_StnSV().mis == 1, "transit: taira during a mission: mood, greeting, nofee=latch ("..dl..")");
	-- The mission ends in the same visit: the latch still stops the fee; the next entry charges again.
	h.qs = FALSE;
	t0 = S_Mark();
	bt = S_Trade(Dt.trade[1]);
	HOST_Press("cancel");
	HOST_Check(S_Vanilla(bt) and S_Logs(t0, "no_fee_reason=latch") == 1, "mission ended in the same visit: the latch still stops the fee");
	T_Jump("taira");
	TRF_SetPro(TRF_CurIdx(), 8);
	Dt = S_Setup({});
	t0 = S_Mark();
	bt = S_Trade(Dt.trade[1]);
	HOST_Press("cancel");
	HOST_Check(bt.nb == 1 and bt.box.text ~= "#UI_TradeStationDockRequest" and S_Logs(t0, "no_fee_reason=nil") == 1,
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
	HOST_Check(TRF_StnSV().mis == 1 and S_Logs(n0, "module=station event=pass") == 0 and S_Logs(n0, "module=station event=mood system=gaoba ") == 1
		and S_Logs(n0, "module=station event=dock station_key=42 ") == 1 and S_Vanilla(b), "story mission in gaoba: latch set, mood and dock lines");
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
	local an = S_Logs(n0, "module=station event=pass");
	b = S_Trade(D.trade[1]);
	HOST_Press("cancel");
	local a2 = S_None(D.none[1]);
	TRF_StrictOk = so;
	HOST_Check(an == 0 and S_Logs(n0, "module=station event=pass reason=gate:mission_q system=gaoba at=dock") == 1 and S_Vanilla(b)
		and TRF_StnSV().mis == 1 and S_Logs(n0, "module=station event=pass reason=latch") == 0 and S_Logs(n0, "module=station event=mood system=gaoba ") == 2 and a2.n >= 1,
		"voice_gate 2: moods open under mission_q, dock denied and latched, moods stay open after the latch");
	h.cfg.voice_gate = nil;
	-- voice_gate 1: the same denial closes the moods.
	T_Enter("gaoba");
	TRF_StrictOk = function(idx, feat) return nil, "mission_q"; end;
	D = S_Setup({{"0"}});
	n0 = S_Mark();
	a = S_None(D.none[1]);
	TRF_StrictOk = so;
	HOST_Check(S_Logs(n0, "module=station event=pass reason=gate:mission_q system=gaoba at=none") == 1, "voice_gate 1: mission_q closes the moods");
	-- strict 0: the dock is open, but no fee (stn-e checks the fee).
	h.cfg.strict = 0;
	T_Enter("gaoba");
	D = S_Setup({});
	n0 = S_Mark();
	b = S_Trade(D.trade[1]);
	HOST_Press("cancel");
	HOST_Check(S_Logs(n0, "module=station event=dock station_key=42 ") == 1, "strict 0: dock line (gate open)");
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
	HOST_Check(S_Logs(n0, "module=station event=dock station_key="..TRF_CurIdx().." ") == 1, gs.." at chapter 5: guard off, dock line");
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
		and S_Logs(n0, "module=station event=pass reason=row system=gaoba at=dock") == 1, "G10: row of another function: reason=row, vanilla box");
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
	HOST_Check(S_Vanilla(b) and S_Logs(n1, "module=station event=pass reason=nomap") == 1, "unknown system: nomap");
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
	HOST_Check(st() == 1 and S_Logs(n0, "module=station event=deed station_key=42 change=+1 reason=contract standing_before=0 standing_after=1 cap=none") == 1
		and S_Logs(n0, "module=station event=deed station_key=42 change=0 reason=sesc standing_before=1 standing_after=1 cap=visit_gain") == 1, "gain +1, second gain in the visit capped (gv)");
	T_SaveLoad();
	n0 = S_Mark();
	TRF_AddHelp(1, "dc");
	HOST_Check(st() == 1 and S_Logs(n0, "cap=visit_gain") == 1, "after a load: no second gain in the same visit");
	T_Enter("gaoba");
	ms(4000);
	n0 = S_Mark();
	TRF_AddHelp(1, "raid 3");
	ms(1000);
	TRF_AddHelp(1, "raid 3");
	HOST_Check(st() == 2 and S_Logs(n0, "reason=\"raid 3\" standing_before=1 standing_after=1 cap=far distance=4000") == 1 and S_Logs(n0, "change=+1 reason=\"raid 3\" standing_before=1 standing_after=2 cap=none distance=1000") == 1,
		"raid deed only within stn_near of the station");
	T_Enter("gaoba");
	n0 = S_Mark();
	TRF_Stn_Deed(idx, 1, "test", nil, 2);
	TRF_AddHelp(1, "join");
	HOST_Check(st() == 2 and S_Logs(n0, "reason=test standing_before=2 standing_after=2 cap=ceiling") == 1, "ceiling respected");
	local h0 = TRF.std.heat;
	n0 = S_Mark();
	TRF_AddHeat(1, "kill 7");
	TRF_AddHeat(1, "attack 7");
	TRF_AddHeat(1, "demand 7");
	TRF_AddHeat(-1, "contract");
	HOST_Check(st() == 0 and S_Logs(n0, "change=-1 reason=\"kill 7\" standing_before=2 standing_after=1") == 1 and S_Logs(n0, "change=-1 reason=\"attack 7\" standing_before=1 standing_after=0") == 1
		and S_Logs(n0, "reason=\"demand 7\" standing_before=0 standing_after=0 cap=visit_loss") == 1, "losses: at most two per visit");
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
		and S_Logs(n0, "module=station event=tip station_key=42 kind=feq system=gaoba") == 1, "supply-run tip at e 4 records tf/ts");
	n0 = S_Mark();
	TRF_AddHeat(1, "feq kill");
	TRF.std.heat = 0;
	HOST_Check(TRF.stn[k].st == -3 and TRF.stn[k].nt == 1 and TRF.stn[k].tf == nil and S_Logs(n0, "module=station event=rob station_key=42 standing_after=-3 tip_ban=true") == 1,
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
		and S_Logs(n0, "module=station event=tip station_key=42 kind=sweep") == 1, "sweep tip first, before the supply run");
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
	HOST_Check(strfind(r.scr, TRF_Txt("stntipbase", TRF_StnName(idx)), 1, 1) and S_Logs(n0, "module=station event=tip station_key=42 kind=base system=gaoba") == 1,
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
	HOST_Check(r.nm == 0 and S_Logs(n0, "greeting=stnr1 greeting_skip=gap") == 1 and rg2.msg == TRF_Txt("stnr1").."|",
		"radio spacing: greeting skipped inside stn_gap, sent on the next approach");
	-- parked kill: -1.
	T_Enter("gaoba");
	TRF.stn[k] = {st=2, lg=TRF.clock.legs};
	n0 = S_Mark();
	TRF_AddHeat(1, "parked kill");
	TRF.std.heat = 0;
	HOST_Check(TRF.stn[k].st == 1 and S_Logs(n0, "change=-1 reason=\"parked kill\" standing_before=2 standing_after=1") == 1, "parked kill: -1");
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
	HOST_Check(S_Screen(s0, TRF_Txt("stnnoted")) and S_Logs(n0, "module=station event=docked station_key=42 standing_up=true") == 1, "noted line after docking");
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
	HOST_Check(h.credits == cr0 - want and h.trade_ok == ok0 + 1 and S_Logs(n0, "module=station event=docked station_key=51") == 1
		and S_Logs(n0, "module=station event=fee_ok station_key=51 credits_before="..cr0.." credits_after="..(cr0 - want).." credit=false buyback=false") == 1, "OK: paid, docked through trf_shop's wrapper");
	r = S_Trade(D.trade[1]);
	HOST_Check(S_Vanilla(r), "second approach in the visit: vanilla box");
	HOST_Press("cancel");
	-- A load inside the visit: the saved pv stops a second charge.
	T_SaveLoad();
	D = S_Setup({});
	cr0 = h.credits;
	n0 = S_Mark();
	r = S_Trade(D.trade[1]);
	HOST_Check(S_Vanilla(r) and h.credits == cr0 and TRF.stn[k].pv == TRF.ve and S_Logs(n0, "no_fee_reason=paid_visit") == 1,
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
	HOST_Check(S_Vanilla(r) and r.nm == 0 and h.credits == cr0 and S_Logs(n0, "module=station event=pass reason=quiet system=kadenoa at=dock") == 1
		and S_Logs(n0, "module=station event=dock ") == 0, "__sys_SOS: quiet, no greeting, no fee box, vanilla box");
	HOST_Press("cancel");
	TRF_UiState = HOST_UiState; h.ui = 4;
	r = S_Trade(D.trade[1]);
	HOST_Check(S_Vanilla(r) and h.credits == cr0 and S_Logs(n0, "module=station event=dock ") == 0, "TRF_UiState dialog flag: quiet, no fee box");
	HOST_Press("cancel");
	h.ui = -1;
	r = S_Trade(D.trade[1]);
	HOST_Check(r.nb == 1 and r.box.text ~= "#UI_TradeStationDockRequest" and S_Logs(n0, "module=station event=dock station_key=51 ") == 1, "flag clear (UiState -1 = unknown): fee box");
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
	HOST_Check(S_Vanilla(r) and TRF.stn[k].st == -1 and S_Logs(n0, "reason=credit") == 0, "load in the visit after docking on credit: no box, no second -1");
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
	HOST_Check(S_Vanilla(r) and S_Logs(n0, "no_fee_reason=latch") == 1 and S_Logs(n0, "module=station event=pass reason=latch system=kadenoa at=dock") == 1,
		"story mission active: no fee (nofee=latch)");
	HOST_Press("cancel");
	h.qs = FALSE;
	-- F3: strict 0: no fee.
	h.cfg.strict = 0;
	S_Visit("kadenoa", "5_01", 8);
	D = S_Setup({});
	n0 = S_Mark();
	r = S_Trade(D.trade[1]);
	HOST_Check(S_Vanilla(r) and S_Logs(n0, "no_fee_reason=strict_0") == 1, "strict 0: no fee");
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
	HOST_Check(h.credits == cr0 and h.trade_ok == ok0 + 1 and S_Logs(n0, "module=station event=stale_box") == 1, "stale box after a load: docks, no charge");
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
	HOST_Check(getn(D.trade) == 2 and S_Logs(n0, "module=station event=dock station_key=51 param=\"\" via=prm+pos distance=0") == 1
		and S_Logs(n0, "module=station event=dock station_key=251 param=kadenoa_tri via=prm+pos distance=0") == 1 and S_Logs(n0, "module=station event=pass reason=table system=kadenoa at=dock") == 1,
		"kadenoa: keys 51 and 251 by param and position; quest dock passes");
	-- A dock with the wrong param at the other station's position: position wins.
	T_Enter("kadenoa");
	local e2 = TRF_Map().sys[idx].st[2];
	D = S_Setup({}, {{"", e2.x, e2.y, e2.z}});
	n0 = S_Mark();
	S_Trade(D.extra[1]); HOST_Press("cancel");
	HOST_Check(S_Logs(n0, "module=station event=id_mismatch station_key=251 param_station=1 position_station=2") == 1 and S_Logs(n0, "module=station event=dock station_key=251 param=\"\" via=pos") == 1, "position mismatch: idmis, id=pos");
	-- Station handle whose GetPosition errors: param alone.
	T_Enter("kadenoa");
	D = S_Setup({});
	__system_Dock_array[D.trade[2]][5].GetPosition = function(self) error("dead handle"); end;
	n0 = S_Mark();
	local e0 = h.errors;
	S_Trade(D.trade[2]); HOST_Press("cancel");
	HOST_Check(h.errors == e0 and S_Logs(n0, "module=station event=dock station_key=251 param=kadenoa_tri via=prm distance=nil") == 1, "GetPosition error: id=prm, no error");
	-- stn_pos 0: param only.
	h.cfg.tune = {stn_pos=0};
	T_Enter("kadenoa");
	D = S_Setup({}, {{"", 600, 0, 600}});
	n0 = S_Mark();
	S_Trade(D.extra[1]); HOST_Press("cancel");
	HOST_Check(S_Logs(n0, "module=station event=dock station_key=51 param=\"\" via=prm") == 1, "stn_pos 0: param only");
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
		TRF.stn[kk] = {st=-3, lg=L, gv=L, bv=L, pv=L, tf=L, ts=42, nt=1, ec=L};
		n = n + 1;
	end;
	TRF.vo = {};
	local ow = TRF_StnOwners();
	for nm, t in ow do if V_Idx(nm) then TRF.vo[V_Idx(nm)] = L; end; end;
	local ss, ts = HOST_SaveSize(TRF.stn), 8 + 3 + HOST_SaveSize(TRF);
	HOST_Check(n == 76 and ks[251] == 1 and ss <= 17700 and ts < 100000, "size: "..n.." keys, TRF.stn "..ss.." bytes, TRF "..ts.." bytes");
	HOST_Check(HOST_Reserved(TRF, "TRF") == "", "no reserved key in TRF");
	n0 = S_Mark();
	TRF_DumpState("test");
	HOST_Check(S_Logs(n0, "module=station event=dump visit=") == 1 and S_Logs(n0, " none_wrapped=true trade_wrapped=true") == 1, "dump stn line");
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

-- g: station events (17) ----------------------------------------------------------------------

-- Dock rows activate.script would place (HOST().evrows = {{func, tip}, ...}), set by the scene before
-- TRF_OnActivate, so the entry plan sees them; the scene's trade station also answers the map label of the
-- system (TRF_Station, trf_gen's path A). HOST().evhook runs after the module files are loaded (an override of a
-- module function for this entry).
S_Scene0 = T_Scene;
function T_Scene(sys)
	S_Scene0(sys);
	local h = HOST();
	if not h.evrows then return; end;
	local m = TRF_Map();
	local s = m.sys[m.by[sys]];
	if s and s.st and s.st[1] and s.st[1].label then h.objs[s.st[1].label] = h.station; end;
	local rows = {};
	for i = 1, getn(h.evrows) do
		local e = h.evrows[i];
		tinsert(rows, {e[1], Vector3(100 * i + 40, 0, 900), e[2] or "", 5, HOST_Obj("EVROW"..i, 100 * i, 0, 900)});
	end;
	__system_Dock_array = rows;
	if h.evhook then h.evhook(); end;
end;

-- Dock rows of one kind (functions: an entry clears table globals).
function S_EvBarge() return {{"_NoneStation_Action", "5other"}}; end;
function S_EvShuttle() return {{"__TradeStation_Action", ""}}; end;
function S_EvLaunch() return {{"_NoneStation_Action", "1"}}; end;

function S_Ev() return TRF_StnSV().ev; end;

-- Entry with the event rows; the mothership waits far from every portal and the station.
function S_EvEnter(sys, rows)
	local h = HOST();
	h.evrows = rows;
	T_Enter(sys);
	h.ms.pos = Vector3(5000, 0, 5000);
end;

-- The due spawn (ev_dt 5 + 0..4 s).
function S_EvRun() T_Tick(24, 0.5); end;

-- Mothership next to the lead ship of trader id.
function S_MsTo(id)
	local p = TRF_GnLead(id):GetPosition();
	HOST().ms.pos = Vector3(p.x + 50, p.y, p.z);
end;

-- Docking of path A trader id: the approach trigger, then T_dock (20 s).
function S_EvDock(id)
	HOST_Fire("f_inside", "TRF_OnArrive("..id..",0,");
	T_Tick(50, 0.5);
end;

-- Legs past the event cooldown (ev_cd 24).
function S_EvCool()
	for i = 1, 24 do TRF_AddLeg("test"); end;
end;

-- Occurrences of the plain text pat in s.
function S_Count(s, pat)
	local n, i = 0, 1;
	if type(s) ~= "string" then return 0; end;
	while 1 do
		local a, e = strfind(s, pat, i, 1);
		if not a then return n; end;
		n = n + 1;
		i = e + 1;
	end;
end;

function S_ReadFile(p)
	local f = openfile(p, "rb");
	if not f then return nil; end;
	local s = read(f, "*a");
	closefile(f);
	return s;
end;

function T_STN_G()
	local h = HOST();
	h.labels.CurrentQuest = "9_01";
	S_Begin("gaoba", {log=2, staged=0, seed=0, parked=0, queue=0, feq=0, sweeps=0, tune={ev_p=100, ev_dt=5}});
	local idx = TRF_CurIdx();
	local k = S_Key(1);
	HOST_Check(S_Ev() == nil, "no dock rows at the first entry: no event");
	-- Barge: planned at entry, spawned with a small raid of kind stn, defended: event pay instead of 8.5, deed.
	local n0 = S_Mark();
	S_EvEnter("gaoba", S_EvBarge());
	local ev = S_Ev();
	HOST_Check(ev and ev.kind == "barge" and ev.st == "plan" and TRF.live.ev == "station"
		and S_Logs(n0, "module=station event=ev_plan kind=barge system=gaoba station_key=42 kind_count=1 chance=100 ") == 1,
		"barge: planned at entry, slot station taken");
	local c0 = h.credits;
	S_EvRun();
	ev = S_Ev();
	local r = ev and TRF_Rec(ev.id);
	local rd = ev and type(ev.rn) == "number" and V_Rd(ev.rn);
	HOST_Check(ev.st == "run" and r and r.sev == 1 and r.path == "A" and rd and rd.kind == "stn" and rd.tier == 1
		and TRF.stn[k] and TRF.stn[k].ec == TRF.clock.legs and S_Logs(n0, "module=station event=ev_spawn kind=barge station_key=42 trader_id="..ev.id.." raid_id="..tostring(ev.rn)) == 1
		and S_Screen(0, "Dockmaster: an ore barge is inbound with pirates on its tail. Cover it to the station and the harbour pays.") == nil,
		"barge: path A trader (sev), raid T1 kind stn, cooldown stamp ec, radio line");
	HOST_Check(h.msgs[getn(h.msgs)].t == "Dockmaster: an ore barge is inbound with pirates on its tail. Cover it to the station and the harbour pays."
		and h.spk[getn(h.spk)] == "InocoDispetcher", "barge: dockmaster radio line, owner speaker");
	local st1 = r.st;
	r.st = "in";
	local co, cw = TRF_CtOffer(ev.id);
	r.st = st1;
	HOST_Check(co == nil and cw == "used", "event ship: no escort contract offer ("..tostring(cw)..")");
	local n = ev.rn;
	if V_Rd(n).st == "armed" then HOST_Fire("f_inside", "TRF_RaidGo("..n..","); end;
	local hr = TRF_H().rd[n];
	HOST_Check(hr and getn(hr.sh) == 2, "barge raid: a small flight ("..(hr and getn(hr.sh) or 0).." ships)");
	HOST_Fire("attack", "TRF_OnRaidHit("..n..",1,");
	local want = floor(TRF_PayN(idx) * 40 / 100);
	n0 = S_Mark();
	for j = 1, getn(hr.sh) do hr.sh[j].alive = nil; HOST_Fire("died", "TRF_OnRaidDied("..n..","..j..","); end;
	ev = S_Ev();
	HOST_Check(ev.st == "end" and ev.res == "defended" and h.credits - c0 == want and want > 0
		and S_Logs(n0, "module=raid event=paid raid_id="..n.." trader_id="..ev.id.." credits=0 ") == 1
		and S_Logs(n0, "module=station event=ev_end kind=barge station_key=42 trader_id="..ev.id.." raid_id="..n.." result=defended reason=raid_help pay="..want.." ") == 1
		and S_Logs(n0, "module=station event=deed station_key=42 change=+1 reason=\"event barge\" standing_before=0 standing_after=1") == 1
		and S_Screen(0, "Dockmaster: they are in. "..want.." credits for your trouble, Wolves."),
		"barge defended: 0.4 N_eff = "..want.." instead of the 8.5 credits (paid "..(h.credits - c0).."), deed +1");
	TRF_Remove(ev.id, "test");
	-- Cooldown: the same station within ev_cd legs plans nothing; the slot stays free for others.
	n0 = S_Mark();
	S_EvEnter("gaoba", S_EvBarge());
	HOST_Check(S_Ev() == nil and TRF.live.ev == nil and S_Logs(n0, "module=station event=ev_plan system=gaoba station_key=42 roll=nil result=skipped reason=cooldown") == 1,
		"cooldown: no event within ev_cd legs");
	-- Shuttle: escorted to the station (mothership within ev_r at the docking): delivered, pay, deed.
	S_EvCool();
	S_EvEnter("gaoba", S_EvShuttle());
	S_EvRun();
	ev = S_Ev();
	HOST_Check(ev and ev.kind == "shuttle" and ev.st == "run" and ev.rn == nil and TRF_Rec(ev.id), "shuttle: spawned, no raid");
	c0 = h.credits;
	S_MsTo(ev.id);
	want = floor(TRF_PayN(idx) * 40 / 100);
	local st0 = TRF_Stn_Rung(idx, 1);
	n0 = S_Mark();
	S_EvDock(ev.id);
	HOST_Check(ev.res == "delivered" and h.credits - c0 == want and TRF.stn[k].st == st0 + 1 and TRF_Rec(ev.id) == nil
		and S_Logs(n0, "module=station event=ev_end kind=shuttle station_key=42 trader_id="..ev.id.." raid_id=nil result=delivered reason=dock pay="..want.." distance=") == 1
		and S_Logs(n0, "module=generator event=remove trader_id="..ev.id.." reason=dock") == 1,
		"shuttle delivered: pay "..want..", standing +1, docked");
	-- Shuttle docking without the mothership near: far, no pay, no deed.
	S_EvCool();
	S_EvEnter("gaoba", S_EvShuttle());
	S_EvRun();
	ev = S_Ev();
	c0 = h.credits;
	st0 = TRF_Stn_Rung(idx, 1);
	n0 = S_Mark();
	S_EvDock(ev.id);
	HOST_Check(ev.res == "far" and h.credits == c0 and TRF.stn[k].st == st0 and S_Logs(n0, "result=far reason=dock pay=0 ") == 1
		and S_Screen(0, "Dockmaster: they made it, but not with your help. No pay."), "shuttle far: no pay, no deed");
	-- Launch: waits at its gate (form, no watchdog) until the mothership comes within ev_meet, then flies in.
	S_EvCool();
	S_EvEnter("gaoba", S_EvLaunch());
	S_EvRun();
	ev = S_Ev();
	r = ev and TRF_Rec(ev.id);
	HOST_Check(ev and ev.kind == "launch" and ev.st == "wait" and r and r.st == "form" and HOST_Count("f_inside", "TRF_OnArrive("..ev.id..",0,") == 0,
		"launch: spawned and waiting, no orders");
	T_Tick(140, 0.5);
	HOST_Check(ev.st == "wait" and TRF_Rec(ev.id) and TRF_Rec(ev.id).st == "form", "launch: still waiting after 70 s far away");
	S_MsTo(ev.id);
	n0 = S_Mark();
	T_Tick(4, 0.5);
	HOST_Check(ev.st == "run" and r.st == "in" and HOST_Count("f_inside", "TRF_OnArrive("..ev.id..",0,") == 1
		and S_Logs(n0, "module=station event=ev_pickup kind=launch trader_id="..ev.id.." distance=50") == 1 and S_Screen(0, "Launch: thank you, Wolves! We follow you to the station."),
		"launch: pickup within ev_meet, path A orders");
	c0 = h.credits;
	want = floor(TRF_PayN(idx) * 40 / 100);
	st0 = TRF_Stn_Rung(idx, 1);
	S_EvDock(ev.id);
	HOST_Check(ev.res == "delivered" and h.credits - c0 == want and TRF.stn[k].st == st0 + 1, "launch delivered: pay "..want..", standing +1");
	-- Launch never picked up: the generator's lifetime removal ends it (expired).
	S_EvCool();
	S_EvEnter("gaoba", S_EvLaunch());
	S_EvRun();
	ev = S_Ev();
	TRF_Remove(ev.id, "life");
	n0 = S_Mark();
	T_Tick(4, 0.5);
	HOST_Check(ev.res == "expired" and S_Logs(n0, "result=expired reason=life pay=0 ") == 1 and S_Screen(0, "Dockmaster: we lost them."), "launch expired: no pay");
	-- Barge killed by its raid: lost.
	S_EvCool();
	S_EvEnter("gaoba", S_EvBarge());
	S_EvRun();
	ev = S_Ev();
	c0 = h.credits;
	local x = TRF_H().tr[ev.id];
	n0 = S_Mark();
	for t = 1, getn(x.tp) do x.tp[t].alive = nil; HOST_Fire("died", "TRF_OnShipDied("..ev.id..","..t..","); end;
	T_Tick(4, 0.5);
	HOST_Check(ev.res == "lost" and h.credits == c0 and S_Logs(n0, "module=station event=ev_end kind=barge ") == 1, "barge lost: no pay ("..tostring(ev.res)..")");
	for q, e in TRF.live.rd do if type(e) == "table" and e.st ~= "end" then TRF_Rd_End(q, "cancel"); end; end;
	-- Barge escaped to its portal refuge with counted help before its raid ends: the event waits (state raid);
	-- the raid's end pays the event (defended), not the 8.5 credits.
	S_EvCool();
	S_EvEnter("gaoba", S_EvBarge());
	S_EvRun();
	ev = S_Ev();
	n = ev.rn;
	if V_Rd(n).st == "armed" then HOST_Fire("f_inside", "TRF_RaidGo("..n..","); end;
	hr = TRF_H().rd[n];
	HOST_Fire("attack", "TRF_OnRaidHit("..n..",1,");
	hr.sh[1].alive = nil;
	HOST_Fire("died", "TRF_OnRaidDied("..n..",1,");
	c0 = h.credits;
	want = floor(TRF_PayN(idx) * 40 / 100);
	if TRF_Rec(ev.id).st ~= "flee" then TRF_Flee(ev.id, "raid"); end;
	HOST_Fire("f_object_inside", "TRF_Rd_Safe("..ev.id..",1,");
	T_Tick(4, 0.5);
	HOST_Check(ev.st == "raid" and TRF_Rec(ev.id) == nil and V_Rd(n).hit == 1 and V_Rd(n).st ~= "end",
		"barge escaped with help: event waits for its raid ("..tostring(ev.st)..")");
	n0 = S_Mark();
	TRF_Rd_End(n, "left");
	HOST_Check(ev.res == "defended" and h.credits - c0 == want and want > 0
		and S_Logs(n0, "module=raid event=paid raid_id="..n.." trader_id="..ev.id.." credits=0 ") == 1
		and S_Logs(n0, "module=station event=ev_end kind=barge station_key=42 trader_id="..ev.id.." raid_id="..n.." result=defended reason=raid_help pay="..want.." ") == 1,
		"barge escaped with help: defended at the raid's end, event pay "..want.." (paid "..(h.credits - c0)..")");
	-- Barge escaped without help: the raid's end leaves it no_help, no pay.
	S_EvCool();
	S_EvEnter("gaoba", S_EvBarge());
	S_EvRun();
	ev = S_Ev();
	n = ev.rn;
	if V_Rd(n).st == "armed" then HOST_Fire("f_inside", "TRF_RaidGo("..n..","); end;
	c0 = h.credits;
	if TRF_Rec(ev.id).st ~= "flee" then TRF_Flee(ev.id, "raid"); end;
	n0 = S_Mark();
	HOST_Fire("f_object_inside", "TRF_Rd_Safe("..ev.id..",1,");
	TRF_Stn_Step();
	HOST_Check(ev.st == "raid" and V_Rd(n).st ~= "end", "barge escaped without help: event waits for its raid ("..tostring(ev.st)..")");
	T_Tick(4, 0.5);
	TRF_Rd_End(n, "left");
	T_Tick(4, 0.5);
	HOST_Check(ev.res == "no_help" and h.credits == c0 and S_Logs(n0, "result=no_help reason=escaped pay=0 ") == 1
		and S_Logs(n0, "module=raid event=end raid_id="..n.." trader_id="..ev.id.." ") == 1
		and S_Screen(0, "Dockmaster: they made it, but not with your help. No pay."), "barge escaped without help: no_help at the raid's end, no pay");
	-- Barge whose raid TRF_RaidOn refuses: void before the cooldown stamp and the line; an ordinary trader.
	S_EvCool();
	S_EvEnter("gaoba", S_EvBarge());
	local ro = TRF_RaidOn;
	TRF_RaidOn = function() return nil; end;
	local nm0 = getn(h.msgs);
	n0 = S_Mark();
	S_EvRun();
	TRF_RaidOn = ro;
	ev = S_Ev();
	r = ev and ev.id and TRF_Rec(ev.id);
	HOST_Check(ev and ev.res == "void" and r and r.sev == nil and TRF.live.ev == nil and (TRF.stn[k] == nil or TRF.stn[k].ec ~= TRF.clock.legs)
		and getn(h.msgs) == nm0 and S_Logs(n0, "module=station event=ev_spawn ") == 0
		and S_Logs(n0, "module=station event=ev_end kind=barge station_key=42 trader_id="..tostring(ev and ev.id).." raid_id=nil result=void reason=raid ") == 1,
		"barge raid refused: void, no line, no cooldown stamp, sev cleared, slot freed");
	if ev and ev.id then TRF_Remove(ev.id, "test"); end;
	-- Slot: a sweep that claimed the scripted-event slot at entry wins; the event is refused (log 1 line).
	S_EvCool();
	h.evhook = function() TRF_SweepEntry = function() TRF_EventSlotTake("sweep"); return nil; end; end;
	n0 = S_Mark();
	S_EvEnter("gaoba", S_EvShuttle());
	h.evhook = nil;
	HOST_Check(S_Ev() == nil and TRF.live.ev == "sweep" and S_Logs(n0, "result=skipped reason=slot") == 1
		and S_Logs(n0, "module=plumb event=event_slot kind=station rank=8 holder=sweep result=refused") == 1, "slot held by a sweep: event refused");
	-- Gates: a quest id of the system in process (strict gate), a story mission (free roam), chapter, voice_events 0.
	h.quests["quest_7a"] = QUEST_PROCESS;
	n0 = S_Mark();
	S_EvEnter("kadenoa", S_EvShuttle());
	HOST_Check(S_Ev() == nil and S_Logs(n0, "module=station event=ev_plan system=kadenoa station_key=nil roll=nil result=skipped reason=gate:quest") == 1, "strict gate: quest in process, no event");
	h.quests["quest_7a"] = nil;
	h.qs = TRUE;
	n0 = S_Mark();
	S_EvEnter("gaoba", S_EvShuttle());
	HOST_Check(S_Ev() == nil and S_Logs(n0, "result=skipped reason=latch") == 1, "story mission active: no event");
	h.qs = FALSE;
	h.labels.CurrentQuest = "4_01";
	n0 = S_Mark();
	S_EvEnter("gaoba", S_EvShuttle());
	HOST_Check(S_Ev() == nil and S_Logs(n0, "result=skipped reason=chapter") == 1, "chapter 4: no event");
	h.labels.CurrentQuest = "9_01";
	h.cfg.voice_events = 0;
	n0 = S_Mark();
	S_EvEnter("gaoba", S_EvShuttle());
	HOST_Check(S_Ev() == nil and S_Logs(n0, "result=skipped reason=off") == 1 and TRF.live.ev == nil, "voice_events 0: no event");
	h.cfg.voice_events = nil;
	-- A jump before the spawn ends the plan (void); a load drops the visit record, the cooldown stamp stays.
	n0 = S_Mark();
	S_EvEnter("gaoba", S_EvShuttle());
	ev = S_Ev();
	h.evrows = nil;
	T_Jump("gaoba");
	HOST_Check(ev and ev.res == "void" and S_Logs(n0, "module=station event=ev_end kind=shuttle station_key=42 trader_id=nil raid_id=nil result=void reason=jump") == 1,
		"jump before the spawn: void");
	S_EvEnter("gaoba", S_EvShuttle());
	S_EvRun();
	ev = S_Ev();
	local L1 = TRF.stn[k].ec;
	HOST_Check(ev and ev.st == "run" and L1 == TRF.clock.legs, "planned and spawned again (no stamp from the void plan)");
	T_SaveLoad();
	HOST_Check(S_Ev() == nil and TRF.stn[k].ec == L1, "load: no visit record, ec kept");
	T_Tick(4, 0.5);
	-- Prune keeps a st 0 entry while its cooldown runs, drops it after ev_cd legs; Fix checks ec.
	h.evrows = nil;
	TRF.stn[k] = {st=0, lg=TRF.clock.legs, ec=TRF.clock.legs};
	T_Enter("gaoba");
	HOST_Check(TRF.stn[k] and TRF.stn[k].ec ~= nil, "prune: entry kept while the event cooldown runs");
	S_EvCool();
	T_Enter("gaoba");
	HOST_Check(TRF.stn[k] == nil, "prune: dropped after ev_cd legs");
	local L = TRF.clock.legs;
	TRF.stn = {[42]={st=1, lg=L, ec=L + 5}, [51]={st=1, lg=L, ec="x"}, [251]={st=1, lg=L, ec=L}};
	TRF_Stn_Fix();
	HOST_Check(TRF.stn[42].ec == nil and TRF.stn[51].ec == nil and TRF.stn[251].ec == L, "Fix: ec not a number or past legs -> nil");
	n0 = S_Mark();
	TRF_DumpState("test");
	HOST_Check(S_Logs(n0, "module=station event=dump ") == 1 and S_Logs(n0, " event_legs=251:"..L.." ") == 1, "dump: event_legs");
	-- Launch that fled (trf_raid's heat reaction, r.st flee): no pickup while not held; its escape ends the event lost.
	S_EvCool();
	S_EvEnter("gaoba", S_EvLaunch());
	S_EvRun();
	ev = S_Ev();
	r = TRF_Rec(ev.id);
	r.st = "flee";
	S_MsTo(ev.id);
	n0 = S_Mark();
	T_Tick(4, 0.5);
	HOST_Check(ev.st == "wait" and r.st == "flee" and S_Logs(n0, "event=ev_pickup") == 0, "launch fled: no pickup while not held");
	TRF_Remove(ev.id, "escaped");
	T_Tick(4, 0.5);
	HOST_Check(ev.res == "lost" and S_Logs(n0, "result=lost reason=escaped pay=0 ") == 1, "launch fled and escaped: lost, no pay");
	-- Pure parts.
	local kk = TRF_StnEvKindsOf({{"__TradeStation_Action"}, {"_NoneStation_Action", 0, "4ino"}, {"_NoneStation_Action", 0, "3adm"}, {"_NoneStation_Action", 0, "pirate"}});
	HOST_Check(getn(kk) == 3 and kk[1] == "barge" and kk[2] == "launch" and kk[3] == "shuttle" and getn(TRF_StnEvKindsOf({{"_NoneStation_Action", 0, "5"}, {"_PirDock_Action"}})) == 0,
		"kinds: barge (private/restricted), launch (civil), shuttle (trade); silent and pirate none");
	HOST_Check(TRF_StnEvPayOf(10000, 40) == 4000 and TRF_StnEvPayOf(nil, 40) == 0 and TRF_StnEvPayOf(10000, 0) == 0, "pay: k percent of N_eff");
	-- RU text: every station key, every survivors key (design/survivors-spec.md 9), every faction ladder key
	-- (design/ladder-spec.md 8), every charter key (design/charter-spec.md 8) and every battle scars key
	-- (design/scar-spec.md 8), every wanted captains key (design/captain-spec.md 8), every clan stash key (design/stash-spec.md 8), every Wolves Freight key (design/freight-spec.md 8), every dynamic nest key (design/nest-spec.md 8) and every sealed parcel key (design/parcel-spec.md 8) of the EN tables, cp1251 (no byte
	-- outside ASCII and 0xA8, 0xB8, 0xC0-0xFF), CRLF.
	local ru = S_ReadFile(h.dir.."../../../../loc/trf_ru.loc");
	local want, got, bad = {}, {}, "";
	for kx, v in TRF_Stn_Text() do want[TRF_LocKey(kx)] = 1; end;
	if type(TRF_Sv_Text) == "function" then for kx, v in TRF_Sv_Text() do want[TRF_LocKey(kx)] = 1; end; end;
	if type(TRF_Lad_Text) == "function" then for kx, v in TRF_Lad_Text() do want[TRF_LocKey(kx)] = 1; end; end;
	if type(TRF_Ch_Text) == "function" then for kx, v in TRF_Ch_Text() do want[TRF_LocKey(kx)] = 1; end; end;
	if type(TRF_Sc_Text) == "function" then for kx, v in TRF_Sc_Text() do want[TRF_LocKey(kx)] = 1; end; end;
	if type(TRF_Cap_Text) == "function" then for kx, v in TRF_Cap_Text() do want[TRF_LocKey(kx)] = 1; end; end;
	if type(TRF_Sh_Text) == "function" then for kx, v in TRF_Sh_Text() do want[TRF_LocKey(kx)] = 1; end; end;
	if type(TRF_Fr_Text) == "function" then for kx, v in TRF_Fr_Text() do want[TRF_LocKey(kx)] = 1; end; end;
	if type(TRF_Nest_Text) == "function" then for kx, v in TRF_Nest_Text() do want[TRF_LocKey(kx)] = 1; end; end;
	if type(TRF_Pc_Text) == "function" then for kx, v in TRF_Pc_Text() do want[TRF_LocKey(kx)] = 1; end; end;
	-- Demand page keys (design/demand-page-spec.md 8): the dmp* keys of the supply and hail tables and the answers dmok, dmno.
	for i, fn in {"TRF_Supply_Text", "TRF_Hail_Text"} do
		local tf = getglobal(fn);
		if type(tf) == "function" then for kx, v in tf() do if strsub(kx, 1, 3) == "dmp" or kx == "dmok" or kx == "dmno" then want[TRF_LocKey(kx)] = 1; end; end; end;
	end;
	local nl, ncr, b2 = S_Count(ru, "\n"), S_Count(ru, "\r\n"), strfind(ru or "", "[\128-\167\169-\183\185-\191]");
	local i = 1;
	while ru do
		local a, e, kx = strfind(ru, "#TRF_(%w+) = [^\r]+\r\n", i);
		if not a then break; end;
		got[kx] = 1;
		i = e + 1;
	end;
	for kx, v in want do if not got[kx] then bad = bad.." missing:"..kx; end; end;
	for kx, v in got do if not want[kx] then bad = bad.." extra:"..kx; end; end;
	HOST_Check(ru and strsub(ru, 1, 13) == "LOCALE_FILE\r\n" and bad == "" and nl == ncr and not b2, "loc/trf_ru.loc: every station, survivors, ladder, charter, scar, captain, stash, freight, nest, parcel and demand page key, cp1251, CRLF"..bad);
	for id, rr in TRF.live.tr do if type(rr) == "table" and rr.st ~= "gone" then TRF_Remove(id, "test"); end; end;
end;

-- h: mood providers and the plumbing review carry-overs ------------------------------------------

function S_ProvOne(idx, tip) return "1"; end;
function S_ProvNil(idx, tip) return nil; end;
function S_ProvErr(idx, tip) error("injected provider error"); end;

function T_STN_H()
	local h = HOST();
	S_Begin("gaoba", {log=2});
	local idx = TRF_CurIdx();
	local k = S_Key(1);
	-- Mood providers (5.2 row 1, contract f(idx, tip) -> key or nil): read from trf_plumb's registry.
	local D = S_Setup({{"0"}, {"5"}});
	S_MoodReset(S_Rg().sl);
	S_Rg().ph = 1;
	local n0 = S_Mark();
	S_None(D.none[1]);
	HOST_Check(getn(TRF_Stn_Prov()) == 0 and S_Logs(n0, "vanilla_key=0 mood_key=3adm rule=7 ") == 1, "no provider: Boom row 7 gives 3adm");
	TRF_VoiceProvReg("S_ProvNil");
	TRF_VoiceProvReg("S_ProvOne");
	local pl = TRF_Stn_Prov();
	local vp = TRF_Voice_Prov();
	HOST_Check(getn(pl) == 2 and pl[1] == "S_ProvNil" and pl[2] == "S_ProvOne" and vp[1] == pl[1] and vp[2] == pl[2], "TRF_Stn_Prov is the plumbing registry, in registration order");
	n0 = S_Mark();
	local a = S_None(D.none[1]);
	local b = S_None(D.none[2]);
	HOST_Check(a.t == "#L_Dnone_live_msg" and S_Logs(n0, "vanilla_key=0 mood_key=1 rule=1 ") == 1 and b.t == "#L_Dnone_other_msg"
		and S_Logs(n0, "vanilla_key=5 mood_key=5 rule=1 ") == 1, "provider key wins over the mood table (rule 1); silent stations stay vanilla");
	TRF_InstallPlumb();
	HOST_Check(getn(TRF_Stn_Prov()) == 2, "a second install keeps one entry per provider");
	-- A provider that errors is skipped; the next one answers.
	T_Enter("gaoba");
	HOST_Check(getn(TRF_Stn_Prov()) == 0, "entry: the registry starts empty (modules register in TRF_<M>_Plumb)");
	D = S_Setup({{"0"}});
	S_MoodReset(S_Rg().sl);
	S_Rg().ph = 1;
	TRF_VoiceProvReg("S_ProvErr");
	TRF_VoiceProvReg("S_ProvOne");
	a = {};
	n0 = S_Mark();
	local ne = S_Expect(function() local t = %a; t.r = S_None(%D.none[1]); end);
	HOST_Check(ne == 1 and a.r.t == "#L_Dnone_live_msg" and S_Logs(n0, "mood_key=1 rule=1 ") == 1, "provider error caught, the next provider's key used");
	-- (a) Station fee box that cannot open: event=fee box=false, then the vanilla box; an opened one logs box=true.
	S_Visit("kadenoa", "5_01", 8);
	D = S_Setup({});
	h.smn = 0;
	local sm = ShowMsgBox;
	ShowMsgBox = function(...)
		HOST().smn = HOST().smn + 1;
		if HOST().smn == 1 then error("injected ShowMsgBox failure"); end;
		return call(%sm, arg);
	end;
	b = {};
	n0 = S_Mark();
	ne = S_Expect(function() local t = %b; t.r = S_Trade(%D.trade[1]); end);
	ShowMsgBox = sm;
	b = b.r;
	HOST_Check(ne == 1 and S_Vanilla(b) and S_Logs(n0, "module=station event=fee station_key=51 ") == 1 and S_Logs(n0, " box=false") == 1
		and S_Logs(n0, " box=true") == 0 and S_Logs(n0, "module=plumb event=dock kind=req line_count=0 box=station_fee result=vanilla reason=box_failed") == 1,
		"fee box failed to open: box=false, vanilla box");
	HOST_Press("cancel");
	n0 = S_Mark();
	b = S_Trade(D.trade[1]);
	HOST_Check(b.nb == 1 and not S_Vanilla(b) and S_Logs(n0, "module=station event=fee station_key=51 ") == 1 and S_Logs(n0, " box=true") == 1,
		"fee box opened: box=true after the show");
	HOST_Press("cancel");
	-- (a) Pirate offer box: the stat and event=offer follow the show result (lock refused, then opened).
	local L = TRF.live;
	local sp = {text="offer", ok="TRF_FcPoAcc", no="TRF_FcPoDec", fail="TRF_FcPoFail", shown="TRF_FcPoShown", own="pirate_offer"};
	L.po = {k=1, s=idx, w="box", g=TRF.gen};
	TRF_BoxTake("hail");
	local s0 = L.stat.po_box or 0;
	n0 = S_Mark();
	local ok = TRF_PlShow("pir", "TRF_orig_PirOk", {}, sp);
	HOST_Check(ok == nil and L.po == nil and (L.stat.po_box or 0) == s0
		and S_Logs(n0, "module=faction event=offer offer_kind=1 system=") == 1 and S_Logs(n0, " system_index="..idx.." box=false") == 1, "pirate offer, box lock refused: box=false, no stat");
	TRF_BoxFree("hail");
	L.po = {k=1, s=idx, w="box", g=TRF.gen};
	n0 = S_Mark();
	ok = TRF_PlShow("pir", "TRF_orig_PirOk", {}, sp);
	HOST_Check(ok == 1 and (L.stat.po_box or 0) == s0 + 1 and S_Logs(n0, "module=faction event=offer offer_kind=1 system=") == 1 and S_Logs(n0, " system_index="..idx.." box=true") == 1,
		"pirate offer opened: box=true, stat po_box");
	HOST_Press("cancel");
	-- (b) The docked line (order 90) runs under __disableAction: standing rose, OK pressed while the flag is set.
	S_Visit("gaoba", "9_01");
	D = S_Setup({});
	TRF_Stn_Deed(idx, 1, "test");
	b = S_Trade(D.trade[1]);
	HOST_Check(S_Vanilla(b), "gaoba: vanilla box (no fee)");
	__disableAction = TRUE;
	n0 = S_Mark();
	HOST_Press("ok");
	__disableAction = FALSE;
	HOST_Check(S_Logs(n0, "module=station event=docked station_key=42 standing_up=true") == 1 and TRF_StnSV().nd[42] == 1
		and S_Logs(n0, "module=ui event=say result=skipped reason=flag message=\"Dockmaster: noted, Wolves.\"") == 1
		and S_Logs(n0, "module=plumb event=dock kind=trade ") == 1 and S_Logs(n0, "result=skipped reason=disable_action") == 1, "docked line under __disableAction (always handler; TRF_Say mutes the text as before)");
	-- (c) Leg cap D1: stat leg_cap and its debug line once per visit, also across a load; again after an entry.
	h.cfg.tune = {T_leg=5};
	T_Enter("gaoba");
	local l0 = TRF.clock.legs;
	n0 = S_Mark();
	T_Tick(120, 0.5);
	HOST_Check(TRF.clock.legs == l0 + 3 and TRF.clock.vl == 3 and TRF.clock.vc == 1 and T_Stat("leg_cap") == 1
		and S_Logs(n0, "module=state event=leg_cap legs="..(l0 + 3).." visit_tick_legs=3 cap=3 result=reached") == 1
		and S_Logs(n0, "module=state event=leg_cap legs="..(l0 + 3).." visit_tick_legs=3 cap=3 result=dropped") == 1, "leg cap: counted once in 60 s ("..T_Stat("leg_cap")..")");
	T_SaveLoad();
	n0 = S_Mark();
	T_Tick(40, 0.5);
	HOST_Check(TRF.clock.vc == 1 and S_Logs(n0, "event=leg_cap") == 0, "after a load: no second count in the visit");
	T_Enter("gaoba");
	HOST_Check(TRF.clock.vc == nil, "entry clears vc");
	n0 = S_Mark();
	T_Tick(120, 0.5);
	HOST_Check(T_Stat("leg_cap") == 1 and S_Logs(n0, "result=dropped") == 1, "next visit: counted once again");
	TRF.clock.vc = 7;
	TRF_Repair();
	HOST_Check(TRF.clock.vc == nil, "repair: vc other than 1 -> nil");
	h.cfg.tune = nil;
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
