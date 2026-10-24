-- Worldbuilding plumbing scenarios (design/wb-plumbing-spec.md 13) under stock Lua 4.0.1: TRF_PLUMB=a..e, run by
-- run_host.sh as its own entry point. a dock dispatcher (order, one box, skip, nesting, fee box, lock, double
-- wrap), b _NoneStation_Action chain, CostOfHead and Case_Eject, c clocks across a load and the C1/D1 rules,
-- d visit slots, seed order, arrival lines, job slot and markers, e raid help, ship caps, fst clamp, pk and the
-- orphan scan.
-- Loads host_station.lua up to its first scenario (stubs of host_stubs.lua, the helpers of host_traffic.lua
-- and host_v02.lua, the DockStation.script stubs and the S_* helpers), then adds CostOfPirates.script's
-- CostOfHead to the vanilla includes.

local f = openfile((getenv("TRF_TESTS") or "./").."host_station.lua", "r");
if not f then print("HOST FAIL host_plumb.lua: cannot open host_station.lua"); exit(1); end;
local src = read(f, "*a");
closefile(f);
local cut = strfind(src, "\n-- a: install (12.1, 6.1)", 1, 1);
if not cut then print("HOST FAIL host_plumb.lua: marker '-- a: install (12.1, 6.1)' missing in host_station.lua"); exit(1); end;
dostring(strsub(src, 1, cut), "host_station.lua");

-- Stubs ------------------------------------------------------------------------------------

-- CostOfPirates.script CostOfHead, reduced: Pir_Pilots index^2 x 200 per pilot, 0 for everything else.
P_Includes0 = HOST_Includes;
function HOST_Includes()
	P_Includes0();
	dostring([[
function CostOfHead(pilot_name, count)
	local price = 0;
	for i, pn in Pir_Pilots do
		if pn == pilot_name then price = i * i * 200; end;
	end;
	HOST().coh = (HOST().coh or 0) + 1;
	return price;
end;
]], "DATA/Scripts/include/CostOfPirates.script");
end;

-- Test handlers (registered again after every MapInitialization: the registry is rebuilt) --------------

function P_Rec(x)
	local h = HOST();
	if type(h.pord) ~= "table" then h.pord = {}; end;
	tinsert(h.pord, x);
end;
function P_LineA(kind) P_Rec("a"); return "P line A"; end;
function P_LineB(kind) P_Rec("b"); return {"P line B1", "P line B2"}; end;
function P_Owe(kind) P_Rec("owe:"..tostring(kind)); if kind == "trade" then return "P owed paid"; end; return nil; end;
function P_BoxNil(kind) P_Rec("box400"); return nil; end;
function P_BoxHigh(kind) P_Rec("box300"); return {text="P offer high", ok="P_BoxOk", no="P_BoxNo", a=7, own="p_high"}; end;
function P_BoxLow(kind) P_Rec("box100"); return {text="P offer low", ok="P_BoxOk", own="p_low"}; end;
function P_BoxOk(a) P_Rec("ok:"..tostring(a)); return "P accepted"; end;
function P_BoxNo(a) P_Rec("no:"..tostring(a)); return nil; end;
function P_RegDock()
	TRF_DockLine("trade", 5, "P_LineA");
	TRF_DockLine("trade", 95, "P_LineB");
	TRF_OweReg("P_Owe");
	TRF_DockBox("trade", 400, "P_BoxNil");
	TRF_DockBox("trade", 300, "P_BoxHigh");
	TRF_DockBox("trade", 100, "P_BoxLow");
end;

-- Screen lines after s0, texts joined by "|".
function P_Scr(s0)
	local q, r = HOST().screen, "";
	for i = s0 + 1, getn(q) do r = r..q[i].t.."|"; end;
	return r;
end;

function P_Ord()
	local q, r = HOST().pord or {}, "";
	for i = 1, getn(q) do r = r..q[i]..","; end;
	return r;
end;

function P_Begin(sys, t)
	local h = HOST();
	h.labels.CurrentQuest = "5_1";
	S_Begin(sys, t);
end;

-- a: dock dispatcher (spec 4) ------------------------------------------------------------------

