-- Static signals scenarios (design/static-signals-spec.md 13, A08) under stock Lua 4.0.1: TRF_SG=a..g, run by run_host.sh
-- as its own entry point. a install (loader, lists, texts, cfg and tune defaults and clamps, signals 0); b lighting
-- (phases, one light per tick, candidates, oldest rest first, roll rate, determinism, expiry, rest end, the record round
-- trip and leg wrap, the ring push kind 13 with its landmark and live check, the point table); c the entry line (due,
-- queue, sound, speaker, the queue and event-slot rules, a jump and a load before the due, remark_mode 0, trf_remark
-- absent, signal_sound 0 and 2, a raising PlaySound3D); d the reading (area bound, bands, threat words, a heard source,
-- the quest refusal, the marker again on entry and load, the offer cap with a found cache, the bump by older records);
-- e show and pickup (1x and an 8x step, outcomes trail, stash, ring, lore, the shot recorder, jump, orphans, wind-down);
-- f gates (quest, deny entry, sys_off, the start-system guard, the latch, holds at the due and at the reading, a scene,
-- chapters); g repair, the size bound, the full state and the RU file.
-- Loads host_station.lua up to its first scenario, as host_tips.lua does. Stubs here: squad pilots (SG_Crew, as
-- host_remark.lua's RM_Crew) and HOST_PlaySound3D of host_stubs.lua as PlaySound3D.

local f = openfile((getenv("TRF_TESTS") or "./").."host_station.lua", "r");
if not f then print("HOST FAIL host_signal.lua: cannot open host_station.lua"); exit(1); end;
local src = read(f, "*a");
closefile(f);
local cut = strfind(src, "\n-- a: install (12.1, 6.1)", 1, 1);
if not cut then print("HOST FAIL host_signal.lua: marker '-- a: install (12.1, 6.1)' missing in host_station.lua"); exit(1); end;
dostring(strsub(src, 1, cut), "host_station.lua");

-- Helpers ----------------------------------------------------------------------------------

-- Config of these runs: signals and tips on, the features that claim boxes, lines, slots or entry events off, trf_remark's
-- own remark off (TRF_CrewSay stays), no new light (sg_pct 0) unless t says so, log 2, plus t.
function SG_Cfg(t)
	local c = {signals=1, tips=1, corp=1, cap_enable=0, sweeps=0, sweep_ct=0, feq=0, staged=0, seed=0, queue=0, parked=0, voice_events=0,
		dconv=0, carriers=0, po=0, enable_parcels=0, enable_wq=0, enable_stashes=0, enable_survivors=0, enable_freight=0,
		temper=0, warn=0, remarks=0, enable_scars=0, log=2, tune={sg_pct=0}};
	if t then for k, v in t do c[k] = v; end; end;
	return c;
end;

-- Squad pilots for GetPilot: t = {<template> = {alive, side, csr}} (RM_Crew of host_remark.lua).
function SG_Crew(t)
	local h = HOST();
	h.crew = {};
	for tpl, e in t do
		local p = HOST_Pilot(tpl);
		p.alive = e.alive; p.side = e.side or "Player"; p.csr = e.csr;
		p.IsAlive = function(self) if self.alive then return 1; end; return nil; end;
		p.GetSide = function(self) return self.side; end;
		p.IsCanSayReplica = function(self) if self.csr then return 1; end; return 0; end;
		p.Message = function(self, text, secs)
			HOST_Want(type(text) == "string" and type(secs) == "number", "Pilot:Message(text, secs)");
			print("HOST Message "..self.tpl..": "..tostring(text));
			tinsert(HOST().msgs, {t=text, gt=HOST().gt, tpl=self.tpl});
		end;
		h.crew[tpl] = p;
	end;
end;

-- MapInitialization runs HOST().sgload right after trf_signal.script is loaded (a point for a test system, before the
-- repair at the entry reads the table).
SG_Exec0 = ExecuteScriptFile;
function ExecuteScriptFile(path)
	local r = SG_Exec0(path);
	if r and HOST().sgload and strfind(path, "trf_signal.script", 1, 1) then HOST().sgload(); end;
	return r;
end;

-- Extra points {name = {{x, y, z}}} for systems the table leaves out (gate runs).
function SG_Extra(t)
	HOST().sgx = t;
	HOST().sgload = function()
		local pd = TRF_SgPointData;
		TRF_SgPointData = function() local o = %pd(); for k, v in HOST().sgx do o[k] = v; end; return o; end;
	end;
end;

-- The scene of an entry runs HOST().sghook after the module files are loaded and before TRF_OnEnter.
SG_Scene0 = T_Scene;
function T_Scene(sys)
	SG_Scene0(sys);
	local h = HOST();
	if h.sghook then h.sghook(); end;
end;

-- Scenario start in sys at chapter label ch (default 6): every region Quiet, no records, a campaign 100 legs in.
function SG_Begin(sys, ch, t)
	local h = HOST();
	h.labels.CurrentQuest = ch or "6";
	h.quests = {}; h.qlog = {};
	h.qs = FALSE;
	h.snd = {}; h.snd_err = nil; h.sghook = nil; h.sgload = nil;
	h.block_r = 3;
	PlaySound3D = HOST_PlaySound3D;
	SG_Crew({Hero={alive=1, csr=1}, Lastochka={alive=1, csr=1}});
	S_Begin(sys, SG_Cfg(t));
	h.credits = 1000000;
	SG_Phase(0);
	TRF.base = {}; TRF.sg = nil; TRF.ti = nil; TRF.stash = nil;
	TRF.clock.legs = 100; TRF.clock.rt = 100;
end;

-- Every region in phase ph.
function SG_Phase(ph)
	for s = 1, TRF_RgMap().n do
		TRF.clan[s].sc = 30;
		local rg = TRF.rg[s];
		rg.ph = ph; rg.pt = TRF.clock.legs; rg.sl = 0; rg.sn = 0; rg.sw = 0; rg.sr = nil;
	end;
end;

-- Tune override k = v (TRF_Tune rebuilds on a changed cfg tune).
function SG_Tune(k, v)
	local h = HOST();
	local o = {};
	for a, b in h.cfg.tune do o[a] = b; end;
	o[k] = v;
	h.cfg.tune = o;
end;

function SG_N(t) local n = 0; for k, v in t do n = n + 1; end; return n; end;
function SG_Has(s, t) return strfind(s or "", t, 1, 1); end;

-- signal log lines after mark n0 holding pat (plain).
function SG_Logs(n0, pat)
	local n, q = 0, HOST().logs;
	for i = n0 + 1, getn(q) do if strfind(q[i], "module=signal ", 1, 1) and strfind(q[i], pat, 1, 1) then n = n + 1; end; end;
	return n;
end;

-- The record of system nm: point p, state t, age ag (legs before now); written into its region block.
function SG_Set(nm, p, t, ag)
	local s = V_Idx(nm);
	local slot = TRF_RgOf(s);
	local bs, n = TRF_SgBlocks();
	bs[slot] = {s=s, p=p or 1, g=TRF.clock.legs - (ag or 0), age=ag or 0, t=t or 0, slot=slot};
	TRF_SgStore(bs, n);
	return bs[slot];
end;

function SG_Rec(nm) return TRF_Sg_Rec(V_Idx(nm)); end;
function SG_T(nm) local r = SG_Rec(nm); if r then return r.t; end; return nil; end;

-- Point p of system nm as a Vector3.
function SG_Pt(nm, p)
	local q = TRF_SgPointData()[nm][p or 1];
	return Vector3(q[1], q[2], q[3]);
end;

function SG_MsTo(x, y, z) HOST().ms.pos = Vector3(x, y, z); end;

-- Seconds of ticks at 0.5 s.
function SG_Run(secs) T_Tick(floor(secs * 2 + 0.5), 0.5); end;

-- Radio lines (pilot messages) after index m0 joined by "|", and their templates.
function SG_Msgs(m0)
	local q, s, t = HOST().msgs, "", "";
	for i = (m0 or 0) + 1, getn(q) do s = s..q[i].t.."|"; t = t..tostring(q[i].tpl).."|"; end;
	return s, t;
end;

-- Screen lines after index s0 joined by "|".
function SG_Scr(s0)
	local q, s = HOST().screen, "";
	for i = (s0 or 0) + 1, getn(q) do s = s..q[i].t.."|"; end;
	return s;
end;

-- Live nav point labelled l, or nil.
function SG_Nav(l) return GetNavPointByLabel(l); end;

-- The live source object of slot, or nil.
function SG_Obj(slot)
	local o = HOST().objs["TRF_SGO_"..slot];
	if o and o.alive then return o; end;
	return nil;
end;

-- Entry into sys after a stop elsewhere (a fresh visit): first gredos (no region), then sys.
function SG_Go(sys)
	T_Jump("gredos");
	T_Jump(sys);
end;

-- SG_Go without a region tick at the entry into sys (the gates of 5 before the expiry of 4.4 E2 sees them); pre (optional)
-- runs between the two jumps (a scene hook that only the entry into sys should see).
function SG_GoNt(sys, pre)
	T_Jump("gredos");
	TRF.clock.rt = TRF.clock.legs;
	if pre then pre(); end;
	T_Jump(sys);
end;

-- File contents, or nil.
function SG_Read(p)
	local fh = openfile(p, "rb");
	if not fh then return nil; end;
	local s = read(fh, "*a");
	closefile(fh);
	return s;
end;

function SG_Count(s, t)
	local n, i = 0, 1;
	while 1 do
		local a, e = strfind(s, t, i, 1);
		if not a then return n; end;
		n = n + 1;
		i = e + 1;
	end;
end;

-- Due call of c: a mod line queued at 4 s (trf_warn's note).
function SG_Note(idx) TRF_ArrivalLine("warn", "A warning note."); end;

-- Entry into sunji with the lit record (point 1), then secs of ticks. Returns the record's light leg.
function SG_Line(secs)
	local r = SG_Set("sunji", 1, 0, 1);
	SG_Go("sunji");
	if secs then SG_Run(secs); end;
	return r.g;
end;

-- a: install -------------------------------------------------------------------------------

function T_SG_A()
	local h = HOST();
	SG_Begin("gredos");
	HOST_Check(S_Logs(0, "module=core event=loaded map=true module_count=18 extra_count=23") >= 1, "trf_signal loads last (extra_count=23)");
	local ml, pm, tf, uf = TRF_ModList(), TRF_PlMods(), TRF_Loc_TextFns(), TRF_UI_TextFns();
	HOST_Check(ml[getn(ml)] == "Sg" and ml[getn(ml) - 1] == "Spc" and pm[getn(pm)] == "Sg" and tf[getn(tf) - 1] == "TRF_Sg_Text"
		and tf[getn(tf) - 2] == "TRF_Spc_Text" and tf[getn(tf)] == "TRF_Loc_Text" and uf[getn(uf)] == "TRF_Sg_Text",
		"Sg last in TRF_ModList and TRF_PlMods; TRF_Sg_Text after TRF_Spc_Text in both text lists");
	HOST_Check(TRF_PlReg().off.signal == 1 and TRF_PlReg().off.stash == 1, "signal registers as an offer owner beside stash");
	-- 15 keys; each resolves; no %, #, line break, "gate"; tisignal in TRF_Ti_Text; the scaffold has them.
	local tx, bad, n = TRF_Sg_Text(), "", 0;
	for k, v in tx do
		n = n + 1;
		if strsub(k, 1, 2) ~= "sg" or TRF_Txt(k) == k or SG_Has(v, "%") or SG_Has(v, "#") or SG_Has(v, "\n") or SG_Has(strlower(v), "gate") then
			bad = bad.." "..k;
		end;
	end;
	HOST_Check(n == 15 and bad == "" and TRF_Ti_Text().tisignal == "$1 picked up a looping signal in $3 $4.", "15 sg keys, each resolves, no %, #, line break or 'gate'; tisignal"..bad);
	local en = SG_Read(h.dir.."../../../../loc/trf_en.loc");
	local miss = "";
	for k, v in tx do if not SG_Has(en, "#TRF_"..k.." = ") then miss = miss.." "..k; end; end;
	if not SG_Has(en, "#TRF_tisignal = ") then miss = miss.." tisignal"; end;
	HOST_Check(en and miss == "", "loc/trf_en.loc holds the 16 keys"..miss);
	-- cfg and tune defaults, clamps.
	HOST_Check(TRF_Opt("signals") == 1 and TRF_Sg_OptDef().signals == 1 and TRF_OptEnum().signals == 1 and TRF_OptEnum().signal_sound == 2
		and TRF_SgOpt("signal_sound") == 1 and TRF_SgOpt("signal_at") == "", "cfg signals 1, signal_sound 1, signal_at empty; enumerated");
	h.cfg.tune = {};
	local T = TRF_SgTune();
	HOST_Check(SG_N(TRF_Sg_TuneDef()) == 16 and T.sg_ch == 5 and T.sg_ch_end == 20 and T.sg_ph[0] == 1 and T.sg_ph[1] == 1 and T.sg_ph[2] == nil
		and T.sg_pct == 20 and T.sg_ttl == 12 and T.sg_rest == 20 and T.sg_home == 0 and T.sg_delay == 6 and T.sg_secs == 8 and T.sg_read_s == 10
		and T.sg_area_r == 500 and T.sg_area_min == 150 and T.sg_show_r == 500 and T.sg_pick_r == 60 and T.sg_stash_j == 4 and T.sg_vol == 80,
		"16 tune keys with the defaults of spec 10");
	HOST_Check(T.sg_delay > TRF_Wn_TuneDef().wn_delay and TRF_SgClampT().sg_delay[1] > TRF_Wn_TuneDef().wn_delay, "sg_delay (6, at least 5) is later than wn_delay (4)");
	h.cfg.tune = {sg_delay=2, sg_ttl=500, sg_area_r=50, sg_area_min=900, sg_ph={0, 7, -1, 2.5}, sg_pct=33.7};
	T = TRF_SgTune();
	HOST_Check(T.sg_delay == 5 and T.sg_ttl == 200 and T.sg_area_r == 100 and T.sg_area_min == 100 and T.sg_ph[0] == 1 and T.sg_ph[5] == 1
		and T.sg_ph[2] == 1 and T.sg_ph[1] == nil and T.sg_pct == 33, "clamps: sg_delay >= 5, sg_ttl <= 200, sg_area_r >= 100, sg_area_min <= sg_area_r, phases 0..5, whole");
	h.cfg.tune = {sg_pct=100};
	h.cfg.signal_sound = 3;
	HOST_Check(TRF_SgOpt("signal_sound") == 1, "signal_sound 3 reads as the default");
	h.cfg.signal_sound = nil;
	-- signals 0: no light over 50 region ticks, TRF.sg cleared.
	TRF.sg = "07810991";
	h.cfg.signals = 0;
	local n0 = S_Mark();
	for i = 1, 50 do TRF.clock.legs = TRF.clock.legs + 1; TRF_Sg_RegionTick(TRF.clock.legs); end;
	HOST_Check(TRF.sg == nil and SG_Logs(n0, "event=light region=all result=none reason=off") == 50 and SG_Logs(n0, "result=lit") == 0, "signals 0: no light in 50 region ticks, TRF.sg cleared");
	n0 = S_Mark();
	TRF_Sg_Dump();
	HOST_Check(SG_Logs(n0, "event=dump on=0 record_count=0 records=nil") == 1, "dump with signals 0");
	h.cfg.signals = nil;
	-- With signals 1 the same ticks light sources.
	for i = 1, 5 do TRF.clock.legs = TRF.clock.legs + 1; TRF_Sg_RegionTick(TRF.clock.legs); end;
	HOST_Check(type(TRF.sg) == "string", "signals 1 and sg_pct 100: a source lights ("..tostring(TRF.sg)..")");
	-- No function of trf_signal starts with TRF_Sg that another module defines: the prefix is new.
	local fs = openfile(h.dir.."trf_signal.script", "r");
	local body = read(fs, "*a");
	closefile(fs);
	HOST_Check(SG_Has(body, "function TRF_SgE(") and SG_Has(body, "-- BEGIN gen_stash.py signal") and not SG_Has(body, "GetPlayerQuestState(") and not SG_Has(body, '"GetPlayerQuestState"'),
		"module text: own log wrapper, the generated block, never GetPlayerQuestState");
end;

-- b: lighting ------------------------------------------------------------------------------

function T_SG_B()
	local h = HOST();
	SG_Begin("gredos", "6", {tune={sg_pct=20}});
	local rm = TRF_RgMap();
	local cur = TRF_CurIdx();
	-- The point table: 17 systems and 60 points, each a never-named system without fronn, every point 500..1200 from the
	-- nearest portal (broken ones included) and 400 from every map station (the rules the host can see; gen_stash.py --check has the others).
	local free = TRF_StrictFree();
	local ns, np, bad = 0, 0, "";
	for nm, l in TRF_SgPointData() do
		ns = ns + 1;
		local e = TRF_Map().sys[V_Idx(nm)];
		if not free[nm] or nm == "fronn" or getn(l) > 4 then bad = bad.." "..nm; end;
		for i = 1, getn(l) do
			np = np + 1;
			local p = Vector3(l[i][1], l[i][2], l[i][3]);
			local dp = nil;
			for j = 1, getn(e.portals) do
				local d = HOST_Dist(p, e.portals[j]);
				if not dp or d < dp then dp = d; end;
			end;
			for j = 1, getn(e.broken or {}) do
				local d = HOST_Dist(p, e.broken[j]);
				if not dp or d < dp then dp = d; end;
			end;
			if dp < 500 or dp > 1200 then bad = bad.." "..nm..i..":portal"; end;
			for j = 1, getn(e.st or {}) do if HOST_Dist(p, e.st[j]) < 400 then bad = bad.." "..nm..i..":station"; end; end;
		end;
	end;
	HOST_Check(ns == 17 and np == 60 and bad == "", "point table: 17 never-named systems, 60 points, the portal and station rules"..bad);
	-- Record round trip and the leg wrap.
	local e = TRF_SgEncOf({s=78, p=2, g=1998, t=1});
	local d = TRF_SgDecOf(e, 2003);
	HOST_Check(e == "07829981" and d.s == 78 and d.p == 2 and d.g == 1998 and d.age == 5 and d.t == 1, "record round trip: 8 digits, the leg from the age ("..e..")");
	d = TRF_SgDecOf(TRF_SgEncOf({s=5, p=1, g=999, t=0}), 1002);
	HOST_Check(d.age == 3 and d.g == 999, "leg wrap across 1000: age 3");
	HOST_Check(TRF_SgDecOf("0782998", 2003) == nil and TRF_SgDecOf("07829984", 2003) == nil and TRF_SgDecOf("07809981", 2003) == nil
		and TRF_SgDecOf("0782998x", 2003) == nil and TRF_SgDecOf("00029981", 2003) == nil, "decode refuses short pieces, state 4, point 0, system 0, non-digits");
	-- Candidates (4.2).
	local c = {cur=1, sys={1, 2, 3, 4, 5, 6}, np={[1]=2, [2]=2, [3]=1, [4]=1, [5]=1, [6]=0}, home=2, sg_home=0, base={{s=3, k=1}, {s=4, k=3}},
		sv={[5]=1}, gate={[1]=1, [2]=1, [3]=1, [4]=1, [5]=1, [6]=1}, rest_s=nil};
	local l = TRF_SgCandsOf(c);
	HOST_Check(getn(l) == 1 and l[1] == 4, "candidates: not the current system (C1), no home (C2), no base k 1 (C3; k 3 allowed), no survive record (C4), no point");
	c.sg_home = 1;
	l = TRF_SgCandsOf(c);
	HOST_Check(getn(l) == 2 and l[1] == 2 and l[2] == 4, "sg_home 1: the home may light");
	c.gate[4] = nil;
	l = TRF_SgCandsOf(c);
	HOST_Check(getn(l) == 1 and l[1] == 2, "strict gate false: left out (C5)");
	c.rest_s = 2;
	l = TRF_SgCandsOf(c);
	HOST_Check(getn(l) == 1 and l[1] == 2, "the rest system when it is the only candidate (C6)");
	c.gate[4] = 1;
	l = TRF_SgCandsOf(c);
	HOST_Check(getn(l) == 1 and l[1] == 4, "the rest system left out while another has points (C6)");
	-- Light choice (4.3): empty blocks first, then the oldest rest, then the lower slot; phases; busy, rest, roll.
	local T = {sg_rest=20, sg_pct=100, sg_ph={[0]=1, [1]=1}};
	local rg = {{ph=0, cands={11}, np={[11]=1}}, {ph=0, cands={12}, np={[12]=2}}, {ph=1, cands={13}, np={[13]=1}}};
	local bs = {{s=11, p=1, g=0, age=30, t=3}, nil, {s=13, p=1, g=0, age=50, t=3}};
	local sl, s = TRF_SgLightOf(bs, rg, T, 100);
	HOST_Check(sl == 2 and s == 12, "the empty block lights first");
	bs[2] = {s=12, p=1, g=0, age=1, t=1};
	sl, s = TRF_SgLightOf(bs, rg, T, 100);
	HOST_Check(sl == 3 and s == 13, "then the oldest rest (age 50 before 30)");
	bs[3].age = 30;
	sl, s = TRF_SgLightOf(bs, rg, T, 100);
	HOST_Check(sl == 1, "a tie: the lower slot");
	rg[1].ph = 2; rg[3].ph = 4;
	local w;
	sl, w = TRF_SgLightOf(bs, rg, T, 100);
	HOST_Check(sl == nil and w == "phase", "Build-up and Bust: no light (phase)");
	rg[1].ph = 0; rg[3].ph = 0; bs[1].age = 5; bs[3].age = 20;
	sl, w = TRF_SgLightOf(bs, rg, T, 100);
	HOST_Check(sl == nil and w == "rest", "rests not over (age <= sg_rest): no light (rest)");
	T.sg_pct = 0; bs[1].age = 25;
	sl, w = TRF_SgLightOf(bs, rg, T, 100);
	HOST_Check(sl == nil and w == "roll", "sg_pct 0: the roll fails");
	-- Roll rate near sg_pct over 8 slots x 1000 legs.
	local hit = 0;
	for slot = 1, 8 do for L = 1, 1000 do if TRF_SgRollOf(slot, L) < 20 then hit = hit + 1; end; end; end;
	HOST_Check(hit >= 1400 and hit <= 1800, "roll below 20 in "..hit.." of 8000 (near 20 %)");
	-- Expiry (4.4).
	T = {sg_ttl=12, sg_rest=20};
	HOST_Check(TRF_SgExpireOf({s=5, t=0, age=13}, 0, 6, T, 1) == "ttl" and TRF_SgExpireOf({s=5, t=2, age=13}, 0, 5, T, 1) == nil
		and TRF_SgExpireOf({s=5, t=1, age=3}, 0, 6, T, nil) == "gate" and TRF_SgExpireOf({s=5, t=3, age=21}, 0, 6, T) == "end"
		and TRF_SgExpireOf({s=5, t=3, age=20}, 0, 6, T) == nil, "expiry: ttl (not in the current system), gate, rest end after sg_rest");
	-- 300 region ticks with phases cycling (every 10 legs the next phase).
	local n0 = S_Mark();
	local per, badph, bads, lit = 0, "", "", 0;
	TRF.sg = nil;
	for k = 1, 300 do
		TRF.clock.legs = TRF.clock.legs + 1;
		SG_Phase(mod(floor(k / 10), 6));
		local m0 = getn(h.logs);
		TRF_Sg_RegionTick(TRF.clock.legs);
		local nl = 0;
		for i = m0 + 1, getn(h.logs) do
			local ln = h.logs[i];
			if strfind(ln, "module=signal event=light ", 1, 1) and strfind(ln, "result=lit", 1, 1) then
				nl = nl + 1;
				local _, _, ph = strfind(ln, "phase=(%d)");
				if ph ~= "0" and ph ~= "1" then badph = badph.." "..tostring(ph); end;
				local _, _, si = strfind(ln, "system_index=(%d+)");
				si = tonumber(si);
				local slot = TRF_RgOf(si);
				if si == cur or si == rm[slot].home then bads = bads.." "..si; end;
			end;
		end;
		if nl > 1 then per = per + 1; end;
		lit = lit + nl;
	end;
	HOST_Check(lit >= 5 and per == 0 and badph == "" and bads == "", "300 ticks: "..lit.." lights, at most one per tick, only in Quiet and Boom, never a home or the current system"..badph..bads);
	HOST_Check(SG_Logs(n0, "event=expire ") >= 1 and SG_Logs(n0, "reason=ttl") >= 1 and SG_Logs(n0, "event=rest_end ") >= 1, "sources expire (ttl) and their rest ends");
	-- Determinism: the same 40 ticks from the same state twice (a reload replays the same answer).
	local legs0, sg0 = TRF.clock.legs, TRF.sg;
	local seq = {"", ""};
	for run = 1, 2 do
		TRF.clock.legs = legs0; TRF.sg = sg0;
		for k = 1, 40 do
			TRF.clock.legs = TRF.clock.legs + 1;
			SG_Phase(0);
			TRF_Sg_RegionTick(TRF.clock.legs);
			seq[run] = seq[run]..tostring(TRF.sg)..";";
		end;
	end;
	HOST_Check(seq[1] == seq[2], "the same state and legs give the same lights (no RAND draw)");
	-- Ring push kind 13 at lighting with the X3 landmark; live check current, dead after the rest.
	TRF.sg = nil; TRF.ti = nil;
	SG_Tune("sg_pct", 100);
	SG_Phase(0);
	TRF.clock.legs = TRF.clock.legs + 1;
	n0 = S_Mark();
	TRF_Sg_RegionTick(TRF.clock.legs);
	local bl = TRF_SgBlocks();
	local r = nil;
	for b = 1, rm.n do if bl[b] then r = bl[b]; end; end;
	local rr = TRF_RingRead(nil, {k=13});
	local q = TRF_SgPointData()[TRF_SysName(r.s)][r.p];
	local lm = TRF_TiLmOf(TRF_Map().sys[r.s], {x=q[1], y=q[2], z=q[3]});
	HOST_Check(getn(rr) == 1 and rr[1].s == r.s and rr[1].a == r.p and rr[1].l == lm and rr[1].c == 0 and S_Logs(n0, "module=tips event=push kind=signal") == 1,
		"ring push kind 13 at lighting: system, point, landmark "..lm..", FTU haulers");
	HOST_Check(TRF_TiLiveSt(rr[1]) == "current", "ring live check: current while the source loops");
	r.t = 3; r.g = TRF.clock.legs;
	TRF_SgPut(r);
	HOST_Check(TRF_TiLiveSt(rr[1]) == "dead", "dead after the rest");
	HOST_Check(TRF_TiRankOf(13) == TRF_TiRankOf(8) + 1 and TRF_TiRankOf(5) == TRF_TiRankOf(13) + 1, "tie order: signal right after wreck");
	-- Expiry with the gate: a quest names the system now (stubbed strict gate).
	TRF.sg = nil;
	r = SG_Set("sunji", 1, 1, 2);
	local so = TRF_StrictOk;
	TRF_StrictOk = function(i, f) if f == "signal" and i == V_Idx("sunji") then return nil, "quest"; end; return %so(i, f); end;
	n0 = S_Mark();
	TRF_Sg_RegionTick(TRF.clock.legs);
	TRF_StrictOk = so;
	HOST_Check(SG_T("sunji") == 3 and SG_Logs(n0, "event=expire region="..TRF_RgOf(V_Idx("sunji")).." system=sunji state=1 age=2 reason=gate") == 1, "a quest names the system: rest (gate)");
end;

-- c: entry line ----------------------------------------------------------------------------

function T_SG_C()
	local h = HOST();
	SG_Begin("gredos");
	local si = V_Idx("sunji");
	local slot = TRF_RgOf(si);
	-- Empty entry: armed, due at 6 s, queued for 8 s, shown with the static.
	local n0, m0 = S_Mark(), getn(h.msgs);
	h.snd = {};
	local lg = SG_Line(5.5);
	HOST_Check(SG_Logs(n0, "event=enter system=sunji state=0 result=armed") == 1 and SG_Logs(n0, "event=line ") == 0, "entry: armed, no line before 6 s");
	SG_Run(0.5);
	HOST_Check(SG_Logs(n0, "event=line system=sunji system_index="..si.." light_leg="..lg.." variant=") == 1
		and SG_Logs(n0, "queued_count=0 result=queued") == 1 and S_Logs(n0, "module=plumb event=arrival_line owner=signal line_index=1 delay=2.000 voiced=true result=queued") == 1,
		"due at 6 s: queued for 8 s (the first free slot)");
	SG_Run(2.5);
	local ms, tp = SG_Msgs(m0);
	local ok3 = SG_Has(ms, TRF_Txt("sgline1")) or SG_Has(ms, TRF_Txt("sgline2")) or SG_Has(ms, TRF_Txt("sgline3"));
	HOST_Check(ok3 and tp == "Lastochka|" and SG_T("sunji") == 1, "the broken phrase as Lastochka's radio line (template list), t 1 ("..tp..")");
	local p = h.ms:GetPosition();
	HOST_Check(getn(h.snd) == 2 and h.snd[1].name == "spark4.wav" and h.snd[2].name == "vapour-escape-loop.wav" and h.snd[1].vol == 0.8
		and HOST_Dist(h.snd[1].pos, p) < 1 and HOST_Dist(h.snd[2].pos, p) < 1, "PlaySound3D twice at the mothership, volume 0.8");
	HOST_Check(SG_Logs(n0, "event=say system_index="..si) == 1 and SG_Logs(n0, "speaker=Lastochka output=radio sound=spark4.wav+vapour-escape-loop.wav sound_result=played result=shown") == 1,
		"say line: speaker, radio, sound played, shown");
	-- One line per source: the next entry has no line (t 1, the reading follows).
	n0 = S_Mark();
	SG_Go("sunji");
	SG_Run(9);
	HOST_Check(SG_Logs(n0, "event=enter system=sunji state=1 result=reading") == 1 and SG_Logs(n0, "event=line ") == 0 and SG_Logs(n0, "event=say ") == 0, "heard: no second line");
	-- A remark queued at activation: dropped queued:1, t stays 0.
	SG_Set("sunji", 1, 0, 1);
	SG_Go("sunji");
	TRF_ArrivalLine("remark", "A remark.");
	n0 = S_Mark();
	SG_Run(10);
	HOST_Check(SG_Logs(n0, "event=line system=sunji") == 1 and SG_Logs(n0, "queued_count=1 result=dropped reason=queued:1") == 1 and SG_T("sunji") == 0,
		"a remark queued at the entry: no signal line (queued:1)");
	-- trf_warn's note at 4 s.
	SG_Go("sunji");
	TRF_Due(4, "SG_Note", si);
	n0 = S_Mark();
	SG_Run(10);
	HOST_Check(SG_Logs(n0, "result=dropped reason=queued:1") == 1 and SG_T("sunji") == 0, "a line queued at 4 s (the warn note): dropped queued:1");
	-- The event slot held.
	SG_Go("sunji");
	TRF_EventSlotTake("sweep");
	n0 = S_Mark();
	SG_Run(10);
	HOST_Check(SG_Logs(n0, "queued_count=0 result=dropped reason=event:sweep") == 1 and SG_T("sunji") == 0, "the event slot held: dropped event:sweep");
	-- A jump before the due.
	SG_Go("sunji");
	SG_Run(3);
	n0 = S_Mark();
	T_Jump("gaoba");
	SG_Run(10);
	HOST_Check(SG_Logs(n0, "event=line ") == 0 and SG_T("sunji") == 0, "a jump before the due: no line, t 0");
	-- A load in the system before the due: no line (no entry).
	SG_Go("sunji");
	SG_Run(2);
	n0 = S_Mark();
	T_SaveLoad();
	SG_Run(10);
	HOST_Check(SG_Logs(n0, "event=line ") == 0 and SG_Logs(n0, "event=say ") == 0 and SG_T("sunji") == 0, "a load: no line, t 0");
	-- remark_mode 0: the line form.
	h.cfg.remark_mode = 0;
	local s0 = getn(h.screen);
	n0 = S_Mark();
	SG_Line(9);
	h.cfg.remark_mode = nil;
	HOST_Check(SG_Logs(n0, "speaker=Lastochka output=line") == 1 and SG_Has(SG_Scr(s0), TRF_RmSpeakerName("Lastochka")..": ") and SG_T("sunji") == 1, "remark_mode 0: a screen line naming the pilot");
	-- trf_remark absent: TRF_Say.
	SG_Set("sunji", 1, 0, 1);
	SG_Go("sunji");
	TRF_CrewSay = nil;
	s0 = getn(h.screen);
	n0 = S_Mark();
	SG_Run(9);
	local sc = SG_Scr(s0);
	HOST_Check(SG_Logs(n0, "output=line ") == 1 and SG_Logs(n0, "result=shown") == 1 and (SG_Has(sc, TRF_Txt("sgline1")) or SG_Has(sc, TRF_Txt("sgline2"))
		or SG_Has(sc, TRF_Txt("sgline3"))), "trf_remark absent: the phrase as a screen line");
	-- signal_sound 0 and 2.
	h.cfg.signal_sound = 0; h.snd = {};
	n0 = S_Mark();
	SG_Line(9);
	HOST_Check(getn(h.snd) == 0 and SG_Logs(n0, "sound=none sound_result=off result=shown") == 1, "signal_sound 0: no sound, the line shows");
	h.cfg.signal_sound = 2; h.snd = {};
	n0 = S_Mark();
	SG_Line(9);
	HOST_Check(getn(h.snd) == 2 and SG_Logs(n0, "sound_result=played result=shown") == 1, "signal_sound 2 (no asset shipped): the vanilla pair");
	h.cfg.signal_sound = nil;
	-- PlaySound3D raising: the line still shows; missing: error too.
	h.snd_err = 1;
	n0 = S_Mark();
	local ne = S_Expect(function() SG_Line(9); end);
	h.snd_err = nil;
	HOST_Check(ne == 2 and SG_Logs(n0, "sound_result=error result=shown") == 1 and SG_T("sunji") == 1, "PlaySound3D raising: sound_result=error, the line shows ("..ne.." errors)");
	PlaySound3D = nil;
	n0 = S_Mark();
	SG_Line(9);
	PlaySound3D = HOST_PlaySound3D;
	HOST_Check(SG_Logs(n0, "sound_result=error result=shown") == 1, "PlaySound3D missing: sound_result=error, the line shows");
	-- The say when the record changed between queue and due (heard elsewhere): not shown.
	SG_Line(7);
	local r = SG_Rec("sunji"); r.t = 1; TRF_SgPut(r);
	n0 = S_Mark();
	SG_Run(2);
	HOST_Check(SG_Logs(n0, "result=not_shown reason=heard") == 1, "the record no longer t 0 at the say: not shown");
	-- Debug signal_at: a record at the entry of that system.
	TRF.sg = nil;
	h.cfg.signal_at = "sunji";
	n0 = S_Mark();
	SG_Go("sunji");
	SG_Run(9);
	h.cfg.signal_at = nil;
	HOST_Check(SG_Logs(n0, "event=debug system=sunji result=created") == 1 and SG_T("sunji") == 1, "signal_at: created at the entry, the line follows");
	h.cfg.signal_at = "gredos";
	n0 = S_Mark();
	T_Jump("gredos");
	h.cfg.signal_at = nil;
	HOST_Check(SG_Logs(n0, "event=debug system=gredos result=no_point") == 1, "signal_at in a system without points: no_point");
end;

-- d: reading -------------------------------------------------------------------------------

function T_SG_D()
	local h = HOST();
	SG_Begin("gredos");
	local si = V_Idx("sunji");
	local slot = TRF_RgOf(si);
	local pt = SG_Pt("sunji", 1);
	-- Bands.
	HOST_Check(TRF_SgBandOf(599) == 3 and TRF_SgBandOf(600) == 2 and TRF_SgBandOf(1199) == 2 and TRF_SgBandOf(1200) == 1 and TRF_SgBandOf(nil) == 1,
		"bands: strong below 600, clear below 1200, faint");
	-- Area offsets stay within sg_area_min..sg_area_r for many hashes.
	local bad = "";
	for hh = 0, 9999, 37 do
		local m, off = TRF_SgAreaOf({x=0, y=5, z=0}, hh, 150, 500);
		local dd = sqrt(m.x * m.x + m.z * m.z);
		if dd < 149.9 or dd > 500.1 or m.y ~= 5 or abs(dd - off) > 0.01 then bad = bad.." "..hh; end;
	end;
	HOST_Check(bad == "", "area point 150..500 from the source, the same y"..bad);
	-- The reading sg_read_s after the line.
	local s0 = getn(h.screen);
	local n0 = S_Mark();
	SG_Line(9);
	HOST_Check(SG_T("sunji") == 1 and SG_Nav("TRF_SG_AR_"..slot) == nil, "after the line: no marker yet");
	SG_Run(8);
	HOST_Check(SG_Nav("TRF_SG_AR_"..slot) == nil, "9 s after the line: no reading");
	SG_Run(1.5);
	local nv = SG_Nav("TRF_SG_AR_"..slot);
	local dd = nv and HOST_Dist(nv.pos, pt);
	local d = HOST_Dist(h.ms:GetPosition(), pt);
	local bi = TRF_SgBandOf(d);
	local word = TRF_Str_Word(si);
	HOST_Check(nv and dd >= 149.9 and dd <= 500.1 and nv.icon == "nav_target.dds" and nv.text == "" and SG_T("sunji") == 2,
		"reading: the area marker "..floor(dd or -1).." units from the source, t 2");
	HOST_Check(SG_Has(SG_Scr(s0), TRF_Txt("sgread", TRF_Txt("sgband"..bi), word)) and SG_Logs(n0, "event=read system=sunji system_index="..si) == 1
		and SG_Logs(n0, "marker=TRF_SG_AR_"..slot.." result=shown") == 1 and S_Logs(n0, "module=plumb event=marker owner=signal label=TRF_SG_AR_"..slot.." class=offer offer_count=1 result=added") == 1,
		"the reading line with the band and the threat word ("..word..")");
	-- Threat words 1-4 and the Ghost form, the tier line unchanged.
	local et, ga = TRF_EffTier, TRF_Te_ArrWord;
	local ws = "";
	for t = 1, 4 do
		TRF_EffTier = function(i) return %t; end;
		local w, T = TRF_Str_Word(si);
		ws = ws..w.."/"..T..",";
	end;
	HOST_Check(ws == TRF_Txt("pirw1").."/1,"..TRF_Txt("pirw2").."/2,"..TRF_Txt("packs").."/3,"..TRF_Txt("raiders").."/4,", "TRF_Str_Word: the tier words 1-4 ("..ws..")");
	TRF_Te_ArrWord = function(i, tw) return tw.." and ghosts"; end;
	local gw = TRF_Str_Word(si);
	HOST_Check(gw == TRF_Txt("raiders").." and ghosts" and TRF_UI_ArrDis(si, 2) == TRF_Txt("arrt2", gw), "the Ghost form, and the tier arrival line uses the same word");
	TRF_EffTier = et; TRF_Te_ArrWord = ga;
	HOST_Check(TRF_UI_ArrDis(si, 2) == TRF_Txt("arrt2", TRF_Str_Word(si)), "the tier arrival line as built");
	-- Once per source: no second reading.
	n0 = S_Mark();
	SG_Run(15);
	HOST_Check(SG_Logs(n0, "event=read ") == 0, "one reading per source");
	-- t 2: the marker again on entry and after a load.
	SG_Go("sunji");
	HOST_Check(SG_Nav("TRF_SG_AR_"..slot) ~= nil, "t 2: the area marker again on entry");
	T_SaveLoad();
	HOST_Check(SG_Nav("TRF_SG_AR_"..slot) ~= nil and TRF_PlMkCount() == 1, "t 2: the area marker again after a load (one marker)");
	-- A heard source on a later entry: the reading without a line.
	SG_Set("sunji", 1, 1, 1);
	n0 = S_Mark();
	SG_Go("sunji");
	SG_Run(11);
	HOST_Check(SG_Logs(n0, "event=line ") == 0 and SG_Logs(n0, "result=shown") == 1 and SG_T("sunji") == 2, "t 1 on entry: read after sg_read_s, no line");
	-- The quest refusal of the marker (the latch stubbed open): wait once, retried.
	SG_Set("sunji", 1, 1, 1);
	SG_Go("sunji");
	local qs = TRF_Safe_QState;
	TRF_Safe_QState = function() return nil; end;
	h.qs = TRUE;
	n0 = S_Mark();
	SG_Run(14);
	HOST_Check(SG_Logs(n0, "result=wait reason=quest") == 1 and SG_T("sunji") == 1, "a story mission at the reading: wait (quest), once");
	h.qs = FALSE;
	SG_Run(1.5);
	TRF_Safe_QState = qs;
	HOST_Check(SG_Logs(n0, "result=shown") == 1 and SG_T("sunji") == 2, "retried at the next step");
	-- Offer cap: a found cache in gaoba plus the signal fit (one stash marker after the stash change).
	h.cfg.enable_stashes = 1;
	TRF.sg = nil;
	local gi = V_Idx("gaoba");
	local gs = TRF_RgOf(gi);
	TRF.stash = {{sys=gi, slot=1, clan=gs, cls=2, v=200, seed=4711, leg=TRF.clock.legs, st=1, src=1, sf=2, sv=0, rf=0}};
	SG_Set("gaoba", 1, 1, 1);
	SG_Go("gaoba");
	local gp = SG_Pt("gaoba", 1);
	SG_MsTo(gp.x + 900, gp.y, gp.z);
	HOST_Check(SG_Nav("TRF_STASH_AR_1") ~= nil, "a known cache: its area marker");
	TRF_ShFound(1, "test");
	HOST_Check(SG_Nav("TRF_STASH_AR_1") == nil and SG_Nav("TRF_STASH_NP_1") ~= nil, "found: the area marker goes before the attached one (one marker per cache)");
	n0 = S_Mark();
	SG_Run(11);
	HOST_Check(SG_Nav("TRF_SG_AR_"..gs) ~= nil and S_Logs(n0, "owner=signal label=TRF_SG_AR_"..gs.." class=offer offer_count=2 result=added") == 1, "the signal marker fits beside the cache (2 = mk_offer)");
	h.cfg.enable_stashes = 0;
	TRF.stash = nil;
	-- Two test owners with older records bump the signal marker; A08 adds it again when one clears.
	TRF_MarkerClear("stash");
	TRF_MarkerOfferReg("tsta"); TRF_MarkerOfferReg("tstb");
	local g = SG_Rec("gaoba").g;
	n0 = S_Mark();
	HOST_Check(TRF_MarkerAdd("tsta", "TRF_TSTA_1", 10, 0, 10, "", nil, nil, g - 5) == 1, "an older test record fits (2 offer markers)");
	HOST_Check(TRF_MarkerAdd("tstb", "TRF_TSTB_1", 20, 0, 20, "", nil, nil, g - 6) == 1 and SG_Nav("TRF_SG_AR_"..gs) == nil
		and S_Logs(n0, "module=plumb event=marker owner=signal label=TRF_SG_AR_"..gs.." class=offer offer_count=1 result=bumped by=TRF_TSTB_1") == 1
		and TRF_MarkerHeld("TRF_SG_AR_"..gs) == nil and TRF_MarkerHeld("TRF_TSTB_1") == 1,
		"a second older record bumps the newest offer marker (the signal's)");
	HOST_Check(TRF_MarkerAdd("tsta", "TRF_TSTA_2", 30, 0, 30, "", nil, nil, g + 5) == nil, "a newer record is refused at the cap (offer_cap)");
	SG_Run(1.5);
	HOST_Check(SG_Nav("TRF_SG_AR_"..gs) == nil and S_Logs(n0, "owner=signal label=TRF_SG_AR_"..gs.." class=offer offer_count=2 result=refused reason=offer_cap") >= 1,
		"A08 tries again at the step: refused while the older two hold the cap");
	TRF_MarkerClear("tsta");
	SG_Run(1.5);
	HOST_Check(SG_Nav("TRF_SG_AR_"..gs) ~= nil, "one test owner clears: the signal marker is back");
	TRF_MarkerClear();
end;

-- e: show and pickup -----------------------------------------------------------------------

-- Entry into sunji with a read source (t 2), the mothership far from the point.
function SG_Read2(nm)
	nm = nm or "sunji";
	SG_Set(nm, 1, 2, 1);
	SG_Go(nm);
	local p = SG_Pt(nm, 1);
	SG_MsTo(p.x + 900, p.y, p.z);
	SG_Run(1.5);
end;

-- Flies the mothership from x + dx0 toward the point in steps of st units a tick until x + dx1.
function SG_Fly(nm, dx0, dx1, st)
	local p = SG_Pt(nm or "sunji", 1);
	local x = dx0;
	while x >= dx1 do
		SG_MsTo(p.x + x, p.y, p.z);
		T_Tick(1, 0.5);
		x = x - st;
	end;
end;

function T_SG_E()
	local h = HOST();
	SG_Begin("gredos", "6", {tune={sg_pct=0, sg_stash_j=0}});
	local si = V_Idx("sunji");
	local slot = TRF_RgOf(si);
	-- 1x: show within 500, pickup within 60; outcome lore (no trail, stash or ring).
	SG_Read2();
	HOST_Check(SG_Nav("TRF_SG_AR_"..slot) ~= nil and SG_Obj(slot) == nil, "far away: the area marker, no object");
	local s0, n0 = getn(h.screen), S_Mark();
	SG_Fly("sunji", 880, 520, 20);
	HOST_Check(SG_Obj(slot) == nil, "outside sg_show_r: no object");
	SG_Fly("sunji", 500, 480, 20);
	local o = SG_Obj(slot);
	HOST_Check(o and o.tpl == "radiopod" and HOST_Dist(o.pos, SG_Pt("sunji", 1)) < 1 and SG_Nav("TRF_SG_AR_"..slot) == nil and SG_Nav("TRF_SG_NP_"..slot)
		and SG_Nav("TRF_SG_NP_"..slot).obj == o and SG_Has(SG_Scr(s0), TRF_Txt("sgnear")) and SG_Logs(n0, "event=show system=sunji system_index="..si) == 1
		and SG_Logs(n0, "model=radiopod label=TRF_SGO_"..slot.." result=placed") == 1, "within sg_show_r: the recorder, the attached marker instead of the area marker, the near line");
	SG_Fly("sunji", 460, 80, 20);
	HOST_Check(SG_Obj(slot) ~= nil and SG_T("sunji") == 2, "not yet within sg_pick_r");
	local m0 = getn(h.msgs);
	SG_Fly("sunji", 60, 40, 20);
	local ms = SG_Msgs(m0);
	HOST_Check(SG_Obj(slot) == nil and SG_T("sunji") == 3 and TRF_PlMkCount() == 0 and (SG_Has(ms, TRF_Txt("sgreclore1")) or SG_Has(ms, TRF_Txt("sgreclore2")))
		and SG_Logs(n0, "outcome=lore stash_index=nil stash_system=nil") == 1 and SG_Logs(n0, "result=found") == 1, "pickup: the object goes, markers cleared, rest, the lore line");
	-- 8x: one long step from outside sg_show_r through the point shows and picks up in one tick.
	SG_Read2();
	n0 = S_Mark();
	local p = SG_Pt("sunji", 1);
	SG_MsTo(p.x + 600, p.y, p.z);
	T_Tick(1, 0.5);
	HOST_Check(SG_Obj(slot) == nil and SG_T("sunji") == 2, "600 units away: nothing yet");
	SG_MsTo(p.x - 200, p.y, p.z);
	T_Tick(1, 0.5);
	HOST_Check(SG_T("sunji") == 3 and SG_Logs(n0, "result=placed") == 1 and SG_Logs(n0, "segment=0 result=found") == 1, "an 800-unit step through the point (8x): show and pickup in one tick (swept segment)");
	HOST_Check(TRF_SgPickOf({x=0, y=0, z=0}, {x=-200, y=50, z=0}, {x=200, y=50, z=0}, 60) == 1 and TRF_SgPickOf({x=0, y=0, z=0}, {x=-200, y=70, z=0}, {x=200, y=70, z=0}, 60) == nil,
		"TRF_SgPickOf: the segment's distance, not the end points");
	-- Outcome 1: a trail fragment (A07 hook).
	TRF_Tr_SignalFrag = function(idx) return "A trail fragment."; end;
	SG_Read2();
	m0 = getn(h.msgs);
	n0 = S_Mark();
	SG_Fly("sunji", 100, 0, 50);
	TRF_Tr_SignalFrag = nil;
	HOST_Check(SG_Logs(n0, "outcome=trail") == 1 and SG_Has(SG_Msgs(m0), "A trail fragment."), "outcome 1: the A07 trail fragment");
	-- Outcome 2 (from farles, which has caches within 4 jumps): the nearest unknown cache within sg_stash_j jumps, never the
	-- current system.
	SG_Tune("sg_stash_j", 4);
	h.cfg.enable_stashes = 1;
	local fi = V_Idx("farles");
	local fsl = TRF_RgOf(fi);
	local near = TRF_RgNear(fi, 4);
	local cand = {};
	for i = 1, getn(near) do if TRF_ShSlots(TRF_SysName(near[i].idx)) then tinsert(cand, near[i]); end; end;
	sort(cand, function(a, b) if a.j ~= b.j then return a.j < b.j; end; return a.idx < b.idx; end);
	HOST_Check(getn(cand) >= 2 and cand[getn(cand)].j > 1, "stash systems within 4 jumps of farles");
	local c1, c2 = cand[1], cand[getn(cand)];
	SG_Read2("farles");
	TRF.stash = {};
	TRF.stash[1] = {sys=c2.idx, slot=1, clan=TRF_RgOf(c2.idx), cls=2, v=200, seed=11, leg=TRF.clock.legs, st=0, src=0, sf=0, sv=0, rf=0};
	TRF.stash[2] = {sys=fi, slot=1, clan=fsl, cls=2, v=200, seed=12, leg=TRF.clock.legs, st=0, src=0, sf=0, sv=0, rf=0};
	TRF.stash[3] = {sys=c1.idx, slot=1, clan=TRF_RgOf(c1.idx), cls=2, v=200, seed=13, leg=TRF.clock.legs, st=0, src=0, sf=0, sv=0, rf=0};
	m0 = getn(h.msgs);
	n0 = S_Mark();
	SG_Fly("farles", 100, 0, 50);
	local r3 = TRF.stash[3];
	HOST_Check(r3.st == 1 and r3.src == 5 and r3.sf == 0 and TRF.stash[2].st == 0 and TRF.stash[1].st == 0 and SG_Logs(n0, "outcome=stash stash_index=3 stash_system="..TRF_SysName(c1.idx)) == 1
		and S_Logs(n0, "module=stash event=reveal index=3 system="..TRF_SysName(c1.idx).." source=5 from=farles jumps="..c1.j.." result=ok") == 1
		and SG_Has(SG_Msgs(m0), TRF_Txt("sgrecstash", TRF_ClanName(r3.clan), TRF_UI_SysName(c1.idx))), "outcome 2: the nearest cache revealed (st 1, src 5), never the current system");
	TRF_Sh_Fix();
	HOST_Check(TRF.stash[3] and TRF.stash[3].src == 5, "the stash repair keeps src 5");
	-- Out of range: sg_stash_j 1 and only a far cache.
	TRF.stash = {{sys=c2.idx, slot=1, clan=TRF_RgOf(c2.idx), cls=2, v=200, seed=11, leg=TRF.clock.legs, st=0, src=0, sf=0, sv=0, rf=0}};
	HOST_Check(TRF_Sh_Reveal(fi, 1, 5) == nil and TRF.stash[1].st == 0, "a cache beyond the range: no reveal");
	TRF.stash = nil;
	h.cfg.enable_stashes = 0;
	-- Outcome 3: the ring rumour, signal records left out.
	near = TRF_RgNear(si, 1);
	local nb = near[1].idx;
	local ns = TRF_RgOf(nb);
	TRF.ti = nil;
	local tib = {};
	for b = 1, TRF_RgMap().n do tib[b] = {}; end;
	tinsert(tib[ns], {k=13, s=nb, l=0, g=TRF.clock.legs, c=0, a=1, f=0});
	tinsert(tib[ns], {k=1, s=nb, l=0, g=TRF.clock.legs - 1, c=0, a=0, f=0});
	TRF.ti = TRF_TiJoinOf(tib, TRF_RgMap().n);
	SG_Read2();
	m0 = getn(h.msgs);
	n0 = S_Mark();
	SG_Fly("sunji", 100, 0, 50);
	local ml = SG_Msgs(m0);
	HOST_Check(SG_Logs(n0, "outcome=ring") == 1 and S_Logs(n0, "module=tips event=pick surface=hail") == 1 and S_Logs(n0, "event=pick surface=hail system=sunji kind=raid target="..TRF_SysName(nb)) == 1
		and SG_Has(ml, "The recorder's last entry: "), "outcome 3: the ring rumour of a raid, the signal record left out");
	TRF.ti = nil;
	-- The recorder shot: destroyed, the lost line.
	SG_Read2();
	SG_Fly("sunji", 400, 380, 20);
	o = SG_Obj(slot);
	o.alive = nil;
	s0, n0 = getn(h.screen), S_Mark();
	T_Tick(1, 0.5);
	HOST_Check(SG_T("sunji") == 3 and TRF_PlMkCount() == 0 and SG_Has(SG_Scr(s0), TRF_Txt("sglost")) and SG_Logs(n0, "outcome=destroyed") == 1, "the recorder shot: rest, markers cleared, the lost line");
	-- The object deleted at the jump; the record keeps t 2.
	SG_Read2();
	SG_Fly("sunji", 400, 380, 20);
	o = SG_Obj(slot);
	n0 = S_Mark();
	T_Jump("gredos");
	HOST_Check(o and not o.alive and SG_T("sunji") == 2 and SG_Logs(n0, "event=orphan_delete label=TRF_SGO_"..slot.." reason=jump") == 1, "jump: the object goes, the record stays t 2");
	-- Orphans at the entry (a jump that bypassed TRF_BeforeJump) and at a load.
	h.sghook = function() local o = CreateCarcass("radiopod", Vector3(0, 0, 0)); SetObjectLabel(o, "TRF_SGO_3"); end;
	n0 = S_Mark();
	T_Jump("sunji");
	h.sghook = nil;
	HOST_Check(SG_Obj(3) == nil and SG_Logs(n0, "event=orphan_delete label=TRF_SGO_3 reason=entry") == 1, "an orphan at the entry is deleted");
	SG_Read2();
	SG_Fly("sunji", 400, 380, 20);
	o = SG_Obj(slot);
	n0 = S_Mark();
	T_SaveLoad();
	HOST_Check(o and not o.alive and SG_Logs(n0, "event=orphan_delete label=TRF_SGO_"..slot.." reason=load") == 1 and SG_Nav("TRF_SG_AR_"..slot) ~= nil,
		"load: the object found by label is deleted, the area marker again");
	SG_MsTo(p.x + 300, p.y, p.z);
	SG_Run(1.5);
	HOST_Check(SG_Obj(slot) ~= nil, "after the load: shown again on approach");
	-- Wind-down.
	n0 = S_Mark();
	TRF_WindDown();
	HOST_Check(SG_Obj(slot) == nil and TRF_PlMkCount() == 0 and SG_Logs(n0, "reason=wind") == 1 and SG_T("sunji") == 2, "wind-down: object and marker go, the record stays");
	-- A record that rests while shown (region tick): the object goes at the next tick.
	SG_Read2();
	SG_Fly("sunji", 400, 380, 20);
	local r = SG_Rec("sunji"); r.t = 3; TRF_SgPut(r);
	T_Tick(1, 0.5);
	HOST_Check(SG_Obj(slot) == nil and TRF_PlMkCount() == 0, "a rest while shown: the object and marker go");
	-- Show failed (blocked spot): retried after 10 s.
	SG_Read2();
	h.block_r = 5000;
	local sh = HOST_Obj("blocker", 0, 0, 0);
	sh.kind = "ship"; tinsert(h.ships, sh);
	n0 = S_Mark();
	SG_Fly("sunji", 400, 380, 20);
	HOST_Check(SG_Logs(n0, "result=failed") == 1 and SG_Obj(slot) == nil, "CreateCarcass nil: show failed");
	SG_Run(3);
	HOST_Check(SG_Logs(n0, "result=failed") == 1, "no retry before 10 s");
	sh.alive = nil; h.block_r = 3;
	SG_Run(8);
	HOST_Check(SG_Logs(n0, "result=placed") == 1 and SG_Obj(slot) ~= nil, "retried after 10 s: placed");
end;

-- f: gates ---------------------------------------------------------------------------------

function T_SG_F()
	local h = HOST();
	SG_Begin("gredos");
	local li = V_Idx("lidau");
	local qi = TRF_Map().sys[li].qi;
	local sl = TRF_RgOf(V_Idx("sunji"));
	-- A quest naming the system in process (lidau, given a point for this run).
	SG_Extra({lidau={{0, 0, 900}}, ahilles={{0, 0, 900}}});
	T_Jump("gredos");
	SG_Set("lidau", 1, 0, 1);
	local n0, m0 = S_Mark(), getn(h.msgs);
	SG_GoNt("lidau", function() local q = %qi[1]; HOST().sghook = function() local h = HOST(); h.quests = {}; h.quests[%q] = QUEST_PROCESS; end; end);
	SG_Run(20);
	h.sghook = nil; h.quests = {};
	HOST_Check(SG_Logs(n0, "event=skip system=lidau reason=gate:quest") == 1 and SG_Logs(n0, "event=line ") == 0 and SG_T("lidau") == 0 and SG_Msgs(m0) == "",
		"a quest naming the system in process: skip gate:quest, nothing shown, t unchanged");
	-- The same quest at a region tick: the source rests (4.4 E2).
	h.quests = {}; h.quests[qi[1]] = QUEST_PROCESS;
	n0 = S_Mark();
	T_Jump("gredos");
	TRF_Sg_RegionTick(TRF.clock.legs);
	h.quests = {};
	HOST_Check(SG_T("lidau") == 3 and SG_Logs(n0, "system=lidau state=0 age=") == 1 and SG_Logs(n0, "reason=gate") == 1, "the quest at a region tick: rest (gate)");
	TRF.sg = nil;
	-- A deny entry with signal = 0.
	SG_Set("sunji", 1, 0, 1);
	n0 = S_Mark();
	SG_GoNt("sunji", function() HOST().sghook = function() local d0 = TRF_DenyEntry; TRF_DenyEntry = function(n) if n == "sunji" then return {signal=0}; end; return %d0(n); end; end; end);
	SG_Run(20);
	h.sghook = nil;
	HOST_Check(SG_Logs(n0, "event=skip system=sunji reason=gate:deny_signal") == 1 and SG_Logs(n0, "event=line ") == 0 and SG_T("sunji") == 0, "deny entry signal = 0: skip gate:deny_signal");
	-- sys_off.
	SG_Set("sunji", 1, 0, 1);
	n0 = S_Mark();
	SG_GoNt("sunji", function() HOST().cfg.sys_off = {"sunji"}; end);
	SG_Run(20);
	h.cfg.sys_off = nil;
	HOST_Check(SG_Logs(n0, "event=skip system=sunji reason=mode:sys_off") == 1 and SG_T("sunji") == 0, "sys_off: skip mode:sys_off");
	-- The start-system guard (ahilles, chapter 3 with the window opened to chapter 0).
	SG_Tune("sg_ch", 0);
	h.labels.CurrentQuest = "3";
	T_Jump("gredos");
	SG_Set("ahilles", 1, 0, 1);
	n0 = S_Mark();
	SG_GoNt("ahilles");
	SG_Run(20);
	h.labels.CurrentQuest = "6";
	SG_Tune("sg_ch", 5);
	HOST_Check(SG_Logs(n0, "event=skip system=ahilles reason=mode:guard") == 1 and SG_T("ahilles") == 0, "start system in chapter 3: skip mode:guard");
	TRF.sg = nil;
	-- The latch: a story mission seen at the entry, gone before the due.
	SG_Set("sunji", 1, 0, 1);
	n0 = S_Mark();
	SG_GoNt("sunji", function() HOST().sghook = function() HOST().qs = TRUE; end; end);
	h.sghook = nil; h.qs = FALSE;
	SG_Run(20);
	HOST_Check(SG_Logs(n0, "event=skip system=sunji reason=latch") == 1 and SG_Logs(n0, "event=line ") == 0 and SG_T("sunji") == 0, "the visit latch: no line for the visit");
	-- __disableAction at the due; __sys_SOS at the due.
	SG_Set("sunji", 1, 0, 1);
	SG_GoNt("sunji");
	__disableAction = TRUE;
	n0 = S_Mark();
	SG_Run(7);
	__disableAction = FALSE;
	SG_Run(10);
	HOST_Check(SG_Logs(n0, "result=dropped reason=hold:disable_action") == 1 and SG_T("sunji") == 0, "__disableAction at the due: dropped hold:disable_action, t 0");
	SG_GoNt("sunji");
	__sys_SOS = TRUE;
	n0 = S_Mark();
	SG_Run(7);
	__sys_SOS = FALSE;
	SG_Run(10);
	HOST_Check(SG_Logs(n0, "result=dropped reason=hold:sys_sos") == 1 and SG_T("sunji") == 0, "__sys_SOS at the due: dropped hold:sys_sos");
	-- A scene between the queue and the say.
	SG_GoNt("sunji");
	SG_Run(7);
	local im = TRF_InMovie;
	TRF_InMovie = HOST_InMovie; h.mov = 1;
	n0 = S_Mark();
	SG_Run(2);
	TRF_InMovie = im; h.mov = nil;
	HOST_Check(SG_Logs(n0, "result=not_shown reason=hold:scene") == 1 and SG_T("sunji") == 0, "a scene at the say: not shown (hold:scene), t 0");
	-- Holds at the reading: nothing read while held, read after.
	local p = SG_Pt("sunji", 1);
	SG_Set("sunji", 1, 1, 1);
	SG_GoNt("sunji");
	SG_MsTo(p.x + 900, p.y, p.z);
	__sys_SOS = TRUE;
	n0 = S_Mark();
	SG_Run(15);
	HOST_Check(SG_Logs(n0, "event=read ") == 0 and SG_T("sunji") == 1 and SG_Logs(n0, "event=skip system=sunji reason=hold:sys_sos") == 1, "__sys_SOS at the reading: skip, t 1");
	__sys_SOS = FALSE;
	SG_Run(1.5);
	HOST_Check(SG_T("sunji") == 2, "read once the hold ends");
	-- Holds at the show: no object while __disableAction holds.
	__disableAction = TRUE;
	SG_MsTo(p.x + 300, p.y, p.z);
	SG_Run(2);
	HOST_Check(SG_Obj(sl) == nil, "__disableAction: no show");
	__disableAction = FALSE;
	SG_Run(1.5);
	HOST_Check(SG_Obj(sl) ~= nil, "shown once the hold ends");
	-- Chapters 4 and 5.
	SG_Set("sunji", 1, 0, 1);
	h.labels.CurrentQuest = "4";
	n0 = S_Mark();
	SG_GoNt("sunji");
	SG_Run(20);
	HOST_Check(SG_Logs(n0, "event=skip system=sunji reason=chapter") == 1 and SG_T("sunji") == 0, "chapter 4: skip chapter");
	TRF.sg = nil;
	SG_Phase(0);
	SG_Tune("sg_pct", 100);
	TRF.clock.legs = TRF.clock.legs + 1;
	n0 = S_Mark();
	TRF_Sg_RegionTick(TRF.clock.legs);
	HOST_Check(TRF.sg == nil and SG_Logs(n0, "result=none reason=chapter") == 1, "chapter 4: no light");
	h.labels.CurrentQuest = "5";
	SG_Tune("sg_pct", 0);
	SG_Set("sunji", 1, 0, 1);
	n0 = S_Mark();
	SG_GoNt("sunji");
	SG_Run(10);
	HOST_Check(SG_Logs(n0, "result=shown") == 1 and SG_T("sunji") == 1, "chapter 5: the line");
	h.labels.CurrentQuest = "6";
end;

-- g: save and repair -----------------------------------------------------------------------

function T_SG_G()
	local h = HOST();
	SG_Begin("gredos");
	local si, gi, ai = V_Idx("sunji"), V_Idx("gaoba"), V_Idx("areko");
	local ks, ka = TRF_RgOf(si), TRF_RgOf(ai);
	local n = TRF_RgMap().n;
	HOST_Check(n == 8, "8 region slots");
	-- F1 a number.
	TRF.sg = 42;
	local n0 = S_Mark();
	TRF_Sg_Fix();
	HOST_Check(TRF.sg == nil and SG_Logs(n0, "event=fix kept=0 dropped=1 moved=0") == 1, "F1: a number is dropped");
	-- F2-F4: bad digits, a short block, an unknown system, a point above the count, state 7, a record in the wrong block,
	-- 9 blocks.
	local enc = function(s, p, t) return TRF_SgEncOf({s=s, p=p, g=TRF.clock.legs, t=t}); end;
	local blk = {};
	for b = 1, 9 do blk[b] = ""; end;
	blk[ks] = enc(si, 2, 1);
	blk[1] = "0782x001";
	if ks == 1 then blk[2] = "0782x001"; end;
	blk[3] = "0781";
	blk[4] = enc(V_Idx("gredos"), 1, 0);
	blk[6] = enc(V_Idx("tarrot"), 3, 0);
	blk[7] = "07810997";
	blk[9] = enc(ai, 1, 0);
	if ka == 9 then blk[8] = enc(ai, 1, 0); end;
	local s = blk[1];
	for b = 2, 9 do s = s.."/"..blk[b]; end;
	TRF.sg = s;
	n0 = S_Mark();
	TRF_Sg_Fix();
	local bs = TRF_SgBlocks();
	HOST_Check(bs[ks] and bs[ks].s == si and bs[ks].p == 2 and bs[ks].t == 1 and bs[ka] and bs[ka].s == ai and SG_Logs(n0, "event=fix kept=2 dropped=5 moved=1") == 1
		and strlen(TRF.sg) == 8 * 2 + n - 1, "F2-F5: bad digits, short, unknown system, point above the count, state 7 dropped; the wrong block moved; 8 blocks ("..tostring(TRF.sg)..")");
	-- A second record of an occupied region is dropped, not moved.
	local s2 = TRF.sg.."/"..enc(gi, 1, 0);
	TRF.sg = s2;
	n0 = S_Mark();
	TRF_Sg_Fix();
	HOST_Check(SG_Logs(n0, "event=fix kept=2 dropped=1 moved=0") == 1, "F4: a record for an occupied block is dropped");
	n0 = S_Mark();
	TRF_Sg_Fix();
	HOST_Check(SG_Logs(n0, "event=fix ") == 0, "a clean string is left alone");
	-- 8 full blocks: the size bound.
	local full = {};
	for b = 1, 8 do full[b] = {s=999, p=4, g=TRF.clock.legs, t=3}; end;
	TRF.sg = TRF_SgJoinOf(full, 8);
	HOST_Check(HOST_SaveSize(TRF.sg) + 10 <= 89 and HOST_SaveSize(TRF.sg) + 10 == 89, "8 records: "..(HOST_SaveSize(TRF.sg) + 10).." bytes with the key (<= 89)");
	HOST_Check(TRF_SgJoinOf({}, 8) == nil, "every block empty: nil");
	-- Save and load keep TRF.sg; the dump.
	TRF.sg = nil;
	SG_Set("sunji", 2, 1, 3);
	local before = TRF.sg;
	T_SaveLoad();
	n0 = S_Mark();
	TRF_Sg_Dump();
	HOST_Check(TRF.sg == before and SG_Logs(n0, "event=dump on=1 record_count=1 records="..ks..":sunji/2/1/3") == 1, "save and load keep TRF.sg; the dump");
	-- Full state.
	local size = 8 + 3 + HOST_SaveSize(TRF);
	HOST_Check(size < 100000 and HOST_Reserved(TRF, "TRF") == "", "full state "..size.." bytes < 100000, no reserved key");
	-- RU fixed forms: 16 keys, CRLF, cp1251.
	local ru = SG_Read(h.dir.."../../../../loc/trf_ru.loc");
	local miss = "";
	for k, v in TRF_Sg_Text() do if not SG_Has(ru, format("\r\n#TRF_%s = ", k)) then miss = miss.." "..k; end; end;
	if not SG_Has(ru, "\r\n#TRF_tisignal = ") then miss = miss.." tisignal"; end;
	HOST_Check(ru and miss == "" and SG_Count(ru, "\n") == SG_Count(ru, "\r\n") and not strfind(ru, "\208[\128-\191]"), "loc/trf_ru.loc: the 16 keys, CRLF, cp1251"..miss);
end;

-- Dispatch -----------------------------------------------------------------------------------------------

local sc = getenv("TRF_SG") or "";
local fn = getglobal("T_SG_"..strupper(sc));
print("HOST ==== static signals scenario sg-"..sc.." dir="..HOST().dir);
if type(fn) == "function" then
	fn();
	HOST_Check(T_LeftGlobals() == "", "no handle globals left at the end"..T_LeftGlobals());
else
	HOST_Check(nil, "unknown static signals scenario "..sc);
end;
HOST_Check((HOST().gpm_tick or 0) == 0, "no GetPlayerMotherShip from a tick (n="..tostring(HOST().gpm_tick or 0)..")");
print("HOST errors="..HOST().errors.." fails="..HOST().fails);
if HOST().errors > 0 or HOST().fails > 0 then exit(1); end;
exit(0);
