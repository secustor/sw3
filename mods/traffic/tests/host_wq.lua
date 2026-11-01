-- Freight unlock quest scenarios, commit 1 (design/freight-quest-spec.md 9) under stock Lua 4.0.1: TRF_WQ=a, b, run by
-- run_host.sh as its own entry point. a: registration, toggles, tune, texts, the offer gate reasons, the grandfather rule,
-- the decline cooldown, the box and the card spec with both mothership variants, the Office board row, the logbook
-- (AddQuest and the Job log, the move between them, ClearQuests), the save fields and TRF_Wq_Fix. b: the Kestrel mayday:
-- the seeded roll, the scripted-event slot, the spawn with the flag wq, the raid of why "wq" and its tier (min(2, cap)),
-- the 8.5 resolver flag, saved and lost (step 20, the lines, both thanks variants), the voids (no engagement, a refused
-- raid, a jump, a load) with the cooldown and wq_tries, the 8.4 contract exclusion, the names, the save size.
-- Loads host_parcel.lua up to its first scenario (helpers PC_*, which load host_station.lua). Stubs in host_stubs.lua:
-- HOST_MissionCard, HOST_JobPress, HOST_JobTick (the card), HOST_JobLogOn (the Job log natives).

local f = openfile((getenv("TRF_TESTS") or "./").."host_parcel.lua", "r");
if not f then print("HOST FAIL host_wq.lua: cannot open host_parcel.lua"); exit(1); end;
local src = read(f, "*a");
closefile(f);
local cut = strfind(src, "\n-- a: registration, toggles", 1, 1);
if not cut then print("HOST FAIL host_wq.lua: marker '-- a: registration, toggles' missing in host_parcel.lua"); exit(1); end;
dostring(strsub(src, 1, cut), "host_parcel.lua");

-- Helpers ----------------------------------------------------------------------------------

-- Config of these runs: the quest and freight on (the freight prize gap off), parcels and the features that claim boxes,
-- lines or entry slots off, the box path of the jobs UI (jobs_ui 0), log 2, plus t.
function WQ_Cfg(t)
	local c = {enable_wq=1, enable_freight=1, fw_prize_gap=0, enable_parcels=0, charter=0, cap_enable=0, sweeps=0, sweep_ct=0, feq=0,
		staged=0, seed=0, queue=0, parked=0, voice_events=0, dconv=0, carriers=0, po=0, enable_survivors=0, lad_enabled=0,
		enable_stashes=0, enable_scars=0, jobs_ui=0, log=2, tune={}};
	if t then for k, v in t do c[k] = v; end; end;
	return c;
end;

-- Scenario start in sys at chapter label ch (default 5_1): help 5, heat 0, no freight or quest record, the start hull
-- unknown (the new ship variant); jl 1 installs the Job log natives before the scripts load (trf_plumb probes them once).
function WQ_Begin(sys, ch, t, jl)
	local h = HOST();
	h.jl = {}; h.jl_off = nil;
	HOST_JobLogOn(jl or 0);
	h.labels.CurrentQuest = ch or "5_1";
	h.quests = {}; h.qlog = {};
	h.qs = FALSE;
	h.rel_team = nil;
	h.ms.model = nil;
	h.jc = {}; h.jq = {}; h.jc_open = nil; h.jc_off = nil; h.jc_why = nil;
	TRF_MissionCard = nil; TRF_JobBoard = nil; TRF_JobBoardMark = nil;
	S_Begin(sys, WQ_Cfg(t));
	h.credits = 1000000;
	TRF.std.help = 5; TRF.std.heat = 0;
	TRF.co = nil; TRF.wq = nil; TRF.stn = {};
	PC_World();
end;

function WQ_Has(s, t) return strfind(s or "", t, 1, 1); end;
-- wq log lines after mark n0 holding pat (plain).
function WQ_Logs(n0, pat)
	local n, q = 0, HOST().logs;
	for i = n0 + 1, getn(q) do if strfind(q[i], "module=wq ", 1, 1) and strfind(q[i], pat, 1, 1) then n = n + 1; end; end;
	return n;
end;
-- Messages (radio and screen) after index m0 joined by "|".
function WQ_Msgs(m0)
	local h, s = HOST(), "";
	for i = m0 + 1, getn(h.msgs) do s = s..h.msgs[i].t.."|"; end;
	return s;
end;
function WQ_Scr(s0)
	local h, s = HOST(), "";
	for i = s0 + 1, getn(h.screen) do s = s..h.screen[i].t.."|"; end;
	return s;
end;
-- Every line said after the mark: radio messages and screen lines.
function WQ_Said(m0, s0) return WQ_Msgs(m0)..WQ_Scr(s0); end;

-- Mothership next to the lead ship of trader id.
function WQ_MsTo(id)
	local p = TRF_GnLead(id):GetPosition();
	HOST().ms.pos = Vector3(p.x + 50, p.y, p.z);
end;

-- A new visit without a jump (the per-visit state of WQ and PC, the plumbing box lock).
function WQ_Visit()
	PC_Visit();
	TRF_Wq_OnEnter();
