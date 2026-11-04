-- Clan temperaments and the Clan file scenarios (design/temperament-spec.md 11, B10) under stock Lua 4.0.1: TRF_TP=a..h,
-- run by run_host.sh as its own entry point. a registration, defaults and clamps, the table, the texts, the shared
-- intro-quest record TRF.iq (API, packing, repair, size), the dump; b the opening line on every raid kind (demand form,
-- no-demand form within R_radio, captain, once per raid id, chapters 3 and 4, the guard, temper 0 against the module
-- hidden); c the behaviour rows (Cutter leave, Haggler clamps, line and loss leave, Planner weight and call-off, Ghost
-- leave, the arrival word, the kept kinds stn, wq and captain); d the Ghost decloak (te_fx 1 and 0, no point, a base
-- raid); e the 200-leg check of the Planner weight; f the signals (trouble page, patrol board and its gate, harbour
-- news, dockmaster tip, news bulletin); g the offer (gates, box 350, OK, Cancel, card, D1 and its fallbacks, the files);
-- h progress and report (the answered raid on both pay branches and at the jump, step 20, D2 and the fallback line,
-- done, the reward, the letter, the logbook and its reconcile, a load, the lapse with and without the owner,
-- TRF_Te_Fix, te_quest 0, the full state).
-- Loads host_station.lua up to its first scenario (stubs of host_stubs.lua, the helpers of host_traffic.lua and
-- host_v02.lua, the DockStation.script stubs and the S_* helpers), as host_warn.lua does. No new native stub:
-- Carcass:PlayFX, StartTradeDialog, TRF_MissionCard (HOST_MissionCard), AddPost and the Job log natives exist.

local f = openfile((getenv("TRF_TESTS") or "./").."host_station.lua", "r");
if not f then print("HOST FAIL host_temper.lua: cannot open host_station.lua"); exit(1); end;
local src = read(f, "*a");
closefile(f);
local cut = strfind(src, "\n-- a: install (12.1, 6.1)", 1, 1);
if not cut then print("HOST FAIL host_temper.lua: marker '-- a: install (12.1, 6.1)' missing in host_station.lua"); exit(1); end;
dostring(strsub(src, 1, cut), "host_station.lua");

-- Helpers ----------------------------------------------------------------------------------

-- Config of these runs: temperaments and the Clan file on, its dialogs off, the features that claim boxes, lines,
-- raid slots or entry events off (captains, sweeps, carriers, parcels, the freight quest, stashes, survivors, the
-- ladder, charters, scars), the box path of the jobs UI, log 2, plus t.
function TP_Cfg(t)
	local c = {temper=1, te_quest=1, te_gate=1, te_dialog=0, cap_enable=0, sweeps=0, sweep_ct=0, feq=0, staged=0, seed=0, queue=0,
		parked=0, voice_events=0, dconv=0, carriers=0, po=0, enable_parcels=0, enable_wq=0, enable_stashes=0, enable_survivors=0,
		enable_freight=0, lad_enabled=0, charter=0, enable_scars=0, warn=0, remarks=0, jobs_ui=0, log=2, tune={}};
	if t then for k, v in t do c[k] = v; end; end;
	return c;
end;

-- Scenario start in sys at chapter label ch (default 5_1): every clan at score sc (default 60, T3), the regions in
-- Build-up, no intro-quest record, no relation overrides; jl 1 installs the Job log natives first.
function TP_Begin(sys, ch, t, sc, jl)
	local h = HOST();
	h.jl = {}; h.jl_off = nil;
	HOST_JobLogOn(jl or 0);
	h.labels.CurrentQuest = ch or "5_1";
	h.quests = {}; h.qlog = {};
	h.qs = FALSE;
	h.rel_team = nil;
	h.posts = {};
	h.jc = {}; h.jq = {}; h.jc_open = nil; h.jc_off = nil; h.jc_why = nil;
	TRF_MissionCard = nil; TRF_JobBoard = nil; TRF_JobBoardMark = nil;
	S_Begin(sys, TP_Cfg(t));
	h.credits = 1000000;
	for s = 1, TRF_RgMap().n do
		TRF.clan[s].sc = sc or 60;
		local rg = TRF.rg[s];
		rg.ph = 2; rg.pt = TRF.clock.legs; rg.sl = 0; rg.sn = 0; rg.sw = 0; rg.sr = nil;
	end;
	TRF.iq = nil;
	TRF_TeKeepThunk = nil;
	if type(TRF_TeVisit) == "function" then TRF_TeVisit(); end;
end;

function TP_Has(s, t) return strfind(s or "", t, 1, 1); end;

function TP_N(t) local n = 0; for k, v in t do n = n + 1; end; return n; end;

-- temper log lines after mark n0 holding pat (plain).
function TP_Logs(n0, pat)
	local n, q = 0, HOST().logs;
	for i = n0 + 1, getn(q) do if strfind(q[i], "module=temper ", 1, 1) and strfind(q[i], pat, 1, 1) then n = n + 1; end; end;
	return n;
end;

-- Every line said after the marks (radio messages and screen lines) joined by "|".
function TP_Said(m0, s0)
	local h, s = HOST(), "";
	for i = (m0 or 0) + 1, getn(h.msgs) do s = s..h.msgs[i].t.."|"; end;
	for i = (s0 or 0) + 1, getn(h.screen) do s = s..h.screen[i].t.."|"; end;
	return s;
end;
function TP_Marks() local h = HOST(); return getn(h.msgs), getn(h.screen); end;

-- Relation of team to the player (HOST().rel_team; the stub answers FRIEND for an unknown pair).
function TP_Rel(team, rel)
	local h = HOST();
	if type(h.rel_team) ~= "table" then h.rel_team = {}; end;
	h.rel_team[team.."|"..PLAYER_TEAM] = rel;
end;

-- Patrol docking through the wrapper chain at the current location: screen lines, boxes opened, the newest box.
function TP_PatDock()
	local h = HOST();
	local s0, b0 = getn(h.screen), getn(h.boxes);
	_param = GetCurrentLocation();
	__PatrolStationDock_Ok();
	local r = {scr="", nb=getn(h.boxes) - b0, s0=s0};
	for i = s0 + 1, getn(h.screen) do r.scr = r.scr..h.screen[i].t.."|"; end;
	if r.nb > 0 then r.box = h.boxes[getn(h.boxes)]; end;
	return r;
end;

-- A new visit without a jump (the visit state of trf_temper and the plumbing box lock).
function TP_Visit()
	TRF_TeVisit();
	if type(TRF.live) == "table" then TRF.live.box = nil; TRF.live.bt = nil; end;
end;

-- The open dialog: file name, page, pilot, message text, visible answers ({} when none is open).
function TP_Dlg()
	local d = HOST().dlg;
	if not d or not d.open then return {}; end;
	return {name=d.name, cur=d.cur, pilot=HOST_DlgPilot(), text=HOST_DlgText(), vis=HOST_DlgVis()};
end;
function TP_Picks(...) for i = 1, arg.n do HOST_DlgPick(arg[i]); end; end;
function TP_DlgUi(u)
	TRF_UiState = HOST_UiState;
	HOST().ui = u or 0;
end;

function TP_Read(rel)
	local f = openfile(HOST().dir..rel, "r");
	if not f then return nil; end;
	local s = read(f, "*a");
	closefile(f);
	return s;
end;

-- A fresh trader of path (default C) 40 from the mothership, the others removed, no combat hold: id, record, handles.
function TP_Trader(path)
	local h = HOST();
	V_ClearTr();
	TRF.live.cbt = nil;
	local id = T_Spawn(path or "C");
	if not id then id = T_Spawn(nil); end;
	T_MoveTr(id, h.ms.pos.x + 40, h.ms.pos.y, h.ms.pos.z);
	return id, TRF.live.tr[id], TRF_H().tr[id];
end;

-- A lane raid on a fresh trader: armed, then the go (its ships moved next to the mothership, so the no-demand opening
-- line is in range). Returns raid id, trader id, record, the flight table.
-- Every open raid cancelled.
function TP_EndRaids()
	local open = {};
	for k, rd in TRF.live.rd do if type(rd) == "table" and rd.st ~= "end" then tinsert(open, k); end; end;
	for i = 1, getn(open) do TRF_Rd_End(open[i], "cancel"); end;
	for id, r in TRF.live.tr do if type(r) == "table" then r.rdn = nil; end; end;
end;

function TP_Raid(path)
	local h = HOST();
	TP_EndRaids();
	local id, r, x = TP_Trader(path);
	local n = V_Raid(id);
	if not n then return nil, id, r; end;
	HOST_Fire("f_inside", "TRF_RaidGo("..n..",");
	local hr = TRF_H().rd[n];
	if hr then for j = 1, getn(hr.sh) do hr.sh[j].pos = Vector3(h.ms.pos.x + 60, h.ms.pos.y, h.ms.pos.z + 20 * j); end; end;
	return n, id, r, hr;
end;

function TP_Meet(n) HOST_Fire("f_object_inside", "TRF_RaidMeet("..n..","); end;

-- Bitwise test of an integer.
function TP_Bit(v, b) return TRF_IqHas(v, b) == 1; end;

-- a: registration, defaults, the table, texts, TRF.iq (3, 8, 10) -----------------------------------------

