-- Demand result page and No witnesses scenarios (design/demand-page-spec.md 9) under stock Lua 4.0.1: TRF_DM=a..g,
-- run by run_host.sh as its own entry point. a the page as boxes through the hail menu (comply: answer, items, the
-- question box, Leave; refusal: one box), the item names, demand_k, the items log value, cfg demand_page 0; b the
-- page as the dialog TRF_HailPg (hail_box 2: answers, tokens, Leave, Esc, No witnesses, the refusal page, the
-- fallback to the boxes); c No witnesses and every ship killed unseen: retracted (heat back, kill heat skipped, pro
-- and dis as a kill, the lost line); d witnessed: a ship in range, a station in range, an escort left alive, no
-- count native (witness_slack 0); e the time-out (step and late kill), the refused marks, the dump and the save size;
-- f the subtractions of the witness count: the player's fighters, witness_slack, the flight's earlier wrecks; g cfg
-- demand_drop (the robbed stacks in one container beside the trader, the fallbacks, the jump and load cleanup); h the
-- typed witness rule through TRF_Near (spec 5.8: the HOST_Carcasses stub with a rocket, a wreck, a station, a player
-- fighter, the flight's own ships, a drop container, and the native answering nil: the count path).
-- Every run but h leaves TRF_Carcasses undefined, so a..g stay on the count path.
-- Loads host_station.lua up to its first scenario, as host_captain.lua does. Natives from host_stubs.lua:
-- GetCarcassCountInSphere (HOST().cc_ships, cc_static), GetPilot (HOST().crew), the mothership pilot's flight
-- (HOST().pwing, HOST_PlayerShip), StartTradeDialog/SetReplaceValue/ShowAnswer/HideAnswer, ShowMsgBox, CombineStr
-- and NewTrigger.

local f = openfile((getenv("TRF_TESTS") or "./").."host_station.lua", "r");
if not f then print("HOST FAIL host_demand.lua: cannot open host_station.lua"); exit(1); end;
local src = read(f, "*a");
closefile(f);
local cut = strfind(src, "\n-- a: install (12.1, 6.1)", 1, 1);
if not cut then print("HOST FAIL host_demand.lua: marker '-- a: install (12.1, 6.1)' missing in host_station.lua"); exit(1); end;
dostring(strsub(src, 1, cut), "host_station.lua");

-- Helpers ----------------------------------------------------------------------------------

-- Config of these runs: entry events, raids and other modules that would spawn ships or claim the box off, log 2.
function DM_Cfg(t)
	local c = {sweeps=0, sweep_ct=0, feq=0, staged=0, seed=0, queue=0, parked=0, voice_events=0, dconv=0, raids=0,
		carriers=0, po=0, bases=0, conv=0, enable_survivors=0, lad_enabled=0, charter=0, enable_scars=0, contracts=0, log=2};
	if t then for k, v in t do c[k] = v; end; end;
	return c;
end;

function DM_Begin(t)
	local h = HOST();
	h.labels.CurrentQuest = "5_1";
	h.st_label = nil;
	S_Begin("gredos", DM_Cfg(t));
	h.credits = 1000000;
	h.ms.model = "mothership_arba";
end;

-- A point of the current system with no map station or portal within witness_r.
function DM_Far()
	local R = TRF_SpT("witness_r", 1500);
	for i = 1, 20 do
		local p = {x=3000 * i, y=0, z=3000 * i};
		local ns, np = TRF_SpStatic(p, R);
		if ns == 0 and np == 0 then return p; end;
	end;
	return nil;
end;

-- A trader 40 units from the mothership at p (default DM_Far()), heat h0, a known hold, braveness 0.2 (no roll).
-- Returns id, record, handles.
function DM_Trader(p, h0, hold)
	local h = HOST();
	V_ClearTr();
	T_Tick(2, 0.5);
	-- Kills of earlier runs raise dis, lower pro and fill the visit kill count, which would stop the spawn.
	local cur = TRF_CurIdx();
	TRF.live.kills = 0;
	TRF_SetDis(cur, 0);
	if type(TRF.sys) == "table" and type(TRF.sys[cur]) == "table" then TRF.sys[cur].pro = 5; end;
	p = p or DM_Far();
	h.ms.pos = Vector3(p.x, p.y, p.z);
	TRF.std.heat = h0 or 0;
	local id = T_Spawn("B") or T_Spawn("A");
	T_MoveTr(id, p.x + 40, p.y, p.z);
	local r = TRF.live.tr[id];
	r.co = 1;
	r.br = 0.2;
	r.hold = hold or {{i="Cargo_01", n=2, s=1}, {i="Cargo_04", n=2, s=1}};
	h.ms.inv = {};
	return id, r, TRF_H().tr[id];
end;

-- Demand on trader id outside the hail: comply (roll 0, then rk for the container roll) or refuse (roll 99).
function DM_Demand(id, comply, rk)
	local h = HOST();
	if comply then h.rq = {0, rk or 2}; else h.rq = {99}; end;
	local res = TRF_DemandDo(id);
	h.rq = {};
	return res;
end;

-- Close an open page chain the way a player leaves it: OK on an answer box, Cancel on the question, Esc on a dialog.
function DM_End()
	local h = HOST();
	for i = 1, 6 do
		if not TRF.live.hl then return; end;
		local b = HOST_Box();
		if h.dlg and h.dlg.open then HOST_DlgEsc();
		elseif b and not b.done then if b.cancel then HOST_Press("cancel"); else HOST_Press("ok"); end; end;
		T_Tick(3, 0.5);
	end;
end;

-- Containers in the mothership inventory.
function DM_Got()
	local n, q = 0, HOST().ms.inv;
	for i = 1, getn(q) do n = n + q[i][2]; end;
	return n;
end;

-- 1 when a screen or radio line after the marks (s0 screen, m0 msgs) contains text (plain).
function DM_Said(s0, m0, text)
	local h = HOST();
	for i = (s0 or 0) + 1, getn(h.screen) do if strfind(h.screen[i].t, text, 1, 1) then return 1; end; end;
	for i = (m0 or 0) + 1, getn(h.msgs) do if strfind(h.msgs[i].t, text, 1, 1) then return 1; end; end;
	return nil;
end;

-- Kill trader id with counted player fire (other: without it): every ship dead (all = 1) or the transports only,
-- then the died triggers.
function DM_Kill(id, all, other)
	local x = TRF_H().tr[id];
	local r = TRF.live.tr[id];
	r.pa = TRF_SpGt();
	if other then r.pa = nil; end;
	local l = x.tp;
	if all then l = x.sh; end;
	for k = 1, getn(l) do l[k].alive = nil; end;
	HOST_FireAll("died", "TRF_OnShipDied("..id..",");
end;

-- Live non-transport ships of trader id (escorts); at least one is added from the flight list when none.
function DM_Escorts(x)
	local n = 0;
	for i = 1, getn(x.sh) do
		local tp = nil;
		for j = 1, getn(x.tp) do if x.tp[j] == x.sh[i] then tp = 1; end; end;
		if not tp and x.sh[i].alive then n = n + 1; end;
	end;
	return n;
end;

-- Mark trader id as prey through the page boxes (comply page OK, question OK) from a fresh demand.
function DM_Mark(id)
	DM_Demand(id, 1);
	HOST_Press("ok");
	T_Tick(1, 0.5);
	HOST_Press("ok");
	T_Tick(1, 0.5);
	return TRF.live.tr[id].dw;
end;

-- a: the page as boxes -------------------------------------------------------------------------------

function T_DM_A()
	local h = HOST();
	DM_Begin();
	local T = TRF_Tune();
	HOST_Check(T.demand_k == 3 and T.witness_t == 180 and T.witness_r == 1500 and T.witness_dead == 0 and T.witness_slack == 1
		and TRF_Opt("demand_page") == 1, "tune demand_k 3, witness_t 180, witness_r 1500, witness_dead 0, witness_slack 1; cfg demand_page 1");
	-- Through the hail menu (box chain): Cancel until the demand option, OK -> the page after the due call.
	local id, r = DM_Trader(nil, 0);
	local nb = getn(h.boxes);
	HOST_Check(TRF_HailOpen(id, "focus") == "menu", "hail menu opened");
	local lab = TRF_HlLabel(id, "demand");
	local k = 0;
	while k < 12 and not strfind(HOST_Box().text, lab, 1, 1) do HOST_Press("cancel"); T_Tick(1, 0.5); k = k + 1; end;
	HOST_Check(strfind(HOST_Box().text, lab, 1, 1), "the menu reaches "..lab);
	-- Comply roll 0 and container roll 2 forced (the tick between OK and the due call may draw other numbers).
	local sr = TRF_SpRand;
	TRF_SpRand = function(n) if n == 100 then return 0; end; if n == 3 then return 2; end; return %sr(n); end;
	local n0 = S_Mark();
	local s1, m1 = getn(h.screen), getn(h.msgs);
	HOST_Press("ok");
	HOST_Check(DM_Got() == 0, "nothing runs inside the box callback");
	T_Tick(1, 0.5);
	TRF_SpRand = sr;
	local nm = TRF_SpName(r);
	local want = TRF_SpTxt("dmok", nm).."\n"..TRF_SpTxt("dmpgot", nm, "2 x Cargo_01, 1 x Cargo_04");
	local bx = HOST_Box();
	HOST_Check(bx.text == want and bx.cancel == nil and TRF.live.hl and TRF.live.hl.w == "pg" and TRF.live.hl.pn == 1 and h.box_nested == 0,
		"comply page: the answer and the moved items in one OK box: "..tostring(bx.text));
	HOST_Check(DM_Got() == 3 and S_Logs(n0, "module=supply event=demand_comply trader_id="..id.." container_count=3 moved_count=3 heat=2 items=Cargo_01:2,Cargo_04:1") == 1
		and S_Logs(n0, "module=hail event=page trader_id="..id.." via=box no_witness_offered=true") == 1,
		"demand_k 3, roll 2: 3 containers, the items log value, the page log");
	HOST_Check(not DM_Said(s1, m1, TRF_SpTxt("dmok", nm)), "no separate answer line while the page is up");
	-- OK -> "No witnesses?" (OK/Cancel); Cancel = Leave: chain closed, no mark.
	HOST_Press("ok");
	HOST_Check(getn(h.boxes) == nb + k + 2, "the question waits for the due call");
	T_Tick(1, 0.5);
	bx = HOST_Box();
	HOST_Check(bx.text == TRF_Txt("dmpq") and bx.cancel ~= nil and TRF.live.hl.w == "pgq", "second box: "..bx.text);
	HOST_Press("cancel");
	T_Tick(1, 0.5);
	HOST_Check(TRF.live.hl == nil and r.dw == nil and S_Logs(n0, "module=hail event=close trader_id="..id.." reason=leave") == 1 and TRF.live.box == nil,
		"Cancel = Leave: chain closed, no mark, box lock free ("..TRF_Dump({TRF.live.hl, r.dw, TRF.live.box})..")");
	-- Refusal page: one OK box, no question.
	local id2, r2 = DM_Trader(nil, 0);
	n0 = S_Mark();
	nb = getn(h.boxes);
	HOST_Check(DM_Demand(id2, nil) == "refuse", "refusal at roll 99");
	bx = HOST_Box();
	HOST_Check(getn(h.boxes) == nb + 1 and bx.text == TRF_SpTxt("dmno", TRF_SpName(r2)) and TRF.live.hl.pn == nil
		and S_Logs(n0, "event=page trader_id="..id2.." via=box no_witness_offered=false") == 1, "refusal page: the refusal text alone");
	HOST_Press("ok");
	T_Tick(1, 0.5);
	HOST_Check(TRF.live.hl == nil and getn(h.boxes) == nb + 1 and r2.dw == nil, "refusal OK = Leave: no question box");
	-- demand_k 1 (and 0): always one container, no roll taken.
	h.cfg.tune = {demand_k=1};
	local id3 = DM_Trader(nil, 0);
	n0 = S_Mark();
	h.rq = {0, 2};
	TRF_DemandDo(id3);
	HOST_Check(getn(h.rq) == 1 and DM_Got() == 1 and S_Logs(n0, "container_count=1 moved_count=1 heat=2 items=Cargo_01:1") == 1, "demand_k 1: one container, no container roll");
	h.rq = {};
	DM_End();
	h.cfg.tune = {demand_k=0};
	HOST_Check(TRF_SpDemandK() == 1, "demand_k 0: one container");
	h.cfg.tune = nil;
	-- Item names: the vanilla #M_Name_<id> through CombineStr, the id when it comes back as a key.
	local cs = CombineStr;
	CombineStr = function(k, v) if k == "#M_Name_Cargo_01" then return "Machinery"; end; return k; end;
	HOST_Check(TRF_SpItems({{i="Cargo_01", n=2}, {i="Cargo_04", n=1}}) == "2 x Machinery, 1 x Cargo_04" and TRF_SpItems({}) == TRF_SpTxt("dmpnone"),
		"item names: loc name, id fallback, nothing");
	CombineStr = nil;
	HOST_Check(TRF_SpItemName("Uranium") == "Uranium", "no CombineStr: the id");
	CombineStr = cs;
	-- demand_page 0: the answer as a line, no page.
	h.cfg.demand_page = 0;
	local id4, r4 = DM_Trader(nil, 0);
	nb = getn(h.boxes);
	local s0, m0 = getn(h.screen), getn(h.msgs);
	DM_Demand(id4, 1);
	HOST_Check(getn(h.boxes) == nb and TRF.live.hl == nil and DM_Said(s0, m0, TRF_SpTxt("dmok", TRF_SpName(r4))), "demand_page 0: the line, no box");
	h.cfg.demand_page = nil;
	-- hail_box 0: lines.
	h.cfg.tune = {hail_box=0};
	local id5, r5 = DM_Trader(nil, 0);
	s0, m0 = getn(h.screen), getn(h.msgs);
	DM_Demand(id5, nil);
	HOST_Check(getn(h.boxes) == nb and DM_Said(s0, m0, TRF_SpTxt("dmno", TRF_SpName(r5))), "hail_box 0: the refusal as a line");
	h.cfg.tune = nil;
	-- cfg loc_mode 1: the scaffold keys (the RU .loc text), the item list after #TRF_dmpgot.
	TRF_H().loc = nil; h.cfg.loc_mode = 1;
	local id6 = DM_Trader(nil, 0);
	DM_Demand(id6, 1);
	bx = HOST_Box();
	HOST_Check(bx.text == "#TRF_dmok\n#TRF_dmpgot: 2 x Cargo_01, 1 x Cargo_04" and TRF_SpTxt("dmplost", "x") == "#TRF_dmplost"
		and TRF_SpTxt("dmno", "x") == "#TRF_dmno", "loc_mode 1: the page as keys and the items: "..tostring(bx.text));
	DM_End();
	TRF_H().loc = nil; h.cfg.loc_mode = nil;
	V_ClearTr();
end;

-- b: the page as the dialog --------------------------------------------------------------------------

function T_DM_B()
	local h = HOST();
	DM_Begin();
	local us = TRF_UiState;
	h.cfg.tune = {hail_box=2};
	h.cfg.hail_xml = 1;
	TRF_UiState = HOST_UiState; h.ui = 0;
	-- Comply: TRF_HailPg with Leave and No witnesses, "FTU <name>: <answer and items>".
	local id, r = DM_Trader(nil, 0);
	local nb, nd = getn(h.boxes), getn(h.tdlgs);
	local n0 = S_Mark();
	DM_Demand(id, 1);
	local td = h.tdlgs[nd + 1] or {};
	local nm = TRF_HlName(r);
	local body = TRF_SpTxt("dmok", nm);
	body = strsub(body, strlen("FTU "..nm..": ") + 1).."\n"..TRF_SpTxt("dmpgot", nm, "2 x Cargo_01, 1 x Cargo_04");
	HOST_Check(td.d == "TRF_HailPg" and td.init == "TRF_HlPgInit" and h.dlg and h.dlg.open and getn(h.boxes) == nb and TRF.live.hl.w == "dlg",
		"comply: StartTradeDialog(TRF_HailPg, TRF_HlPgInit), no box");
	HOST_Check(HOST_DlgVis() == "a_leave a_nowit" and HOST_DlgText() == "FTU "..nm..": "..body and HOST_DlgText("a_leave") == "- Leave"
		and HOST_DlgText("a_nowit") == "- No witnesses" and S_Logs(n0, "event=page trader_id="..id.." via=dialog no_witness_offered=true") == 1,
		"page: msg10 with #who# #m1#, both answers: "..tostring(HOST_DlgText()));
	HOST_Check(S_Logs(n0, "module=hail event=dialog_answers trader_id="..id.." dialog=page answers=leave,nowit") == 1, "log 2: page answers");
	-- Leave: chain closed, no mark.
	HOST_DlgPick("a_leave");
	HOST_Check(TRF.live.hl == nil and r.dw == nil and S_Logs(n0, "event=close trader_id="..id.." reason=leave") == 1, "Leave: chain closed");
	T_Tick(3, 0.5);
	HOST_Check(S_Logs(n0, "reason=\"dialog closed\"") == 0, "no second close after the pick");
	-- Esc: Leave by the dialog check.
	local id2, r2 = DM_Trader(nil, 0);
	n0 = S_Mark();
	DM_Demand(id2, 1);
	HOST_DlgEsc();
	T_Tick(3, 0.5);
	HOST_Check(TRF.live.hl == nil and r2.dw == nil and S_Logs(n0, "event=close trader_id="..id2.." reason=\"dialog closed\"") == 1, "Esc = Leave");
	-- No witnesses: the mark from the due call, nothing inside the callback.
	local id3, r3 = DM_Trader(nil, 0);
	n0 = S_Mark();
	DM_Demand(id3, 1);
	HOST_DlgPick("a_nowit");
	HOST_Check(r3.dw == nil and TRF.live.hl.w == "wait", "No witnesses pick: recorded only");
	T_Tick(1, 0.5);
	HOST_Check(type(r3.dw) == "table" and r3.dw.w == 0 and type(r3.dw.t) == "number" and r3.dw.b == 0 and TRF.live.hl == nil
		and S_Logs(n0, "module=supply event=demand_prey trader_id="..id3.." background_count=0 ") == 1
		and S_Logs(n0, "module=hail event=option_result trader_id="..id3.." key=nowit result=prey") == 1,
		"No witnesses: pw = {t, w 0, b 0}, chain closed ("..TRF_Dump(r3.dw)..")");
	-- Refusal page: Leave only.
	local id4 = DM_Trader(nil, 0);
	DM_Demand(id4, nil);
	HOST_Check(HOST_DlgVis() == "a_leave" and TRF.live.hl.pn == nil, "refusal page: Leave only ("..HOST_DlgVis()..")");
	HOST_DlgPick("a_leave");
	-- A stale page dialog (gen change) and a nowit pick on a page without it: Leave.
	local id5, r5 = DM_Trader(nil, 0);
	DM_Demand(id5, nil);
	HOST_DlgEsc();
	TRF_HlDlgA_nowit();
	T_Tick(1, 0.5);
	HOST_Check(TRF.live.hl == nil and r5.dw == nil, "nowit on a refusal page: Leave");
	-- Fallback (UI not idle): the boxes.
	local id6 = DM_Trader(nil, 0);
	nb, nd = getn(h.boxes), getn(h.tdlgs);
	h.ui = -1;
	DM_Demand(id6, 1);
	h.ui = 0;
	HOST_Check(getn(h.tdlgs) == nd and getn(h.boxes) == nb + 1 and TRF.live.hl.w == "pg", "UI not idle: the page as boxes");
	DM_End();
	-- Through the hail menu dialog: a_demand, then the page dialog on the menu's chain while the menu's dialog check
	-- is still due; Leave, No witnesses and Esc on it.
	local sr = TRF_SpRand;
	for i, act in {"leave", "nowit", "esc"} do
		local id7, r7 = DM_Trader(nil, 0);
		n0 = S_Mark();
		nd = getn(h.tdlgs);
		TRF_HailOpen(id7, "focus");
		local t1 = h.tdlgs[nd + 1] or {};
		HOST_Check(t1.d == "TRF_Hail" and h.dlg and h.dlg.open and strfind(HOST_DlgVis(), "a_demand", 1, 1), act..": the menu dialog with a_demand: "..HOST_DlgVis());
		TRF_SpRand = function(n) if n == 100 then return 0; end; if n == 3 then return 2; end; return %sr(n); end;
		HOST_DlgPick("a_demand");
		T_Tick(1, 0.5);
		TRF_SpRand = sr;
		local t2 = h.tdlgs[nd + 2] or {};
		HOST_Check(t2.d == "TRF_HailPg" and h.dlg and h.dlg.open and TRF.live.hl and TRF.live.hl.id == id7 and TRF.live.hl.w == "dlg"
			and HOST_DlgVis() == "a_leave a_nowit" and S_Logs(n0, "event=close trader_id="..id7) == 0
			and S_Logs(n0, "event=page trader_id="..id7.." via=dialog no_witness_offered=true") == 1, act..": the page dialog on the menu chain, no close");
		T_Tick(3, 0.5);
		HOST_Check(h.dlg.open and TRF.live.hl and TRF.live.hl.w == "dlg" and S_Logs(n0, "event=close trader_id="..id7) == 0,
			act..": the menu's pending check leaves the page open");
		if act == "leave" then HOST_DlgPick("a_leave");
		elseif act == "nowit" then HOST_DlgPick("a_nowit");
		else HOST_DlgEsc(); end;
		T_Tick(3, 0.5);
		local want = "reason=leave";
		if act == "nowit" then want = "reason=nowit"; elseif act == "esc" then want = "reason=\"dialog closed\""; end;
		HOST_Check(TRF.live.hl == nil and S_Logs(n0, "event=close trader_id="..id7.." "..want) == 1 and S_Logs(n0, "event=close trader_id="..id7) == 1
			and ((act == "nowit" and type(r7.dw) == "table") or (act ~= "nowit" and r7.dw == nil)), act..": one close ("..want.."), mark "..TRF_Dump(r7.dw));
	end;
	h.cfg.tune = nil; h.cfg.hail_xml = nil;
	TRF_UiState = us; h.ui = nil;
	V_ClearTr();
end;

-- c: retracted -----------------------------------------------------------------------------------------

function T_DM_C()
	local h = HOST();
	DM_Begin();
	local cur = TRF_CurIdx();
	local id, r, x = DM_Trader(nil, 2);
	local pw = DM_Mark(id);
	HOST_Check(type(pw) == "table" and pw.w == 0 and TRF.std.heat == 4, "marked after the comply (heat 2 + 2)");
	local pro0, dis0 = TRF_Pro(cur), TRF_Dis(cur);
	local s0, m0 = getn(h.screen), getn(h.msgs);
	local n0 = S_Mark();
	T_Tick(20, 0.5);
	DM_Kill(id, 1);
	T_Tick(2, 0.5);
	HOST_Check(S_Logs(n0, "module=events event=kill trader_id="..id.." system_index="..cur.." by=player") == 1, "killed with player fire");
	HOST_Check(S_Logs(n0, "module=supply event=demand_kill trader_id="..id) >= 1 and S_Logs(n0, "witness_count=0 reason=none witnessed=false") >= 1
		and S_Logs(n0, "witnessed=true") == 0, "every kill unseen");
	HOST_Check(TRF.std.heat == 2 and S_Logs(n0, "module=supply event=demand_retract trader_id="..id.." by=player age=") == 1
		and S_Logs(n0, " heat=2") >= 1 and S_Logs(n0, "event=heat reason=\"kill "..id.."\"") == 0,
		"retracted: heat -2 and no kill heat (heat "..TRF.std.heat..")");
	HOST_Check(TRF_Pro(cur) == pro0 - 3 and TRF_Dis(cur) == dis0 + 2, "pro -3 and dis +2 as a kill (pro "..pro0.."->"..TRF_Pro(cur)..", dis "..dis0.."->"..TRF_Dis(cur)..")");
	HOST_Check(DM_Said(s0, m0, TRF_SpTxt("dmplost", TRF_SpName({nm=r.nm}))) and not DM_Said(s0, m0, "robbed"), "the lost line, not robbed");
	HOST_Check(TRF.live.tr[id].dw == nil and TRF.live.stat.dm_retract == 1, "mark gone with the record, stat dm_retract");
	HOST_Check(TRF_Carcasses == nil and S_Logs(n0, "event=demand_retract trader_id="..id) == 1 and S_Logs(n0, " heat=2 via=count") == 1
		and S_Logs(n0, "event=demand_kill trader_id="..id) == S_Logs(n0, "witnessed=false via=count") and S_Logs(n0, "via=typed") == 0,
		"no TRF_Carcasses: the count path (via=count)");
	-- Without the mark the same kill gives the kill heat.
	local id2 = DM_Trader(nil, 2);
	n0 = S_Mark();
	DM_Kill(id2, 1);
	T_Tick(2, 0.5);
	HOST_Check(TRF.std.heat == 3 and S_Logs(n0, "event=demand_") == 0, "unmarked kill: kill heat +1, no demand line");
	V_ClearTr();
end;

-- d: witnessed (witness_slack 0: one ship is a witness; f covers the slack) ---------------------------

function T_DM_D()
	local h = HOST();
	DM_Begin();
	h.cfg.tune = {witness_slack=0};
	local cur = TRF_CurIdx();
	-- A ship in range of the kill (not of the flight): witnessed, the demand and kill heat stay.
	local id, r, x = DM_Trader(nil, 2);
	DM_Mark(id);
	local p = x.tp[1].pos;
	h.cc_ships = {Vector3(p.x + 300, p.y, p.z)};
	local s0, m0 = getn(h.screen), getn(h.msgs);
	local n0 = S_Mark();
	DM_Kill(id, 1);
	T_Tick(2, 0.5);
	h.cc_ships = {};
	HOST_Check(S_Logs(n0, "event=demand_kill trader_id="..id.." ship=1 witness_count=1 reason=ship witnessed=true") == 1
		and S_Logs(n0, "module=supply event=demand_witnessed trader_id="..id.." reason=witness ship_count=0 age=") == 1
		and S_Logs(n0, "result=witnessed") == 1 and TRF.std.heat == 5 and S_Logs(n0, "event=demand_retract") == 0,
		"a ship 300 from the kill: witnessed, heat 4 + kill 1 = "..TRF.std.heat);
	HOST_Check(DM_Said(s0, m0, TRF_SpTxt("dmpseen", TRF_SpName({nm=r.nm}))), "the witness line");
	-- Out of range (witness_r 1500): unseen.
	local id2, r2, x2 = DM_Trader(nil, 2);
	DM_Mark(id2);
	p = x2.tp[1].pos;
	h.cc_ships = {Vector3(p.x + 1600, p.y, p.z)};
	n0 = S_Mark();
	DM_Kill(id2, 1);
	T_Tick(2, 0.5);
	h.cc_ships = {};
	HOST_Check(S_Logs(n0, "event=demand_retract trader_id="..id2) == 1, "a ship 1600 away: not a witness");
	-- A station within witness_r: witnessed.
	local st = TRF_Map().sys[cur].st[1];
	local id3 = DM_Trader({x=st.x + 600, y=st.y, z=st.z}, 2);
	DM_Mark(id3);
	n0 = S_Mark();
	DM_Kill(id3, 1);
	T_Tick(2, 0.5);
	HOST_Check(S_Logs(n0, "event=demand_kill trader_id="..id3.." ship=1 witness_count=1 reason=station witnessed=true") == 1
		and S_Logs(n0, "event=demand_witnessed trader_id="..id3.." reason=witness") == 1, "a station 600 away: witnessed");
	-- An escort left alive after the transports: witnessed (reason survivor). The flight gets an escort if it has none.
	local id4, r4, x4 = DM_Trader(nil, 2);
	if DM_Escorts(x4) == 0 then
		local e = HOST_Obj("esc", x4.tp[1].pos.x + 20, 0, x4.tp[1].pos.z);
		e.kind = "ship";
		tinsert(x4.sh, e);
	end;
	DM_Mark(id4);
	n0 = S_Mark();
	DM_Kill(id4, nil);
	T_Tick(2, 0.5);
	HOST_Check(S_Logs(n0, "event=demand_witnessed trader_id="..id4.." reason=survivor ship_count=") == 1 and S_Logs(n0, "event=demand_retract") == 0,
		"an escort alive at the last transport's death: witnessed (survivor)");
	-- The escorts left alive would be witnesses of the next runs at the same point.
	for k = 1, getn(x4.sh) do x4.sh[k].alive = nil; end;
	-- No count native: a retraction needs a count.
	local gc = GetCarcassCountInSphere;
	local id5 = DM_Trader(nil, 2);
	DM_Mark(id5);
	GetCarcassCountInSphere = nil;
	n0 = S_Mark();
	DM_Kill(id5, 1);
	T_Tick(2, 0.5);
	GetCarcassCountInSphere = gc;
	HOST_Check(S_Logs(n0, "event=demand_kill trader_id="..id5.." ship=1 witness_count=1 reason=no_count witnessed=true") == 1
		and S_Logs(n0, "event=demand_witnessed trader_id="..id5) == 1, "no GetCarcassCountInSphere: witnessed");
	-- witness_dead 1 takes one carcass off each count: the ship 300 away is masked.
	h.cfg.tune = {witness_dead=1, witness_slack=0};
	local id6, r6, x6 = DM_Trader(nil, 2);
	DM_Mark(id6);
	p = x6.tp[1].pos;
	h.cc_ships = {Vector3(p.x + 300, p.y, p.z)};
	n0 = S_Mark();
	DM_Kill(id6, 1);
	T_Tick(2, 0.5);
	h.cc_ships = {};
	h.cfg.tune = {witness_slack=0};
	HOST_Check(S_Logs(n0, "event=demand_retract trader_id="..id6) == 1, "witness_dead 1: one carcass less per count");
	-- A mod ship (here a raid ship) within witness_r at the mark and still there at the kill: not in the
	-- background, so a witness.
	local id7, r7, x7 = DM_Trader(nil, 2);
	p = x7.tp[1].pos;
	local rs = HOST_Obj("dm_raid", p.x + 400, p.y, p.z);
	rs.kind = "ship";
	TRF_H().rd[999] = {sh={rs}, dk={}};
	h.cc_ships = {Vector3(p.x + 400, p.y, p.z)};
	local pw7 = DM_Mark(id7);
	n0 = S_Mark();
	DM_Kill(id7, 1);
	T_Tick(2, 0.5);
	h.cc_ships = {};
	TRF_H().rd[999] = nil;
	HOST_Check(type(pw7) == "table" and pw7.b == 0 and S_Logs(n0, "event=demand_kill trader_id="..id7.." ship=1 witness_count=1 reason=ship witnessed=true") == 1
		and S_Logs(n0, "event=demand_witnessed trader_id="..id7.." reason=witness") == 1, "a raid ship there at the mark and at the kill: witnessed ("..TRF_Dump(pw7)..")");
	-- A witnessed kill without player fire: logged, no witness line (the Wolves did not destroy it).
	local id8, r8, x8 = DM_Trader(nil, 2);
	DM_Mark(id8);
	p = x8.tp[1].pos;
	h.cc_ships = {Vector3(p.x + 300, p.y, p.z)};
	s0, m0 = getn(h.screen), getn(h.msgs);
	n0 = S_Mark();
	DM_Kill(id8, 1, 1);
	T_Tick(2, 0.5);
	h.cc_ships = {};
	HOST_Check(S_Logs(n0, "event=kill trader_id="..id8.." system_index="..cur.." by=other") == 1 and S_Logs(n0, "event=demand_witnessed trader_id="..id8) == 1
		and not DM_Said(s0, m0, TRF_SpTxt("dmpseen", TRF_SpName({nm=r8.nm}))), "witnessed kill by others: no witness line");
	h.cfg.tune = nil;
	V_ClearTr();
end;

-- f: subtractions of the witness count (spec 5.3) -------------------------------------------------------

-- A flight of the player's crew pilot nm (GetPilot) holding the pilots of ships ls.
function DM_CrewWing(nm, ls)
	local fl = {ps={}};
	for i = 1, getn(ls) do tinsert(fl.ps, ls[i]:GetPilot()); end;
	fl.GetPilotCount = function(self) return getn(self.ps); end;
	fl.GetPilotByNumber = function(self, i) return self.ps[i]; end;
	local q = {kind="pilot"};
	q.GetSide = function(self) return "Player"; end;
	q.GetFlight = function(self) return %fl; end;
	q.GetShip = function(self) return nil; end;
	HOST().crew[nm] = q;
	return fl;
end;

function T_DM_F()
	local h = HOST();
	DM_Begin();
	-- Two player fighters launched after the mark, 200 from the kill, no other ship: no witness. One flies in the
	-- mothership's flight, the other in the flight of the crew pilot Hero.
	local id, r, x = DM_Trader(nil, 2);
	local pw = DM_Mark(id);
	local p = x.tp[1].pos;
	local f1 = HOST_PlayerShip(p.x + 200, p.y, p.z);
	local f2 = HOST_PlayerShip(p.x - 200, p.y, p.z);
	h.pwing = {f1:GetPilot()};
	DM_CrewWing("Hero", {f2});
	h.cc_ships = {Vector3(p.x + 200, p.y, p.z), Vector3(p.x - 200, p.y, p.z)};
	HOST_Check(TRF_SpPlayerNear(p, 1500) == 2 and TRF_SpPlayerNear(p, 100) == 0, "two player fighters found within witness_r, none within 100");
	local n0 = S_Mark();
	DM_Kill(id, 1);
	T_Tick(2, 0.5);
	HOST_Check(type(pw) == "table" and S_Logs(n0, "event=demand_kill trader_id="..id.." ship=1 witness_count=0 reason=none witnessed=false") == 1
		and S_Logs(n0, "event=demand_retract trader_id="..id) == 1 and S_Logs(n0, "module=supply event=error") == 0,
		"two player fighters near the kill, no other ship: not seen, retracted");
	-- One vanilla ship more (a rocket in flight to the native): within witness_slack 1, not seen. The fighters are
	-- near at the mark too: taken off the background as well, so they are not subtracted twice.
	local id2, r2, x2 = DM_Trader(nil, 2);
	local pw2 = DM_Mark(id2);
	p = x2.tp[1].pos;
	HOST_Check(type(pw2) == "table" and pw2.b == 0, "fighters at the mark: background 0 ("..TRF_Dump(pw2)..")");
	f1.pos = Vector3(p.x + 200, p.y, p.z); f2.pos = Vector3(p.x - 200, p.y, p.z);
	h.cc_ships = {Vector3(p.x + 200, p.y, p.z), Vector3(p.x - 200, p.y, p.z), Vector3(p.x + 300, p.y, p.z)};
	n0 = S_Mark();
	DM_Kill(id2, 1);
	T_Tick(2, 0.5);
	HOST_Check(S_Logs(n0, "event=demand_kill trader_id="..id2.." ship=1 witness_count=0 reason=none") == 1
		and S_Logs(n0, "event=demand_retract trader_id="..id2) == 1, "fighters and one ship more: within witness_slack 1, retracted");
	-- Two vanilla ships next to the fighters: the excess 2 is more than the slack, seen.
	h.cc_ships = {};
	local id3, r3, x3 = DM_Trader(nil, 2);
	DM_Mark(id3);
	p = x3.tp[1].pos;
	f1.pos = Vector3(p.x + 200, p.y, p.z); f2.pos = Vector3(p.x - 200, p.y, p.z);
	h.cc_ships = {Vector3(p.x + 200, p.y, p.z), Vector3(p.x - 200, p.y, p.z), Vector3(p.x + 300, p.y, p.z), Vector3(p.x - 300, p.y, p.z)};
	n0 = S_Mark();
	DM_Kill(id3, 1);
	T_Tick(2, 0.5);
	HOST_Check(S_Logs(n0, "event=demand_kill trader_id="..id3.." ship=1 witness_count=2 reason=ship witnessed=true") == 1
		and S_Logs(n0, "event=demand_witnessed trader_id="..id3.." reason=witness") == 1, "fighters and two ships more: beyond witness_slack, witnessed");
	h.cc_ships = {}; h.pwing = {}; h.crew = {};
	-- The wreck of the flight's first transport is in the count at the second death (witness_slack 0, so one
	-- carcass would be a witness): not seen. A second transport is added when the flight has one.
	h.cfg.tune = {witness_slack=0};
	local id4, r4, x4 = DM_Trader(nil, 2);
	if getn(x4.tp) < 2 then
		local e = HOST_Obj("tp2", x4.tp[1].pos.x + 30, 0, x4.tp[1].pos.z);
		e.kind = "ship";
		tinsert(x4.tp, e);
		tinsert(x4.sh, e);
	end;
	local pw4 = DM_Mark(id4);
	p = x4.tp[1].pos;
	n0 = S_Mark();
	x4.tp[1].alive = nil;
	TRF_OnShipDied(id4, 1, TRF.gen);
	HOST_Check(type(pw4) == "table" and r4.dw == pw4 and pw4.d == 1 and pw4.w == 0
		and S_Logs(n0, "event=demand_kill trader_id="..id4.." ship=1 witness_count=0 reason=none") == 1, "first transport unseen, dw.d = 1 ("..TRF_Dump(pw4)..")");
	h.cc_ships = {Vector3(p.x, p.y, p.z)};
	for k = 1, getn(x4.sh) do x4.sh[k].alive = nil; end;
	for k = 2, getn(x4.tp) do TRF_OnShipDied(id4, k, TRF.gen); end;
	T_Tick(2, 0.5);
	h.cc_ships = {};
	h.cfg.tune = nil;
	HOST_Check(S_Logs(n0, "event=demand_kill trader_id="..id4.." ship=2 witness_count=0 reason=none witnessed=false") == 1
		and S_Logs(n0, "event=demand_retract trader_id="..id4) == 1, "the first transport's wreck at the second death: not seen, retracted");
	V_ClearTr();
