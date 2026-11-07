-- Crew requests scenarios (design/crew-requests-spec.md 13, B03) under stock Lua 4.0.1: TRF_RQ=a..h, run by run_host.sh as
-- its own entry point. a install (loader, lists, texts, cfg and tune defaults and clamps, the event table, the module body,
-- registrations, requests 0); b the pick (each finder with matching and failing fixtures, strict-denied and armed subject
-- systems, the c1 order, rq_gap, chapter 4, rq_dl_ch, a pending record kept and dropped, request_at); c the radio pair (queue
-- counts 0, 1 and 2, lines queued first, the event slot, a silent pilot, part 1 shown with the logbook on both lists, part 1
-- refused at the say, part 2 from the Hero, a responder or nobody, three misses -> the box state); d outcomes (the trf_track
-- hook, the death bus with and without the player's fire, an off-screen captain death, the pods aboard, the patrol dock line
-- with and without a tip, rewards at TRF_PayN 9,000, the outcome line under a scene, owed after a jump, dropped after
-- rq_owe_max); e lapses (deadline at dd and dd + 1, the chapter, an expired trader, a gone beacon, the pilot gone in chapter
-- 11, Lastochka2 in chapter 13, the lapse line at the next entry); f the dock box (a higher box wins, alone at trade and
-- patrol docks, OK, Cancel, a failed box, the gates, rq_box 0); g gates (R1-R12, the latch, a load); h save and repair
-- (TRF_Rq_Fix, the byte bounds, the full state).
-- Loads host_station.lua up to its first scenario, as host_remark.lua does. Stubs in this file: squad pilots in HOST().crew
-- (RQ_Crew: IsAlive, GetSide, IsCanSayReplica, Message recording the template, HasProperty).

local f = openfile((getenv("TRF_TESTS") or "./").."host_station.lua", "r");
if not f then print("HOST FAIL host_request.lua: cannot open host_station.lua"); exit(1); end;
local src = read(f, "*a");
closefile(f);
local cut = strfind(src, "\n-- a: install (12.1, 6.1)", 1, 1);
if not cut then print("HOST FAIL host_request.lua: marker '-- a: install (12.1, 6.1)' missing in host_station.lua"); exit(1); end;
dostring(strsub(src, 1, cut), "host_station.lua");

-- Helpers ----------------------------------------------------------------------------------

-- Config of these runs: the entry events and the modules that queue arrival lines or claim boxes off, tracked traders not
-- spawned (track 0: the pool is read only), captains off (the cap scenarios turn them on), log 2, plus t.
function RQ_Cfg(t)
	local c = {sweeps=0, sweep_ct=0, feq=0, staged=0, seed=0, queue=0, parked=0, voice_events=0, dconv=0, carriers=0, po=0,
		enable_survivors=0, enable_scars=0, enable_stashes=0, enable_freight=0, warn=0, signals=0, remarks=0, survey=0, track=0,
		cap_enable=0, cap_board=0, cap_intel=0, cap_chase=0, lad_enabled=0, charter=0, temper=0, corp=0, debrief=0, requests=1,
		log=2};
	if t then for k, v in t do c[k] = v; end; end;
	return c;
end;

-- Squad pilots for GetPilot: t = {<template> = {dead, side (default "Player"), csr (default 1), props}}.
function RQ_Crew(t)
	local h = HOST();
	h.crew = {};
	for tpl, e in t do
		local p = HOST_Pilot(tpl);
		p.alive = not e.dead; p.side = e.side or "Player"; p.csr = e.csr ~= 0; p.props = e.props or {};
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

-- The crew of chapters 6-10: the Hero, Ternie (Lastochka) and Greyhair (Sedoy).
function RQ_Crew0() RQ_Crew({Hero={}, Lastochka={}, Sedoy={}}); end;

-- The scene of an entry runs HOST().rqhook after the module files are loaded and before TRF_OnEnter.
RQ_Scene0 = T_Scene;
function T_Scene(sys)
	RQ_Scene0(sys);
	local h = HOST();
	if h.rqhook then h.rqhook(); end;
end;

-- Scenario start in sys at chapter label ch (default 6): no quest, no records; jl 1 installs the Job log.
function RQ_Begin(sys, ch, t, jl)
	local h = HOST();
	h.labels.CurrentQuest = ch or "6";
	h.quests = {}; h.qlog = {};
	h.qs = FALSE;
	h.jl = {}; h.jl_off = nil;
	HOST_JobLogOn(jl or 0);
	h.rqhook = nil;
	RQ_Crew0();
	S_Begin(sys, RQ_Cfg(t));
	h.credits = 100000;
	h.quests = {}; h.qlog = {}; h.jl = {};
	TRF.rq = nil; TRF.tp = {}; TRF.sv = nil; TRF.claim = nil;
	TRF_RqKeepThunk = nil;
	TRF.clock.legs = 100;
	TRF_RqVisit();
end;

function RQ_Has(s, t) return strfind(s or "", t, 1, 1) ~= nil; end;
function RQ_N(t) local n = 0; for k, v in t do n = n + 1; end; return n; end;

-- request log lines after mark n0 holding pat (plain).
function RQ_Logs(n0, pat)
	local n, q = 0, HOST().logs;
	for i = n0 + 1, getn(q) do if strfind(q[i], "module=request ", 1, 1) and strfind(q[i], pat, 1, 1) then n = n + 1; end; end;
	return n;
end;

-- Last request log line after n0 holding pat, or "".
function RQ_Line(n0, pat)
	local q, r = HOST().logs, "";
	for i = n0 + 1, getn(q) do if strfind(q[i], "module=request ", 1, 1) and strfind(q[i], pat, 1, 1) then r = q[i]; end; end;
	return r;
end;

-- Radio lines after m0: "tpl:text|...".
function RQ_Msgs(m0)
	local q, s = HOST().msgs, "";
	for i = (m0 or 0) + 1, getn(q) do s = s..tostring(q[i].tpl)..":"..q[i].t.."|"; end;
	return s;
end;

-- Screen lines after s0 joined by "|".
function RQ_Scr(s0)
	local q, s = HOST().screen, "";
	for i = (s0 or 0) + 1, getn(q) do s = s..q[i].t.."|"; end;
	return s;
end;

function RQ_ReadFile(p)
	local fh = openfile(p, "rb");
	if not fh then return nil; end;
	local s = read(fh, "*a");
	closefile(fh);
	return s;
end;

-- Region 5 (Red Knives) systems: gaoba (trade and patrol, Inoco), its neighbours lidau, heos and xk10.
function RQ_Sys() return V_Idx("gaoba"), V_Idx("lidau"), V_Idx("heos"), V_Idx("xk10"); end;

-- Entry into sys (fx runs right after the entry, before the due), then secs (default 30) game seconds of ticks.
function RQ_Go(sys, fx, secs)
	T_Jump(sys);
	if fx then fx(); end;
	T_Tick(floor((secs or 30) * 2 + 0.5), 0.5);
end;

-- A tracked trader record in system s: id, flags fl, elapsed legs el at the next entry (default 3), damage dm, place d.
function RQ_Trk(id, s, fl, el, dm, d, o)
	if type(TRF.tp) ~= "table" then TRF.tp = {}; end;
	local t = TRF.clock.legs - (el or 3) - 1;
	tinsert(TRF.tp, TRF_TpPack({id=id, nm=2, o=o or 0, c=1, tt=1, pw=3, n=2, e=0, s=s, fr=V_Idx("gaoba"), d=d or 0, dm=dm or 0, fl=fl or 1, t=t}));
end;

-- The captain record of region slot: gen 2, st, esc, met, gr (fields of t override).
function RQ_Cap(slot, t)
	if type(TRF.cap) ~= "table" then TRF.cap = {}; end;
	local home = TRF_RgMap()[slot].home;
	local r = {nm=3, gen=2, st=1, tp=3, esc=1, noto=0, gr=1, gr_t=0, seen=home, due=0, lj=0, dj=0, born=0, met=1, last=0};
	if t then for k, v in t do r[k] = v; end; end;
	TRF.cap[slot] = r;
	return r;
end;

-- A seeded beacon in system s (lg default the current leg, n pods).
function RQ_Bcn(s, lg, n, t)
	if type(TRF.sv) ~= "table" then TRF.sv = {}; end;
	local S = TRF.sv;
	S.b = S.b or {}; S.st = S.st or {res=0, sold=0, lost=0}; S.r = S.r or {}; S.cd = S.cd or {}; S.sd = S.sd or 1;
	local b = {s=s, x=0, y=0, z=0, n=n or 2, n0=n or 2, f=0, nm=0, lg=lg or TRF.clock.legs, src=2, sl=0, pf=100, pp=0};
	if t then for k, v in t do b[k] = v; end; end;
	tinsert(S.b, b);
	return b;
end;

-- Standing digit v of faction f (1..5) in region slot (rung 2 for 5..7).
function RQ_Fs(slot, f, v)
	TRF_Fs_Init();
	TRF.fs[slot] = TRF_FcSetDig(TRF.fs[slot], f, v);
end;