function T_TP_A()
	local h = HOST();
	TP_Begin("gredos", "5_1");
	HOST_Check(S_Logs(0, "module=core event=loaded map=true module_count=18 extra_count=21") >= 1, "trf_temper loads before trf_corp and trf_debrief (extra_count=21)");
	local ml, pm, tf, uf = TRF_ModList(), TRF_PlMods(), TRF_Loc_TextFns(), TRF_UI_TextFns();
	HOST_Check(ml[getn(ml) - 3] == "Te" and pm[getn(pm) - 2] == "Te" and tf[getn(tf) - 4] == "TRF_Te_Text" and tf[getn(tf)] == "TRF_Loc_Text"
		and uf[getn(uf) - 3] == "TRF_Te_Text", "Te, Crp, Db at the end of TRF_ModList and TRF_PlMods, TRF_Te_Text before TRF_Crp_Text and TRF_Db_Text in both text lists");
	-- cfg and tune defaults, clamps.
	local d = TRF_Te_OptDef();
	local e = TRF_OptEnum();
	HOST_Check(d.temper == 1 and d.te_quest == 1 and d.te_gate == 1 and d.te_dialog == 1 and e.temper == 1 and e.te_quest == 1 and e.te_gate == 1
		and e.te_dialog == 1 and TRF_Opt("te_gate") == 1, "cfg temper, te_quest, te_gate, te_dialog default 1, enumerations 0..1");
	h.cfg.te_gate = 3;
	HOST_Check(TRF_TeOpt("te_gate") == 1, "cfg te_gate outside 0..1 reads as the default");
	h.cfg.te_gate = nil;
	local T = TRF_TeTune();
	HOST_Check(T.te_ch == 4 and T.te_cut_hp == 0.25 and T.te_hag_cmin == 25 and T.te_hag_cmax == 98 and T.te_pl_hi == 1.6 and T.te_pl_lo == 0.7
		and T.te_pl_hp == 0.6 and T.te_pl_out == 1 and T.te_gh_hp == 0.7 and T.te_fx == 0 and T.te_gh_lo == 400 and T.te_gh_hi == 600
		and T.te_dc == 2 and TRF_Tune().te_pl_hi == 1.6 and TRF_Tune().iq_stale == 40 and TRF_PlTune("iq_stale") == 40,
		"tune defaults (13 te_* keys merged into TRF_Tune), trf_plumb iq_stale 40");
	h.cfg.tune = {te_ch=99, te_cut_hp=2, te_hag_cmin=60, te_hag_cmax=30, te_pl_hi=-1, te_pl_out=9, te_fx=5, te_gh_lo=1000, te_gh_hi=300, te_dc=-4, iq_stale=900};
	T = TRF_TeTune();
	HOST_Check(T.te_ch == 20 and T.te_cut_hp == 0.9 and T.te_hag_cmin == 60 and T.te_hag_cmax == 60 and T.te_pl_hi == 0 and T.te_pl_out == 5
		and T.te_fx == 1 and T.te_gh_lo == 1000 and T.te_gh_hi == 1000 and T.te_dc == 0 and TRF_PlTune("iq_stale") == 500,
		"tune clamps: te_hag_cmax raised to te_hag_cmin, te_gh_hi to te_gh_lo, iq_stale <= 500");
	h.cfg.tune = {};
	-- The table (2.1).
	local tab = TRF_TeTab();
	local per, bad = {0, 0, 0, 0}, "";
	for s = 1, 8 do per[tab[s]] = per[tab[s]] + 1; end;
	for s = 9, 15 do if TRF_Te_Of(s) then bad = bad.." "..s; end; end;
	HOST_Check(tab[1] == 2 and tab[2] == 4 and tab[3] == 2 and tab[4] == 3 and tab[5] == 1 and tab[6] == 3 and tab[7] == 1 and tab[8] == 4
		and per[1] == 2 and per[2] == 2 and per[3] == 2 and per[4] == 2 and bad == "" and TRF_Te_Of(nil) == nil,
		"table {2,4,2,3,1,3,1,4}: two clans per temperament, none for the spare slots 9..15"..bad);
	local cn = {"Rust Jackals", "Black Comets", "Ash Vipers", "Grey Ravens", "Red Knives", "Cold Suns", "Bone Hounds", "Night Kites"};
	local hn = {"dosis", "elinor", "gefest", "golkonda", "kadi", "moscowia", "torr", "xt27"};
	bad = "";
	for s = 1, 8 do
		if TRF_ClanName(s) ~= cn[s] or TRF_SysName(TRF_RgMap()[s].home) ~= hn[s] then bad = bad.." "..s; end;
	end;
	HOST_Check(bad == "", "clan names and homes by slot as spec 2.1"..bad);
	local ind = nil;
	for i = 1, getn(TRF_Map().sys) do if not TRF_RgOf(i) then ind = i; break; end; end;
	local m1, w1 = TRF_Te_Mode(ind);
	HOST_Check(ind and m1 == 0 and w1 == "no_clan" and TRF_Te_Word(ind) == nil, "an independent system: mode 0 no_clan, no word ("..tostring(ind and TRF_SysName(ind))..")");
	local mg, wg = TRF_Te_Mode(V_Idx("gredos"));
	local mk = TRF_Te_Mode(V_Idx("kadi"));
	HOST_Check(mg == 2 and wg == "full" and mk == 2 and TRF_Te_Word(V_Idx("kadi")) == "no talk" and TRF_Te_Word(V_Idx("taira")) == "unseen",
		"chapter 5: full in Gredos (guard off) and Kadi; words no talk (Kadi), unseen (Taira)");
	-- Texts (7): 82 keys, plain, every one in the merged EN table.
	local tx = TRF_Te_Text();
	local en = TRF_Loc_EN();
	bad = "";
	for k, v in tx do
		if strlen(v) >= 480 or strfind(v, "[%%#\n]") or strsub(v, 1, 1) == "#" or en[TRF_LocKey(k)] ~= v then bad = bad.." "..k; end;
	end;
	HOST_Check(TP_N(tx) == 82 and bad == "", "82 text keys below 480 characters, no %, # or newline, all in TRF_Loc_EN"..bad);
	HOST_Check(TRF_Txt("tews", "some", TRF_Txt("tew2")) == "some, talk first" and TRF_Txt("tecn", "Red Knives") == "Red Knives here. No talk, no tax. Open fire."
		and TRF_Txt("tenw", "Cold Suns", TRF_Txt("tev3")) == "The Cold Suns pick their targets.", "text forms: the trouble word, the Cutter line, the news suffix");
	-- TRF.iq (3.1): pack round trip at the bounds.
	local u = TRF_IqUnpack(TRF_IqPack(6, 9, 99, 9, 9999));
	local u0 = TRF_IqUnpack(TRF_IqPack(1, 1, 0, 0, 0));
	HOST_Check(TRF_IqPack(6, 9, 99, 9, 9999) == 999969999 and u.q == 6 and u.s == 9 and u.t == 99 and u.c == 9 and u.sd == 9999
		and u0.q == 1 and u0.s == 1 and u0.t == 0 and u0.c == 0 and u0.sd == 0, "packed a: round trip at the bounds (999969999)");
	local I = TRF_IqGet();
	HOST_Check(TRF.iq == nil and I.q == 0 and I.d == 0 and I.r == 0 and I.l == nil, "no record: zeros");
	local n0 = S_Mark();
	local L = TRF.clock.legs;
	local ok = TRF_IqTake(1, 21, 4410);
	local ok2, w2 = TRF_IqTake(2, 5, 1);
	I = TRF_IqGet();
	HOST_Check(ok == 1 and ok2 == nil and w2 == "busy" and I.q == 1 and I.s == 1 and I.t == 21 and I.c == 0 and I.sd == 4410 and I.l == L
		and S_Logs(n0, "module=plumb event=iq quest=1 step=1 target=21 count=0 result=taken") == 1
		and S_Logs(n0, "module=plumb event=iq quest=2 step=nil target=nil count=nil result=busy") == 1, "take: step 1, count 0, l = legs; a second take busy");
	TRF.clock.legs = L + 3;
	local s1, sw = TRF_IqSet(2, 2, 21, 0);
	local s2 = TRF_IqSet(1, 1, 21, 1);
	I = TRF_IqGet();
	HOST_Check(s1 == nil and sw == "owner" and s2 == 1 and I.c == 1 and I.l == L + 3 and I.sd == 4410, "set: only by the active quest's owner; l = legs; seed kept");
	local e2 = TRF_IqEnd(2, "done", 1);
	local e1 = TRF_IqEnd(1, "done", 4);
	I = TRF_IqGet();
	HOST_Check(e2 == nil and e1 == 1 and I.q == 0 and I.d == 1 and I.r == 4 and I.l == nil and TRF_IqDone(1) == 1 and TRF_IqDone(2) == nil
		and TRF_IqR(4) == 1 and TRF_IqR(1) == nil and TRF.iq.a == 0, "end done: done bit 1, reward bits ORed, a and l cleared");
	TRF_IqTake(1, 12, 1);
	TRF_IqEnd(1, "done", 4 + 16);
	HOST_Check(TRF.iq.d == 1 and TRF.iq.r == 20, "a second done: bits ORed (r 4 | 20 = 20)");
	TRF_IqTake(3, 0, 1);
	TRF_IqEnd(3, "lapsed");
	TRF_IqTake(4, 0, 1);
	TRF_IqEnd(4, "dropped");
	HOST_Check(TRF.iq.d == 1 and TRF.iq.a == 0 and S_Logs(n0, "quest=3 step=1 target=0 count=0 result=lapsed") == 1 and S_Logs(n0, "result=dropped") == 1,
		"lapsed and dropped set no done bit");
	-- Decline and wait.
	TRF.iq = nil;
	TRF.clock.legs = L;
	HOST_Check(TRF_IqDecline(1) == 1 and TRF.iq.l == L * 10 + 1 and TRF_IqWait(1, 2) == 1 and TRF_IqWait(2, 2) == nil, "decline: l = legs x 10 + q, the wait for that q only");
	TRF.clock.legs = L + 2;
	HOST_Check(TRF_IqWait(1, 2) == nil and TRF_IqWait(1, 3) == 1, "the wait ends after te_dc legs");
	TRF_IqTake(1, 21, 1);
	local dw, dww = TRF_IqDecline(2);
	HOST_Check(dw == nil and dww == "busy" and TRF_IqWait(1, 9) == nil, "no decline or wait while a quest is active");
	-- Size at the widest (3.4).
	TRF.iq = {a=999999999, d=63, r=1073741823, l=999999};
	local sz = HOST_SaveSize(TRF.iq);
	print("HOST info TRF.iq widest "..sz.." bytes");
	HOST_Check(sz <= 100, "HOST_SaveSize(TRF.iq) at the widest "..sz.." <= 100");
	-- Repair (3.1).
	local fx = function(v) TRF.iq = v; TRF_Pl_Fix(); return TRF.iq; end;
	local r1 = fx("junk");
	local r2 = fx({a=1.5, d=64, r=-1, l=1, x=1});
	local r2b = fx({d=1, r=2, l=1, x=1});
	local r3 = fx({a=TRF_IqPack(7, 1, 21, 0, 1), d=1, r=1});
	local r4 = fx({a=TRF_IqPack(1, 0, 21, 0, 1), d=1, l=TRF.clock.legs});
	local r5 = fx({a=0, d=0, r=0});
	local r6 = fx({a=0, d=1, l=(TRF.clock.legs + 1) * 10 + 1});
	local r7 = fx({a=TRF_IqPack(1, 2, 21, 0, 1), d=0, r=0, l=TRF.clock.legs});
	n0 = S_Mark();
	local r8 = fx({a=TRF_IqPack(1, 1, 21, 0, 1), d=0, r=0});
	local r9 = fx({a=TRF_IqPack(1, 1, 21, 0, 1), d=0, r=0, l=TRF.clock.legs * 10 + 1});
	HOST_Check(r8.l == TRF.clock.legs and r9.l == TRF.clock.legs and S_Logs(n0, "module=plumb event=iq_fix field=l result=reset") == 2,
		"repair: an active quest without a progress leg, or with a decline stamp, gets legs (the lapse clock)");
	HOST_Check(r1 == nil and r2 == nil and r2b.a == 0 and r2b.d == 1 and r2b.r == 2 and r2b.l == 1 and r2b.x == nil and r3.a == 0 and r3.d == 1
		and r4.a == 0 and r4.l == nil and r5 == nil and r6.l == nil and r6.d == 1 and r7.a == TRF_IqPack(1, 2, 21, 0, 1) and r7.l == TRF.clock.legs,
		"repair: a string dropped, bad a/d/r reset, unknown keys dropped, q 7 and s 0 reset (with their l), empty record nil, l above legs dropped, a sound record kept");
	-- The owner fix (3.2).
	n0 = S_Mark();
	TRF.iq = {a=TRF_IqPack(1, 1, 95, 0, 1), d=0, r=0, l=TRF.clock.legs};
	TRF_Repair();
	local f1 = TRF.iq;
	TRF.iq = {a=TRF_IqPack(1, 1, 26, 0, 1), d=0, r=0, l=TRF.clock.legs};
	TRF_Repair();
	local f2 = TRF.iq;
	TRF.iq = {a=TRF_IqPack(1, 1, 21, 2, 1), d=0, r=0, l=TRF.clock.legs};
	TRF_Repair();
	local f3 = TRF.iq;
	TRF.iq = {a=TRF_IqPack(1, 2, 21, 0, 1), d=1, r=1, l=TRF.clock.legs};
	TRF_Repair();
	local f4 = TRF.iq;
	TRF.iq = {a=TRF_IqPack(1, 1, 21, 1, 1), d=0, r=0, l=TRF.clock.legs};
	TRF_Repair();
	HOST_Check(f1 == nil and f2 == nil and f3 == nil and f4 and f4.a == 0 and f4.r == 1 and TRF_IqGet().c == 1
		and TP_Logs(n0, "event=fix field=slot result=dropped") == 1 and TP_Logs(n0, "event=fix field=faction result=dropped") == 1
		and TP_Logs(n0, "event=fix field=c result=dropped") == 1 and TP_Logs(n0, "event=fix field=done result=dropped") == 1,
		"TRF_Te_Fix: a bad slot (9), faction (6) or count (2 at step 10) and a run for a done faction are dropped; a sound run kept");
	-- Dump.
	n0 = S_Mark();
	TRF_Te_Dump();
	TRF_Pl_Dump();
	HOST_Check(TP_Logs(n0, "event=dump temper=1 gate=1 quest=1 step=10 slot=2 faction=1 count=1 done=0 reward=0 table=2,4,2,3,1,3,1,4") == 1
		and S_Logs(n0, "module=plumb event=dump_iq quest=1 step=1 target=21 count=1") == 1, "dump lines (temper and plumb)");
	TRF.iq = nil;
	-- cfg temper 0 and enabled 2: mode 0 off.
	h.cfg.temper = 0;
	local mo, wo = TRF_Te_Mode(V_Idx("kadi"));
	h.cfg.temper = nil;
	HOST_Check(mo == 0 and wo == "off", "cfg temper 0: mode 0 off");
end;

-- b: the opening line (T7, 5.2) -----------------------------------------------------------------

