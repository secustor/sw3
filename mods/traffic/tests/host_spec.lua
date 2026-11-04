-- Specialist answers scenarios (design/specialist-spec.md 11, A05) under stock Lua 4.0.1: TRF_SPC=a..g, run by run_host.sh as
-- its own entry point. a install (loader, module list, text keys, cfg and tune defaults and clamps, the dump, cfg spec 0),
-- b the specialist probe (order and rank, filters, a raising HasProperty, the mothership firmware with spc_ai 1 and 0,
-- the Hero's Intuition), c qualification (every gate of spec 5 and its skip reason, an open raid gives no menu), d the hail
-- flow (the raid end re-arm, the meeting trigger, the provider-only dialog menu with the label in a_p1 and the head, the
-- patch on paths C and A with Repairman and Expert Repairman, the unflee, help and the page, the pilot line by radio, by
-- screen fallback and from the firmware, help already paid, no specialist, the box chain, the extra hail beyond hail_max,
-- the slot overflow), e the SetHP fallback (spc_fb 1 with the hold guard on the poll and the HP trigger, spc_fb 0, a
-- raising SetHP, an unflee refused), f the next meeting (the pool bit at the exit write, the rebuild with res and spcmet,
-- the bit cleared by the next write, the corporation bits kept, a second patch without help), g save and repair
-- (TRF_Spc_Fix, the byte figures, a jump and a load drop the visit state, the RU file). The fence page's Intuition answer
-- (spec 6.8) is tested in host_wq.lua wq-g, which has the quest harness.
-- Loads host_station.lua up to its first scenario, as host_remark.lua does. Stubs in this file: squad pilots in
-- HOST().crew (SP_Crew: IsAlive, GetSide, IsCanSayReplica, Message, perks in props read by host_stubs' HasProperty), the
-- firmware's perks in HOST().ms_props, a lead's SetHP replaced to be ignored or to raise.

local f = openfile((getenv("TRF_TESTS") or "./").."host_station.lua", "r");
if not f then print("HOST FAIL host_spec.lua: cannot open host_station.lua"); exit(1); end;
local src = read(f, "*a");
closefile(f);
local cut = strfind(src, "\n-- a: install (12.1, 6.1)", 1, 1);
if not cut then print("HOST FAIL host_spec.lua: marker '-- a: install (12.1, 6.1)' missing in host_station.lua"); exit(1); end;
dostring(strsub(src, 1, cut), "host_station.lua");

-- Helpers ----------------------------------------------------------------------------------

-- Config of these runs: entry events and modules that spawn ships or claim the box off, raids on, escort contracts and
-- demand off, TT4 off (a tier 4 trader never qualifies; the menu of a plain trader is trade, head, trouble, boom), log 2, plus t.
function SP_Cfg(t)
	local c = {sweeps=0, sweep_ct=0, feq=0, staged=0, seed=0, queue=0, parked=0, voice_events=0, dconv=0, raids=1,
		carriers=0, po=0, bases=0, conv=0, enable_survivors=0, lad_enabled=0, charter=0, enable_scars=0, contracts=0,
		esc_flight=0, demand=0, warn=0, tt4=0, tier_cap=3, log=2, tune={}};
	if t then for k, v in t do c[k] = v; end; end;
	return c;
end;

function SP_Begin(ch, t)
	local h = HOST();
	h.labels.CurrentQuest = ch or "5_1";
	h.st_label = nil;
	h.crew = {};
	h.ms_props = nil;
	S_Begin("gredos", SP_Cfg(t));
	h.credits = 1000000;
	__sys_FTrader_3 = 0;
end;

-- Dialog mode (tune hail_box 2, hail_xml 1, an idle UI) or the box chain (hail_box 1); t: more tune keys.
function SP_Dlg(on, t)
	local h = HOST();
	local tu = {};
	if t then for k, v in t do tu[k] = v; end; end;
	if on then
		tu.hail_box = 2;
		h.cfg.hail_xml = 1;
		TRF_UiState = HOST_UiState;
		h.ui = 0;
	else
		h.cfg.hail_xml = nil;
		TRF_UiState = nil;
		h.ui = nil;
	end;
	h.cfg.tune = tu;
end;

-- Squad pilots for GetPilot: t = {<template> = {dead, side (default "Player"), csr (default 1), props, perr}}.
function SP_Crew(t)
	local h = HOST();
	h.crew = {};
	for tpl, e in t do
		local p = HOST_Pilot(tpl);
		p.alive = not e.dead; p.side = e.side or "Player"; p.csr = e.csr ~= 0; p.props = e.props or {}; p.props_err = e.perr;
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

-- A trader of path (default C) 40 from the mothership whose raid spawned; its lead at hpf (default 0.3) x hp0, then
-- TRF_Flee(fl, default hp); the raid ends how (default killed; "open" keeps it; "fake": a raid record 997 made and ended
-- by hand, as path A has no raid point in gredos, then trf_spec's raid end); np: the station approach point (a near one
-- makes the station the refuge). The trader was met before (r.ha set, as the announce does) unless HOST().sp_unmet.
-- Returns id, record, handles, raid id, lead; HOST().sp_ext the exit name before the flee.
function SP_Fled(path, fl, hpf, how, np)
	local h = HOST();
	V_ClearTr();
	T_Tick(2, 0.5);
	TRF.std.heat = 0;
	TRF.live.cbt = nil;
	TRF.live.hl = nil;
	local id = T_Spawn(path or "C");
	HOST_Want(id, "SP_Fled: a trader of path "..tostring(path or "C"));
	if not id then return nil; end;
	T_MoveTr(id, h.ms.pos.x + 40, h.ms.pos.y, h.ms.pos.z);
	local r, x = TRF.live.tr[id], TRF_H().tr[id];
	if not h.sp_unmet then r.ha = r.ha or TRF.clock.gt; end;
	local n, rh = 997, nil;
	if how == "fake" then
		if r.rdn then TRF_Rd_End(r.rdn, "cancel"); end;
		TRF.live.rd[n] = {n=n, id=id, st="come"};
		r.rdn = n;
	else
		n = V_Raid(id);
		HOST_Want(n, "SP_Fled: a raid armed on the trader");
		HOST_Fire("f_inside", "TRF_RaidGo("..n..",");
		rh = TRF_H().rd[n];
	end;
	local lead = TRF_GnLead(id);
	lead.hp = (hpf or 0.3) * r.hp0;
	h.sp_ext = r.ext;
	if np then x.np = np; end;
	TRF_Flee(id, fl or "hp");
	TRF.live.cbt = nil;
	if how == "fake" then
		TRF.live.rd[n].st = "end";
		TRF.live.rd[n].how = "killed";
		TRF_Spc_RaidEnd(id, n, "killed");
	elseif how ~= "open" then
		TRF_Rd_End(n, how or "killed");
		-- Killed: the raid ships are dead (the next raid spawns at the same point).
		if type(rh) == "table" and type(rh.sh) == "table" then for i = 1, getn(rh.sh) do rh.sh[i].alive = nil; end; end;
	end;
	return id, r, x, n, lead;
end;

-- Hail of trader id with the cooldown passed (via focus); the result of TRF_HailOpen.
function SP_Hail(id, via)
	local r = TRF.live.tr[id];
	if type(r.hlt) == "number" then r.hlt = r.hlt - 1000; end;
	TRF.live.cbt = nil;
	return TRF_HailOpen(id, via or "focus");
end;

-- Closes whatever the hail chain has open (dialog by Esc, box by Cancel).
function SP_End()
	local h = HOST();
	for i = 1, 8 do
		if not TRF.live.hl then return; end;
		local b = HOST_Box();
		if h.dlg and h.dlg.open then HOST_DlgEsc();
		elseif b and not b.done then HOST_Press("cancel"); end;
		T_Tick(3, 0.5);
	end;
end;

-- Qualification reason of trader id now ("ok" when it qualifies).
function SP_Q(id)
	local w = TRF_SpcQual(id, TRF.live.tr[id]);
	return w or "ok";
end;

-- Per-visit caches of the strict gate and the chapter, after a change of HOST().labels or quests.
function SP_QCache()
	TRF.live.qa = nil; TRF.live.qai = nil; TRF_H().loc = nil; TRF.live.gl = nil; TRF.live.sm = nil;
end;

-- Screen lines and radio lines after marks s0 / m0 joined by "|".
function SP_Scr(s0)
	local q, s = HOST().screen, "";
	for i = s0 + 1, getn(q) do s = s..q[i].t.."|"; end;
	return s;
end;
function SP_Msgs(m0)
	local q, s = HOST().msgs, "";
	for i = m0 + 1, getn(q) do s = s..tostring(q[i].tpl)..":"..q[i].t.."|"; end;
	return s;
end;

-- Text of the newest box, or nil.
function SP_BoxText()
	local b = HOST_Box();
	if b then return b.text; end;
	return nil;
end;

function SP_Has(s, sub) return type(s) == "string" and strfind(s, sub, 1, 1) ~= nil; end;

function SP_ReadFile(p)
	local fh = openfile(p, "rb");
	if not fh then return nil; end;
	local s = read(fh, "*a");
	closefile(fh);
	return s;
end;

function SP_Count(s, pat)
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

-- The label text after "<pilot> [<perk>]: " (a function: ClearGlobals drops data globals at every entry).
function SP_Lab() return "Cut your engines and hold still, we can patch that drive"; end;

-- a: install -------------------------------------------------------------------------------

function T_SPC_A()
	local h = HOST();
	SP_Begin();
	HOST_Check(S_Logs(0, "module=core event=loaded map=true module_count=18 extra_count=22") >= 1, "trf_spec loads last (extra_count=22)");
	local ml, tf, uf = TRF_ModList(), TRF_Loc_TextFns(), TRF_UI_TextFns();
	HOST_Check(ml[getn(ml)] == "Spc" and tf[getn(tf) - 1] == "TRF_Spc_Text" and tf[getn(tf)] == "TRF_Loc_Text" and uf[getn(uf)] == "TRF_Spc_Text",
		"Spc last in TRF_ModList, TRF_Spc_Text before TRF_Loc_Text and last in the UI list");
	local n, bad = 0, "";
	for k, v in TRF_Spc_Text() do
		n = n + 1;
		if strfind(v, "[%%#\n]") or strlen(v) > 480 or TRF_Txt(k) == k then bad = bad.." "..k; end;
	end;
	HOST_Check(n == 24 and bad == "" and TRF_Txt("spcnyana") == "Jana" and TRF_Txt("spcprepx") == "Expert Repairman",
		"24 text keys, no %, # or newline, each found by TRF_Txt"..bad);
	HOST_Check(TRF_Opt("spec") == 1 and TRF_Spc_OptDef().spec == 1 and TRF_OptEnum().spec == 1, "cfg spec 1 by default, enumerated 0..1");
	local T = TRF_SpcTune();
	local nt = 0;
	for k, v in TRF_Spc_TuneDef() do nt = nt + 1; end;
	HOST_Check(nt == 11 and T.spc_ch == 4 and T.spc_low == 0.6 and T.spc_hp == 0.75 and T.spc_hp_exp == 0.9 and T.spc_arm == 90
		and T.spc_meet == 1 and T.spc_ai == 1 and T.spc_fb == 1 and T.spc_say == 1 and T.spc_secs == 6 and T.spc_wq == 1,
		"11 tune keys with the defaults of spec 8");
	h.cfg.tune = {spc_hp=0.2, spc_ch=99, spc_arm=5, spc_secs=2.7, spc_low=3, spc_meet=4};
	T = TRF_SpcTune();
	HOST_Check(T.spc_hp == 0.55 and T.spc_ch == 20 and T.spc_arm == 30 and T.spc_secs == 3 and T.spc_low == 1 and T.spc_meet == 1,
		"tune clamps: spc_hp 0.55, spc_ch 20, spc_arm 30, spc_secs 3 (integer), spc_low 1, spc_meet 1");
	h.cfg.tune = {};
	local n0 = S_Mark();
	TRF_DumpState("test");
	HOST_Check(S_Logs(n0, "module=spec event=dump spec=1 hold_count=0 armed_count=0") == 1, "TRF_DumpState calls the spec dump");
	-- cfg spec 0: no item, the built head, no re-arm, no fence answer, no extra hail.
	SP_Crew({Yana={props={Repairman=1}}});
	local id, r, x, rn = SP_Fled("C", "hp", 0.3);
	HOST_Check(TRF_Spc_Due(id, r) == 1 and getn(TRF_Spc_HailOpts(id, r)) == 1 and TRF_Spc_Head(r, id) == TRF_Txt("spchead") and TRF_Spc_WqOk() == 1,
		"spec 1: the trader qualifies, one item, the head");
	h.cfg.spec = 0;
	n0 = S_Mark();
	local ha = r.ha;
	HOST_Check(getn(TRF_Spc_HailOpts(id, r)) == 0 and TRF_Spc_Head(r, id) == nil and TRF_Spc_Pre(r, id) == nil and TRF_Spc_RaidEnd(id, rn, "killed") == nil
		and r.ha == ha and TRF_Spc_WqOk() == nil and TRF_Spc_Due(id, r) == nil and TRF_HlMax(id, r) == 2 and S_Logs(n0, "module=spec event=skip trader_id="..id.." reason=off") == 1,
		"spec 0: no item, no head, no re-arm, no fence answer, hail_max 2 (skip reason off)");
	h.cfg.spec = nil;
	HOST_Check(TRF_HlMax(id, r) == 3, "spec 1: one hail beyond hail_max for the qualifying trader");
end;

-- b: the specialist probe -----------------------------------------------------------------

function T_SPC_B()
	local h = HOST();
	SP_Begin();
	local w, tried = TRF_Spc_Who("rep");
	HOST_Check(w == nil and tried == "Kalem:absent,Yana:absent,Josef:absent,Blade:absent,Uel:absent,Uel4:absent,Uel2:absent,Uel3:absent,Aia:absent,Alex:absent,Hero:absent,ai:noperk",
		"nobody: no specialist, every template tried ("..tostring(tried)..")");
	SP_Crew({Hero={props={Repairman=1}}});
	w = TRF_Spc_Who("rep");
	HOST_Check(w and w.tpl == "Hero" and w.rank == 1 and w.perk == "Repairman" and TRF_Txt("spclab", w.name, w.perkname) == "Hero [Repairman]: "..SP_Lab(),
		"the Hero with Repairman: Hero [Repairman]");
	SP_Crew({Hero={props={Repairman=1}}, Yana={props={Repairman=1}}});
	w = TRF_Spc_Who("rep");
	HOST_Check(w and w.tpl == "Yana" and TRF_Txt("spclab", w.name, w.perkname) == "Jana [Repairman]: "..SP_Lab(), "Yana before the Hero at the same rank: Jana [Repairman]");
	local n0 = S_Mark();
	SP_Crew({Yana={props={Repairman=1}}, Josef={props={Repairman_Exp=1, Repairman=1}}, Kalem={props={Repairman=1}}});
	w = TRF_Spc_Who("rep");
	HOST_Check(w and w.tpl == "Josef" and w.rank == 2 and w.perk == "Repairman_Exp" and TRF_Txt("spclab", w.name, w.perkname) == "Joseph [Expert Repairman]: "..SP_Lab()
		and S_Logs(n0, "module=spec event=who kind=rep speaker=Josef rank=2 tried=Kalem:ok1,Yana:ok1,Josef:ok2,Blade:absent") == 1,
		"Expert Repairman beats list order: Joseph [Expert Repairman]");
	SP_Crew({Yana={props={Repairman=1}, dead=1}, Josef={props={Repairman=1}, side="Trade"}, Kalem={perr=1}, Hero={props={Repairman=1}}});
	w, tried = TRF_Spc_Who("rep");
	HOST_Check(w and w.tpl == "Hero" and SP_Has(tried, "Kalem:error,Yana:dead,Josef:side,") and SP_Has(tried, "Hero:ok1,ai:noperk"),
		"filters: a raising HasProperty (error), dead Yana, Josef of side Trade; the Hero ("..tostring(tried)..")");
	SP_Crew({});
	h.ms_props = {Repairman=1};
	w = TRF_Spc_Who("rep");
	HOST_Check(w and w.tpl == "ai" and w.rank == 1 and TRF_Txt("spclab", w.name, w.perkname) == "Mothership [Repairman]: "..SP_Lab(),
		"System firmware: Mothership [Repairman]");
	h.ms_props = {Repairman_Exp=1, Repairman=1};
	SP_Crew({Kalem={props={Repairman=1}}});
	w = TRF_Spc_Who("rep");
	local w2 = w and w.tpl;
	h.cfg.tune = {spc_ai=0};
	w, tried = TRF_Spc_Who("rep");
	HOST_Check(w2 == "ai" and w and w.tpl == "Kalem" and not SP_Has(tried, "ai:"), "firmware Mk 3 (rank 2) beats Kalem; spc_ai 0: Kalem, ai not tried");
	h.cfg.tune = {};
	h.ms_props = nil;
	SP_Crew({Hero={props={F_of_Merchant=1}}, Yana={props={F_of_Merchant=1}}});
	w, tried = TRF_Spc_Who("int");
	HOST_Check(w and w.tpl == "Hero" and w.name == "Hero" and w.perkname == "Intuition" and tried == "Hero:ok1", "Intuition: the Hero only");
	SP_Crew({Yana={props={F_of_Merchant=1}}});
	HOST_Check(TRF_Spc_Who("int") == nil, "Intuition: nobody without the Hero's perk");
end;

-- c: qualification -------------------------------------------------------------------------

function T_SPC_C()
	local h = HOST();
	SP_Begin();
	SP_Crew({Yana={props={Repairman=1}}});
	local id, r, x, rn, lead = SP_Fled("C", "hp", 0.3);
	HOST_Check(r.hp0 == 1000 and r.st == "flee" and r.fl == "hp" and V_Rd(rn).st == "end" and SP_Q(id) == "ok", "fleeing hp after its raid ended: qualifies");
	local res = "";
	local tc = {{"rdn", nil, "no_raid"}, {"rdn", 999, "ok"}, {"cnt", 1, "attacked"}, {"sk", 2, "done"}, {"hx", ",fix,", "done"}, {"own", 1, "kind"},
		{"fw", 1, "kind"}, {"sev", 1, "kind"}, {"wq", 1, "kind"}, {"cv", 3, "kind"}, {"feq", 1, "kind"}, {"tier", 4, "kind"}, {"fl", "heat", "flight"},
		{"fl", "threat", "flight"}, {"fl", "staged", "flight"}, {"fl", "chased", "flight"}, {"st", "out", "flight"}};
	for i = 1, getn(tc) do
		local k, v, want = tc[i][1], tc[i][2], tc[i][3];
		local old = r[k];
		r[k] = v;
		local got = SP_Q(id);
		if got ~= want then res = res.." "..k.."="..tostring(v)..":"..got; end;
		r[k] = old;
	end;
	HOST_Check(res == "", "record gates: no_raid, a pruned raid record qualifies, attacked, done (sk, hx), kind (own, fw, sev, wq, cv, feq, tier 4), flight (heat, threat, staged, chased, not fleeing)"..res);
	local fq = TRF_FeqId;
	TRF_FeqId = function(i) return "FTU equipment convoy"; end;
	local q1 = SP_Q(id);
	TRF_FeqId = fq;
	lead.hp = 700;
	local q2 = SP_Q(id);
	lead.hp = nil;
	local q3 = SP_Q(id);
	lead.hp = 300;
	HOST_Check(q1 == "kind" and q2 == "hp" and q3 == "ok", "the equipment convoy lead (TRF_FeqId): kind; hp flight at 0.7: hp; no GetCurHP reading: hp flight qualifies");
	-- A refused raid's flight (fl raid): HP below spc_low 0.6 only, and only with a reading.
	local id2, r2, x2, rn2, lead2 = SP_Fled("C", "raid", 0.4);
	local q4 = SP_Q(id2);
	lead2.hp = 700;
	local q5 = SP_Q(id2);
	lead2.hp = nil;
	local q6 = SP_Q(id2);
	lead2.hp = 400;
	HOST_Check(r2.fl == "raid" and q4 == "ok" and q5 == "hp" and q6 == "hp", "raid flight: 0.4 qualifies, 0.7 and no reading: hp");
	-- Chapter 3, a deny row spec = 0, the start-system guard, trf_raid's unflee missing.
	h.labels.CurrentQuest = "3";
	SP_QCache();
	local c3 = SP_Q(id2);
	h.labels.CurrentQuest = "5_1";
	SP_QCache();
	local de = TRF_DenyEntry;
	TRF_DenyEntry = function(nm) return {spec=0, why="test"}; end;
	local n0 = S_Mark();
	local dn = SP_Q(id2);
	TRF_DenyEntry = de;
	SP_QCache();
	local sm = TRF_SysModeQuiet;
	TRF_SysModeQuiet = function() return "van", "guard"; end;
	local gd = SP_Q(id2);
	TRF_SysModeQuiet = sm;
	local uf = TRF_Rd_Unflee;
	TRF_Rd_Unflee = nil;
	local rm = SP_Q(id2);
	TRF_Rd_Unflee = uf;
	HOST_Check(c3 == "chapter" and dn == "gate:deny_spec" and S_Logs(n0, "module=safety event=gate feature=spec") == 1 and gd == "mode:guard"
		and rm == "raid_module" and SP_Q(id2) == "ok", "chapter 3, deny row spec = 0, start-system guard, no TRF_Rd_Unflee: "..c3.." "..dn.." "..gd.." "..rm);
	-- D17 heat below 3: at heat 3 (the refusal box, the charter menu) and with Trade at war no item, no answer line, no extra hail.
	TRF.std.heat = 3;
	n0 = S_Mark();
	local ht = SP_Q(id2);
	local hm = TRF_HlMax(id2, r2);
	local ho = TRF_Spc_HailOpts(id2, r2);
	local hh = SP_Hail(id2);
	SP_End();
	TRF.std.heat = 0;
	local tw = TRF_HlTradeWar;
	TRF_HlTradeWar = function() return 1; end;
	local wr = SP_Q(id2);
	TRF_HlTradeWar = tw;
	HOST_Check(ht == "heat" and hm == 2 and getn(ho) == 0 and hh == "refuse" and S_Logs(n0, "module=spec event=answer") == 0
		and S_Logs(n0, "module=safety event=gate feature=spec") == 0 and wr == "heat" and SP_Q(id2) == "ok",
		"heat 3: reason heat, hail_max 2, no item, the refusal, no answer line, no strict-gate ask; Trade at war: heat");
	-- The skip line once per trader and visit; an open raid: no item, the combat hail instead of the menu.
	n0 = S_Mark();
	TRF_SpcSH().sk[id2] = nil;
	r2.fl = "heat";
	TRF_Spc_HailOpts(id2, r2);
	TRF_Spc_HailOpts(id2, r2);
	r2.fl = "raid";
	r2.cnt = 1;
	TRF_Spc_HailOpts(id2, r2);
	r2.cnt = nil;
	HOST_Check(S_Logs(n0, "module=spec event=skip trader_id="..id2.." reason=flight") == 1 and S_Logs(n0, "module=spec event=skip trader_id="..id2) == 1,
		"skip line at log 2, once per trader and visit (flight, then attacked: one line)");
	local id3, r3, x3, rn3 = SP_Fled("C", "hp", 0.3, "open");
	n0 = S_Mark();
	local o = SP_Hail(id3);
	HOST_Check(SP_Q(id3) == "raid" and o ~= "menu" and S_Logs(n0, "module=spec event=answer") == 0 and TRF_HlMax(id3, r3) == 2,
		"raid record open: reason raid, no menu ("..tostring(o).."), no answer, hail_max 2");
	SP_End();
	TRF_Rd_End(rn3, "cancel");
end;

-- d: the hail flow ---------------------------------------------------------------------------

function T_SPC_D()
	local h = HOST();
	SP_Begin();
	SP_Dlg(1);
	SP_Crew({Yana={props={Repairman=1}}});
	-- The raid end arms the hail again: the window, the focus trigger, one meeting trigger.
	local n0 = S_Mark();
	local id, r, x, rn, lead = SP_Fled("C", "hp", 0.3);
	local gt = TRF.clock.gt;
	HOST_Check(S_Logs(n0, "module=spec event=arm trader_id="..id.." raid_id="..rn.." raid_end=killed flight=hp hp_fraction=0.300 meet=true") == 1
		and r.ha >= gt + 89 and HOST_Count("focus", "TRF_OnHail("..id..",") >= 1 and HOST_Count("f_object_inside", "TRF_Spc_Meet("..id..",") == 1,
		"raid end: event=arm, r.ha = gt + 90, the focus trigger and one meeting trigger");
	-- The meeting trigger opens the menu (hail_start 2): provider items only, the label in a_p1, the head.
	n0 = S_Mark();
	HOST_Fire("f_object_inside", "TRF_Spc_Meet("..id..",");
	local d = h.dlg or {rv={}};
	HOST_Check(S_Logs(n0, "module=hail event=hail trader_id="..id.." via=patch answer_count=1") == 1 and HOST_DlgVis() == "a_p1 a_close"
		and d.rv.p1 == "Jana [Repairman]: "..SP_Lab() and d.rv.head == TRF_Txt("spchead")
		and S_Logs(n0, "module=spec event=answer trader_id="..id.." speaker=Yana perk=Repairman rank=1 result=offered") == 1,
		"meeting trigger: the dialog via patch, a_p1 'Jana [Repairman]: ...' and Close only, the head spchead");
	-- The pick: SetHP 0.75 x hp0, the unflee (path C: out, the old exit with its trigger), help + 1, the page.
	local help0 = TRF.std.help;
	local m0, s0 = getn(h.msgs), getn(h.screen);
	n0 = S_Mark();
	HOST_DlgPick("a_p1");
	T_Tick(1, 0.5);
	local pg = HOST_DlgText() or "";
	HOST_Check(lead.hp == 750 and r.st == "out" and r.fl == nil and r.sk == 2 and r.ext == h.sp_ext and TRF.std.help == help0 + 1
		and TRF_HlUsed(r, "fix") and HOST_Count("f_object_inside", "TRF_OnExit("..id..",") == 1 and SP_Has(pg, "By Space, she's holding!")
		and S_Logs(n0, "module=raid event=unflee trader_id="..id.." reason=patch state=out portal="..tostring(h.sp_ext)) == 1
		and S_Logs(n0, "module=spec event=patch trader_id="..id.." speaker=Yana rank=1 hp_before=300 target=750 hp_after=750 hp0=1000 state=out help=1 reason=nil result=patched") == 1,
		"pick: HP 750, out by the old exit "..tostring(h.sp_ext).." with its exit trigger, sk 2, help + 1, the page spcok");
	SP_End();
	HOST_Check(SP_Has(SP_Msgs(m0), "Yana:Done. Their drive will hold for a while yet.")
		and S_Logs(n0, "module=spec event=say trader_id="..id.." speaker=Yana output=radio result=shown reason=nil") == 1,
		"the pilot's radio line after the page (closed)");
	HOST_Check(SP_Q(id) == "flight" and TRF_HlMax(id, r) == 2 and TRF_Spc_Due(id, r) == nil, "patched: no longer qualifies, hail_max 2");
	-- Kalem with Expert Repairman on path A: 0.9 x hp0, state in.
	SP_Crew({Kalem={props={Repairman_Exp=1}}, Yana={props={Repairman=1}}});
	local ida, ra, xa, rna, leada = SP_Fled("A", "hp", 0.2, "fake");
	n0 = S_Mark();
	SP_Hail(ida);
	HOST_DlgPick("a_p1");
	T_Tick(1, 0.5);
	HOST_Check(leada.hp == 900 and ra.st == "in" and ra.fl == nil and S_Logs(n0, "module=raid event=unflee trader_id="..ida.." reason=patch state=in") == 1
		and S_Logs(n0, "speaker=Kalem rank=2 hp_before=200 target=900 hp_after=900") == 1, "Kalem (Expert Repairman), path A: HP 900, state in");
	SP_End();
	-- The mothership firmware: its line on screen; a squad pilot who cannot speak: the screen fallback; help already paid.
	SP_Crew({});
	h.ms_props = {Repairman=1};
	local idm, rm = SP_Fled("C", "hp", 0.3);
	rm.res = 1;
	help0 = TRF.std.help;
	s0 = getn(h.screen);
	n0 = S_Mark();
	SP_Hail(idm);
	local pm = h.dlg.rv.p1;
	HOST_DlgPick("a_p1");
	T_Tick(1, 0.5);
	SP_End();
	HOST_Check(pm == "Mothership [Repairman]: "..SP_Lab() and SP_Has(SP_Scr(s0), "Mothership: Repair drones are back aboard.") and TRF.std.help == help0
		and S_Logs(n0, "help=0 reason=help_paid result=patched") == 1 and S_Logs(n0, "speaker=ai output=line result=shown") == 1,
		"firmware: Mothership [Repairman], its screen line; raid help paid before: help 0, reason help_paid");
	h.ms_props = nil;
	SP_Crew({Yana={props={Repairman=1}, csr=0}});
	local idq = SP_Fled("C", "hp", 0.3);
	s0 = getn(h.screen);
	n0 = S_Mark();
	SP_Hail(idq);
	HOST_DlgPick("a_p1");
	T_Tick(1, 0.5);
	SP_End();
	HOST_Check(SP_Has(SP_Scr(s0), "Jana: Done. Their drive will hold for a while yet.") and S_Logs(n0, "speaker=Yana output=line result=shown reason=no_speaker") == 1,
		"a pilot who cannot speak (IsCanSayReplica 0): the screen line 'Jana: ...'");
	-- loc_mode 1: the screen line is the spcsay key (the spcsayl wrapper would show only its fixed form).
	local idl = SP_Fled("C", "hp", 0.3);
	h.cfg.loc_mode = 1; TRF_H().loc = nil;
	s0 = getn(h.screen);
	SP_Hail(idl);
	HOST_DlgPick("a_p1");
	T_Tick(1, 0.5);
	SP_End();
	local sl = SP_Scr(s0);
	h.cfg.loc_mode = nil; TRF_H().loc = nil;
	HOST_Check(SP_Has(sl, "#TRF_spcsay") and not SP_Has(sl, "#TRF_spcsayl"), "loc_mode 1, a pilot who cannot speak: the spcsay key on screen ("..sl..")");
	-- No specialist: no item, the head names the missing skill, the full menu.
	SP_Crew({});
	local idn, rn2 = SP_Fled("C", "hp", 0.3);
	n0 = S_Mark();
	SP_Hail(idn);
	d = h.dlg or {rv={}};
	HOST_Check(d.rv.head == TRF_Txt("spcneed") and HOST_DlgVis() == "a_trade a_head a_trouble a_boom a_close" and d.rv.p1 == ""
		and S_Logs(n0, "module=spec event=need trader_id="..idn.." via=dialog tried=Kalem:absent") == 1 and S_Logs(n0, "reason=no_specialist") == 1,
		"no specialist: the head spcneed, the full menu, no p item, event=need");
	SP_End();
	-- The box chain (hail_box 1): the first box carries spcneedb or spcheadb; the patch box.
	SP_Dlg(nil);
	local idb, rb = SP_Fled("C", "hp", 0.3);
	SP_Hail(idb);
	local b1 = SP_BoxText();
	SP_End();
	SP_Crew({Yana={props={Repairman=1}}});
	local idc, rc, xc, rnc, leadc = SP_Fled("C", "hp", 0.3);
	n0 = S_Mark();
	SP_Hail(idc);
	local b2 = SP_BoxText();
	HOST_Press("ok");
	T_Tick(1, 0.5);
	local b3 = SP_BoxText();
	local nm = TRF_HlName(rc);
	HOST_Check(SP_Has(b1, "FTU "..TRF_HlName(rb)..": They chewed us up good and the drive is failing. If you had a repairman aboard")
		and b2 == "FTU "..nm..": They chewed us up good. The drive won't last to the portal, but we're trying!"..TRF_Br()..TRF_Txt("hailq", TRF_HlWho(rc, idc), "Jana [Repairman]: "..SP_Lab())
		and b3 == "FTU "..nm..": By Space, she's holding! Back on course, and thank you, friends." and leadc.hp == 750 and rc.st == "out",
		"box chain: spcneedb / spcheadb in the first box, the label box, OK patches, the answer box ("..tostring(b2)..")");
	SP_End();
	-- hail_max: two hails used, one more while the trader qualifies, none after the patch.
	SP_Dlg(1);
	local idx, rx = SP_Fled("C", "hp", 0.3);
	rx.hn = 2;
	local o1 = SP_Hail(idx);
	HOST_DlgPick("a_p1");
	T_Tick(1, 0.5);
	SP_End();
	local o2, w2 = SP_Hail(idx);
	HOST_Check(o1 == "menu" and rx.hn == 3 and rx.sk == 2 and o2 == nil and w2 == "max", "hail_max 2 reached: a third hail while qualifying, none after the patch");
	-- A trader not met before its raid: the raid end leaves r.ha nil, so the meeting still announces it and arms the hail.
	h.sp_unmet = 1;
	local idu, ru = SP_Fled("C", "hp", 0.3);
	h.sp_unmet = nil;
	local hu = ru.ha;
	local mc = h.cfg.meet;
	h.cfg.meet = 2;
	n0 = S_Mark();
	HOST_Fire("f_object_inside", "TRF_OnMeet("..idu..",");
	h.cfg.meet = mc;
	HOST_Check(hu == nil and type(ru.ha) == "number" and S_Logs(n0, "module=ui event=announce trader_id="..idu) == 1,
		"unmet trader: no r.ha at the raid end, the meeting announces it and arms the hail");
	SP_End();
	-- A synthetic sixth slotted provider item: the menu falls back to the box chain (reason slots).
	local dco, dcd = TRF_Dc_HailOpts, TRF_Dc_HailDo;
	TRF_Dc_HailOpts = function(id, r) return {"z1", "z2", "z3", "z4", "z5"}; end;
	TRF_Dc_HailDo = function(k, id) end;
	local idz = SP_Fled("C", "hp", 0.3);
	n0 = S_Mark();
	SP_Hail(idz);
	TRF_Dc_HailOpts = dco; TRF_Dc_HailDo = dcd;
	HOST_Check(S_Logs(n0, "module=hail event=dialog_fallback reason=slots") == 1 and HOST_Box() and not HOST_Box().done, "six slotted items: dialog_fallback reason=slots, the boxes");
	SP_End();
end;

-- e: the SetHP fallback --------------------------------------------------------------------------

function T_SPC_E()
	local h = HOST();
	SP_Begin();
	SP_Dlg(1);
	SP_Crew({Yana={props={Repairman=1}}});
	-- SetHP ignored, spc_fb 1: the flee ends anyway (flee_only), the guard holds the poll and the HP trigger.
	local id, r, x, rn, lead = SP_Fled("C", "hp", 0.3);
	lead.SetHP = function(self, v) end;
	local n0 = S_Mark();
	SP_Hail(id);
	HOST_DlgPick("a_p1");
	T_Tick(1, 0.5);
	local pg = HOST_DlgText() or "";
	HOST_Check(lead.hp == 300 and r.st == "out" and r.fl == nil and r.sk == 2 and SP_Has(pg, "She still rattles, but she'll fly.")
		and S_Logs(n0, "target=750 hp_after=300 hp0=1000 state=out help=1 reason=sethp result=flee_only") == 1, "SetHP ignored: flee_only, spcfo, the flee ended");
	SP_End();
	n0 = S_Mark();
	TRF_Raid_Step();
	TRF_OnLowHP(id, TRF.gen);
	HOST_Check(r.fl == nil and r.st == "out" and S_Logs(n0, "module=raid event=flee trader_id="..id) == 0
		and S_Logs(n0, "module=spec event=hold trader_id="..id.." hp=300 floor=270.000 result=held") == 1, "the 2 s poll and the HP trigger: held at HP 300 (floor 270)");
	lead.hp = 250;
	n0 = S_Mark();
	TRF_Raid_Step();
	HOST_Check(r.fl == "hp" and r.st == "flee" and S_Logs(n0, "result=released") == 1 and S_Logs(n0, "module=raid event=flee trader_id="..id.." reason=hp") == 1,
		"a hit below 0.9 x 300: the guard released, the trader flees again");
	-- spc_fb 0: no patch, spcfail, the flee goes on.
	SP_Dlg(1, {spc_fb=0});
	local id2, r2, x2, rn2, lead2 = SP_Fled("C", "hp", 0.3);
	lead2.SetHP = function(self, v) end;
	n0 = S_Mark();
	SP_Hail(id2);
	HOST_DlgPick("a_p1");
	T_Tick(1, 0.5);
	pg = HOST_DlgText() or "";
	HOST_Check(r2.st == "flee" and r2.fl == "hp" and r2.sk == nil and SP_Has(pg, "It didn't take.") and S_Logs(n0, "reason=sethp result=failed") == 1
		and S_Logs(n0, "module=raid event=unflee") == 0, "spc_fb 0: spcfail, the flee goes on");
	SP_End();
	-- A raising SetHP reads as ignored.
	SP_Dlg(1);
	local id3, r3, x3, rn3, lead3 = SP_Fled("C", "hp", 0.3);
	lead3.SetHP = function(self, v) error("injected SetHP error"); end;
	n0 = S_Mark();
	SP_Hail(id3);
	HOST_DlgPick("a_p1");
	T_Tick(1, 0.5);
	HOST_Check(r3.st == "out" and S_Logs(n0, "reason=sethp result=flee_only") == 1 and S_Logs(n0, " event=error ") == 0, "a raising SetHP: flee_only, no error line");
	SP_End();
	-- The unflee refused: the wind-down, a trader not fleeing.
	local id4, r4 = SP_Fled("C", "hp", 0.3);
	n0 = S_Mark();
	SP_Hail(id4);
	TRF.live.wind = 1;
	HOST_DlgPick("a_p1");
	T_Tick(1, 0.5);
	TRF.live.wind = nil;
	pg = HOST_DlgText() or "";
	HOST_Check(r4.st == "flee" and r4.sk == nil and SP_Has(pg, "It didn't take.") and S_Logs(n0, "reason=unflee:wind result=failed") == 1, "wind-down: unflee refused, spcfail");
	SP_End();
	r4.st = "out";
	local u, uw = TRF_Rd_Unflee(id4, "test");
	HOST_Check(u == nil and uw == "state", "TRF_Rd_Unflee of a trader not fleeing: nil, state");
	-- A station-refuge flee keeps no exit (h.ex0 nil); with the exit handle lost the unflee takes the nearest portal.
	n0 = S_Mark();
	local id5, r5, x5 = SP_Fled("C", "hp", 0.3, nil, Vector3(h.ms.pos.x + 45, h.ms.pos.y, h.ms.pos.z));
	HOST_Check(S_Logs(n0, "module=raid event=flee trader_id="..id5.." reason=hp refuge=station") == 1 and x5.ex0 == nil,
		"a near station approach point: the trader flees to the station, no h.ex0");
	x5.ext = nil;
	n0 = S_Mark();
	SP_Hail(id5);
	HOST_DlgPick("a_p1");
	T_Tick(1, 0.5);
	HOST_Check(r5.st == "out" and r5.fl == nil and x5.ext ~= nil and type(r5.ext) == "string"
		and S_Logs(n0, "module=raid event=unflee trader_id="..id5.." reason=patch state=out portal="..r5.ext) == 1
		and HOST_Count("f_object_inside", "TRF_OnExit("..id5..",") == 1,
		"unflee after a station flee, exit lost: out by the nearest portal "..tostring(r5.ext).." with one exit trigger");
	SP_End();
end;

-- f: the next meeting --------------------------------------------------------------------------------

function T_SPC_F()
	local h = HOST();
	SP_Begin();
	SP_Dlg(1);
	SP_Crew({Yana={props={Repairman=1}}});
	local id, r, x, rn, lead = SP_Fled("C", "hp", 0.3);
	SP_Hail(id);
	HOST_DlgPick("a_p1");
	T_Tick(1, 0.5);
	SP_End();
	local cur = TRF_CurIdx();
	local to = V_Idx("gaoba");
	TRF_TrackWrite(id, to, 1, cur);
	local i, rec = TRF_TpFind(id);
	HOST_Check(r.sk == 2 and rec and TRF_Bit(rec.fl, 256) == 1 and rec.dm == 0, "exit write after the patch: pool fl bit 256, damage band 0 (HP 750)");
	HOST_Check(TRF_TkCrpFl(256 + 64, 5) == 256 + 192 and TRF_TkCrpOf(256 + 128) == 4 and TRF_TkCrpFl(256 + 64, nil) == 256,
		"the corporation bits 64 and 128 beside bit 256");
	-- The rebuild: res 1 (the free rumour), event=rebuilt, the spcmet announce line once.
	V_ClearTr();
	TRF.tp = {TRF_TpPack({id=7500, nm=rec.nm, o=0, c=1, tt=1, pw=3, n=1, e=0, s=cur, fr=to, d=0, dm=0, fl=256 + 1, t=TRF.clock.legs})};
	local n0 = S_Mark();
	local tid = TRF_TrackSpawn(7500, "dock");
	local r2 = tid and TRF.live.tr[tid];
	HOST_Check(r2 and r2.res == 1 and S_Logs(n0, "module=spec event=rebuilt trader_id="..tostring(tid).." pool_id=7500") == 1,
		"rebuild from a patched pool record: res 1, event=rebuilt");
	local m1 = tid and TRF_TrackMetAgain(tid);
	local m2 = tid and TRF_TrackMetAgain(tid);
	HOST_Check(m1 == "Wolves again! That patch of yours held all the way." and m2 == nil, "the met-again line spcmet, once per visit");
	if not r2 then return; end;
	local fl = TRF_TkFlags(tid, r2);
	HOST_Check(TRF_Bit(fl, 256) == 0 and TRF_Bit(fl, 1) == 1 and TRF_Bit(fl, 32) == 1, "the next write without a patch: bit 256 cleared, met and rescued kept");
	-- A second patch of the rebuilt trader: no help (res 1), the bit again.
	local lead2 = TRF_GnLead(tid);
	T_MoveTr(tid, h.ms.pos.x + 40, h.ms.pos.y, h.ms.pos.z);
	TRF.live.rd[998] = {n=998, id=tid, st="end", how="killed"};
	r2.rdn = 998;
	r2.st = "flee";
	r2.fl = "hp";
	lead2.hp = 0.3 * r2.hp0;
	local help0 = TRF.std.help;
	n0 = S_Mark();
	SP_Hail(tid);
	HOST_DlgPick("a_p1");
	T_Tick(1, 0.5);
	SP_End();
	HOST_Check(r2.sk == 2 and TRF.std.help == help0 and S_Logs(n0, "help=0 reason=help_paid result=patched") == 1 and TRF_Bit(TRF_TkFlags(tid, r2), 256) == 1,
		"a second patch of the rebuilt trader: help 0, bit 256 set again");
	TRF.live.rd[998] = nil;
end;

-- g: save and repair ----------------------------------------------------------------------------

function T_SPC_G()
	local h = HOST();
	SP_Begin();
	local L = TRF.live;
	L.tr[9901] = {st="in", sk=3}; L.tr[9902] = {st="out", sk="x"}; L.tr[9903] = {st="out", sk=2}; L.tr[9904] = {st="gone", sk=2};
	TRF_Repair();
	HOST_Check(L.tr[9901].sk == nil and L.tr[9902].sk == nil and L.tr[9903].sk == 2 and L.tr[9904].sk == nil, "TRF_Spc_Fix (from TRF_Repair): sk 2 on live records only");
	for k = 9901, 9904 do L.tr[k] = nil; end;
	-- Byte figures (3.3): sk, the fix mark in hx, res on one record; the pool bit.
	local one = HOST_SaveSize({sk=2, hx=",fix,", res=1}) - HOST_SaveSize({});
	local pk = {id=99, nm=40, o=0, c=6, tt=3, pw=20, n=99, e=9, s=113, fr=113, d=2, dm=3, fl=0, t=9999};
	local p0 = HOST_SaveSize(TRF_TpPack(pk));
	pk.fl = 256;
	local p1 = HOST_SaveSize(TRF_TpPack(pk));
	pk.fl = 63;
	local p2 = HOST_SaveSize(TRF_TpPack(pk)) ;
	pk.fl = 256 + 63;
	local p3 = HOST_SaveSize(TRF_TpPack(pk));
	local worst = 8 * one + 16 * max(p1 - p0, p3 - p2);
	HOST_Check(one == 68 and p1 - p0 <= 3 and p3 - p2 <= 3 and worst <= 592, "A05 fields: "..one.." bytes a record, pool bit +"..(p1 - p0)..", worst case "..worst.." <= 592");
	local size = 8 + 3 + HOST_SaveSize(TRF);
	HOST_Check(size < 100000, "TRF after the scenario: "..size.." bytes < 100000");
	-- A jump and a load drop the visit state; a meeting trigger of an old generation does nothing.
	SP_Crew({Yana={props={Repairman=1}}});
	local id = SP_Fled("C", "hp", 0.3);
	local g0 = TRF.gen;
	TRF_SpcSH().hold[id] = {g=g0, f=300};
	HOST_Check(type(TRF_H().spc) == "table" and TRF_H().spc.mt[id] == 1, "visit state in the handle table (meeting trigger armed)");
	T_SaveLoad();
	HOST_Check(TRF_H().spc == nil and TRF_Spc_Hold(id, 300) == nil, "a load: no visit state (the dump does not create it), no hold");
	T_Jump("gaoba");
	local n0 = S_Mark();
	TRF_Spc_Meet(id, g0);
	HOST_Check(TRF_H().spc == nil and S_Logs(n0, "module=hail event=hail") == 0 and S_Logs(n0, "module=spec event=skip") == 0,
		"a jump: no visit state; TRF_Spc_Meet of an old generation does nothing");
	-- RU fixed forms: 24 keys, CRLF, cp1251.
	local ru = SP_ReadFile(h.dir.."../../../../loc/trf_ru.loc");
	local miss = "";
	for k, v in TRF_Spc_Text() do if not SP_Has(ru, format("\r\n#TRF_%s = ", k)) then miss = miss.." "..k; end; end;
	HOST_Check(miss == "" and SP_Count(ru, "\n") == SP_Count(ru, "\r\n") and not strfind(ru, "\208[\128-\191]"), "loc/trf_ru.loc: the 24 spc keys, CRLF, cp1251"..miss);
end;

-- Dispatch -----------------------------------------------------------------------------------------------

local sc = getenv("TRF_SPC") or "";
local fn = getglobal("T_SPC_"..strupper(sc));
print("HOST ==== specialist scenario spc-"..sc.." dir="..HOST().dir);
if type(fn) == "function" then
	fn();
	HOST_Check(T_LeftGlobals() == "", "no handle globals left at the end"..T_LeftGlobals());
else
	HOST_Check(nil, "unknown specialist scenario "..sc);
end;
HOST_Check((HOST().gpm_tick or 0) == 0, "no GetPlayerMotherShip from a tick (n="..tostring(HOST().gpm_tick or 0)..")");
print("HOST errors="..HOST().errors.." fails="..HOST().fails);
if HOST().errors > 0 or HOST().fails > 0 then exit(1); end;
exit(0);