-- TRF.rq with one record (the done bit of the record's event set for states 2, 4 and 5).
function RQ_Set(e, s, t)
	local n = getn(TRF_RqData());
	local rec = {e=e, s=s, m=0, p=1, a=0, b=0, g=TRF_RqMod(TRF.clock.legs, 1000), d=0};
	if t then for k, v in t do rec[k] = v; end; end;
	local done = TRF_RqSetOf("", 0, n);
	if s ~= 1 and s ~= 3 then done = TRF_RqSetOf(done, e, n); end;
	TRF.rq = TRF_RqJoinOf(done, rec, nil);
	return rec;
end;

-- The record of TRF.rq now, or nil.
function RQ_R()
	local d, r = TRF_RqSplitOf(TRF.rq, getn(TRF_RqData()));
	return r;
end;
function RQ_Done(id) return TRF_RqBitOf(TRF_RqSplitOf(TRF.rq, getn(TRF_RqData())), id); end;

-- Trade and patrol dockings at the current location (r.scr lines, r.nb boxes, r.box the newest).
function RQ_Dock(kind)
	local h = HOST();
	local s0, b0 = getn(h.screen), getn(h.boxes);
	_param = GetCurrentLocation();
	if kind == "patrol" then __PatrolStationDock_Ok(); else __TradeStationDock_Ok(); end;
	local r = {scr="", nb=getn(h.boxes) - b0, s0=s0};
	for i = s0 + 1, getn(h.screen) do r.scr = r.scr..h.screen[i].t.."|"; end;
	if r.nb > 0 then r.box = h.boxes[getn(h.boxes)]; end;
	return r;
end;

-- A box of prio 400 at trade docks (stands in for the parcel offer).
function RQ_Box400(kind, param) return {text="stub offer 400", ok="RQ_BoxNil", no="RQ_BoxNil", own="stub"}; end;
function RQ_BoxNil(a) return nil; end;

-- The pay basis 9,000 and the ring rumour (tip) for the rewards.
function RQ_Pay9k() TRF_PayN = function(idx) return 9000; end; end;
function RQ_Tip(t) if t then TRF_Ti_Rumour = function(idx) return "Pirates were seen at Heos."; end; else TRF_Ti_Rumour = function(idx) return nil; end; end; end;

-- Per-visit caches of the strict gate and the chapter, after a change of HOST().labels or quests.
function RQ_QCache()
	TRF.live.qa = nil; TRF.live.qai = nil; TRF_H().loc = nil; TRF.live.gl = nil; TRF.live.sm = nil;
end;

-- a: install (12.1, 9, 10) -------------------------------------------------------------------

function T_RQ_A()
	local h = HOST();
	RQ_Begin("gaoba");
	HOST_Check(S_Logs(0, "module=core event=loaded map=true module_count=18 extra_count=25") >= 1, "trf_request loads last (extra_count=25)");
	local ml, pm, tf, uf = TRF_ModList(), TRF_PlMods(), TRF_Loc_TextFns(), TRF_UI_TextFns();
	HOST_Check(ml[getn(ml)] == "Rq" and ml[getn(ml) - 1] == "Sy" and pm[getn(pm)] == "Rq" and tf[getn(tf) - 1] == "TRF_Rq_Text"
		and tf[getn(tf) - 2] == "TRF_Sy_Text" and tf[getn(tf)] == "TRF_Loc_Text" and uf[getn(uf)] == "TRF_Rq_Text",
		"Rq last in TRF_ModList and TRF_PlMods; TRF_Rq_Text after TRF_Sy_Text in both text lists");
	HOST_Check(TRF_OptEnum().requests == 1 and TRF_OptEnum().rq_box == 1 and TRF_Opt("requests") == 1 and TRF_Opt("rq_box") == 1
		and TRF_Opt("request_at") == "", "cfg requests 1, rq_box 1, request_at \"\" by default; enums of requests and rq_box");
	-- Registrations: trade and patrol box 50 (last), patrol line 85 (last), the death bus.
	local P = TRF_PlReg();
	local tb, pb, pl = P.dock.trade.box, P.dock.patrol.box, P.dock.patrol.line;
	HOST_Check(tb[getn(tb)].o == 50 and TRF_PlName(tb[getn(tb)].f) == "TRF_Rq_DockBox" and pb[getn(pb)].o == 50
		and TRF_PlName(pb[getn(pb)].f) == "TRF_Rq_DockBox" and pl[getn(pl)].o == 85 and TRF_PlName(pl[getn(pl)].f) == "TRF_Rq_PatrolLine"
		and TRF_PlIn(P.dh, "Rq"), "box 50 at trade and patrol docks below every built box, patrol line 85 last, death bus Rq");
	-- Texts: 82 keys, each resolves, no %, #, line break, under 480 characters; the scaffold holds them.
	local tx, bad, n = TRF_Rq_Text(), "", 0;
	for k, v in tx do
		n = n + 1;
		if strsub(k, 1, 2) ~= "rq" or TRF_Txt(k) == k or RQ_Has(v, "%") or RQ_Has(v, "#") or RQ_Has(v, "\n") or strlen(v) >= 480 then
			bad = bad.." "..k;
		end;
	end;
	HOST_Check(n == 82 and bad == "", "82 rq keys, each resolves, no %, #, line break, under 480 characters ("..n..")"..bad);
	local d = TRF_RqData();
	local miss = "";
	for i = 1, getn(d) do
		for _, sx in {"a", "o", "x"} do if not tx["rq"..d[i].k..sx] then miss = miss.." rq"..d[i].k..sx; end; end;
		if not tx["rqt"..strsub(d[i].k, 1, 2)] then miss = miss.." rqt"..strsub(d[i].k, 1, 2); end;
		if not tx["rqd"..d[i].kd] or not tx["rqj"..d[i].kd] then miss = miss.." "..d[i].kd; end;
	end;
	HOST_Check(miss == "", "every event has its request, outcome and lapse lines, a fallback title and the kind texts"..miss);
	local en = RQ_ReadFile(h.dir.."../../../../loc/trf_en.loc");
	local cr, lf = strchar(13), strchar(10);
	miss = "";
	for k, v in tx do
		local want = cr..lf.."#TRF_"..TRF_LocKey(k).." = "..TRF_Loc_Plain(v)..cr..lf;
		if not (en and strfind(en, want, 1, 1)) then miss = miss.." "..k; end;
	end;
	HOST_Check(miss == "", "loc/trf_en.loc holds the 82 rq keys with their fixed forms (rqt* and rqd* for AddQuest)"..miss);
	-- The 10 display names of trf_remark (EN and RU).
	local rt = TRF_Rm_Text();
	local nm = {"rmnsedoy", "rmnyana", "rmnjosef", "rmnblade", "rmnuel", "rmnaia", "rmnalex", "rmnvalidol", "rmnalisa", "rmnche"};
	local ru = RQ_ReadFile(h.dir.."../../../../loc/trf_ru.loc");
	miss = "";
	for i = 1, getn(nm) do
		if type(rt[nm[i]]) ~= "string" or not (ru and strfind(ru, lf.."#TRF_"..nm[i].." = [^"..cr..lf.."]+"..cr..lf)) then miss = miss.." "..nm[i]; end;
	end;
	HOST_Check(miss == "" and TRF_RmSpeakerName("Sedoy") == "Greyhair" and TRF_RmSpeakerName("Uel3") == "SAM" and TRF_RmSpeakerName("Alisa") == "Alice",
		"trf_remark: the 10 names in EN and RU, the screen-line name of Sedoy, Uel3, Alisa"..miss);
	-- Tune defaults and clamps; rq_delay after A08's sg_delay.
	local T = TRF_RqTune();
	HOST_Check(T.rq_ch == 4 and T.rq_ch_end == 20 and T.rq_dl_ch == 5 and T.rq_delay == 7 and T.rq_secs == 8 and T.rq_gap == 4 and T.rq_miss == 3
		and T.rq_pend_old == 40 and T.rq_owe_max == 3 and T.rq_dl_cap == 15 and T.rq_dl_rng == 10 and T.rq_trk_over == 2 and T.rq_trk_j == 3
		and T.rq_bcn_j == 2 and T.rq_rng_j == 1 and T.rq_rung == 2 and T.rq_k == 10 and T.rq_help == 1 and T.rq_fs == 1 and T.rq_log_keep == 10,
		"tune defaults of spec 10");
	HOST_Check(T.rq_delay > TRF_Sg_TuneDef().sg_delay and TRF_RqClampT().rq_delay[1] > TRF_Sg_TuneDef().sg_delay, "rq_delay (7) after sg_delay (6), clamp 7..20");
	h.cfg.tune = {rq_delay=3, rq_miss=0, rq_k=99, rq_gap=2.6};
	T = TRF_RqTune();
	HOST_Check(T.rq_delay == 7 and T.rq_miss == 1 and T.rq_k == 50 and T.rq_gap == 2, "clamps: rq_delay 3 -> 7, rq_miss 0 -> 1, rq_k 99 -> 50, rq_gap 2.6 -> 2");
	h.cfg.tune = nil;
	h.cfg.requests = 5;
	HOST_Check(TRF_RqOpt("requests") == 1, "cfg requests 5 reads as the default");
	h.cfg.requests = nil;
	-- The event table (6.1).
	local keys = "";
	for i = 1, getn(d) do keys = keys..d[i].k..","; end;
	local crew = TRF_SpCrew();
	tinsert(crew, "Alisa"); tinsert(crew, "Che");
	local bt = "";
	for i = 1, getn(d) do
		if d[i].v ~= "rep" then
			for j = 1, getn(d[i].v) do if not TRF_RqIdx(crew, d[i].v[j]) then bt = bt.." "..d[i].v[j]; end; end;
		end;
		if (d[i].dl ~= nil) ~= (d[i].kd == "cap" or (d[i].kd == "rng" and d[i].k ~= "hr1")) then bt = bt.." dl:"..d[i].k; end;
	end;
	HOST_Check(keys == "tn1,tn2,tn3,tn4,hr1,hr2,hr3,gh1,gh2,km1,rp1,vd1,al1,ch1,ax1,jn1," and getn(d) <= TRF_RqK().nmax and bt == "",
		"16 events in id order, templates in TRF_SpCrew (plus Alisa, Che of the data note) or rep, deadlines on cap and rng rows but hr1"..bt);
	local c4 = "";
	for i = 1, getn(d) do if d[i].c0 <= 4 then c4 = c4..d[i].k..","; end; end;
	HOST_Check(c4 == "tn1,hr1,", "chapter 4: only tn1 and hr1 (no deadline)");
	-- The module body.
	local body = RQ_ReadFile(h.dir.."trf_request.script");
	HOST_Check(body and not RQ_Has(body, "GetPlayerQuestState(") and not RQ_Has(body, "AddPlayerExperience") and not RQ_Has(body, "SetPerk")
		and not RQ_Has(body, "CreatePilot") and not RQ_Has(body, "GetPlayerMotherShip") and not RQ_Has(body, "\n\"") and not strfind(body, "[\128-\255]"),
		"body: no GetPlayerQuestState, AddPlayerExperience, SetPerk, CreatePilot, GetPlayerMotherShip; ASCII");
	local tk = RQ_ReadFile(h.dir.."trf_track.script");
	HOST_Check(tk and RQ_Has(tk, 'TRF_P("TRF_Rq_OnTrack", rec.id, rec.nm);'), "trf_track: the spawn hook line in TRF_TrackSpawn");
	-- requests 0: nothing over 10 entries and 50 ticks with a subject in reach; the record kept.
	h.cfg.requests = 0;
	local g, li = RQ_Sys();
	local n0 = S_Mark();
	for i = 1, 10 do
		if mod(i, 2) == 1 then RQ_Go("lidau", nil, 3); else RQ_Go("gaoba", function() RQ_Trk(500 + %i, %li, 1); end, 3); end;
	end;
	T_Tick(50, 0.5);
	local busy = RQ_Logs(n0, "event=pick") + RQ_Logs(n0, "event=line") + RQ_Logs(n0, "event=say") + RQ_Logs(n0, "event=request ") + RQ_Logs(n0, "event=logbook")
		+ RQ_Logs(n0, "event=jump") + RQ_Logs(n0, "event=enter");
	HOST_Check(TRF.rq == nil and busy == 0 and RQ_Msgs(0) == "" and RQ_Logs(n0, "event=skip system=gaoba reason=off") >= 1,
		"requests 0: TRF.rq nil, no pick, line, say, logbook or enter line over 10 entries (only skip off and the dump)");
	RQ_Set(1, 2, {a=7, b=li});
	local s1 = TRF.rq;
	RQ_Go("gaoba", nil, 10);
	HOST_Check(TRF.rq == s1, "requests 0: an active request waits");
	h.cfg.requests = nil;
	n0 = S_Mark();
	TRF_Rq_Dump();
	HOST_Check(RQ_Logs(n0, "event=dump on=1 event_count=16 done=1000 state=2 event_key=tn1") == 1, "dump line ("..RQ_Line(n0, "event=dump")..")");
end;

-- b: the pick (6.2, 6.3, RD2) ----------------------------------------------------------------

function RQ_OkNot(x) if x == HOST().rq_deny then return nil; end; return 1; end;

function T_RQ_B()
	local h = HOST();
	RQ_Begin("gaoba");
	local g, li, he, xk = RQ_Sys();
	local T = {rq_trk_over=2, rq_trk_j=3, record_ttl=8, rq_bcn_j=2, rq_rung=2};
	local dist = {[g]=0, [li]=1, [he]=1, [xk]=2};
	local L = 100;
	-- trk: filters, the overdue bounds, robbed and attacked bits, the order.
	local pool = {{id=1, nm=1, o=0, s=li, d=0, dm=0, fl=1, t=L - 4}};
	HOST_Check(TRF_RqTrkOf(pool, g, dist, L, T, "met").a == 1, "trk: met, overdue 3 legs, one jump: found");
	HOST_Check(TRF_RqTrkOf(pool, g, dist, L, T, "con") == nil and TRF_RqTrkOf(pool, g, dist, L, T, "dmg") == nil
		and TRF_RqTrkOf(pool, g, dist, L, T, "mc").a == 1, "trk filters: contract and damaged refuse a met trader, met-or-contract takes it");
	pool[1].fl = 2;
	HOST_Check(TRF_RqTrkOf(pool, g, dist, L, T, "con").a == 1 and TRF_RqTrkOf(pool, g, dist, L, T, "met") == nil, "trk: contract bit 2");
	pool[1].fl = 1; pool[1].dm = 2;
	HOST_Check(TRF_RqTrkOf(pool, g, dist, L, T, "dmg").a == 1, "trk: damaged dm 2");
	pool[1].fl = 1 + 4;
	HOST_Check(TRF_RqTrkOf(pool, g, dist, L, T, "met") == nil, "trk: robbed (bit 4) refused");
	pool[1].fl = 1 + 16;
	HOST_Check(TRF_RqTrkOf(pool, g, dist, L, T, "met") == nil, "trk: attacked by the player (bit 16) refused");
	pool[1].fl = 1;
	pool[1].t = L - 2;
	HOST_Check(TRF_RqTrkOf(pool, g, dist, L, T, "met") == nil, "trk: elapsed 1 < rq_trk_over 2 refused");
	pool[1].t = L - 3;
	HOST_Check(TRF_RqTrkOf(pool, g, dist, L, T, "met") ~= nil, "trk: elapsed 2 taken");
	pool[1].t = L - 7;
	HOST_Check(TRF_RqTrkOf(pool, g, dist, L, T, "met") ~= nil, "trk: elapsed 6 = record_ttl - 2 taken");
	pool[1].t = L - 8;
	HOST_Check(TRF_RqTrkOf(pool, g, dist, L, T, "met") == nil, "trk: elapsed 7 > record_ttl - 2 refused");
	pool[1].t = L - 4;
	pool[1].s = g;
	HOST_Check(TRF_RqTrkOf(pool, g, dist, L, T, "met") == nil, "trk: in the current system refused");
	pool[1].s = V_Idx("kadi");
	HOST_Check(TRF_RqTrkOf(pool, g, dist, L, T, "met") == nil, "trk: beyond the jump list refused");
	pool[1].s = li; pool[1].d = 2;
	HOST_Check(TRF_RqTrkOf(pool, g, dist, L, T, "met") == nil, "trk: docked (d 2) refused");
	pool[1].d = 1; pool[1].o = 1;
	HOST_Check(TRF_RqTrkOf(pool, g, dist, L, T, "met") == nil, "trk: owner not FTU refused");
	pool[1].o = 0;
	pool = {{id=5, o=0, s=xk, d=0, fl=1, t=L - 6}, {id=4, o=0, s=li, d=1, fl=1, t=L - 3}, {id=3, o=0, s=he, d=0, fl=1, t=L - 5},
		{id=2, o=0, s=he, d=0, fl=1, t=L - 5}};
	HOST_Check(TRF_RqTrkOf(pool, g, dist, L, T, "met").a == 2, "trk order: one jump first, then the oldest t, then id");
	h.rq_deny = he;
	HOST_Check(TRF_RqTrkOf(pool, g, dist, L, T, "met", RQ_OkNot).a == 4, "trk: a denied system (heos) dropped");
	h.rq_deny = nil;
	-- cap: st, esc, met/gr, named.
	local c = {gen=3, st=1, esc=0, met=0, gr=0, seen=g};
	HOST_Check(TRF_RqCapOf(c, 5, "any", 1).a == 3 and TRF_RqCapOf(c, 5, "any", 1).b == 5, "cap: an active captain (gen 3, slot 5)");
	HOST_Check(TRF_RqCapOf(c, 5, "any", nil) == nil, "cap: not named (cfg cap_enable 0) refused");
	HOST_Check(TRF_RqCapOf(c, 5, "esc", 1) == nil and TRF_RqCapOf(c, 5, "grudge", 1) == nil, "cap: esc 0 and no grudge refused");
	c.esc = 1; c.met = 1; c.gr = 2;
	HOST_Check(TRF_RqCapOf(c, 5, "esc", 1) ~= nil and TRF_RqCapOf(c, 5, "grudge", 1) ~= nil, "cap: esc 1, met 1 with grudge 2 taken");
	c.st = 3;
	HOST_Check(TRF_RqCapOf(c, 5, "any", 1) == nil, "cap: hiding (st 3) refused");
	c.st = 1;
	h.rq_deny = g;
	HOST_Check(TRF_RqCapOf(c, 5, "any", 1, RQ_OkNot) == nil, "cap: last seen in a denied system refused");
	h.rq_deny = nil;
	-- bcn: src, q, age, aboard, order.
	local bl = {{s=li, n=2, lg=L - 1, src=2}};
	HOST_Check(TRF_RqBcnOf(bl, {}, g, dist, L, 4, T).b == li and TRF_RqBcnOf(bl, {}, g, dist, L, 4, T).a == L - 1, "bcn: seeded, pods left, age 1");
	bl[1].src = 1;
	HOST_Check(TRF_RqBcnOf(bl, {}, g, dist, L, 4, T) == nil, "bcn: witnessed (src 1) refused");
	bl[1].src = 2; bl[1].q = 1;
	HOST_Check(TRF_RqBcnOf(bl, {}, g, dist, L, 4, T) == nil, "bcn: a quest record refused");
	bl[1].q = nil; bl[1].lg = L - 4;
	HOST_Check(TRF_RqBcnOf(bl, {}, g, dist, L, 4, T) == nil, "bcn: age 4 >= sv_ttl refused");
	bl[1].lg = L - 3;
	HOST_Check(TRF_RqBcnOf(bl, {}, g, dist, L, 4, T) ~= nil and TRF_RqBcnOf(bl, {li}, g, dist, L, 4, T) == nil, "bcn: age 3 taken; its system aboard refused");
	bl[1].n = 0;
	HOST_Check(TRF_RqBcnOf(bl, {}, g, dist, L, 4, T) == nil, "bcn: no pods left refused");
	bl = {{s=xk, n=1, lg=L, src=2}, {s=he, n=1, lg=L - 2, src=2}, {s=li, n=1, lg=L - 1, src=2}};
	HOST_Check(TRF_RqBcnOf(bl, {}, g, dist, L, 4, T).b == li, "bcn order: one jump first, then the newest lg");
	-- rng: rung, war, order.
	local rr = {{x=he, j=1, pat=1, f=5, rung=2}, {x=g, j=0, pat=1, f=5, rung=1}};
	HOST_Check(TRF_RqRngOf(rr, g, T).b == he, "rng: rung 1 at the current desk refused, the neighbour's rung 2 taken");
	rr[2].rung = 2;
	HOST_Check(TRF_RqRngOf(rr, g, T).b == g and TRF_RqRngOf(rr, g, T).a == 5, "rng order: the current system first");
	rr[2].war = 1;
	HOST_Check(TRF_RqRngOf(rr, g, T).b == he, "rng: a faction at war refused");
	rr[1].f = nil;
	HOST_Check(TRF_RqRngOf(rr, g, T) == nil, "rng: no faction (Neutral) refused");
	-- The live system checks: a strict-denied system (a quest naming it) and an armed warn row.
	local qi = TRF_SafeQIds(li, TRF_Map().sys[li]);
	if type(qi) == "table" and qi[1] then
		h.quests[qi[1]] = QUEST_PROCESS;
		RQ_QCache();
		HOST_Check(not TRF_RqSysOk(li), "TRF_RqSysOk: lidau denied while a quest naming it runs");
		h.quests = {};
		RQ_QCache();
	end;
	HOST_Check(TRF_RqSysOk(li), "TRF_RqSysOk: lidau free");
	local wa = TRF_Wn_Armed;
	TRF_Wn_Armed = function(x) if x == HOST().rq_arm then return 1, "test"; end; return nil; end;
	h.rq_arm = li;
	HOST_Check(not TRF_RqSysOk(li), "TRF_RqSysOk: an armed warn row (TRF_Wn_Armed) denies the system");
	-- The pick: order by c1, done bits, chapter windows, rq_dl_ch, speakers, subjects.
	local rows = TRF_RqData();
	local s = {ch=6, T=TRF_RqTune(), done=TRF_RqSetOf("", 0, 16), at="", spk=TRF_RqSpk, subj=RQ_SubjAll};
	h.rq_subj = {};
	local pk, res = TRF_RqPickOf(rows, s);
	HOST_Check(pk == nil and res[1].res == "none" and res[4].res == "chapter" and res[10].res == "chapter" and res[8].res == "none",
		"pick: no subject -> none; tn4 and km1 out of their chapters; gh1 none");
	h.rq_subj = {hr2=1, tn3=1, gh1=1};
	pk, res = TRF_RqPickOf(rows, s);
	HOST_Check(pk and pk.id == 3 and pk.tpl == "Lastochka" and pk.pp == 2, "pick: tn3 (c1 10) before hr2 and gh1 (c1 20); Lastochka is template 2 of tn3");
	s.done = TRF_RqSetOf(s.done, 3, 16);
	pk, res = TRF_RqPickOf(rows, s);
	HOST_Check(pk and pk.id == 6 and res[3].res == "done", "pick: tn3 done -> hr2 (id 6 before gh1 8)");
	HOST().crew.Sedoy = nil;
	h.rq_subj = {gh1=1};
	pk, res = TRF_RqPickOf(rows, s);
	HOST_Check(pk == nil and res[8].res == "no_speaker", "pick: Greyhair absent -> no_speaker");
	RQ_Crew0();
	s.T = {rq_dl_ch=8};
	h.rq_subj = {tn2=1};
	pk, res = TRF_RqPickOf(rows, s);
	HOST_Check(pk == nil and res[2].res == "deadline_ch", "pick: rq_dl_ch 8 at chapter 6 refuses the deadline row tn2");
	s.T = TRF_RqTune();
	s.ch = 4;
	h.rq_subj = {tn1=1, tn2=1, tn3=1, hr1=1, hr2=1};
	pk, res = TRF_RqPickOf(rows, s);
	local ok4 = "";
	for i = 1, getn(res) do if res[i].res == "ok" then ok4 = ok4..res[i].k..","; end; end;
	HOST_Check(ok4 == "tn1,hr1," and pk.id == 1, "chapter 4: only tn1 and hr1 are candidates, tn1 first ("..ok4..")");
	s.ch = 6;
	s.done = TRF_RqSetOf(TRF_RqSetOf("", 1, 16), 3, 16);
	s.at = "tn1";
	h.rq_subj = {tn1=1, tn2=1};
	pk, res = TRF_RqPickOf(rows, s);
	HOST_Check(pk and pk.id == 1 and res[1].res == "ok", "request_at tn1: its done bit ignored, first in the order");
	-- rp1: the Repairman holder (not the firmware).
	RQ_Crew({Hero={}, Kalem={props={Repairman=1}}});
	s.at = ""; s.done = TRF_RqSetOf("", 0, 16);
	h.rq_subj = {rp1=1};
	pk, res = TRF_RqPickOf(rows, s);
	HOST_Check(pk and pk.id == 11 and pk.tpl == "Kalem" and pk.pp == 1, "rp1: Kalem with Repairman speaks (index 1 of the candidates)");
	RQ_Crew({Hero={}});
	h.ms_props = {Repairman=1};
	pk, res = TRF_RqPickOf(rows, s);
	HOST_Check(pk == nil and res[11].res == "no_speaker", "rp1: the mothership firmware alone is no speaker");
	h.ms_props = nil;
	RQ_Crew0();
	TRF_Wn_Armed = wa;
	-- Flow: the finders on the live records at an entry into gaoba.
	local n0 = S_Mark();
	RQ_Go("gaoba", function() RQ_Trk(41, %li, 1); end);
	HOST_Check(RQ_R() and RQ_R().e == 1 and RQ_R().a == 41 and RQ_R().b == li and RQ_Logs(n0, "event=pick event_key=tn1 kind=trk speaker=Lastochka subject_a=41") == 1
		and RQ_Logs(n0, "event=candidate event_key=tn2 result=none") == 1, "entry: tn1 picked on the pool record (trader 41 in lidau)");
	-- rq_gap: an end 2 legs ago holds the next pick.
	TRF.rq = TRF_RqJoinOf(TRF_RqSetOf("", 1, 16), nil, TRF_RqMod(TRF.clock.legs - 1, 1000));
	TRF.tp = {};
	n0 = S_Mark();
	RQ_Go("gaoba", function() RQ_Trk(42, %li, 2); end);
	HOST_Check(RQ_R() == nil and RQ_Logs(n0, "reason=gap") == 1, "rq_gap: an end 2 legs back, no pick");
	TRF.rq = TRF_RqJoinOf(TRF_RqSetOf("", 1, 16), nil, TRF_RqMod(TRF.clock.legs - 3, 1000));
	n0 = S_Mark();
	RQ_Go("gaoba", function() TRF.tp = {}; RQ_Trk(42, %li, 2); end);
	HOST_Check(RQ_R() and RQ_R().e == 6, "rq_gap: 4 legs after the end hr2 is picked");
	-- A pending record: kept while live, dropped when the subject goes or it gets old (RD2), done bit untouched.
	TRF.tp = {}; TRF.rq = nil;
	n0 = S_Mark();
	RQ_Go("gaoba", function() RQ_Trk(43, %li, 1); TRF_EventSlotTake("test"); end);
	HOST_Check(RQ_R() and RQ_R().s == 1 and RQ_R().m == 1 and not RQ_Done(1) and RQ_Logs(n0, "result=miss reason=event:test") == 1,
		"event slot held: tn1 pending with one miss");
	n0 = S_Mark();
	RQ_Go("gaoba", function() TRF_EventSlotTake("test"); end);
	HOST_Check(RQ_R() and RQ_R().s == 1 and RQ_R().m == 2 and RQ_Logs(n0, "event=pick event_key=tn1") == 1 and RQ_Logs(n0, "result=kept") == 1,
		"next entry: the pending record kept (second miss)");
	TRF.tp = {};
	n0 = S_Mark();
	RQ_Go("gaoba");
	HOST_Check(RQ_R() == nil and not RQ_Done(1) and RQ_Logs(n0, "result=cleared reason=subject") == 1, "RD2: the trader gone, the pending record cleared unconsumed");
	RQ_Set(1, 1, {a=44, b=li, g=TRF_RqMod(TRF.clock.legs - 41, 1000)});
	n0 = S_Mark();
	RQ_Go("gaoba", function() RQ_Trk(44, %li, 1); end);
	HOST_Check(RQ_Logs(n0, "result=cleared reason=old") == 1 and RQ_Logs(n0, "event=pick event_key=tn1") == 2, "RD2: pending for 41 legs dropped (old), then picked again");
	-- RD2 for a kept record: its system armed now (D13), then the chapter past its c1.
	TRF.tp = {};
	RQ_Set(1, 1, {a=47, b=li});
	n0 = S_Mark();
	RQ_Go("gaoba", function() RQ_Trk(47, %li, 1); TRF_Wn_Armed = function(x) if x == HOST().rq_arm then return 1, "test"; end; return nil; end; end);
	TRF_Wn_Armed = wa;
	HOST_Check(RQ_R() == nil and not RQ_Done(1) and RQ_Logs(n0, "result=cleared reason=subject") == 1 and RQ_Logs(n0, "result=queued") == 0,
		"RD2: a pending record whose system became armed is cleared, not queued");
	TRF.tp = {};
	RQ_Set(1, 1, {a=48, b=li});
	h.labels.CurrentQuest = "11";
	n0 = S_Mark();
	RQ_Go("gaoba", function() RQ_Trk(48, %li, 1); end);
	h.labels.CurrentQuest = "6";
	HOST_Check(not (RQ_R() and RQ_R().e == 1) and not RQ_Done(1) and RQ_Logs(n0, "result=cleared reason=chapter") == 1,
		"RD2: a pending tn1 at chapter 11 (c1 10) is cleared unconsumed");
	-- request_at: done bit and gap ignored.
	h.cfg.request_at = "tn1";
	TRF.rq = TRF_RqJoinOf(TRF_RqSetOf("", 1, 16), nil, TRF_RqMod(TRF.clock.legs, 1000));
	n0 = S_Mark();
	RQ_Go("gaoba", function() TRF.tp = {}; RQ_Trk(45, %li, 1); end);
	HOST_Check(RQ_R() and RQ_R().e == 1 and RQ_Logs(n0, "event=debug event_key=tn1 result=eligible") == 1, "request_at tn1: picked although done and inside the gap");
	-- Inside the gap request_at opens only its own row: hr2 waits.
	TRF.rq = TRF_RqJoinOf(TRF_RqSetOf("", 1, 16), nil, TRF_RqMod(TRF.clock.legs, 1000));
	h.cfg.request_at = "tn3";
	n0 = S_Mark();
	RQ_Go("gaoba", function() TRF.tp = {}; RQ_Trk(46, %li, 2); end);
	HOST_Check(RQ_R() == nil and RQ_Logs(n0, "event=candidate event_key=hr2 result=gap") == 1 and RQ_Logs(n0, "event=debug event_key=tn3 result=none") == 1,
		"request_at tn3 inside the gap: hr2 not picked (gap), tn3 without a subject");
	h.cfg.request_at = nil;
end;

-- Subject stub of TRF_RqPickOf: the keys in HOST().rq_subj.
function RQ_SubjAll(e, id)
	if HOST().rq_subj[e.k] then return {a=id, b=1}; end;
	return nil;
end;

-- c: the radio pair (7.2, 7.3) ---------------------------------------------------------------

function RQ_Q2() TRF_ArrivalLine("remark", "first line", {v={"Hero"}, s=TRF_CurIdx(), l=1}); TRF_ArrivalLine("signal", "second line"); end;

function T_RQ_C()
	local h = HOST();
	RQ_Begin("gaoba");
	local g, li = RQ_Sys();
	-- The pair: Lastochka asks, the Hero answers; state 2, the done bit, the logbook (mission list).
	local n0, m0 = S_Mark(), 0;
	RQ_Go("gaoba", function() RQ_Trk(51, %li, 1); end);
	local ms = RQ_Msgs(0);
	local tn = TRF_Names()[2];
	HOST_Check(RQ_Has(ms, "Lastochka:The "..tn.." has gone quiet since she left for Lidau.") and RQ_Has(ms, "|Hero:Understood. If we pass through Lidau, we look for the "..tn.."."),
		"pair: Lastochka's request, then the Hero's reply ("..ms..")");
	local r = RQ_R();
	HOST_Check(r and r.s == 2 and r.m == 0 and r.d == 0 and RQ_Done(1) and RQ_Logs(n0, "event=request event_key=tn1 kind=trk chapter=6 deadline=0 via=radio result=shown") == 1
		and RQ_Logs(n0, "event=say event_key=tn1 part=1 speaker=Lastochka output=radio result=shown") == 1 and RQ_Logs(n0, "part=2 speaker=Hero output=radio result=shown") == 1,
		"part 1 shown: state 2, the done bit, the request line; part 2 shown");
	HOST_Check(h.quests.trf_rq == QUEST_PROCESS and h.qlog.trf_rq.t == "#TRF_rqttn" and h.qlog.trf_rq.d == "#TRF_rqdtrk"
		and RQ_Logs(n0, "event=logbook id=trf_rq entry=start list=quest result=added") == 1, "logbook: AddQuest with the fixed keys");
	HOST_Check(S_Logs(n0, "module=plumb event=arrival_line owner=request line_index=1") == 1 and S_Logs(n0, "owner=request line_index=2") == 1,
		"two queue slots used (line 1 and 2)");
	-- Job log on: plain text with the names.
	RQ_Begin("gaoba", "6", {jobs_log=1}, 1);
	n0 = S_Mark();
	RQ_Go("gaoba", function() RQ_Trk(52, %li, 1); end);
	local je = h.jl[1];
	HOST_Check(je and je.id == "trf_rq" and je.t == "Ternie's request" and je.d == "Ternie asked us to look for the "..tn.." at Lidau." and je.s == QUEST_PROCESS
		and RQ_Logs(n0, "list=jobs result=added") == 1 and h.quests.trf_rq == nil, "logbook: the Job log entry with plain text ("..tostring(je and je.d)..")");
	-- Lines queued first (a remark and a signal line): the pair needs two free slots.
	RQ_Begin("gaoba");
	n0 = S_Mark();
	RQ_Go("gaoba", function() RQ_Trk(53, %li, 1); TRF_ArrivalLine("remark", "first line"); end);
	local q = HOST().logs;
	local order = "";
	for i = n0 + 1, getn(q) do
		local a, b, o = strfind(q[i], "module=plumb event=arrival_line owner=(%a+) line_index=%d+ .*result=queued");
		if o then order = order..o..","; end;
	end;
	HOST_Check(order == "remark,request,request," and RQ_R().s == 2, "queue 1: the remark first, then the pair ("..order..")");
	RQ_Begin("gaoba");
	n0 = S_Mark();
	RQ_Go("gaoba", function() RQ_Trk(54, %li, 1); TRF_ArrivalLine("remark", "first line"); TRF_ArrivalLine("signal", "second line"); end);
	HOST_Check(RQ_R().s == 1 and RQ_R().m == 1 and RQ_Logs(n0, "event=line event_key=tn1 miss_count=1 line_count=0 result=miss reason=queued:2") == 1,
		"queue 2: a miss (queued:2), nothing queued");
	-- A silent pilot (csr false): a miss with no_speaker:silent; one miss per entry.
	RQ_Begin("gaoba");
	RQ_Crew({Hero={}, Lastochka={csr=0}});
	n0 = S_Mark();
	RQ_Go("gaoba", function() RQ_Trk(55, %li, 1); end);
	HOST_Check(RQ_R().s == 1 and RQ_R().m == 1 and RQ_Logs(n0, "reason=no_speaker:silent") == 1, "silent pilot: one miss (no_speaker:silent)");
	n0 = S_Mark();
	RQ_Go("gaoba");
	HOST_Check(RQ_R().s == 1 and RQ_R().m == 2, "second entry: miss 2");
	n0 = S_Mark();
	RQ_Go("gaoba");
	HOST_Check(RQ_R().s == 3 and RQ_R().m == 3 and RQ_Logs(n0, "result=box") == 1 and not RQ_Done(1), "third miss: state 3 (the box), not done");
	-- Part 1 refused at the say (a hold between the queue and the say): a miss, part 2 not shown.
	RQ_Begin("gaoba");
	n0 = S_Mark();
	T_Jump("gaoba");
	RQ_Trk(56, li, 1);
	T_Tick(15, 0.5);
	HOST_Check(RQ_Logs(n0, "line_count=2 result=queued") == 1, "the pair queued at the due");
	__disableAction = TRUE;
	T_Tick(30, 0.5);
	__disableAction = nil;
	HOST_Check(RQ_R().s == 1 and RQ_R().m == 1 and RQ_Logs(n0, "part=1 speaker=Lastochka output=nil result=not_shown reason=hold:disable_action") == 1
		and RQ_Logs(n0, "part=2") == 1 and RQ_Logs(n0, "part=2 speaker=Hero output=nil result=not_shown") == 1 and RQ_Msgs(0) == "",
		"part 1 refused (hold): a miss; part 2 refused too");
	-- The Hero's own request: the reply from the first present responder; nobody: one line.
	RQ_Begin("gaoba");
	n0 = S_Mark();
	RQ_Go("gaoba", function() RQ_Trk(57, %li, 2); end);
	ms = RQ_Msgs(0);
	HOST_Check(RQ_R().e == 6 and RQ_Has(ms, "Hero:The "..tn.." flew under our contract") and RQ_Has(ms, "|Lastochka:We will keep an eye out at Lidau."),
		"hr2: the Hero asks, Ternie answers ("..ms..")");
	RQ_Begin("gaoba");
	RQ_Crew({Hero={}});
	n0 = S_Mark();
	RQ_Go("gaoba", function() RQ_Trk(58, %li, 2); end);
	HOST_Check(RQ_R().s == 2 and RQ_Logs(n0, "line_count=1 result=queued") == 1 and getn(h.msgs) == 1, "hr2 without a responder: the request alone");
	-- A bcn request: part 2 from the Hero (rqrbcn).
	RQ_Begin("gaoba");
	n0 = S_Mark();
	RQ_Go("gaoba", function() RQ_Bcn(%li); end);
	ms = RQ_Msgs(0);
	HOST_Check(RQ_R().e == 3 and RQ_Has(ms, "Lastochka:That beacon at Lidau is a hauler crew in pods.") and RQ_Has(ms, "|Hero:Copy. Plotting for Lidau."),
		"tn3: the beacon request and the Hero's reply");
end;

-- d: outcomes (6.4, 7.5, 7.6) ------------------------------------------------------------------

function T_RQ_D()
	local h = HOST();
	RQ_Begin("gaoba");
	local g, li, he = RQ_Sys();
	local tn = TRF_Names()[2];
	-- trk: the spawn hook in the subject's system pays help and 900 credits; the line from the 1 s step.
	RQ_Go("gaoba", function() RQ_Trk(61, %li, 1); end);
	HOST_Check(RQ_R().s == 2, "tn1 active");
	RQ_Go("heos", nil, 3);
	TRF_Rq_OnTrack(61, 2);
	HOST_Check(RQ_R().s == 2, "the spawn hook in another system: nothing");
	RQ_Go("lidau", nil, 1);
	RQ_Pay9k();
	local c0, hp0, n0, m0 = h.credits, TRF.std.help, S_Mark(), getn(h.msgs);
	TRF_Rq_OnTrack(61, 2);
	HOST_Check(h.credits - c0 == 900 and TRF.std.help == hp0 + 1 and RQ_Logs(n0, "event=outcome event_key=tn1 kind=trk age=") == 1
		and RQ_Logs(n0, "credits=900 help=1 standing=0 tip=false result=done") == 1 and S_Logs(n0, "module=region event=pay reason=rq amount=900") == 1,
		"trk outcome: help +1 and 900 cr through TRF_Pay");
	HOST_Check(RQ_Logs(n0, "event=logbook id=trf_rq entry=end list=quest result=done") == 1 and h.quests.trf_rq == QUEST_DONE, "logbook end: done");
	T_Tick(4, 0.5);
	HOST_Check(RQ_Has(RQ_Msgs(m0), "Lastochka:There she is, the "..tn..".") and RQ_R() == nil and RQ_Logs(n0, "part=outcome speaker=Lastochka output=radio result=shown") == 1,
		"the outcome line at the next step, the record cleared, the end stamped");
	HOST_Check(h.credits - c0 == 900, "TRF_Pay once per outcome");
	-- cap: the death bus with the player's fire; without it a lapse (other).
	TRF.rq = nil; TRF.tp = {};
	T_Tick(2, 0.5);
	RQ_Begin("gaoba", "6", {cap_enable=1});
	local slot = V_Slot("gaoba");
	RQ_Go("gaoba", function() RQ_Cap(%slot, {met=0, gr=0}); end);
	HOST_Check(RQ_R() and RQ_R().e == 2 and RQ_R().s == 2 and RQ_R().d == 15 and RQ_R().a == 2 and RQ_R().b == slot, "tn2 active (deadline 15)");
	n0 = S_Mark();
	TRF_Dead("cap", {g="TRF_Cap_"..slot, n=slot, j=1}, nil, 1);
	HOST_Check(RQ_R().s == 4 and RQ_Logs(n0, "event=outcome event_key=tn2 kind=cap") == 1 and RQ_Logs(n0, "credits=0 help=0 standing=0") == 1,
		"death bus with pfire 1: done, no reward (the claim pays)");
	T_Tick(4, 0.5);
	HOST_Check(RQ_R() == nil and RQ_Has(RQ_Msgs(0), "Lastochka:"..TRF_CapNm(TRF.cap[slot]).." is dead."), "the outcome line");
	RQ_Begin("gaoba", "6", {cap_enable=1});
	RQ_Go("gaoba", function() RQ_Cap(%slot, {met=0, gr=0}); end);
	n0 = S_Mark();
	TRF_Dead("cap", {g="TRF_Cap_"..slot, n=slot, j=1}, nil, nil);
	HOST_Check(RQ_R().s == 5 and RQ_Logs(n0, "event=lapse event_key=tn2 age=0 reason=other") == 1 and h.quests.trf_rq == QUEST_FAILED, "death bus without the player's fire: lapse other");
	TRF_Dead("raid", {g="TRF_Raid_1", n=slot, j=1}, nil, 1);
	HOST_Check(RQ_R().s == 5, "a raid death changes nothing");
	-- An off-screen captain death (st 4, no claim): the 1 s step lapses it (subject); with a claim it is done.
	RQ_Begin("gaoba", "6", {cap_enable=1});
	RQ_Go("gaoba", function() RQ_Cap(%slot, {met=0, gr=0}); end);
	n0 = S_Mark();
	TRF.cap[slot].st = 4;
	T_Tick(3, 0.5);
	HOST_Check(RQ_R().s == 5 and RQ_Logs(n0, "reason=subject") == 1, "off-screen death without a claim: lapse subject (poll)");
	RQ_Begin("gaoba", "6", {cap_enable=1});
	RQ_Go("gaoba", function() RQ_Cap(%slot, {met=0, gr=0}); end);
	n0 = S_Mark();
	TRF.cap[slot].st = 4;
	TRF.claim = {{slot=slot, gen=2, nm=3, amt=1000, kind=1, leg=TRF.clock.legs}};
	T_Tick(3, 0.5);
	HOST_Check(RQ_Logs(n0, "event=outcome event_key=tn2") == 1, "dead with the player's claim: done (poll)");
	-- bcn: the pods aboard (poll) pay 900.
	RQ_Begin("gaoba");
	RQ_Go("gaoba", function() RQ_Bcn(%li); end);
	HOST_Check(RQ_R().e == 3 and RQ_R().s == 2 and RQ_R().d == 0, "tn3 active (no deadline: the beacon's life)");
	RQ_Go("lidau", nil, 1);
	RQ_Pay9k();
	c0, n0 = h.credits, S_Mark();
	TRF.sv.b[1].n = 0;
	TRF.sv.c = {n=2, cr=200, pc=0, s1=li, f=0, lg=TRF.clock.legs};
	T_Tick(3, 0.5);
	HOST_Check(h.credits - c0 == 900 and RQ_Logs(n0, "event=outcome event_key=tn3 kind=bcn") == 1 and RQ_Logs(n0, "event=lapse") == 0, "pods aboard: done before the beacon's lapse, 900 cr");
	-- rng: the patrol desk in the named system: the dock line with the tip, standing +1.
	RQ_Begin("gaoba");
	local f = TRF_FacIdx("Inoco");
	RQ_Fs(slot, f, 6);
	RQ_Go("gaoba");
	HOST_Check(RQ_R() and RQ_R().e == 5 and RQ_R().a == f and RQ_R().b == g and RQ_R().d == 0, "hr1 active (the Inoco desk at Gaoba, rung 2)");
	RQ_Go("heos", nil, 3);
	local pr = RQ_Dock("patrol");
	HOST_Check(RQ_R().s == 2 and not RQ_Has(pr.scr, "Hero:"), "a patrol dock in another system: nothing");
	RQ_Go("gaoba", nil, 3);
	RQ_Tip(1);
	n0 = S_Mark();
	local fs0 = TRF_Fs(slot, f);
	pr = RQ_Dock("patrol");
	HOST_Check(RQ_Has(pr.scr, "Hero: The "..TRF_FcFacName(f).." desk at Gaoba kept its word.") and RQ_Has(pr.scr, "The desk officer adds: Pirates were seen at Heos.")
		and TRF_Fs(slot, f) == fs0 + 1 and RQ_R() == nil and RQ_Logs(n0, "standing=1 tip=true result=done") == 1, "rng outcome at the dock: the line, the tip, standing +1 ("..pr.scr..")");
	RQ_Begin("gaoba");
	RQ_Fs(slot, f, 6);
	RQ_Go("gaoba");
	RQ_Tip(nil);
	n0 = S_Mark();
	pr = RQ_Dock("patrol");
	HOST_Check(RQ_R() == nil and not RQ_Has(pr.scr, "desk officer") and RQ_Logs(n0, "tip=false result=done") == 1, "rng outcome without a rumour: no tip clause");
	-- loc_mode 1: the dock line is the outcome key (the rqsay wrapper would show only its fixed form).
	RQ_Begin("gaoba");
	RQ_Fs(slot, f, 6);
	RQ_Go("gaoba");
	h.cfg.loc_mode = 1; TRF_H().loc = nil;
	pr = RQ_Dock("patrol");
	h.cfg.loc_mode = nil; TRF_H().loc = nil;
	HOST_Check(RQ_R() == nil and RQ_Has(pr.scr, "#TRF_rqhr1o") and not RQ_Has(pr.scr, "#TRF_rqsay"), "loc_mode 1: the dock outcome line is the hr1o key ("..pr.scr..")");
	-- The outcome line under a scene: retried at the steps until the scene ends.
	RQ_Begin("gaoba");
	RQ_Go("gaoba", function() RQ_Trk(62, %li, 1); end);
	RQ_Go("lidau", nil, 1);
	local m1 = getn(h.msgs);
	h.ui = 1; TRF_UiState = HOST_UiState;
	TRF_Rq_OnTrack(62, 2);
	T_Tick(6, 0.5);
	HOST_Check(RQ_R().s == 4 and getn(h.msgs) == m1, "outcome under a scene: state 4, no line yet");
	h.ui = 0;
	T_Tick(3, 0.5);
	TRF_UiState = nil; h.ui = nil;
	HOST_Check(RQ_R() == nil and getn(h.msgs) == m1 + 1, "scene over: the outcome line at the next step");
	-- Owed after a jump: the line at the next entry through the queue; dropped after rq_owe_max entries.
	RQ_Begin("gaoba");
	RQ_Go("gaoba", function() RQ_Trk(63, %li, 1); end);
	RQ_Go("lidau", nil, 1);
	__disableAction = TRUE;
	TRF_Rq_OnTrack(63, 2);
	__disableAction = nil;
	HOST_Check(RQ_R().s == 4, "outcome under a hold: state 4");
	n0 = S_Mark();
	RQ_Go("heos");
	HOST_Check(RQ_R() == nil and RQ_Logs(n0, "event=owe event_key=tn1 result=queued") == 1 and RQ_Logs(n0, "event=owe event_key=tn1 result=shown") == 1
		and RQ_Has(RQ_Msgs(0), "Lastochka:There she is"), "owed: queued and shown at the next entry");
	RQ_Begin("gaoba");
	RQ_Go("gaoba", function() RQ_Trk(64, %li, 1); end);
	RQ_Set(1, 4, {a=64, b=li, p=2});
	RQ_Crew({Hero={}, Lastochka={csr=0}});
	n0 = S_Mark();
	RQ_Go("heos"); RQ_Go("lidau");
	HOST_Check(RQ_R() and RQ_R().s == 4 and RQ_R().m == 2, "owed line, silent speaker: two tries");
	RQ_Go("heos");
	HOST_Check(RQ_R() == nil and RQ_Logs(n0, "event=owe event_key=tn1 result=dropped") == 1, "rq_owe_max 3: dropped without the line");
end;

-- e: lapses (7.6) ---------------------------------------------------------------------------

function T_RQ_E()
	local h = HOST();
	RQ_Begin("gaoba", "6", {cap_enable=1});
	local g, li, he = RQ_Sys();
	local slot = V_Slot("gaoba");
	-- deadline: dd 15 holds at age 15, lapses at 16.
	RQ_Go("gaoba", function() RQ_Cap(%slot, {met=0, gr=0}); end);
	local r = RQ_R();
	HOST_Check(r.e == 2 and r.d == 15, "tn2 active");
	r.g = TRF_RqMod(TRF.clock.legs - 15, 1000);
	TRF.rq = TRF_RqJoinOf(TRF_RqSetOf("", 2, 16), r, nil);
	T_Tick(3, 0.5);
	HOST_Check(RQ_R().s == 2, "deadline: age 15 = dd holds");
	r.g = TRF_RqMod(TRF.clock.legs - 16, 1000);
	TRF.rq = TRF_RqJoinOf(TRF_RqSetOf("", 2, 16), r, nil);
	local n0 = S_Mark();
	T_Tick(3, 0.5);
	HOST_Check(RQ_R().s == 5 and RQ_Logs(n0, "event=lapse event_key=tn2 age=16 reason=deadline") == 1 and RQ_Logs(n0, "entry=end list=quest result=lapsed") == 1,
		"deadline: age 16 lapses, the logbook lapses");
	-- The lapse line at the next entry.
	n0 = S_Mark();
	RQ_Go("heos");
	HOST_Check(RQ_R() == nil and RQ_Has(RQ_Msgs(0), "Lastochka:We missed our chance at") and RQ_Logs(n0, "event=say event_key=tn2 part=lapse speaker=Lastochka output=radio result=shown") == 1,
		"lapse line at the next entry");
	-- chapter: past c1 (tn1 at chapter 10 -> 11 with Ternie still aboard counts the pilot first; chapter 12 for hr1-like rows).
	RQ_Begin("gaoba", "10");
	RQ_Go("gaoba", function() RQ_Trk(71, %li, 1); end);
	HOST_Check(RQ_R().e == 1 and RQ_R().s == 2, "tn1 active in chapter 10");
	h.labels.CurrentQuest = "12";
	RQ_QCache();
	n0 = S_Mark();
	RQ_Go("heos");
	HOST_Check(RQ_Logs(n0, "event=lapse event_key=tn1") == 1 and RQ_Logs(n0, "reason=chapter") == 1, "chapter 12 > c1 10: lapse chapter");
	-- subject: the trader record expired; a beacon gone.
	RQ_Begin("gaoba");
	RQ_Go("gaoba", function() RQ_Trk(72, %li, 1); end);
	TRF.tp = {};
	n0 = S_Mark();
	T_Tick(3, 0.5);
	HOST_Check(RQ_R().s == 5 and RQ_Logs(n0, "reason=subject") == 1, "trader record gone: lapse subject");
	RQ_Begin("gaoba");
	RQ_Go("gaoba", function() RQ_Bcn(%li); end);
	TRF.sv.b = {};
	n0 = S_Mark();
	T_Tick(3, 0.5);
	HOST_Check(RQ_R().e == 3 and RQ_R().s == 5 and RQ_Logs(n0, "reason=subject") == 1, "beacon gone: lapse subject");
	-- pilot: Ternie removed (chapter 11): cleared at once, no line, the logbook lapses.
	RQ_Begin("gaoba", "10");
	RQ_Go("gaoba", function() RQ_Trk(73, %li, 1); end);
	h.labels.CurrentQuest = "11_1";
	RQ_QCache();
	RQ_Crew({Hero={}, Sedoy={}});
	local m0 = getn(h.msgs);
	n0 = S_Mark();
	T_Tick(3, 0.5);
	HOST_Check(RQ_R() == nil and RQ_Done(1) and RQ_Logs(n0, "event=lapse event_key=tn1") == 1 and RQ_Logs(n0, "reason=pilot") == 1
		and h.quests.trf_rq == QUEST_FAILED and getn(h.msgs) == m0, "pilot gone: cleared at once, done bit kept, no line, logbook lapsed");
	RQ_Go("heos");
	HOST_Check(not RQ_Has(RQ_Msgs(0), "Lastochka:"), "no Ternie line after the pilot lapse");
	-- Lastochka2 in chapter 13 for tn4 (he escaped once).
	RQ_Begin("gaoba", "13a", {cap_enable=1});
	RQ_Crew({Hero={}, Lastochka2={}, Kalem={}, Sedoy={}});
	n0 = S_Mark();
	RQ_Go("gaoba", function() RQ_Cap(%slot, {esc=1, met=0, gr=0}); end);
	HOST_Check(RQ_R() and RQ_R().e == 4 and RQ_Logs(n0, "event=pick event_key=tn4 kind=cap speaker=Lastochka2") == 1 and RQ_Has(RQ_Msgs(0), "Lastochka2:"),
		"chapter 13: tn4 spoken by Lastochka2");
end;

-- f: the dock box (7.4) ------------------------------------------------------------------------

function RQ_BoxSetup()
	local g, li = RQ_Sys();
	RQ_Crew({Hero={}, Lastochka={csr=0}});
	RQ_Go("gaoba", function() RQ_Trk(81, %li, 1); end);
	RQ_Go("gaoba"); RQ_Go("gaoba");
	HOST_Want(RQ_R() and RQ_R().s == 3, "the box state after three misses");
	RQ_Crew({Hero={}, Lastochka={csr=0}});
end;

function T_RQ_F()
	local h = HOST();
	RQ_Begin("gaoba");
	RQ_BoxSetup();
	-- A higher box (the parcel offer 400) wins: B03 is not asked.
	TRF_DockBox("trade", 400, "RQ_Box400");
	local n0 = S_Mark();
	local r = RQ_Dock("trade");
	HOST_Check(r.nb == 1 and r.box.text == "stub offer 400" and RQ_Logs(n0, "event=box") == 0, "box 400 wins; B03 not asked");
	HOST_Press("cancel", r.box);
	-- Alone: box 50 at the trade dock; Cancel consumes.
	RQ_Go("gaoba", nil, 3);
	n0 = S_Mark();
	r = RQ_Dock("trade");
	HOST_Check(r.nb == 1 and r.box.title == "#UI_TradeStationWndCaption" and RQ_Has(r.box.text, "Ternie: The ") and RQ_Has(r.box.text, "Will you take it on?")
		and RQ_Logs(n0, "event=box event_key=tn1 dock_kind=trade result=shown") == 1, "trade dock: box 50 with the request ("..tostring(r.box and r.box.text)..")");
	local s0 = getn(h.screen);
	HOST_Press("cancel", r.box);
	HOST_Check(RQ_R() == nil and RQ_Done(1) and RQ_Has(RQ_Scr(s0), "Ternie: Fair enough. Forget I asked.") and RQ_Logs(n0, "result=declined") == 1,
		"Cancel: the done bit, the record cleared, the reply");
	-- At a patrol dock; OK starts it (via box), the logbook.
	RQ_Begin("gaoba");
	RQ_BoxSetup();
	n0 = S_Mark();
	r = RQ_Dock("patrol");
	HOST_Check(r.nb == 1 and r.box.title == "#UI_PatrolStationWndCaption", "patrol dock: box 50");
	s0 = getn(h.screen);
	HOST_Press("ok", r.box);
	HOST_Check(RQ_R().s == 2 and RQ_Done(1) and RQ_Logs(n0, "event=request event_key=tn1 kind=trk chapter=6 deadline=0 via=box result=shown") == 1
		and RQ_Logs(n0, "result=accepted") == 1 and RQ_Has(RQ_Scr(s0), "Ternie: Thanks. I will not forget it.") and h.quests.trf_rq == QUEST_PROCESS,
		"OK: state 2 via box, the reply, the logbook");
	-- Gates: TRF_Quiet, a mission, the strict gate; a failed box; rq_box 0.
	RQ_Begin("gaoba");
	RQ_BoxSetup();
	__sys_SOS = TRUE;
	n0 = S_Mark();
	HOST_Check(TRF_Rq_DockBox("trade") == nil and RQ_Logs(n0, "reason=quiet") >= 1, "box gate: TRF_Quiet");
	__sys_SOS = nil;
	h.qs = TRUE;
	TRF_RqCV().q = nil;
	n0 = S_Mark();
	HOST_Check(TRF_Rq_DockBox("trade") == nil and RQ_Logs(n0, "reason=latch") >= 1, "box gate: a mission (the latch)");
	h.qs = FALSE;
	TRF_RqCV().q = nil;
	local qi = TRF_SafeQIds(TRF_CurIdx(), TRF_Map().sys[TRF_CurIdx()]);
	if type(qi) == "table" and qi[1] then
		h.quests[qi[1]] = QUEST_PROCESS;
		RQ_QCache();
		n0 = S_Mark();
		HOST_Check(TRF_Rq_DockBox("trade") == nil and RQ_Logs(n0, "reason=gate:") >= 1, "box gate: strict");
		h.quests = {};
		RQ_QCache();
	end;
	local smb = ShowMsgBox;
	ShowMsgBox = nil;
	n0 = S_Mark();
	r = RQ_Dock("trade");
	ShowMsgBox = smb;
	HOST_Check(RQ_R().s == 3 and RQ_Logs(n0, "result=failed") == 1, "a failed box changes nothing");
	h.cfg.rq_box = 0;
	r = RQ_Dock("trade");
	HOST_Check(not (r.box and RQ_Has(r.box.text, "Will you take it on?")), "rq_box 0: no box");
	h.cfg.rq_box = nil;
	-- The box gate: its system armed now (D13), the chapter past c1; loc_mode 1 shows the request key.
	local wa = TRF_Wn_Armed;
	h.rq_arm = V_Idx("lidau");
	TRF_Wn_Armed = function(x) if x == HOST().rq_arm then return 1, "test"; end; return nil; end;
	n0 = S_Mark();
	HOST_Check(TRF_Rq_DockBox("trade") == nil and RQ_Logs(n0, "result=none reason=subject") >= 1, "box gate: an armed subject system");
	TRF_Wn_Armed = wa;
	h.labels.CurrentQuest = "11";
	n0 = S_Mark();
	HOST_Check(TRF_Rq_DockBox("trade") == nil and RQ_Logs(n0, "result=none reason=chapter") >= 1, "box gate: the chapter past c1");
	h.labels.CurrentQuest = "6";
	h.cfg.loc_mode = 1; TRF_H().loc = nil;
	local lb = TRF_Rq_DockBox("trade");
	h.cfg.loc_mode = nil; TRF_H().loc = nil;
	HOST_Check(type(lb) == "table" and RQ_Has(lb.text, "#TRF_rqtn1a") and not RQ_Has(lb.text, "#TRF_rqbox") and RQ_R().s == 3,
		"loc_mode 1: the box text is the request key ("..tostring(lb and lb.text)..")");
	-- rq_box 0: no box state; the record stays pending.
	RQ_Begin("gaoba", "6", {rq_box=0});
	RQ_Crew({Hero={}, Lastochka={csr=0}});
	RQ_Go("gaoba", function() RQ_Trk(82, V_Idx("lidau"), 1); end);
	RQ_Go("gaoba"); RQ_Go("gaoba"); RQ_Go("gaoba");
	HOST_Check(RQ_R().s == 1 and RQ_R().m == 4, "rq_box 0: pending after four misses");
	-- The box record goes stale when its subject goes (RD2 at the due).
	RQ_Begin("gaoba");
	RQ_BoxSetup();
	TRF.tp = {};
	n0 = S_Mark();
	RQ_Go("gaoba");
	HOST_Check(RQ_R() == nil and not RQ_Done(1) and RQ_Logs(n0, "result=cleared reason=subject") == 1, "box record without its subject: cleared");
end;

-- g: gates (4) -----------------------------------------------------------------------------------

function T_RQ_G()
	local h = HOST();
	RQ_Begin("gaoba");
	local g, li = RQ_Sys();
	local n0 = S_Mark();
	-- R1 off.
	h.cfg.requests = 0;
	HOST_Check(TRF_RqGate(g, "space") == "off", "R1: off");
	h.cfg.requests = nil;
	-- R2 chapter.
	h.labels.CurrentQuest = "3";
	RQ_QCache();
	HOST_Check(TRF_RqGate(g, "space") == "chapter", "R2: chapter 3");
	h.labels.CurrentQuest = "6";
	RQ_QCache();
	-- R3 nomap.
	HOST_Check(TRF_RqGate(nil, "space") == "nomap" and TRF_RqGate(9999, "space") == "nomap", "R3: nomap");
	-- R4 mode.
	local sm = TRF_SysModeQuiet;
	TRF_SysModeQuiet = function() return "van", "test"; end;
	HOST_Check(TRF_RqGate(g, "space") == "mode:test" and TRF_RqGate(g, "dock") == nil, "R4: mode in space only");
	TRF_SysModeQuiet = sm;
	-- R5 strict: a deny entry with request = 0.
	local dl = TRF_DenyEntry;
	TRF_DenyEntry = function(idx) return {request=0}; end;
	RQ_QCache();
	local w = TRF_RqGate(g, "space");
	TRF_DenyEntry = dl;
	RQ_QCache();
	HOST_Check(w and strsub(w, 1, 5) == "gate:", "R5: a deny entry with request = 0 ("..tostring(w)..")");
	-- R6 latch, mission at a dock.
	h.qs = TRUE;
	HOST_Check(TRF_RqGate(g, "space") == "latch", "R6: the latch");
	h.qs = FALSE;
	HOST_Check(TRF_RqGate(g, "space") == "latch", "R6: the latch stays for the visit");
	TRF_RqVisit();
	HOST_Check(TRF_RqGate(g, "space") == nil, "R6: a new visit clears it");
	-- R7 holds.
	__disableAction = TRUE;
	HOST_Check(TRF_RqGate(g, "space") == "hold:disable_action" and TRF_RqGate(g, "out") == nil, "R7: hold in space; an outcome is not held");
	__disableAction = nil;
	__sys_SOS = TRUE;
	HOST_Check(TRF_RqGate(g, "space") == "hold:sys_sos" and TRF_RqGate(g, "dock") == "quiet", "R7: sys_sos; quiet at a dock");
	__sys_SOS = nil;
	h.ui = 1; TRF_UiState = HOST_UiState;
	HOST_Check(TRF_RqGate(g, "space") == "hold:scene", "R7: scene");
	TRF_UiState = nil; h.ui = nil;
	-- Skip lines once per reason and visit.
	HOST_Check(RQ_Logs(n0, "event=skip system=gaoba reason=hold:disable_action") == 1, "skip line once per reason and visit");
	-- At an entry: the latch set at the entry, no due, nothing changes.
	h.qs = TRUE;
	n0 = S_Mark();
	RQ_Go("gaoba", function() RQ_Trk(91, %li, 1); end);
	HOST_Check(TRF.rq == nil and RQ_Logs(n0, "reason=latch") >= 1 and RQ_Logs(n0, "event=pick") == 0, "entry under a mission: latch, no pick");
	h.qs = FALSE;
	-- R8 event slot, R9 queue (c), R10 gap (b), R11 no speaker, R12 none.
	RQ_Crew({Hero={}});
	TRF.tp = {};
	n0 = S_Mark();
	RQ_Go("gaoba", function() RQ_Trk(92, %li, 1); end);
	HOST_Check(TRF.rq == nil and RQ_Logs(n0, "event=candidate event_key=tn1 result=no_speaker") == 1 and RQ_Logs(n0, "event=pick result=none") == 1,
		"R11: Ternie absent, no pick of tn1; R12: nothing else -> none");
	RQ_Crew0();
	-- A load: no line (no entry); the logbook reconcile restores a missing entry of an active request.
	RQ_Go("gaoba", function() TRF.tp = {}; RQ_Trk(93, %li, 1); end);
	HOST_Check(RQ_R().s == 2 and h.quests.trf_rq == QUEST_PROCESS, "tn1 active");
	local m0 = getn(h.msgs);
	n0 = S_Mark();
	T_SaveLoad(function() HOST().quests = {}; end);
	T_Tick(30, 0.5);
	HOST_Check(getn(h.msgs) == m0 and RQ_Logs(n0, "event=line") == 0 and RQ_Logs(n0, "entry=start list=quest result=restored") == 1 and h.quests.trf_rq == QUEST_PROCESS,
		"load: no line, the missing logbook entry restored");
	-- The ended entry is removed rq_log_keep legs after the end.
	TRF.rq = TRF_RqJoinOf(TRF_RqSetOf("", 1, 16), nil, TRF_RqMod(TRF.clock.legs - 9, 1000));
	n0 = S_Mark();
	RQ_Go("heos", nil, 1);
	HOST_Check(RQ_Logs(n0, "result=removed") == 1 and h.quests.trf_rq == nil, "logbook removed 10 legs after the end");
	-- An entry gate denying the system (mode): no due.
	h.rqhook = function() TRF_SysModeQuiet = function() return "van", "test"; end; end;
	TRF.rq = nil; TRF.tp = {};
	n0 = S_Mark();
	RQ_Go("gaoba", function() RQ_Trk(94, %li, 1); end);
	h.rqhook = nil;
	HOST_Check(TRF.rq == nil and RQ_Logs(n0, "reason=mode:test") >= 1, "entry: mode not mod, no pick");
end;

-- h: save and repair (3, 7.7) ------------------------------------------------------------------

function T_RQ_H()
	local h = HOST();
	RQ_Begin("gaoba");
	local rows = TRF_RqData();
	local n = getn(rows);
	local fx = function(s) local o, ch = TRF_RqFixOf(s, %n, %rows); local w = ""; for i = 1, getn(ch) do w = w..ch[i][1]..":"..ch[i][2]..","; end; return o, w; end;
	local o, w = fx(nil);
	HOST_Check(o == nil and w == "", "F: nil stays nil");
	o, w = fx(12);
	HOST_Check(o == nil and w == "rq:dropped,", "F1: a number -> nil");
	o, w = fx("0000/");
	HOST_Check(o == nil and w == "rq:dropped,", "F2: two parts -> nil");
	o, w = fx("0z1g//");
	HOST_Check(o == "0010//" and w == "done:reset,", "F3: bad hex -> 0 ("..tostring(o)..")");
	o, w = fx("10//");
	HOST_Check(o == "1000//" and w == "done:reset,", "F3: padded to 4");
	o, w = fx("100000//123");
	HOST_Check(o == "1000//123" and w == "done:reset,", "F3: cut to 4");
	local o18, w18 = TRF_RqFixOf("fffff//", 18, {});
	HOST_Check(o18 == "ffff3//" and w18[1][1] == "done", "F3: bits above N (18) cleared ("..tostring(o18)..")");
	o, w = fx("0000/0121/");
	HOST_Check(o == nil and w == "rec:dropped,", "F4: a short rec dropped");
	o, w = fx("0000/016001000700500000/");
	HOST_Check(o == nil and w == "rec:dropped,", "F4: state 6 dropped");
	o, w = fx("0000/012000000700500000/");
	HOST_Check(o == nil and w == "rec:dropped,", "F4: pp 0 in state 2 dropped");
	o, w = fx("0000/011001000700500003/");
	HOST_Check(o == nil and w == "rec:dropped,", "F4: dd 3 on tn1 (no deadline) dropped");
	o, w = fx("0000/172001000700500000/");
	HOST_Check(o == nil and w == "rec:dropped,", "F4: event 17 > N dropped");
	o, w = fx("0000/012001000700500000/");
	HOST_Check(o == "1000/012001000700500000/" and w == "rec:set,", "F4: state 2 with the done bit clear -> set");
	o, w = fx("1000/011001000700500000/");
	HOST_Check(o == "1000//" and w == "rec:dropped,", "F4: state 1 with the done bit set -> dropped");
	o, w = fx("2000/022101000300501215/");
	HOST_Check(o == "2000/022101000300501215/" and w == "", "F4: tn2 active with deadline 15 kept");
	o, w = fx("1000//12a");
	HOST_Check(o == "1000//" and w == "end:reset,", "F5: bad end -> \"\"");
	o, w = fx("0000//");
	HOST_Check(o == nil and w == "", "F6: empty -> nil");
	-- TRF_Rq_Fix through TRF_Repair at an entry.
	TRF.rq = "0z00/016001000700500000/1x";
	local n0 = S_Mark();
	TRF_Repair();
	HOST_Check(TRF.rq == nil and RQ_Logs(n0, "event=fix field=done result=reset") == 1 and RQ_Logs(n0, "field=rec result=dropped") == 1
		and RQ_Logs(n0, "field=end result=reset") == 1, "TRF_Rq_Fix: fix lines, nil when empty");
	TRF.rq = "1000/012001000700500000/099";
	n0 = S_Mark();
	TRF_Repair();
	HOST_Check(TRF.rq == "1000/012001000700500000/099" and RQ_Logs(n0, "event=fix") == 0, "TRF_Rq_Fix: a valid string unchanged, no fix line");
	-- Pure helpers.
	HOST_Check(TRF_RqAgeOf(998, 1003) == 5 and TRF_RqAgeOf(5, 1005) == 0 and TRF_RqAgeOf(10, 9) == 999, "TRF_RqAgeOf over the wrap");
	local d = TRF_RqSetOf("", 0, 16);
	for i = 1, 16 do d = TRF_RqSetOf(d, i, 16); end;
	HOST_Check(d == "ffff" and TRF_RqBitOf(d, 16) and not TRF_RqBitOf("fff7", 16) and TRF_RqBitOf("0008", 16) and TRF_RqSetOf("0000", 17, 16) == "0000",
		"done bits: 16 events in 4 characters");
	local rs = TRF_RqRecStr({e=14, s=2, m=0, p=1, a=999, b=8, g=999, d=15});
	HOST_Check(rs == "142001099900899915" and TRF_RqRecOf(rs).a == 999 and TRF_RqRecOf(rs).d == 15 and strlen(rs) == 18, "record: 18 digits round trip");
	local w0 = TRF_RqRewardOf({rw="hc"}, 9000, TRF_RqTune());
	local w1 = TRF_RqRewardOf({rw="st"}, 9000, TRF_RqTune());
	local w2 = TRF_RqRewardOf({rw="none"}, 9000, TRF_RqTune());
	HOST_Check(w0.help == 1 and w0.cr == 900 and w1.fs == 1 and w1.tip == 1 and w1.cr == 0 and w2.cr == 0 and w2.help == 0, "rewards of 6.4");
	-- Lapse order of 7.6.
	local e = rows[2];
	HOST_Check(TRF_RqLapseOf({d=15}, e, {age=20, ch=12}) == "pilot" and TRF_RqLapseOf({d=15}, e, {pres=1, age=16, ch=12, live=1}) == "deadline"
		and TRF_RqLapseOf({d=15}, e, {pres=1, age=15, ch=12, live=1}) == "chapter" and TRF_RqLapseOf({d=15}, e, {pres=1, age=1, ch=6}) == "subject"
		and TRF_RqLapseOf({d=15}, e, {pres=1, age=1, ch=6, live=1}) == nil, "lapse order: pilot, deadline, chapter, subject");
	-- Size (3.4): 20 events at the bound, the 16-event table, idle after an end.
	local d20 = TRF_RqSetOf("", 0, 20);
	for i = 1, 20 do d20 = TRF_RqSetOf(d20, i, 20); end;
	TRF.rq = TRF_RqJoinOf(d20, {e=20, s=5, m=9, p=20, a=9999, b=999, g=999, d=99}, 999);
	local sz = HOST_SaveSize(TRF.rq) + 10;
	HOST_Check(sz == 46 and sz <= 46, "TRF.rq worst case with 20 events: "..sz.." bytes <= 46");
	TRF.rq = TRF_RqJoinOf(d, {e=16, s=5, m=9, p=1, a=999, b=999, g=999, d=0}, 999);
	HOST_Check(HOST_SaveSize(TRF.rq) + 10 == 45, "TRF.rq worst case with the 16 events: 45 bytes");
	TRF.rq = TRF_RqJoinOf(d, nil, 999);
	HOST_Check(HOST_SaveSize(TRF.rq) + 10 == 27, "idle after an end: 27 bytes");
	TRF.rq = TRF_RqJoinOf(d20, {e=20, s=5, m=9, p=20, a=9999, b=999, g=999, d=99}, 999);
	local full = 8 + 3 + HOST_SaveSize(TRF);
	HOST_Check(full < 100000, "TRF with TRF.rq at its bound: "..full.." bytes < 100000");
	TRF.rq = nil;
	-- The visit state is not saved; no handle in TRF; the keep thunk goes at a load.
	RQ_Go("gaoba", function() RQ_Trk(95, V_Idx("lidau"), 1); end);
	HOST_Check(type(TRF.rq) == "string" and type(TRF_RqKeepThunk) == "function", "active request, keep thunk set");
	local s1 = TRF.rq;
	T_SaveLoad();
	HOST_Check(TRF.rq == s1 and TRF_RqKeepThunk == nil and RQ_N(TRF_RqCV().pr) == 0, "save and load: TRF.rq kept, the keep thunk and the visit state gone");
	n0 = S_Mark();
	TRF_Rq_Dump();
	HOST_Check(RQ_Logs(n0, "event=dump on=1 event_count=16 done=1000 state=2 event_key=tn1") == 1, "dump after the load equals the state");
end;

-- Dispatch ---------------------------------------------------------------------------------

local sc = getenv("TRF_RQ") or "";
local fn = getglobal("T_RQ_"..strupper(sc));
print("HOST ==== request scenario rq-"..sc.." dir="..HOST().dir);
if type(fn) == "function" then
	fn();
	HOST_Check(T_LeftGlobals() == "", "no handle globals left at the end"..T_LeftGlobals());
else
	HOST_Check(nil, "unknown request scenario "..sc);
end;
HOST_Check((HOST().gpm_tick or 0) == 0, "no GetPlayerMotherShip from a tick (n="..tostring(HOST().gpm_tick or 0)..")");
print("HOST errors="..HOST().errors.." fails="..HOST().fails);
if HOST().errors > 0 or HOST().fails > 0 then exit(1); end;
exit(0);