-- One lane raid in Valensia (Haggler) with a fixed seed and forced draws: meet, decide (comply), leave. Returns the
-- module=raid log lines and the lines said, joined.
function TP_LaneFlow(t)
	local h = HOST();
	TRF = nil;
	h.seed = 4242;
	TP_Begin("valensia", "5_1", t);
	local n0 = S_Mark();
	local m0, s0 = TP_Marks();
	local n, id, r = TP_Raid("C");
	if not n then return "no raid"; end;
	TP_Meet(n);
	r.br = 0.05;
	h.rq = {0};
	T_Tick(20, 0.5);
	h.rq = {};
	T_Tick(30, 0.5);
	local q, o = h.logs, "";
	for i = n0 + 1, getn(q) do if strfind(q[i], "module=raid ", 1, 1) then o = o..q[i].." || "; end; end;
	return o.."said:"..TP_Said(m0, s0);
end;

function T_TP_B()
	local h = HOST();
	-- Stations without positions: every route point qualifies as a raid point (as v02-h).
	h.st_label = "TRADE STATION";
	-- temper 0 against the module hidden: the same raid log and lines (same seed, same draws).
	h.hide = {["trf_temper.script"]=1};
	local a = TP_LaneFlow({temper=0});
	HOST_Check(S_Logs(0, "extra_count=20") >= 1 and type(TRF_Te_Open) ~= "function", "trf_temper hidden: extra_count=20, no hooks");
	h.hide = nil;
	h.logs = {};
	local b = TP_LaneFlow({temper=0});
	HOST_Check(a == b and TP_Has(a, "result=comply") and TP_Has(a, TRF_Txt("comply", "")) == nil, "cfg temper 0: the raid log and lines equal the run without trf_temper");
	if a ~= b then print("HOST info hidden: "..a); print("HOST info temper 0: "..b); end;
	HOST_Check(TP_Has(a, "event=demand") and TP_Has(a, "result=comply"), "the built flow: demand, comply");
	-- Demand kinds: the opening line replaces the demand line, said by the raid leader (one line, the clan named).
	local cases = {{"valensia", "tehd", "Ash Vipers", "haggler"}, {"golkonda", "tepd", "Grey Ravens", "planner"}, {"taira", "tegd", "Black Comets", "ghost"}};
	for i = 1, getn(cases) do
		local c = cases[i];
		TP_Begin(c[1], "5_1");
		local n, id, r, hr = TP_Raid("C");
		local m0, s0 = TP_Marks();
		local n0 = S_Mark();
		TP_Meet(n);
		local said = TP_Said(m0, s0);
		local nl = 0;
		for k = m0 + 1, getn(h.msgs) do nl = nl + 1; end;
		for k = s0 + 1, getn(h.screen) do nl = nl + 1; end;
		HOST_Check(n and said == TRF_Txt(c[2], c[3]).."|" and nl == 1 and S_Logs(n0, "module=raid event=demand raid_id="..n) == 1
			and TP_Logs(n0, "event=open raid_id="..n.." kind=lane clan_slot="..TRF_RgOf(TRF_CurIdx()).." temper="..c[4].." form=demand mode=full result=said") == 1
			and V_Rd(n).st == "demand", c[1]..": the "..c[4].." demand line replaces the built one ("..tostring(said)..")");
		TRF_Rd_End(n, "cancel");
	end;
	-- Cutter: no demand, the no-demand line within R_radio, refuse, distress, flee.
	TP_Begin("kadi", "5_1");
	local n, id, r, hr = TP_Raid("C");
	local m0, s0 = TP_Marks();
	local n0 = S_Mark();
	TP_Meet(n);
	local said = TP_Said(m0, s0);
	HOST_Check(n and TP_Has(said, TRF_Txt("tecn", "Red Knives")) and S_Logs(n0, "module=raid event=demand") == 0 and S_Logs(n0, "module=raid event=refuse raid_id="..n) == 1
		and TP_Has(said, "pirates on us") and r.st == "flee" and V_Rd(n).st == "fight"
		and TP_Logs(n0, "event=open raid_id="..n.." kind=lane clan_slot=5 temper=cutter form=no_demand mode=full result=said") == 1,
		"kadi (Cutter): no demand, tecn, refuse, distress line, the trader flees ("..said..")");
	-- Once per raid id.
	n0 = S_Mark();
	HOST_Check(TRF_Te_Open(n, V_Rd(n), "n") == nil and TP_Logs(n0, "event=open raid_id="..n.." result=none reason=said") == 1, "once per raid id: the second call says nothing");
	TRF_Rd_End(n, "cancel");
	-- A captain's raid: no line.
	n0 = S_Mark();
	HOST_Check(TRF_Te_Open(77, {why="staged", cap=5}, "n") == nil and TP_Logs(n0, "event=open raid_id=77 result=none reason=captain") == 1, "a captain's raid: no opening line");
	-- TRF_RaidOn kinds: fq at the portal go (in range), dc armed at a raid point (at the meet), stn and wq.
	local kinds = {"fq", "dc", "stn", "wq"};
	for i = 1, getn(kinds) do
		local k = kinds[i];
		local id2 = TP_Trader("C");
		n0 = S_Mark();
		m0, s0 = TP_Marks();
		local n2 = TRF_RaidOn({id2}, 2, k, 0);
		if n2 and V_Rd(n2) and V_Rd(n2).st == "armed" then
			HOST_Fire("f_inside", "TRF_RaidGo("..n2..",");
			local hr2 = TRF_H().rd[n2];
			if hr2 then for j = 1, getn(hr2.sh) do hr2.sh[j].pos = Vector3(h.ms.pos.x + 60, h.ms.pos.y, h.ms.pos.z + 20 * j); end; end;
			TP_Meet(n2);
		end;
		said = TP_Said(m0, s0);
		HOST_Check(n2 and TP_Has(said, TRF_Txt("tecn", "Red Knives")) and TP_Logs(n0, "event=open raid_id="..n2.." kind="..k.." clan_slot=5 temper=cutter form=no_demand") == 1
			and S_Logs(n0, "module=raid event=demand") == 0, "TRF_RaidOn kind "..k..": the no-demand line ("..tostring(n2 and V_Rd(n2) and V_Rd(n2).st)..")");
		if n2 then TRF_Rd_End(n2, "cancel"); end;
	end;
	-- Beyond R_radio: no line, and none later for that raid.
	local id3 = TP_Trader("C");
	local ms0 = h.ms.pos;
	n0 = S_Mark();
	m0, s0 = TP_Marks();
	h.ms.pos = Vector3(ms0.x + 9000, ms0.y, ms0.z);
	local n3 = TRF_RaidOn({id3}, 2, "fq", 0);
	h.ms.pos = ms0;
	local hr3 = TRF_H().rd[n3];
	if hr3 then for j = 1, getn(hr3.sh) do hr3.sh[j].pos = Vector3(ms0.x + 60, ms0.y, ms0.z + 20 * j); end; end;
	local again = TRF_Te_Open(n3, V_Rd(n3), "n");
	HOST_Check(n3 and not TP_Has(TP_Said(m0, s0), "Red Knives here") and again == nil and TP_Logs(n0, "event=open raid_id="..n3.." distance=") == 1
		and TP_Logs(n0, "reason=range") == 1 and TP_Logs(n0, "reason=said") == 1, "beyond R_radio at the go: no line, none later (reason=range, then said)");
	if n3 then TRF_Rd_End(n3, "cancel"); end;
	-- A carrier wave at its meet (kind cr, a demand kind): the Cutter skips the demand there too.
	local n4 = TP_Raid("C");
	V_Rd(n4).kind = "cr"; V_Rd(n4).why = "carrier";
	n0 = S_Mark();
	TP_Meet(n4);
	HOST_Check(TP_Logs(n0, "event=open raid_id="..n4.." kind=carrier clan_slot=5 temper=cutter form=no_demand mode=full result=said") == 1
		and S_Logs(n0, "module=raid event=refuse raid_id="..n4) == 1, "a carrier wave at its meet: the opening line, no demand (Cutter)");
	TRF_Rd_End(n4, "cancel");
	-- Chapter 3: none; the built demand line.
	TP_Begin("valensia", "3");
	n = TP_Raid("C");
	m0, s0 = TP_Marks();
	n0 = S_Mark();
	TP_Meet(n);
	said = TP_Said(m0, s0);
	HOST_Check(said == TRF_Rd_Txt("demand", "Ash Vipers").."|" and TP_Logs(n0, "result=said") == 0 and TP_Logs(n0, "reason=chapter") == 1, "chapter 3: the built demand line ("..said..")");
	TRF_Rd_End(n, "cancel");
	-- Chapter 4 in a guard system (Gredos): lines only (the demand form, no clamps). The system runs vanilla in chapter
	-- 4 (no mod trader spawns there), so the raid is built in chapter 5 and the chapter set to 4 before the meet.
	TP_Begin("gredos", "5_1");
	n = TP_Raid("C");
	h.labels.CurrentQuest = "4_1";
	m0, s0 = TP_Marks();
	n0 = S_Mark();
	TP_Meet(n);
	said = TP_Said(m0, s0);
	local lo = TRF_Te_Comply(TRF_CurIdx(), V_Rd(n));
	HOST_Check(said == TRF_Txt("tehd", "Ash Vipers").."|" and TP_Logs(n0, "form=demand mode=lines result=said") == 1 and lo == nil
		and TRF_Te_LeaveHp(TRF_CurIdx(), V_Rd(n)) == nil, "chapter 4, guard system: the opening line, no comply clamps, no leave change");
	TRF_Rd_End(n, "cancel");
	-- A Cutter under the guard (Kadi marked as a start system for this run): it demands, with tecd.
	TP_Begin("kadi", "5_1");
	local kx = TRF_Map().sys[V_Idx("kadi")];
	n = TP_Raid("C");
	kx.start = 1;
	h.labels.CurrentQuest = "4_1";
	m0, s0 = TP_Marks();
	n0 = S_Mark();
	TP_Meet(n);
	said = TP_Said(m0, s0);
	HOST_Check(said == TRF_Txt("tecd", "Red Knives").."|" and S_Logs(n0, "module=raid event=demand raid_id="..n) == 1 and TRF_Te_Nd(n, V_Rd(n)) == nil
		and TRF_Te_LeaveHp(TRF_CurIdx(), V_Rd(n)) == nil, "chapter 4, guard: a Cutter demands with tecd, no leave change");
	TRF_Rd_End(n, "cancel");
	kx.start = nil;
	-- Chapter 4 outside the guard (Valensia): full.
	TP_Begin("valensia", "4_1");
	local c1, c2 = TRF_Te_Comply(TRF_CurIdx(), {why="lane"});
	HOST_Check(TRF_Te_Mode(TRF_CurIdx()) == 2 and c1 == 25 and c2 == 98, "chapter 4 outside the guard: full (the Haggler clamps)");
	-- A staged raid (Elio, Haggler): the no-demand line at the fight start.
	TP_Begin("elio", "5_1", {staged=1});
	local idx = TRF_CurIdx();
	TRF.live.ent = nil;
	TRF_SetDis(idx, 6);
	h.ms.pos = Vector3(-300, 30, 1500);
	TRF.live.cbt = nil;
	n0 = S_Mark();
	m0, s0 = TP_Marks();
	h.rq = {0, 0, 0};
	local pl = TRF_StagedRoll();
	h.rq = {};
	local sn = nil;
	for k = 1, 30 do
		T_Tick(1, 0.5);
		sn = TRF.live.nrd;
		if sn and V_Rd(sn) and V_Rd(sn).sg == 1 and V_Rd(sn).st == "fight" then break; end;
	end;
	HOST_Check(pl == 1 and sn and TP_Has(TP_Said(m0, s0), TRF_Txt("tehn", "Ash Vipers")) and TP_Logs(n0, "kind=staged clan_slot=3 temper=haggler form=no_demand mode=full result=said") == 1,
		"a staged raid: tehn at the fight start");
	h.st_label = nil;
end;

-- c: the behaviour rows (2.1, 5.2) -------------------------------------------------------------------

-- Raid n set to its fight state (the refuse of the decide).
function TP_Fight(n)
	TRF_Rd_Refuse(n, V_Rd(n), TRF_H().rd[n]);
end;

