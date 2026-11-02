-- Freight unlock quest scenarios, commits 1-3 (design/freight-quest-spec.md 9) under stock Lua 4.0.1: TRF_WQ=a..f, run by
-- run_host.sh as its own entry point. a: registration, toggles, tune, texts, the offer gate reasons, the grandfather rule,
-- the decline cooldown, the box and the card spec with both mothership variants, the Office board row, the logbook
-- (AddQuest and the Job log, the move between them, ClearQuests), the save fields and TRF_Wq_Fix. b: the Kestrel mayday:
-- the seeded roll, the scripted-event slot, the spawn with the flag wq, the raid of why "wq" and its tier (min(2, cap)),
-- the 8.5 resolver flag, saved and lost (step 20, the lines, both thanks variants), the voids (no engagement, a refused
-- raid, a jump, a load) with the cooldown and wq_tries, the 8.4 contract exclusion, the names, the save size. Commit 2:
-- c: the report per result and its gates, the wreck pick (hash, debris6 from chapter 6), the Marlin wreck through
-- trf_survive's quest records (the seed in ws only, q 1, the fallback point, no second seed while a quest record or
-- carry exists, the full list, the pickup, the hand-in, the credits_only dock, TRF_Sv_Fix, TRF_SvExpire, TRF_SvRoom, the
-- slaver roll, the dump). d: the fence box (region, price, OK, cannot pay, Cancel), the patrol board (rung 0 and 1), the
-- logbook and the reconcile at steps 30-50, the repair of ws and k, the dump, the size. Commit 3: e: the clan hold at
-- XB-13 (the hold points and the stash slots, mode 1 with the captain tip and the open-band line, the base lost in view
-- or off-screen, mode 3 with the hulk and the tier-3 guard by difficulty, its death through the died triggers or the 1 s
-- step, the pods, the pickups, a jump with none or part of the crew aboard, a load, the gates). f: the hand-in, the
-- TRF_FrBuyGate unlock with enable_wq 1 and 0, the box text fwboxq, OK, Cancel and a poor OK, the done entry and its
-- removal (mission list and Job log), the parcel box at step 70, the repair of m, cg, pn, pk, wd, the dump, the size.
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
	HOST_Check(WQ_N(tx) == 39 and bad == "" and TRF_Txt("wqt") == "Missing in Capricorn" and TRF_Txt("fwboxtitle") == "FTU charter office"
		and TRF_Txt("wqalone") == "The Kestrel limped in alone." and TRF_Txt("wqname") == "Kestrel",
		"39 texts, at most 480 characters, no %, # or newline; title fwboxtitle"..bad);
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

-- c: the report, the Marlin wreck (survive quest records) ------------------------------------

-- Live mod objects with label prefix p (TRF_SVB_, TRF_SVP_).
function WQ_Objs(p)
	local n, q = 0, HOST().ships;
	for i = 1, getn(q) do
		if q[i].alive and type(q[i].label) == "string" and strsub(q[i].label, 1, strlen(p)) == p then n = n + 1; end;
	end;
	return n;
end;

-- Quest records in TRF.sv.b: count, the first one.
function WQ_QRecs()
	local n, f = 0, nil;
	if type(TRF.sv) ~= "table" or type(TRF.sv.b) ~= "table" then return 0, nil; end;
	for i = 1, getn(TRF.sv.b) do if TRF.sv.b[i].q == 1 then n = n + 1; if not f then f = TRF.sv.b[i]; end; end; end;
	return n, f;
end;

-- The mothership flown onto pod j of the placed record of system s (two ticks: the swept segment ends there).
function WQ_ToPod(s, j)
	local o = TRF_SvGet(s, j or 1);
	if not o then return nil; end;
	local p = o:GetPosition();
	HOST().ms.pos = Vector3(p.x + 5, p.y, p.z);
	T_Tick(2, 0.5);
	return 1;
end;

-- Ordinary survivor record fixture of system idx (no objects).
function WQ_SvRec(idx, n, lg, t)
	local b = {s=idx, si=0, x=300, y=0, z=0, n=n, n0=max(n, 1), f=0, nm=0, lg=lg, src=2, sl=0, pf=0, pp=0};
	if t then for k, v in t do b[k] = v; end; end;
	return b;
end;

-- Pirate and patrol docking through the wrapper chains (as host_stash.lua SH_PirDock, SH_PatDock).
function WQ_PirDock()
	local h = HOST();
	local s0, b0 = getn(h.screen), getn(h.boxes);
	_param = "pirate1";
	__PirStationDock_Ok();
	local r = {scr="", nb=getn(h.boxes) - b0, s0=s0};
	for i = s0 + 1, getn(h.screen) do r.scr = r.scr..h.screen[i].t.."|"; end;
	if r.nb > 0 then r.box = h.boxes[getn(h.boxes)]; end;
	return r;
end;

function WQ_PatDock()
	local h = HOST();
	local s0, b0 = getn(h.screen), getn(h.boxes);
	_param = GetCurrentLocation();
	__PatrolStationDock_Ok();
	local r = {scr="", nb=getn(h.boxes) - b0, s0=s0};
	for i = s0 + 1, getn(h.screen) do r.scr = r.scr..h.screen[i].t.."|"; end;
	if r.nb > 0 then r.box = h.boxes[getn(h.boxes)]; end;
	return r;
end;

-- The expected wreck pick of seed sd in chapter ch (spec 4.3: hash(sd, 11) mod n over golkonda, callipso, debris6 from 6).
function WQ_WsOf(sd, ch)
	local l = {V_Idx("golkonda"), V_Idx("callipso")};
	if ch >= 6 then tinsert(l, V_Idx("debris6")); end;
	return l[1 + TRF_WqM(TRF_WqHash(sd, 11, 0), getn(l))];
end;

