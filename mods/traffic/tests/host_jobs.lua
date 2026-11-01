-- Station jobs UI scenarios, steps 1 and 2 (design/station-jobs-spec.md 9) under stock Lua 4.0.1: TRF_JB=a, b, c, d, e
-- (f is step 3), run by run_host.sh as its own entry point. Loads host_parcel.lua up to its first scenario (helpers PC_*,
-- which load host_station.lua). Stubs in host_stubs.lua: HOST_MissionCard (TRF_MissionCard), HOST_JobPress and HOST_JobTick
-- (the T4 queue that calls TRF_OnJobCard), HOST_JobBoard, HOST_JobBoardMark (TRF_JobBoard, TRF_JobBoardMark) and
-- HOST_JobClick (a click on an Office card).

local f = openfile((getenv("TRF_TESTS") or "./").."host_parcel.lua", "r");
if not f then print("HOST FAIL host_jobs.lua: cannot open host_parcel.lua"); exit(1); end;
local src = read(f, "*a");
closefile(f);
local cut = strfind(src, "\n-- a: registration, toggles", 1, 1);
if not cut then print("HOST FAIL host_jobs.lua: marker '-- a: registration, toggles' missing in host_parcel.lua"); exit(1); end;
dostring(strsub(src, 1, cut), "host_parcel.lua");

-- Helpers ----------------------------------------------------------------------------------

-- Plumb log lines after mark n0 holding pat (plain).
function JB_Logs(n0, pat)
	local n, q = 0, HOST().logs;
	for i = n0 + 1, getn(q) do if strfind(q[i], "module=plumb ", 1, 1) and strfind(q[i], pat, 1, 1) then n = n + 1; end; end;
	return n;
end;

-- Parcel scenario start at Altair with an offer window for the relief offer to Taira; jobs_ui ui (nil: the default),
-- the stub card native when card is 1, the stub board natives when board is 1.
function JB_Begin(ui, card, board)
	local h = HOST();
	PC_Begin("altair", "9_1", {jobs_ui=ui});
	PC_Short("taira", 1);
	PC_Window(TRF_CurIdx(), 80, nil);
	h.jc = {}; h.jq = {}; h.jc_open = nil; h.jc_off = nil; h.jc_why = nil;
	h.jb = nil; h.jbs = {}; h.jbm = {}; h.jb_tab = nil; h.jb_off = nil;
	if card == 1 then TRF_MissionCard = HOST_MissionCard; else TRF_MissionCard = nil; end;
	if board == 1 then TRF_JobBoard = HOST_JobBoard; TRF_JobBoardMark = HOST_JobBoardMark;
	else TRF_JobBoard = nil; TRF_JobBoardMark = nil; end;
end;

-- The last TRF_JobBoardMark call, or {}.
function JB_Mark()
	local h = HOST();
	return h.jbm[getn(h.jbm)] or {};
end;

-- Patrol ("patrol") or pirate ("pir") docking through the wrapper chain, as host_stash.lua's SH_PatDock / SH_PirDock.
function JB_Dock(kind)
	if kind == "pir" then _param = "pirate1"; __PirStationDock_Ok(); else _param = GetCurrentLocation(); __PatrolStationDock_Ok(); end;
end;

-- Trade dock, click on the parcel card, the open event, the answer ev and its delivery.
function JB_Answer(ev)
	PC_Dock();
	HOST_JobClick("pcl");
	HOST_JobTick();
	HOST_JobPress(ev);
	return HOST_JobTick();
end;

-- Screen lines after index s0 joined by "|".
function JB_Scr(s0)
	local h, s = HOST(), "";
	for i = s0 + 1, getn(h.screen) do s = s..h.screen[i].t.."|"; end;
	return s;
end;

-- a: the box path without the native, jobs_ui 0 with it --------------------------------------

