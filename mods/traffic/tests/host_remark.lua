-- Crew remarks scenarios (design/crew-remarks-spec.md 13, B06) under stock Lua 4.0.1: TRF_RM=a..g, run by run_host.sh as
-- its own entry point. a install (loader, module list, text keys, cfg and tune defaults, remarks 0, dump), b the speaker
-- function (voice order and filters with stubbed squad pilots, a template list, TRF_CrewSay radio, line, fallback and
-- suppression), c record kinds and texts (trader, sweep navy and pirate, base, captain; ages; chapters; the chapter 5
-- rule; on-screen, hidden and opened records; unplaced records), d the told rules (oldest first, same-leg merge with the
-- captain clause, the sweep family across base system and home, the stamp cap and floor, prune, a witnessed base, the
-- arrival queue full, a jump before the due, a load, each event told once), e the own line and the output modes (suffix,
-- voice once, rm_own 0, remark_mode 0, a raising Message, scarold, trf_remark absent), f gates (a quest naming the system,
-- a mission naming it, a deny entry with remark = 0, the start-system guard, sys_off, __disableAction at entry,
-- __sys_SOS and a scene between queue and due), g save and repair (TRF_Rm_Fix, trf_captain's dl, the size bound, the RU
-- file) and the off-screen sweep scar in the base system (owner decision 6).
-- Loads host_station.lua up to its first scenario, as host_scar.lua does. Stubs in this file: squad pilots in HOST().crew
-- (RM_Crew: IsAlive, GetSide, IsCanSayReplica, an err field that makes one method raise, Message recording the template).

local f = openfile((getenv("TRF_TESTS") or "./").."host_station.lua", "r");
if not f then print("HOST FAIL host_remark.lua: cannot open host_station.lua"); exit(1); end;
local src = read(f, "*a");
closefile(f);
local cut = strfind(src, "\n-- a: install (12.1, 6.1)", 1, 1);
if not cut then print("HOST FAIL host_remark.lua: marker '-- a: install (12.1, 6.1)' missing in host_station.lua"); exit(1); end;
dostring(strsub(src, 1, cut), "host_station.lua");

-- Helpers ----------------------------------------------------------------------------------

-- Config of these runs: the repo defaults with the entry events that would claim lines or slots on their own turned off,
-- scars off (rm-e turns them on), warnings off, log 2, plus t.
function RM_Cfg(t)
	local c = {sweeps=0, feq=0, staged=0, seed=0, queue=0, parked=0, voice_events=0, dconv=0, carriers=0, po=0,
		enable_survivors=0, enable_scars=0, enable_stashes=0, enable_freight=0, warn=0, log=2};
	if t then for k, v in t do c[k] = v; end; end;
	return c;
end;

-- Squad pilots for GetPilot: t = {<template> = {alive, side (default "Player"), csr, err = alive|side|csr|msg}}.
function RM_Crew(t)
	local h = HOST();
	h.crew = {};
	for tpl, e in t do
		local p = HOST_Pilot(tpl);
		p.alive = e.alive; p.side = e.side or "Player"; p.csr = e.csr; p.err = e.err;
		p.IsAlive = function(self)
			if self.err == "alive" then error("injected IsAlive error"); end;
			if self.alive then return 1; end;
			return nil;
		end;
		p.GetSide = function(self)
			if self.err == "side" then error("injected GetSide error"); end;
			return self.side;
		end;
		p.IsCanSayReplica = function(self)
			if self.err == "csr" then error("injected IsCanSayReplica error"); end;
			if self.csr then return 1; end;
			return 0;
		end;
		p.Message = function(self, text, secs)
			HOST_Want(type(text) == "string" and type(secs) == "number", "Pilot:Message(text, secs)");
			if self.err == "msg" then error("injected Message error"); end;
			print("HOST Message "..self.tpl..": "..tostring(text));
			tinsert(HOST().msgs, {t=text, gt=HOST().gt, tpl=self.tpl});
		end;
		h.crew[tpl] = p;
	end;
end;

-- The crew of chapters 4-10: the Hero and Lastochka (Ternie).
function RM_Crew0() RM_Crew({Hero={alive=1, csr=1}, Lastochka={alive=1, csr=1}}); end;

-- The scene of an entry runs HOST().rmhook after the module files are loaded and before TRF_OnEnter (an override of a
-- module function or a flag for this entry).
RM_Scene0 = T_Scene;
function T_Scene(sys)
	RM_Scene0(sys);
	local h = HOST();
	if h.rmhook then h.rmhook(); end;
end;

-- Scenario start in sys at chapter label ch: no quest, no mission, no records.
function RM_Begin(sys, ch, t)
	local h = HOST();
	h.labels.CurrentQuest = ch or "6";
	h.quests = {};
	h.qs = FALSE;
	h.scsnap = {};
	h.block_r = 3;
	h.rmhook = nil;
	RM_Crew0();
	S_Begin(sys, RM_Cfg(t));
	TRF.scar = nil; TRF.rm = nil; TRF.base = {}; TRF.cap = nil;
	-- A campaign 100 legs in (event legs and captain death legs stay positive); no region catch-up from it.
	TRF.clock.legs = 100; TRF.clock.rt = 100;
end;

-- Scar record fixture of system idx (an off-screen trader wreck, placed, event leg leg), fields of t override.
function RM_Scar(idx, leg, t)
	local r = {sys=idx, k=0, kind=1, fac=0, x=0, y=0, z=0, leg=leg, ttl=30, on=0, mine=0, lv=2, seed=1234, nd=1, st=1, hid=0, scv=1,
		rec=0, nm=1, rf=0};
	if t then for k, v in t do r[k] = v; end; end;
	if type(TRF.scar) ~= "table" then TRF.scar = {}; end;
	for i = getn(TRF.scar), 1, -1 do if TRF.scar[i].sys == idx then tremove(TRF.scar, i); end; end;
	tinsert(TRF.scar, r);
	return r;
end;

-- Destroyed (D) base record of system idx at leg t.
function RM_Base(idx, t)
	if type(TRF.base) ~= "table" then TRF.base = {}; end;
	tinsert(TRF.base, {s=idx, k=3, h=0, t=t, w=0});
end;

-- Captain of region slot killed by an off-screen sweep at leg dl (record nm).
function RM_Cap(slot, nm, dl)
	if type(TRF.cap) ~= "table" then TRF.cap = {}; end;
	local home = TRF_RgMap()[slot].home;
	TRF.cap[slot] = {nm=nm, gen=1, st=4, tp=3, esc=0, noto=0, gr=0, gr_t=0, seen=home, due=0, lj=0, dj=0, born=0, met=0, last=0, dl=dl};
end;

-- Visit state of trf_remark cleared (a fresh entry without MapInitialization).
function RM_Fresh()
	local rm = TRF_RmRM();
	rm.done = nil; rm.own = {}; rm.tc = nil;
end;

-- Candidates and remark of system idx now (visit state fresh unless keep).
function RM_Pick(idx, keep)
	if not keep then RM_Fresh(); end;
	local s = TRF_RmIn(idx);
	local l = TRF_RmCandsOf(s);
	local rem = TRF_RmPickOf(l, s);
	return rem, l, s;
end;

-- Result word of the candidate of kind k in l, or nil.
function RM_Res(l, k)
	for i = 1, getn(l) do if l[i].k == k then return l[i].res; end; end;
	return nil;
