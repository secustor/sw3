-- Station jobs UI scenarios, step 1 (design/station-jobs-spec.md 9) under stock Lua 4.0.1: TRF_JB=a, b, d, e (c and f
-- are the steps 2 and 3), run by run_host.sh as its own entry point. Loads host_parcel.lua up to its first scenario
-- (helpers PC_*, which load host_station.lua). Stubs in host_stubs.lua: HOST_MissionCard (TRF_MissionCard),
-- HOST_JobPress and HOST_JobTick (the T4 queue that calls TRF_OnJobCard).

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
-- the stub card native when card is 1.
function JB_Begin(ui, card)
	local h = HOST();
	PC_Begin("altair", "9_1", {jobs_ui=ui});
	PC_Short("taira", 1);
	PC_Window(TRF_CurIdx(), 80, nil);
	h.jc = {}; h.jq = {}; h.jc_open = nil; h.jc_off = nil; h.jc_why = nil;
	if card == 1 then TRF_MissionCard = HOST_MissionCard; else TRF_MissionCard = nil; end;
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