function T_TP_C()
	local h = HOST();
	h.st_label = "TRADE STATION";
	-- Cutter (Kadi, T3: built leave 0.4): no leave at 0.3 x hp0, leave at 0.2.
	TP_Begin("kadi", "5_1");
	local n, id, r, hr = TP_Raid("C");
	TP_Meet(n);
	local hp0 = V_Rd(n).hp0;
	hr.sh[1].hp = 0.3 * hp0;
	T_Tick(6, 0.5);
	local st1 = V_Rd(n).st;
	local n0 = S_Mark();
	hr.sh[1].hp = 0.2 * hp0;
	T_Tick(6, 0.5);
	HOST_Check(V_Rd(n).tier >= 2 and st1 == "fight" and S_Logs(n0, "module=raid event=leave raid_id="..n.." reason=hp") == 1 and TRF_Te_LeaveHp(TRF_CurIdx(), {why="lane"}) == 0.25,
		"Cutter: still fighting at 0.3 x hp0 (built T2+ leave 0.4), leaves at 0.2 (te_cut_hp 0.25)");
	TRF_Rd_End(n, "cancel");
	-- Haggler (Valensia): the comply clamps 25..98, the comply line, the leave at the first raid ship lost.
	TP_Begin("valensia", "5_1");
	HOST_Check(TRF_Rd_ComplyOf(10, 10, 1) == 5 and TRF_Rd_ComplyOf(10, 10, 1, 25, 98) == 25 and TRF_Rd_ComplyOf(1, 10, 0.01, 25, 98) == 98
		and TRF_Rd_ComplyOf(1, 10, 0.01) == 95, "TRF_Rd_ComplyOf: the built clamps 5..95 without lo, hi; the Haggler's 25..98");
	n, id, r, hr = TP_Raid("C");
	TP_Meet(n);
	r.br = 1; r.pw = 1000;
	local m0, s0 = TP_Marks();
	n0 = S_Mark();
	h.rq = {24};
	T_Tick(18, 0.5);
	h.rq = {};
	local said = TP_Said(m0, s0);
	HOST_Check(S_Logs(n0, "chance=25.000 roll=24 result=comply") == 1 and TP_Has(said, TRF_Txt("tehcp", TRF_Rd_Name(r), "Ash Vipers"))
		and not TP_Has(said, "Cargo released. Don't shoot."), "Haggler: a strong brave trader complies at 25 % (roll 24), the comply line names the clan");
	T_Tick(20, 0.5);
	n, id, r, hr = TP_Raid("C");
	TP_Meet(n);
	TP_Fight(n);
	n0 = S_Mark();
	hr.sh[2].alive = nil;
	HOST_Fire("died", "TRF_OnRaidDied("..n..",2,");
	HOST_Check(S_Logs(n0, "module=raid event=leave raid_id="..n.." reason=loss") == 1 and TRF_Rd_AliveN(hr) >= 1, "Haggler: the raid leaves at its first ship lost (reason loss) while ships live");
	TRF_Rd_End(n, "cancel");
	-- Planner (Golkonda): the chance weight on the formula branch only.
	TP_Begin("golkonda", "5_1");
	local cur = TRF_CurIdx();
	HOST_Check(TRF_Te_RollK(cur, {tier=3}) == 1.6 and TRF_Te_RollK(cur, {tier=1, cv=4}) == 1.6 and TRF_Te_RollK(cur, {tier=1}) == 0.7
		and TRF_Te_RollK(V_Idx("valensia"), {tier=3}) == 1, "Planner weight: 1.6 for tier 3 or a convoy member, 0.7 else; 1 in a Haggler system");
	id, r = TP_Trader("C");
	local k = 0.7;
	if (r.tier or 0) >= 3 or type(r.cv) == "number" then k = 1.6; end;
	n0 = S_Mark();
	TRF.live.cbt = nil;
	TP_EndRaids();
	h.rq = {9999};
	TRF_RaidRoll(id, "lane");
	V_NoRaid(id);
	h.rq = {9999};
	TRF_RaidRoll(id, "contract");
	V_NoRaid(id);
	h.cfg.tune = {raid_p=30};
	h.rq = {9999};
	TRF_RaidRoll(id, "lane");
	h.cfg.tune = {};
	h.rq = {};
	local p0 = TRF_Rd_RollPOf(TRF_Rd_BaseDanger(cur, TRF_Rd_DangerEff(cur)), TRF_Rd_Tier(cur), TRF_N("TRF_Attr", cur), r.fw);
	HOST_Check(S_Logs(n0, "source=lane danger_eff="..TRF_Rd_BaseDanger(cur, TRF_Rd_DangerEff(cur)).." tier="..TRF_Rd_Tier(cur).." chance="..TRF_F(p0 * k).." roll=9999 result=no_raid temper_k="..TRF_F(k)) == 1
		and S_Logs(n0, "source=contract") == 1 and S_Logs(n0, "chance=0.400 roll=9999 result=no_raid temper_k=1.000") == 1
		and S_Logs(n0, "chance=0.300 roll=9999 result=no_raid temper_k=1.000") == 1,
		"roll: the formula chance x "..k..", contract 0.4 and raid_p 0.3 unweighted");
	-- Planner call-off: not before a player shot or a loss; the player side only with ph; then tepoff once.
	local osps = TRF_SpPlayerSide;
	TRF_SpPlayerSide = function() return 1000, 5, 2; end;
	n, id, r, hr = TP_Raid("C");
	TP_Meet(n);
	TP_Fight(n);
	r.pw = 1;
	n0 = S_Mark();
	T_Tick(4, 0.5);
	local c0 = V_Rd(n).st;
	hr.sh[2].alive = nil;
	HOST_Fire("died", "TRF_OnRaidDied("..n..",2,");
	T_Tick(4, 0.5);
	local c1 = V_Rd(n).st;
	m0, s0 = TP_Marks();
	V_Rd(n).ph = 1;
	T_Tick(4, 0.5);
	said = TP_Said(m0, s0);
	HOST_Check(c0 == "fight" and c1 == "fight" and TP_Has(said, TRF_Txt("tepoff", "Grey Ravens"))
		and TP_Logs(n0, "event=calloff raid_id="..n.." trader_strength=") == 1 and TP_Logs(n0, "player_fired=true result=leave") == 1
		and S_Logs(n0, "module=raid event=leave raid_id="..n.." reason=calloff") == 1, "Planner: no call-off before a shot or loss, nor after a loss without the player side; with ph the call-off");
	T_Tick(4, 0.5);
	HOST_Check(TP_Logs(n0, "event=calloff") == 1, "the call-off once");
	TRF_Rd_End(n, "cancel");
	-- A strong trader after a loss calls the raid off without the player side.
	TRF_SpPlayerSide = function() return 0, 0, 0; end;
	n, id, r, hr = TP_Raid("C");
	TP_Meet(n);
	TP_Fight(n);
	r.pw = 1000;
	n0 = S_Mark();
	T_Tick(4, 0.5);
	c0 = V_Rd(n).st;
	hr.sh[2].alive = nil;
	HOST_Fire("died", "TRF_OnRaidDied("..n..",2,");
	T_Tick(4, 0.5);
	HOST_Check(c0 == "fight" and TP_Logs(n0, "event=calloff raid_id="..n.." trader_strength=") == 1 and TP_Logs(n0, "player_fired=false") == 1,
		"Planner: a strong trader after a loss: the call-off without a player shot");
	TRF_Rd_End(n, "cancel");
	-- Under a live escort contract near the mothership TRF_Rd_HailRatio counts the player side; ph adds it no second time.
	local orps = TRF_Rd_PlayerSide;
	TRF_Rd_PlayerSide = function() return 1; end;
	n, id, r, hr = TP_Raid("C");
	TP_Meet(n);
	TP_Fight(n);
	r.pw = 1;
	local st, sr = TRF_Rd_HailRatio(n);
	TRF_SpPlayerSide = function() return %sr, 5, 2; end;
	n0 = S_Mark();
	V_Rd(n).ph = 1;
	T_Tick(4, 0.5);
	local c2 = TP_Logs(n0, "event=calloff");
	TRF_Rd_PlayerSide = function() return 0; end;
	T_Tick(4, 0.5);
	TRF_Rd_PlayerSide = orps;
	HOST_Check(st < sr and c2 == 0 and TP_Logs(n0, "event=calloff raid_id="..n.." trader_strength=") == 1,
		"Planner: the player side counted once (in TRF_Rd_HailRatio under a live contract), the call-off once it is not");
	TRF_Rd_End(n, "cancel");
	TRF_SpPlayerSide = osps;
	-- Ghost (Taira): leave at 0.7 x hp0.
	TP_Begin("taira", "5_1");
	n, id, r, hr = TP_Raid("C");
	TP_Meet(n);
	TP_Fight(n);
	hp0 = V_Rd(n).hp0;
	hr.sh[1].hp = 0.75 * hp0;
	T_Tick(4, 0.5);
	st1 = V_Rd(n).st;
	n0 = S_Mark();
	hr.sh[1].hp = 0.65 * hp0;
	T_Tick(4, 0.5);
	HOST_Check(st1 == "fight" and S_Logs(n0, "module=raid event=leave raid_id="..n.." reason=hp") == 1, "Ghost: fights at 0.75, leaves at 0.65 x hp0 (te_gh_hp 0.7)");
	TRF_Rd_End(n, "cancel");
	-- The tier arrival line: the Ghost word in Taira, unchanged in Valensia.
	local w = {"pirw1", "pirw2", "packs", "raiders"};
	local ti, tv = TRF_CurIdx(), V_Idx("valensia");
	local ta = TRF_UI_ArrDis(ti, 1);
	local va = TRF_UI_ArrDis(tv, 1);
	HOST_Check(TP_Has(ta, TRF_Txt(w[TRF_EffTier(ti)]).." and unidentified contacts") and not TP_Has(va, "unidentified"),
		"arrival line: '"..ta.."' in a Ghost system, '"..va.."' elsewhere");
	TRF.clan[TRF_RgOf(ti)].sc = 30;
	HOST_Check(TP_Has(TRF_UI_ArrDis(ti, 1), "pirate gangs and unidentified contacts") or TRF_EffTier(ti) ~= 2, "tier 2: 'pirate gangs and unidentified contacts'");
	-- The kept kinds (T6): stn and wq keep the built leave, comply and demand; a captain's raid everything.
	TP_Begin("kadi", "5_1");
	cur = TRF_CurIdx();
	local bad = "";
	local recs = {{why="stn"}, {why="wq"}, {why="staged", cap=5}, {why="lane", cap=5}};
	for i = 1, getn(recs) do
		local rd = recs[i];
		if TRF_Te_Row(cur, rd) or TRF_Te_Nd(1, rd) or TRF_Te_LeaveHp(cur, rd) or TRF_Te_Comply(cur, rd) or TRF_Te_LossLeave(1, rd) then bad = bad.." "..rd.why; end;
	end;
	HOST_Check(bad == "" and TRF_Te_Row(cur, {why="lane"}).k == 1, "stn, wq and captain raids: no behaviour row (lane: the Cutter row)"..bad);
	id = TP_Trader("C");
	local n5 = TRF_RaidOn({id}, 2, "stn", 0);
	if n5 and V_Rd(n5).st == "armed" then HOST_Fire("f_inside", "TRF_RaidGo("..n5..","); end;
	local hr5 = TRF_H().rd[n5];
	for j = 1, getn(hr5.sh) do hr5.sh[j].pos = Vector3(h.ms.pos.x + 60, h.ms.pos.y, h.ms.pos.z + 20 * j); end;
	TP_Meet(n5);
	hp0 = V_Rd(n5).hp0;
	n0 = S_Mark();
	hr5.sh[1].hp = 0.3 * hp0;
	T_Tick(4, 0.5);
	HOST_Check(S_Logs(n0, "module=raid event=leave raid_id="..n5.." reason=hp") == 1, "stn raid in a Cutter region: the built leave HP (0.3 x hp0 leaves)");
	TRF_Rd_End(n5, "cancel");
	h.st_label = nil;
end;

-- d: the Ghost decloak (T11, 5.2) ---------------------------------------------------------------------

-- Counts Portal:Start calls of the scene's portal objects in HOST().pst.
function TP_PortalCount()
	local h = HOST();
	h.pst = 0;
	for k, o in h.objs do
		if type(o) == "table" and type(k) == "string" and strfind(k, "PORTAL", 1, 1) and not o.pst0 then
			o.pst0 = o.Start;
			o.Start = function(self, a, b) HOST().pst = HOST().pst + 1; return self.pst0(self, a, b); end;
		end;
	end;
end;