end;

-- Entry into sys, then 20 game seconds of ticks (the arrival queue's due calls run).
function RM_Go(sys)
	T_Jump(sys);
	T_Tick(40, 0.5);
end;

-- Entry into sys with the location snapshot (as host_scar.lua's SC_Jump keep 1): the scar objects of sys left alive on
-- the last visit are back in the scene; then 20 game seconds of ticks.
function RM_GoK(sys)
	local h = HOST();
	TeleportToLocation(sys);
	local l = {};
	for i = 1, getn(h.ships) do
		local s = h.ships[i];
		if s.alive and type(s.label) == "string" and strsub(s.label, 1, 9) == "TRF_SCAR_" then tinsert(l, s); end;
	end;
	h.scsnap[h.loc] = l;
	h.last = h.loc; h.loc = sys;
	h.triggers = {}; h.ships = {}; h.screen = {}; h.msgs = {};
	if h.scsnap[sys] then
		for i = 1, getn(h.scsnap[sys]) do if h.scsnap[sys][i].alive then tinsert(h.ships, h.scsnap[sys][i]); end; end;
	end;
	print("HOST ---- enter "..sys.." (cleared "..HOST_ClearWithCarry().." globals)");
	HOST_MapInit();
	T_Scene(sys);
	TRF_OnEnter();
	TRF_OnActivate();
	T_Tick(40, 0.5);
end;

-- Event leg whose age is a at the next entry (an entry adds one leg).
function RM_L(a) return TRF.clock.legs + 1 - a; end;

-- Radio lines of the visit: texts joined by "|", and the templates.
function RM_Msgs()
	local q, s, t = HOST().msgs, "", "";
	for i = 1, getn(q) do s = s..q[i].t.."|"; t = t..tostring(q[i].tpl).."|"; end;
	return s, t;
end;

-- Screen lines of the visit joined by "|".
function RM_Scr()
	local q, s = HOST().screen, "";
	for i = 1, getn(q) do s = s..q[i].t.."|"; end;
	return s;
end;

function RM_ReadFile(p)
	local f = openfile(p, "rb");
	if not f then return nil; end;
	local s = read(f, "*a");
	closefile(f);
	return s;
end;

-- Number of plain occurrences of pat in s.
function RM_Count(s, pat)
	local n, i = 0, 1;
	if type(s) ~= "string" then return 0; end;
	while 1 do
		local a, b = strfind(s, pat, i, 1);
		if not a then break; end;
		n = n + 1;
		i = b + 1;
	end;
	return n;
end;

function RM_Has(s, sub) return strfind(s, sub, 1, 1) ~= nil; end;

-- Stamp of system idx in TRF.rm, or nil.
function RM_St(idx)
	if type(TRF.rm) ~= "table" then return nil; end;
	return TRF.rm[idx];
end;

-- Per-visit caches of the strict gate, after a change of HOST().quests or qs.
function RM_QCache()
	TRF.live.qa = nil; TRF.live.qai = nil; TRF_H().loc = nil; TRF.live.gl = nil;
end;

-- Systems of region 5 (Red Knives, home Kadi): gaoba (no quest, no base slot), altair (the region's base slot), kadi.
function RM_Sys()
	return V_Idx("gaoba"), V_Idx("altair"), V_Idx("kadi"), V_Slot("gaoba");
end;

-- a: install (12.1, 10, 11) -----------------------------------------------------------------

function T_RM_A()
	local h = HOST();
	RM_Begin("gaoba", "6");
	local g, al, kd, sl = RM_Sys();
	HOST_Check(S_Logs(0, "module=core event=loaded map=true module_count=18 extra_count=17") >= 1, "trf_remark loads last (extra_count=17)");
	local ml, tf, uf = TRF_ModList(), TRF_Loc_TextFns(), TRF_UI_TextFns();
	HOST_Check(ml[getn(ml)] == "Rm" and tf[getn(tf) - 1] == "TRF_Rm_Text" and tf[getn(tf)] == "TRF_Loc_Text" and uf[getn(uf)] == "TRF_Rm_Text",
		"TRF_ModList ends with Rm; TRF_Rm_Text before TRF_Loc_Text and last in TRF_UI_TextFns");
	HOST_Check(g == 42 and al == 2 and kd == 52 and sl == 5 and TRF_RgMap()[sl].home == kd and TRF_BaseAllowed(al), "fixture: gaoba 42, altair 2 (base slot), kadi 52 (home) in region 5");
	-- Text keys (9): 14, plain sentences without %, # or a line break; the loc layer finds each one.
	local tx = TRF_Rm_Text();
	local n, bad = 0, "";
	for k, v in tx do
		n = n + 1;
		if strfind(v, "%", 1, 1) or strfind(v, "#", 1, 1) or strfind(v, "\n", 1, 1) or strsub(k, 1, 2) ~= "rm" then bad = bad.." "..k; end;
		if TRF_Txt(k) == k then bad = bad.." unknown:"..k; end;
	end;
	HOST_Check(n == 14 and bad == "", "14 rm text keys, no %, # or line break, every key found by TRF_Txt"..bad);
	-- Defaults and clamps (10).
	local T = TRF_RmTune();
	HOST_Check(TRF_Opt("remarks") == 1 and TRF_Opt("remark_mode") == 1 and T.rm_ch == 0 and T.rm_ch_late == 5 and T.rm_age == 40
		and T.rm_secs == 8 and T.rm_csr == 1 and T.rm_own == 1 and TRF_RmK().keep == 4, "cfg remarks 1, remark_mode 1; tune rm_ch 0, rm_ch_late 5, rm_age 40, rm_secs 8, rm_csr 1, rm_own 1; keep 4");
	h.cfg.tune = {rm_age=999, rm_ch=-3, rm_secs=1, rm_csr=7};
	T = TRF_RmTune();
	HOST_Check(T.rm_age == 200 and T.rm_ch == 0 and T.rm_secs == 3 and T.rm_csr == 1, "tune clamps: rm_age 200, rm_ch 0, rm_secs 3, rm_csr 1");
	h.cfg.tune = nil;
	h.cfg.remark_mode = 5;
	HOST_Check(TRF_RmOpt("remark_mode") == 1, "remark_mode out of range reads the default 1");
	h.cfg.remark_mode = nil;
	-- Dump (log 1).
	local n0 = S_Mark();
	TRF.rm = {[42]=3, [7]=1, f=0};
	TRF_Rm_Dump();
	HOST_Check(S_Logs(n0, "module=remark event=dump floor=0 stamp_count=2 stamps=7:1,42:3 remark_mode=1") == 1, "dump line");
	TRF.rm = nil;
	-- An eligible trader record: the remark is queued at the entry and plays as radio.
	RM_Scar(g, RM_L(12), {nm=2});
	n0 = S_Mark();
	RM_Go("gaoba");
	local said = RM_Msgs();
	HOST_Check(S_Logs(n0, "module=remark event=remark system=gaoba system_index=42 kind=trader") == 1
		and S_Logs(n0, "module=plumb event=arrival_line owner=remark line_index=1 ") == 1 and S_Logs(n0, "voiced=true result=queued") == 1
		and RM_Has(said, "The freighter Albatross went missing here 12 days back. Pirates, most likely."), "entry: one remark queued and said: "..said);
	-- remarks 0: no queue call, the scar's own line as before (scars on, a fresh record placed at the entry).
	RM_Begin("gaoba", "6", {remarks=0, enable_scars=1});
	n0 = S_Mark();
	RM_Go("kadi");
	RM_Scar(g, RM_L(1), {st=0});
	RM_Go("gaoba");
	local line = TRF_Txt("scararrivet0", "Kestrel");
	HOST_Check(S_Logs(n0, "owner=remark") == 0 and S_Logs(n0, "module=remark event=say") == 0 and S_Logs(n0, "module=remark event=skip system=- reason=off") >= 1
		and RM_Has(RM_Scr(), line.."|") and not RM_Has(RM_Scr(), "That was") and TRF.rm == nil, "remarks 0: no remark, the scar line unchanged ("..RM_Scr()..")");
end;

-- b: speaker function (5) ---------------------------------------------------------------------

function T_RM_B()
	local h = HOST();
	RM_Begin("gaoba", "6");
	-- Pure order with a stub probe.
	local P = function(tpl, csr)
		local w = {Lastochka2="absent", Lastochka="dead", Hero="ok"};
		if w[tpl] == "ok" then return {tpl=tpl}, "ok"; end;
		return nil, w[tpl] or "absent";
	end;
	local tpl, tried = TRF_RmVoiceOf(TRF_CrewVoiceTab().pirate, P, 1);
	HOST_Check(tpl == "Hero" and tried == "Lastochka2:absent,Lastochka:dead,Hero:ok", "TRF_RmVoiceOf: the first that passes, tried list "..tostring(tried));
	HOST_Check(TRF_RmVoiceOf(nil, P, 1) == nil and TRF_RmScarVoice(3, 2) == "navy" and TRF_RmScarVoice(3, 0) == "pirate" and TRF_RmScarVoice(1, 0) == "pirate",
		"no list: nobody; scar voice navy for navy hulls, pirate otherwise");
	local V = function(kind)
		local n0 = S_Mark();
		local p, t = TRF_CrewVoice(kind);
		return t, S_Line(n0, "module=remark event=voice "), p;
	end;
	-- Nobody aboard.
	RM_Crew({});
	local t, ln = V("pirate");
	HOST_Check(t == "no_speaker" and RM_Has(ln, "voice=pirate speaker=nil tried=Lastochka2:absent,Lastochka:absent,Hero:absent"), "no crew: no_speaker ("..ln..")");
	-- The Hero only.
	RM_Crew({Hero={alive=1, csr=1}});
	t, ln = V("pirate");
	HOST_Check(t == "Hero" and RM_Has(ln, "speaker=Hero tried=Lastochka2:absent,Lastochka:absent,Hero:ok"), "Hero only: the Hero speaks for the pirates");
	-- Lastochka dead (missions 11_1, 11_2), Lastochka2 alive.
	RM_Crew({Hero={alive=1, csr=1}, Lastochka={csr=1}});
	t, ln = V("pirate");
	HOST_Check(t == "Hero" and RM_Has(ln, "tried=Lastochka2:absent,Lastochka:dead,Hero:ok"), "Lastochka dead: skipped, the Hero");
	RM_Crew({Hero={alive=1, csr=1}, Lastochka={alive=1, csr=1}, Lastochka2={alive=1, csr=1}, Kalem={alive=1, csr=1}});
	t, ln = V("pirate");
	local t2, ln2 = V("navy");
	HOST_Check(t == "Lastochka2" and RM_Has(ln, "tried=Lastochka2:ok") and t2 == "Kalem" and RM_Has(ln2, "voice=navy speaker=Kalem tried=Kalem:ok"),
		"chapters 13+: Lastochka2 for pirate records, Kalem for navy records");
	-- Kalem on another side, silent, raising.
	RM_Crew({Hero={alive=1, csr=1}, Kalem={alive=1, csr=1, side="Trade"}});
	t, ln = V("navy");
	HOST_Check(t == "Hero" and RM_Has(ln, "tried=Kalem:side,Hero:ok"), "Kalem not on the player side: skipped");
	RM_Crew({Hero={alive=1, csr=1}, Kalem={alive=1}});
	t, ln = V("navy");
	HOST_Check(t == "Hero" and RM_Has(ln, "tried=Kalem:silent,Hero:ok"), "Kalem cannot say a replica (rm_csr 1): skipped");
	h.cfg.tune = {rm_csr=0};
	t, ln = V("navy");
	HOST_Check(t == "Kalem" and RM_Has(ln, "tried=Kalem:ok"), "rm_csr 0: IsCanSayReplica not asked");
	h.cfg.tune = nil;
	RM_Crew({Hero={alive=1, csr=1}, Kalem={alive=1, csr=1, err="side"}});
	t, ln = V("navy");
	HOST_Check(t == "Hero" and RM_Has(ln, "tried=Kalem:error,Hero:ok") and S_Logs(0, "event=error message=") == 0, "a raising GetSide: only that template skipped, no error line");
	-- The crew voice, a template list (B03), an unknown voice.
	RM_Crew({Hero={alive=1, csr=1}, Lastochka={alive=1, csr=1}});
	t, ln = V("crew");
	local t3, ln3 = V({"Lastochka2", "Lastochka"});
	local t4, ln4 = V("veteran");
	HOST_Check(t == "Hero" and t3 == "Lastochka" and RM_Has(ln3, "voice=list speaker=Lastochka tried=Lastochka2:absent,Lastochka:ok") and t4 == "no_speaker"
		and RM_Has(ln4, "tried=-"), "crew voice: the Hero; a template list; an unknown voice finds nobody");
	-- TRF_CrewSay: radio (remark_mode 1) with the portrait, live.line stamped.
	h.msgs = {};
	TRF.live.line = nil;
	local ok, how, who = TRF_CrewSay("pirate", "host remark", 8);
	local said, tpls = RM_Msgs();
	HOST_Check(ok == 1 and how == "radio" and who == "Lastochka" and said == "host remark|" and tpls == "Lastochka|" and TRF.live.line == TRF.clock.gt,
		"TRF_CrewSay radio: Lastochka's Message, live.line = gt");
	-- remark_mode 0: the screen line with the name.
	h.cfg.remark_mode = 0;
	local s0 = getn(h.screen);
	ok, how, who = TRF_CrewSay("pirate", "host remark", 8);
	HOST_Check(ok == 1 and how == "line" and S_Screen(s0, "Ternie: host remark") and getn(h.msgs) == 1, "remark_mode 0: screen line 'Ternie: host remark'");
	h.cfg.remark_mode = nil;
	-- A raising Message: the screen line, reason msg_error.
	RM_Crew({Hero={alive=1, csr=1, err="msg"}});
	s0 = getn(h.screen);
	local fb = nil;
	h.rmr = {};
	local ne = S_Expect(function() local r = HOST().rmr; r[1], r[2], r[3], r[4] = TRF_CrewSay("crew", "host remark", 8); end);
	ok, how, who, fb = h.rmr[1], h.rmr[2], h.rmr[3], h.rmr[4];
	HOST_Check(ne == 1 and ok == 1 and how == "line" and fb == "msg_error" and S_Screen(s0, "Hero: host remark"), "Message raising: the screen line 'Hero: host remark', reason msg_error");
	-- Suppressed and nobody.
	__disableAction = TRUE;
	ok, how = TRF_CrewSay("crew", "host remark", 8);
	__disableAction = FALSE;
	HOST_Check(ok == nil and how == "supp:flag", "__disableAction: nil, supp:flag");
	RM_Crew({});
	ok, how = TRF_CrewSay("crew", "host remark", 8);
	HOST_Check(ok == nil and how == "no_speaker", "nobody: nil, no_speaker");
	-- Never CreatePilot or GetPlayerMotherShip (the crew is read with GetPilot only).
	local cp = 0;
	local cp0 = CreatePilot;
	CreatePilot = function(t) local q = %cp0(t); HOST().rm_cp = (HOST().rm_cp or 0) + 1; return nil; end;
	RM_Crew0();
	TRF_CrewSay("pirate", "host remark", 8);
	CreatePilot = cp0;
	HOST_Check((h.rm_cp or 0) == 0, "no CreatePilot of a story template");
end;

-- c: record kinds and texts (4, 9) --------------------------------------------------------------

function T_RM_C()
	local h = HOST();
	RM_Begin("gaoba", "6");
	local g, al, kd, sl = RM_Sys();
	local L = TRF.clock.legs;
	local rem, l = nil, nil;
	-- Trader scar aged 12, placed, not fresh.
	RM_Scar(g, L - 12, {nm=1});
	rem, l = RM_Pick(g);
	HOST_Check(rem and rem.k == "trader" and rem.v == "pirate" and rem.key == "rmtrader" and TRF_RmText(rem) == "The freighter Kestrel went missing here 12 days back. Pirates, most likely.",
		"trader: "..(rem and TRF_RmText(rem) or "none"));
	-- Ages (D13): 0, 1, 25, 40 (in), 41 (out).
	local A = function(a)
		RM_Scar(%g, %L - a);
		local r = RM_Pick(%g);
		if not r then return nil; end;
		return TRF_RmText(r);
	end;
	HOST_Check(A(0) == "The freighter Kestrel went missing here earlier today. Pirates, most likely." and RM_Has(A(1) or "", " here yesterday.")
		and RM_Has(A(25) or "", " here 25 days back.") and RM_Has(A(40) or "", " here 40 days back.") and A(41) == nil, "age phrases: earlier today, yesterday, 25 days back; rm_age 40 keeps 40, drops 41");
	RM_Scar(g, L - 41);
	rem, l = RM_Pick(g);
	HOST_Check(RM_Res(l, "trader") == "old", "41 legs: result old");
	HOST_Check(TRF_RmAgeOf(0) == "rmage0" and TRF_RmAgeOf(1) == "rmage1" and TRF_RmAgeOf(7) == "rmagen" and TRF_Rm_AgeText(L - 7) == "7 days back", "TRF_RmAgeOf, TRF_Rm_AgeText");
	-- Sweep scars: navy hulls (failed, faction 2), pirate hulls (won).
	RM_Scar(g, L - 9, {kind=3, fac=2});
	rem, l = RM_Pick(g);
	HOST_Check(rem and rem.k == "sweep_navy" and rem.v == "navy" and TRF_RmText(rem) == "New Empire sent a fleet against the Red Knives here 9 days back and lost it.",
		"sweep navy: "..(rem and TRF_RmText(rem) or "none"));
	RM_Scar(g, L - 3, {kind=3, fac=0});
	rem = RM_Pick(g);
	HOST_Check(rem and rem.k == "sweep_pirate" and rem.v == "pirate" and TRF_RmText(rem) == "A sweep caught the Red Knives here 3 days back.", "sweep pirate: "..(rem and TRF_RmText(rem) or "none"));
	-- Base D record (altair) and a captain killed by a sweep (home kadi; the sweep scar elsewhere would hide him, K3).
	RM_Base(al, L - 1);
	rem = RM_Pick(al);
	HOST_Check(rem and rem.k == "base" and rem.v == "pirate" and TRF_RmText(rem) == "The Red Knives lost their base here yesterday." and rem.h == nil,
		"base: "..(rem and TRF_RmText(rem) or "none"));
	TRF.base = {};
	RM_Cap(sl, 3, L - 5);
	rem = RM_Pick(kd);
	local cn = TRF_CapNm(TRF.cap[sl]);
	HOST_Check(rem and rem.k == "captain" and TRF_RmText(rem) == "A sweep caught "..cn.." here 5 days back. The Red Knives lost their captain.", "captain: "..(rem and TRF_RmText(rem) or "none"));
	HOST_Check(RM_Pick(g) and RM_Pick(g).k == "sweep_pirate", "the captain counts only in the home system");
	TRF.cap[sl].st = 1;
	HOST_Check(RM_Pick(kd) == nil, "a living captain: no remark");
	TRF.cap = nil;
	-- Chapter 3: trader yes, sweep no (rm_ch 0, rm_ch_late 5).
	h.labels.CurrentQuest = "3";
	RM_Scar(g, L - 4);
	HOST_Check(RM_Pick(g) and RM_Pick(g).k == "trader", "chapter 3: trader remark");
	RM_Scar(g, L - 4, {kind=3, fac=2});
	rem, l = RM_Pick(g);
	HOST_Check(rem == nil and RM_Res(l, "sweep_navy") == "chapter", "chapter 3: no sweep remark (result chapter)");
	h.cfg.tune = {rm_ch=4};
	RM_Scar(g, L - 4);
	rem, l = RM_Pick(g);
	HOST_Check(rem == nil and RM_Res(l, "trader") == "chapter", "rm_ch 4: no trader remark in chapter 3");
	h.cfg.tune = nil;
	-- Chapter 5: no trader remark in Corrino (the freight sub-plot rule), a sweep there is told.
	h.labels.CurrentQuest = "5";
	local co = V_Idx("corrino");
	RM_Scar(co, L - 4);
	rem, l = RM_Pick(co);
	HOST_Check(rem == nil and RM_Res(l, "trader") == "ch5", "chapter 5 Corrino: trader excluded (result ch5)");
	RM_Scar(co, L - 4, {kind=3, fac=1});
	HOST_Check(RM_Pick(co) and RM_Pick(co).k == "sweep_navy", "chapter 5 Corrino: a sweep is told");
	h.labels.CurrentQuest = "6";
	-- On-screen, hidden and opened records, convoy and base wrecks: no candidate.
	local none = 1;
	for i, t in {{on=1}, {hid=1}, {st=2}, {st=3}, {kind=2}, {kind=4}} do
		RM_Scar(g, L - 4, t);
		local r, q = RM_Pick(g);
		if r or getn(q) > 0 then none = nil; end;
	end;
	HOST_Check(none, "on-screen, hidden, opened and stripped records, convoy and base wrecks: no candidate");
	-- Chapter 2: an unplaced record (st 0, visual mode) is told; the remark names no wreck.
	h.labels.CurrentQuest = "2";
	RM_Scar(g, L - 6, {st=0});
	HOST_Check(RM_Pick(g) and RM_Pick(g).k == "trader", "chapter 2: an unplaced record is eligible");
	h.labels.CurrentQuest = "6";
	-- A refreshed record dates the refresh (K5): its leg is the refresh leg.
	RM_Scar(g, L - 2, {rf=1});
	HOST_Check(RM_Has(TRF_RmText(RM_Pick(g)), " 2 days back."), "a refreshed record dates the refresh");
	-- The entry logs every candidate with its result (level 2) and the remark (level 1).
	TRF.scar = nil;
	RM_Scar(g, RM_L(12), {nm=1});
	local n0 = S_Mark();
	RM_Go("gaoba");
	HOST_Check(S_Logs(n0, "module=remark event=candidate system_index=42 kind=trader event_leg="..RM_L(13).." age=12 result=ok") == 1
		and S_Logs(n0, "module=remark event=remark system=gaoba system_index=42 kind=trader event_leg="..RM_L(13).." age=12 voice=pirate speaker=Lastochka clause=false candidate_count=1 result=queued") == 1,
		"entry logs: candidate result=ok, remark result=queued");
end;

-- d: told rules (8) -------------------------------------------------------------------------------

function T_RM_D()
	local h = HOST();
	RM_Begin("gaoba", "6");
	local g, al, kd, sl = RM_Sys();
	-- Pure: stamps, cap 4, floor, prune.
	local rm, ev = TRF_RmStampOf(nil, 1, 10, 4);
	rm, ev = TRF_RmStampOf(rm, 1, 8, 4);
	HOST_Check(rm[1] == 10 and ev == nil, "stamp keeps the larger leg");
	for i = 2, 5 do rm, ev = TRF_RmStampOf(rm, i, 10 + i, 4); end;
	HOST_Check(TRF_RmCountOf(rm) == 4 and rm[1] == nil and rm.f == 10 and ev == 1, "a fifth stamp evicts the smallest leg; floor 10");
	HOST_Check(TRF_RmToldOf(rm, 9, 10) == "floor" and TRF_RmToldOf(rm, 9, 11) == nil and TRF_RmToldOf(rm, 3, 13) == "told", "floor: leg 10 told everywhere, 11 not");
	rm, ev = TRF_RmStampOf(rm, 6, 9, 4);
	HOST_Check(rm[6] == nil and ev == 6 and rm.f == 10, "a stamp older than all others is evicted at once; the floor stays");
	local pr, d = TRF_RmPruneOf({[1]=10, [2]=50, f=5}, 60, 40);
	HOST_Check(pr[1] == nil and pr[2] == 50 and pr.f == nil and d == 1, "prune: past rm_age dropped, the floor too");
	pr = TRF_RmPruneOf({[1]=10}, 60, 40);
	HOST_Check(pr == nil, "prune: empty -> nil");
	-- Two events in kadi: the trader scar (older) first, the captain on the next entry, then nothing.
	RM_Scar(kd, RM_L(20), {nm=3});
	RM_Cap(sl, 4, RM_L(6));
	local n0 = S_Mark();
	RM_Go("kadi");
	local said = RM_Msgs();
	HOST_Check(RM_Has(said, "The freighter Heron went missing here 20 days back.") and not RM_Has(said, "lost their captain") and RM_St(kd) == RM_L(21),
		"first entry: the oldest event (the trader), stamped "..tostring(RM_St(kd)));
	RM_Go("gaoba");
	RM_Go("kadi");
	said = RM_Msgs();
	HOST_Check(RM_Has(said, "here 8 days back. The Red Knives lost their captain."), "second entry: the captain ("..said..")");
	RM_Go("gaoba");
	n0 = S_Mark();
	RM_Go("kadi");
	HOST_Check(RM_Msgs() == "" and S_Logs(n0, "module=remark event=skip system=kadi reason=none") == 1 and S_Logs(n0, "kind=captain event_leg=") == 1
		and S_Logs(n0, "result=told") == 2, "third entry: both told, no remark");
	-- Same leg in one system: one remark, the captain as its clause.
	TRF.rm = nil;
	local lc = RM_L(4);
	RM_Scar(kd, lc, {kind=3, fac=0});
	RM_Cap(sl, 5, lc);
	RM_Go("gaoba");
	n0 = S_Mark();
	RM_Go("kadi");
	said = RM_Msgs();
	local cn = TRF_CapNm(TRF.cap[sl]);
	HOST_Check(RM_Has(said, "A sweep caught the Red Knives here 5 days back. "..cn.." went down with them.|") and S_Logs(n0, "clause=true candidate_count=2") == 1
		and S_Logs(n0, "kind=captain event_leg="..lc.." age=5 result=merged") == 1, "same leg: the sweep remark with the captain clause ("..said..")");
	-- Sweep family, new placement: base D record and sweep scar in altair, the captain dead in kadi, all at one leg.
	TRF.rm = nil; TRF.scar = nil; TRF.base = {};
	local lf = RM_L(3);
	RM_Base(al, lf);
	RM_Scar(al, lf, {kind=3, fac=0});
	RM_Cap(sl, 6, lf);
	cn = TRF_CapNm(TRF.cap[sl]);
	n0 = S_Mark();
	RM_Go("kadi");
	HOST_Check(RM_Msgs() == "" and S_Logs(n0, "kind=captain event_leg="..lf.." age=3 result=elsewhere") == 1, "home while the D record lives: the captain is told in the base system");
	RM_Go("altair");
	said = RM_Msgs();
	HOST_Check(RM_Has(said, "The Red Knives lost their base here 4 days back. "..cn.." went down with them.|") and RM_St(al) == lf and RM_St(kd) == lf,
		"base system: the base remark with the captain clause; stamps base system and home ("..said..")");
	TRF.base = {};
	n0 = S_Mark();
	RM_Go("kadi");
	HOST_Check(RM_Msgs() == "" and S_Logs(n0, "kind=captain event_leg="..lf.." age=5 result=told") == 1, "D record gone: the captain stays told at home");
	-- Old placement (a save from before the fix): sweep scar at home, base in altair.
	TRF.rm = nil; TRF.scar = nil; TRF.base = {}; TRF.cap = nil;
	lf = RM_L(2);
	RM_Base(al, lf);
	RM_Scar(kd, lf, {kind=3, fac=0});
	n0 = S_Mark();
	RM_Go("kadi");
	HOST_Check(RM_Msgs() == "" and S_Logs(n0, "kind=sweep_pirate event_leg="..lf.." age=2 result=elsewhere") == 1, "old placement: the home's sweep scar waits for the base system");
	RM_Go("altair");
	HOST_Check(RM_Has(RM_Msgs(), "The Red Knives lost their base here 3 days back.|") and RM_St(kd) == lf, "old placement: the base remark stamps the home too");
	-- Five systems told: the cap evicts the oldest stamp and raises the floor.
	TRF.rm = nil; TRF.scar = nil; TRF.base = {};
	local sys5 = {"gaoba", "sunji", "b_leftera2", "b_leftera3", "x244"};
	for i = 1, 5 do RM_Scar(V_Idx(sys5[i]), RM_L(10 - i)); end;
	for i = 1, 5 do RM_Go(sys5[i]); end;
	HOST_Check(TRF_RmCountOf(TRF.rm) == 4 and RM_St(V_Idx("gaoba")) == nil and type(TRF.rm.f) == "number", "five systems told: four stamps and the floor ("..TRF_RmCountOf(TRF.rm)..")");
	n0 = S_Mark();
	RM_Go("gaoba");
	HOST_Check(RM_Msgs() == "" and S_Logs(n0, "result=floor") == 1, "the evicted event is not told again (floor)");
	-- A base the player destroys during the visit: stamped at the jump (witness), no remark on re-entry.
	TRF.rm = nil; TRF.scar = nil; TRF.base = {};
	RM_Go("altair");
	RM_Base(al, TRF.clock.legs);
	n0 = S_Mark();
	RM_Go("kadi");
	HOST_Check(RM_St(al) == TRF.clock.legs - 1 and S_Logs(n0, "module=remark event=told system_index=2 event_leg="..(TRF.clock.legs - 1).." via=witness") == 1, "jump after a base fell in view: witness stamp");
	n0 = S_Mark();
	RM_Go("altair");
	HOST_Check(RM_Msgs() == "" and S_Logs(n0, "kind=base") == 1 and S_Logs(n0, "result=told") == 1, "re-entry: no remark about it");
	-- The arrival queue full before the remark: dropped (cap), not stamped, told on the next entry.
	TRF.rm = nil; TRF.base = {};
	RM_Scar(g, RM_L(8));
	h.rmhook = function() TRF_Wn_OnActivate = function() for i = 1, 3 do TRF_ArrivalLine("host", "filler "..i); end; end; end;
	n0 = S_Mark();
	RM_Go("gaoba");
	h.rmhook = nil;
	HOST_Check(S_Logs(n0, "module=remark event=remark system=gaoba") == 1 and S_Logs(n0, "result=dropped reason=cap") == 2 and RM_Msgs() == "" and RM_St(g) == nil,
		"queue full: the remark dropped (cap), nothing stamped");
	RM_Go("kadi");
	RM_Go("gaoba");
	HOST_Check(RM_Has(RM_Msgs(), "went missing here 10 days back") and RM_St(g) == RM_L(11), "next entry: told");
	-- A jump before the due: not stamped; a load: no line.
	TRF.rm = nil;
	RM_Scar(g, RM_L(5));
	T_Jump("gaoba");
	T_Tick(4, 0.5);
	n0 = S_Mark();
	RM_Go("kadi");
	HOST_Check(RM_St(g) == nil and S_Logs(n0, "module=remark event=say owner=remark") == 0, "a jump before the due: not shown, not stamped");
	T_Jump("gaoba");
	T_Tick(4, 0.5);
	n0 = S_Mark();
	T_SaveLoad();
	T_Tick(40, 0.5);
	HOST_Check(RM_St(g) == nil and S_Logs(n0, "module=remark event=say") == 0 and S_Logs(n0, "module=remark event=remark") == 0, "a load before the due: no line, not stamped");
	-- Each told event was said once over the scenario.
	local seen, twice = {}, "";
	for i = 1, getn(h.logs) do
		local ln = h.logs[i];
		if strfind(ln, "module=remark event=say owner=remark", 1, 1) and strfind(ln, "result=shown", 1, 1) then
			local a, b, si, el = strfind(ln, "system_index=(%d+) event_leg=(%-?%d+)");
			local k = tostring(si)..":"..tostring(el);
			if seen[k] then twice = twice.." "..k; end;
			seen[k] = 1;
		end;
	end;
	HOST_Check(twice == "", "no event said twice (TRF.rm reset between the parts)"..twice);
end;

-- e: own line and output (7.2, 5.3) ----------------------------------------------------------------

function T_RM_E()
	local h = HOST();
	RM_Begin("gaoba", "6", {enable_scars=1, cycle=0});
	local g, al, kd, sl = RM_Sys();
	local line = TRF_Txt("scararrivet0", "Kestrel");
	-- A fresh trader wreck at home and a captain killed a leg later: the own line gets the age, is voiced, and blocks the
	-- remark (one crew line per entry); the captain follows on the next entry.
	RM_Scar(kd, RM_L(2), {st=0});
	RM_Cap(sl, 2, RM_L(1));
	local n0 = S_Mark();
	RM_GoK("kadi");
	local said, tpls = RM_Msgs();
	local lk = TRF.scar[1].leg;
	HOST_Check(said == line.." That was 2 days back.|" and tpls == "Lastochka|" and RM_St(kd) == lk and S_Logs(n0, "module=remark event=own owner=scar system_index=52 event_leg="..lk.." age=2 voice=pirate voiced=true result=suffix") == 1
		and S_Logs(n0, "module=remark event=skip system=kadi reason=done") == 1 and S_Logs(n0, "module=plumb event=arrival_line owner=scar line_index=1 ") == 1
		and S_Logs(n0, "module=remark event=say owner=scar system_index=52 event_leg="..lk.." voice=pirate speaker=Lastochka output=radio result=shown") == 1,
		"fresh own line: suffix, voiced by Ternie, stamped at the due, the remark waits ("..said..")");
	-- Re-entry while still fresh: suffix, told -> no voice, the screen line; the captain is told now.
	RM_GoK("gaoba");
	n0 = S_Mark();
	RM_GoK("kadi");
	said = RM_Msgs();
	HOST_Check(RM_Has(RM_Scr(), line.." That was 4 days back.|") and not RM_Has(said, "FTU beacon") and RM_Has(said, "lost their captain")
		and S_Logs(n0, "voiced=false result=told") == 1, "re-entry: suffix, a screen line, the captain remark ("..said..")");
	-- rm_own 0: the own line unvoiced (screen line, stamped as own), the remark still plays.
	TRF.rm = nil; TRF.scar = nil;
	h.cfg.tune = {rm_own=0};
	RM_Scar(kd, RM_L(1), {st=0});
	RM_Cap(sl, 2, RM_L(9));
	n0 = S_Mark();
	RM_Go("kadi");
	said = RM_Msgs();
	HOST_Check(RM_Has(RM_Scr(), line.." That was yesterday.|") and RM_Has(said, "lost their captain") and not RM_Has(said, "FTU beacon")
		and S_Logs(n0, "module=remark event=told system_index=52 event_leg="..TRF.scar[1].leg.." via=own") == 1, "rm_own 0: own line on screen and stamped, the remark as radio");
	h.cfg.tune = nil;
	-- remark_mode 0: the remark as "Ternie: ..." on screen, the own line unvoiced.
	TRF.rm = nil; TRF.scar = nil;
	h.cfg.remark_mode = 0;
	RM_Scar(kd, RM_L(1), {st=0});
	RM_Cap(sl, 2, RM_L(9));
	n0 = S_Mark();
	RM_Go("kadi");
	local scr = RM_Scr();
	HOST_Check(RM_Msgs() == "" and RM_Has(scr, line.." That was yesterday.|") and RM_Has(scr, "|Ternie: A sweep caught ") and S_Logs(n0, "output=line result=shown") == 2,
		"remark_mode 0: the own line plain, the remark 'Ternie: ...' ("..scr..")");
	h.cfg.remark_mode = nil;
	-- Message raising: the remark falls back to the screen line (reason msg_error).
	TRF.rm = nil; TRF.scar = nil;
	RM_Crew({Hero={alive=1, csr=1}, Lastochka={alive=1, csr=1, err="msg"}});
	RM_Cap(sl, 2, RM_L(9));
	n0 = S_Mark();
	local ne = S_Expect(function() RM_Go("kadi"); end);
	HOST_Check(ne == 1 and RM_Has(RM_Scr(), "Ternie: A sweep caught ") and S_Logs(n0, "owner=remark system_index=52") == 1 and S_Logs(n0, "output=line result=shown reason=msg_error") == 1
		and RM_St(kd) == TRF.cap[sl].dl, "Message raising: the screen line, stamped");
	RM_Crew0();
	-- No crew member for the own line: the beacon on screen, stamped.
	TRF.rm = nil; TRF.cap = nil;
	RM_Crew({});
	RM_Scar(g, RM_L(1), {st=0});
	n0 = S_Mark();
	RM_Go("gaoba");
	HOST_Check(RM_Has(RM_Scr(), line.." That was yesterday.|") and RM_St(g) == TRF.scar[1].leg and S_Logs(n0, "voiced=false result=suffix") == 1, "no speaker at the entry: the own line plain, stamped");
	RM_Crew0();
	-- scarold (an opened wreck) unchanged.
	TRF.rm = nil; TRF.scar = nil;
	RM_Scar(g, RM_L(3), {st=2});
	n0 = S_Mark();
	RM_Go("gaoba");
	HOST_Check(RM_Has(RM_Scr(), TRF_Txt("scarold").."|") and not RM_Has(RM_Scr(), "That was") and S_Logs(n0, "module=remark event=own") == 0, "scarold: unchanged ("..RM_Scr()..")");
	-- trf_remark absent: the scar line as before.
	TRF.rm = nil; TRF.scar = nil;
	RM_Scar(g, RM_L(1), {st=0});
	h.rmhook = function() TRF_Rm_Own = nil; TRF_Rm_OnActivate = nil; TRF_Rm_ArrSay = nil; end;
	n0 = S_Mark();
	RM_Go("gaoba");
	h.rmhook = nil;
	HOST_Check(RM_Has(RM_Scr(), line.."|") and not RM_Has(RM_Scr(), "That was") and RM_Msgs() == "" and TRF.rm == nil and S_Logs(n0, "module=remark event=own") == 0 and S_Logs(n0, "module=remark event=say") == 0,
		"without trf_remark: the scar line as before");
end;

-- f: gates (6) ---------------------------------------------------------------------------------------

function T_RM_F()
	local h = HOST();
	RM_Begin("gaoba", "6");
	local g, al, kd, sl = RM_Sys();
	local li = V_Idx("lidau");
	local qi = TRF_Map().sys[li].qi;
	-- A quest naming the system in process: skip gate:quest.
	RM_Scar(li, RM_L(5));
	h.rmhook = function() local h = HOST(); h.quests = {}; h.quests[%qi[1]] = QUEST_PROCESS; end;
	local n0 = S_Mark();
	RM_Go("lidau");
	h.rmhook = nil; h.quests = {};
	HOST_Check(S_Logs(n0, "module=remark event=skip system=lidau reason=gate:quest") == 1 and RM_Msgs() == "" and TRF.rm == nil, "a quest naming the system in process: skip gate:quest");
	-- A story mission running (cfg strict 2: every system denied during a mission; with strict 1 a system whose quest ids
	-- are known and none in process stays open, design 9.9 option 1).
	h.qs = TRUE; h.cfg.strict = 2;
	n0 = S_Mark();
	RM_Go("lidau");
	h.qs = FALSE; h.cfg.strict = nil;
	HOST_Check(S_Logs(n0, "module=remark event=skip system=lidau reason=gate:mission_all") == 1 and RM_Msgs() == "", "a mission running (strict 2): skip gate:mission_all");
	-- A deny entry with remark = 0.
	RM_Scar(g, RM_L(5));
	h.rmhook = function() local d0 = TRF_DenyEntry; TRF_DenyEntry = function(n) if n == "gaoba" then return {remark=0}; end; return %d0(n); end; end;
	n0 = S_Mark();
	RM_Go("gaoba");
	h.rmhook = nil;
	HOST_Check(S_Logs(n0, "module=remark event=skip system=gaoba reason=gate:deny_remark") == 1 and RM_Msgs() == "", "deny entry remark = 0: skip gate:deny_remark");
	-- The start-system guard in chapter 3.
	h.labels.CurrentQuest = "3";
	RM_Scar(V_Idx("ahilles"), RM_L(5));
	n0 = S_Mark();
	RM_Go("ahilles");
	HOST_Check(S_Logs(n0, "module=remark event=skip system=ahilles reason=mode:guard") == 1 and RM_Msgs() == "", "start system, chapter 3: skip mode:guard");
	h.labels.CurrentQuest = "6";
	-- sys_off.
	h.cfg.sys_off = {"gaoba"};
	n0 = S_Mark();
	RM_Go("gaoba");
	h.cfg.sys_off = nil;
	HOST_Check(S_Logs(n0, "module=remark event=skip system=gaoba reason=mode:sys_off") == 1, "sys_off: skip mode:sys_off");
	-- __disableAction at the entry.
	h.rmhook = function() __disableAction = TRUE; end;
	n0 = S_Mark();
	T_Jump("gaoba");
	h.rmhook = nil;
	__disableAction = FALSE;
	T_Tick(40, 0.5);
	HOST_Check(S_Logs(n0, "module=remark event=skip system=gaoba reason=hold:disable_action") == 1 and RM_Msgs() == "", "__disableAction at the entry: skip hold:disable_action");
	-- __sys_SOS between the queue and the due: not shown, not stamped; the next entry tells it.
	RM_Go("kadi");
	n0 = S_Mark();
	T_Jump("gaoba");
	__sys_SOS = TRUE;
	T_Tick(40, 0.5);
	__sys_SOS = FALSE;
	HOST_Check(S_Logs(n0, "module=remark event=remark system=gaoba") == 1 and S_Logs(n0, "result=not_shown reason=supp:quiet") == 1 and RM_St(g) == nil and RM_Msgs() == "",
		"__sys_SOS at the due: not shown (supp:quiet), not stamped");
	-- A scene at the due.
	RM_Go("kadi");
	n0 = S_Mark();
	T_Jump("gaoba");
	local im = TRF_InMovie;
	TRF_InMovie = HOST_InMovie; h.mov = 1;
	T_Tick(40, 0.5);
	TRF_InMovie = im; h.mov = nil;
	HOST_Check(S_Logs(n0, "result=not_shown reason=supp:quiet") == 1 and RM_St(g) == nil, "a scene at the due: not shown, not stamped");
	-- A quest of the system set in process between queue and due: not shown (gate).
	RM_Go("kadi");
	RM_Scar(li, RM_L(5));
	local st0 = RM_St(li);
	n0 = S_Mark();
	T_Jump("lidau");
	h.quests = {}; h.quests[qi[1]] = QUEST_PROCESS;
	RM_QCache();
	T_Tick(40, 0.5);
	h.quests = {};
	RM_QCache();
	HOST_Check(S_Logs(n0, "module=remark event=remark system=lidau") == 1 and S_Logs(n0, "result=not_shown reason=gate:quest") == 1 and RM_St(li) == st0,
		"a quest set in process before the due: not shown (gate:quest)");
	-- Finally told when nothing holds it.
	RM_Go("gaoba");
	HOST_Check(RM_St(g) ~= nil and RM_Has(RM_Msgs(), "went missing here"), "gaoba told once the gates pass");
end;

-- g: save and repair (3.1, 3.3), the sweep scar placement (16) ---------------------------------------

function T_RM_G()
	local h = HOST();
	RM_Begin("gaoba", "6");
	local g, al, kd, sl = RM_Sys();
	local legs = TRF.clock.legs;
	local n0 = S_Mark();
	TRF.rm = "x";
	TRF_Rm_Fix();
	HOST_Check(TRF.rm == nil and S_Logs(n0, "module=remark event=fix field=rm result=dropped") == 1, "repair: a string TRF.rm dropped");
	TRF.rm = {[1]=legs - 5, foo=3, [999]=2, [3]=legs + 5, [4]="x", [5.5]=1, f="y"};
	TRF_Rm_Fix();
	HOST_Check(TRF_RmCountOf(TRF.rm) == 1 and TRF.rm[1] == legs - 5 and TRF.rm.f == nil, "repair: bad keys, values above legs and a bad floor dropped");
	TRF.rm = {[1]=1, [2]=2, [3]=3, [4]=4, [5]=5, [6]=6, [7]=7, f=1};
	TRF_Rm_Fix();
	HOST_Check(TRF_RmCountOf(TRF.rm) == 4 and TRF.rm[4] == 4 and TRF.rm[7] == 7 and TRF.rm[3] == nil and TRF.rm.f == 3, "repair: 7 stamps -> the 4 largest, floor 3");
	TRF.rm = {f=legs};
	TRF_Rm_Fix();
	HOST_Check(TRF.rm.f == legs, "repair: a floor alone is kept");
	TRF.rm = {};
	TRF_Rm_Fix();
	HOST_Check(TRF.rm == nil, "repair: empty -> nil");
	-- trf_captain dl (D5): on a dead record only, a number within 0..legs.
	TRF.cap = {};
	RM_Cap(sl, 2, legs - 1);
	TRF_Cap_Fix();
	HOST_Check(TRF.cap[sl].dl == legs - 1, "captain repair keeps dl on a dead record");
	TRF.cap[sl].dl = "x";
	TRF_Cap_Fix();
	HOST_Check(TRF.cap[sl].dl == nil, "captain repair: a string dl dropped");
	TRF.cap[sl].dl = legs; TRF.cap[sl].st = 1;
	TRF_Cap_Fix();
	HOST_Check(TRF.cap[sl].dl == nil, "captain repair: dl on a living captain dropped");
	TRF.cap[sl].st = 4; TRF.cap[sl].dl = legs + 3;
	TRF_Cap_Fix();
	HOST_Check(TRF.cap[sl].dl == nil, "captain repair: dl above legs dropped");
	-- trf_captain writes dl at an off-screen sweep death, not at an on-screen one (D16).
	h.cfg.cap_enable = 1;
	local dead, on = 0, 0;
	for i = 1, 20 do
		local r = TRF.cap[sl];
		r.st = 1; r.esc = 0; r.lj = 0; r.dl = nil;
		TRF_Cap_Sweep(sl, legs + i, 1, "off");
		if TRF.cap[sl].st == 4 then
			if TRF.cap[sl].dl == legs then dead = dead + 1; else dead = -99; end;
		end;
		r = TRF.cap[sl];
		r.st = 1; r.esc = 0; r.lj = 0; r.dl = nil;
		TRF_Cap_Sweep(sl, legs + i, 1, "on");
		if TRF.cap[sl].st == 4 and TRF.cap[sl].dl ~= nil then on = on + 1; end;
	end;
	h.cfg.cap_enable = nil;
	HOST_Check(dead >= 4 and on == 0, "TRF_Cap_Sweep: dl = legs on "..dead.." off-screen deaths, none on screen");
	TRF.cap = nil;
	-- Size (3.3): 4 stamps and the floor at the host grammar.
	TRF.rm = {[110]=99999, [111]=99999, [112]=99999, [113]=99999, f=99999};
	local sz = HOST_SaveSize(TRF.rm) + 8 + strlen("rm");
	HOST_Check(sz <= 140, "TRF.rm worst case "..sz.." bytes <= 140");
	local full = 8 + 3 + HOST_SaveSize(TRF);
	HOST_Check(full < 100000, "TRF with TRF.rm: "..full.." bytes < 100000");
	TRF.rm = nil;
	-- RU fixed forms: the 14 keys, cp1251, CRLF.
	local ru = RM_ReadFile(h.dir.."../../../../loc/trf_ru.loc");
	local miss = "";
	local cr, lf = strchar(13), strchar(10);
	for k, v in TRF_Rm_Text() do
		if not (ru and strfind(ru, lf.."#TRF_"..TRF_LocKey(k).." = [^"..cr..lf.."]+"..cr..lf)) then miss = miss.." "..k; end;
	end;
	HOST_Check(ru and miss == "" and RM_Count(ru, "\n") == RM_Count(ru, "\r\n"), "loc/trf_ru.loc: the 14 rm keys, CRLF"..miss);
	-- EN scaffold: the 14 keys in loc/trf_en.loc (gen_map.py --loc).
	local en = RM_ReadFile(h.dir.."../../../../loc/trf_en.loc");
	miss = "";
	for k, v in TRF_Rm_Text() do
		local want = cr..lf.."#TRF_"..TRF_LocKey(k).." = "..TRF_Loc_Plain(v)..cr..lf;
		if not (en and strfind(en, want, 1, 1)) then miss = miss.." "..k; end;
	end;
	HOST_Check(miss == "", "loc/trf_en.loc: the 14 rm keys with their fixed forms"..miss);
	-- Owner decision 6 (16): a won off-screen sweep over the active base in altair writes its scar in altair, not at home.
	h.cfg.enable_scars = 1;
	TRF.scar = nil;
	TRF.base = {{s=al, k=2, h=9, t=0, w=0}};
	HOST_Check(TRF_SweepTarget(sl) == al, "the sweep target is the active base system");
	TRF.rg[sl].sl = 0;
	TRF_RgSweepOut(sl, TRF.clock.legs, 1, 1, "off", 50);
	local i1, ra = TRF_ScAt(al);
	local i2, rh = TRF_ScAt(kd);
	HOST_Check(TRF.base[1].k == 3 and ra and ra.kind == 3 and ra.fac == 0 and rh == nil, "won sweep over the base: the scar in the base system (altair), none at home");
	-- The remark in altair tells it once: base and sweep scar at one leg.
	local rem, l = RM_Pick(al);
	HOST_Check(rem and rem.k == "base" and rem.l == TRF.base[1].t and RM_Res(l, "sweep_pirate") == "merged", "base system: one remark for base and sweep scar (merged)");
	-- Without a base the target is the home.
	TRF.scar = nil; TRF.base = {};
	TRF_RgSweepOut(sl, TRF.clock.legs, nil, 1, "off", 50);
	i2, rh = TRF_ScAt(kd);
	HOST_Check(rh and rh.kind == 3, "no base: the sweep scar at home");
	h.cfg.enable_scars = nil;
end;

-- Dispatch (H3) ------------------------------------------------------------------------------

local sc = getenv("TRF_RM") or "";
local fn = getglobal("T_RM_"..strupper(sc));
print("HOST ==== remark scenario rm-"..sc.." dir="..HOST().dir);
if type(fn) == "function" then
	fn();
	HOST_Check(T_LeftGlobals() == "", "no handle globals left at the end"..T_LeftGlobals());
else
	HOST_Check(nil, "unknown remark scenario "..sc);
end;
HOST_Check((HOST().gpm_tick or 0) == 0, "no GetPlayerMotherShip from a tick (n="..tostring(HOST().gpm_tick or 0)..")");
print("HOST errors="..HOST().errors.." fails="..HOST().fails);
if HOST().errors > 0 or HOST().fails > 0 then exit(1); end;
exit(0);
