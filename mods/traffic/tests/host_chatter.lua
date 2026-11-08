-- Station chatter scenarios (design/station-chatter-spec.md 11) under stock Lua 4.0.1: TRF_RC=a..h, run by run_host.sh as
-- its own entry point. a install (loader, lists, texts, cfg and tune defaults and clamps, the getters, no TRF key, chatter
-- 0, one exchange through the 1 s dispatch); b events (4.1 for every docking step, the collapse to go, path B, records met
-- mid-way or at a load, dock_mode 0, excluded records); c rate and repetition (rc_gap in real seconds at 1x and 8x, rc_max,
-- rc_per, stale and full drops, the priority order, no key twice, the used drop); d gates (R1-R8 one by one, events still
-- age); e content first (Q1-Q5, the waiting call, the dropped answer, TRF.live.line and SV.rt untouched); f speakers and
-- texts (dispatcher per owner, leader or Trader, the carrier key, Kadenoa station 2, the destination key, bays, lengths, the
-- call signs, corp 0, the go readback); g the sound (rc_sound 0-3, the voice clips, the music volume of TRF_MusicVol x
-- rc_vol and its clamp, PlaySound missing or raising); h jump, load and the save size.
-- Loads host_station.lua up to its first scenario, as host_request.lua does. The trader records are written into
-- TRF.live.tr and their handles into TRF_H().tr (a flight with a recording lead pilot, the station object at the map
-- position) per step; the 1 s step is called directly with TRF.clock.gt and TRF.clock.rs set by the scenario (RC_Step).
-- Stubs in this file: CreatePilot pilots whose Message records the template (HOST().msgs[i].tpl); PlaySound is host_stubs'
-- HOST_PlaySound; TRF_MusicVol is nil (no DLL) unless a run sets host_stubs' HOST_MusicVol.

local f = openfile((getenv("TRF_TESTS") or "./").."host_station.lua", "r");
if not f then print("HOST FAIL host_chatter.lua: cannot open host_station.lua"); exit(1); end;
local src = read(f, "*a");
closefile(f);
local cut = strfind(src, "\n-- a: install (12.1, 6.1)", 1, 1);
if not cut then print("HOST FAIL host_chatter.lua: marker '-- a: install (12.1, 6.1)' missing in host_station.lua"); exit(1); end;
dostring(strsub(src, 1, cut), "host_station.lua");

-- Stubs ------------------------------------------------------------------------------------

function RC_Message(self, text, secs)
	HOST_Want(type(text) == "string" and type(secs) == "number", "Pilot:Message(text, secs)");
	if HOST().msg_err then error("injected Message error"); end;
	print("HOST Message "..tostring(self.tpl)..": "..tostring(text));
	tinsert(HOST().msgs, {t=text, gt=HOST().gt, tpl=self.tpl, secs=secs});
end;

RC_CreatePilot0 = CreatePilot;
function CreatePilot(tpl)
	local p = RC_CreatePilot0(tpl);
	p.Message = RC_Message;
	return p;
end;

-- Helpers ----------------------------------------------------------------------------------

-- Config of these runs: the entry events and the modules that queue arrival lines off, no trader spawns (cap_traders 0),
-- chatter on, log 2, plus t.
function RC_Cfg(t)
	local c = {sweeps=0, sweep_ct=0, feq=0, staged=0, seed=0, queue=0, parked=0, voice_events=0, dconv=0, carriers=0, po=0,
		enable_survivors=0, enable_scars=0, enable_stashes=0, enable_freight=0, warn=0, signals=0, remarks=0, survey=0, track=0,
		cap_enable=0, cap_board=0, cap_intel=0, cap_chase=0, lad_enabled=0, charter=0, temper=0, corp=0, debrief=0, requests=0,
		cap_traders=0, raids=0, contracts=0, chatter=1, log=2};
	if t then for k, v in t do c[k] = v; end; end;
	return c;
end;

-- The scene of an entry runs HOST().rchook after the module files are loaded and before TRF_OnEnter.
RC_Scene0 = T_Scene;
function T_Scene(sys)
	RC_Scene0(sys);
	local h = HOST();
	if h.rchook then h.rchook(); end;
end;

-- Scenario start in sys at chapter label ch (default 6), the cue stub installed, a clean visit (RC_Fresh).
function RC_Begin(sys, ch, t)
	local h = HOST();
	h.labels.CurrentQuest = ch or "6";
	h.quests = {}; h.qlog = {};
	h.qs = FALSE;
	h.rchook = nil;
	h.psnd = {}; h.psnd_err = nil; h.msg_err = nil;
	h.mvol = nil; h.svol = nil; h.mvol_why = nil; h.mvol_n = 0;
	PlaySound = HOST_PlaySound;
	TRF_MusicVol = nil;
	S_Begin(sys, RC_Cfg(t));
	RC_Fresh();
end;

-- The stations of the current system (map entries) and the station key of ordinal j.
function RC_St(j) return TRF_RcTlOf(TRF_Map(), TRF_CurIdx())[j or 1]; end;
function RC_Key(j) return TRF_Stn_Key(TRF_CurIdx(), j or 1); end;

-- The mothership d units off station j in x (nil: far away).
function RC_Ms(d, j)
	local s = RC_St(j);
	if not d then HOST().ms.pos = Vector3(9000, 0, 9000); return; end;
	HOST().ms.pos = Vector3(s.x + d, s.y, s.z);
end;

-- A clean visit: no trader records or handles, the approach radio of every station done, no content line stamps, the
-- clocks at gt 1000 and rs 5000, the mothership 600 off station 1, no recorded lines or cues.
function RC_Fresh()
	local h = HOST();
	TRF.live.tr = {};
	TRF_H().tr = {};
	TRF_RcVisit();
	local sv = TRF_StnSV();
	local n = getn(TRF_RcTlOf(TRF_Map(), TRF_CurIdx()));
	for j = 1, n do sv.nr[RC_Key(j)] = 2; end;
	sv.rt = nil;
	TRF.live.line = nil; TRF.live.aqt = nil;
	TRF.clock.gt = 1000; TRF.clock.rs = 5000;
	if n > 0 then RC_Ms(600); end;
	h.msgs = {}; h.psnd = {};
end;