end;

-- A Wolves freighter owned (the grandfather rule).
function WQ_Owner()
	TRF.co = {seq=1, bal=0, vn=0, pg=0, rt=0, lk=0, vch=0, owe=0, lost=0, ships={}};
	TRF.co.ships[1] = {id=1, nm=1};
end;

-- The quest record at step s (repaired).
function WQ_At(s, t)
	TRF.wq = {v=1, s=s, k=0, n=0, sd=77};
	if t then for k, v in t do TRF.wq[k] = v; end; end;
	TRF_Wq_Fix();
	return TRF.wq;
end;

-- Legs set to the first value >= the current one whose next entry (TRF_AddLeg "enter") passes the mayday roll.
function WQ_Pass()
	local R = TRF.wq;
	local L = TRF.clock.legs;
	for i = 0, 400 do
		local l = L + i;
		if TRF_WqM(TRF_WqHash(R.sd, l + 1, R.s + 10 * R.n), 100) < TRF_WqK().pct then TRF.clock.legs = l; return l; end;
	end;
	return nil;
end;

-- Entry into sys with the roll passing; the due spawn (30-60 s). Returns the visit event.
function WQ_Mayday(sys)
	WQ_Pass();
	T_Enter(sys);
	T_Tick(130, 0.5);
	return TRF_WqSH().v.ev;
end;

-- The open raid of the event armed or not: its flight in.
function WQ_RaidIn(n)
	if V_Rd(n) and V_Rd(n).st == "armed" then HOST_Fire("f_inside", "TRF_RaidGo("..n..","); end;
	return TRF_H().rd[n];
end;

-- a: registration, gates, offer, card, logbook, repair -------------------------------------------

function WQ_N(t) local n = 0; for k, v in t do n = n + 1; end; return n; end;