function T_JB_A()
	local h = HOST();
	-- jobs_ui 0: the box even with the native.
	JB_Begin(0, 1);
	local n0 = S_Mark();
	local r = PC_Dock();
	HOST_Check(r.nb == 1 and getn(h.jc) == 0 and JB_Logs(n0, "event=jobs_fallback") == 0 and JB_Logs(n0, "result=box") == 1,
		"jobs_ui 0: the parcel box, no card call, no fallback line");
	local s = PC_Press(r, "ok");
	HOST_Check(PC_Has(s, TRF_Txt("pclhand")) and PC_Logs(n0, "event=accept") == 1 and PC_Logs(n0, "via=box") == 1, "jobs_ui 0: OK accepts as before (via=box)");
	-- jobs_ui 1 (the default) without the native: the box, one native_missing line for two dockings.
	JB_Begin(nil, 0);
	n0 = S_Mark();
	r = PC_Dock();
	local t1 = r.box and r.box.text;
	PC_Press(r, "cancel");
	PC_Visit();
	r = PC_Dock();
	HOST_Check(TRF_PlOpt("jobs_ui") == 1 and t1 and r.nb == 1 and r.box.text == t1 and r.box.title == "FTU courier desk"
		and JB_Logs(n0, "event=jobs_fallback jobs_ui=1 reason=native_missing") == 1, "jobs_ui 1 without the native: the box, jobs_fallback reason=native_missing once");
	PC_Press(r, "cancel");
	-- jobs_ui 2 (step 2 not built) without natives: the same.
	JB_Begin(2, 0);
	n0 = S_Mark();
	r = PC_Dock();
	HOST_Check(r.nb == 1 and JB_Logs(n0, "event=jobs_fallback jobs_ui=2 reason=native_missing") == 1, "jobs_ui 2 without natives: the box, native_missing");
	PC_Press(r, "cancel");
	-- Out of range reads the default.
	h.cfg.jobs_ui = 3;
	HOST_Check(TRF_PlOpt("jobs_ui") == 1 and TRF_Pl_OptDef().jobs_ui == 1, "cfg jobs_ui 3 reads the default 1");
	h.cfg.jobs_ui = nil;
end;

-- b: step 1 card, OK, fallbacks -----------------------------------------------------------------

function T_JB_B()
	local h = HOST();
	JB_Begin(1, 1);
	local n0, b0, d0, k0 = S_Mark(), getn(h.boxes), getn(h.dlgs), h.trade_ok;
	local r = PC_Dock();
	local o = TRF_PcSH().offer;
	local c = h.jc[1];
	HOST_Check(r.nb == 0 and getn(h.boxes) == b0 and getn(h.jc) == 1 and getn(h.dlgs) == d0 and h.trade_ok == k0
		and JB_Logs(n0, "event=dock kind=trade line_count=0 box=parcel priority=400 result=card") == 1,
		"trade dock: one TRF_MissionCard call, no ShowMsgBox, the vanilla call waits for the answer");
	HOST_Check(o and c and c.id == "pcl" and c.header == "Sealed parcel to Taira" and c.cost == TRF_PcNum(o.pay) and c.text == TRF_PcBoxText(o)
		and c.title == "FTU courier contract", "card: id pcl, header pcljobh, cost the pay, the box text, title jbcard ("..tostring(c and c.header)..")");
	HOST_Check(TRF.live.box == "dock_trade", "the card holds the box lock dock_trade");
	HOST_Check(HOST_JobTick() == "open" and PC_Logs(n0, "result=shown via=card") == 1 and JB_Logs(n0, "event=jobs_card id=pcl card_event=open result=ok") == 1,
		"open event: the offer line via=card (TRF_Pc_BoxShown)");
	local s0 = getn(h.screen);
	HOST_JobPress("ok");
	HOST_Check(HOST_JobTick() == "ok", "ok event delivered");
	HOST_Check(PC_Logs(n0, "event=accept") == 1 and PC_Logs(n0, "result=ok") >= 1 and TRF_PcJob() ~= nil and PC_Has(JB_Scr(s0), TRF_Txt("pclhand")),
		"ok: TRF_Pc_BoxOk accepts (result=ok), the reply pclhand on screen");
	HOST_Check(getn(h.dlgs) == d0 + 1 and h.trade_ok == k0 + 1 and getn(h.boxes) == b0 and TRF.live.box == nil
		and JB_Logs(n0, "event=box_answer kind=trade box=parcel answer=1 result=done") == 1 and JB_Logs(n0, "event=jobs_card id=pcl card_event=ok result=ok reply=") == 1,
		"then the vanilla dock call once (shop), the lock freed, box_answer and jobs_card lines");
	HOST_Check(HOST_JobTick() == nil, "queue empty");
	-- The native refuses (TRF_UiState movie or dialog): the box for that docking.
	JB_Begin(1, 1);
	h.jc_why = "ui";
	n0, d0 = S_Mark(), getn(h.dlgs);
	r = PC_Dock();
	HOST_Check(r.nb == 1 and getn(h.jc) == 0 and getn(h.dlgs) == d0 and JB_Logs(n0, "event=jobs_fallback id=pcl reason=ui") == 1
		and JB_Logs(n0, "result=box") == 1, "TRF_MissionCard nil, \"ui\": jobs_fallback reason=ui, the box opens");
	s0 = getn(h.screen);
	PC_Press(r, "ok");
	HOST_Check(PC_Logs(n0, "via=box") == 1 and PC_Logs(n0, "event=accept") == 1 and getn(h.dlgs) == d0 + 1, "the fallback box answers as before");
	-- ini jobs_card 0 (probe "off"): the box, one fallback line.
	JB_Begin(1, 1);
	h.jc_off = "off";
	n0 = S_Mark();
	r = PC_Dock();
	HOST_Check(r.nb == 1 and JB_Logs(n0, "event=jobs_fallback jobs_ui=1 reason=off") == 1, "probe nil, \"off\": the box, jobs_fallback reason=off");
	PC_Press(r, "cancel");
	PC_Visit();
	r = PC_Dock();
	HOST_Check(JB_Logs(n0, "event=jobs_fallback") == 1, "the probe answer is kept: no second fallback line in the visit");
	if r.nb > 0 then PC_Press(r, "cancel"); end;