-- An armed lane raid on a fresh trader next to the mothership: raid id, trader id.
function TP_Armed()
	TP_EndRaids();
	local id = TP_Trader("C");
	local n = V_Raid(id);
	return n, id;
end;

function T_TP_D()
	local h = HOST();
	h.st_label = "TRADE STATION";
	TP_Begin("taira", "5_1", {tune={te_fx=1}});
	local cur = TRF_CurIdx();
	TP_PortalCount();
	local n, id = TP_Armed();
	h.pst = 0;
	local n0 = S_Mark();
	HOST_Fire("f_inside", "TRF_RaidGo("..n..",");
	local hr = TRF_H().rd[n];
	local lp = TRF_GnLead(id):GetPosition();
	local rp = hr.sh[1].pos;
	local d = HOST_Dist(rp, lp);
	local dm = HOST_Dist(rp, h.ms.pos);
	local fx = 0;
	for j = 1, getn(hr.sh) do if hr.sh[j].fx == "Cloak Out.shfx" then fx = fx + 1; end; end;
	local sy = TRF_Map().sys[cur];
	local stok = 1;
	for i = 1, getn(sy.st or {}) do
		local e = sy.st[i];
		if type(e.x) == "number" and HOST_Dist(rp, Vector3(e.x, e.y, e.z)) < 400 then stok = nil; end;
	end;
	HOST_Check(d >= 399 and d <= 601 and dm >= 300 and stok and fx == getn(hr.sh) and h.pst == 0
		and S_Logs(n0, "module=raid event=go raid_id="..n.." trader_id="..id.." via=decloak") == 1
		and TP_Logs(n0, "event=decloak raid_id="..n.." distance=") == 1 and TP_Logs(n0, "fx_count="..getn(hr.sh).." result=placed") == 1,
		"te_fx 1: spawned "..floor(d).." from the lead, "..floor(dm).." from the mothership, Cloak Out.shfx on "..fx.." ships, via=decloak, no portal glow");
	-- Pure: the point 400-600 from the lead; every direction blocked gives nil.
	local p1 = TRF_TeGhostOf({x=0, y=0, z=0}, 500, 1, nil, 400, {x=500, y=0, z=0}, 300);
	HOST_Check(p1 and abs(p1.x - 353.55) < 0.01 and abs(p1.z - 353.55) < 0.01 and p1.y == 0,
		"TRF_TeGhostOf: the first direction (on the mothership) skipped, the next one (45 degrees) taken");
	-- In the game a position is userdata: the lead and mothership positions are taken as such (type() answers "userdata"
	-- for the host's Vector3 here).
	n, id = TP_Armed();
	local ot = type;
	type = function(v) if tag(v) == HOST().vtag then return "userdata"; end; return %ot(v); end;
	local pu = TRF_TeGhostOf(Vector3(0, 0, 0), 500, 1, nil, 400, Vector3(500, 0, 0), 300);
	local gu = TRF_Te_GhostPos(n, TRF_Rd_Live().rd[n], TRF_GnLead(id));
	type = ot;
	HOST_Check(pu and abs(pu.x - 353.55) < 0.01 and gu and HOST_Dist(gu, TRF_GnLead(id):GetPosition()) >= 399 and HOST_Dist(gu, h.ms.pos) >= 300,
		"userdata positions: the mothership rule applies and the decloak point is found");
	-- Every direction blocked: event=decloak result=none reason=no_point, the built spawn.
	n, id = TP_Armed();
	local pok = TRF_Rd_PointOk;
	TRF_Rd_PointOk = function() return nil; end;
	n0 = S_Mark();
	h.pst = 0;
	HOST_Fire("f_inside", "TRF_RaidGo("..n..",");
	TRF_Rd_PointOk = pok;
	hr = TRF_H().rd[n];
	fx = 0;
	for j = 1, getn(hr.sh) do if hr.sh[j].fx then fx = fx + 1; end; end;
	HOST_Check(TP_Logs(n0, "event=decloak raid_id="..n.." distance=") == 1 and TP_Logs(n0, "result=none reason=no_point") == 1 and fx == 0
		and S_Logs(n0, "via=decloak") == 0 and S_Logs(n0, "module=raid event=go raid_id="..n) == 1, "no decloak point: the built spawn, no PlayFX");
	-- A base raid keeps the base position.
	n, id = TP_Armed();
	local bh, bp = TRF_Rd_BaseHere, TRF_BaseRaidPos;
	TRF_Rd_BaseHere = function() return 1; end;
	TRF_BaseRaidPos = function(c, p) return Vector3(p.x + 100, p.y, p.z); end;
	n0 = S_Mark();
	HOST_Fire("f_inside", "TRF_RaidGo("..n..",");
	TRF_Rd_BaseHere, TRF_BaseRaidPos = bh, bp;
	HOST_Check(S_Logs(n0, "module=raid event=go raid_id="..n.." trader_id="..id.." via=base") == 1 and TP_Logs(n0, "event=decloak") == 0, "a base raid: the base position, no decloak");
	TP_EndRaids();
	-- te_fx 0 (the default): the built spawn, no PlayFX.
	h.cfg.tune = {};
	n, id = TP_Armed();
	n0 = S_Mark();
	HOST_Fire("f_inside", "TRF_RaidGo("..n..",");
	hr = TRF_H().rd[n];
	fx = 0;
	for j = 1, getn(hr.sh) do if hr.sh[j].fx then fx = fx + 1; end; end;
	HOST_Check(fx == 0 and S_Logs(n0, "via=decloak") == 0 and TP_Logs(n0, "event=decloak raid_id="..n.." result=none reason=fx_off") == 1,
		"te_fx 0: the built spawn, no PlayFX (reason=fx_off at log 2)");
	TP_EndRaids();
	-- A Planner lane raid with te_fx 1: no decloak.
	TP_Begin("golkonda", "5_1", {tune={te_fx=1}});
	n, id = TP_Armed();
	n0 = S_Mark();
	HOST_Fire("f_inside", "TRF_RaidGo("..n..",");
	HOST_Check(S_Logs(n0, "via=decloak") == 0 and TP_Logs(n0, "event=decloak") == 0, "te_fx 1 in a Planner region: the built spawn");
	TP_EndRaids();
	h.st_label = nil;
end;

-- e: the 200-leg check (P 2b.7, T9) ------------------------------------------------------------------

-- Pure: trader tier of a spawn by the pro rule (pro 0-2 T1, 3-5 T2, 6-8 T3, 9 T4; the v02 9.2 bands).
function TP_TierOf(pro)
	if pro >= 9 then return 4; end;
	if pro >= 6 then return 3; end;
	if pro >= 3 then return 2; end;
	return 1;
end;

-- 200 legs with a per-leg on-screen raid model (V_Run200 of host_v02.lua plus the raids): in each region's
-- highest-pro system 4 trader rolls a leg; the formula chance (TRF_Rd_RollPOf) times TRF_Te_RollK; the decide with
-- TRF_Rd_ComplyOf at braveness 0.6 and ratio 1 and the temperament clamps (Cutters always refuse); comply: clan +1
-- (rob), dis +1; refuse: dis +1, and the trader killed at 20 % (Cutters 35 %): dis +2, pro -1. temper 0 or 1, same seed.
-- Returns the cycle record of V_Run200 plus per slot raids (rn), legs in Raids (lr) and Raids entries (er).
function TP_Model(temper, label)
	local h = HOST();
	h.labels.CurrentQuest = "5_1";
	h.cfg.temper = temper;
	h.seed = tonumber(getenv("TRF_SEED") or "") or 1;
	TRF = nil;
	TRF_State_OnEnter(1);
	local m = TRF_RgMap();
	local n = m.n;
	local R = {miss=0, maxhi=0, lenbad=0, lenmsg="", frozen=0, gap=0, rn={}, lr={}, er={}, kills={}};
	local hold = TRF_RgTune().rg_hold;
	local hi, last, start, gxs, vis = {}, {}, {}, {}, {};
	for s = 1, n do
		hi[s] = 0; last[s] = TRF_Phase(s); start[s] = nil; gxs[s] = TRF.rg[s].gx;
		R.rn[s] = 0; R.lr[s] = 0; R.er[s] = 0; R.kills[s] = 0;
		vis[s] = {};
		for p = 0, 5 do vis[s][p] = TRF.clock.legs; end;
	end;
	for leg = 1, 200 do
		TRF_AddLeg("test");
		for s = 1, n do
			local top, tp = nil, -1;
			local ss = m[s].sys;
			for i = 1, getn(ss) do if TRF_Pro(ss[i]) > tp then top = ss[i]; tp = TRF_Pro(ss[i]); end; end;
			for t = 1, 4 do
				local tr = {tier=TP_TierOf(TRF_Pro(top))};
				local dE = TRF_Rd_DangerEff(top);
				local attr = TRF_N("TRF_Attr", top);
				local p = TRF_Rd_RollPOf(dE, TRF_Rd_Tier(top), attr, nil) * TRF_Te_RollK(top, tr);
				if TRF_Rand(10000) < p * 10000 then
					R.rn[s] = R.rn[s] + 1;
					local row = TRF_Te_Row(top, {why="lane"});
					local lo, hi2 = nil, nil;
					if row then lo = row.cmin; hi2 = row.cmax; end;
					local cp = TRF_Rd_ComplyOf(1, 1, 0.6, lo, hi2);
					if not (row and row.nd == 1) and TRF_Rand(100) < cp then
						TRF_ClanAdd(s, 1, "rob");
						TRF_AddDis(top, 1, "model");
					else
						TRF_AddDis(top, 1, "model");
						local kp = 20;
						if row and row.nd == 1 then kp = 35; end;
						if TRF_Rand(100) < kp then TRF_AddDis(top, 2, "model"); TRF_ProAdd(top, -1, "model"); R.kills[s] = R.kills[s] + 1; end;
					end;
				end;
			end;
		end;
		local nb, nur, nxv = 0, 0, 0;
		for s = 1, n do
			local ph = TRF_Phase(s);
			if ph == 1 then nb = nb + 1; end;
			if ph == 2 or ph == 3 then nur = nur + 1; end;
			if ph == 4 or ph == 5 then nxv = nxv + 1; end;
			if ph == 3 then R.lr[s] = R.lr[s] + 1; end;
			if TRF_ClanScore(s) >= 75 then hi[s] = hi[s] + 1; else hi[s] = 0; end;
			if hi[s] > R.maxhi then R.maxhi = hi[s]; end;
			if ph ~= last[s] then
				if ph == 3 then R.er[s] = R.er[s] + 1; end;
				if start[s] then
					local len = TRF.rg[s].pt - start[s];
					local mn, mx = TRF_RgLen(s, last[s], gxs[s], TRF_RgTune());
					if len < mn or len > mx + hold then
						R.lenbad = R.lenbad + 1;
						R.lenmsg = R.lenmsg.." s"..s.."p"..last[s].."="..len.."("..mn..".."..mx.."+"..hold..")";
					end;
				end;
				start[s] = TRF.rg[s].pt;
				gxs[s] = TRF.rg[s].gx;
				last[s] = ph;
			end;
			local mn, mx = TRF_RgLen(s, ph, TRF.rg[s].gx, TRF_RgTune());
			if TRF.clock.legs - TRF.rg[s].pt > mx + 10 then R.frozen = R.frozen + 1; end;
			vis[s][ph] = TRF.clock.legs;
			for p = 0, 5 do
				if TRF.clock.legs - vis[s][p] > R.gap then R.gap = TRF.clock.legs - vis[s][p]; end;
			end;
		end;
		if nb == 0 or nur == 0 or nxv == 0 then R.miss = R.miss + 1; end;
	end;
	local line = "";
	for s = 1, n do
		local k = TRF_Te_Of(s);
		line = line..format(" s%d(%s) raids=%d raids_legs=%d entries=%d kills=%d", s, TRF_TeK().name[k], R.rn[s], R.lr[s], R.er[s], R.kills[s]);
	end;
	print(format("HOST %s: miss %d maxhi %d frozen %d gap %d lenbad %d;%s", label, R.miss, R.maxhi, R.frozen, R.gap, R.lenbad, line));
	h.cfg.temper = nil;
	return R;
end;

function T_TP_E()
	local h = HOST();
	TP_Begin("gredos", "5_1", {log=1});
	h.logs = nil;
	local F = TP_Model(0, "tp-e flat");
	local P = TP_Model(1, "tp-e temper");
	h.logs = {};
	HOST_Check(P.lenbad == 0 and P.frozen == 0 and P.miss <= 4 and P.gap <= 120 and P.maxhi <= 18,
		"temper run: the v02-b cycle criteria (lengths, nothing frozen, miss "..P.miss.." <= 4, gap "..P.gap.." <= 120, sc >= 75 run "..P.maxhi.." <= 18)"..P.lenmsg);
	local bad = "";
	for s = 1, TRF_RgMap().n do if P.er[s] < 2 then bad = bad.." s"..s.."="..P.er[s]; end; end;
	HOST_Check(bad == "", "temper run: every slot enters Raids at least twice"..bad);
	bad = "";
	for s = 1, TRF_RgMap().n do
		if TRF_Te_Of(s) == 3 then
			local sh = abs(P.lr[s] - F.lr[s]) / 200;
			local q = P.rn[s] / max(F.rn[s], 1);
			print(format("HOST info tp-e planner slot %d: Raids share %.3f vs %.3f (diff %.3f), raids %d vs %d (ratio %.2f)", s, P.lr[s] / 200, F.lr[s] / 200, sh, P.rn[s], F.rn[s], q));
			if sh > 0.05 or q < 0.8 or q > 1.2 then bad = bad..format(" s%d:share_diff=%.3f,ratio=%.2f", s, sh, q); end;
		end;
	end;
	HOST_Check(bad == "", "Planner slots: Raids share within 0.05 and raids per leg within 0.8..1.2 of the flat run"..bad);
end;

-- f: the signals (T14, 5.3, 6.6) -------------------------------------------------------------------------

-- The nearest system (BFS, depth 1 first) of idx with a clan temperament, or nil; every other system of the BFS at dis 0.
function TP_Near(idx, k)
	local l = TRF_HlBfs(idx, 3);
	local f = nil;
	for i = 1, getn(l) do
		TRF_SetDis(l[i].i, 0);
		if not f and TRF_Te_Of(TRF_RgOf(l[i].i)) and (not k or TRF_Te_Of(TRF_RgOf(l[i].i)) == k) then f = l[i].i; end;
	end;
	return f;
end;

function T_TP_F()
	local h = HOST();
	-- The hail trouble page: the word for listed systems of a clan (ungated), none for an independent system, none in
	-- chapter 3; the harbour news (no tw) unchanged.
	TP_Begin("gredos", "5_1", {te_quest=0});
	local gi = TP_Near(TRF_CurIdx(), 2);
	TRF_SetDis(gi, 3);
	local t1 = TRF_Trouble(TRF_CurIdx(), 1);
	local t0 = TRF_Trouble(TRF_CurIdx());
	local it = TRF_Txt("tritem", TRF_HlSysName(gi), TRF_Txt("tews", TRF_HlSevWord(gi), "talk first"));
	HOST_Check(TP_Has(t1, it) and not TP_Has(t0, "talk first") and TP_Has(t0, TRF_Txt("tritem", TRF_HlSysName(gi), TRF_HlSevWord(gi))),
		"trouble page: '"..t1.."'; without tw (harbour news) '"..t0.."'");
	local ind = nil;
	for i = 1, getn(TRF_Map().sys) do if not TRF_RgOf(i) then ind = i; break; end; end;
	HOST_Check(TRF_HlSevWord(ind, 1) == TRF_HlSevWord(ind), "an independent system: no word");
	h.labels.CurrentQuest = "3";
	HOST_Check(not TP_Has(TRF_Trouble(TRF_CurIdx(), 1), "talk first"), "chapter 3: no word");
	h.labels.CurrentQuest = "4_1";
	HOST_Check(TP_Has(TRF_Trouble(TRF_CurIdx(), 1), "talk first") or TRF_Map().sys[gi].start ~= 1, "chapter 4 in a guard system: the word (lines only)");
	h.labels.CurrentQuest = "5_1";
	-- The patrol board (Taira, MSF): no words without the Clan file of MSF; with its reward bit the words; another
	-- faction's dock (Proserpina, NESF): none; te_gate 0: words everywhere.
	TP_Begin("taira", "5_1", {te_quest=0});
	local ti = TP_Near(TRF_CurIdx(), nil);
	TRF_SetDis(ti, 3);
	local tw = TRF_Te_Word(ti);
	local n0 = S_Mark();
	local r = TP_PatDock();
	local wl = TRF_Txt("tritem", TRF_HlSysName(ti), TRF_Txt("tews", TRF_HlSevWord(ti), tw));
	HOST_Check(TP_Has(r.scr, TRF_Txt("tritem", TRF_HlSysName(ti), TRF_HlSevWord(ti))) and not TP_Has(r.scr, tw)
		and TP_Logs(n0, "event=board faction=1 result=gate") >= 1, "patrol board without the reward: no words ("..r.scr..")");
	TRF.iq = {a=0, d=1, r=1};
	TP_Visit();
	n0 = S_Mark();
	r = TP_PatDock();
	HOST_Check(TP_Has(r.scr, wl) and TP_Logs(n0, "event=board faction=1 result=words") >= 1, "with MSF's reward bit: the words ("..r.scr..")");
	T_Jump("proserpina");
	local pi = TP_Near(TRF_CurIdx(), nil);
	TRF_SetDis(pi, 3);
	local pw = TRF_Te_Word(pi);
	n0 = S_Mark();
	r = TP_PatDock();
	HOST_Check(TP_Has(r.scr, TRF_HlSysName(pi)) and not TP_Has(r.scr, ", "..pw..")") and TP_Logs(n0, "event=board faction=2 result=gate") >= 1,
		"NESF's dock: no words (MSF's bit only)");
	h.cfg.te_gate = 0;
	TP_Visit();
	r = TP_PatDock();
	h.cfg.te_gate = nil;
	HOST_Check(TP_Has(r.scr, TRF_Txt("tews", TRF_HlSevWord(pi), pw)), "te_gate 0: the words at every patrol board ("..r.scr..")");
	-- The dockmaster tip (Valensia, rung 4): none before an opening line of the Ash Vipers in the visit, then kind temper;
	-- the built supply-run tip first; none after a jump.
	TP_Begin("valensia", "5_1", {te_quest=0});
	local vi = TRF_CurIdx();
	local k = S_Key();
	TRF.stn[k] = {st=4, lg=TRF.clock.legs};
	S_NewVisit();
	local D = S_Setup({});
	n0 = S_Mark();
	r = S_Trade(D.trade[1]);
	if r.nb > 0 then HOST_Press("cancel"); end;
	local tip = TRF_Txt("tetip2", "Ash Vipers");
	HOST_Check(not TP_Has(r.scr, tip) and S_Logs(n0, "kind=temper") == 0, "no tip before a raid of that clan in the visit");
	HOST_Check(TRF_Te_Open(901, {why="lane"}, "d") == TRF_Txt("tehd", "Ash Vipers") and TRF_TeSH().v.rs[3] == 1, "an opening line marks the clan's raid in the visit");
	S_NewVisit();
	D = S_Setup({});
	n0 = S_Mark();
	r = S_Trade(D.trade[1]);
	if r.nb > 0 then HOST_Press("cancel"); end;
	HOST_Check(TP_Has(r.scr, tip) and S_Logs(n0, "module=station event=tip station_key="..k.." kind=temper system=valensia") == 1,
		"after the opening line: the tip of kind temper ("..r.scr..")");
	TRF.feq = {k=1, f=1, s=vi, r=1, t=TRF.clock.legs};
	S_NewVisit();
	D = S_Setup({});
	n0 = S_Mark();
	r = S_Trade(D.trade[1]);
	if r.nb > 0 then HOST_Press("cancel"); end;
	TRF.feq = nil;
	HOST_Check(not TP_Has(r.scr, tip) and S_Logs(n0, "kind=feq") == 1, "the supply-run tip comes first");
	T_Jump("kassilia");
	T_Jump("valensia");
	TRF.stn[k] = {st=4, lg=TRF.clock.legs};
	S_NewVisit();
	D = S_Setup({});
	n0 = S_Mark();
	r = S_Trade(D.trade[1]);
	if r.nb > 0 then HOST_Press("cancel"); end;
	HOST_Check(not TP_Has(r.scr, tip) and S_Logs(n0, "kind=temper") == 0, "after a jump: no tip");
	-- The news bulletin: the lane raid text gains the suffix (mode >= 1 in the home system); other topics and chapter 3
	-- none; news_mode 2 posts the static record.
	local nt = TRF_UI_NewsText("lane", "raid", 3);
	HOST_Check(TP_Has(nt, ". The Ash Vipers talk first.") and not TP_Has(TRF_UI_NewsText("lane", "quiet", 3), "talk first")
		and TP_Has(TRF_UI_NewsText("lane", "raid", 5), ". The Red Knives don't talk, they shoot."), "news bulletin: '"..nt.."'");
	h.labels.CurrentQuest = "3";
	HOST_Check(not TP_Has(TRF_UI_NewsText("lane", "raid", 3), "talk first"), "chapter 3: the bulletin without the suffix");
	h.labels.CurrentQuest = "5_1";
	h.cfg.news_mode = 2;
	h.posts = {};
	TRF_NewsPost("lane", "raid", 3);
	h.cfg.news_mode = nil;
	HOST_Check(h.posts[getn(h.posts)] == "+trf_r3_lane_raid", "news_mode 2: the static record trf_r3_lane_raid (unchanged)");
end;

-- g: the offer (4.3, 6.1, 6.9) ---------------------------------------------------------------------------

function TP_GCfg(t)
	local c = {te_dialog=1, hail_xml=1, news_mode=2};
	if t then for k, v in t do c[k] = v; end; end;
	return c;
end;

function T_TP_G()
	local h = HOST();
	TP_Begin("taira", "5_1");
	local cur = TRF_CurIdx();
	local f = TRF_TeDockFac();
	_param = nil;
	HOST_Check(f == 1 and TRF_TeOfferWhy(cur, 1) == nil, "Taira (MSF patrol, Black Comets T3, chapter 5): the offer is due");
	-- Every gate reason (4.3).
	local ind = nil;
	for i = 1, getn(TRF_Map().sys) do if not TRF_RgOf(i) then ind = i; break; end; end;
	local osk = TRF_StrictOk;
	local gates = {
		{"chapter", function() HOST().labels.CurrentQuest = "4_1"; end}, {"chapter_end", function() HOST().labels.CurrentQuest = "21"; end},
		{"mission", function() V_QuestOn(); end}, {"nk", nil, V_Idx("nk"), 2}, {"owner", nil, cur, "none"},
		{"war", function() TP_Rel("Vks", RELATION_WAR); end}, {"region", nil, ind, 1},
		{"tier", function() TRF.clan[2].sc = 5; end}, {"tier", function() HOST().cfg.tier_cap = 1; end},
		{"busy", function() TRF_IqTake(2, 0, 1); end}, {"done", function() TRF.iq = {a=0, d=1, r=1}; end},
		{"declined", function() TRF_IqDecline(1); end}, {"declined", function() TRF_TeSH().v.dec = 1; end},
		{"strict:deny_temper", function() TRF_StrictOk = function(i, ft) if ft == "temper" then return nil, "deny_temper"; end; return 1; end; end},
		{"off", function() HOST().cfg.te_quest = 0; end}, {"off", function() HOST().cfg.temper = 0; end}};
	local bad = "";
	for i = 1, getn(gates) do
		local g = gates[i];
		if g[2] then g[2](); end;
		local at, ff = g[3] or cur, g[4] or 1;
		if ff == "none" then ff = nil; end;
		local why = TRF_TeOfferWhy(at, ff);
		if why ~= g[1] then bad = bad.." "..g[1].."->"..tostring(why); end;
		h.labels.CurrentQuest = "5_1"; V_QuestOff(); h.rel_team = nil; TRF.clan[2].sc = 60; h.cfg.tier_cap = nil; TRF.iq = nil;
		TRF_TeSH().v.dec = nil; TRF_StrictOk = osk; h.cfg.te_quest = nil; h.cfg.temper = nil;
	end;
	HOST_Check(bad == "", "offer gates: chapter 4 and 21, a mission, New Kyoto, no faction owner, war, an independent system, tier 1 and tier_cap 1, another intro quest, the faction done, the decline wait and the visit flag, the strict gate, te_quest 0, temper 0"..bad);
	-- A scene: no box and no log line.
	local oq = TRF_Quiet;
	TRF_Quiet = function() return 1; end;
	local n0 = S_Mark();
	local qb = TRF_Te_DockBox("patrol");
	TRF_Quiet = oq;
	HOST_Check(qb == nil and TP_Logs(n0, "event=offer") == 0, "TRF_Quiet: no box, no log line");
	-- Registrations: patrol box 350 between the board 400 and the ladder 300, talk box 455, line 47; no Office row.
	local P = TRF_PlReg();
	local bo, lo = "", "";
	for i = 1, getn(P.dock.patrol.box) do bo = bo..P.dock.patrol.box[i].o..":"..TRF_PlName(P.dock.patrol.box[i].f)..","; end;
	for i = 1, getn(P.dock.patrol.line) do lo = lo..P.dock.patrol.line[i].o..","; end;
	HOST_Check(TP_Has(bo, "460:TRF_Wq_TalkBox,455:TRF_Te_TalkBox,400:TRF_BoardOfBox,350:TRF_Te_DockBox,300:") and TP_Has(lo, "45,47,50,")
		and getn(P.dock.patrol.row) == 0, "patrol boxes "..bo.." lines "..lo..", no patrol Office row");
	-- The board offer wins; the next docking shows the Clan file.
	local ob = TRF_BoardOfBox;
	TRF_BoardOfBox = function(k) return {text="BOARD OFFER", own="board_test"}; end;
	n0 = S_Mark();
	local r = TP_PatDock();
	TRF_BoardOfBox = ob;
	if r.nb > 0 then HOST_Press("cancel", r.box); end;
	HOST_Check(r.nb == 1 and r.box.text == "BOARD OFFER" and TP_Logs(n0, "event=offer") == 0, "a board offer at 400 wins: no Clan file");
	TP_Visit();
	n0 = S_Mark();
	r = TP_PatDock();
	local btext = TRF_Txt("tebox", "Black Comets", "Elinor", "MSF");
	HOST_Check(r.nb == 1 and r.box.text == btext and r.box.title == "#UI_PatrolStationWndCaption"
		and TP_Logs(n0, "event=offer system=taira faction=1 clan_slot=2 result=shown via=box") == 1
		and S_Logs(n0, "module=plumb event=dock kind=patrol") >= 1, "the next docking: box 350 ("..tostring(r.box and r.box.text)..")");
	-- OK: the record, the logbook (mission list), the reply.
	local L = TRF.clock.legs;
	n0 = S_Mark();
	local s0 = getn(h.screen);
	HOST_Press("ok", r.box);
	local I = TRF_IqGet();
	HOST_Check(I.q == 1 and I.s == 1 and I.t == 21 and I.c == 0 and I.l == L and h.quests.trf_te == QUEST_PROCESS and h.qlog.trf_te.t == "#TRF_tet"
		and h.qlog.trf_te.d == "#TRF_ted10s2" and TP_Has(TP_Said(nil, s0), TRF_Txt("teok")) and TP_Logs(n0, "event=accept system=taira faction=1 clan_slot=2 seed=") == 1
		and TP_Logs(n0, "event=logbook list=mission id=trf_te text=#TRF_ted10s2 result=added") == 1, "OK: quest 1 at step 10, target 21, the entry #TRF_ted10s2, teok");
	-- Cancel: the decline stamp, none again in the visit, nor within te_dc legs.
	TP_Begin("taira", "5_1");
	r = TP_PatDock();
	n0 = S_Mark();
	HOST_Press("cancel", r.box);
	L = TRF.clock.legs;
	HOST_Check(TRF.iq and TRF.iq.l == L * 10 + 1 and TRF_IqGet().q == 0 and TP_Logs(n0, "event=decline system=taira faction=1 leg="..L.." result=declined") == 1, "Cancel: l = legs x 10 + 1");
	n0 = S_Mark();
	r = TP_PatDock();
	if r.nb > 0 then HOST_Press("cancel", r.box); end;
	HOST_Check(r.nb == 0 and TP_Logs(n0, "reason=declined") == 1, "declined: none again in the visit");
	TP_Visit();
	TRF.clock.legs = L + 1;
	HOST_Check(TRF_TeOfferWhy(cur, 1) == "declined", "declined: none within te_dc 2 legs");
	TRF.clock.legs = L + 2;
	HOST_Check(TRF_TeOfferWhy(cur, 1) == nil, "after 2 legs: due again");
	-- The Job log (jobs_log 1 with the natives): the entry there and the telog line.
	TP_Begin("taira", "5_1", {jobs_log=1}, nil, 1);
	r = TP_PatDock();
	s0 = getn(h.screen);
	HOST_Press("ok", r.box);
	HOST_Check(HOST_JlFind("trf_te") and h.jl[HOST_JlFind("trf_te")].d == "#TRF_ted10s2" and h.qlog.trf_te == nil and TP_Has(TP_Said(nil, s0), TRF_Txt("telog")),
		"jobs_log 1: the entry in the Job log, the telog line");
	-- The card (jobs_ui 1): id te, header Clan file, title Patrol office; OK accepts.
	TP_Begin("taira", "5_1", {jobs_ui=1});
	TRF_MissionCard = HOST_MissionCard;
	n0 = S_Mark();
	r = TP_PatDock();
	local c = h.jc[1];
	HOST_Check(r.nb == 0 and c and c.id == "te" and c.header == "Clan file" and c.title == "Patrol office" and c.text == btext and c.cost == nil
		and S_Logs(n0, "box=te priority=350 result=card") == 1, "card: id te, header, title, the box text");
	HOST_Check(HOST_JobTick() == "open" and TP_Logs(n0, "result=shown via=card") == 1, "card open: the offer line via=card");
	HOST_JobPress("ok");
	HOST_JobTick();
	HOST_Check(TRF_IqGet().q == 1, "card OK: accepted");
	-- The card's Esc: nothing (no decline stamp, no visit flag); the next docking offers again.
	TP_Begin("taira", "5_1", {jobs_ui=1});
	TRF_MissionCard = HOST_MissionCard;
	n0 = S_Mark();
	r = TP_PatDock();
	HOST_JobTick();
	HOST_JobPress("esc");
	HOST_JobTick();
	HOST_Check(TRF_IqGet().q == 0 and TRF_IqWait(1, 9) == nil and TRF_TeOfferWhy(cur, 1) == nil
		and TP_Logs(n0, "event=decline system=taira faction=1 result=closed") == 1 and TP_Logs(n0, "result=declined") == 0,
		"card Esc: no decline stamp, no visit flag, offered again");
	TRF_MissionCard = nil;
	-- D1 (te_dialog 1, hail_xml 1): three pages, the tokens, accept.
	TP_Begin("taira", "5_1", TP_GCfg());
	TP_DlgUi(0);
	local np = getn(h.pdlgs);
	n0 = S_Mark();
	r = TP_PatDock();
	local w = TP_Dlg();
	HOST_Check(r.nb == 0 and w.name == "TRF_Te1" and w.pilot == "TRF_WqP_patrol" and w.vis == "a_what"
		and w.text == "Patrol officer: "..TRF_Txt("te1p1", "Black Comets", "Elinor") and TP_Logs(n0, "result=shown via=dialog") == 1,
		"D1: the patrol officer's first page ("..tostring(w.text)..")");
	TP_Picks("a_what");
	w = TP_Dlg();
	HOST_Check(w.vis == "a_acc a_why a_dec" and TP_Has(w.text, "tell any MSF patrol station"), "D1 page 2: the faction named, accept, why, decline");
	TP_Picks("a_why");
	w = TP_Dlg();
	HOST_Check(w.vis == "a_acc2 a_dec2" and TP_Has(w.text, "Three old fighters"), "D1 page 3");
	TP_Picks("a_acc2");
	T_Tick(2, 0.5);
	HOST_Check(TRF_IqGet().q == 1 and TRF_IqGet().t == 21 and getn(h.pdlgs) == np + 1 and h.qlog.trf_te and h.qlog.trf_te.d == "#TRF_ted10s2"
		and TP_Logs(n0, "event=dialog dialog=1 via=dock answer=acc result=done") == 1, "D1 accept: the run, the entry in the mission list, the patrol window after it");
	-- D1 decline.
	TP_Begin("taira", "5_1", TP_GCfg());
	TP_DlgUi(0);
	r = TP_PatDock();
	TP_Picks("a_what", "a_dec");
	T_Tick(2, 0.5);
	HOST_Check(TRF_IqGet().q == 0 and TRF.iq and TRF.iq.l == TRF.clock.legs * 10 + 1, "D1 decline: the decline stamp");
	-- D1 Esc: nothing; the offer at the next docking.
	TP_Begin("taira", "5_1", TP_GCfg());
	TP_DlgUi(0);
	r = TP_PatDock();
	HOST_DlgEsc();
	T_Tick(4, 0.5);
	TP_Visit();
	n0 = S_Mark();
	r = TP_PatDock();
	HOST_Check(TRF.iq == nil and TP_Dlg().name == "TRF_Te1", "D1 Esc: no record, the offer again at the next docking");
	HOST_DlgEsc();
	T_Tick(4, 0.5);
	-- Fallbacks: te_dialog 0 (box, no fallback line), hail_xml 0, no StartTradeDialog, ui=4.
	local fb = {{{te_dialog=0}, nil}, {{hail_xml=0}, "xml"}, {{}, "native"}, {{}, "ui=4", '"ui=4"'}};
	bad = "";
	for i = 1, getn(fb) do
		TP_Begin("taira", "5_1", TP_GCfg(fb[i][1]));
		TP_DlgUi(0);
		local std = StartTradeDialog;
		if fb[i][2] == "native" then StartTradeDialog = nil; end;
		-- ui=4 (a dialog flag) makes TRF_Quiet answer a visible scene (no offer at all); the stub reaches the dialog gate.
		local oq2 = TRF_Quiet;
		if fb[i][2] == "ui=4" then h.ui = 4; TRF_Quiet = function() return nil; end; end;
		n0 = S_Mark();
		r = TP_PatDock();
		StartTradeDialog = std;
		TRF_Quiet = oq2;
		h.ui = 0;
		local ok = r.nb == 1 and r.box.text == btext;
		if fb[i][2] then ok = ok and TP_Logs(n0, "event=dialog_fallback dialog=1 reason="..(fb[i][3] or fb[i][2])) == 1; else ok = ok and TP_Logs(n0, "dialog_fallback") == 0; end;
		if not ok then bad = bad.." "..tostring(fb[i][2]); end;
		if r.nb > 0 then HOST_Press("cancel", r.box); end;
	end;
	HOST_Check(bad == "", "fallbacks: te_dialog 0, hail_xml 0, no StartTradeDialog, ui=4 give the box"..bad);
	-- The files: CRLF, ASCII, plain-text messages, every answer and token as TRF_TeDlgFiles lists them, the speaker in the
	-- speakers block of merge/Pilots.xml.
	local px = TP_Read("../../../../merge/Pilots.xml") or "";
	local b0 = strfind(px, "<!--sw3-traffic speakers begin", 1, 1);
	local e0 = strfind(px, "<!--sw3-traffic speakers end-->", 1, 1);
	if b0 and e0 then px = strsub(px, b0, e0); else px = ""; end;
	bad = "";
	for k, fi in TRF_TeDlgFiles() do
		local raw = TP_Read("../../Trade/"..fi.f..".xml") or "";
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
				local _, _, tk = strfind(pg.msg or "", "^Patrol officer: #(%w+)#$");
				if not tk or not fi.tk[tk] or pg.pilot ~= "TRF_WqP_patrol" then bad = bad.." "..fi.f..":"..pn; end;
			end;
		end;
	end;
	HOST_Check(bad == "" and TP_Has(px, '<GamePilot name="TRF_WqP_patrol">'), "dialog files: CRLF, ASCII, answers, tokens, links, the speaker TRF_WqP_patrol in the speakers block"..bad);
end;

-- h: progress, report, done, logbook, lapse (6.2-6.8) ---------------------------------------------------

-- A raid on a fresh trader paid now (TRF_Rd_Pay): how "paid" (help counted), "hail" (the combat hail paid the help),
-- "nohelp", "kill" (the trader killed), "tk" (the target killed), "open" (left open in the fight state for the jump).
-- Returns raid id, record.
function TP_Pay(how)
	local id, r = TP_Trader("C");
	TP_EndRaids();
	local L = TRF.live;
	local n = TRF_Rd_NewN(L);
	local rd = {n=n, id=id, st="fight", tier=2, t=0, hit=1, why="lane"};
	if how == "hail" then rd.hp = 1; end;
	if how == "nohelp" then rd.hit = nil; end;
	if how == "kill" then r.why = "kill"; end;
	if how == "tk" then rd.tk = 1; end;
	L.rd[n] = rd;
	if how == "open" then return n, rd; end;
	TRF_Rd_Pay(n, rd);
	rd.st = "end";
	return n, rd;
end;

-- Count of AddPost calls of id.
function TP_Posts(id)
	local n = 0;
	for i = 1, getn(HOST().posts) do if HOST().posts[i] == "+"..id then n = n + 1; end; end;
	return n;
end;

function T_TP_H()
	local h = HOST();
	TP_Begin("taira", "5_1", {news_mode=2});
	TRF_IqTake(1, 21, 77);
	TRF_TeRec("accept");
	HOST_Check(h.qlog.trf_te and h.qlog.trf_te.d == "#TRF_ted10s2", "run taken: the entry #TRF_ted10s2");
	-- A paid raid in the slot: count 1, tecnt after the thanks line, the entry ted11s2.
	local m0, s0 = TP_Marks();
	local n0 = S_Mark();
	local n = TP_Pay("paid");
	local said = TP_Said(m0, s0);
	local a1, a2 = strfind(said, "Thank you, Wolves", 1, 1), strfind(said, TRF_Txt("tecnt", 1, 2, "Black Comets"), 1, 1);
	HOST_Check(TRF_IqGet().c == 1 and TRF_IqGet().s == 1 and a1 and a2 and a1 < a2 and h.qlog.trf_te.d == "#TRF_ted11s2"
		and TP_Logs(n0, "event=count raid_id="..n.." kind=lane clan_slot=2 count=1 via=paid result=counted") == 1,
		"a paid raid of the Black Comets: count 1 after the thanks line, #TRF_ted11s2 ("..said..")");
	-- Not counted: no help, the trader killed, the target killed.
	TP_Pay("nohelp");
	TP_Pay("kill");
	TP_Pay("tk");
	HOST_Check(TRF_IqGet().c == 1, "no help, trader killed, target killed: not counted");
	-- A load mid-quest keeps step and count; the entry counts as current (no rewrite).
	n0 = S_Mark();
	T_SaveLoad();
	HOST_Check(TRF_IqGet().q == 1 and TRF_IqGet().c == 1 and TRF_IqGet().t == 21 and TP_Logs(n0, "result=added") == 0 and h.qlog.trf_te.d == "#TRF_ted11s2",
		"a load at count 1: the run kept, the entry not rewritten");
	-- ClearQuests at a mission start: the next entry adds it again.
	h.quests = {}; h.qlog = {};
	TRF_Te_OnActivate();
	HOST_Check(h.qlog.trf_te and h.qlog.trf_te.d == "#TRF_ted11s2", "reconcile after ClearQuests (step 10, count 1)");
	-- Another region: no count.
	T_Jump("kadi");
	n0 = S_Mark();
	n = TP_Pay("paid");
	HOST_Check(TRF_IqGet().c == 1 and TP_Logs(n0, "event=count raid_id="..n.." kind=lane clan_slot=5 via=paid result=none reason=region") == 1, "a raid in Kadi: not counted (reason region)");
	-- The second at the jump (8.5 pay of an open raid at TRF_BeforeJump): step 20, tecnt2, ted20f1.
	T_Jump("taira");
	n = TP_Pay("open");
	n0 = S_Mark();
	m0, s0 = TP_Marks();
	T_Jump("escaflon");
	HOST_Check(TRF_IqGet().s == 2 and TRF_IqGet().c == 0 and h.qlog.trf_te.d == "#TRF_ted20f1" and TP_Logs(n0, "event=count raid_id="..n.." kind=lane clan_slot=2 count=2 via=paid result=counted") == 1
		and TP_Logs(n0, "event=step step_before=10 step_after=20 reason=count") == 1 and S_Logs(n0, "result=jump") >= 1,
		"the second answered raid paid at the jump: step 20, #TRF_ted20f1");
	h.quests = {}; h.qlog = {};
	TRF_Te_OnActivate();
	HOST_Check(h.qlog.trf_te and h.qlog.trf_te.d == "#TRF_ted20f1", "reconcile after ClearQuests (step 20)");
	-- The report at another faction's dock (Proserpina, NESF): nothing.
	T_Jump("proserpina");
	n0 = S_Mark();
	local r = TP_PatDock();
	if r.nb > 0 then HOST_Press("cancel", r.box); end;
	HOST_Check(TRF_IqGet().s == 2 and TP_Logs(n0, "event=report system=proserpina faction=2 result=none reason=faction") == 1 and not TP_Has(r.scr, "Into the file"),
		"NESF patrol dock: no report (reason faction)");
	-- At an MSF dock (Escaflon) with the dialogs: talk box 455, D2 with the Ghost answer only, then done.
	T_Jump("escaflon");
	h.cfg.te_dialog = 1; h.cfg.hail_xml = 1;
	TP_DlgUi(0);
	-- A talk whose box did not open stays with its docking: a later docking that fails the report gate clears it.
	_param = GetCurrentLocation();
	TRF_Te_PatrolLine("patrol");
	local tb1 = TRF_Te_TalkBox("patrol");
	local odf = TRF_TeDockFac;
	TRF_TeDockFac = function() return 2; end;
	TRF_Te_PatrolLine("patrol");
	TRF_TeDockFac = odf;
	HOST_Check(type(tb1) == "table" and TRF_Te_TalkBox("patrol") == nil and TRF_IqGet().s == 2, "a stale talk: no talk box at a later docking of another faction");
	n0 = S_Mark();
	r = TP_PatDock();
	local w = TP_Dlg();
	HOST_Check(r.nb == 0 and w.name == "TRF_Te2" and w.vis == "a_k4" and w.text == "Patrol officer: "..TRF_Txt("te2p1", "Black Comets", "Elinor")
		and TP_Has(HOST_DlgText("a_k4"), "out of nowhere") and S_Logs(n0, "box=te_talk priority=455") == 1, "D2 at an MSF dock: the talk box 455, only the Ghost answer");
	TP_Picks("a_k4");
	HOST_Check(TP_Has(TP_Dlg().text, "That goes in the file"), "D2 page 2");
	TP_Picks("a_end");
	T_Tick(2, 0.5);
	local I = TRF_IqGet();
	_param = GetCurrentLocation();
	local bon = TRF_Te_BoardOn();
	HOST_Check(I.q == 0 and I.d == 1 and I.r == 1 and TRF.iq.a == 0 and bon == 1 and TP_Posts("mail_trf_te1") == 1
		and TP_Logs(n0, "event=done system=escaflon faction=1 clan_slot=2 leg=") == 1 and TP_Logs(n0, "event=letter post=mail_trf_te1 result=posted") == 1
		and h.qlog.trf_te and h.qlog.trf_te.d == "#TRF_ted30" and h.quests.trf_te == QUEST_DONE, "done: d 1, r 1 (MSF), the board words at once, the letter, the entry done");
	h.cfg.te_dialog = 0;
	-- The done entry goes 10 legs later; it stays across an entry before that.
	T_Jump("taira");
	HOST_Check(h.qlog.trf_te and h.qlog.trf_te.d == "#TRF_ted30", "the done entry stays at the next entry");
	TRF.clock.legs = TRF.clock.legs + 10;
	T_Jump("escaflon");
	HOST_Check(h.qlog.trf_te == nil, "the done entry removed 10 legs later");
	-- MSF done: no offer there; NESF offers (its bit not set).
	HOST_Check(TRF_TeOfferWhy(V_Idx("taira"), 1) == "done" and TRF_TeOfferWhy(V_Idx("proserpina"), 2) == nil, "MSF done, NESF due");
	-- A second faction's run with the fallback line (te_dialog 0): terep4, done, no second letter.
	T_Jump("proserpina");
	TRF_IqTake(1, 22, 5);
	TRF_IqSet(1, 2, 22, 0);
	n0 = S_Mark();
	r = TP_PatDock();
	if r.nb > 0 then HOST_Press("cancel", r.box); end;
	HOST_Check(TP_Has(r.scr, TRF_Txt("terep4")) and TRF_IqGet().r == 3 and TP_Posts("mail_trf_te1") == 1 and TP_Logs(n0, "event=done") == 1,
		"NESF's report without the dialog: terep4, reward bits 1 | 2, no second letter");
	-- The lapse after iq_stale 40 legs without progress: event=lapse, the entry removed, the offer again.
	TRF.iq = {a=0, d=1, r=3};
	TRF_IqTake(1, 22, 5);
	TRF_TeRec("accept");
	HOST_Check(h.qlog.trf_te ~= nil, "a third run taken");
	TRF.iq.r = 1;
	local l0 = TRF_IqGet().l;
	TRF.clock.legs = TRF.clock.legs + 38;
	T_Jump("taira");
	HOST_Check(TRF_IqGet().q == 1 and TRF.clock.legs - l0 == 39, "39 legs: still active");
	n0 = S_Mark();
	T_Jump("proserpina");
	HOST_Check(TRF_IqGet().q == 0 and TP_Logs(n0, "event=lapse step=10 count=0 leg=") == 1 and S_Logs(n0, "module=plumb event=iq quest=1 step=1 target=22 count=0 result=lapsed") == 1
		and h.qlog.trf_te == nil and TRF_TeOfferWhy(TRF_CurIdx(), 2) == nil, "40 legs without progress: lapsed, the entry removed, the offer again");
	-- The owner missing: the plumbing ends it.
	TRF_IqTake(1, 22, 5);
	local lf = TRF_Te_IqLapse;
	TRF_Te_IqLapse = nil;
	TRF.clock.legs = TRF.clock.legs + 40;
	n0 = S_Mark();
	TRF_IqStale();
	TRF_Te_IqLapse = lf;
	HOST_Check(TRF_IqGet().q == 0 and S_Logs(n0, "module=plumb event=iq quest=1 step=1 target=22 count=0 result=lapsed") == 1 and TP_Logs(n0, "event=lapse") == 0,
		"without TRF_Te_IqLapse: trf_plumb lapses the run itself");
	-- te_quest 0: no count, no offer; the lapse still runs.
	h.cfg.te_quest = 0;
	TRF_IqTake(1, 22, 5);
	TRF_TeRec("accept");
	TP_Pay("paid");
	HOST_Check(TRF_IqGet().c == 0 and TRF_TeOfferWhy(TRF_CurIdx(), 2) == "off", "te_quest 0: no count, no offer");
	TRF.clock.legs = TRF.clock.legs + 40;
	T_Jump("taira");
	HOST_Check(TRF_IqGet().q == 0, "te_quest 0: the lapse still runs");
	h.cfg.te_quest = nil;
	-- A hail_paid raid counts (via=hail).
	TRF_IqTake(1, 21, 5);
	n0 = S_Mark();
	n = TP_Pay("hail");
	HOST_Check(TRF_IqGet().c == 1 and TP_Logs(n0, "event=count raid_id="..n.." kind=lane clan_slot=2 count=1 via=hail result=counted") == 1
		and S_Logs(n0, "reason=hail_paid") == 1, "a hail_paid raid counts (via=hail)");
	-- The full state of this run.
	local size = 8 + 3 + HOST_SaveSize(TRF);
	print("HOST info TRF save size (temper run) "..size.." bytes, iq="..HOST_SaveSize(TRF.iq));
	HOST_Check(size < 100000, "full state "..size.." < 100000");
end;

-- Dispatch ------------------------------------------------------------------------------------

local sc = getenv("TRF_TP") or "";
local fn = getglobal("T_TP_"..strupper(sc));
print("HOST ==== temper scenario tp-"..sc.." dir="..HOST().dir);
if type(fn) == "function" then
	fn();
	HOST_Check(T_LeftGlobals() == "", "no handle globals left at the end"..T_LeftGlobals());
else
	HOST_Check(nil, "unknown temper scenario "..sc);
end;
HOST_Check((HOST().gpm_tick or 0) == 0, "no GetPlayerMotherShip from a tick (n="..tostring(HOST().gpm_tick or 0)..")");
print("HOST errors="..HOST().errors.." fails="..HOST().fails);
if HOST().errors > 0 or HOST().fails > 0 then exit(1); end;
exit(0);