function T_PL_A()
	local h = HOST();
	P_Begin("gredos", {seed=0, queue=0, parked=0, staged=0, raids=0});
	-- Install: CostOfHead wrapped once over the vanilla chunk's function; every module registered.
	local src = function(fn) return getinfo(fn, "S").source or ""; end;
	HOST_Check(S_Logs(0, "module=plumb event=install cost_of_head_installed=true cost_of_head_wrapped=true") >= 1
		and strfind(src(TRF_orig_CostOfHead), "CostOfPirates.script", 1, 1) and TRF_PlIsMine(CostOfHead), "install: CostOfHead wrapped over the vanilla function");
	local c1 = TRF_PlCounts();
	local r = TRF_InstallPlumb();
	local c2 = TRF_PlCounts();
	local same = 1;
	for k, v in c1 do if c2[k] ~= v then same = nil; end; end;
	HOST_Check(r.coh == 0 and same and TRF_InstallTradeDock() == 0 and TRF_InstallBoard() == 0 and TRF_InstallPirDock() == 0
		and TRF_InstallStation().trade == 0 and TRF_InstallGen().ce == 0, "second install: no double wrap, registrations replaced in place ("..c2.line.." lines)");
	-- Survivors (design/survivors-spec.md 4): the trade dock line at order 30 and the seed provider at 550; faction ladder
	-- (design/ladder-spec.md 4): patrol line 50, patrol box 300, one CostOfHead handler.
	HOST_Check(c2.line == 6 and c2.box == 4 and c2.none == 1 and c2.ej == 1 and c2.owe == 1 and c2.seed == 9 and c2.coh == 1,
		"traffic registrations: 6 lines, 4 boxes, 1 none handler, 1 eject handler, 1 payer, 9 seed providers, 1 CostOfHead handler");
	local o1 = TRF_orig_CostOfHead;
	T_Jump("aurora");
	T_Jump("gredos");
	HOST_Check(TRF_orig_CostOfHead ~= o1 and strfind(src(TRF_orig_CostOfHead), "CostOfPirates.script", 1, 1) and TRF_PlIsMine(CostOfHead),
		"next MapInitialization: wrapped again over the fresh vanilla function");
	-- Line order, payers at order 50, one box (highest prio with a spec), the original after the answer.
	P_RegDock();
	h.pord = {};
	local s0, b0, t0 = getn(h.screen), getn(h.boxes), h.trade_ok;
	local n0 = S_Mark();
	V_TradeDock();
	HOST_Check(P_Ord() == "a,owe:trade,b,box400,box300," and P_Scr(s0) == "P line A|P owed paid|P line B1|P line B2|"
		and getn(h.boxes) == b0 + 2 and HOST_Box().text == "P offer high" and HOST_Box().title == "#UI_TradeStationWndCaption" and h.trade_ok == t0,
		"trade dock: lines in order (5, payers at 50, 95), first box spec of the highest prio, low prio not asked, original waits ("..P_Ord()..")");
	HOST_Check(TRF.live.box == "dock_trade" and S_Logs(n0, "module=plumb event=dock kind=trade line_count=4 box=p_high priority=300 result=box") == 1,
		"box lock held by dock_trade, dock line logged");
	h.pord = {};
	s0 = getn(h.screen);
	HOST_Press("ok");
	HOST_Check(P_Ord() == "ok:7," and h.trade_ok == t0 + 1 and P_Scr(s0) == "P accepted|" and TRF.live.box == nil and getn(h.boxes) == b0 + 2,
		"box OK: handler with a, its line, the original exactly once, lock freed");
	-- Cancel: the no handler, then the original once.
	h.pord = {};
	t0 = h.trade_ok;
	V_TradeDock();
	HOST_Press("cancel");
	HOST_Check(P_Ord() == "a,owe:trade,b,box400,box300,no:7," and h.trade_ok == t0 + 1, "box Cancel: no handler, original once");
	-- __sys_SOS and __disableAction: only the always handlers (shop restore), no box, the original at once.
	local flags = {"__sys_SOS", "__disableAction"};
	for i = 1, getn(flags) do
		h.pord = {};
		t0, b0 = h.trade_ok, getn(h.boxes);
		n0 = S_Mark();
		setglobal(flags[i], TRUE);
		V_TradeDock();
		setglobal(flags[i], FALSE);
		HOST_Check(P_Ord() == "" and h.trade_ok == t0 + 1 and getn(h.boxes) == b0 + 1 and S_Logs(n0, "module=plumb event=dock kind=trade line_count=0 result=skipped") == 1,
			flags[i]..": dispatcher skipped, no line, no box, the original once");
	end;
	-- A pending box of an earlier docking is dropped at the next docking; a late answer to it does nothing.
	t0 = h.trade_ok;
	V_TradeDock();
	local old = HOST_Box();
	n0 = S_Mark();
	V_TradeDock();
	HOST_Check(S_Logs(n0, "module=plumb event=box_answer kind=trade box=p_high result=dropped") == 1 and HOST_Box() ~= old, "pending box dropped by the next docking");
	HOST_Press("ok");
	HOST_Press("ok", old);
	HOST_Check(h.trade_ok == t0 + 1, "late answer to the dropped box: no second original");
	-- Box lock held by another owner: no box, the original at once; a stale lock (60 game s) is taken over.
	TRF_BoxTake("hail");
	t0, b0 = h.trade_ok, getn(h.boxes);
	n0 = S_Mark();
	V_TradeDock();
	HOST_Check(h.trade_ok == t0 + 1 and getn(h.boxes) == b0 + 1 and S_Logs(n0, "kind=trade line_count=4 result=vanilla reason=box_lock") == 1, "lock held by hail: no box, original at once");
	TRF.live.bt = TRF.clock.gt - 61;
	V_TradeDock();
	HOST_Check(HOST_Box().text == "P offer high" and TRF.live.box == "dock_trade", "stale lock: taken over, box shown");
	HOST_Press("cancel");
	-- Nested dispatch of the same kind runs only the original.
	h.van = 0;
	P_Van = function() HOST().van = HOST().van + 1; return "v"; end;
	P_Nest = function(kind) P_Rec("nest"); return TRF_PlDock("trade", "P_Van", {}); end;
	TRF_DockLine("trade", 6, "P_Nest");
	h.pord = {};
	local rv = TRF_PlDock("trade", "P_Van", {});
	HOST_Check(h.van == 1 and strfind(P_Ord(), "nest", 1, 1) and HOST_Box().text == "P offer high", "nested call of the same kind: the original only");
	HOST_Press("ok");
	HOST_Check(h.van == 2, "outer original after the answer");
	local p0 = TRF_PlCounts();
	TRF_DockLine("trade", 6, "P_Nest");
	local p1 = TRF_PlCounts();
	HOST_Check(p0.line == p1.line, "registering the same handler again replaces it");
	P_Nest = nil;
	-- Without a box the original's result is passed through.
	local bh, bl = P_BoxHigh, P_BoxLow;
	P_BoxHigh = P_BoxNil; P_BoxLow = P_BoxNil;
	HOST_Check(TRF_PlDock("trade", "P_Van", {}) == "v" and h.van == 3, "no box: the original once, its result passed through");
	P_BoxHigh = bh; P_BoxLow = bl;
	P_Van = nil;
	-- Fee box (kind req, #3) -> its OK docks -> no offer box at the trade dock (wb_box_after_fee 0).
	S_Visit("kadenoa", "5_01", 8);
	P_RegDock();
	local D = S_Setup({});
	b0, t0 = getn(h.boxes), h.trade_ok;
	local tr = S_Trade(D.trade[1]);
	HOST_Check(tr.nb == 1 and tr.box.text ~= "#UI_TradeStationDockRequest" and TRF.live.box == "dock_req", "fee box from the request dispatcher, lock dock_req");
	h.pord = {};
	n0 = S_Mark();
	HOST_Press("ok");
	HOST_Check(h.trade_ok == t0 + 1 and getn(h.boxes) == b0 + 1 and S_Logs(n0, "kind=trade line_count=4 result=vanilla reason=after_fee") == 1
		and not strfind(P_Ord(), "box300", 1, 1), "fee box OK: trade dock lines, no offer box (after_fee), original once");
	h.cfg.wb_box_after_fee = 1;
	S_Visit("kadenoa", "5_01", 8);
	P_RegDock();
	D = S_Setup({});
	tr = S_Trade(D.trade[1]);
	t0 = h.trade_ok;
	HOST_Press("ok");
	HOST_Check(HOST_Box().text == "P offer high" and h.trade_ok == t0, "wb_box_after_fee 1: the offer box follows the fee box");
	HOST_Press("cancel");
	HOST_Check(h.trade_ok == t0 + 1, "offer Cancel: original once");
	h.cfg.wb_box_after_fee = nil;
	-- Patrol (8.10): one offer box per docking; a declined offer is not shown again in the visit.
	T_Jump("gredos");
	local bo = TRF_Faction_BoardOffers;
	P_OfOk = function(a) P_Rec("of:"..tostring(a)); return "P offer taken"; end;
	TRF_Faction_BoardOffers = function()
		return {{k="join", t="P join?", ok=P_OfOk, a=1}, {k="bounty", t="P bounty?", ok=P_OfOk, a=2}};
	end;
	local q0 = h.patrol_ok;
	b0 = getn(h.boxes);
	V_PatrolDock();
	HOST_Check(getn(h.boxes) == b0 + 2 and HOST_Box().text == "P join?" and h.patrol_ok == q0, "patrol: the first offer box, original waits");
	HOST_Press("cancel");
	HOST_Check(h.patrol_ok == q0 + 1 and TRF.live.bkd == ",join,", "offer declined: original once, join declined for the visit");
	h.pord = {};
	s0 = getn(h.screen);
	V_PatrolDock();
	HOST_Check(HOST_Box().text == "P bounty?", "next docking: the next offer");
	HOST_Press("ok");
	HOST_Check(P_Ord() == "of:2," and h.patrol_ok == q0 + 2 and strfind(P_Scr(s0), "P offer taken|", 1, 1), "offer OK: ok(a), the reply line, original once");
	TRF_Faction_BoardOffers = bo;
	P_OfOk = nil;
end;

-- b: _NoneStation_Action chain, CostOfHead, Case_Eject (spec 4.3-4.5) -----------------------------

function P_Depot(param) P_Rec("depot:"..tostring(param)); return HOST().pdep; end;
function P_Prov(idx, tip) if tip == "1" then return "3"; end; return nil; end;
function P_CoHLow(name, count, price) return price - 100; end;
function P_CoHHigh(name, count, price) if name == "PirateCaptain" then return price + 500; end; return nil; end;
function P_CoHErr(name, count, price) error("injected"); end;
function P_Ej(pilot, r, ne) if pilot.tpl == "PirateCaptain" then return 1; end; return 7; end;

function T_PL_B()
	local h = HOST();
	P_Begin("gaoba");
	local D = S_Setup({{"1"}});
	-- Station mood handler alone (prio 100): vanilla line for tip 1 in a quiet region.
	local a = S_None(D.none[1]);
	HOST_Check(a.n == 1 and a.t == "#L_Dnone_live_msg", "station handler: vanilla key, one Message");
	-- #9 depot match first (prio 300): 0 = handled (no vanilla line), a key replaces the param, nil passes on.
	TRF_NoneStationReg(300, "P_Depot");
	h.pdep = 0;
	h.pord = {};
	a = S_None(D.none[1]);
	HOST_Check(a.n == 0 and P_Ord() == "depot:1,", "depot handler returns 0: handled, no vanilla call");
	h.pdep = "2";
	a = S_None(D.none[1]);
	HOST_Check(a.n == 1 and a.t == "#L_Dnone_closed_msg", "depot handler returns a key: vanilla with that key, station not asked");
	h.pdep = nil;
	a = S_None(D.none[1]);
	HOST_Check(a.n == 1 and a.t == "#L_Dnone_live_msg", "depot handler passes: the station mood follows");
	-- Mood provider (TRF_Voice_Prov, row 1 of the station's table).
	TRF_VoiceProvReg("P_Prov");
	a = S_None(D.none[1]);
	HOST_Check(a.n == 1 and a.t == "#L_Dnone_war_closed_msg" and getn(TRF_Voice_Prov()) == 1, "voice provider: key 3 through the station's row 1");
	-- __disableAction: the depot (not always) is skipped, the station logs its gate, vanilla with the param.
	h.pord = {};
	local n0 = S_Mark();
	__disableAction = TRUE;
	a = S_None(D.none[1]);
	__disableAction = FALSE;
	HOST_Check(P_Ord() == "" and a.n == 1 and a.t == "#L_Dnone_live_msg" and S_Logs(n0, "module=station event=pass reason=flag") == 1,
		"__disableAction: depot skipped, station gate logged, vanilla line");
	-- CostOfHead chain: never below the vanilla price; the larger price wins; an error is caught.
	TRF_CostOfHeadReg("P_CoHLow");
	TRF_CostOfHeadReg("P_CoHHigh");
	TRF_CostOfHeadReg("P_CoHErr");
	local ne = S_Expect(function() HOST().cohv = CostOfHead("PirateCaptain", 1); HOST().cohw = CostOfHead("Trader", 2); end);
	HOST_Check(h.cohv == 9 * 200 + 500 and h.cohw == 0 and ne == 2, "CostOfHead: 1800 vanilla -> 2300, trader 0 unchanged, handler errors caught ("..tostring(h.cohv)..")");
	-- Case_Eject: vanilla result passed through, a handler may return 1..3 (7 ignored), never under __NoEject.
	local e0 = h.eject;
	local pc, pt = HOST_Pilot("PirateCaptain"), HOST_Pilot("Trader");
	TRF_EjectReg("P_Ej");
	HOST_Check(Case_Eject(pt) == 2 and Case_Eject(pc) == 1 and h.eject == e0 + 2, "Case_Eject: vanilla 2 kept (7 ignored), captain handler 1, vanilla once per call");
	h.labels.__NoEject = "PirateCaptain";
	HOST_Check(Case_Eject(pc) == 2 and h.eject == e0 + 3, "__NoEject set: the vanilla result stands");
	h.labels.__NoEject = nil;
end;

-- c: clocks, C1 help decay, D1 leg cap (spec 10) ----------------------------------------------

function T_PL_C()
	local h = HOST();
	P_Begin("gredos", {seed=0, queue=0, parked=0, staged=0, raids=0});
	local j0 = TRF_Jumps();
	T_Jump("aurora");
	HOST_Check(TRF_Jumps() == j0 + 1, "jump: clock.j + 1");
	T_SaveLoad();
	HOST_Check(TRF_Jumps() == j0 + 1, "load: clock.j unchanged");
	T_Jump("gredos");
	HOST_Check(TRF_Jumps() == j0 + 2 and TRF.clock.j == j0 + 2, "second jump: + 1");
	-- rs: dt_real only while dt_game > 0 (the unpaused proxy), carried across a load.
	local r0 = TRF_RealSecs();
	TRF_OnTick(0, 5);
	HOST_Check(TRF_RealSecs() == r0, "dt_game 0 (paused): rs unchanged");
	TRF_OnTick(0.5, 2);
	HOST_Check(TRF_RealSecs() == r0 + 2, "dt_game > 0: rs + dt_real");
	T_SaveLoad();
	HOST_Check(TRF_RealSecs() == r0 + 2, "load: rs carried");
	-- D1: at most leg_cap (3) game-time legs per visit; the entry leg always counts; a load keeps the count.
	T_Jump("aurora");
	local L0 = TRF.clock.legs;
	local n0 = S_Mark();
	T_Tick(150, 10);
	HOST_Check(TRF.clock.legs == L0 + 3 and TRF.clock.vl == 3 and (TRF.live.stat.leg_cap or 0) >= 1
		and S_Logs(n0, "module=state event=leg_cap legs="..(L0 + 3).." visit_tick_legs=3 cap=3 result=reached") == 1, "1500 game s in one visit: 3 legs, then capped");
	T_SaveLoad();
	T_Tick(40, 10);
	HOST_Check(TRF.clock.legs == L0 + 3, "after a load in the same visit: still capped");
	T_Jump("gredos");
	HOST_Check(TRF.clock.legs == L0 + 4 and TRF.clock.vl == 0, "entry: the entry leg counts, visit count 0");
	T_Tick(31, 10);
	HOST_Check(TRF.clock.legs == L0 + 5, "next visit: game-time legs count again");
	h.cfg.tune = {leg_cap=0};
	T_Tick(150, 10);
	HOST_Check(TRF.clock.legs >= L0 + 9, "tune leg_cap 0: no cap");
	h.cfg.tune = nil;
	-- C1: help above 10 loses 1 per 20 legs, never below 10.
	TRF.std.help = 15;
	TRF.std.ht = TRF.clock.legs;
	for i = 1, 19 do TRF_AddLeg("test"); end;
	HOST_Check(TRF.std.help == 15, "19 legs: help 15");
	TRF_AddLeg("test");
	HOST_Check(TRF.std.help == 14, "20 legs: help 14");
	for i = 1, 200 do TRF_AddLeg("test"); end;
	HOST_Check(TRF.std.help == 10, "200 more legs: help stops at 10");
	TRF_AddHelp(3, "test");
	HOST_Check(TRF.std.help == 13 and TRF.std.ht == TRF.clock.legs, "help rises above 10: the decay mark restarts");
	for i = 1, 20 do TRF_AddLeg("test"); end;
	HOST_Check(TRF.std.help == 12, "20 legs after the rise: help 12");
	TRF.std.help = 8;
	for i = 1, 60 do TRF_AddLeg("test"); end;
	HOST_Check(TRF.std.help == 8, "help 8: no decay");
	TRF.std.ht = nil;
	TRF_Repair();
	HOST_Check(TRF.std.ht == TRF.clock.legs and TRF.clock.j >= 0 and TRF.clock.rs >= 0 and TRF.clock.vl >= 0, "repair: ht, j, rs, vl present");
end;

-- d: visit slots, seed order, arrival lines, job slot, markers (spec 5, 8) ---------------------------

function P_SeedRec(c) P_Rec("p400"); end;
function P_SeedNo(c) P_Rec("TRF_GnSeedStaged"); c.noseed = "staged"; end;
function P_CapTrim1(g, n) local h = HOST(); h.trim = (h.trim or "")..g..":"..n..","; return n; end;
function P_SeedStop(c) P_Rec("p260"); c.done = 1; end;

function T_PL_D()
	local h = HOST();
	h.labels.CurrentQuest = "5_1"; h.st_label = "TRADE STATION";
	V_Begin("elio", {seed=0, queue=0, parked=0});
	-- Box lock.
	HOST_Check(TRF_BoxTake("a") == 1 and TRF_BoxTake("a") == 1 and TRF_BoxTake("b") == nil and TRF_BoxHolder() == "a"
		and TRF_BoxFree("b") == nil and TRF_BoxFree("a") == 1 and TRF_BoxTake("b") == 1, "box lock: take, refuse, free");
	TRF.live.bt = TRF.clock.gt - 61;
	HOST_Check(TRF_BoxHolder() == nil and TRF_BoxTake("c") == 1 and TRF_BoxHolder() == "c", "box lock: stale after 60 game s");
	-- Escort slot.
	HOST_Check(TRF_EscortTake("pack") == 1 and TRF_EscortTake("ladder") == nil and TRF_EscortTake("pack") == 1
		and TRF_EscortFree("ladder") == nil and TRF_EscortFree("pack") == 1 and TRF_EscortTake("ladder") == 1, "escort slot: first hire wins");
	-- Scripted-event slot: the staged raid goes through it.
	local idx = TRF_CurIdx();
	TRF.live.ev = nil;
	TRF.live.ent = nil;
	TRF_SetDis(idx, 6);
	h.ms.pos = Vector3(-300, 30, 1500);
	HOST_Check(TRF_EventSlotTake("push") == 1 and TRF_EventSlotTake("sweep") == nil and TRF_EventSlot() == "push", "event slot: first claim wins");
	h.rq = {0, 0, 0};
	HOST_Check(not TRF_StagedRoll() and (TRF.live.stat.staged_skip_slot or 0) == 1, "staged raid refused while push holds the slot");
	HOST_Check(TRF_EventSlotFree("sweep") == nil and TRF_EventSlotFree("push") == 1, "event slot: only the holder frees it");
	h.rq = {0, 0, 0};
	HOST_Check(TRF_StagedRoll() == 1 and TRF_EventSlot() == "staged" and TRF_EventSlotTake("feq") == nil, "staged raid takes the slot; later claims refused");
	h.rq = {};
	-- Entry and load clear every slot.
	TRF_BoxTake("x");
	T_Jump("gredos");
	HOST_Check(TRF.live.box == nil and TRF.live.ev == nil and TRF.live.esc == nil and TRF_BoxTake("y") == 1 and TRF_EventSlotTake("vendetta") == 1, "entry: slots empty");
	T_SaveLoad();
	HOST_Check(TRF.live.box == nil and TRF.live.ev == nil, "load: slots empty");
	-- Seed order: the providers of 00 section 6 in priority order; a provider may stop the list.
	TRF_SeedReg(400, "P_SeedRec");
	TRF_SeedReg(260, "P_SeedStop");
	local nm = {"Chase", "Sweep", "Carrier", "Feq", "Staged", "Hold", "Po", "Plain"};
	local keep = {};
	for i = 1, getn(nm) do
		local n = "TRF_GnSeed"..nm[i];
		keep[n] = getglobal(n);
		local w = function(c) P_Rec(%n); return %keep[%n](c); end;
		setglobal(n, w);
	end;
	h.pord = {};
	TRF.live.ent = nil;
	TRF_EntryPlan();
	HOST_Check(P_Ord() == "TRF_GnSeedChase,TRF_GnSeedSweep,TRF_GnSeedCarrier,TRF_GnSeedFeq,TRF_GnSeedStaged,TRF_GnSeedHold,p400,p260,",
		"seed providers in order: chase, sweep, carrier, feq, staged, hold, a #8-slot provider, then a stop ("..P_Ord()..")");
	-- An event took the seed's place: the hold stops the list before the #8 and #5 slots.
	setglobal("TRF_GnSeedStaged", P_SeedNo);
	h.pord = {};
	TRF.live.ent = nil;
	TRF_EntryPlan();
	for k, fn in keep do setglobal(k, fn); end;
	HOST_Check(P_Ord() == "TRF_GnSeedChase,TRF_GnSeedSweep,TRF_GnSeedCarrier,TRF_GnSeedFeq,TRF_GnSeedStaged,TRF_GnSeedHold,",
		"no seed after the staged raid: the hold stops the list before #8 ("..P_Ord()..")");
	-- Arrival lines: traffic's at 5 s, then mod lines at 3 s steps, at most 3 per entry.
	T_Jump("aurora");
	local g0 = h.gt;
	local n0 = S_Mark();
	local q = {TRF_ArrivalLine("p1", "P arr 1"), TRF_ArrivalLine("p2", "P arr 2"), TRF_ArrivalLine("p3", "P arr 3"), TRF_ArrivalLine("p4", "P arr 4")};
	HOST_Check(q[1] == 1 and q[2] == 1 and q[3] == 1 and q[4] == nil and S_Logs(n0, "module=plumb event=arrival_line owner=p4 line_index=4 result=dropped reason=cap") == 1,
		"three mod lines queued, the fourth dropped");
	T_Tick(40, 0.5);
	local at, seen = {}, "";
	for i = 1, getn(h.screen) do
		local e = h.screen[i];
		if strsub(e.t, 1, 5) == "P arr" then seen = seen..e.t.."|"; tinsert(at, e.gt - g0); end;
	end;
	HOST_Check(seen == "P arr 1|P arr 2|P arr 3|" and at[1] >= 8 and at[1] < 9 and at[2] >= 11 and at[2] < 12 and at[3] >= 14 and at[3] < 15,
		"arrival lines at 8, 11, 14 s ("..tostring(at[1])..", "..tostring(at[2])..", "..tostring(at[3])..")");
	-- Lines queued after their slot keep the 3 s spacing.
	T_Jump("gredos");
	T_Tick(20, 0.5);
	g0 = h.gt;
	local ns = getn(h.screen);
	TRF_ArrivalLine("p6", "P arr 6");
	TRF_ArrivalLine("p7", "P arr 7");
	T_Tick(8, 0.5);
	at = {};
	for i = ns + 1, getn(h.screen) do
		local e = h.screen[i];
		if strsub(e.t, 1, 5) == "P arr" then tinsert(at, e.gt - g0); end;
	end;
	HOST_Check(getn(at) == 2 and at[1] < 1 and at[2] >= 3 and at[2] < 4, "late lines: the first at once, the second 3 s after it is due ("..tostring(at[1])..", "..tostring(at[2])..")");
	T_SaveLoad();
	HOST_Check(TRF_ArrivalLine("p5", "P arr 5") == nil, "after a load: no arrival line (no entry)");
	-- Job slot.
	HOST_Check(TRF_JobTake(1, {s=3, pay=500}) == 1 and TRF_JobTake(5, {}) == nil and TRF_JobGet().k == 1 and TRF_JobGet().s == 3, "job slot: one open job");
	T_SaveLoad();
	HOST_Check(TRF_JobGet() and TRF_JobGet().pay == 500, "job slot: saved");
	HOST_Check(TRF_JobClear() == 1 and TRF_JobGet() == nil and TRF_JobTake(5, {t={}}) == nil
		and TRF_JobTake(5, {a=1, b=2, c=3, d=4, e=5, f=6, g=7}) == nil and TRF_JobTake(5, {s=strrep("x", 25)}) == nil, "job slot: clear, nested, 7 fields and long strings refused");
	TRF.job = {k={}};
	TRF_Pl_Fix();
	HOST_Check(TRF.job == nil, "repair: a broken job is dropped");
	HOST_Check(TRF_JobTake(strrep("k", 25), {}) == nil and TRF.job == nil, "job kind longer than 24 refused");
	TRF.job = {k=1, s=strrep("x", 30)};
	TRF.mk = strrep("x", 300);
	TRF_Pl_Fix();
	HOST_Check(TRF.job == nil and TRF.mk == nil, "repair: a job string over 24 and a TRF.mk over 272 characters dropped");
	-- Markers: refused under a story mission, TRF_ labels only, at most 8, deleted before a jump and after a load.
	local nv0 = HOST_Navs();
	h.qs = TRUE;
	local ok, why = TRF_MarkerAdd("p1", "TRF_P1_A", 100, 0, 100);
	h.qs = FALSE;
	HOST_Check(ok == nil and why == "quest" and HOST_Navs() == nv0, "marker refused while GetPlayerQuestState() == TRUE");
	HOST_Check(TRF_MarkerAdd("p1", "TRF_P1_Q", 0, 0, 0) == 1 and HOST_Navs() == nv0 + 1, "marker before the mission");
	h.qs = TRUE;
	T_Tick(2, 0.5);
	h.qs = FALSE;
	HOST_Check(HOST_Navs() == nv0 and TRF.mk == nil, "mission started: the marker is deleted");
	ok, why = TRF_MarkerAdd("p123456789", "TRF_P1_O", 0, 0, 0);
	HOST_Check(ok == nil and why == "owner", "marker owner longer than 8 refused");
	ok, why = TRF_MarkerAdd("p1", "trf_bad", 0, 0, 0);
	HOST_Check(ok == nil and why == "label", "marker label must start with TRF_");
	HOST_Check(TRF_MarkerAdd("p1", "TRF_P1_A", 100, 0, 100) == 1 and HOST_Navs() == nv0 + 1 and GetNavPointByLabel("TRF_P1_A") and TRF.mk == "TRF_P1_A=p1;",
		"marker added, labelled, saved label");
	for i = 1, 7 do TRF_MarkerAdd("p2", "TRF_P2_"..i, i, 0, 0); end;
	ok, why = TRF_MarkerAdd("p2", "TRF_P2_9", 0, 0, 0);
	HOST_Check(ok == nil and why == "cap" and HOST_Navs() == nv0 + 8, "at most 8 markers");
	HOST_Check(TRF_MarkerClear("p1") == 1 and HOST_Navs() == nv0 + 7 and not strfind(TRF.mk, "TRF_P1_A", 1, 1), "clear by owner");
	T_SaveLoad();
	HOST_Check(HOST_Navs() == nv0 and TRF.mk == nil, "load: markers of the saved visit deleted by label");
	TRF_MarkerAdd("p1", "TRF_P1_B", 0, 0, 0);
	T_Jump("gredos");
	HOST_Check(HOST_Navs() == nv0 and TRF.mk == nil, "jump: every marker deleted");
	-- Byte cost of the worst cases (spec 12): job of 6 fields of 24 characters, 8 markers.
	local jf = {};
	for k = 1, 6 do jf["f"..k] = strrep("x", 24); end;
	TRF_JobTake(5, jf);
	TRF.mk = "";
	for k = 1, 8 do TRF.mk = TRF.mk.."TRF_"..strrep("m", 19)..k.."="..strrep("o", 8)..";"; end;
	print("HOST info plumb worst case: job "..(8 + 3 + HOST_SaveSize(TRF.job)).." bytes, mk "..(8 + 2 + HOST_SaveSize(TRF.mk)).." bytes");
	HOST_Check(8 + 3 + HOST_SaveSize(TRF.job) <= 300 and 8 + 2 + HOST_SaveSize(TRF.mk) <= 300, "worst-case job and marker bytes within the spec figures");
	TRF_JobClear(); TRF.mk = nil;
end;

-- e: raid help, ship caps, fst clamp, pk, orphan scan (spec 6, 7, 9, 11) ------------------------------

function P_RhA(n, rd, amt) return 0.5; end;
function P_RhB(n, rd, amt) return 0.8; end;
function P_RhX(n, rd, amt) return {ex=1}; end;
function P_RhC(n, rd, amt) if HOST().rhc then return "cancel"; end; return nil; end;
function P_CapA(g) return 3; end;
function P_CapB(g) return 2; end;
function P_CapC(g) return 4; end;
function P_CapD(g) return 1; end;

function T_PL_E()
	local h = HOST();
	P_Begin("gredos", {seed=0, queue=0, parked=0, staged=0, raids=0});
	-- 8.5 pure rule: cancel, exclusion, one factor (the lowest), factors never multiply.
	local t = function(rs) local a, w = TRF_RaidHelpOf(1000, 4, rs); return tostring(a)..":"..tostring(w); end;
	HOST_Check(t({0.5, 0.7}) == "500:factor" and t({0.7, 0.5}) == "500:factor" and t({"cancel", 0.5}) == "0:cancel"
		and t({{ex=1}}) == "750:excluded" and t({{ex=1}, 0.5}) == "375:excluded_factor" and t({{ex=4}}) == "0:excluded"
		and t({}) == "1000:none" and t({1.5}) == "1000:factor" and t({{cancel=1}}) == "0:cancel",
		"raid help: lowest factor once, cancel, exclusions");
	-- Resolvers through trf_raid's pay path.
	TRF_RaidHelpReg("P_RhA");
	TRF_RaidHelpReg("P_RhB");
	TRF_RaidHelpReg("P_RhX");
	TRF_RaidHelpReg("P_RhC");
	local cur = TRF_CurIdx();
	TRF.live.tr[901] = {id=901, st="run", nm=1, cls=1, path="B", np=1};
	local rd = {n=77, id=901, hit=1, ns=4, st="fight"};
	local amt0 = floor(0.5 * TRF_Rd_PayN(cur));
	local c0 = h.credits;
	local n0 = S_Mark();
	TRF_Rd_Pay(77, rd);
	local want = floor(amt0 * 3 / 4 * 0.5);
	HOST_Check(rd.paid == want and h.credits == c0 + want and S_Logs(n0, "module=plumb event=raid_help raid_id=77 credits_before="..amt0.." credits_after="..want.." rule=excluded_factor resolver_count=3") == 1
		and S_Logs(n0, "help_rule=excluded_factor") == 1, "TRF_Rd_Pay: one ship excluded, factor 0.5 (not 0.4) -> "..want.." of "..amt0);
	h.rhc = 1;
	local rd2 = {n=78, id=901, hit=1, ns=4, st="fight"};
	c0 = h.credits;
	TRF_Rd_Pay(78, rd2);
	HOST_Check(rd2.paid == 0 and h.credits == c0, "a captain claim (cancel): no credits");
	h.rhc = nil;
	TRF.live.tr[901] = nil;
	-- Ship caps: registered groups count in cap_ships; trim order rival, pack, scavenger, then skip.
	TRF_CapReg("TRF_Rival_1", "P_CapA", "rival");
	TRF_CapReg("TRF_Merc_1", "P_CapB", "pack");
	TRF_CapReg("TRF_Scv_1", "P_CapC", "scavenger");
	TRF_CapReg("TRF_Def_1", "P_CapD", nil);
	local plan, left = TRF_CapTrim(4);
	local pl = function(p) local s = ""; for i = 1, getn(p) do s = s..p[i].g..":"..p[i].n..","; end; return s; end;
	HOST_Check(TRF_CapShips() == 10 and pl(plan) == "TRF_Rival_1:3,TRF_Merc_1:1," and left == 0, "trim 4: rival 3, pack 1 ("..pl(plan)..")");
	plan, left = TRF_CapTrim(12);
	HOST_Check(pl(plan) == "TRF_Rival_1:3,TRF_Merc_1:2,TRF_Scv_1:4," and left == 3, "trim 12: rival, pack, scavenger, 3 left to skip");
	TRF_CapReg("TRF_Rival_1", "P_CapD", "rival");
	HOST_Check(TRF_CapShips() == 8, "a group registered again replaces its entry");
	V_ClearTr();
	TRF_CanSpawn(0, "trader");
	local caps = TRF.live.caps;
	local ok1 = TRF_CanSpawn(caps - 8, "trader");
	local ok2, why2 = TRF_CanSpawn(caps - 7, "trader");
	HOST_Check(ok1 and not ok2 and why2 == "ships", "cap_ships counts the 8 registered ships (cap "..tostring(caps)..")");
	-- Over the cap the trimmable groups give up ships first (rival before pack), then the spawn is skipped.
	TRF_CapReg("TRF_Rival_1", "P_CapD", "rival", "P_CapTrim1");
	h.trim = nil;
	n0 = S_Mark();
	ok2, why2 = TRF_CanSpawn(caps - 7, "trader");
	HOST_Check(ok2 and h.trim == "TRF_Rival_1:1," and S_Logs(n0, "module=plumb event=cap_trim over_count=1 group_count=1 freed_count=1") == 1, "over by 1: the rival frees 1, the spawn fits");
	h.trim = nil;
	ok2, why2 = TRF_CanSpawn(caps - 5, "trader");
	HOST_Check(not ok2 and why2 == "ships" and h.trim == "TRF_Rival_1:1,", "over by 3: rival 1, the pack has no trim, skipped");
	TRF_CapReg("TRF_Rival_1", "P_CapD", "rival");
	h.trim = nil;
	-- S35: the owed payment is that docking's offer; the mark is gone at the next pirate docking.
	local of0 = TRF.offer;
	TRF.offer = {k=3, s=3, t=TRF.clock.legs + 8, p=100};
	HOST_Check(type(TRF_FcPoOwe("pir")) == "string" and TRF.offer == nil and TRF.live.pp == 1 and TRF_FcPoBody() == "paid" and TRF.live.pp == nil,
		"owed S35 payment: no offer box in the same docking");
	TRF.live.pp = 1;
	HOST_Check(TRF_FcPoOwe("pir") == nil and TRF.live.pp == nil, "next pirate docking: the paid mark cleared");
	TRF.offer = of0;
	-- Supply contract box: takes the hail's lock, frees it at the answer; refused while another box holds it.
	local sco = TRF_SpCtOffer;
	TRF_SpCtOffer = function(id) return "P contract", 100; end;
	TRF_BoxTake("hail");
	local nbx = getn(h.boxes);
	HOST_Check(TRF_SupplyCtDo(5) == 1 and getn(h.boxes) == nbx + 1 and TRF.live.box == "supply_ct", "contract box: the lock passes from the hail");
	HOST_Press("cancel");
	HOST_Check(TRF.live.box == nil and TRF.live.spc == nil, "contract box answered: lock free");
	TRF_BoxTake("meeting");
	HOST_Check(TRF_SupplyCtDo(5) == nil and getn(h.boxes) == nbx + 1, "contract box refused while another mod box is open");
	TRF_BoxFree("meeting");
	TRF_SpCtOffer = sco;
	-- fst clamp: a faction whose team is at war with the player keeps its standing; drift too.
	TRF.std.fst = "55555";
	local tm = TRF_FacTeam(1);
	h.rel_team = {};
	h.rel_team[tm.."|"..PLAYER_TEAM] = RELATION_WAR;
	n0 = S_Mark();
	TRF_FstAdd(1, -2, "test");
	TRF_FstAdd(2, -2, "test");
	HOST_Check(TRF.std.fst == "53555" and S_Logs(n0, "module=faction event=faction_standing faction="..tm.." reason=test standing_before=5 standing_after=5 result=frozen") == 1,
		"fst: frozen while "..tm.." is at war, the other faction changes");
	TRF.std.fst = "15555";
	HOST_Check(TRF_FstClamp("55555") == "55555", "clamp after an event: the war faction's digit restored");
	h.rel_team = nil;
	TRF.std.fst = "15555";
	HOST_Check(TRF_FstClamp("55555") == "15555" and TRF_FstClamp(nil) == "15555", "no war: the new digit stays");
	TRF.std.fst = "55555";
	-- pk: player-caused shortages are never relief targets; a merge keeps pk.
	TRF.short = {};
	local L = TRF.clock.legs;
	TRF_ShortAdd(3, 2, L + 6, 1);
	TRF_ShortAdd(6, 3, L + 6);
	local rl = TRF_ShortRelief();
	HOST_Check(getn(rl) == 1 and rl[1].s == 6 and TRF.short[1].pk == 1 and TRF.short[2].pk == nil, "relief targets skip pk = 1");
	TRF_ShortAdd(6, 3, L + 8, 1);
	HOST_Check(getn(TRF_ShortRelief()) == 0 and TRF.short[2].pk == 1 and TRF.short[2].t == L + 8, "merge with a player-caused shortage: pk kept");
	TRF.short = {};
	TRF_Ev_Short(9, 4, 1);
	TRF_Ev_Short(12, 4);
	HOST_Check(TRF.short[1].pk == 1 and TRF.short[2].pk == nil, "kill shortage: pk from counted player fire only");
	TRF.short = {};
	-- Orphan scan at load: ships labelled trf_<prefix>_<n>_<j> deleted, TRF_G<prefix>_ globals cleared.
	local s1 = T_LabelShip("trf_cust_1_1", 800, 800, "TRF_Cust_1");
	local s2 = T_LabelShip("trf_rival_2_3", 900, 900, "TRF_Rival_2");
	local s3 = T_LabelShip("trf_other_1_1", 1000, 1000, "TRF_Other");
	TRF_GCust_7 = HOST_Group("TRF_Cust_7");
	n0 = S_Mark();
	T_SaveLoad();
	HOST_Check(not s1.alive and not s2.alive and s3.alive and TRF_GCust_7 == nil and S_Logs(n0, "module=plumb event=orphan deleted_count=2 global_count=1") == 1,
		"load: 2 orphan ships of the group prefixes deleted, group global cleared, other labels kept");
	s3.alive = nil;
	HOST_Check(T_LeftGlobals() == "", "no group globals left"..T_LeftGlobals());
	TRF_GScv_2 = 1;
	HOST_Check(strfind(T_LeftGlobals(), "TRF_GScv_2", 1, 1), "host lint: a left TRF_GScv_ global is reported");
	TRF_GScv_2 = nil;
	-- Dump line.
	n0 = S_Mark();
	TRF_DumpState("test");
	HOST_Check(S_Logs(n0, "module=plumb event=dump ") == 1, "dump: plumb line");
end;

-- Dispatch ---------------------------------------------------------------------------------

local sc = getenv("TRF_PLUMB") or "";
local fn = getglobal("T_PL_"..strupper(sc));
print("HOST ==== plumb scenario pl-"..sc.." dir="..HOST().dir);
if type(fn) == "function" then
	fn();
	HOST_Check(T_LeftGlobals() == "", "no handle globals left at the end"..T_LeftGlobals());
else
	HOST_Check(nil, "unknown plumb scenario "..sc);
end;
HOST_Check((HOST().gpm_tick or 0) == 0, "no GetPlayerMotherShip from a tick (n="..tostring(HOST().gpm_tick or 0)..")");
print("HOST errors="..HOST().errors.." fails="..HOST().fails);
if HOST().errors > 0 or HOST().fails > 0 then exit(1); end;
exit(0);