function T_WQ_A()
	local h = HOST();
	WQ_Begin("debris6", "5_1");
	local idx = TRF_CurIdx();
	HOST_Check(S_Logs(0, "module=core event=loaded map=true module_count=18 extra_count=15") >= 1, "trf_wq loads last (extra_count=15)");
	local ml, pm, tf, uf = TRF_ModList(), TRF_PlMods(), TRF_Loc_TextFns(), TRF_UI_TextFns();
	HOST_Check(ml[getn(ml)] == "Wq" and pm[getn(pm)] == "Wq" and tf[getn(tf) - 1] == "TRF_Wq_Text" and uf[getn(uf)] == "TRF_Wq_Text",
		"Wq last in TRF_ModList and TRF_PlMods, TRF_Wq_Text in both text lists");
	HOST_Check(TRF_Wq_OptDef().enable_wq == 1 and TRF_WqOpt("enable_wq") == 1 and TRF_Opt("enable_wq") == 1, "cfg enable_wq 1 by default");
	local T = TRF_WqTune();
	HOST_Check(T.wq_help == 2 and T.wq_cd == 6 and T.wq_tries == 2 and TRF_Tune().wq_cd == 6, "tune defaults wq_help 2, wq_cd 6, wq_tries 2, merged into TRF_Tune");
	h.cfg.tune = {wq_help=150, wq_cd=-3, wq_tries=0.4};
	T = TRF_WqTune();
	HOST_Check(T.wq_help == 99 and T.wq_cd == 0 and T.wq_tries == 1, "clamps: wq_help <= 99, wq_cd >= 0, wq_tries >= 1");
	h.cfg.tune = {};
	-- Registrations (trf_plumb).
	local P = TRF_PlReg();
	local bo, ro, so, rh = "", "", "", "";
	for i = 1, getn(P.dock.trade.box) do bo = bo..P.dock.trade.box[i].o..":"..TRF_PlName(P.dock.trade.box[i].f)..","; end;
	for i = 1, getn(P.dock.trade.row) do ro = ro..P.dock.trade.row[i].o..":"..TRF_PlName(P.dock.trade.row[i].f)..","; end;
	for i = 1, getn(P.seed) do so = so..P.seed[i].o..":"..TRF_PlName(P.seed[i].f)..","; end;
	for i = 1, getn(P.rh) do rh = rh..TRF_PlName(P.rh[i].f)..","; end;
	HOST_Check(strsub(bo, 1, 23) == "450:TRF_Wq_DockBox,400:" and strsub(ro, 1, 22) == "450:TRF_Wq_JobRow,400:" and WQ_Has(so, "650:TRF_GnSeedCarrier,620:TRF_Wq_Seed,600:TRF_GnSeedFeq,")
		and WQ_Has(rh, "TRF_Wq_Help,"), "trade box 450 and board row 450 first, seed provider 620 between 650 and 600, the 8.5 resolver ("..bo.." "..so..")");
	-- Texts.
	local tx = TRF_Wq_Text();
	local bad = "";
	for k, v in tx do
		if strlen(v) > 480 or strfind(v, "[%%#\n]") then bad = bad.." "..k; end;
	end;
	HOST_Check(WQ_N(tx) == 19 and bad == "" and TRF_Txt("wqt") == "Missing in Capricorn" and TRF_Txt("fwboxtitle") == "FTU charter office"
		and TRF_Txt("wqalone") == "The Kestrel limped in alone." and TRF_Txt("wqname") == "Kestrel",
		"19 texts, at most 480 characters, no %, # or newline; title fwboxtitle"..bad);
	bad = "";
	for k, v in {"wqboxo", "wqoko", "wqthxo"} do
		if not WQ_Has(TRF_Txt(v), "Arba") or WQ_Has(TRF_Txt(v), "Alex") then bad = bad.." "..v; end;
	end;
	HOST_Check(bad == "" and WQ_Has(TRF_Txt("wqd20"), "report") and WQ_Has(TRF_Txt("wqd20l"), "pod-band account")
		and WQ_Has(TRF_Txt("wqd20a"), "on her own"), "old hauler texts name the Arba, not Alex; step-20 logbook text per result (wqd20, wqd20l, wqd20a)"..bad);
	-- Gate reasons (the station of debris6 is a loop stop of the Golkonda region).
	local K = TRF_WqK();
	HOST_Check(TRF_WqGate(idx) == nil and K.ch_min == 5 and K.ch_max == 18, "debris6, chapter 5, help 5: the offer is due");
	local gates = {{"4_1", "chapter"}, {"19_1", "chapter_end"}, {"5_1", "help", function() TRF.std.help = 1; end},
		{"5_1", "heat", function() TRF.std.heat = 3; end}, {"5_1", "war", function() PC_Rel("Trade", RELATION_WAR); end},
		{"5_1", "mission", function() V_QuestOn(); end}, {"5_1", "grandfather", function() WQ_Owner(); end},
		{"5_1", "started", function() WQ_At(10); end}, {"5_1", "declined", function() WQ_At(0, {dc=TRF.clock.legs - 3}); end},
		{"5_1", "off", function() HOST().cfg.enable_wq = 0; end}, {"5_1", "freight_off", function() HOST().cfg.enable_freight = 0; end},
		{"5_1", "chapter_region", nil, "kadi"}, {"9_1", "no_loop", nil, "xt05"}, {"5_1", "nk", nil, "nk"}};
	bad = "";
	for i = 1, getn(gates) do
		local g = gates[i];
		h.labels.CurrentQuest = g[1];
		TRF.std.help = 5; TRF.std.heat = 0; h.rel_team = nil; TRF.co = nil; TRF.wq = nil;
		if g[3] then g[3](); end;
		local at = idx;
		if g[4] then at = V_Idx(g[4]); end;
		local why = TRF_WqGate(at);
		if why ~= g[2] then bad = bad.." "..g[2].."->"..tostring(why); end;
		if g[2] == "mission" then V_QuestOff(); end;
		h.cfg.enable_wq = nil; h.cfg.enable_freight = 1;
	end;
	TRF.co = nil; TRF.wq = nil; h.rel_team = nil; h.labels.CurrentQuest = "5_1"; TRF.std.help = 5;
	HOST_Check(bad == "", "offer gates: chapter 4 and 19, help, heat, Trade at war, a mission, the grandfather rule, a started line, the decline cooldown, enable_wq 0, freight off, Kadi in chapter 5, a station off the loop, New Kyoto"..bad);
	local wk5 = TRF_WqGate(V_Idx("kadi"));
	h.labels.CurrentQuest = "7_1";
	HOST_Check(wk5 == "chapter_region" and TRF_WqGate(V_Idx("kadi")) == nil, "Kadi: not in chapters 5-6, every loop region from chapter 7");
	h.labels.CurrentQuest = "5_1";
	-- The box, new ship variant; Cancel starts the 10-leg cooldown.
	WQ_Visit();
	local n0 = S_Mark();
	local r = PC_Dock();
	HOST_Check(r.nb == 1 and r.box.title == "FTU charter office" and r.box.text == TRF_Txt("wqbox") and WQ_Has(r.box.text, "The Kestrel is three days overdue")
		and not WQ_Has(r.box.text, "Alex") and WQ_Logs(n0, "event=offer system=debris6 variant=new help=5 result=shown via=box") == 1
		and S_Logs(n0, "module=plumb event=dock kind=trade line_count=0 box=wq priority=450 result=box") == 1, "box 450: title fwboxtitle, the new ship text, offer line");
	PC_Press(r, "cancel");
	HOST_Check(TRF.wq and TRF.wq.s == 0 and TRF.wq.dc == TRF.clock.legs and h.qlog.trf_wq == nil and WQ_Logs(n0, "event=decline system=debris6 leg="..TRF.clock.legs.." result=declined") == 1,
		"Cancel: the record at step 0 with the decline leg, no logbook entry");
	n0 = S_Mark();
	r = PC_Dock();
	if r.nb > 0 then PC_Press(r, "cancel"); end;
	HOST_Check(S_Logs(n0, "box=wq ") == 0, "declined: no second offer in the visit");
	WQ_Visit();
	HOST_Check(TRF_WqGate(idx) == "declined", "declined: no offer within 10 legs");
	TRF.clock.legs = TRF.clock.legs + 10;
	HOST_Check(TRF_WqGate(idx) == nil, "after 10 legs the offer is due again");
	-- Old hauler variant (an Arba hauler), OK: step 10, the seed, the logbook entry, the clerk's reply.
	h.ms.model = "Mothership_arba";
	WQ_Visit();
	n0 = S_Mark();
	r = PC_Dock();
	HOST_Check(r.nb == 1 and r.box.text == TRF_Txt("wqboxo") and WQ_Has(r.box.text, "that Arba hauler") and WQ_Logs(n0, "variant=old") == 1,
		"Arba_pl2 hull Mothership_arba (GetName, any case): the old hauler text");
	local s = PC_Press(r, "ok");
	local R = TRF.wq;
	HOST_Check(R.s == 10 and R.dc == nil and R.n == 0 and type(R.sd) == "number" and R.sd >= 1 and R.sd <= 9999 and R.ql == 10
		and h.quests.trf_wq == QUEST_PROCESS and h.qlog.trf_wq.t == "#TRF_wqt" and h.qlog.trf_wq.d == "#TRF_wqd10"
		and WQ_Has(s, TRF_Txt("wqoko")) and WQ_Logs(n0, "event=accept system=debris6 variant=old") == 1
		and WQ_Logs(n0, "event=logbook list=mission id=trf_wq step=10 result=added") == 1, "OK: step 10, seed, AddQuest trf_wq (#TRF_wqt, #TRF_wqd10), the old hauler reply");
	WQ_Visit();
	n0 = S_Mark();
	r = PC_Dock();
	if r.nb > 0 then PC_Press(r, "cancel"); end;
	HOST_Check(TRF_WqGate(idx) == "started" and S_Logs(n0, "box=wq ") == 0, "started: no offer again (the freight purchase box may show)");
	bad = "";
	for k, v in {"hm_queen_pl", "arba_t", "Mothership_arba_pirate", "mothership_arba"} do
		h.ms.model = v;
		if TRF_WqVar() ~= "old" or TRF_WqVKey("wqthx") ~= "wqthxo" then bad = bad.." "..v; end;
	end;
	for k, v in {"mothership_empire", "Arba_0", "hm_queen", ""} do
		h.ms.model = v;
		if TRF_WqVar() ~= "new" or TRF_WqVKey("wqthx") ~= "wqthx" then bad = bad.." "..v; end;
	end;
	h.ms.model = nil;
	HOST_Check(bad == "" and TRF_WqVar() == "new", "hm_queen_pl, arba_t, mothership_arba_pirate, mothership_arba read old; any other hull or no name new"..bad);
	-- ClearQuests (a mission start) wipes the entry: the entry reconcile adds it again; s 0 removes it.
	ClearQuests();
	n0 = S_Mark();
	TRF_Wq_OnActivate();
	HOST_Check(h.qlog.trf_wq and h.qlog.trf_wq.d == "#TRF_wqd10" and WQ_Logs(n0, "event=reconcile id=trf_wq list=mission step=10 result=added reason=enter") == 1,
		"ClearQuests: the entry is added again at the next entry");
	TRF.wq.s = 0;
	TRF_Wq_OnActivate();
	HOST_Check(h.qlog.trf_wq == nil and h.quests.trf_wq == nil, "no described step: the entry is removed");
	-- The mission card (jobs_ui 1 with the native): the box spec's card.
	WQ_Begin("debris6", "5_1", {jobs_ui=1});
	TRF_MissionCard = HOST_MissionCard;
	h.ms.model = "hm_queen_pl";
	n0 = S_Mark();
	r = PC_Dock();
	local c = h.jc[1];
	HOST_Check(r.nb == 0 and c and c.id == "wq" and c.header == "The overdue transport" and c.title == "FTU charter office" and c.cost == nil
		and c.text == TRF_Txt("wqboxo") and S_Logs(n0, "box=wq priority=450 result=card") == 1, "card: id wq, header wqjobh, no cost, title fwboxtitle, the old hauler text");
	HOST_Check(HOST_JobTick() == "open" and WQ_Logs(n0, "result=shown via=card") == 1, "card open: the offer line via=card");
	HOST_JobPress("ok");
	HOST_JobTick();
	HOST_Check(TRF.wq and TRF.wq.s == 10 and h.qlog.trf_wq, "card OK: accepted as the box");
	-- The Office board row (cfg jobs_ui 2): the box spec as a row, and no box after the board was set.
	WQ_Begin("debris6", "5_1");
	local row = TRF_Wq_JobRow("trade");
	HOST_Check(row and row.id == "wq" and row.header == "The overdue transport" and row.short == "Capricorn lanes, no deadline" and row.text == TRF_Txt("wqbox")
		and row.ok == "TRF_Wq_BoxOk" and row.no == "TRF_Wq_BoxNo" and row.took == "TRF_Wq_JobTook" and TRF_Wq_JobTook(row.a) == nil,
		"board row: id wq, header, second line, the box text and handlers");
	TRF_PlReg().jb = {k="trade", rows={}, g=TRF.gen};
	HOST_Check(TRF_Wq_DockBox("trade") == nil, "no box after the board was set at this docking");
	TRF_PlReg().jb = nil;
	TRF_Wq_BoxOk(row.a);
	HOST_Check(TRF.wq and TRF.wq.s == 10 and TRF_Wq_JobTook(row.a) == 1, "row OK: step 10, took answers 1");
	-- The Job log (cfg jobs_log 1 with the natives): the entry in the Job log with the wqlog line; jobs_log 0 moves it back.
	WQ_Begin("debris6", "5_1", {jobs_log=1}, 1);
	WQ_Visit();
	n0 = S_Mark();
	r = PC_Dock();
	s = PC_Press(r, "ok");
	local je = h.jl[1];
	HOST_Check(je and je.id == "trf_wq" and je.t == "#TRF_wqt" and je.d == "#TRF_wqd10" and je.s == QUEST_PROCESS and h.qlog.trf_wq == nil
		and WQ_Has(s, "Charter office job added to the Job log.") and WQ_Logs(n0, "event=logbook list=job id=trf_wq step=10 result=added") == 1,
		"Job log: TRF_JobAdd trf_wq, no mission-list entry, the wqlog line");
	h.cfg.jobs_log = 0;
	n0 = S_Mark();
	TRF_Wq_OnActivate();
	HOST_Check(getn(h.jl) == 0 and h.qlog.trf_wq and h.qlog.trf_wq.d == "#TRF_wqd10" and WQ_Logs(n0, "event=logbook list=job id=trf_wq result=removed reason=moved") == 1,
		"jobs_log 0: the entry moves to the mission list");
	h.cfg.jobs_log = 1;
	TRF_Wq_OnActivate();
	HOST_Check(getn(h.jl) == 1 and h.qlog.trf_wq == nil, "jobs_log 1 again: back to the Job log");
	-- Repair and the save fields.
	TRF.wq = 7;
	TRF_Wq_Fix();
	HOST_Check(TRF.wq == nil, "a non-table record is dropped");
	TRF.wq = {s=15};
	TRF_Wq_Fix();
	HOST_Check(TRF.wq == nil, "an unknown step is dropped");
	local legs = TRF.clock.legs;
	TRF.wq = {s=20, k=9, n=40, dc=legs - 1, cd=legs + 5, lv=1, r=3, p=1, ql=20, zz=1};
	TRF_Wq_Fix();
	R = TRF.wq;
	HOST_Check(R.v == 1 and R.s == 20 and R.k == 0 and R.n == 0 and R.dc == nil and R.cd == nil and R.lv == nil and R.r == 3 and R.p == 1 and R.ql == 20
		and R.zz == nil and type(R.sd) == "number", "fields in range: k, n, a future void leg dropped, dc only at step 0, lv only at step 10, unknown keys dropped, a seed");
	TRF.wq = {s=0, dc=legs - 2};
	TRF_Wq_Fix();
	HOST_Check(TRF.wq.dc == legs - 2 and TRF.wq.s == 0, "step 0 keeps the decline leg");
	TRF.wq = nil;
	WQ_Owner();
	TRF_Wq_Fix();
	HOST_Check(TRF.wq and TRF.wq.s == 80 and TRF.wq.k == 2 and TRF_WqGate(idx) == "grandfather", "grandfather: a save with a freighter gets step 80 (bit 2), no offer");
	TRF.co = nil;
	TRF_Repair();
	HOST_Check(TRF.wq and TRF.wq.s == 80, "TRF_Repair runs TRF_Wq_Fix (the record stays once made)");
	HOST_Check(HOST_Reserved(TRF, "TRF") == "", "no reserved key");