end;

-- c: step 2 Office board -----------------------------------------------------------------------------

function T_JB_C()
	local h = HOST();
	-- The row is set before the vanilla TradeStationDlg; no box, no card at the dock; SetTraderFlag(FALSE) (J7).
	JB_Begin(2, 1, 1);
	local n0, b0, d0 = S_Mark(), getn(h.boxes), getn(h.dlgs);
	h.trflag = TRUE;
	local r = PC_Dock();
	local o = TRF_PcSH().offer;
	local w = h.jb and h.jb[1];
	HOST_Check(r.nb == 0 and getn(h.boxes) == b0 and getn(h.jc) == 0 and getn(h.jbs) == 1 and h.jbs[1].n == 1 and h.jbs[1].d == d0
		and getn(h.dlgs) == d0 + 1 and TRF.live.box == nil, "trade dock: one row before the vanilla TradeStationDlg, no box, no card, no box lock");
	local sh = nil;
	if o then if o.j == 1 then sh = TRF_Txt("pcljob1", o.dl); else sh = TRF_Txt("pcljobs", o.j, o.dl); end; end;
	HOST_Check(o and w and w.id == "pcl" and w.header == "Sealed parcel to Taira" and w.cost == TRF_PcNum(o.pay) and w.text == TRF_PcBoxText(o)
		and w.title == "FTU courier contract" and sh and w.short == sh and h.jb_tab == "Jobs", "row: id pcl, header pcljobh, cost, box text, title, short pcljobs, tab jbtab ("..tostring(w and w.short)..")");
	HOST_Check(h.trflag == FALSE and JB_Logs(n0, "event=jobs_board kind=trade row_count=1 result=set") == 1
		and JB_Logs(n0, "event=jobs_board kind=trade row_count=1 result=armed trader_flag=false") == 1 and PC_Logs(n0, "result=listed via=board") == 1,
		"jobs_board set and armed, SetTraderFlag(FALSE), offer listed via=board");
	-- Click: the card from the row; open runs BoxShown via=board.
	HOST_Check(HOST_JobClick("pcl") == "open" and HOST_JobTick() == "open" and PC_Logs(n0, "result=shown via=board") == 1
		and JB_Logs(n0, "event=jobs_card id=pcl card_event=open result=ok via=board") == 1, "click: card open, offer shown via=board");
	local b1 = getn(h.boxes);
	HOST_JobPress("ok");
	HOST_Check(HOST_JobTick() == "ok" and PC_Logs(n0, "event=accept") == 1 and TRF_PcJob() ~= nil and getn(h.boxes) == b1 + 1
		and h.boxes[b1 + 1].text == TRF_Txt("pclhand") and h.boxes[b1 + 1].title == "FTU courier contract" and getn(h.dlgs) == d0 + 1,
		"ok: accepted, the reply pclhand as a box over the Office window, no second vanilla call");
	local m = JB_Mark();
	HOST_Check(getn(h.jbm) == 1 and m.id == "pcl" and m.header == "Accepted" and m.closed == 1 and h.jb[1].closed == 1
		and JB_Logs(n0, "card_event=ok result=ok reply=") == 1 and JB_Logs(n0, "via=board mark=jbtaken") == 1, "TRF_JobBoardMark(pcl, Accepted, 1)");
	HOST_Press("ok", h.boxes[b1 + 1]);
	HOST_Check(HOST_JobClick("pcl") == "closed" and getn(h.jc) == 1, "a closed row opens no card");
	-- A second answer of an answered row is stale.
	n0 = S_Mark();
	TRF_OnJobCard("pcl", "cancel");
	HOST_Check(JB_Logs(n0, "event=jobs_card id=pcl card_event=cancel result=stale via=board") == 1 and PC_Logs(n0, "result=declined") == 0
		and getn(h.jbm) == 1, "a second answer: stale, nothing runs");
	-- Poor: the deposit above the credits: the reply pclpoor, the job slot stays free, the row closed jbgone.
	JB_Begin(2, 1, 1);
	n0, b0 = S_Mark(), getn(h.boxes);
	h.credits = 0;
	JB_Answer("ok");
	o = h.jb and h.jb[1];
	m = JB_Mark();
	HOST_Check(TRF_PcJob() == nil and PC_Logs(n0, "result=poor") == 1 and getn(h.boxes) == b0 + 1 and strfind(h.boxes[b0 + 1].text, "Come back with the money", 1, 1)
		and m.header == "No longer available" and m.closed == 1 and JB_Logs(n0, "mark=jbgone") == 1, "poor: reply pclpoor, no job, row closed jbgone");
	HOST_Press("ok", h.boxes[b0 + 1]);
	-- Cancel and Esc: declined (pc.v.dec), the row closed jbgone, no reply box; a second dock in the visit lists no row.
	foreachi({"cancel", "esc"}, function(i, ev)
		local h = HOST();
		JB_Begin(2, 1, 1);
		local n0, b0, d0 = S_Mark(), getn(h.boxes), getn(h.dlgs);
		HOST_Check(JB_Answer(ev) == ev, ev.." delivered");
		local m = JB_Mark();
		HOST_Check(PC_Logs(n0, "result=declined") == 1 and TRF_PcSH().v.dec == 1 and TRF_PcJob() == nil and m.header == "No longer available" and m.closed == 1
			and getn(h.boxes) == b0 and getn(h.dlgs) == d0 + 1 and JB_Logs(n0, "card_event="..ev.." result=ok reply=nil via=board mark=jbgone") == 1,
			ev..": declined, row closed jbgone, no reply box, the vanilla call once (at the dock)");
		n0 = S_Mark();
		local r = PC_Dock();
		HOST_Check(r.nb == 0 and getn(h.jc) == 1 and h.jbs[getn(h.jbs)].n == 0 and PC_Logs(n0, "reason=declined") == 1
			and JB_Logs(n0, "event=jobs_board kind=trade row_count=0 result=cleared") == 1, ev..": a second dock lists no row, opens no box");
	end);
	-- An event for an id the board does not hold: stale, the row marked gone.
	JB_Begin(2, 1, 1);
	PC_Dock();
	n0 = S_Mark();
	TRF_OnJobCard("other", "ok");
	HOST_Check(JB_Logs(n0, "event=jobs_card id=other card_event=ok result=stale") == 1 and getn(h.jbm) == 0 and PC_Logs(n0, "event=accept") == 0,
		"unknown id: stale (the native answers none for the mark)");
	-- Clears: a quest TradeStationDlg (not armed), a patrol dock, a pirate dock, a jump, a load; SetTraderFlag only with rows.
	h.trflag = TRUE;
	n0 = S_Mark();
	TradeStationDlg("quest_shop");
	HOST_Check(getn(h.jb) == 0 and h.trflag == TRUE and JB_Logs(n0, "event=jobs_board row_count=0 result=cleared reason=dialog") == 1,
		"quest TradeStationDlg without the arm: board cleared, IsATrader unchanged");
	PC_Dock();
	n0 = S_Mark();
	JB_Dock("patrol");
	HOST_Check(getn(h.jb) == 0 and JB_Logs(n0, "result=cleared reason=dock_patrol") == 1, "patrol dock: board cleared");
	PC_Dock();
	n0 = S_Mark();
	JB_Dock("pir");
	HOST_Check(getn(h.jb) == 0 and h.trflag == TRUE and JB_Logs(n0, "result=cleared reason=dock_pir") == 1, "pirate dock: board cleared, vanilla IsATrader TRUE");
	n0 = S_Mark();
	PC_Dock();
	HOST_Check(getn(h.jb) == 1 and h.trflag == FALSE, "trade dock after the pirate dock in the visit: the row and IsATrader FALSE (J7)");
	n0 = S_Mark();
	TRF_BeforeJump("taira");
	HOST_Check(getn(h.jb) == 0 and JB_Logs(n0, "result=cleared reason=jump") == 1, "jump: board cleared");
	T_Enter("altair");
	JB_Begin(2, 1, 1);
	PC_Dock();
	n0 = S_Mark();
	T_SaveLoad();
	HOST_Check(getn(h.jb) == 0 and JB_Logs(n0, "result=cleared reason=load") == 1, "load: board cleared");
	-- No row (declined visit): no SetTraderFlag.
	JB_Begin(2, 1, 1);
	JB_Answer("cancel");
	h.trflag = TRUE;
	PC_Dock();
	HOST_Check(h.trflag == TRUE and h.jbs[getn(h.jbs)].n == 0, "trade dock without rows: IsATrader unchanged");
	-- Board native off (ini jobs_board 0): one native_missing line, the card of step 1 at the dock.
	JB_Begin(2, 1, 1);
	h.jb_off = "off";
	n0 = S_Mark();
	PC_Dock();
	HOST_Check(getn(h.jc) == 1 and JB_Logs(n0, "event=jobs_board row_count=0 result=native_missing reason=off") == 1
		and JB_Logs(n0, "result=card") == 1, "TRF_JobBoard off: the step 1 card at the dock");
	HOST_JobTick();
	HOST_JobPress("cancel");
	HOST_JobTick();
	-- jobs_ui 1 with the board natives: the card at the dock, the board never called.
	JB_Begin(1, 1, 1);
	PC_Dock();
	HOST_Check(getn(h.jc) == 1 and getn(h.jbs) == 0, "jobs_ui 1: card at the dock, no board call");
	HOST_JobTick();
	HOST_JobPress("cancel");
	HOST_JobTick();