end;

-- e: time-out, refused marks, dump, save ---------------------------------------------------------

function T_DM_E()
	local h = HOST();
	DM_Begin();
	-- Step time-out: the flight alive after witness_t, the mark cleared, the kill later gives the kill heat.
	h.cfg.tune = {witness_t=30};
	local id, r = DM_Trader(nil, 2);
	DM_Mark(id);
	local n0 = S_Mark();
	T_Tick(80, 0.5);
	HOST_Check(r.dw == nil and S_Logs(n0, "module=supply event=demand_witness_timeout trader_id="..id.." age=") == 1
		and S_Logs(n0, "witnessed=false reason=time") == 1, "witness_t 30: cleared by the step ("..tostring(r.st)..")");
	if r.st ~= "gone" then
		n0 = S_Mark();
		local h0 = TRF.std.heat;
		DM_Kill(id, 1);
		T_Tick(2, 0.5);
		HOST_Check(TRF.std.heat == h0 + 1 and S_Logs(n0, "event=demand_") == 0, "kill after the time-out: kill heat, no demand line");
	end;
	-- Late kill before the step ran: the kill reports the time-out.
	local id2, r2 = DM_Trader(nil, 2);
	DM_Mark(id2);
	r2.dw.t = TRF_SpGt() - 31;
	n0 = S_Mark();
	DM_Kill(id2, 1);
	HOST_Check(S_Logs(n0, "event=demand_witness_timeout trader_id="..id2.." age=31.000 reason=late_kill") == 1 and S_Logs(n0, "event=demand_retract") == 0,
		"late kill: time-out, no retraction");
	T_Tick(2, 0.5);
	h.cfg.tune = nil;
	-- Refused marks: no demand, twice, no record.
	local id3, r3 = DM_Trader(nil, 0);
	n0 = S_Mark();
	HOST_Check(TRF_DemandNoWit(id3) == nil and S_Logs(n0, "event=demand_prey trader_id="..id3.." reason=not_demanded result=refused") == 1, "no demand: refused");
	DM_Mark(id3);
	HOST_Check(TRF_DemandNoWit(id3) == nil and S_Logs(n0, "reason=marked result=refused") == 1 and TRF_DemandNoWit(9999) == nil, "marked twice or no record: refused");
	-- Dump and save size: pw on every live record of the trader cap stays small.
	n0 = S_Mark();
	TRF_Supply_Dump();
	HOST_Check(S_Logs(n0, "demand_page_option=1 prey_count=1") == 1, "dump: demand_page_option, prey_count");
	-- Worst cases: the count path {t, w, b, d, v}; the typed path {t, w, v, wc, wt} with a 63 character template.
	local pw = {t=99999999.5, w=1, b=999, d=8, v="count"};
	local tw = {t=99999999.5, w=1, v="typed", wc=9, wt=strrep("x", 63)};
	local one = max(HOST_SaveSize(pw), HOST_SaveSize(tw)) + 8 + strlen("dw");
	local sz = 8 * one;
	print("HOST demand dw worst case bytes "..sz.." ("..one.." per record; count "..HOST_SaveSize(pw)..", typed "..HOST_SaveSize(tw)..")");
	HOST_Check(one == 189 and sz <= 1512, "dw: 189 bytes per record, "..sz.." bytes on 8 live records <= 1512 (spec 3)");
	HOST_Check(HOST_Reserved(TRF, "TRF") == "", "no reserved key in TRF");
	V_ClearTr();