end;

-- b: the Kestrel mayday ------------------------------------------------------------------------

function T_WQ_B()
	local h = HOST();
	WQ_Begin("debris6", "5_1");
	-- Mayday systems (spec 4.2), checked against TRF_Map.
	local bad = "";
	for nm, v in TRF_WqK().sys5 do if not V_Idx(nm) then bad = bad.." "..nm; end; end;
	for nm, v in TRF_WqK().sys6 do if not V_Idx(nm) then bad = bad.." "..nm; end; end;
	local ch6, fq = TRF_FrCh6(), {corrino=1, debris1=1, debris2=1, debris4=1, debris6=1};
	for nm, v in TRF_WqK().sys5 do if ch6[nm] or fq[nm] then bad = bad.." "..nm; end; end;
	HOST_Check(bad == "" and TRF_WqSysOk(V_Idx("golkonda"), 5) and not TRF_WqSysOk(V_Idx("debris6"), 5) and TRF_WqSysOk(V_Idx("debris6"), 6)
		and not TRF_WqSysOk(V_Idx("aurora"), 9), "mayday systems: on the map, none of the chapter-6 story or Quest5Freight systems in chapter 5, debris6 from chapter 6"..bad);
	-- No record, step 0 or 20: no seed. Step 10 in a system off the list: none.
	local R = WQ_At(10);
	local n0 = S_Mark();
	T_Enter("aurora");
	HOST_Check(TRF_WqSH().v.ev == nil and WQ_Logs(n0, "event=seed system=aurora result=none reason=system") == 1, "aurora: not a mayday system");
	-- Golkonda: a failed roll, then a passing one: the slot, the due spawn.
	local L = TRF.clock.legs;
	local l = L;
	while TRF_WqM(TRF_WqHash(R.sd, l + 1, R.s), 100) < 50 do l = l + 1; end;
	TRF.clock.legs = l;
	n0 = S_Mark();
	T_Enter("golkonda");
	HOST_Check(TRF_WqSH().v.ev == nil and WQ_Logs(n0, "event=seed system=golkonda roll=") == 1 and WQ_Logs(n0, "result=none reason=roll") == 1, "a failed roll: no event");
	n0 = S_Mark();
	WQ_Pass();
	T_Enter("golkonda");
	local ev = TRF_WqSH().v.ev;
	HOST_Check(ev and ev.st == "due" and TRF.live.ev == "wq" and WQ_Logs(n0, "event=seed system=golkonda") == 1 and WQ_Logs(n0, "result=planned") == 1
		and S_Logs(n0, "module=plumb event=event_slot kind=wq rank=8 result=taken") == 1, "passing roll: slot wq taken (optional rank 8), the spawn due");
	local m0, s0 = getn(h.msgs), getn(h.screen);
	T_Tick(130, 0.5);
	ev = TRF_WqSH().v.ev;
	local rec = ev and ev.id and TRF_Rec(ev.id);
	local rd = ev and type(ev.rn) == "number" and V_Rd(ev.rn);
	HOST_Check(ev.st == "live" and rec and rec.wq == 1 and rec.nm == 0 and rec.path == "A" and rd and rd.kind == "wq" and rd.tier == 2 and TRF.wq.lv == 1
		and WQ_Logs(n0, "event=spawn system=golkonda trader_id="..ev.id.." raid_id="..ev.rn.." tier=2 ") == 1, "spawn: path A trader with the flag wq, no pool name, raid of why wq at T2, live flag saved");
	HOST_Check(WQ_Has(WQ_Said(m0, s0), TRF_Txt("wqmay")) and S_Logs(n0, "module=plumb event=marker owner=wq label=TRF_WQ_NP result=added") == 1,
		"the mayday line and the marker");
	HOST_Check(TRF_Rd_Name(rec) == "Kestrel" and TRF_UI_Who(rec, ev.id) == "FTU transport Kestrel" and TRF_HlName(rec) == "Kestrel", "names: Kestrel (raid lines, hail), FTU transport Kestrel");
	local st1 = rec.st;
	rec.st = "in";
	local co, cw = TRF_CtOffer(ev.id);
	local rdn = rec.rdn;
	rec.rdn = nil;
	local co2, cw2 = TRF_CtOffer(ev.id);
	rec.rdn = rdn; rec.st = st1;
	HOST_Check(co == nil and cw == "used" and co2 == nil and cw2 == "wq", "no 8.4 contract: during the raid (used), after it (wq)");
	local hp, hw = TRF_HlHelpWhy(rec, {});
	HOST_Check(hp == nil and hw == "own", "no combat-hail help offer (the 8.5 raid help pays her): "..tostring(hw));
	-- Saved: counted help, the raid's ships dead; the resolver sets bit 1, the step gives step 20.
	local n = ev.rn;
	local hr = WQ_RaidIn(n);
	HOST_Fire("attack", "TRF_OnRaidHit("..n..",1,");
	local c0 = h.credits;
	m0, s0 = getn(h.msgs), getn(h.screen);
	n0 = S_Mark();
	for j = 1, getn(hr.sh) do hr.sh[j].alive = nil; HOST_Fire("died", "TRF_OnRaidDied("..n..","..j..","); end;
	HOST_Check(TRF_WqBit(TRF.wq.k, 1) and TRF.wq.s == 10 and WQ_Logs(n0, "event=help raid_id="..n) == 1 and S_Logs(n0, "module=raid event=paid raid_id="..n) == 1
		and h.credits > c0, "8.5 pay runs (credits "..(h.credits - c0).."), the resolver sets bit 1 and returns nil");
	T_Tick(4, 0.5);
	R = TRF.wq;
	HOST_Check(R.s == 20 and R.r == 1 and R.lv == nil and ev.st == "end" and h.qlog.trf_wq and h.qlog.trf_wq.d == "#TRF_wqd20"
		and WQ_Has(WQ_Said(m0, s0), TRF_Txt("wqthx")) and WQ_Logs(n0, "event=rescued system=golkonda trader_id="..ev.id.." raid_id="..n.." variant=new reason=raid_help") == 1
		and WQ_Logs(n0, "event=step step_before=10 step_after=20 reason=rescued") == 1 and S_Logs(n0, "module=plumb event=marker owner=wq deleted_count=1 result=cleared") == 1,
		"saved: step 20, r 1, the thanks line (new ship), the logbook at wqd20, the marker gone");
	TRF_Remove(ev.id, "test");
	-- Saved with the old hauler (the Arba_pl2 hull): the thanks variant.
	WQ_Begin("debris6", "5_1");
	R = WQ_At(10);
	h.ms.model = "mothership_arba";
	ev = WQ_Mayday("golkonda");
	n = ev.rn;
	hr = WQ_RaidIn(n);
	HOST_Fire("attack", "TRF_OnRaidHit("..n..",1,");
	m0, s0 = getn(h.msgs), getn(h.screen);
	for j = 1, getn(hr.sh) do hr.sh[j].alive = nil; HOST_Fire("died", "TRF_OnRaidDied("..n..","..j..","); end;
	T_Tick(4, 0.5);
	HOST_Check(TRF.wq.s == 20 and WQ_Has(WQ_Said(m0, s0), TRF_Txt("wqthxo")) and h.qlog.trf_wq.d == "#TRF_wqd20", "saved, old hauler: the thanks variant wqthxo");
	TRF_Remove(ev.id, "test");
	-- Lost: the Kestrel killed by her raid.
	WQ_Begin("debris6", "5_1");
	R = WQ_At(10);
	ev = WQ_Mayday("golkonda");
	local x = TRF_H().tr[ev.id];
	m0, s0 = getn(h.msgs), getn(h.screen);
	n0 = S_Mark();
	for t = 1, getn(x.tp) do x.tp[t].alive = nil; HOST_Fire("died", "TRF_OnShipDied("..ev.id..","..t..","); end;
	R = TRF.wq;
	HOST_Check(R.s == 20 and R.r == 2 and R.lv == nil and WQ_Has(WQ_Said(m0, s0), TRF_Txt("wqlost")) and WQ_Logs(n0, "event=lost system=golkonda trader_id="..ev.id) == 1
		and h.qlog.trf_wq.d == "#TRF_wqd20l", "lost: step 20, r 2, the pod band line, the logbook at wqd20l");
	ClearQuests();
	TRF_Wq_OnActivate();
	HOST_Check(h.qlog.trf_wq and h.qlog.trf_wq.d == "#TRF_wqd20l" and TRF.wq.ql == 20, "lost: the reconcile after ClearQuests adds wqd20l again");
	for q, e in TRF.live.rd do if type(e) == "table" and e.st ~= "end" then TRF_Rd_End(q, "cancel"); end; end;
	-- No engagement: the raid ends without counted help; void, slot freed, the cooldown, a re-roll after wq_cd legs.
	WQ_Begin("debris6", "5_1");
	R = WQ_At(10);
	ev = WQ_Mayday("golkonda");
	n = ev.rn;
	WQ_RaidIn(n);
	local tid = ev.id;
	n0 = S_Mark();
	TRF_Rd_End(n, "left");
	T_Tick(4, 0.5);
	R = TRF.wq;
	HOST_Check(R.s == 10 and R.n == 1 and R.cd == TRF.clock.legs and R.lv == nil and TRF.live.ev == nil and ev.st == "end"
		and WQ_Logs(n0, "event=void trader_id="..tid.." reason=no_help tries=1 tries_max=2") == 1 and TRF_Rec(tid) and TRF_Rec(tid).wq == 1,
		"no engagement: void, tries 1, slot freed; the Kestrel flies on (still no contract)");
	TRF_Remove(tid, "test");
	n0 = S_Mark();
	WQ_Pass();
	T_Enter("gredos");
	HOST_Check(TRF_WqSH().v.ev == nil and WQ_Logs(n0, "event=seed system=gredos result=none reason=cooldown") == 1, "within wq_cd legs: no new mayday");
	TRF.clock.legs = TRF.clock.legs + 6;
	-- A refused raid: void, the flag cleared (an ordinary trader with a pool name); the second void ends step 1.
	m0, s0 = getn(h.msgs), getn(h.screen);
	n0 = S_Mark();
	WQ_Pass();
	T_Enter("gredos");
	local ro = TRF_RaidOn;
	TRF_RaidOn = function() return nil; end;
	T_Tick(130, 0.5);
	TRF_RaidOn = ro;
	ev = TRF_WqSH().v.ev;
	rec = ev and ev.id and TRF_Rec(ev.id);
	R = TRF.wq;
	HOST_Check(ev and ev.st == "end" and rec and rec.wq == nil and rec.nm >= 1 and R.n == 2 and R.s == 20 and R.r == 3 and R.p == nil
		and WQ_Logs(n0, "event=void trader_id="..ev.id.." reason=raid tries=2") == 1 and WQ_Logs(n0, "event=limped tries=2 line=true") == 1
		and WQ_Has(WQ_Said(m0, s0), "The Kestrel limped in alone.") and h.qlog.trf_wq.d == "#TRF_wqd20a",
		"refused raid: void, the flag cleared; wq_tries voids: step 20 (r 3) with the limped-in line, the logbook at wqd20a");
	if rec then TRF_Remove(ev.id, "test"); end;
	-- A jump while she is on-screen: void; at the last try the line waits for the next entry.
	WQ_Begin("debris6", "5_1");
	R = WQ_At(10, {n=1});
	ev = WQ_Mayday("golkonda");
	tid = ev.id;
	HOST_Check(ev.st == "live", "jump case: the Kestrel is on-screen");
	n0 = S_Mark();
	T_Jump("elio");
	R = TRF.wq;
	HOST_Check(R.s == 20 and R.r == 3 and R.n == 2 and WQ_Logs(n0, "event=void trader_id="..tid.." reason=jump tries=2") == 1 and WQ_Logs(n0, "event=limped tries=2 line=false") == 1
		and R.p == nil and S_Logs(n0, "module=plumb event=arrival_line owner=wq ") == 1 and h.qlog.trf_wq and h.qlog.trf_wq.d == "#TRF_wqd20a",
		"jump: void, the last try, the limped-in line as an arrival line of the next entry, the logbook at wqd20a");
	-- A load while she is on-screen (the mothership next to her, so trf_gen's load pass adopts her): the record removed
	-- (orphan), void.
	WQ_Begin("debris6", "5_1");
	R = WQ_At(10);
	ev = WQ_Mayday("golkonda");
	tid = ev.id;
	WQ_MsTo(tid);
	n0 = S_Mark();
	T_SaveLoad();
	R = TRF.wq;
	HOST_Check(R.s == 10 and R.n == 1 and R.lv == nil and TRF_Rec(tid) == nil and WQ_Logs(n0, "event=orphan trader_id="..tid.." result=removed") == 1
		and WQ_Logs(n0, "event=void trader_id=nil reason=load tries=1") == 1, "load: the Kestrel removed, void (tries 1)");
	-- A saved live flag with the help bit (a load or an unseen jump before the step resolved it): saved, no void.
	WQ_Begin("debris6", "5_1");
	R = WQ_At(10, {k=1, lv=1});
	n0 = S_Mark();
	TRF_Wq_OnEnter();
	HOST_Check(R.s == 20 and R.r == 1 and R.lv == nil and R.n == 0 and WQ_Logs(n0, "event=rescued reason=entry tries=0") == 1
		and WQ_Logs(n0, "event=void") == 0 and h.qlog.trf_wq and h.qlog.trf_wq.d == "#TRF_wqd20",
		"live flag with the help bit at an entry: saved without the line, no void, the logbook at wqd20");
	-- The tier rule: tier cap 1 gives T1.
	WQ_Begin("debris6", "5_1", {tier_cap=1});
	R = WQ_At(10);
	ev = WQ_Mayday("golkonda");
	rd = ev and type(ev.rn) == "number" and V_Rd(ev.rn);
	HOST_Check(rd and rd.kind == "wq" and rd.tier == 1, "tier cap 1: the wq raid is T1 (min(2, cap))");
	for q, e in TRF.live.rd do if type(e) == "table" and e.st ~= "end" then TRF_Rd_End(q, "cancel"); end; end;
	if ev and ev.id then TRF_Remove(ev.id, "test"); end;
	-- A mission or enable_wq 0: no seed.
	WQ_Begin("debris6", "5_1", {enable_wq=0});
	R = WQ_At(10);
	n0 = S_Mark();
	WQ_Mayday("golkonda");
	HOST_Check(TRF_WqSH().v.ev == nil and TRF.wq.s == 10 and WQ_Logs(n0, "event=spawn") == 0, "enable_wq 0: no mayday, the record kept");
	-- Save size: the record at its widest (every field) is at most 260 bytes; dump.
	TRF.wq = {v=1, s=90, k=3, n=9, dc=-9999999, cd=-9999999, sd=9999, lv=1, r=3, p=1, ql=90};
	local z = HOST_SaveSize(TRF.wq);
	HOST_Check(z <= 260, "TRF.wq at its widest: "..z.." bytes <= 260");
	n0 = S_Mark();
	TRF_Wq_Dump();
	HOST_Check(WQ_Logs(n0, "event=dump step=90 flags=3 tries=9") == 1, "dump line");
	HOST_Check(HOST_Reserved(TRF, "TRF") == "", "no reserved key");
end;

-- Dispatch ---------------------------------------------------------------------------------

local sc = getenv("TRF_WQ") or "a";
local fn = getglobal("T_WQ_"..strupper(sc));
if type(fn) == "function" then
	fn();
	HOST_Check(T_LeftGlobals() == "", "no handle globals left at the end"..T_LeftGlobals());
	local q = T_BadCallbacks();
	HOST_Check(q == "", "every mod callback string carries the current gen"..q);
else
	HOST_Check(nil, "unknown freight unlock quest scenario "..sc);
end;
HOST_Check((HOST().gpm_tick or 0) == 0, "no GetPlayerMotherShip from a tick (n="..tostring(HOST().gpm_tick or 0)..")");
print("HOST errors="..HOST().errors.." fails="..HOST().fails);
if HOST().errors > 0 or HOST().fails > 0 then exit(1); end;
exit(0);