end;

-- d: Cancel and Esc -------------------------------------------------------------------------------

function T_JB_D()
	local h = HOST();
	foreachi({"cancel", "esc"}, function(i, ev)
		local h = HOST();
		JB_Begin(1, 1);
		local n0, d0 = S_Mark(), getn(h.dlgs);
		PC_Dock();
		HOST_JobTick();
		HOST_JobPress(ev);
		HOST_Check(HOST_JobTick() == ev, ev.." event delivered");
		HOST_Check(PC_Logs(n0, "result=declined") == 1 and TRF_PcSH().v.dec == 1 and TRF_PcJob() == nil and getn(h.dlgs) == d0 + 1
			and JB_Logs(n0, "event=box_answer kind=trade box=parcel answer=0 result=done") == 1 and JB_Logs(n0, "card_event="..ev.." result=ok") == 1,
			ev..": declined (TRF_Pc_BoxNo, pc.v.dec), the vanilla dock call once");
		n0 = S_Mark();
		local r = PC_Dock();
		HOST_Check(r.nb == 0 and getn(h.jc) == 1 and PC_Logs(n0, "reason=declined") == 1, ev..": a second dock in the visit offers nothing");
	end);
	-- An event for another id or without a card is stale and runs nothing.
	JB_Begin(1, 1);
	local n0, d0 = S_Mark(), getn(h.dlgs);
	TRF_OnJobCard("pcl", "ok");
	HOST_Check(JB_Logs(n0, "event=jobs_card id=pcl card_event=ok result=stale") == 1 and getn(h.dlgs) == d0, "no card: stale, no vanilla call");
	PC_Dock();
	TRF_OnJobCard("other", "ok");
	HOST_Check(JB_Logs(n0, "event=jobs_card id=other card_event=ok result=stale") == 1 and getn(h.dlgs) == d0 and PC_Logs(n0, "event=accept") == 0,
		"another id: stale");
	TRF_OnJobCard("pcl", "bogus");
	HOST_Check(JB_Logs(n0, "card_event=bogus result=unknown") == 1 and TRF.live.box == "dock_trade", "an unknown event: logged, the card stays open");
	HOST_JobTick();
	HOST_JobPress("ok");
	HOST_JobTick();
	HOST_Check(PC_Logs(n0, "event=accept") == 1 and getn(h.dlgs) == d0 + 1, "the card still answers after the stale events");