end;

-- g: cfg demand_drop ------------------------------------------------------------------------------------

-- Live drop container of label lb, or nil.
function DM_Drop(lb)
	local o = HOST().objs[lb];
	if type(o) == "table" and o.alive then return o; end;
	return nil;
end;

-- Stacks of an object inventory as "<id>:<n>,..." in insertion order.
function DM_Inv(o)
	local s = "";
	for i = 1, getn(o.inv) do
		if i > 1 then s = s..","; end;
		s = s..o.inv[i][1]..":"..o.inv[i][2];
	end;
	return s;
end;

function T_DM_G()
	local h = HOST();
	DM_Begin();
	HOST_Check(TRF_SpOpt("demand_drop", 0) == 0 and TRF_Supply_OptDef().demand_drop == 0, "cfg demand_drop default 0");
	-- demand_drop 0: the stacks on the mothership, drop=false.
	local id0 = DM_Trader(nil, 0);
	local n0 = S_Mark();
	DM_Demand(id0, 1);
	HOST_Check(DM_Got() == 3 and DM_Drop("trf_drop_1_1") == nil
		and S_Logs(n0, "event=demand_comply trader_id="..id0.." container_count=3 moved_count=3 heat=2 items=Cargo_01:2,Cargo_04:1 drop=false container_name=nil") == 1,
		"demand_drop 0: the mothership, drop=false container_name=nil");
	DM_End();
	-- demand_drop 1: one container 40-80 from the leader with the stacks; the mothership untouched.
	h.cfg.demand_drop = 1;
	local id, r = DM_Trader(nil, 0);
	local lp = TRF_SpPos(TRF_SpLead(id));
	n0 = S_Mark();
	local s1 = getn(h.screen);
	DM_Demand(id, 1);
	local o = DM_Drop("trf_drop_1_1");
	local d = o and TRF_SpDist(o.pos, lp);
	HOST_Check(o and o.tpl == "cargo01_destroyed_inv" and o.cleared == 1 and DM_Inv(o) == "Cargo_01:2,Cargo_04:1",
		"container cargo01_destroyed_inv, ClearInventory, then the stacks: "..TRF_Dump(o and o.inv));
	HOST_Check(d and d >= 39.99 and d <= 80.01, "container 40-80 from the leader: "..tostring(d));
	HOST_Check(DM_Got() == 0 and getn(h.ms.inv) == 0, "mothership inventory untouched");
	HOST_Check(S_Logs(n0, "event=demand_comply trader_id="..id.." container_count=3 moved_count=3 heat=2 items=Cargo_01:2,Cargo_04:1 drop=true container_name=trf_drop_1_1") == 1
		and S_Logs(n0, "reason=drop_failed") == 0, "log drop=true container_name=trf_drop_1_1");
	local bx = HOST_Box();
	HOST_Check(bx and strfind(bx.text, "2 x Cargo_01, 1 x Cargo_04", 1, 1) and TRF_H().dp.n == 1 and TRF_H().dp.o[1] == o,
		"page lists the dropped stacks, handle in TRF_H().dp");
	DM_End();
	HOST_Check(getn(r.hold) == 1 and r.hold[1].i == "Cargo_04" and r.hold[1].n == 1, "the hold lost the robbed stacks");
	-- Witnesses: a live container is no witness (TRF_SpDropNear). The background at the leader is the same with the
	-- container alive or gone; a container made after the mark does not add one at a kill (slack 1, one extra carcass).
	local hh = TRF_SpHTr(id);
	local lq = {x=lp.x, y=lp.y, z=lp.z};
	local bq = TRF_SpBack(lq, hh, id);
	o.alive = nil;
	local bq0 = TRF_SpBack(lq, hh, id);
	o.alive = 1;
	h.extra_carcass = 1;
	local wq, wy = TRF_SpWitness(lq, hh, bq0, 0);
	h.extra_carcass = nil;
	HOST_Check(TRF_SpDropNear(lq, 1500) == 1 and TRF_SpDropNear({x=lp.x + 5000, y=lp.y, z=lp.z}, 1500) == 0
		and bq and bq == bq0 and wq == 0 and wy == "none",
		"drop container never a witness: background "..tostring(bq).."/"..tostring(bq0)..", kill "..tostring(wq).." "..tostring(wy));
	-- Second drop: next slot.
	local id2 = DM_Trader(nil, 0);
	n0 = S_Mark();
	DM_Demand(id2, 1, 0);
	local o2 = DM_Drop("trf_drop_1_2");
	HOST_Check(o2 and DM_Inv(o2) == "Cargo_01:1" and DM_Drop("trf_drop_1_1") == o and S_Logs(n0, "drop=true container_name=trf_drop_1_2") == 1,
		"second drop: slot 2, the first container stays");
	DM_End();
	-- Creation fails (every spot blocked): fallback to the mothership, reason=drop_failed.
	local id3 = DM_Trader(nil, 0);
	h.block_r = 100000;
	n0 = S_Mark();
	DM_Demand(id3, 1);
	h.block_r = 3;
	HOST_Check(DM_Got() == 3 and DM_Drop("trf_drop_1_3") == nil and TRF_H().dp.n == 2
		and S_Logs(n0, "items=Cargo_01:2,Cargo_04:1 drop=false container_name=nil reason=drop_failed drop_cause=create_failed") == 1,
		"creation failed: the mothership, reason=drop_failed drop_cause=create_failed");
	DM_End();
	-- Inventory fails: the container is deleted, the mothership gets the stacks.
	local inv = TRF_Sc_Inv;
	TRF_Sc_Inv = function(o, l) return nil; end;
	local id4 = DM_Trader(nil, 0);
	n0 = S_Mark();
	DM_Demand(id4, 1);
	TRF_Sc_Inv = inv;
	local o4 = h.objs["trf_drop_1_3"];
	HOST_Check(DM_Got() == 3 and o4 and not o4.alive and S_Logs(n0, "reason=drop_failed drop_cause=inventory_failed") == 1,
		"inventory failed: container deleted, the mothership");
	DM_End();
	-- trf_scar helpers missing: fallback.
	local mk = TRF_Sc_Make;
	TRF_Sc_Make = nil;
	local id5 = DM_Trader(nil, 0);
	n0 = S_Mark();
	DM_Demand(id5, 1);
	TRF_Sc_Make = mk;
	HOST_Check(DM_Got() == 3 and S_Logs(n0, "drop_cause=no_helper") == 1, "no trf_scar helper: the mothership");
	DM_End();
	-- Slot wrap after 24 drops: slot 1 again, its old container deleted first.
	TRF_H().dp.n = 24;
	local id6 = DM_Trader(nil, 0);
	n0 = S_Mark();
	DM_Demand(id6, 1);
	local o6 = DM_Drop("trf_drop_1_1");
	HOST_Check(o6 and o6 ~= o and not o.alive and TRF_H().dp.n == 1 and S_Logs(n0, "container_name=trf_drop_1_1") == 1,
		"slot wrap: trf_drop_1_1 reused, the old container deleted");
	DM_End();
	HOST_Check(TRF_SpDropLbl(6) == "trf_drop_1_6" and TRF_SpDropLbl(7) == "trf_drop_2_1" and TRF_SpDropLbl(24) == "trf_drop_4_6",
		"labels trf_drop_<1..4>_<1..6>");
	-- Load: trf_plumb's orphan scan deletes a container restored with the save (group Drop), a destroyed one too
	-- (o2 answers dead; the host label table also still answers the deleted inventory_failed container of slot 3).
	o2.alive = nil;
	o2.Delete = function(self) self.alive = nil; self.del = 1; end;
	n0 = S_Mark();
	local pn, pg = TRF_PlOrphans();
	HOST_Check(pn == 3 and o2.del == 1 and not o6.alive and S_Logs(n0, "module=plumb event=orphan deleted_count=3") == 1,
		"orphan scan at load: live and destroyed containers deleted ("..tostring(pn)..")");
	TRF_Supply_OnLoad();
	HOST_Check(TRF_H().dp == nil, "load: drop handles cleared");
	-- Before a jump: every live container of the visit deleted.
	local id7 = DM_Trader(nil, 0);
	DM_Demand(id7, 1);
	local o7 = DM_Drop("trf_drop_1_1");
	DM_End();
	n0 = S_Mark();
	TRF_Supply_BeforeJump();
	HOST_Check(o7 and not o7.alive and TRF_H().dp == nil and S_Logs(n0, "module=supply event=demand_drop_clear deleted_count=1 reason=jump") == 1,
		"jump: container deleted, demand_drop_clear");
	n0 = S_Mark();
	TRF_Supply_Dump();
	HOST_Check(S_Logs(n0, "demand_drop_option=1") == 1, "dump: demand_drop_option");
	h.cfg.demand_drop = nil;
	HOST_Check(HOST_Reserved(TRF, "TRF") == "", "no reserved key in TRF");
	V_ClearTr();