function T_WQ_C()
	local h = HOST();
	WQ_Begin("debris6", "5_1", {enable_survivors=1, sv_seeded=0});
	TRF.sv = nil;
	local K = TRF_WqK();
	local P = TRF_PlReg();
	local lo = "";
	for i = 1, getn(P.dock.trade.line) do lo = lo..P.dock.trade.line[i].o..":"..TRF_PlName(P.dock.trade.line[i].f)..","; end;
	HOST_Check(WQ_Has(lo, "30:TRF_Sv_DockLine,40:TRF_Wq_DockLine,60:"), "trade line 40 between survivors 30 and freight 60 ("..lo..")");
	-- The report per result r: the line, step 30, the wreck pick; the logbook at wqd30.
	local res = {"saved", "lost", "limped"};
	local bad = "";
	for r = 1, 3 do
		WQ_Visit();
		local R = WQ_At(20, {r=r, ql=20});
		local n0 = S_Mark();
		local d = PC_Dock();
		if R.s ~= 30 or not WQ_Has(d.scr, TRF_Txt("wqrep"..r)) or R.ws ~= WQ_WsOf(R.sd, 5) or TRF_WqBit(R.k, 4)
			or WQ_Logs(n0, "event=report system=debris6 result="..res[r].." wreck_system="..TRF_WqName(R.ws)) ~= 1
			or WQ_Logs(n0, "event=step step_before=20 step_after=30 reason=report") ~= 1 or h.qlog.trf_wq.d ~= "#TRF_wqd30" then
			bad = bad.." r"..r;
		end;
	end;
	HOST_Check(bad == "" and WQ_Has(TRF_Txt("wqrep1"), "Kestrel's captain") and WQ_Has(TRF_Txt("wqrep2"), "pods") and WQ_Has(TRF_Txt("wqrep3"), "on her own"),
		"report per result: wqrep1 saved, wqrep2 lost, wqrep3 limped in; step 30, ws = hash(sd, 11) mod 2, logbook wqd30"..bad);
	-- The same pick on a re-run (the seed decides); debris6 only from chapter 6 (k bit 4, wqd30d).
	local R = WQ_At(20, {r=1, sd=77});
	TRF_WqWsPick(R, 5);
	local w1 = R.ws;
	TRF_WqWsPick(R, 5);
	local d5 = nil;
	for sd = 1, 300 do R.sd = sd; TRF_WqWsPick(R, 5); if R.ws == V_Idx("debris6") or TRF_WqBit(R.k, 4) then d5 = sd; end; end;
	local s6 = nil;
	for sd = 1, 300 do if not s6 and WQ_WsOf(sd, 6) == V_Idx("debris6") then s6 = sd; end; end;
	HOST_Check(w1 == R.ws or w1 == WQ_WsOf(77, 5), "the same seed picks the same system");
	HOST_Check(d5 == nil and s6 ~= nil, "chapter 5 never picks debris6 (seeds 1..300); chapter 6 can (seed "..tostring(s6)..")");
	h.labels.CurrentQuest = "6_1";
	WQ_Visit();
	R = WQ_At(20, {r=1, sd=s6, ql=20});
	PC_Dock();
	HOST_Check(R.s == 30 and R.ws == V_Idx("debris6") and TRF_WqBit(R.k, 4) and h.qlog.trf_wq.d == "#TRF_wqd30d" and WQ_Has(TRF_Txt("wqd30d"), "Debris 6")
		and not WQ_Has(TRF_Txt("wqd30"), "Debris 6"), "chapter 6: debris6 picked, k bit 4, logbook wqd30d");
	h.labels.CurrentQuest = "5_1";
	-- Report gates: any region (gaoba, off every loop), not at New Kyoto, not during a mission, not with enable_wq 0.
	T_Enter("gaoba");
	WQ_Visit();
	R = WQ_At(20, {r=2});
	local n0 = S_Mark();
	local d = PC_Dock();
	HOST_Check(R.s == 30 and WQ_Has(d.scr, TRF_Txt("wqrep2")), "report at gaoba (no loop stop): step 30");
	T_Enter("nk");
	WQ_Visit();
	R = WQ_At(20, {r=1});
	n0 = S_Mark();
	PC_Dock();
	local gnk = R.s;
	T_Enter("gaoba");
	R = WQ_At(20, {r=1});
	V_QuestOn();
	n0 = S_Mark();
	PC_Dock();
	local gms = R.s;
	V_QuestOff();
	h.cfg.enable_wq = 0;
	WQ_Visit();
	PC_Dock();
	local goff = R.s;
	h.cfg.enable_wq = 1;
	HOST_Check(gnk == 20 and gms == 20 and goff == 20 and TRF_WqRepGate(V_Idx("nk"), WQ_At(20)) == "nk", "no report at New Kyoto, during a mission, with enable_wq 0");
	-- Trader contacts of the wreck systems (open question 14): golkonda and callipso give contact points.
	local cg = "";
	for k, nm in {"golkonda", "callipso"} do
		T_Enter(nm);
		local cs = TRF_GnContacts() or {};
		local nt = 0;
		for i = 1, getn(cs) do if TRF_GnIsTrader(cs[i]) then nt = nt + 1; end; end;
		local np = getn(TRF_SvPoints(TRF_CurIdx(), TRF_SvK()));
		cg = cg.." "..nm..":"..nt.."/"..np;
		if nt == 0 then cg = cg.."!"; end;
	end;
	-- The host scene's contact points sit near the map stations, as the vanilla ones do (spec 12 question 14): the
	-- portal fallback point is the normal case there.
	HOST_Check(not WQ_Has(cg, "!"), "golkonda and callipso: trader contacts after TRF_GnContacts (contacts/points passing the site rule"..cg..")");
	-- The wreck: on entry into ws only; a quest record q 1, pf 0, src 2, one pod, placed with the beacon line and the marker.
	TRF.sv = nil;
	T_Enter("debris6");
	R = WQ_At(30, {r=1, ws=V_Idx("golkonda"), ql=30});
	n0 = S_Mark();
	T_Enter("callipso");
	HOST_Check(WQ_QRecs() == 0 and WQ_Logs(n0, "event=wreck system=callipso result=none reason=system") == 1, "callipso with ws golkonda: no wreck");
	n0 = S_Mark();
	local m0, s0 = getn(h.msgs), getn(h.screen);
	T_Enter("golkonda");
	local nq, b = WQ_QRecs();
	HOST_Check(nq == 1 and b.q == 1 and b.pf == 0 and b.src == 2 and b.n == 1 and b.s == V_Idx("golkonda") and WQ_Objs("TRF_SVP_") == 1 and WQ_Objs("TRF_SVB_") == 1
		and WQ_Logs(n0, "event=wreck system=golkonda beacon=1 point=portal result=seeded") == 1
		and S_Logs(n0, "module=survive event=seed system=golkonda kind=quest source=2 pods=1 pay=0 point=portal result=beacon beacon=1") == 1
		and S_Logs(n0, "module=plumb event=marker owner=sv label=TRF_SV_"..b.s.." result=added") == 1
		and S_Logs(n0, "module=plumb event=arrival_line owner=survive ") == 1 and TRF.live.ev == nil,
		"golkonda (ws): quest record q 1, pf 0, src 2, one pod, beacon and pod placed, the marker and the beacon line; no event slot");
	-- No second seed while the record exists.
	n0 = S_Mark();
	T_Jump("debris6");
	T_Jump("golkonda");
	HOST_Check(WQ_QRecs() == 1 and WQ_Logs(n0, "event=wreck system=golkonda result=none reason=record") == 1, "a quest record exists: no second seed");
	-- Pickup: c.q, the navigator's line, the marker goes with the record.
	m0, s0 = getn(h.msgs), getn(h.screen);
	n0 = S_Mark();
	WQ_ToPod(V_Idx("golkonda"), 1);
	local c = TRF.sv.c;
	HOST_Check(c and c.q == 1 and c.n == 1 and c.cr == 0 and WQ_Has(WQ_Said(m0, s0), TRF_Txt("wqnav")) and WQ_Logs(n0, "event=wreck system=golkonda pods=0 result=picked") == 1
		and S_Logs(n0, "module=plumb event=marker owner=sv deleted_count=1 result=cleared") == 1 and TRF.wq.s == 30,
		"pickup: c.q 1, the navigator's line, the marker cleared, still step 30");
	-- The carry is q: no seed even without a record.
	TRF.sv.b = {};
	n0 = S_Mark();
	T_Jump("debris6");
	T_Jump("golkonda");
	HOST_Check(WQ_QRecs() == 0 and WQ_Logs(n0, "event=wreck system=golkonda result=none reason=carry") == 1, "a quest crew aboard: no seed");
	-- TRF_SvExpire: the q carry never expires; an ordinary one does.
	TRF.sv.c.lg = TRF.clock.legs - 50;
	HOST_Check(TRF_SvExpire(1) == nil and TRF.sv.c and TRF.sv.c.q == 1, "TRF_SvExpire: the quest crew is kept past sv_carry");
	-- A credits_only dock (cfg sv_deny) keeps the q crew aboard: an ordinary crew's credits merged in are paid and cleared.
	TRF.sv.c.lg = TRF.clock.legs;
	TRF.sv.c.cr = 2500;
	h.cfg.sv_deny = {"golkonda"};
	local cr0, h0 = h.credits, TRF.std.help;
	n0 = S_Mark();
	WQ_Visit();
	PC_Dock();
	c = TRF.sv.c;
	HOST_Check(c and c.q == 1 and c.n == 1 and c.cr == 0 and h.credits == cr0 + 2500 and TRF.std.help == h0 and TRF.wq.s == 30
		and S_Logs(n0, "result=credits_only reason=deny quest_kept=true") == 1, "denied dock: the credits paid, the quest crew stays aboard (step 30)");
	n0 = S_Mark();
	WQ_Visit();
	PC_Dock();
	HOST_Check(TRF.sv.c and TRF.sv.c.q == 1 and S_Logs(n0, "result=skipped reason=deny") == 1, "denied dock without credits: kept aboard");
	h.cfg.sv_deny = nil;
	-- Hand-in: the normal survivor standing, no credits, step 40, logbook wqd40.
	cr0, h0 = h.credits, TRF.std.help;
	m0, s0 = getn(h.msgs), getn(h.screen);
	n0 = S_Mark();
	WQ_Visit();
	d = PC_Dock();
	HOST_Check(TRF.sv.c == nil and TRF.wq.s == 40 and h.credits == cr0 and TRF.std.help == h0 + 1 and WQ_Logs(n0, "event=wreck system=golkonda carried=1 result=handed") == 1
		and WQ_Logs(n0, "event=step step_before=30 step_after=40 reason=handed") == 1 and h.qlog.trf_wq.d == "#TRF_wqd40"
		and S_Logs(n0, "module=survive event=hand kind=ftu system=golkonda carried=1 pay=0 ") == 1, "hand-in: help +1, no credits, step 40, logbook wqd40");
	-- A second hand-in of a q crew after step 30 does not move the step again.
	TRF.sv.c = {n=1, cr=0, pc=0, s1=V_Idx("golkonda"), f=0, lg=TRF.clock.legs, q=1};
	n0 = S_Mark();
	WQ_Visit();
	PC_Dock();
	HOST_Check(TRF.wq.s == 40 and TRF.sv.c == nil and WQ_Logs(n0, "event=wreck system=golkonda carried=1 step=40 result=none reason=step") == 1, "a quest crew after step 30: no step");
	-- The full list: four ordinary records; the seed drops the oldest empty one, never a q record.
	T_Enter("debris6");
	local L = TRF.clock.legs;
	TRF.sv.b = {WQ_SvRec(V_Idx("heos"), 2, L - 3), WQ_SvRec(V_Idx("xk10"), 0, L - 1), WQ_SvRec(V_Idx("lidau"), 1, L - 2), WQ_SvRec(V_Idx("altair"), 0, L)};
	TRF.sv.c = nil;
	R = WQ_At(30, {r=1, ws=V_Idx("golkonda"), ql=30});
	n0 = S_Mark();
	T_Enter("golkonda");
	nq, b = WQ_QRecs();
	HOST_Check(getn(TRF.sv.b) == 4 and nq == 1 and S_Logs(n0, "module=survive event=expire system=xk10 ") == 1 and S_Logs(n0, "reason=cap") == 1,
		"full list (4 ordinary records): the oldest empty one dropped for the quest record");
	local T = TRF_SvTune();
	n0 = S_Mark();
	TRF_SvAdd(WQ_SvRec(V_Idx("kadi"), 1, L), T);
	nq = WQ_QRecs();
	HOST_Check(getn(TRF.sv.b) == 4 and nq == 1 and S_Logs(n0, "event=expire system=golkonda") == 0, "TRF_SvAdd at sv_max: an ordinary record goes, never the q record");
	h.cfg.tune = {sv_max=1};
	TRF.sv.b = {b};
	local ai = TRF_SvAdd(WQ_SvRec(V_Idx("kadi"), 1, L), TRF_SvTune());
	HOST_Check(ai == nil and getn(TRF.sv.b) == 1 and TRF.sv.b[1].q == 1, "sv_max 1 with the q record: TRF_SvAdd refuses (nil)");
	h.cfg.tune = {};
	-- An ordinary record in ws is replaced by the quest record (one record per system).
	TRF_Sv_BeforeJump();
	TRF.sv.b = {WQ_SvRec(V_Idx("golkonda"), 2, L, {pf=900})};
	n0 = S_Mark();
	T_Enter("golkonda");
	nq, b = WQ_QRecs();
	HOST_Check(nq == 1 and getn(TRF.sv.b) == 1 and b.n == 1 and S_Logs(n0, "event=expire system=golkonda beacon=1 pods=2 source=2 ") == 1
		and S_Logs(n0, "event=clear system=golkonda deleted_count=3 reason=quest") == 1 and S_Logs(n0, "module=plumb event=arrival_line owner=survive ") == 1,
		"an ordinary record in ws: dropped (reason quest) for the quest record, one beacon line");
	-- The quest record expires as any (sv_ttl); the next entry seeds it again.
	b.lg = TRF.clock.legs - 10;
	TRF_SvExpire(1);
	nq = WQ_QRecs();
	HOST_Check(nq == 0 and TRF.sv.x == nil, "TRF_SvExpire: the quest beacon expires after sv_ttl, never on the silent list");
	n0 = S_Mark();
	T_Jump("debris6");
	T_Jump("golkonda");
	nq = WQ_QRecs();
	HOST_Check(nq == 1 and WQ_Logs(n0, "event=wreck system=golkonda beacon=1 ") == 1, "the next entry into ws seeds it again");
	-- A destroyed pod (n 0, no carry): the next entry replaces the empty quest record (no wait for sv_ttl).
	nq, b = WQ_QRecs();
	b.n = 0;
	n0 = S_Mark();
	T_Jump("debris6");
	T_Jump("golkonda");
	nq, b = WQ_QRecs();
	HOST_Check(nq == 1 and b.n == 1 and WQ_Logs(n0, "event=wreck system=golkonda beacon=1 ") == 1
		and S_Logs(n0, "event=expire system=golkonda beacon=1 pods=0 source=2 ") == 1 and S_Logs(n0, "reason=quest") >= 1
		and S_Logs(n0, "module=plumb event=arrival_line owner=survive ") == 1,
		"an empty quest record (the pod destroyed): replaced at the next entry, with the beacon line");
	-- The fallback point: no contact point, K.q_off from the entry portal, outside the site rule.
	TRF_Sv_BeforeJump();
	TRF.sv.b = {};
	local sp = TRF_SvPoints;
	TRF_SvPoints = function() return {}; end;
	n0 = S_Mark();
	TRF_WqWreck();
	TRF_SvPoints = sp;
	nq, b = WQ_QRecs();
	local pl, sl = TRF_SvSites(V_Idx("golkonda"));
	local ms = TRF_Sv_MsPos();
	local ep, ed = nil, nil;
	for i = 1, getn(pl) do local dd = TRF_SvDist(ms, pl[i]); if not ed or dd < ed then ep = pl[i]; ed = dd; end; end;
	local dp = ep and TRF_SvDist(b, ep);
	HOST_Check(nq == 1 and WQ_Logs(n0, "point=portal result=seeded") == 1 and dp and abs(dp - TRF_SvK().q_off) < 1.5 and TRF_SvSiteOf(b, pl, sl, ms, TRF_SvK()) == nil,
		"no contact point: the record "..TRF_SvK().q_off.." from the entry portal ("..tostring(dp and floor(dp))..") outside the site rule");
	-- A contact point that passes the site rule is taken first.
	TRF_Sv_BeforeJump();
	TRF.sv.b = {};
	TRF_SvPoints = function() return {{x=-40.4, y=0, z=611.6}}; end;
	n0 = S_Mark();
	TRF_WqWreck();
	TRF_SvPoints = sp;
	nq, b = WQ_QRecs();
	HOST_Check(nq == 1 and b.x == -40 and b.z == 612 and WQ_Logs(n0, "point=contact result=seeded") == 1, "a contact point: taken (rounded)");
	L = TRF.clock.legs;
	-- Each wreck system seeds when it is ws (debris6 from chapter 6), a candidate that is not ws does not.
	bad = "";
	h.labels.CurrentQuest = "6_1";
	for k, e in {{"callipso", "debris6"}, {"debris6", "golkonda"}, {"golkonda", "callipso"}} do
		TRF_Sv_BeforeJump();
		TRF.sv.b = {}; TRF.sv.c = nil;
		T_Enter("kron");
		WQ_At(30, {r=1, ws=V_Idx(e[1]), ql=30});
		T_Enter(e[2]);
		local n1 = WQ_QRecs();
		T_Enter(e[1]);
		local n2, q2 = WQ_QRecs();
		if n1 ~= 0 or n2 ~= 1 or q2.s ~= V_Idx(e[1]) then bad = bad.." "..e[1]; end;
	end;
	h.labels.CurrentQuest = "5_1";
	HOST_Check(bad == "", "callipso, debris6 (chapter 6) and golkonda each seed as ws; another candidate does not"..bad);
	L = TRF.clock.legs;
	-- TRF_Sv_Fix keeps q on records and carry and prefers the q record at the per-system and b_max caps (order kept).
	TRF.sv.b = {WQ_SvRec(V_Idx("golkonda"), 1, L), WQ_SvRec(V_Idx("heos"), 1, L), WQ_SvRec(V_Idx("xk10"), 1, L), WQ_SvRec(V_Idx("lidau"), 1, L),
		WQ_SvRec(V_Idx("golkonda"), 1, L, {q=1}), WQ_SvRec(V_Idx("callipso"), 1, L, {q=1})};
	TRF.sv.c = {n=2, cr=10, pc=0, s1=V_Idx("golkonda"), f=0, lg=L, q=1};
	TRF_Sv_Fix();
	local o = "";
	for i = 1, getn(TRF.sv.b) do o = o..TRF_SvName(TRF.sv.b[i].s)..":"..tostring(TRF.sv.b[i].q).."," end;
	HOST_Check(o == "heos:nil,xk10:nil,golkonda:1,callipso:1," and TRF.sv.c.q == 1, "Fix: q kept on records and carry, the q records win the per-system and b_max caps ("..o..")");
	TRF.sv.b = {WQ_SvRec(V_Idx("heos"), 1, L, {q=7})};
	TRF.sv.c.q = 2;
	TRF_Sv_Fix();
	HOST_Check(TRF.sv.b[1].q == nil and TRF.sv.c.q == nil, "Fix: q other than 1 dropped");
	-- TRF_SvRoom: an ordinary crew merged into a quest carry keeps q (its pay adds).
	TRF.sv.c = {n=1, cr=0, pc=0, s1=V_Idx("golkonda"), f=0, lg=L, q=1};
	TRF.sv.b = {WQ_SvRec(V_Idx("heos"), 1, L, {pf=700})};
	TRF_SvPick(1, TRF.sv.b[1], 1, 0, TRF_SvTune());
	c = TRF.sv.c;
	HOST_Check(c.q == 1 and c.n == 2 and c.cr == 700 and c.s2 == V_Idx("heos"), "an ordinary pod into a quest carry: q kept, its pay added");
	-- The off-screen slaver roll skips a quest record.
	TRF.sv.b = {WQ_SvRec(V_Idx("heos"), 1, L, {q=1}), WQ_SvRec(V_Idx("xk10"), 1, L)};
	h.cfg.tune = {sv_slave_off=100};
	local et = TRF_EffTier;
	TRF_EffTier = function() return 3; end;
	TRF_Sv_RegionTick(TRF.clock.legs);
	TRF_EffTier = et;
	h.cfg.tune = {};
	HOST_Check(TRF.sv.b[1].n == 1 and TRF.sv.b[1].sl == 0 and TRF.sv.b[2].sl == 1, "slaver roll: the quest record kept, an ordinary one taken");
	-- Dump: q marks.
	TRF.sv.b = {WQ_SvRec(V_Idx("heos"), 1, L, {q=1})};
	TRF.sv.c = {n=1, cr=0, pc=0, s1=V_Idx("heos"), f=0, lg=L, q=1};
	n0 = S_Mark();
	TRF_Sv_Dump();
	HOST_Check(S_Logs(n0, "beacons=heos:1/1/0/"..L.."/2/0/0q carried=1 credits=0 pirate_credits=0 carried_quest=true") == 1, "survive dump: q record and carry marked");
	TRF.sv = nil;
	HOST_Check(HOST_Reserved(TRF, "TRF") == "", "no reserved key");