end;

-- e: clears at load and jump, busy -----------------------------------------------------------------

function T_JB_E()
	local h = HOST();
	-- Load while the card is open: the window is gone, its late esc finds no box.
	JB_Begin(1, 1);
	local n0, d0 = S_Mark(), getn(h.dlgs);
	PC_Dock();
	HOST_JobTick();
	T_SaveLoad();
	HOST_Check(JB_Logs(n0, "event=jobs_card id=pcl result=dropped") == 1 and TRF_PlBoxThunk == nil, "load: the open card dropped");
	HOST_JobPress("esc");
	HOST_JobTick();
	HOST_Check(JB_Logs(n0, "event=jobs_card id=pcl card_event=esc result=stale") == 1 and getn(h.dlgs) == d0 and PC_Logs(n0, "result=declined") == 0,
		"a late esc after the load: stale, no shop, no decline");
	-- Jump while the card is open (a quest teleport from a due call): dropped, the lock freed.
	JB_Begin(1, 1);
	n0, d0 = S_Mark(), getn(h.dlgs);
	PC_Dock();
	HOST_JobTick();
	TRF_BeforeJump("taira");
	HOST_Check(JB_Logs(n0, "event=jobs_card id=pcl result=dropped") == 1 and TRF.live.box == nil, "jump: the open card dropped, lock freed");
	HOST_JobPress("ok");
	HOST_JobTick();
	HOST_Check(JB_Logs(n0, "card_event=ok result=stale") == 1 and getn(h.dlgs) == d0 and PC_Logs(n0, "event=accept") == 0, "a late ok after the jump: stale");
	T_Enter("altair");
	-- Busy (a card or a queued answer): the box for that docking.
	JB_Begin(1, 1);
	h.jc_open = "x";
	n0 = S_Mark();
	local r = PC_Dock();
	HOST_Check(r.nb == 1 and JB_Logs(n0, "event=jobs_fallback id=pcl reason=busy") == 1, "busy: jobs_fallback reason=busy, the box");
	h.jc_open = nil;
	PC_Press(r, "cancel");
end;

-- Dispatch ---------------------------------------------------------------------------------

local sc = getenv("TRF_JB") or "";
local fn = getglobal("T_JB_"..strupper(sc));
print("HOST ==== station jobs scenario jb-"..sc.." dir="..HOST().dir);
if type(fn) == "function" then
	fn();
	HOST_Check(T_LeftGlobals() == "", "no handle globals left at the end"..T_LeftGlobals());
	local q = T_BadCallbacks();
	HOST_Check(q == "", "every mod callback string carries the current gen"..q);
else
	HOST_Check(nil, "unknown station jobs scenario "..sc);
end;
HOST_Check((HOST().gpm_tick or 0) == 0, "no GetPlayerMotherShip from a tick (n="..tostring(HOST().gpm_tick or 0)..")");
print("HOST errors="..HOST().errors.." fails="..HOST().fails);
if HOST().errors > 0 or HOST().fails > 0 then exit(1); end;
exit(0);