end;

-- h: the typed witness rule (spec 5.8) -------------------------------------------------------------

-- uids on the flight's handles (the id field TRF_Carcasses records carry), from base; the list of uids.
function DM_Uids(x, base)
	local ids = {};
	for i = 1, getn(x.sh) do x.sh[i].id = base + i; tinsert(ids, base + i); end;
	for i = 1, getn(x.tp) do if type(x.tp[i].id) ~= "number" then x.tp[i].id = base + 50 + i; tinsert(ids, base + 50 + i); end; end;
	return ids;
end;

-- Records of the flight's ships as TRF_Carcasses would list them at the kill (still alive in the list: the
-- worst case of a stale entry), each with uid ids[i].
function DM_OwnRecs(x, ids)
	local out = {};
	for i = 1, getn(ids) do
		local p = x.tp[1].pos;
		tinsert(out, {id=ids[i], cls=3, tpl="trader_ship", team="TRF_Trade", hp=500, hpmax=800, x=p.x + 10 * i, y=p.y, z=p.z, pl=0});
	end;
	return out;
end;

-- A trader of heat 2 with uids, marked; HOST().carc = the flight's own records plus recs (records placed relative
-- to the first transport: field dx). Kill every ship with player fire. Returns id, record, mark, log mark.
function DM_TypedKill(recs, base)
	local h = HOST();
	local id, r, x = DM_Trader(nil, 2);
	local ids = DM_Uids(x, base);
	h.carc = DM_OwnRecs(x, ids);
	local pw = DM_Mark(id);
	local p = x.tp[1].pos;
	for i = 1, getn(recs) do
		local c = recs[i];
		c.x, c.y, c.z = p.x + c.dx, p.y, p.z;
		tinsert(h.carc, c);
	end;
	local n0 = S_Mark();
	DM_Kill(id, 1);
	T_Tick(2, 0.5);
	return id, r, pw, n0;