end;

-- d: the fence and the patrol board, the logbook, repair, size ------------------------------------

function T_WQ_D()
	local h = HOST();
	WQ_Begin("golkonda", "5_1");
	local g = V_Idx("golkonda");
	local P = TRF_PlReg();
	local lb, ll = "", "";
	for i = 1, getn(P.dock.pir.box) do lb = lb..P.dock.pir.box[i].o..":"..TRF_PlName(P.dock.pir.box[i].f)..","; end;
	for i = 1, getn(P.dock.patrol.line) do ll = ll..P.dock.patrol.line[i].o..":"..TRF_PlName(P.dock.patrol.line[i].f)..","; end;
	HOST_Check(WQ_Has(lb, "300:TRF_Wq_PirBox,") and WQ_Has(ll, "40:TRF_Sh_PatrolLine,45:TRF_Wq_PatrolLine,50:"), "pirate box 300, patrol line 45 ("..lb.." "..ll..")");
	-- The clue region: the slot of XB-13.
	local bad = "";
	for k, nm in {"golkonda", "callipso", "xb13", "debris6"} do if not TRF_WqClueRg(V_Idx(nm)) then bad = bad.." "..nm; end; end;
	for k, nm in {"gaoba", "elio", "kadi"} do if TRF_WqClueRg(V_Idx(nm)) and TRF_RgOf(V_Idx(nm)) ~= TRF_RgOf(V_Idx("xb13")) then bad = bad.." "..nm; end; end;
	HOST_Check(bad == "" and TRF_RgOf(g) == TRF_RgOf(V_Idx("xb13")), "clue region: golkonda, callipso, xb13, debris6 in the region of XB-13 (TRF_RgOf)"..bad);
	-- Step 30: no fence box.
	local R = WQ_At(30, {r=1, ws=g, ql=30});
	WQ_Visit();
	local d = WQ_PirDock();
	HOST_Check(not (d.box and WQ_Has(d.box.text, "Marlin papers")), "step 30: no fence box");
	-- Step 40: the fence box with the price round(0.4 x TRF_PayN).
	R = WQ_At(40, {r=1, ws=g, ql=40});
	local price = floor(0.4 * TRF_PayN(g) + 0.5);
	WQ_Visit();
	local n0 = S_Mark();
	d = WQ_PirDock();
	HOST_Check(d.nb == 1 and d.box.text == TRF_Txt("wqfence", tostring(price)) and WQ_Has(d.box.text, "Cost you "..price.." cr.") and price > 0
		and WQ_Logs(n0, "event=fence system=golkonda price="..price.." result=shown") == 1, "step 40 at a Golkonda pirate dock: the fence box, price "..price);
	-- Cancel: nothing; the box again at the next docking.
	PC_Press(d, "cancel");
	HOST_Check(R.s == 40 and WQ_Logs(n0, "event=clue via=fence system=golkonda result=declined") == 1, "Cancel: step 40");
	WQ_Visit();
	d = WQ_PirDock();
	HOST_Check(d.nb == 1 and WQ_Has(d.box.text, "Marlin papers"), "the box again at the next docking");
	-- OK with the wallet emptied after the box opened: the poor line, step 40.
	h.credits = price - 1;
	local s = PC_Press(d, "ok");
	HOST_Check(R.s == 40 and h.credits == price - 1 and WQ_Has(s, TRF_Txt("wqfencepoor")) and WQ_Logs(n0, "event=clue via=fence system=golkonda cost="..price.." result=poor reason=short") == 1,
		"OK without the credits: the poor line, nothing taken");
	-- Cannot pay: no box.
	WQ_Visit();
	n0 = S_Mark();
	d = WQ_PirDock();
	HOST_Check(not (d.box and WQ_Has(d.box.text, "Marlin papers")) and WQ_Logs(n0, "event=fence system=golkonda price="..price.." result=none reason=poor") == 1, "wallet below the price: no box");
	-- OK: the price through TRF_Charge, step 50, the reply, the logbook at wqd50.
	h.credits = 1000000;
	WQ_Visit();
	n0 = S_Mark();
	d = WQ_PirDock();
	s = PC_Press(d, "ok");
	HOST_Check(R.s == 50 and h.credits == 1000000 - price and WQ_Has(s, TRF_Txt("wqfenceok")) and WQ_Logs(n0, "event=clue via=fence system=golkonda cost="..price.." result=ok") == 1
		and S_Logs(n0, "module=region event=charge reason=wq amount="..price) == 1 and h.qlog.trf_wq.d == "#TRF_wqd50" and WQ_Has(TRF_Txt("wqd50"), "XB-13"),
		"OK: credits - "..price.." (TRF_Charge why wq), step 50, the reply, logbook wqd50");
	WQ_Visit();
	d = WQ_PirDock();
	HOST_Check(not (d.box and WQ_Has(d.box.text, "Marlin papers")), "step 50: no fence box");
	-- Outside the region of XB-13: no box.
	T_Enter("gaoba");
	R = WQ_At(40, {r=1, ws=g, ql=40});
	n0 = S_Mark();
	d = WQ_PirDock();
	HOST_Check(not (d.box and WQ_Has(d.box.text, "Marlin papers")) and WQ_Logs(n0, "event=fence system=gaoba price=0 result=none reason=region") == 1, "gaoba: no fence box (region)");
	-- The patrol board: silent at rung 0, the clue at rung 1 (the system's trade station), step 50.
	T_Enter("golkonda");
	R = WQ_At(40, {r=1, ws=g, ql=40});
	TRF.stn = {};
	WQ_Visit();
	n0 = S_Mark();
	local m0, s0 = getn(h.msgs), getn(h.screen);
	d = WQ_PatDock();
	HOST_Check(R.s == 40 and not WQ_Has(WQ_Said(m0, s0), "Patrol board") and WQ_Logs(n0, "event=clue via=patrol system=golkonda rung=0 result=none reason=rung") == 1,
		"patrol board at rung 0: silent");
	TRF.stn[TRF_Stn_Key(g, 1)] = {st=1, lg=TRF.clock.legs};
	WQ_Visit();
	n0 = S_Mark();
	m0, s0 = getn(h.msgs), getn(h.screen);
	d = WQ_PatDock();
	HOST_Check(R.s == 50 and WQ_Has(WQ_Said(m0, s0), TRF_Txt("wqpatrol")) and WQ_Logs(n0, "event=clue via=patrol system=golkonda cost=0 rung=1 result=ok") == 1
		and h.qlog.trf_wq.d == "#TRF_wqd50", "patrol board at rung 1: the clue, step 50, logbook wqd50");
	TRF.std.heat = 5;
	R = WQ_At(40, {r=1, ws=g, ql=40});
	HOST_Check(TRF_WqRung(g) == 0, "heat 5 caps the effective rung to 0");
	TRF.std.heat = 0;
	-- The logbook and the reconcile at each step (ClearQuests at a mission start).
	bad = "";
	for k, st in {30, 40, 50} do
		R = WQ_At(st, {r=1, ws=g});
		ClearQuests();
		TRF_Wq_OnActivate();
		local want = "#TRF_wqd"..st;
		if not h.qlog.trf_wq or h.qlog.trf_wq.d ~= want or R.ql ~= st then bad = bad.." "..st; end;
	end;
	HOST_Check(bad == "", "reconcile after ClearQuests at steps 30, 40, 50"..bad);
	-- Repair: ws at steps 30 and 40 only, a wreck system only; a missing ws at 30 picked again; k 0..7.
	local legs = TRF.clock.legs;
	TRF.wq = {s=30, r=1, k=7, sd=77, ws=V_Idx("gaoba")};
	TRF_Wq_Fix();
	R = TRF.wq;
	HOST_Check(R.ws == WQ_WsOf(77, 5) and R.k == 3, "s 30, ws not a wreck system: picked again (chapter 5, bit 4 cleared)");
	TRF.wq = {s=40, r=1, k=5, sd=77, ws=V_Idx("gaoba")};
	TRF_Wq_Fix();
	HOST_Check(TRF.wq.ws == nil and TRF.wq.k == 5, "s 40, a bad ws: dropped; k 5 kept");
	TRF.wq = {s=40, r=1, sd=77, ws=V_Idx("callipso")};
	TRF_Wq_Fix();
	local k40 = TRF.wq.ws;
	TRF.wq = {s=50, r=1, sd=77, ws=V_Idx("callipso"), k=9};
	TRF_Wq_Fix();
	HOST_Check(k40 == V_Idx("callipso") and TRF.wq.ws == nil and TRF.wq.k == 0, "s 40 keeps a wreck system; s 50 drops ws; k 9 dropped");
	-- Dump and size: the record at its widest with ws.
	R = WQ_At(30, {r=1, ws=g, ql=30});
	n0 = S_Mark();
	TRF_Wq_Dump();
	HOST_Check(WQ_Logs(n0, "event=dump step=30 ") == 1 and WQ_Logs(n0, "wreck_system=golkonda") == 1, "dump: the wreck system");
	TRF.wq = {v=1, s=90, k=7, n=9, dc=-9999999, cd=-9999999, sd=9999, lv=1, r=3, p=1, ql=90, ws=999};
	local z = HOST_SaveSize(TRF.wq);
	HOST_Check(z <= 280, "TRF.wq at its widest with ws: "..z.." bytes <= 280");
	HOST_Check(HOST_Reserved(TRF, "TRF") == "", "no reserved key");
end;

-- e: the clan hold at XB-13 (step 3) ------------------------------------------------------------

-- The live guard ships of the hold (labels trf_wqg_<j>).
function WQ_Guard()
	local n, l = 0, {};
	for j = 1, 5 do
		local o = HOST().objs["trf_wqg_"..j];
		if o and o.alive then n = n + 1; tinsert(l, o); end;
	end;
	return n, l;
end;

-- The quest record of XB-13 in TRF.sv.b, or nil.
function WQ_XbRec()
	local x = V_Idx("xb13");
	if type(TRF.sv) ~= "table" or type(TRF.sv.b) ~= "table" then return nil; end;
	for i = 1, getn(TRF.sv.b) do if TRF.sv.b[i].q == 1 and TRF.sv.b[i].s == x then return TRF.sv.b[i]; end; end;
	return nil;
end;

-- Every guard ship killed through its died trigger.
function WQ_KillGuard()
	local n = 0;
	for j = 1, 5 do
		local o = HOST().objs["trf_wqg_"..j];
		if o and o.alive then o.alive = nil; HOST_Fire("died", "TRF_Wq_GuardDied("..j..","); n = n + 1; end;
	end;
	return n;
end;

-- Every pod of the XB-13 record picked up (one pickup per call of WQ_ToPod: the record packs its pods).
function WQ_PickAll(k)
	local x = V_Idx("xb13");
	for i = 1, k or 3 do
		local b = WQ_XbRec();
		if b and b.n > 0 then WQ_ToPod(x, 1); end;
	end;
end;

function T_WQ_E()
	local h = HOST();
	-- sv_pick_r 10: one pod per pickup (the pods lie 25 units apart).
	WQ_Begin("golkonda", "5_1", {enable_survivors=1, sv_seeded=0, cap_enable=1, tune={sv_pick_r=10}});
	TRF.sv = nil;
	local x = V_Idx("xb13");
	local slot = TRF_RgOf(x);
	local K = TRF_WqK();
	-- The hold points: the hulk 200 units off the map's base site (950, 0, 400), clear of xb13's four stash slots; the pods
	-- 120 units from the hulk.
	local bs = TRF_Map().sys[x].bs;
	local hp, pp = TRF_WqHoldPt(K.hk_off), TRF_WqHoldPt(K.pod_off);
	local sl = TRF_ShSlots("xb13");
	local dmin = 99999;
	for i = 1, getn(sl) do
		local dx, dy, dz = hp.x - sl[i][1], hp.y - sl[i][2], hp.z - sl[i][3];
		dmin = min(dmin, sqrt(dx * dx + dy * dy + dz * dz));
	end;
	HOST_Check(bs.x == 950 and bs.z == 400 and hp.x == 750 and hp.z == 400 and pp.x == 750 and pp.z == 280 and getn(sl) == 4 and dmin >= 150,
		"hold points: hulk (750, 0, 400) from the base site (950, 0, 400), pods (750, 0, 280); nearest stash slot "..floor(dmin).." >= 150");
	-- A slot next to the hulk point turns the offset (TRF_ShSlots stub): the first clear direction.
	local sl0 = TRF_ShSlots;
	TRF_ShSlots = function(nm) return {{750, 0, 400}}; end;
	local tp = TRF_WqHoldPt(K.hk_off);
	TRF_ShSlots = sl0;
	HOST_Check(tp.x == 950 and tp.z == 200, "a stash slot at the hulk point: the offset turned 90 degrees ("..tp.x..", "..tp.z..")");
	-- Mode 1: the clan's active base at xb13; the region captain tipped (r.ti, r.seen, cg); the open-band line names him.
	TRF.cap = nil;
	TRF_Cap_Fix();
	local cr = TRF.cap and TRF.cap[slot];
	HOST_Check(type(cr) == "table" and cr.st == 1, "the region captain of XB-13 lives (st 1)");
	if type(cr) ~= "table" then return; end;
	TRF.clan[slot].sc = 60;
	TRF.base = {{s=x, k=2, h=9, t=TRF.clock.legs, w=0}};
	local R = WQ_At(50, {r=1, ql=50});
	local n0 = S_Mark();
	T_Jump("xb13");
	R = TRF.wq;
	local L = TRF.clock.legs;
	cr = TRF.cap[slot];
	HOST_Check(R.m == 1 and R.cg == cr.gen and cr.seen == x and (cr.ti == L or cr.ti == nil)
		and WQ_Logs(n0, "event=hold system=xb13 mode=1 captain_slot="..slot.." captain_generation="..cr.gen.." result=tipped") == 1
		and S_Logs(n0, "module=captain event=intel slot="..slot.." generation="..cr.gen.." seen=xb13 result=tipped reason=quest") == 1
		and S_Logs(n0, "module=captain event=plan slot="..slot) >= 1 and S_Logs(n0, "via=tip") >= 1,
		"mode 1 (active base): the captain tipped to xb13 (seen, ti; his plan at chance 100 via the tip), cg = his generation");
	local m0, s0 = getn(h.msgs), getn(h.screen);
	T_Tick(30, 0.5);
	local said = WQ_Said(m0, s0);
	local who = TRF_Cap_NameOf(slot);
	HOST_Check(WQ_Has(said, TRF_Txt("wqband", who)) and WQ_Has(TRF_Txt("wqband", who), who.." says the Marlin's people") and not WQ_Has(said, TRF_Txt("wqmoved"))
		and WQ_Objs("TRF_WQ_HULK") == 0 and WQ_Guard() == 0, "the open-band line names the captain ("..who.."); no hulk, no guard in mode 1");
	-- Without a living captain: the clan speaks; the tip is refused (state).
	TRF.cap[slot].st = 4;
	n0 = S_Mark();
	T_Jump("golkonda");
	R = TRF.wq;
	T_Jump("xb13");
	R = TRF.wq;
	m0, s0 = getn(h.msgs), getn(h.screen);
	T_Tick(30, 0.5);
	HOST_Check(R.m == 1 and R.cg == nil and WQ_Has(WQ_Said(m0, s0), TRF_Txt("wqband", "The Golkonda clan"))
		and WQ_Logs(n0, "event=hold system=xb13 mode=1 captain_slot="..slot.." result=base reason=captain:state_4") == 1,
		"no living captain: no tip, cg dropped, 'The Golkonda clan says'");
	TRF.cap[slot].st = 1;
	-- The base destroyed by the player in view: the hook runs before the record changes, 2-3 pods, the master's line.
	m0, s0 = getn(h.msgs), getn(h.screen);
	n0 = S_Mark();
	TRF_BaseDestroyed(x, "player");
	local b = WQ_XbRec();
	local pn = 2 + TRF_WqM(TRF_WqHash(R.sd, 17, 0), 2);
	HOST_Check(TRF.base[1].k == 3 and b and b.n == pn and b.pf == 0 and b.src == 2 and R.pn == pn and R.pk == 0 and R.s == 50
		and WQ_Has(WQ_Said(m0, s0), TRF_Txt("wqmaster")) and WQ_Logs(n0, "event=hold system=xb13 mode=1 by=player off_screen=false result=base_gone") == 1
		and WQ_Logs(n0, "event=hold system=xb13 mode=1 beacon=") == 1 and WQ_Logs(n0, "pods="..pn.." via=base_gone result=pods") == 1
		and S_Logs(n0, "module=survive event=seed system=xb13 kind=quest source=2 pods="..pn.." pay=0 point=given result=beacon") == 1
		and WQ_Objs("TRF_SVP_"..x) == pn and b.x == 750 and b.z == 280, "the base destroyed by the player: "..pn.." quest pods at (750, 0, 280), the master's line, pn "..pn);
	-- Pickups: pk counts; the last pod gives step 60 (logbook wqd60).
	n0 = S_Mark();
	WQ_ToPod(x, 1);
	HOST_Check(R.pk == 1 and R.s == 50 and TRF.sv.c and TRF.sv.c.q == 1 and WQ_Logs(n0, "event=crew system=xb13 picked=1 pods="..pn.." left="..(pn - 1).." result=picked") == 1,
		"first pod aboard: pk 1, step 50");
	WQ_PickAll(3);
	HOST_Check(R.pk == pn and R.s == 60 and WQ_Logs(n0, "event=crew system=xb13 picked="..pn.." pods="..pn.." result=aboard") == 1
		and WQ_Logs(n0, "event=step step_before=50 step_after=60 reason=aboard") == 1 and h.qlog.trf_wq.d == "#TRF_wqd60"
		and WQ_Has(TRF_Txt("wqd60"), "Hand them in"), "all pods aboard: step 60, logbook wqd60");
	-- An off-screen loss (sweep) leaves mode 1 now; the next entry switches to mode 3 with the line wqmoved.
	TRF.sv = nil;
	TRF.base = {{s=x, k=2, h=9, t=TRF.clock.legs, w=0}};
	T_Jump("golkonda");
	R = TRF.wq;
	R = WQ_At(50, {r=1, ql=50, m=1});
	n0 = S_Mark();
	TRF_BaseDestroyed(x, "sweep");
	HOST_Check(R.m == 1 and R.pn == nil and WQ_XbRec() == nil and WQ_Logs(n0, "event=hold system=xb13 mode=1 by=sweep off_screen=true result=base_gone") == 1,
		"base lost off-screen (sweep): no pods, mode 1 kept until the next entry");
	n0 = S_Mark();
	T_Jump("xb13");
	R = TRF.wq;
	m0, s0 = getn(h.msgs), getn(h.screen);
	T_Tick(30, 0.5);
	said = WQ_Said(m0, s0);
	local ng, gl = WQ_Guard();
	local hk = h.objs["TRF_WQ_HULK"];
	HOST_Check(R.m == 3 and R.cg == nil and WQ_Has(said, TRF_Txt("wqmoved")) and WQ_Has(said, TRF_Txt("wqband", TRF_Cap_NameOf(slot)))
		and hk and hk.alive and hk.tpl == "Btransport_destroyed" and hk.pos.x == 750 and hk.pos.z == 400
		and ng >= 3 and ng <= 5 and WQ_Logs(n0, "event=hold system=xb13 mode=3 x=750 z=400 hulk=true marker=true tier=3 ") == 1
		and WQ_Logs(n0, "ship_count="..ng.." ships_asked=4 result=spawned") == 1 and S_Logs(n0, "module=plumb event=marker owner=wq label=TRF_WQ_HK result=added") == 1,
		"next entry: mode 3, 'They moved the crew to a hulk at XB-13.', the hulk (Btransport_destroyed) at (750, 0, 400) with its marker, a tier-3 guard of "..ng.." ships (NORMAL asks 4)");
	-- The hulk is no trader record (no traffic pay, help or heat).
	local hrec = nil;
	for id, r in TRF.live.tr do if r.wq then hrec = id; end; end;
	HOST_Check(hrec == nil, "the hulk is no trader record");
	-- Guard counts by difficulty: EASY 3, HARD 5 asked (the row's entries cap the ships).
	h.diff = HARD;
	T_Jump("golkonda");
	R = TRF.wq;
	n0 = S_Mark();
	T_Jump("xb13");
	R = TRF.wq;
	local ngh = WQ_Guard();
	h.diff = EASY;
	T_Jump("golkonda");
	R = TRF.wq;
	local n1 = S_Mark();
	T_Jump("xb13");
	R = TRF.wq;
	local nge = WQ_Guard();
	h.diff = NORMAL;
	HOST_Check(WQ_Logs(n0, "ships_asked=5 result=spawned") == 1 and WQ_Logs(n1, "ships_asked=3 result=spawned") == 1 and nge == 3 and ngh >= nge and ngh <= 5,
		"guard ships by difficulty: HARD asks 5 ("..ngh.."), EASY 3 ("..nge..")");
	-- A jump deletes the hulk and the guard; the next entry builds them again.
	n0 = S_Mark();
	T_Jump("golkonda");
	R = TRF.wq;
	HOST_Check(WQ_Logs(n0, "event=hold deleted_count=3 hulk=true result=void reason=jump") == 1, "jump: the hulk and the guard deleted (void)");
	T_Jump("xb13");
	R = TRF.wq;
	ng = WQ_Guard();
	-- Every guard ship dead (their died triggers): the pods at the hulk, the master's line.
	m0, s0 = getn(h.msgs), getn(h.screen);
	n0 = S_Mark();
	local nk = WQ_KillGuard();
	b = WQ_XbRec();
	HOST_Check(nk == ng and b and R.pn == pn and b.n == pn and WQ_Has(WQ_Said(m0, s0), TRF_Txt("wqmaster"))
		and WQ_Logs(n0, "event=hold system=xb13 mode=3 kill_count="..ng.." ship_count="..ng.." via=died result=guard_dead") == 1
		and WQ_Logs(n0, "via=guard_dead result=pods") == 1 and S_Logs(n0, "module=plumb event=marker owner=wq deleted_count=1 result=cleared") == 1,
		"guard dead ("..ng.." died triggers): "..pn.." pods, the master's line, the hulk marker cleared");
	-- A jump before any pod is aboard: s 50, the record keeps its pods (placed again on entry), no second guard.
	n0 = S_Mark();
	T_Jump("golkonda");
	R = TRF.wq;
	T_Jump("xb13");
	R = TRF.wq;
	HOST_Check(R.s == 50 and R.pn == pn and WQ_XbRec() and WQ_Objs("TRF_SVP_"..x) == pn and WQ_Guard() == 0 and WQ_Logs(n0, "result=spawned") == 0,
		"a jump with no pod aboard: step 50, the pods placed again, no new guard");
	-- A partial carry and a jump: the crew aboard goes home as it is (the pods left are dropped), step 60.
	WQ_ToPod(x, 1);
	n0 = S_Mark();
	T_Jump("golkonda");
	R = TRF.wq;
	HOST_Check(R.s == 60 and R.pk == 1 and WQ_XbRec() == nil and TRF.sv.c and TRF.sv.c.q == 1 and TRF.sv.c.n == 1
		and WQ_Logs(n0, "event=crew system=xb13 picked=1 pods="..pn.." result=partial reason=entry") == 1
		and S_Logs(n0, "module=survive event=expire system=xb13 ") == 1 and S_Logs(n0, "module=survive event=expire system=xb13 beacon=1 pods="..(pn - 1).." ") == 1
		and WQ_Logs(n0, "event=step step_before=50 step_after=60 reason=partial") == 1, "partial carry, then a jump: step 60, the pods left dropped");
	-- The record gone with no pod aboard: the hold starts again (pn and pk go).
	R = WQ_At(50, {r=1, ql=50, m=3, pn=3, pk=0});
	TRF.sv = nil;
	n0 = S_Mark();
	T_Jump("xb13");
	R = TRF.wq;
	HOST_Check(R.pn == nil and R.m == 3 and WQ_Guard() >= 3 and WQ_Logs(n0, "event=crew system=xb13 pods=3 result=reset reason=gone") == 1
		and WQ_Logs(n0, "result=spawned") == 1, "pods gone with none aboard: the hold starts again (a new guard)");
	-- The 1 s step counts the guard through its handles (a death no trigger reported).
	ng, gl = WQ_Guard();
	for i = 1, getn(gl) do gl[i].alive = nil; end;
	n0 = S_Mark();
	T_Tick(4, 0.5);
	HOST_Check(R.pn == pn and WQ_Logs(n0, "via=step result=guard_dead") == 1, "guard dead without its triggers: the 1 s step finds it, pods");
	-- A load in XB-13 before the pods: the hold of the visit is void (the saved hulk and guard found by label deleted).
	T_Jump("golkonda");
	R = TRF.wq;
	TRF.sv = nil;
	R = WQ_At(50, {r=1, ql=50, m=3});
	T_Jump("xb13");
	R = TRF.wq;
	ng = WQ_Guard();
	n0 = S_Mark();
	T_SaveLoad();
	R = TRF.wq;
	HOST_Check(WQ_Guard() == 0 and WQ_Objs("TRF_WQ_HULK") == 0 and R.s == 50 and WQ_Logs(n0, "event=hold deleted_count="..ng.." hulk=true result=void reason=load") == 1,
		"load in XB-13: the guard and the hulk deleted (void until the next entry)");
	-- Gates: a mission, the strict deny list, another system, enable_wq 0.
	V_QuestOn();
	n0 = S_Mark();
	WQ_Visit();
	HOST_Check(WQ_Logs(n0, "event=hold system=xb13 result=none reason=mission") == 1, "a mission: no hold");
	V_QuestOff();
	-- A per-feature deny entry wq = 0 for xb13 (the strict gate's TRF_DenyEntry).
	local de = TRF_DenyEntry;
	TRF_DenyEntry = function(nm) if nm == "xb13" then return {wq=0, why="host"}; end; return %de(nm); end;
	TRF_H().loc = nil; TRF.live.qa = nil; TRF.live.qai = nil;
	n0 = S_Mark();
	WQ_Visit();
	HOST_Check(WQ_Logs(n0, "event=hold system=xb13 result=none reason=strict:deny_wq") == 1, "a deny entry wq = 0 (strict gate): no hold");
	TRF_DenyEntry = de;
	TRF_H().loc = nil; TRF.live.qa = nil; TRF.live.qai = nil;
	n0 = S_Mark();
	T_Jump("golkonda");
	R = TRF.wq;
	HOST_Check(WQ_Logs(n0, "event=hold system=golkonda result=none reason=system") == 1, "golkonda: no hold (system)");
	-- The hook ignores other bases and other steps.
	R = WQ_At(40, {r=1, ws=V_Idx("golkonda"), ql=40});
	TRF.base = {{s=x, k=2, h=9, t=TRF.clock.legs, w=0}};
	n0 = S_Mark();
	TRF_BaseDestroyed(x, "sweep");
	HOST_Check(WQ_Logs(n0, "event=hold") == 0, "step 40: the base hook does nothing");
	TRF.base = {};
end;

-- f: the charter office (step 4), the logbook end, repair, size ----------------------------------

function T_WQ_F()
	local h = HOST();
	WQ_Begin("golkonda", "5_1", {enable_survivors=1, sv_seeded=0});
	TRF.sv = nil;
	local x = V_Idx("xb13");
	-- Hand-in at s 60: the normal survivor standing (help +1), no credits, step 70, the clerk's line, logbook wqd70.
	local R = WQ_At(60, {r=1, ql=60, pn=3, pk=3});
	TRF.sv = {b={}, c={n=3, cr=0, pc=0, s1=x, f=0, lg=TRF.clock.legs, q=1}, st={res=0, sold=0, lost=0}, r={}, sd=1};
	TRF_Sv_Fix();
	local cr0, h0 = h.credits, TRF.std.help;
	local n0 = S_Mark();
	WQ_Visit();
	local d = PC_Dock();
	HOST_Check(R.s == 70 and TRF.sv.c == nil and h.credits == cr0 and TRF.std.help == h0 + 1 and WQ_Has(d.scr, TRF_Txt("wqhome"))
		and WQ_Logs(n0, "event=crew system=golkonda carried=3 picked=3 pods=3 result=handed") == 1 and WQ_Logs(n0, "event=step step_before=60 step_after=70 reason=handed") == 1
		and h.qlog.trf_wq.d == "#TRF_wqd70" and WQ_Has(TRF_Txt("wqhome"), "brought the crew home"), "hand-in at s 60: help +1, no credits, step 70, the clerk's line, logbook wqd70");
	-- A partial crew handed in at s 50: the pods left go, step 60, then 70.
	R = WQ_At(50, {r=1, ql=50, m=3, pn=3, pk=1});
	TRF.sv = {b={{s=x, si=0, x=750, y=0, z=280, n=2, n0=3, f=0, nm=0, lg=TRF.clock.legs, src=2, sl=0, pf=0, pp=0, q=1}},
		c={n=1, cr=0, pc=0, s1=x, f=0, lg=TRF.clock.legs, q=1}, st={res=0, sold=0, lost=0}, r={}, sd=1};
	TRF_Sv_Fix();
	n0 = S_Mark();
	PC_Visit();
	d = PC_Dock();
	HOST_Check(R.s == 70 and WQ_XbRec() == nil and WQ_Logs(n0, "result=partial reason=handed") == 1 and WQ_Logs(n0, "step_before=50 step_after=60 reason=partial") == 1
		and WQ_Logs(n0, "step_before=60 step_after=70 reason=handed") == 1, "a partial crew handed in at s 50: the pods left dropped, step 60 then 70");
	-- The unlock gate (TRF_FrBuyGate, the first ship): quest below s 70 (help 99 does not count), s 70 and 80 pass;
	-- enable_wq 0 restores help >= 5.
	T_Enter("debris6");
	local dx = TRF_CurIdx();
	TRF.std.help = 99;
	local g = {};
	TRF.wq = nil; g[1] = TRF_FrBuyGate(dx);
	R = WQ_At(60); g[2] = TRF_FrBuyGate(dx);
	R = WQ_At(70); g[3] = TRF_FrBuyGate(dx);
	R = WQ_At(80); g[4] = TRF_FrBuyGate(dx);
	h.cfg.enable_wq = 0;
	R = WQ_At(60);
	TRF.std.help = 4; g[5] = TRF_FrBuyGate(dx);
	TRF.std.help = 5; g[6] = TRF_FrBuyGate(dx);
	h.cfg.enable_wq = 1;
	HOST_Check(g[1] == "quest" and g[2] == "quest" and g[3] == nil and g[4] == nil and g[5] == "help" and g[6] == nil,
		"TRF_FrBuyGate: quest without the record and at s 60, s 70 and 80 pass; enable_wq 0: help 4 refused, help 5 passes");
	-- s 70 at a loop stop: the box text fwboxq (no first-offer rumour); OK buys the ship and gives s 80, the logbook done.
	TRF.std.help = 5;
	R = WQ_At(70, {r=1, ql=70});
	TRF.co = nil;
	WQ_Visit();
	n0 = S_Mark();
	d = PC_Dock();
	HOST_Check(d.nb == 1 and WQ_Has(d.box.text, "does not forget a carrier who brings his people back") and WQ_Has(d.box.text, "Register a hull under Wolves Freight for ")
		and not WQ_Has(d.box.text, "Cover premiums") and d.box.title == TRF_Txt("fwboxtitle"), "s 70: the purchase box reads fwboxq");
	local s = PC_Press(d, "ok");
	local L = TRF.clock.legs;
	HOST_Check(R.s == 80 and R.wd == L and TRF_FrCount() == 1 and h.quests.trf_wq == QUEST_DONE and h.qlog.trf_wq.d == "#TRF_wqd80"
		and WQ_Logs(n0, "event=unlock system=debris6 leg="..L.." result=bought") == 1 and WQ_Logs(n0, "event=step step_before=70 step_after=80 reason=bought") == 1
		and WQ_Logs(n0, "event=logbook list=mission id=trf_wq state="..QUEST_DONE.." result=done") == 1, "OK: the ship bought, step 80, wd, the logbook entry wqd80 done");
	-- The done entry stays 9 legs and goes at the first entry 10 legs after wd; ClearQuests before then adds it again, done.
	TRF.clock.legs = L + 9;
	ClearQuests();
	TRF_Wq_OnActivate();
	local k9 = h.qlog.trf_wq and h.qlog.trf_wq.d == "#TRF_wqd80" and h.quests.trf_wq == QUEST_DONE;
	TRF.clock.legs = L + 10;
	n0 = S_Mark();
	TRF_Wq_OnActivate();
	HOST_Check(k9 and h.qlog.trf_wq == nil and R.ql == nil and R.s == 80 and WQ_Logs(n0, "event=reconcile id=trf_wq list=mission result=removed reason=enter") == 1,
		"the done entry: added again done after ClearQuests at 9 legs, removed 10 legs after wd");
	TRF.clock.legs = L;
	-- Cancel at s 70: s 80 as well, the freight decline cooldown starts.
	TRF.co = nil;
	R = WQ_At(70, {r=1, ql=70});
	WQ_Visit();
	n0 = S_Mark();
	d = PC_Dock();
	PC_Press(d, "cancel");
	HOST_Check(R.s == 80 and TRF_FrCount() == 0 and TRF.co and type(TRF.co.decl) == "table" and TRF.co.decl.sys == dx
		and WQ_Logs(n0, "result=declined") >= 1 and WQ_Logs(n0, "event=step step_before=70 step_after=80 reason=declined") == 1, "Cancel: step 80, the freight decline cooldown");
	-- OK without the credits: s 70 stays (the box with fwboxq again).
	TRF.co = nil;
	R = WQ_At(70, {r=1, ql=70});
	WQ_Visit();
	d = PC_Dock();
	h.credits = 10;
	PC_Press(d, "ok");
	h.credits = 1000000;
	HOST_Check(R.s == 70 and TRF_FrCount() == 0, "OK without the credits: step 70 stays");
	-- The Job log: the done state through TRF_JobState.
	WQ_Begin("debris6", "5_1", {jobs_log=1}, 1);
	R = WQ_At(70, {r=1});
	TRF_Wq_OnActivate();
	WQ_Visit();
	d = PC_Dock();
	PC_Press(d, "ok");
	local je = h.jl[HOST_JlFind("trf_wq") or 0];
	HOST_Check(R.s == 80 and je and je.d == "#TRF_wqd80" and je.s == QUEST_DONE and h.qlog.trf_wq == nil, "Job log: the entry wqd80 done (TRF_JobState)");
	-- Open question 12: at s 70 the parcel box steps aside while the purchase box opens (the board lists both rows).
	WQ_Begin("debris6", "5_1", {enable_parcels=1});
	R = WQ_At(70, {r=1, ql=70});
	WQ_Visit();
	n0 = S_Mark();
	d = PC_Dock();
	HOST_Check(d.nb == 1 and WQ_Has(d.box.text, "does not forget a carrier") and S_Logs(n0, "module=parcel event=offer system=debris6 result=none reason=wq_unlock") == 1
		and TRF_Wq_UnlockDue(TRF_CurIdx()) == 1, "s 70: the parcel box skipped (reason wq_unlock), the purchase box opens");
	PC_Press(d, "cancel");
	HOST_Check(TRF_Wq_UnlockDue(TRF_CurIdx()) == nil, "s 80: the parcel box is back");
	R = WQ_At(70, {r=1, ql=70});
	T_Enter("gaoba");
	HOST_Check(TRF_Wq_UnlockDue(TRF_CurIdx()) == nil, "s 70 at a station off the loop: the parcel box stays");
	-- Repair of the new fields: m (1, 3) and cg at s 50, pn (1..3) and pk (0..pn) at s 50 and 60, wd at s 80; s 90 kept.
	local legs = TRF.clock.legs;
	TRF.wq = {s=50, r=1, sd=7, m=3, cg=12, pn=3, pk=2, wd=5};
	TRF_Wq_Fix();
	local a = TRF.wq;
	TRF.wq = {s=50, r=1, sd=7, m=2, cg="x", pn=4, pk=1};
	TRF_Wq_Fix();
	local b = TRF.wq;
	TRF.wq = {s=60, r=1, sd=7, m=1, cg=3, pn=2, pk=3};
	TRF_Wq_Fix();
	local c = TRF.wq;
	TRF.wq = {s=80, sd=7, wd=legs, pn=2, m=1};
	TRF_Wq_Fix();
	local e = TRF.wq;
	TRF.wq = {s=80, sd=7, wd=legs + 5};
	TRF_Wq_Fix();
	local f = TRF.wq;
	TRF.wq = {s=90, sd=7, k=1};
	TRF_Wq_Fix();
	local z9 = TRF.wq;
	HOST_Check(a.m == 3 and a.cg == 12 and a.pn == 3 and a.pk == 2 and a.wd == nil and b.m == nil and b.cg == nil and b.pn == nil and b.pk == nil
		and c.m == nil and c.cg == nil and c.pn == 2 and c.pk == nil and e.wd == legs and e.pn == nil and e.m == nil and f.wd == nil and z9 and z9.s == 90,
		"repair: m and cg at s 50, pn and pk (0..pn) at 50 and 60, wd at 80 (not in the future); s 90 kept");
	-- Dump and size: the record at its widest with the new fields.
	R = WQ_At(50, {r=1, m=3, cg=999, pn=3, pk=2});
	n0 = S_Mark();
	TRF_Wq_Dump();
	HOST_Check(WQ_Logs(n0, "event=dump step=50 ") == 1 and WQ_Logs(n0, "mode=3 captain_generation=999 pods=3 picked=2") == 1, "dump: mode, captain generation, pods, picked");
	TRF.wq = {v=1, s=90, k=7, n=9, dc=-9999999, cd=-9999999, sd=9999, lv=1, r=3, p=1, ql=90, ws=999, m=3, cg=999, pn=3, pk=3, wd=-9999999};
	local zz = HOST_SaveSize(TRF.wq);
	HOST_Check(zz <= 390, "TRF.wq at its widest with the step 3-4 fields: "..zz.." bytes <= 390");
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