-- A trader record id (path A, st "in", born now, name 1 + id mod 9, cargo class 1, from the first portal's system) with
-- the fields of t; its handles: the station object of ordinal t.j (default 1) and a flight whose lead pilot is "lead<id>"
-- (t.nolead: no flight). Returns the record.
function RC_Tr(id, t)
	t = t or {};
	local r = {id=id, nm=1 + mod(id, 9), cls=1, from=V_Idx("aurora"), to=0, path="A", st="in", born=TRF.clock.gt, k=1, np=1,
		nt=1, esc=0, lt=TRF.clock.gt, wd=0, tier=1, hold={}, pw=3};
	for k, v in t do if k ~= "j" and k ~= "nolead" then r[k] = v; end; end;
	TRF.live.tr[id] = r;
	local s = RC_St(t.j);
	local hd = {st=HOST_Obj("RC_ST", s.x, s.y, s.z), k=1};
	if not t.nolead then
		local p = CreatePilot("lead"..id);
		hd.fl = {__obj=1, p=p, alive=1};
		hd.fl.IsAlive = function(self) if self.alive then return 1; end; return nil; end;
		hd.fl.GetLeader = function(self) return self.p; end;
		hd.fl.Delete = function(self) self.alive = nil; end;
	end;
	TRF_H().tr[id] = hd;
	return r;
end;

-- n 1 s steps: game time +1 each, real time +dr (default 1).
function RC_Step(n, dr)
	for i = 1, (n or 1) do
		TRF.clock.gt = TRF.clock.gt + 1;
		TRF.clock.rs = TRF.clock.rs + (dr or 1);
		TRF_Rc_Step();
	end;
end;

function RC_Has(s, t) return strfind(s or "", t, 1, 1) ~= nil; end;
function RC_N(t) local n = 0; for k, v in t do n = n + 1; end; return n; end;

-- chatter log lines after mark n0 holding pat (plain).
function RC_Logs(n0, pat)
	local n, q = 0, HOST().logs;
	for i = n0 + 1, getn(q) do if strfind(q[i], "module=chatter ", 1, 1) and strfind(q[i], pat, 1, 1) then n = n + 1; end; end;
	return n;
end;

-- Last chatter log line after n0 holding pat, or "".
function RC_Line(n0, pat)
	local q, r = HOST().logs, "";
	for i = n0 + 1, getn(q) do if strfind(q[i], "module=chatter ", 1, 1) and strfind(q[i], pat, 1, 1) then r = q[i]; end; end;
	return r;
end;

-- Every chatter log line after n0 holding pat.
function RC_All(n0, pat)
	local q, o = HOST().logs, {};
	for i = n0 + 1, getn(q) do if strfind(q[i], "module=chatter ", 1, 1) and strfind(q[i], pat, 1, 1) then tinsert(o, q[i]); end; end;
	return o;
end;

-- Value of key k in a logfmt line, or nil.
function RC_Kv(line, k)
	local a, b, v = strfind(line or "", " "..k.."=([^ ]*)");
	return v;
end;

-- The shown calls after n0.
function RC_Calls(n0)
	local o, q = {}, RC_All(n0, "part=call ");
	for i = 1, getn(q) do if strfind(q[i], " result=shown ", 1, 1) then tinsert(o, q[i]); end; end;
	return o;
end;

-- Radio lines after m0: "tpl:text|...".
function RC_Msgs(m0)
	local q, s = HOST().msgs, "";
	for i = (m0 or 0) + 1, getn(q) do s = s..tostring(q[i].tpl)..":"..q[i].t.."|"; end;
	return s;
end;

function RC_ReadFile(p)
	local fh = openfile(p, "rb");
	if not fh then return nil; end;
	local s = read(fh, "*a");
	closefile(fh);
	return s;
end;

-- The keys of t, sorted and joined by ",".
function RC_Keys(t)
	local o = {};
	for k, v in t do tinsert(o, tostring(k)); end;
	sort(o);
	local s = "";
	for i = 1, getn(o) do if i > 1 then s = s..","; end; s = s..o[i]; end;
	return s;
end;

-- One docking request exchange of trader id: the record from "in" to "dock" and the steps until the answer is due.
function RC_Req(id, t)
	RC_Tr(id, t);
	RC_Step(1);
	TRF.live.tr[id].st = "dock";
	RC_Step(1);
end;

-- a: install (10, 7, 8, 9) -----------------------------------------------------------------

function T_RC_A()
	local h = HOST();
	RC_Begin("gredos");
	HOST_Check(S_Logs(0, "module=core event=loaded map=true module_count=18 extra_count=26") >= 1, "trf_chatter loads last (extra_count=26)");
	local ml, pm, tf, uf = TRF_ModList(), TRF_PlMods(), TRF_Loc_TextFns(), TRF_UI_TextFns();
	local pmh = nil;
	for i = 1, getn(pm) do if pm[i] == "Rc" then pmh = 1; end; end;
	HOST_Check(ml[getn(ml)] == "Rc" and ml[getn(ml) - 1] == "Rq" and tf[getn(tf) - 1] == "TRF_Rc_Text" and tf[getn(tf) - 2] == "TRF_Rq_Text"
		and tf[getn(tf)] == "TRF_Loc_Text" and uf[getn(uf)] == "TRF_Rc_Text" and uf[getn(uf) - 1] == "TRF_Rq_Text" and not pmh,
		"Rc last in TRF_ModList (not a plumb module); TRF_Rc_Text after TRF_Rq_Text in both text lists");
	HOST_Check(TRF_OptEnum().chatter == 1 and TRF_Opt("chatter") == 1 and TRF_Rc_OptDef().chatter == 1 and TRF_Config().chatter == 1,
		"cfg chatter 1 in config.script and TRF_Rc_OptDef, enumerated 0..1");
	-- Texts (7): 21 keys rch* (18 line keys, rchctl, rchctl2, rchhvy), each found by TRF_Txt, no %, # or line break; the
	-- scaffold holds their fixed forms.
	local tx = TRF_Rc_Text();
	local n, bad = 0, "";
	for k, v in tx do
		n = n + 1;
		if strfind(v, "%", 1, 1) or strfind(v, "#", 1, 1) or strfind(v, "\n", 1, 1) or strsub(k, 1, 3) ~= "rch" then bad = bad.." "..k; end;
		if TRF_Txt(k) == k then bad = bad.." unknown:"..k; end;
	end;
	local nl = 0;
	for k, v in TRF_RcK().vo do if tx[k] then nl = nl + 1; end; end;
	HOST_Check(n == 21 and nl == 18 and bad == "", "21 rch text keys (18 line keys with a clip, rchctl, rchctl2, rchhvy), no %, # or line break, every key found by TRF_Txt"..bad);
	local en = RC_ReadFile(h.dir.."../../../../loc/trf_en.loc");
	local cr, lf = strchar(13), strchar(10);
	local miss = "";
	for k, v in tx do
		local want = cr..lf.."#TRF_"..TRF_LocKey(k).." = "..TRF_Loc_Plain(v)..cr..lf;
		if not (en and strfind(en, want, 1, 1)) then miss = miss.." "..k; end;
	end;
	HOST_Check(miss == "", "loc/trf_en.loc: the 21 rch keys with their fixed forms (gen_map.py --loc)"..miss);
	-- Tune defaults and clamps (8).
	local T = TRF_RcTune();
	HOST_Check(RC_N(TRF_Rc_TuneDef()) == 13 and T.rc_r == 1500 and T.rc_gap == 45 and T.rc_pair == 6 and T.rc_secs == 6 and T.rc_quiet == 10
		and T.rc_stale == 20 and T.rc_max == 6 and T.rc_per == 2 and T.rc_dock_r == 300 and T.rc_pos == 300 and T.rc_bays == 6
		and T.rc_sound == 3 and T.rc_vol == 80, "13 tune keys with the defaults of spec 8 (rc_sound 3, rc_vol 80)");
	h.cfg.tune = {rc_r=99999, rc_gap=1, rc_pair=45.7, rc_sound=7, rc_vol=-5, rc_bays=0, rc_quiet="x"};
	T = TRF_RcTune();
	HOST_Check(T.rc_r == 5000 and T.rc_gap == 10 and T.rc_pair == 20 and T.rc_sound == 3 and T.rc_vol == 0 and T.rc_bays == 1
		and T.rc_quiet == 10, "tune clamps: rc_r 5000, rc_gap 10, rc_pair 20 (45.7 floored, clamped), rc_sound 3, rc_vol 0, rc_bays 1, a string reads as the default");
	h.cfg.tune = {};
	h.cfg.chatter = 7;
	HOST_Check(TRF_RcOpt("chatter") == 1, "cfg chatter outside 0..1 reads as the default 1");
	h.cfg.chatter = 1;
	-- The getters (10.3).
	local idx = TRF_CurIdx();
	RC_Tr(41);
	local p = TRF_Gen_DockPos(41);
	local s = RC_St(1);
	HOST_Check(type(p) == "table" and p.x == s.x and p.y == s.y and p.z == s.z, "TRF_Gen_DockPos: the position of the trader's station handle");
	TRF_H().tr[41] = nil;
	p = TRF_Gen_DockPos(41);
	local sp = h.station:GetPosition();
	HOST_Check(type(p) == "table" and p.x == sp.x and p.z == sp.z and TRF_Gen_DockPos("x") ~= nil, "TRF_Gen_DockPos: without a handle the system's trade station");
	TRF_H().tr[41] = {st=HOST_Obj("DEAD", 0, 0, 0)};
	TRF_H().tr[41].st.alive = nil;
	p = TRF_Gen_DockPos(41);
	HOST_Check(type(p) == "table" and p.x == sp.x, "TRF_Gen_DockPos: a dead station handle falls back to the system's trade station");
	TRF.live.aqt = nil;
	HOST_Check(TRF_ArrivalLast() == nil, "TRF_ArrivalLast: nil without a queued arrival line");
	TRF.live.aqt = 1234;
	HOST_Check(TRF_ArrivalLast() == 1234, "TRF_ArrivalLast: the due time of the last queued arrival line (live.aqt)");
	TRF.live.aqt = nil;
	h.teams.gredos = "Vks";
	local c = TRF_Stn_ChatCtx(idx, 1);
	HOST_Check(type(c) == "table" and c.why == nil and c.spk == "DispetcherVKS" and c.near == 0 and c.rt == nil,
		"TRF_Stn_ChatCtx: gate open, the Vks dispatcher, the approach done (near 0), no radio stamp");
	TRF_StnSV().nr[RC_Key(1)] = 1;
	HOST_Check(TRF_Stn_ChatCtx(idx, 1).near == 1, "TRF_Stn_ChatCtx: near 1 while the greeting is said and the info line pending");
	TRF_StnSV().nr[RC_Key(1)] = nil;
	RC_Ms(1000);
	HOST_Check(TRF_Stn_ChatCtx(idx, 1).near == 1, "TRF_Stn_ChatCtx: near 1 within stn_hail_r before the greeting");
	RC_Ms(1600);
	HOST_Check(TRF_Stn_ChatCtx(idx, 1).near == 0, "TRF_Stn_ChatCtx: near 0 outside stn_hail_r");
	RC_Ms(1000);
	TRF_StnSV().dk[RC_Key(1)] = 1;
	HOST_Check(TRF_Stn_ChatCtx(idx, 1).near == 0, "TRF_Stn_ChatCtx: near 0 after the docking");
	TRF_StnSV().dk[RC_Key(1)] = nil;
	h.cfg.voice_near = 0;
	HOST_Check(TRF_Stn_ChatCtx(idx, 1).near == 0, "TRF_Stn_ChatCtx: near 0 with voice_near 0");
	h.cfg.voice_near = nil;
	h.cfg.voice = 0;
	HOST_Check(TRF_Stn_ChatCtx(idx, 1).why == "off", "TRF_Stn_ChatCtx: why off with voice 0");
	h.cfg.voice = nil;
	-- The module body: functions and RC only; no TRF key after a full exchange.
	RC_Fresh();
	local k0, l0 = RC_Keys(TRF), RC_Keys(TRF.live);
	local n0, m0 = S_Mark(), getn(h.msgs);
	RC_Req(42);
	RC_Step(8);
	HOST_Check(RC_Logs(n0, "event=say kind=req part=call") == 1 and RC_Logs(n0, "event=say kind=req part=answer") == 1
		and RC_Logs(n0, "result=shown") == 2 and getn(h.msgs) == m0 + 2, "one request: the call and the answer shown");
	HOST_Check(RC_Keys(TRF) == k0 and RC_Keys(TRF.live) == l0 and TRF.live.line == nil and TRF_StnSV().rt == nil,
		"no TRF or TRF.live key added; TRF.live.line and SV.rt not written");
	n0 = S_Mark();
	TRF_DumpState("test");
	HOST_Check(RC_Logs(n0, "event=dump on=1 exchange_count=1 pending=nil event_count=0 keys=rchreq") == 1, "dump through TRF_ModList: "..RC_Line(n0, "event=dump"));
	-- chatter 0: no poll, no line.
	RC_Fresh();
	h.cfg.chatter = 0;
	n0, m0 = S_Mark(), getn(h.msgs);
	RC_Req(43);
	RC_Step(8);
	HOST_Check(getn(h.msgs) == m0 and RC_N(TRF_RcCV().s) == 0 and RC_Logs(n0, "event=event") == 0 and RC_Logs(n0, "event=skip system=gredos reason=off") == 1,
		"chatter 0: no poll, no event, no line; skip reason=off once");
	h.cfg.chatter = 1;
	-- The 1 s dispatch of traffic.script runs the step.
	RC_Fresh();
	n0 = S_Mark();
	RC_Tr(44);
	T_Tick(4, 0.5);
	TRF.live.tr[44].st = "dock";
	T_Tick(4, 0.5);
	HOST_Check(RC_Logs(n0, "event=event kind=req trader_id=44") == 1, "TRF_OnTick's 1 s block runs TRF_Rc_Step: "..RC_Line(n0, "event=event"));
	-- No cue native: the line still shows.
	RC_Fresh();
	PlaySound = nil;
	n0, m0 = S_Mark(), getn(h.msgs);
	RC_Req(45);
	HOST_Check(getn(h.msgs) == m0 + 1 and RC_Logs(n0, "sound=trf_voice\\rchreq") == 1 and RC_Logs(n0, "sound_result=none volume=0.800 result=shown") == 1,
		"PlaySound missing: sound_result=none, the line shown: "..RC_Line(n0, "event=say"));
	PlaySound = HOST_PlaySound;
end;

-- b: events (4.1) ---------------------------------------------------------------------------

function T_RC_B()
	local h = HOST();
	RC_Begin("gredos");
	local T = TRF_RcTune();
	-- Pure rules.
	local A = function(st, t) local r = {path="A", st=st}; if t then for k, v in t do r[k] = v; end; end; return r; end;
	local k, s = TRF_RcSeeOf(nil, A("in"), 100, T);
	local k2, s2 = TRF_RcSeeOf("in", A("dock"), 100, T);
	local k3, s3 = TRF_RcSeeOf("dock", A("dock", {dkd=1}), 100, T);
	local k4, s4 = TRF_RcSeeOf("bay", A("dock", {dkd=1}), 100, T);
	HOST_Check(k == nil and s == "in" and k2 == "req" and s2 == "dock" and k3 == "bay" and s3 == "bay" and k4 == nil and s4 == "bay",
		"path A: first sight no event, in -> dock req, dkd 1 bay, then nothing");
	k, s = TRF_RcSeeOf("in", A("queue"), 100, T);
	k2, s2 = TRF_RcSeeOf("queue", A("queue", {qgo=1}), 100, T);
	k3, s3 = TRF_RcSeeOf("go", A("queue", {qgo=1}), 100, T);
	k4, s4 = TRF_RcSeeOf("go", A("dock"), 100, T);
	local k5, s5 = TRF_RcSeeOf("dock", A("dock", {dkd=1}), 100, T);
	HOST_Check(k == "hold" and s == "queue" and k2 == "go" and s2 == "go" and k3 == nil and s3 == "go" and k4 == nil and s4 == "dock"
		and k5 == "bay", "queue: hold, released (qgo) go, no second go while it flies back, no req after go, then bay");
	k, s = TRF_RcSeeOf("queue", A("dock"), 100, T);
	k2, s2 = TRF_RcSeeOf("queue", A("in"), 100, T);
	HOST_Check(k == "go" and s == "go" and k2 == "go", "how 3 in one step (queue -> in -> dock): the collapse to go, no req");
	k, s = TRF_RcSeeOf(nil, {path="B", from=0, st="out", born=100}, 100, T);
	k2, s2 = TRF_RcSeeOf(nil, {path="B", from=0, st="out", born=70}, 100, T);
	k3 = TRF_RcSeeOf(nil, {path="B", from=0, st="out", born=80}, 100, T);
	k4 = TRF_RcSeeOf(nil, {path="B", from=3, st="out", born=100}, 100, T);
	k5 = TRF_RcSeeOf("out", {path="B", from=0, st="out", born=100}, 100, T);
	HOST_Check(k == "out" and s == "out" and k2 == nil and s2 == "out" and k3 == "out" and k4 == nil and k5 == nil,
		"path B from the station: out when born within rc_stale (20 s: 0 and 20 s yes, 30 s no), not from a portal, once");
	k, s = TRF_RcSeeOf(nil, A("dock"), 100, T);
	k2, s2 = TRF_RcSeeOf(nil, A("dock", {dkd=1}), 100, T);
	k3, s3 = TRF_RcSeeOf(nil, A("queue", {qgo=1}), 100, T);
	HOST_Check(k == nil and s == "dock" and k2 == nil and s2 == "bay" and k3 == nil and s3 == "go", "met mid-way: no event, the state taken (dock, bay, go)");
	HOST_Check(TRF_RcPlainOf(A("in")) and TRF_RcPlainOf({path="B", st="out"}) and not TRF_RcPlainOf(A("in", {sev=1}))
		and not TRF_RcPlainOf(A("in", {fw=1})) and not TRF_RcPlainOf(A("in", {wq=2})) and not TRF_RcPlainOf(A("in", {own=3}))
		and not TRF_RcPlainOf(A("in", {fl=1})) and TRF_RcPlainOf(A("in", {fl=0})) and not TRF_RcPlainOf({path="C", st="out"})
		and not TRF_RcPlainOf(A("gone")), "plain traders only: sev, fw, wq, own, fl, path C and gone records left out");
	-- The poll: every docking step once; the mothership far, so nothing is said and the events stay.
	RC_Ms(nil);
	local n0 = S_Mark();
	RC_Tr(1); RC_Tr(2); RC_Tr(3);
	RC_Step(1);
	TRF.live.tr[1].st = "dock";
	TRF.live.tr[2].st = "queue";
	TRF.live.tr[3].st = "queue";
	RC_Step(1);
	TRF.live.tr[1].dkd = 1;
	TRF.live.tr[2].qgo = 1;
	TRF.live.tr[3].st = "dock";
	RC_Step(1);
	TRF.live.tr[2].st = "dock";
	RC_Step(1);
	TRF.live.tr[2].dkd = 1;
	TRF.live.tr[3].dkd = 1;
	RC_Step(2);
	HOST_Check(RC_Logs(n0, "event=event kind=req trader_id=1 ") == 1 and RC_Logs(n0, "event=event kind=bay trader_id=1 ") == 1
		and RC_Logs(n0, "event=event kind=hold trader_id=2 ") == 1 and RC_Logs(n0, "event=event kind=go trader_id=2 ") == 1
		and RC_Logs(n0, "event=event kind=bay trader_id=2 ") == 1 and RC_Logs(n0, "event=event kind=hold trader_id=3 ") == 1
		and RC_Logs(n0, "event=event kind=go trader_id=3 ") == 1 and RC_Logs(n0, "event=event kind=bay trader_id=3 ") == 1
		and RC_Logs(n0, "event=event kind=req") == 1 and RC_Logs(n0, "event=event") == 8 and RC_Logs(n0, "station_key="..RC_Key(1).." result=queued") == 8,
		"poll: req and bay; hold, go (qgo), bay; hold, go (how 3), bay; no req after a release; each once with the station key");
	HOST_Check(getn(TRF_RcCV().ev) == 4 and RC_Logs(n0, "event=drop") >= 4 and RC_Logs(n0, "reason=full") == 4, "at most 4 pending events, a fifth drops the oldest (reason=full)");
	-- Path B now and 30 s ago; excluded records; dock_mode 0 (no dkd): req only.
	RC_Fresh();
	RC_Ms(nil);
	n0 = S_Mark();
	RC_Tr(5, {path="B", from=0, st="out"});
	RC_Tr(6, {path="B", from=0, st="out", born=TRF.clock.gt - 30});
	RC_Tr(7, {sev=1}); RC_Tr(8, {fw=1}); RC_Tr(9, {wq=1}); RC_Tr(10, {own=2}); RC_Tr(11, {fl=1});
	RC_Tr(12);
	RC_Step(1);
	for i = 7, 12 do TRF.live.tr[i].st = "dock"; end;
	RC_Step(30);
	HOST_Check(RC_Logs(n0, "event=event kind=out trader_id=5 ") == 1 and RC_Logs(n0, "trader_id=6 ") == 0 and RC_Logs(n0, "event=event kind=req trader_id=12 ") == 1
		and RC_Logs(n0, "event=event") == 2, "path B born now: out; born 30 s ago: nothing; sev, fw, wq, own, fl: nothing; dock_mode 0: req, never bay");
	HOST_Check(RC_Logs(n0, "event=drop kind=out trader_id=5 reason=stale") == 1 and getn(TRF_RcCV().ev) == 0, "events older than rc_stale dropped (reason=stale)");
	-- Records of the visit at a load: seen without events; a gone record's event is dropped, a bay event kept.
	RC_Fresh();
	RC_Ms(nil);
	RC_Tr(13, {path="B", from=0, st="out"});
	RC_Tr(14, {st="dock"});
	TRF_Rc_OnLoad();
	n0 = S_Mark();
	RC_Step(2);
	HOST_Check(RC_Logs(n0, "event=event") == 0 and TRF_RcCV().s[13] == "out" and TRF_RcCV().s[14] == "dock",
		"a load: the records that exist are seen without events");
	TRF.live.tr[14].dkd = 1;
	RC_Tr(15);
	RC_Step(1);
	TRF.live.tr[15].st = "dock";
	RC_Step(1);
	TRF.live.tr[14].st = "gone";
	TRF.live.tr[15].st = "gone";
	RC_Step(1);
	HOST_Check(RC_Logs(n0, "event=drop kind=req trader_id=15 reason=gone") == 1 and getn(TRF_RcCV().ev) == 1 and TRF_RcCV().ev[1].kind == "bay",
		"a gone record's event dropped (reason=gone), the bay event of a docked (removed) ship kept");
end;

-- c: rate and repetition (5 Q6, 4.2, 4.4) --------------------------------------------------------

function T_RC_C()
	local h = HOST();
	RC_Begin("gredos");
	local T = TRF_RcTune();
	-- Pure: the pick, the key rotation, the rate.
	local ev = {{kind="bay", id=1, t=5}, {kind="req", id=2, t=3}, {kind="go", id=3, t=9}, {kind="go", id=4, t=8}, {kind="hold", id=5, t=1}};
	HOST_Check(TRF_RcPickOf(ev, {}, T) == 4 and TRF_RcPickOf(ev, {[4]=2}, T) == 3 and TRF_RcPickOf(ev, {[3]=2, [4]=2}, T) == 5
		and TRF_RcPickOf({}, {}, T) == nil and TRF_RcPickOf({{kind="req", id=1, t=1}}, {[1]=2}, T) == nil,
		"pick: lowest priority number (go 1, hold 2, req 3, out 4, bay 5), then the oldest; a trader at rc_per passed over");
	HOST_Check(TRF_RcKeyOf({"a", "b", "c"}, {}, 0) == "a" and TRF_RcKeyOf({"a", "b", "c"}, {}, 4) == "b" and TRF_RcKeyOf({"a", "b", "c"}, {a=1}, 1) == "c"
		and TRF_RcKeyOf({"a", "b"}, {a=1, b=1}, 3) == nil, "key: the unused keys rotated by the hash; none left nil");
	HOST_Check(TRF_RcHashOf(4, 1) == 34 and TRF_RcHashOf(3, 5) == 31 and TRF_RcBayOf(4, 1, 6) == 2 and TRF_RcBayOf(9, 2, 6) == 4,
		"hash mod(31 id + 7 kind, 97), bay 1 + mod(7 id + 3 j, rc_bays)");
	HOST_Check(TRF_RcRateOf(nil, 10, 0, 0, T) == nil and TRF_RcRateOf(100, 144, 0, 0, T) == "gap" and TRF_RcRateOf(100, 145, 0, 0, T) == nil
		and TRF_RcRateOf(nil, 10, 6, 0, T) == "cap" and TRF_RcRateOf(nil, 10, 5, 2, T) == "per_trader", "rate: rc_gap 45 real s, rc_max 6, rc_per 2");
	-- Five traders dock in one visit at 1x: calls 45 real seconds apart, at most 6 exchanges, 2 per trader.
	local n0, m0 = S_Mark(), getn(h.msgs);
	for id = 1, 5 do RC_Tr(id); end;
	RC_Step(1);
	TRF.live.tr[1].st = "dock";
	RC_Step(1);
	TRF.live.tr[2].st = "dock";
	RC_Step(50);
	TRF.live.tr[3].st = "dock";
	RC_Step(50);
	local calls = RC_All(n0, "part=call");
	local ok, last = 1, nil;
	for i = 1, getn(calls) do
		local rt = tonumber(RC_Kv(calls[i], "real_time"));
		if last and rt - last < 45 then ok = nil; end;
		last = rt;
	end;
	HOST_Check(getn(calls) == 2 and ok and RC_Logs(n0, "event=drop kind=req trader_id=2 reason=stale") == 1,
		"1x: trader 1 at once, trader 2 waits the gap and goes stale at rc_stale, trader 3 45 s after the first call ("..getn(calls).." calls)");
	-- The visit cap and the per-trader cap (rc_gap 10 for speed): holds, releases, requests, then bays.
	h.cfg.tune = {rc_gap=10, rc_stale=120};
	RC_Fresh();
	n0 = S_Mark();
	for id = 1, 8 do RC_Tr(id); end;
	RC_Step(1);
	for id = 1, 4 do TRF.live.tr[id].st = "queue"; end;
	RC_Step(25);
	for id = 1, 4 do TRF.live.tr[id].qgo = 1; end;
	RC_Step(25);
	for id = 5, 8 do TRF.live.tr[id].st = "dock"; end;
	RC_Step(25);
	for id = 5, 8 do TRF.live.tr[id].dkd = 1; end;
	RC_Step(25);
	local per, okp = {}, 1;
	calls = RC_Calls(n0);
	for i = 1, getn(calls) do
		local id = RC_Kv(calls[i], "trader_id");
		per[id] = (per[id] or 0) + 1;
		if per[id] > 2 then okp = nil; end;
	end;
	HOST_Check(getn(calls) == 6 and TRF_RcCV().ex == 6 and okp and RC_Logs(n0, "event=skip system=gredos reason=cap") == 1
		and RC_Logs(n0, "reason=used") >= 4, "rc_max: 6 exchanges in the visit (2 hold, 2 go, 2 req keys), at most rc_per 2 per trader, then skip reason=cap ("..getn(calls).." calls)");
	-- No key twice; the used drop after the variants of a kind.
	local seen, dup = {}, "";
	local said = RC_All(n0, "result=shown");
	for i = 1, getn(said) do
		local key = RC_Kv(said[i], "key");
		if seen[key] then dup = dup.." "..key; end;
		seen[key] = 1;
	end;
	HOST_Check(dup == "", "no line key twice in the visit"..dup);
	-- rc_per: one trader's third event is passed over (skip reason=per_trader).
	h.cfg.tune = {rc_gap=10, rc_stale=120, rc_max=30};
	RC_Fresh();
	local n1 = S_Mark();
	RC_Tr(1);
	RC_Step(1);
	TRF.live.tr[1].st = "queue";
	RC_Step(15);
	TRF.live.tr[1].qgo = 1;
	RC_Step(15);
	TRF.live.tr[1].dkd = 1;
	RC_Step(15);
	HOST_Check(getn(RC_Calls(n1)) == 2 and RC_Logs(n1, "reason=per_trader") == 1 and getn(TRF_RcCV().ev) == 1,
		"rc_per 2: the trader's bay event passed over (skip reason=per_trader), it waits until stale");
	-- Priority: hold, req, out and bay waiting, a go added after the first call: said hold, go, req, out, bay.
	h.cfg.tune = {rc_gap=10, rc_stale=120, rc_max=30, rc_per=5};
	RC_Fresh();
	n0 = S_Mark();
	local rs = {RC_Tr(1, {st="queue"}), RC_Tr(2, {st="dock"}), RC_Tr(3, {path="B", from=0, st="out", born=TRF.clock.gt - 500}),
		RC_Tr(4, {st="dock", dkd=1}), RC_Tr(5, {st="queue", qgo=1})};
	local gt = TRF.clock.gt;
	TRF_RcCV().ev = {{kind="bay", id=4, t=gt, j=1, r=rs[4]}, {kind="out", id=3, t=gt, j=1, r=rs[3]}, {kind="req", id=2, t=gt, j=1, r=rs[2]},
		{kind="hold", id=1, t=gt, j=1, r=rs[1]}};
	RC_Step(3);
	tinsert(TRF_RcCV().ev, {kind="go", id=5, t=TRF.clock.gt, j=1, r=rs[5]});
	RC_Step(80);
	calls = RC_Calls(n0);
	local order = "";
	for i = 1, getn(calls) do order = order..RC_Kv(calls[i], "kind")..","; end;
	HOST_Check(order == "hold,go,req,out,bay,", "priority order go, hold, req, out, bay: "..order);
	-- The used drop: three bay events, two variants.
	RC_Fresh();
	n0 = S_Mark();
	for id = 1, 3 do RC_Tr(id, {st="dock"}); end;
	RC_Step(1);
	for id = 1, 3 do TRF.live.tr[id].dkd = 1; end;
	RC_Step(40);
	HOST_Check(RC_Logs(n0, "event=say kind=bay part=call") == 2 and RC_Logs(n0, "event=drop kind=bay trader_id=3 reason=used") + RC_Logs(n0, "event=drop kind=bay trader_id=2 reason=used") + RC_Logs(n0, "event=drop kind=bay trader_id=1 reason=used") == 1,
		"bay: rchin1 and rchin2 once each, the third bay event dropped (reason=used)");
	-- 8x: game time runs 8 x real time; the calls stay 45 real seconds apart.
	h.cfg.tune = {};
	RC_Fresh();
	n0 = S_Mark();
	for id = 1, 3 do RC_Tr(id); end;
	RC_Step(1, 0.125);
	TRF.live.tr[1].st = "dock";
	RC_Step(10, 0.125);
	TRF.live.tr[2].st = "dock";
	RC_Step(19, 0.125);
	TRF.live.tr[3].st = "queue";
	RC_Step(361, 0.125);
	calls = RC_Calls(n0);
	ok, last = 1, nil;
	for i = 1, getn(calls) do
		local rt = tonumber(RC_Kv(calls[i], "real_time"));
		if last and rt - last < 45 then ok = nil; end;
		last = rt;
	end;
	HOST_Check(getn(calls) == 1 and ok and RC_Logs(n0, "event=drop kind=req trader_id=2 reason=stale") == 1 and RC_Logs(n0, "event=drop kind=hold trader_id=3 reason=stale") == 1,
		"8x: one call; the next events wait in real seconds and go stale in game seconds ("..getn(calls).." calls)");
end;

-- d: gates (5 R1-R8) ------------------------------------------------------------------------

-- One waiting request event of a new trader id, then n steps; returns the log mark and the message count before.
function RC_Gated(id, n)
	local h = HOST();
	TRF_RcCV().pr = {};
	local n0, m0 = S_Mark(), getn(h.msgs);
	RC_Req(id);
	RC_Step(n or 3);
	return n0, m0;
end;

function T_RC_D()
	local h = HOST();
	RC_Begin("gredos");
	-- R1
	h.cfg.chatter = 0;
	local n0, m0 = RC_Gated(1);
	HOST_Check(RC_Logs(n0, "event=skip system=gredos reason=off") == 1 and getn(h.msgs) == m0, "R1: chatter 0 -> reason=off, no line");
	h.cfg.chatter = 1;
	-- R2: no map entry; a system without a trade station.
	RC_Fresh();
	TRF_RcCV().pr = {};
	n0, m0 = S_Mark(), getn(h.msgs);
	RC_Tr(2);
	local ci = TRF_CurIdx;
	TRF_CurIdx = function() return nil; end;
	RC_Step(3);
	TRF_CurIdx = ci;
	HOST_Check(RC_Logs(n0, "reason=nomap") == 1 and getn(h.msgs) == m0, "R2: no map index -> reason=nomap");
	local m, none = TRF_Map(), nil;
	for i = 1, getn(m.sys) do
		local s = m.sys[i];
		if not none and type(s) == "table" and getn(TRF_RcTlOf(m, i)) == 0 and type(s.portals) == "table" and getn(s.portals) > 0 and s.name ~= "gredos" then none = s.name; end;
	end;
	T_Jump(none);
	n0 = S_Mark();
	RC_Step(2);
	HOST_Check(RC_Logs(n0, "event=skip system="..none.." reason=none") == 1, "R2: "..tostring(none).." has no trade station -> reason=none");
	T_Jump("gredos");
	RC_Fresh();
	-- R3: the system mode.
	local smq = TRF_SysModeQuiet;
	TRF_SysModeQuiet = function() return "vanilla", "sys_off"; end;
	n0, m0 = RC_Gated(3);
	HOST_Check(RC_Logs(n0, "reason=mode:sys_off") == 1 and getn(h.msgs) == m0, "R3: sys_off -> reason=mode:sys_off, no line");
	TRF_SysModeQuiet = function() return "vanilla", "guard"; end;
	n0, m0 = RC_Gated(4);
	TRF_SysModeQuiet = smq;
	HOST_Check(RC_Logs(n0, "reason=mode:guard") == 1 and getn(h.msgs) == m0, "R3: a guard system -> reason=mode:guard");
	-- R4: the strict gate.
	RC_Fresh();
	local so = TRF_StrictOk;
	local seen = nil;
	TRF_StrictOk = function(idx, ft) if ft == "chatter" then HOST().rcft = ft; return nil, "deny_chatter"; end; return %so(idx, ft); end;
	n0, m0 = RC_Gated(5);
	TRF_StrictOk = so;
	HOST_Check(RC_Logs(n0, "reason=gate:deny_chatter") == 1 and getn(h.msgs) == m0 and h.rcft == "chatter", "R4: TRF_StrictOk(idx, \"chatter\") denied -> reason=gate:<why>");
	-- R5: voice 0, a voice-deny system, trf_station missing.
	RC_Fresh();
	h.cfg.voice = 0;
	n0, m0 = RC_Gated(6);
	h.cfg.voice = nil;
	HOST_Check(RC_Logs(n0, "reason=station:off") == 1 and getn(h.msgs) == m0, "R5: voice 0 -> reason=station:off");
	RC_Fresh();
	local vd = TRF_StnVDeny;
	TRF_StnVDeny = function() return {gredos=1}; end;
	n0, m0 = RC_Gated(7);
	TRF_StnVDeny = vd;
	HOST_Check(RC_Logs(n0, "reason=station:vdeny") == 1 and getn(h.msgs) == m0, "R5: a voice-deny system -> reason=station:vdeny");
	RC_Fresh();
	local cc = TRF_Stn_ChatCtx;
	TRF_Stn_ChatCtx = nil;
	n0, m0 = RC_Gated(8);
	TRF_Stn_ChatCtx = cc;
	HOST_Check(RC_Logs(n0, "reason=station_off") == 1 and getn(h.msgs) == m0, "R5: trf_station missing -> reason=station_off");
	-- R5 at an authored deny entry (elio): station:deny only while the strict gate denies "voice" with a mission
	-- reason (stubbed for voice alone: a staged mission stops at R4 or R6 first); outside a mission open.
	T_Jump("elio");
	RC_Fresh();
	TRF_StrictOk = function(idx, ft) if ft == "voice" then return nil, "mission_deny"; end; return %so(idx, ft); end;
	n0, m0 = RC_Gated(17);
	TRF_StrictOk = so;
	HOST_Check(RC_Logs(n0, "event=skip system=elio reason=station:deny") == 1 and getn(h.msgs) == m0,
		"R5: elio while the strict gate denies voice (mission_deny) -> reason=station:deny");
	T_Jump("elio");
	RC_Fresh();
	n0, m0 = RC_Gated(18);
	RC_Step(8);
	HOST_Check(RC_Logs(n0, "reason=station:") == 0 and RC_Logs(n0, "event=say kind=req part=call") == 1 and getn(h.msgs) > m0,
		"R5: elio outside a mission is open for chatter (the call shown)");
	T_Jump("gredos");
	-- R6: the latch at the entry and later in the visit.
	h.qs = TRUE;
	T_Jump("gredos");
	local q0 = TRF_RcCV().q;
	RC_Fresh();
	n0, m0 = RC_Gated(9);
	HOST_Check(q0 == 1 and TRF_RcCV().q == 1 and RC_Logs(n0, "reason=latch") == 1 and getn(h.msgs) == m0, "R6: a mission at the entry -> reason=latch");
	h.qs = FALSE;
	T_Jump("gredos");
	RC_Fresh();
	HOST_Check(TRF_RcCV().q == nil, "R6: no latch without a mission");
	h.qs = TRUE;
	n0, m0 = RC_Gated(10);
	h.qs = FALSE;
	RC_Step(3);
	HOST_Check(RC_Logs(n0, "reason=latch") == 1 and TRF_RcCV().q == 1 and getn(h.msgs) == m0, "R6: a mission started in the visit latches it for the rest of the visit");
	T_Jump("gredos");
	RC_Fresh();
	-- R7: the hold flags and the scene.
	__disableAction = TRUE;
	n0, m0 = RC_Gated(11);
	__disableAction = FALSE;
	HOST_Check(RC_Logs(n0, "reason=hold:disable_action") == 1 and getn(h.msgs) == m0, "R7: __disableAction -> reason=hold:disable_action");
	RC_Fresh();
	__sys_SOS = TRUE;
	n0, m0 = RC_Gated(12);
	__sys_SOS = FALSE;
	HOST_Check(RC_Logs(n0, "reason=hold:sys_sos") == 1 and getn(h.msgs) == m0, "R7: __sys_SOS -> reason=hold:sys_sos");
	RC_Fresh();
	local sp = TRF_Supp;
	TRF_Supp = function() return 2; end;
	n0, m0 = RC_Gated(13);
	TRF_Supp = sp;
	HOST_Check(RC_Logs(n0, "reason=hold:suppressed") == 1 and getn(h.msgs) == m0, "R7: TRF_Supp() ~= 0 -> reason=hold:suppressed");
	RC_Fresh();
	TRF_InMovie = HOST_InMovie;
	h.mov = 1;
	__disableAction = TRUE;
	n0, m0 = RC_Gated(14);
	h.mov = 0;
	__disableAction = FALSE;
	TRF_InMovie = nil;
	HOST_Check(RC_Logs(n0, "reason=hold:scene") == 1 and RC_Logs(n0, "reason=hold:disable_action") == 0 and getn(h.msgs) == m0,
		"R7: a scene first -> reason=hold:scene (before disable_action)");
	-- R8: combat.
	RC_Fresh();
	TRF_CombatMark("raid", "host");
	n0, m0 = RC_Gated(15);
	HOST_Check(RC_Logs(n0, "reason=combat") == 1 and getn(h.msgs) == m0, "R8: TRF_Combat -> reason=combat");
	-- Events still age under a gate: the request goes stale after rc_stale, nothing is said when the gate opens.
	RC_Step(20);
	HOST_Check(RC_Logs(n0, "event=drop kind=req trader_id=15 reason=stale") == 1 and getn(TRF_RcCV().ev) == 0, "a gated event ages and is dropped at rc_stale");
	TRF.live.cbt = nil;
	RC_Step(30);
	HOST_Check(getn(h.msgs) == m0, "after the gate opens nothing stale is said");
	-- The skip line once per reason and visit.
	n0 = S_Mark();
	RC_Fresh();
	h.cfg.chatter = 0;
	RC_Step(5);
	h.cfg.chatter = 1;
	HOST_Check(RC_Logs(n0, "reason=off") == 1, "a skip reason logged once per visit");
	-- A due answer meets a gate: dropped.
	RC_Fresh();
	n0 = S_Mark();
	RC_Req(16);
	__sys_SOS = TRUE;
	RC_Step(8);
	__sys_SOS = FALSE;
	RC_Step(8);
	HOST_Check(RC_Logs(n0, "part=call") == 1 and RC_Logs(n0, "part=answer") == 1 and RC_Logs(n0, "part=answer trader_id=16 station_key="..RC_Key(1).." speaker=nil key=nil callsign=\"FTU 62\" distance=nil") == 1
		and RC_Logs(n0, "result=dropped reason=hold:sys_sos") == 1 and TRF_RcCV().pend == nil, "a due answer under a hold is dropped, never delayed (the call sign logged)");
end;

-- e: content first (5 Q1-Q5) ------------------------------------------------------------------

function T_RC_E()
	local h = HOST();
	RC_Begin("gredos");
	local T = TRF_RcTune();
	local w, a = TRF_RcQuietOf(100, 97, nil, nil, T);
	local w2, a2 = TRF_RcQuietOf(100, nil, 95, nil, T);
	local w3, a3 = TRF_RcQuietOf(100, 80, nil, 108, T);
	local w4, a4 = TRF_RcQuietOf(100, 85, 89, 90, T);
	local w5, a5 = TRF_RcQuietOf(100, nil, nil, nil, T);
	HOST_Check(w == "quiet_line" and a == 3 and w2 == "quiet_line" and a2 == 5 and w3 == "quiet_arrival" and a3 == -8 and w4 == nil and a4 == 10
		and w5 == nil and a5 == nil, "Q1, Q2: the content line, the station radio, the last arrival line plus rc_quiet; the smaller age");
	-- Q1: TRF.live.line 3 s ago, the call waits; said once 10 s have passed.
	local n0, m0 = S_Mark(), getn(h.msgs);
	RC_Tr(1);
	RC_Step(1);
	TRF.live.tr[1].st = "dock";
	TRF.live.line = TRF.clock.gt - 2;
	RC_Step(1);
	HOST_Check(RC_Logs(n0, "reason=quiet_line") == 1 and getn(h.msgs) == m0 and getn(TRF_RcCV().ev) == 1, "Q1: a content line 3 s ago -> reason=quiet_line, the call waits");
	RC_Step(7);
	HOST_Check(getn(h.msgs) == m0 + 1 and tonumber(RC_Kv(RC_Line(n0, "part=call"), "quiet_age")) == 10, "the call after rc_quiet, quiet_age=10");
	-- SV.rt 5 s ago.
	RC_Fresh();
	TRF_RcCV().pr = {};
	n0, m0 = S_Mark(), getn(h.msgs);
	TRF_StnSV().rt = TRF.clock.gt - 3;
	RC_Req(2);
	HOST_Check(RC_Logs(n0, "reason=quiet_line") == 1 and getn(h.msgs) == m0, "Q1: trf_station's radio line 5 s ago -> reason=quiet_line");
	-- Q2: an arrival line due in 8 s.
	RC_Fresh();
	n0, m0 = S_Mark(), getn(h.msgs);
	TRF.live.aqt = TRF.clock.gt + 6;
	RC_Req(3);
	RC_Step(10);
	HOST_Check(RC_Logs(n0, "reason=quiet_arrival") == 1 and getn(h.msgs) == m0, "Q2: an arrival line queued due in 8 s -> reason=quiet_arrival (until due + rc_quiet)");
	RC_Step(8);
	HOST_Check(getn(h.msgs) >= m0 + 1, "Q2: the call after the arrival line's due time plus rc_quiet");
	-- Q3: the approach radio pending.
	RC_Fresh();
	n0, m0 = S_Mark(), getn(h.msgs);
	TRF_StnSV().nr[RC_Key(1)] = 1;
	RC_Req(4);
	HOST_Check(RC_Logs(n0, "reason=approach") == 1 and getn(h.msgs) == m0, "Q3: the station's approach radio pending (near 1) -> reason=approach");
	-- Q4, Q5: the player docking, far, no position.
	RC_Fresh();
	n0, m0 = S_Mark(), getn(h.msgs);
	RC_Ms(200);
	RC_Req(5);
	HOST_Check(RC_Logs(n0, "reason=player_dock") == 1 and getn(h.msgs) == m0, "Q4: the mothership 200 from the station -> reason=player_dock");
	RC_Fresh();
	n0, m0 = S_Mark(), getn(h.msgs);
	RC_Ms(1600);
	RC_Req(6);
	HOST_Check(RC_Logs(n0, "reason=far") == 1 and getn(h.msgs) == m0, "Q5: the mothership 1600 from the station -> reason=far");
	RC_Fresh();
	n0, m0 = S_Mark(), getn(h.msgs);
	local pp = TRF_PlPos;
	TRF_PlPos = function(o) return nil; end;
	RC_Req(7);
	TRF_PlPos = pp;
	HOST_Check(RC_Logs(n0, "reason=pos") == 1 and getn(h.msgs) == m0, "Q5: no mothership position -> reason=pos");
	-- A content line between the call and the answer: the answer dropped with quiet_line.
	RC_Fresh();
	n0, m0 = S_Mark(), getn(h.msgs);
	RC_Req(8);
	HOST_Check(getn(h.msgs) == m0 + 1, "the call shown");
	TRF.live.line = TRF.clock.gt + 2;
	RC_Step(8);
	HOST_Check(RC_Logs(n0, "part=answer") == 1 and RC_Logs(n0, "part=answer trader_id=8") == 1 and RC_Logs(n0, "result=dropped reason=quiet_line") == 1
		and getn(h.msgs) == m0 + 1 and TRF_RcCV().pend == nil, "a content line between call and answer: the answer dropped (reason=quiet_line), never delayed");
	-- The answer of a request whose trader left (gone) is dropped; an undock answer is said after the record went.
	RC_Fresh();
	n0, m0 = S_Mark(), getn(h.msgs);
	RC_Req(9);
	TRF.live.tr[9].st = "gone";
	RC_Step(8);
	HOST_Check(RC_Logs(n0, "result=dropped reason=gone") == 1 and getn(h.msgs) == m0 + 1, "the answer to a gone trader dropped (reason=gone)");
	RC_Fresh();
	n0, m0 = S_Mark(), getn(h.msgs);
	RC_Tr(10, {path="B", from=0, st="out"});
	RC_Step(1);
	TRF.live.tr[10].st = "gone";
	RC_Step(8);
	HOST_Check(RC_Logs(n0, "event=say kind=out part=answer") == 1 and RC_Logs(n0, "event=say kind=out part=answer trader_id=10 station_key="..RC_Key(1)) == 1
		and getn(h.msgs) == m0 + 2, "an undock answer still said after the record went");
	-- The module never writes the content stamps.
	HOST_Check(TRF.live.line == nil and TRF_StnSV().rt == nil, "TRF.live.line and SV.rt never written by the module");
end;

-- f: speakers and texts (4.2, 4.3, 7) -------------------------------------------------------------

function T_RC_F()
	local h = HOST();
	RC_Begin("gredos", "6", {corp=1, tune={rc_gap=10}});
	local idx = TRF_CurIdx();
	local want = {Neutral="DialogSystem", Vks="DispetcherVKS", Kfni="DispetcherKFNI", Uss="USSDispetcher", Triada="TriadaDispetcher",
		Inoco="InocoDispetcher", Rebel="DispetcherRebel"};
	local bad = "";
	for own, tpl in want do
		h.teams.gredos = own;
		if TRF_Stn_ChatCtx(idx, 1).spk ~= tpl then bad = bad.." "..own; end;
	end;
	HOST_Check(bad == "", "dispatcher template per owner (SV 8.7)"..bad);
	-- A hold line from the Inoco dispatcher, the answer from the trader's lead pilot.
	h.teams.gredos = "Inoco";
	local n0, m0 = S_Mark(), getn(h.msgs);
	RC_Tr(1);
	RC_Step(1);
	TRF.live.tr[1].st = "queue";
	RC_Step(8);
	local s = RC_Msgs(m0);
	HOST_Check(getn(h.msgs) == m0 + 2 and strfind(s, "^InocoDispetcher:") and RC_Has(s, "|lead1:")
		and RC_Logs(n0, "part=call trader_id=1 station_key="..RC_Key(1).." speaker=InocoDispetcher") == 1 and RC_Logs(n0, "part=answer trader_id=1 station_key="..RC_Key(1).." speaker=leader") == 1,
		"hold: the call by the dispatcher, the answer by the trader's lead pilot: "..s);
	-- No leader: the Trader template.
	RC_Fresh();
	m0 = getn(h.msgs);
	RC_Req(2, {nolead=1});
	HOST_Check(strfind(RC_Msgs(m0), "^Trader:"), "no lead pilot: CreatePilot(\"Trader\"): "..RC_Msgs(m0));
	-- A corporation carrier: rchreqc first.
	RC_Fresh();
	n0, m0 = S_Mark(), getn(h.msgs);
	RC_Req(3, {crp=5});
	HOST_Check(RC_Logs(n0, "key=rchreqc ") == 1 and RC_Has(RC_Msgs(m0), "Gredos Control, InoCo 367 heavy, inbound, full load of "..TRF_Txt("cls1")..", request docking.|"),
		"a corporation carrier: rchreqc first, the corporation's call sign: "..RC_Msgs(m0));
	RC_Req(4, {crp=5});
	RC_Step(50);
	HOST_Check(RC_Logs(n0, "key=rchreqc ") == 1 and RC_Logs(n0, "part=call") == 2, "rchreqc once per visit, the next carrier takes another variant");
	-- Destinations: rchout1 only with r.to > 0.
	RC_Fresh();
	n0 = S_Mark();
	RC_Tr(5, {path="B", from=0, st="out", to=0});
	RC_Step(10);
	HOST_Check(RC_Logs(n0, "kind=out part=call") == 1 and RC_Logs(n0, "key=rchout2 ") == 1, "no destination: rchout2");
	RC_Fresh();
	n0, m0 = S_Mark(), getn(h.msgs);
	RC_Tr(4, {path="B", from=0, st="out", to=V_Idx("aurora")});
	RC_Step(10);
	HOST_Check(RC_Logs(n0, "kind=out part=call") == 1 and RC_Logs(n0, "key=rchout1 ") == 1 and RC_Has(RC_Msgs(m0), "Gredos Control, FTU 68, clear of bay 2, request departure to "..TRF_SysEn(V_Idx("aurora"))..".|")
		and RC_Has(RC_Msgs(m0), "Over and out.|"),
		"a destination (r.to > 0): rchout1 by the hash of trader 4, control signs off with Over and out.: "..RC_Msgs(m0));
	-- Bays stable per trader; the control name with the system.
	HOST_Check(TRF_RcCV().b[4] == TRF_RcBayOf(4, 1, 6) and TRF_RcCV().b[4] == 2 and RC_Has(RC_Msgs(m0), "Gredos Control, "), "bay of trader 4 fixed for the visit, control named by TRF_SysEn");
	-- Kadenoa: station 2 (Triada) as rchctl2 with the owner word, station 1 as rchctl.
	h.teams.kadenoa = "Uss"; h.teams.kadenoa_tri = "Triada";
	T_Jump("kadenoa");
	RC_Fresh();
	local S = TRF_RcTlOf(TRF_Map(), TRF_CurIdx());
	HOST_Check(getn(S) == 2 and S[2].prm == "kadenoa_tri" and S[2].side == "Triada", "Kadenoa: two trade stations, the second the Triada one");
	n0, m0 = S_Mark(), getn(h.msgs);
	RC_Ms(600, 2);
	RC_Tr(8, {j=2});
	RC_Step(1);
	TRF.live.tr[8].st = "queue";
	RC_Step(8);
	s = RC_Msgs(m0);
	HOST_Check(RC_Has(s, TRF_SysEn(TRF_CurIdx()).." Triada Control") and strfind(s, "^TriadaDispetcher:") and RC_Logs(n0, "station_key="..RC_Key(2)) >= 1
		and TRF_RcCV().b[8] == TRF_RcBayOf(8, 2, 6), "Kadenoa station 2: rchctl2 with the owner word, the Triada dispatcher, its station key and bay: "..s);
	RC_Fresh();
	m0 = getn(h.msgs);
	RC_Ms(600, 1);
	RC_Tr(6, {j=1});
	RC_Step(1);
	TRF.live.tr[6].st = "queue";
	RC_Step(2);
	s = RC_Msgs(m0);
	HOST_Check(RC_Has(s, TRF_SysEn(TRF_CurIdx()).." Control") and not RC_Has(s, "Triada") and strfind(s, "^USSDispetcher:"), "Kadenoa station 1: rchctl, the USS dispatcher: "..s);
	-- A trader whose station is not a map entry within rc_pos: dropped (reason=station).
	RC_Fresh();
	n0 = S_Mark();
	RC_Tr(9);
	TRF_H().tr[9].st = HOST_Obj("FAR", 5000, 0, 5000);
	TRF_H().tr[9].st.alive = 1;
	RC_Step(1);
	TRF.live.tr[9].st = "dock";
	RC_Step(2);
	HOST_Check(RC_Logs(n0, "event=drop kind=req trader_id=9 reason=station") == 1, "no map station within rc_pos -> reason=station");
	-- No ship name: the call sign needs none (decision 11).
	RC_Fresh();
	n0, m0 = S_Mark(), getn(h.msgs);
	RC_Req(10, {j=1, nm=0});
	HOST_Check(RC_Logs(n0, "event=say kind=req part=call trader_id=10") == 1 and RC_Has(RC_Msgs(m0), " Control, FTU 20, "),
		"no ship name: the call FTU 20 still said: "..RC_Msgs(m0));
	-- Call signs (4.3, D10): independent FTU + 2 digits, carrier corporation + 3 digits + heavy; deterministic; no shared
	-- number among ids less than 90 (900) apart.
	local hv = TRF_Txt("rchhvy");
	HOST_Check(TRF_RcCallOf(14, TRF_Txt("owner")) == "FTU 78" and TRF_RcCallOf(23, TRF_UI_FacOf(3), 1, hv) == "Triada 947 heavy"
		and TRF_RcCallOf(5, TRF_UI_FacOf(4), 1, hv) == "USS 245 heavy" and TRF_RcCallOf(2, TRF_UI_FacOf(5), 1, hv) == "InoCo 878 heavy"
		and TRF_RcCallOf(14, "FTU") == TRF_RcCallOf(14, "FTU") and TRF_RcCallOf(9014, "FTU") == "FTU 78",
		"call signs: FTU 78 (id 14), Triada 947 heavy (23), USS 245 heavy (5), InoCo 878 heavy (2), the same on every call, 9014 as 14 (90 x 100 apart)");
	HOST_Check(TRF_RcCallOf(nil, "FTU") == nil and TRF_RcCallOf(3, nil) == nil and TRF_RcCallOf(3, "") == nil and TRF_RcCallOf(3, "FTU", 1, nil) == "FTU 367",
		"no call sign without an id or a designator; a carrier without the heavy word");
	local cbad = "";
	for b = 1, 9001, 250 do
		local seen2, seen3 = {}, {};
		for id = b, b + 899 do
			local n3 = tonumber(strsub(TRF_RcCallOf(id, "X", 1), 3));
			if n3 < 100 or n3 > 999 or seen3[n3] then cbad = cbad.." c"..id; end;
			seen3[n3] = 1;
			if id < b + 90 then
				local n2 = tonumber(strsub(TRF_RcCallOf(id, "X"), 3));
				if n2 < 10 or n2 > 99 or seen2[n2] then cbad = cbad.." i"..id; end;
				seen2[n2] = 1;
			end;
		end;
	end;
	HOST_Check(cbad == "", "no collision for ids less than 90 (independent, 2 digits) or 900 (carrier, 3 digits) apart"..cbad);
	-- corp 0: a record with crp is an independent (TRF_Crp_Of nil): FTU call sign, no rchreqc.
	h.cfg.corp = 0;
	RC_Fresh();
	n0, m0 = S_Mark(), getn(h.msgs);
	RC_Req(23, {crp=3});
	HOST_Check(RC_Logs(n0, "key=rchreqc ") == 0 and RC_Logs(n0, "part=call trader_id=23") == 1 and RC_Has(RC_Msgs(m0), ", FTU 51, ")
		and not RC_Has(RC_Msgs(m0), "heavy"), "corp 0: the independent form FTU 51, no rchreqc: "..RC_Msgs(m0));
	h.cfg.corp = 1;
	RC_Fresh();
	m0 = getn(h.msgs);
	RC_Req(23, {crp=3});
	HOST_Check(RC_Has(RC_Msgs(m0), " Control, Triada 947 heavy, inbound, full load of "), "corp 1: Triada 947 heavy: "..RC_Msgs(m0));
	-- The go readback (decision 12): hold, readback, release, readback by the trader's lead pilot.
	RC_Fresh();
	n0, m0 = S_Mark(), getn(h.msgs);
	RC_Tr(11);
	RC_Step(1);
	TRF.live.tr[11].st = "queue";
	RC_Step(8);
	TRF.live.tr[11].qgo = 1;
	RC_Step(20);
	local gl = RC_Line(n0, "kind=go part=answer");
	HOST_Check(RC_Logs(n0, "kind=hold part=answer trader_id=11 station_key="..RC_Key(1).." speaker=leader key=rchholda") == 1
		and RC_Logs(n0, "kind=go part=call trader_id=11") == 1 and RC_Logs(n0, "kind=go part=answer trader_id=11 station_key="..RC_Key(1).." speaker=leader key=rchgoa") == 1
		and RC_Has(RC_Msgs(m0), "|lead11:Wilco, holding, FTU 57.|") and (RC_Has(RC_Msgs(m0), "|lead11:Cleared to dock bay "..TRF_RcCV().b[11]..", FTU 57.|")
		or RC_Has(RC_Msgs(m0), "|lead11:Roger, on our way in, bay "..TRF_RcCV().b[11]..", FTU 57.|")) and TRF_RcCV().ex == 2,
		"go: the trader reads back the release (rchgoa1/2), as the hold: "..RC_Msgs(m0));
	-- Every text with the longest names: at most 120 characters, no %, #, line break.
	local lg = "";
	local m = TRF_Map();
	for i = 1, getn(m.sys) do local e = TRF_SysEn(i); if type(e) == "string" and strlen(e) > strlen(lg) then lg = e; end; end;
	local ln = TRF_RcCallOf(23, TRF_UI_FacOf(3), 1, hv);
	local wds = {c=TRF_Txt("rchctl2", "Cadenoa", "Triada"), s=ln, g=TRF_Txt("cls3"), b=12, d=lg, h=1};
	local long, mx = "", 0;
	for k, v in TRF_Rc_Text() do
		local t = TRF_Txt(k, TRF_RcArgsOf(k, wds));
		if strlen(t) > mx then mx = strlen(t); end;
		if strlen(t) > 120 or strfind(t, "%", 1, 1) or strfind(t, "#", 1, 1) or strfind(t, "\n", 1, 1) or strfind(t, "%$") then long = long.." "..k..":"..t; end;
	end;
	HOST_Check(long == "" and wds.c == "Cadenoa Triada Control", "every text <= 120 characters with the longest names ("..ln..", "..lg..", longest "..mx.."), no %, #, $n or line break"..long);
end;

-- g: the sound (6.5) ---------------------------------------------------------------------------

function T_RC_G()
	local h = HOST();
	RC_Begin("gredos");
	-- rc_sound 3 (default): the clip of each line key and the call sign's designator (FTU 47: _ftu), at the music volume
	-- (no DLL: 1) x rc_vol 80; the say line logs the call sign.
	local n0, m0 = S_Mark(), getn(h.msgs);
	RC_Req(1);
	RC_Step(8);
	local k1, k2 = RC_Kv(RC_Line(n0, "part=call"), "key"), RC_Kv(RC_Line(n0, "part=answer"), "key");
	HOST_Check(getn(h.psnd) == 2 and h.psnd[1].name == "trf_voice\\"..tostring(k1).."_ftu.wav" and h.psnd[2].name == "trf_voice\\"..tostring(k2).."_ftu.wav"
		and h.psnd[1].vol == 0.8 and h.psnd[2].vol == 0.8 and getn(h.msgs) == m0 + 2 and RC_Logs(n0, "sound_result=played volume=0.800 result=shown") == 2
		and RC_Logs(n0, "sound=trf_voice\\"..tostring(k1).."_ftu.wav ") == 1 and RC_Logs(n0, "key="..tostring(k1).." callsign=\"FTU 47\" ") == 1
		and RC_Logs(n0, "key="..tostring(k2).." callsign=\"FTU 47\" ") == 1 and RC_Has(RC_Msgs(m0), "FTU 47"),
		"rc_sound 3 (default): an FTU trader's lines play <key>_ftu.wav at 0.8 (no TRF_MusicVol: 1 x 80 %), logged with the call sign and the volume");
	-- A corporation carrier (Triada 947 heavy): rchreqc and the answer with the _triada clips.
	h.cfg.corp = 1;
	RC_Fresh();
	n0, m0 = S_Mark(), getn(h.msgs);
	RC_Req(23, {crp=3});
	RC_Step(8);
	k2 = RC_Kv(RC_Line(n0, "part=answer"), "key");
	HOST_Check(getn(h.psnd) == 2 and h.psnd[1].name == "trf_voice\\rchreqc_triada.wav" and h.psnd[2].name == "trf_voice\\"..tostring(k2).."_triada.wav"
		and RC_Logs(n0, "key=rchreqc callsign=\"Triada 947 heavy\" ") == 1 and RC_Logs(n0, "sound=trf_voice\\"..tostring(k2).."_triada.wav sound_result=played") == 1,
		"a Triada carrier: trf_voice\\rchreqc_triada.wav, then the answer's <key>_triada.wav, logged with callsign=\"Triada 947 heavy\"");
	-- An unknown designator (none expected: a stranger name from TRF_UI_FacOf) falls back to the generic clip <key>.wav.
	local fo = TRF_UI_FacOf;
	TRF_UI_FacOf = function(f) return "Kestrel"; end;
	RC_Fresh();
	n0 = S_Mark();
	RC_Req(23, {crp=3});
	TRF_UI_FacOf = fo;
	HOST_Check(getn(h.psnd) == 1 and h.psnd[1].name == "trf_voice\\rchreqc.wav" and RC_Logs(n0, "key=rchreqc callsign=\"Kestrel 947 heavy\" ") == 1,
		"an unknown designator (Kestrel 947 heavy): the generic trf_voice\\rchreqc.wav");
	h.cfg.corp = 0;
	-- Every clip in the repo: per voiced key the generic <key>.wav and <key>_<tag>.wav for each designator tag it has
	-- (rchreqc the three corporations only): 18 + 17 x 4 + 3 = 89 files.
	local K = TRF_RcK();
	local miss, nv, nf = "", 0, 0;
	for k, v in K.vo do
		nv = nv + 1;
		nf = nf + 1;
		if not RC_ReadFile(h.dir.."../../../SOUND/trf_voice/"..k..".wav") then miss = miss.." "..k; end;
		for t, q in K.ft do
			if q >= v then
				nf = nf + 1;
				if not RC_ReadFile(h.dir.."../../../SOUND/trf_voice/"..k.."_"..t..".wav") then miss = miss.." "..k.."_"..t; end;
			end;
		end;
	end;
	HOST_Check(nv == 18 and nf == 89 and miss == "", "18 voiced keys, 89 clips in Data/SOUND/trf_voice/ (<key>.wav and <key>_<tag>.wav, "..nf..")"..miss);
	HOST_Check(TRF_RcSndOf("rchgoa2", 3, "ftu") == "trf_voice\\rchgoa2_ftu.wav" and TRF_RcSndOf("rchgoa2", 3, "inoco") == "trf_voice\\rchgoa2_inoco.wav"
		and TRF_RcSndOf("rchreqc", 3, "uss") == "trf_voice\\rchreqc_uss.wav" and TRF_RcSndOf("rchreqc", 3, "ftu") == "trf_voice\\rchreqc.wav"
		and TRF_RcSndOf("rchgoa2", 3) == "trf_voice\\rchgoa2.wav" and TRF_RcSndOf("rchgoa2", 3, "kestrel") == "trf_voice\\rchgoa2.wav"
		and TRF_RcSndOf("rchctl", 3, "ftu") == "trf_squelch.wav" and TRF_RcSndOf("rchgoa2", 2, "ftu") == "trf_squelch.wav"
		and TRF_RcSndOf("rchgoa2", 1, "triada") == "GUI\\PM1.wav",
		"TRF_RcSndOf: mode 3 the key's clip of the designator tag, the generic clip for no or another tag (rchreqc has no _ftu), the squelch for a key without a clip; modes 1 and 2 as before");
	HOST_Check(TRF_RcFacTag(TRF_Txt("owner")) == "ftu" and TRF_RcFacTag(TRF_UI_FacOf(3)) == "triada" and TRF_RcFacTag(TRF_UI_FacOf(4)) == "uss"
		and TRF_RcFacTag(TRF_UI_FacOf(5)) == "inoco" and TRF_RcFacTag(TRF_UI_FacOf(1)) == nil and TRF_RcFacTag("Kestrel") == nil
		and TRF_RcFacTag(nil) == nil and TRF_RcFacTag("") == nil,
		"TRF_RcFacTag: FTU, Triada, USS, InoCo -> ftu, triada, uss, inoco; "..tostring(TRF_UI_FacOf(1))..", a stranger, nil and \"\" -> nil");
	RC_Fresh();
	-- The music volume (TRF_RcVol over the DLL native) and the clamp.
	TRF_MusicVol = HOST_MusicVol;
	h.mvol = 0.25; h.svol = 0.5;
	HOST_Check(TRF_RcVol() == 0.5 and h.mvol_n == 1, "TRF_RcVol: music / effects of TRF_MusicVol (0.25 / 0.5)");
	h.svol = 0.2;
	HOST_Check(TRF_RcVol() == 1, "TRF_RcVol: music above the effects volume -> 1 (the clamp)");
	h.svol = 0;
	HOST_Check(TRF_RcVol() == 0.25, "TRF_RcVol: effects 0 (muted by the engine) -> music alone");
	h.svol = 1.5;
	HOST_Check(TRF_RcVol() == 0.25, "TRF_RcVol: effects outside 0..1 -> music alone");
	h.svol = 1;
	h.mvol = nil; h.mvol_why = "sig";
	HOST_Check(TRF_RcVol() == 1, "TRF_RcVol: nil, why -> 1");
	h.mvol = 1.5;
	HOST_Check(TRF_RcVol() == 1, "TRF_RcVol: a value outside 0..1 -> 1");
	TRF_MusicVol = function() error("injected TRF_MusicVol error"); end;
	HOST_Check(TRF_RcVol() == 1, "TRF_RcVol: a raising native -> 1");
	TRF_MusicVol = nil;
	HOST_Check(TRF_RcVol() == 1, "TRF_RcVol: no native -> 1");
	HOST_Check(TRF_RcVolOf(0.5, 80) == 0.4 and TRF_RcVolOf(1, 100) == 1 and TRF_RcVolOf(2, 100) == 1 and TRF_RcVolOf(-1, 50) == 0
		and TRF_RcVolOf(0.3, 0) == 0 and TRF_RcVolOf(nil, 80) == 0.8, "TRF_RcVolOf: music x rc_vol / 100, clamped to 0..1, nil music reads as 1");
	TRF_MusicVol = HOST_MusicVol;
	h.mvol = 0.25; h.svol = 1;
	RC_Fresh();
	n0 = S_Mark();
	RC_Req(2);
	HOST_Check(getn(h.psnd) == 1 and h.psnd[1].vol == 0.2 and RC_Logs(n0, "volume=0.200 result=shown") == 1, "music 0.25 / effects 1 x rc_vol 80: PlaySound at 0.2");
	h.mvol = 0.1; h.svol = 0.2;
	RC_Fresh();
	n0 = S_Mark();
	RC_Req(2);
	HOST_Check(getn(h.psnd) == 1 and h.psnd[1].vol == 0.4 and RC_Logs(n0, "volume=0.400 result=shown") == 1, "music 0.1 / effects 0.2 x rc_vol 80: PlaySound at 0.4 (heard 0.08 = music x rc_vol)");
	h.cfg.tune = {rc_vol=100};
	h.mvol = 1;
	RC_Fresh();
	RC_Req(9);
	HOST_Check(getn(h.psnd) == 1 and h.psnd[1].vol == 1, "music 1 x rc_vol 100: PlaySound at 1 (the clamp's top)");
	TRF_MusicVol = nil;
	h.cfg.tune = {rc_sound=2, rc_vol=60};
	RC_Fresh();
	n0 = S_Mark();
	RC_Req(10);
	RC_Step(8);
	HOST_Check(getn(h.psnd) == 2 and h.psnd[1].name == "trf_squelch.wav" and h.psnd[1].vol == 0.6 and h.psnd[2].name == "trf_squelch.wav"
		and RC_Logs(n0, "sound=trf_squelch.wav sound_result=played volume=0.600 result=shown") == 2,
		"rc_sound 2, rc_vol 60: trf_squelch.wav at 0.6 before the call and the answer");
	h.cfg.tune = {rc_sound=1, rc_vol=100};
	RC_Fresh();
	n0 = S_Mark();
	RC_Req(11);
	HOST_Check(getn(h.psnd) == 1 and h.psnd[1].name == "GUI\\PM1.wav" and h.psnd[1].vol == 1 and RC_Logs(n0, "sound=GUI\\PM1.wav sound_result=played") == 1,
		"rc_sound 1, rc_vol 100: GUI\\PM1.wav at 1.0");
	h.cfg.tune = {rc_sound=2, rc_vol=0};
	RC_Fresh();
	RC_Req(3);
	HOST_Check(getn(h.psnd) == 1 and h.psnd[1].vol == 0, "rc_vol 0: the sound at volume 0");
	h.cfg.tune = {rc_sound=0};
	RC_Fresh();
	n0, m0 = S_Mark(), getn(h.msgs);
	RC_Req(4);
	HOST_Check(getn(h.psnd) == 0 and getn(h.msgs) == m0 + 1 and RC_Logs(n0, "sound=none sound_result=off volume=nil result=shown") == 1, "rc_sound 0: no sound, the line shown");
	h.cfg.tune = {};
	RC_Fresh();
	h.psnd_err = 1;
	n0, m0 = S_Mark(), getn(h.msgs);
	RC_Req(5);
	h.psnd_err = nil;
	HOST_Check(getn(h.msgs) == m0 + 1 and RC_Logs(n0, "sound_result=error volume=0.800 result=shown") == 1 and RC_Logs(n0, "event=error") == 0,
		"PlaySound raising: sound_result=error, the line still shown, no error line");
	RC_Fresh();
	PlaySound = nil;
	n0, m0 = S_Mark(), getn(h.msgs);
	RC_Req(6);
	PlaySound = HOST_PlaySound;
	HOST_Check(getn(h.msgs) == m0 + 1 and RC_Logs(n0, "sound_result=none volume=0.800 result=shown") == 1, "PlaySound missing: sound_result=none, the line shown");
	-- A raising Message: result=failed, the event removed, nothing counted.
	RC_Fresh();
	h.msg_err = 1;
	n0 = S_Mark();
	local ne = S_Expect(function() RC_Req(7); end);
	h.msg_err = nil;
	HOST_Check(ne == 1 and RC_Logs(n0, "part=call") == 1 and RC_Logs(n0, "result=failed reason=message") == 1 and TRF_RcCV().ex == 0
		and getn(TRF_RcCV().ev) == 0 and TRF_RcCV().pend == nil, "Message raising: result=failed, the event removed, no exchange counted");
	-- No speaker (no lead pilot, CreatePilot returns nil): no cue, result=failed.
	RC_Fresh();
	local cp = CreatePilot;
	CreatePilot = function(tpl) return nil; end;
	n0, m0 = S_Mark(), getn(h.msgs);
	RC_Req(8, {nolead=1});
	CreatePilot = cp;
	HOST_Check(getn(h.psnd) == 0 and getn(h.msgs) == m0 and RC_Logs(n0, "sound=none sound_result=off volume=nil result=failed reason=message") == 1
		and TRF_RcCV().ex == 0, "no speaker: no sound, result=failed, no exchange counted");
end;

-- h: jump, load, save size (3.1, 6.1) -----------------------------------------------------------

function T_RC_H()
	local h = HOST();
	RC_Begin("gredos");
	-- A pending answer at a jump: cleared.
	RC_Req(1);
	HOST_Check(type(TRF_RcCV().pend) == "table", "a pending answer");
	RC_Tr(2);
	RC_Step(1);
	TRF.live.tr[2].st = "queue";
	TRF_RcCV().ev = {{kind="hold", id=2, t=TRF.clock.gt, j=1, r=TRF.live.tr[2]}};
	TRF_Rc_BeforeJump("aurora");
	HOST_Check(TRF_RcCV().pend == nil and getn(TRF_RcCV().ev) == 0, "TRF_Rc_BeforeJump: the pending answer and the events cleared");
	local n0 = S_Mark();
	T_Jump("aurora");
	HOST_Check(TRF_RcCV().ex == 0 and RC_N(TRF_RcCV().k) == 0 and RC_Logs(n0, "event=enter system=aurora") == 1 and RC_Logs(n0, "via=enter") == 1,
		"the jump: a fresh visit, the enter line: "..RC_Line(n0, "event=enter"));
	T_Jump("gredos");
	RC_Fresh();
	-- A load inside the system: a fresh visit (the keys may be said again).
	RC_Req(3);
	RC_Step(8);
	HOST_Check(TRF_RcCV().ex == 1 and RC_N(TRF_RcCV().k) == 2, "one exchange said");
	n0 = S_Mark();
	T_SaveLoad();
	HOST_Check(TRF_RcCV().ex == 0 and RC_N(TRF_RcCV().k) == 0 and TRF_RcCV().pend == nil and RC_Logs(n0, "event=enter system=gredos") == 1
		and RC_Logs(n0, "via=load") == 1, "a load: a fresh visit, enter via=load");
	-- The save size: equal with and without the module after the same steps.
	RC_Fresh();
	local s0 = HOST_SaveSize(TRF);
	RC_Req(4);
	RC_Step(8);
	RC_Tr(5, {path="B", from=0, st="out"});
	RC_Step(60);
	local s1 = HOST_SaveSize(TRF);
	h.cfg.chatter = 0;
	RC_Fresh();
	local s2 = HOST_SaveSize(TRF);
	RC_Req(4);
	RC_Step(8);
	RC_Tr(5, {path="B", from=0, st="out"});
	RC_Step(60);
	local s3 = HOST_SaveSize(TRF);
	h.cfg.chatter = 1;
	HOST_Check(s1 - s0 == s3 - s2, "HOST_SaveSize(TRF) grows the same with and without the module ("..(s1 - s0).." / "..(s3 - s2)..")");
	-- The full state: 8 trader ids, 4 events, a pending answer, 18 keys in RC; TRF unchanged.
	RC_Fresh();
	RC_Ms(nil);
	local f0 = HOST_SaveSize(TRF);
	for id = 1, 8 do RC_Tr(id); end;
	local rc = TRF_RcCV();
	for k, v in TRF_Rc_Text() do rc.k[k] = 1; end;
	RC_Step(1);
	for id = 1, 8 do TRF.live.tr[id].st = "dock"; end;
	RC_Step(1);
	rc.pend = {kind="req", id=1, j=1, r=TRF.live.tr[1], w={}, at=TRF_RealSecs() + 100};
	local f1 = HOST_SaveSize(TRF);
	for id = 1, 8 do TRF.live.tr[id] = nil; end;
	local f2 = HOST_SaveSize(TRF);
	HOST_Check(getn(rc.ev) == 4 and RC_N(rc.s) == 8 and type(rc.pend) == "table" and f2 <= f0, "RC at its bounds, TRF without a chatter field ("..f0.." / "..f2.." bytes)");
	local full = 8 + 3 + HOST_SaveSize(TRF);
	HOST_Check(full < 100000, "TRF at the end: "..full.." bytes < 100000");
	n0 = S_Mark();
	TRF_Rc_Dump();
	HOST_Check(RC_Logs(n0, "event=dump on=1 exchange_count=0 pending=req event_count=4 keys=rchctl,rchctl2,rchgo1") == 1, "dump: "..RC_Line(n0, "event=dump"));
end;

-- Dispatch ---------------------------------------------------------------------------------

local sc = getenv("TRF_RC") or "";
local fn = getglobal("T_RC_"..strupper(sc));
print("HOST ==== chatter scenario rc-"..sc.." dir="..HOST().dir);
if type(fn) == "function" then
	fn();
	HOST_Check(T_LeftGlobals() == "", "no handle globals left at the end"..T_LeftGlobals());
else
	HOST_Check(nil, "unknown chatter scenario "..sc);
end;
HOST_Check((HOST().gpm_tick or 0) == 0, "no GetPlayerMotherShip from a tick (n="..tostring(HOST().gpm_tick or 0)..")");
print("HOST errors="..HOST().errors.." fails="..HOST().fails);
if HOST().errors > 0 or HOST().fails > 0 then exit(1); end;
exit(0);