end;

function T_DM_H()
	local h = HOST();
	DM_Begin();
	TRF_Carcasses = HOST_Carcasses;
	-- Rocket (cls 12) and wreck (cls 10) beside the kill: no witness; the mark has no background, the kill no wreck
	-- counter, the retraction logs via=typed.
	h.carc_n = 0;
	local nm = S_Mark();
	local id, r, pw, n0 = DM_TypedKill({{id=901, cls=12, tpl="rocket_x", hp=10, hpmax=10, pl=0, dx=50},
		{id=902, cls=10, tpl="wreck_hull", hp=50, hpmax=100, pl=0, dx=120}}, 7000);
	HOST_Check(type(pw) == "table" and pw.b == nil and pw.v == "typed" and h.carc_n >= 2, "mark on the typed path: no background, dw.v typed ("..TRF_Dump(pw)..")");
	HOST_Check(S_Logs(n0, "event=demand_kill trader_id="..id.." ship=1 witness_count=0 reason=none witnessed=false via=typed") >= 1
		and S_Logs(n0, "witnessed=true") == 0 and pw.d == nil, "rocket and wreck at the kill: not seen, no dw.d");
	HOST_Check(S_Logs(n0, "event=demand_retract trader_id="..id.." by=player age=") == 1 and S_Logs(n0, "heat=2 via=typed") == 1
		and TRF.std.heat == 2, "retracted, via=typed (heat "..TRF.std.heat..")");
	HOST_Check(S_Logs(nm, "module=supply event=witness_probe trader_id="..id.." radius=3000 typed_count=") == 1
		and S_Logs(nm, "leader_cls=3 leader_team=TRF_Trade leader_hp=500 leader_cur_hp=") == 1, "level 2 witness_probe at the typed mark (CHECK W5)");
	-- A station (cls 8) 600 from the kill: seen, witness_cls=8 and its template on the kill and the outcome.
	local id2, r2, pw2;
	id2, r2, pw2, n0 = DM_TypedKill({{id=903, cls=8, tpl="station_ftu", team="FTU", hp=9000, hpmax=9000, pl=0, dx=600}}, 7100);
	HOST_Check(S_Logs(n0, "event=demand_kill trader_id="..id2.." ship=1 witness_count=1 reason=station witnessed=true via=typed witness_cls=8 witness_tpl=station_ftu") == 1
		and S_Logs(n0, "event=demand_witnessed trader_id="..id2.." reason=witness ship_count=0 age=") == 1
		and S_Logs(n0, "result=witnessed via=typed witness_cls=8 witness_tpl=station_ftu") == 1
		and S_Logs(n0, "event=demand_retract") == 0 and TRF.std.heat == 5, "a station 600 away: seen, witness_cls=8 (heat "..TRF.std.heat..")");
	-- A vanilla ship (cls 3) 300 away is a witness (no witness_slack on this path, default slack 1).
	local id3;
	id3, r2, pw2, n0 = DM_TypedKill({{id=904, cls=3, tpl="pirate_ship", team="Pirates", hp=300, hpmax=300, pl=0, dx=300}}, 7200);
	HOST_Check(TRF_SpT("witness_slack", 1) == 1 and S_Logs(n0, "event=demand_witnessed trader_id="..id3) == 1
		and S_Logs(n0, "witness_cls=3 witness_tpl=pirate_ship") == 2, "one vanilla ship: seen at slack 1");
	-- The player's fighter (pl=1) 200 away: not seen, no player-fighter search needed.
	local id4;
	id4, r2, pw2, n0 = DM_TypedKill({{id=905, cls=6, tpl="Interceptor_X", team="PlayerTeam", hp=400, hpmax=600, pl=1, dx=200}}, 7300);
	HOST_Check(S_Logs(n0, "event=demand_retract trader_id="..id4) == 1 and S_Logs(n0, "witnessed=true") == 0, "player fighter (pl=1): not seen");
	-- The flight's own ships still listed alive (their uids): not seen; the same records under other uids: seen.
	local id5;
	id5, r2, pw2, n0 = DM_TypedKill({}, 7400);
	HOST_Check(S_Logs(n0, "event=demand_retract trader_id="..id5) == 1 and S_Logs(n0, "witnessed=true") == 0, "own ships by uid: not seen");
	local id6, r6, x6 = DM_Trader(nil, 2);
	local ids6 = DM_Uids(x6, 7500);
	DM_Mark(id6);
	h.carc = DM_OwnRecs(x6, {8001});
	n0 = S_Mark();
	DM_Kill(id6, 1);
	T_Tick(2, 0.5);
	HOST_Check(S_Logs(n0, "event=demand_witnessed trader_id="..id6) == 1 and S_Logs(n0, "witness_tpl=trader_ship") >= 1,
		"control: a trader record with another uid is a witness");
	-- A drop container (its template, cls 8 as a <Station>) 60 away: not seen.
	local id7;
	id7, r2, pw2, n0 = DM_TypedKill({{id=906, cls=8, tpl=TRF_SpDropK().tpl, hp=100, hpmax=100, pl=0, dx=60}}, 7600);
	HOST_Check(TRF_SpDropK().tpl == "cargo01_destroyed_inv" and S_Logs(n0, "event=demand_retract trader_id="..id7) == 1
		and S_Logs(n0, "witnessed=true") == 0, "drop container (cargo01_destroyed_inv): not seen");
	-- A live drop container handle's uid is left out as well, whatever its template.
	local dp = TRF_SpDropH();
	local co = HOST_Obj("trf_drop_1_1", 0, 0, 0);
	co.id = 907;
	dp.o[1] = co;
	local f = TRF_SpWitF(nil);
	dp.o[1] = nil;
	HOST_Check(TRF_PlIn(f.not_ids, 907) and f.alive == 1 and f.player == 0 and getn(f.cls) == 7 and f.cls[1] == 3 and f.cls[7] == 9,
		"filter: cls 3..9, alive, not the player's team, the drop handle's uid");
	-- The native answers nil (ini carcasses=0): the count path, via=count, background from the count.
	h.carc_why = "off";
	local id8, r8, x8 = DM_Trader(nil, 2);
	nm = S_Mark();
	local pw8 = DM_Mark(id8);
	n0 = S_Mark();
	DM_Kill(id8, 1);
	T_Tick(2, 0.5);
	h.carc_why = nil;
	HOST_Check(type(pw8) == "table" and type(pw8.b) == "number" and S_Logs(n0, "event=demand_kill trader_id="..id8) >= 1
		and S_Logs(n0, "reason=none witnessed=false via=count") >= 1 and S_Logs(n0, "heat=2 via=count") == 1
		and S_Logs(n0, "via=typed") == 0 and S_Logs(nm, "event=witness_probe") == 0, "native nil: the count path (via=count, background "..tostring(pw8 and pw8.b)..")");
	TRF_Carcasses = nil;
	h.carc = nil;
	HOST_Check(HOST_Reserved(TRF, "TRF") == "", "no reserved key in TRF");
	V_ClearTr();
end;

-- Dispatch ---------------------------------------------------------------------------------

local sc = getenv("TRF_DM") or "";
local fn = getglobal("T_DM_"..strupper(sc));
print("HOST ==== demand page scenario dm-"..sc.." dir="..HOST().dir);
if type(fn) == "function" then
	fn();
	HOST_Check(T_LeftGlobals() == "", "no handle globals left at the end"..T_LeftGlobals());
	local q = T_BadCallbacks();
	HOST_Check(q == "", "every mod callback string carries the current gen"..q);
else
	HOST_Check(nil, "unknown demand page scenario "..sc);
end;
HOST_Check((HOST().gpm_tick or 0) == 0, "no GetPlayerMotherShip from a tick (n="..tostring(HOST().gpm_tick or 0)..")");
print("HOST errors="..HOST().errors.." fails="..HOST().fails);
if HOST().errors > 0 or HOST().fails > 0 then exit(1); end;
exit(0);
