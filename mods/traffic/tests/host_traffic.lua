-- Traffic scenarios (v0.1 modules) for host_stubs.lua: TRF_SCEN=a..g, run by run_host.sh.
-- a vanilla parity of declines, b caps over many generator calls, c lifetime and watchdog, d attack, heat,
-- response, kills, pirate recovery and the leg clock, e focus and arrival lines, f save/load round trip,
-- g safety predicates. Uses the stubs and engine emulation of host_stubs.lua; state in HOST().

-- Helpers ---------------------------------------------------------------------------

-- Config for the scenario: the repo defaults plus t (TRF_Config returns HOST().cfg). The v0.1 scenarios a..g
-- run with the v0.2 features off (band 0 = v0.1, v02-spec 9.1), so they keep checking the v0.1 behaviour;
-- T_Cfg2 (host_v02.lua) starts from the v0.2 defaults instead.
function T_V01()
	return {prosperity=0, seed=0, parked=0, queue=0, raids=0, staged=0, contracts=0, meet=1, board=0,
		shop_mode=0, short_price=0, news_mode=0};
end;
function T_Cfg(t)
	local c = {exp=0, log=1, traffic=1};
	for k, v in T_V01() do c[k] = v; end;
	if t then for k, v in t do c[k] = v; end; end;
	HOST().cfg = c;
end;

-- location.script + activate.script of the emulated system: portals from map.script (labels "PORTAL L",
-- globals PORTAL_L), a trade station, a trader contact over all portals with three nav points (one 30 above
-- the station), a pirate contact, the _Trader_Init chances, the mothership next to the arrival portal.
-- Labelled ships that survive (load) are put back in the label table.
function T_Scene(sys)
	local h = HOST();
	local m = TRF_Map();
	local s = m.sys[m.by[sys]];
	h.objs = {};
	h.portals = {};
	local arr = nil;
	for i = 1, getn(s.portals) do
		local p = s.portals[i];
		local o = HOST_Obj(gsub(p.name, "_", " "), p.x, p.y, p.z);
		h.objs[o.label] = o;
		setglobal(p.name, o);
		tinsert(h.portals, o);
		if p.to == h.last or not arr then arr = o; end;
	end;
	h.station = HOST_Obj("TRADE STATION", 50, -30, -150);
	h.objs["TRADE STATION"] = h.station;
	for i = 1, getn(h.ships) do
		if h.ships[i].label then h.objs[h.ships[i].label] = h.ships[i]; end;
	end;
	if not h.keep_ms then h.ms.pos = Vector3(arr.pos.x + 50, arr.pos.y, arr.pos.z - 50); end;
	Trade_Group_1 = HOST_Group("Trade_Group_1", "Trade");
	PiratesGroup_1 = HOST_Group("PiratesGroup_1", "Pirates");
	local sp = h.station:GetPosition();
	__sys_LevelRegisteredContacts = {};
	tinsert(__sys_LevelRegisteredContacts, {TRADER_FLIGHT, "Trade_Group_1", h.portals,
		{Vector3(300, 30, 0), Vector3(-300, 30, 100), Vector3(sp.x, sp.y + 30, sp.z)}, h.prob or 100, 8});
	-- The pirate contact gets a portal of its own: host ships do not fly off, and the vanilla builder raises
	-- an error on an occupied spot.
	h.pportal = HOST_Obj("HOST PIRATE PORTAL", 0, 0, 2500);
	tinsert(__sys_LevelRegisteredContacts, {"R_CreatePirateFlight", "PiratesGroup_1", {h.pportal}, {Vector3(0, 0, 0)}, 100, 3});
	_sys_RandomContactsInterval = 120;
	__formation_number = 1;
	__sys_FTrader_1 = 60; __sys_FTrader_2 = 17.5; __sys_FTrader_3 = 15; __sys_SOS_3 = 100;
	__sys_SOS = FALSE; __disableAction = FALSE;
end;

-- Location entry with a new scene (triggers and ships of the old one are gone).
function T_Enter(sys)
	local h = HOST();
	h.last = h.loc; h.loc = sys;
	h.triggers = {}; h.ships = {}; h.screen = {}; h.msgs = {};
	print("HOST ---- enter "..sys.." (cleared "..HOST_ClearWithCarry().." globals)");
	HOST_MapInit();
	T_Scene(sys);
	TRF_OnEnter();
	TRF_OnActivate();
end;

-- Jump through the wrapped native, then entry.
function T_Jump(sys)
	TeleportToLocation(sys);
	T_Enter(sys);
end;

-- Save, quit, load: clear, MapInitialization, clear, restore (mut may change the restored globals),
-- location.script again (scene objects; ships and triggers stay, as the engine restores them), T2d.
function T_SaveLoad(mut)
	local save = HOST_SaveCopy(globals());
	print("HOST ---- save/load");
	HOST_ClearGlobals();
	HOST_MapInit();
	HOST_ClearGlobals();
	for k, v in save do rawset(globals(), k, v); end;
	if mut then mut(); end;
	HOST().keep_ms = 1;
	T_Scene(HOST().loc);
	HOST().keep_ms = nil;
	TRF_OnLoad();
end;

function T_Tick(n, dt)
	local h = HOST();
	dt = dt or 0.5;
	for i = 1, n do
		h.gt = h.gt + dt; h.rt = h.rt + dt;
		TRF_OnTick(dt, dt);
	end;
end;

function T_Gen() return HOST_GenTick(); end;

-- Open traffic records and their live ships.
function T_Open()
	local n, s = 0, 0;
	for id, r in TRF.live.tr do
		if type(r) == "table" and r.st ~= "gone" then
			n = n + 1;
			local x = TRF_H().tr[id];
			if x then for i = 1, getn(x.sh) do if x.sh[i].alive then s = s + 1; end; end; end;
		end;
	end;
	return n, s;
end;

-- New trader through the generator (contact 1 and the roll forced); path: retry until that path.
-- Spacing stamps are cleared between tries, so no game time passes.
function T_Spawn(path)
	local h = HOST();
	for k = 1, 60 do
		local before = TRF.seq;
		h.rq = {0, 0};
		T_Gen();
		h.rq = {};
		if TRF.seq ~= before and TRF_Rec(TRF.seq) then
			local id = TRF.seq;
			if not path or TRF.live.tr[id].path == path then return id; end;
			TRF_Remove(id, "test");
		end;
		TRF.live.port = {};
	end;
	return nil;
end;

function T_MoveTr(id, x, y, z)
	local sh = TRF_H().tr[id].sh;
	for i = 1, getn(sh) do sh[i].pos = Vector3(x, y, z + 5 * i); end;
end;

function T_Stat(k) return TRF.live.stat[k] or 0; end;

function T_Lines(pat)
	local n = 0;
	local q = HOST().screen;
	for i = 1, getn(q) do if not pat or strfind(q[i].t, pat) then n = n + 1; end; end;
	return n;
end;

function T_Msgs(text)
	local n = 0;
	local q = HOST().msgs;
	for i = 1, getn(q) do if q[i].t == text then n = n + 1; end; end;
	return n;
end;

-- Globals the spawn and the response must not leave behind (no handle in the save).
function T_LeftGlobals()
	local s = "";
	for k, v in globals() do
		if type(k) == "string" and (strfind(k, "^flight_trf") or strfind(k, "^ship_trf") or strfind(k, "^pilot_trf")
			or strfind(k, "^TRF_GTrade_") or strfind(k, "^TRF_GResp_")) then s = s.." "..k; end;
	end;
	return s;
end;

-- Mod callback strings without the current gen, as " action" entries.
function T_BadCallbacks()
	local s = "";
	local q = HOST().triggers;
	local tail = ","..TRF.gen..")--";
	for i = 1, getn(q) do
		local a = q[i].action;
		if type(a) == "string" and strsub(a, 1, 4) == "TRF_" and strsub(a, -strlen(tail)) ~= tail then s = s.." "..a; end;
	end;
	return s;
end;

-- Runs f expecting script errors; returns their number and takes them off the error count.
function T_Expect(f)
	local h = HOST();
	local em = _ERRORMESSAGE;
	h.expected = 0;
	_ERRORMESSAGE = function(m) HOST().expected = HOST().expected + 1; print("HOST expected error: "..tostring(m)); end;
	f();
	_ERRORMESSAGE = em;
	return h.expected;
end;

function T_Begin(sys)
	HOST_Includes();
	HOST_Check(ExecuteScriptFile("DATA/Scripts/Mods/Traffic/traffic.script") and HOST_V() == 3, "traffic.script loads the traffic modules");
	T_Enter(sys or "gredos");
end;

-- a: vanilla parity of declines (spec 2.3, 10.4 scenarios 1-3) ---------------------------

function T_A()
	local h = HOST();
	T_Cfg({guard=1});
	h.labels.CurrentQuest = "3"; h.qs = TRUE;
	T_Begin("gredos");
	HOST_Check(TRF_orig_GenAction ~= nil and trigger_generator_Action ~= TRF_orig_GenAction and TRF_IsMine(trigger_generator_Action)
		and not TRF_IsMine(TRF_orig_GenAction), "generator thunk installed over the vanilla action");
	local list = __sys_LevelRegisteredContacts;
	local nv, r0, a0 = getn(h.vgen), h.rand, h.gen_trig.acts;
	T_Gen();
	local v = h.vgen[nv + 1];
	HOST_Check(getn(h.vgen) == nv + 1 and v.n == 0 and v.list == list and getn(v.list) == 2 and v.rand == r0,
		"guard: gredos (start), CurrentQuest 3, mission active -> original once, no args, full contact list, no extra RAND draw");
	HOST_Check(__sys_LevelRegisteredContacts == list and T_Open() == 0 and T_Stat("van_guard") >= 1 and h.gen_trig.acts == a0 + 1,
		"guard: contact table untouched, no traffic record, van_guard counted, re-armed once by the original");
	foreachi({"4_5", "1"}, function(i, q)
		local h = HOST();
		h.labels.CurrentQuest = q;
		local nv, r0 = getn(h.vgen), h.rand;
		T_Gen();
		HOST_Check(getn(h.vgen) == nv + 1 and h.vgen[nv + 1].rand == r0 and h.vgen[nv + 1].n == 0, "guard: CurrentQuest "..q.." -> untouched original");
	end);
	h.labels.CurrentQuest = nil;
	nv, r0 = getn(h.vgen), h.rand;
	T_Gen();
	HOST_Check(getn(h.vgen) == nv + 1 and h.vgen[nv + 1].rand == r0, "guard: CurrentQuest unset (mission 1) -> untouched original");
	-- Mission not active, guard 1: the mod decides; a trader contact never reaches the original.
	h.labels.CurrentQuest = "3"; h.qs = FALSE;
	nv, a0 = getn(h.vgen), h.gen_trig.acts;
	h.rq = {0, 0};
	T_Gen();
	h.rq = {};
	HOST_Check(getn(h.vgen) == nv and h.gen_trig.acts == a0 + 1 and T_Stat("spawn") == 1, "guard 1, no mission: mod path, re-armed by TRF_GenRearm, trader spawned");
	-- guard 2: start system and chapter <= 4 decline without a mission.
	h.cfg.guard = 2;
	nv, r0 = getn(h.vgen), h.rand;
	T_Gen();
	HOST_Check(getn(h.vgen) == nv + 1 and h.vgen[nv + 1].list == list and h.vgen[nv + 1].rand == r0, "guard 2, no mission: untouched original");
	h.cfg.guard = 1;
	-- Non-trader contact in a mod system: the original with only that contact, then the table is restored.
	nv, r0 = getn(h.vgen), h.rand;
	h.rq = {1};
	T_Gen();
	v = h.vgen[nv + 1];
	HOST_Check(getn(h.vgen) == nv + 1 and v.n == 0 and getn(v.list) == 1 and v.list[1] == list[2] and v.rand == r0 + 1
		and __sys_LevelRegisteredContacts == list, "pirate contact: original with {contact 2}, one extra draw, contact table restored");
	h.van_error = 1;
	local ne = T_Expect(function() HOST().rq = {1}; T_Gen(); end);
	h.van_error = nil;
	HOST_Check(ne == 1 and __sys_LevelRegisteredContacts == list, "error inside the original reaches _ERRORMESSAGE once and the table is restored");
	-- override 0 and __disableAction: untouched original.
	h.cfg.override = 0;
	nv, r0 = getn(h.vgen), h.rand;
	T_Gen();
	HOST_Check(getn(h.vgen) == nv + 1 and h.vgen[nv + 1].list == list and h.vgen[nv + 1].rand == r0, "override 0: untouched original");
	h.cfg.override = 1;
	__disableAction = TRUE;
	local n0 = T_Open();
	nv, r0 = getn(h.vgen), h.rand;
	T_Gen();
	HOST_Check(getn(h.vgen) == nv + 1 and h.vgen[nv + 1].rand == r0 and T_Open() <= n0, "__disableAction: untouched original, no spawn");
	__disableAction = FALSE;
	-- Deny list: elio with a mission -> vanilla; without -> mod.
	T_Jump("elio");
	h.labels.CurrentQuest = "5_1"; h.qs = TRUE;
	local m, why = TRF_SysMode();
	HOST_Check(m == "vanilla" and why == "deny", "deny list: elio during a mission -> vanilla ("..tostring(why)..")");
	nv = getn(h.vgen);
	T_Gen();
	HOST_Check(getn(h.vgen) == nv + 1 and h.vgen[nv + 1].list == __sys_LevelRegisteredContacts, "deny list: elio generator tick -> untouched original");
	h.qs = FALSE;
	m, why = TRF_SysMode();
	HOST_Check(m == "mod", "deny list: elio without a mission -> mod");
	HOST_Check(Case_Eject(HOST_Pilot("Trader")) == 2 and h.eject >= 1, "Case_Eject thunk returns the vanilla result");
end;

-- b: caps over 50 generator calls and 200 ticks (spec 5.1, 10.4 scenario 4-5) ------------

function T_B()
	local h = HOST();
	T_Cfg({guard=1});
	h.labels.CurrentQuest = "5_1"; h.qs = FALSE; h.st_label = "TRADE STATION";
	T_Begin("gredos");
	HOST_Check(TRF.live.capt == 2 and TRF.live.caps == 10 and TRF.live.stok == 1, "vanilla cap row 2 traders / 10 ships, station usable");
	local mt, ms, bad = 0, 0, "";
	local a0 = h.gen_trig.acts;
	local paths = {};
	for i = 1, 50 do
		local s0 = TRF.seq;
		T_Gen();
		if TRF.seq ~= s0 then paths[TRF.live.tr[TRF.seq].path] = 1; end;
		local n, s = T_Open();
		if n > 2 or s > 10 then bad = bad.." gen"..i.."="..n.."/"..s; end;
		T_Tick(4, 0.5);
		n, s = T_Open();
		if n > 2 or s > 10 then bad = bad.." tick"..i.."="..n.."/"..s; end;
		if n > mt then mt = n; end;
		if s > ms then ms = s; end;
		if mod(i, 10) == 0 then
			HOST_FireAll(nil, "TRF_ArmExit");
			HOST_FireAll(nil, "TRF_OnArrive");
			HOST_FireAll(nil, "TRF_OnExit");
		end;
		if i == 25 then
			local q = T_BadCallbacks();
			HOST_Check(q == "", "every mod callback string carries the current gen"..q);
		end;
	end;
	HOST_Check(bad == "" and mt == 2, "50 generator calls + 200 ticks: never above 2 traders / 10 ships (max "..mt.."/"..ms..")"..bad);
	HOST_Check(T_Stat("spawn") >= 3 and T_Stat("skip_cap") >= 1, "spawns and cap skips counted (spawn="..T_Stat("spawn").." skip_cap="..T_Stat("skip_cap")..")");
	HOST_Check(h.gen_trig.acts == a0 + 50, "every generator call re-armed the timer once ("..(h.gen_trig.acts - a0)..")");
	local g = "";
	for id, x in TRF_H().tr do
		if not strfind(x.fl.group.name, "^TRF_Trade_[1-4]$") then g = g.." "..x.fl.group.name; end;
	end;
	HOST_Check(g == "", "traffic flights in groups TRF_Trade_1..4"..g);
	local lg = T_LeftGlobals();
	HOST_Check(lg == "", "no flight_trf_/ship_trf_/TRF_GTrade_ globals left"..lg);
	HOST_Check(paths.A and paths.B and paths.C, "paths A, B and C used");
	TRF_DumpState("test");
end;

-- c: lifetime and watchdog (spec 5.3) ---------------------------------------------------

function T_C()
	local h = HOST();
	T_Cfg({guard=0});
	T_Begin("gredos");
	-- Stuck out of view: stage 1 re-route after 60 s, stage 2 deletes.
	local id = T_Spawn();
	local fl = TRF_H().tr[id].fl;
	T_MoveTr(id, 2500, 0, 2500);
	local t0, tw, tr = h.gt, nil, nil;
	for i = 1, 200 do
		T_Tick(2, 0.5);
		if not tw and T_Stat("wd_1") == 1 then tw = h.gt - t0; end;
		if TRF_Rec(id) == nil then tr = h.gt - t0; break; end;
	end;
	HOST_Check(tw and tw >= 60 and tw <= 80, "watchdog stage 1 after 60-80 s without movement ("..tostring(tw)..")");
	HOST_Check(tr and tr >= 120 and tr <= 150 and T_Stat("remove_stuck") == 1 and not fl:IsAlive(), "stuck trader out of view deleted at stage 2 ("..tostring(tr).." s)");
	-- Lifetime: moving, out of view, removed once older than 720 s.
	id = T_Spawn();
	fl = TRF_H().tr[id].fl;
	local born = TRF.live.tr[id].born;
	local x, age = 2500, nil;
	for i = 1, 800 do
		T_Tick(2, 0.5);
		if TRF_Rec(id) == nil then age = TRF.clock.gt - born; break; end;
		if mod(i, 10) == 0 then x = x + 30; T_MoveTr(id, x, 0, 2500); end;
	end;
	HOST_Check(age and age > 720 and age <= 735 and T_Stat("remove_life") == 1 and T_Stat("remove_stuck") == 1 and not fl:IsAlive(),
		"moving trader out of view removed by lifetime at age "..tostring(age));
	-- Stuck in view: stage 2 sends the leader to the nearest portal (stage 3), deleted once out of view.
	id = T_Spawn();
	local x2 = TRF_H().tr[id];
	T_MoveTr(id, h.ms.pos.x + 30, 0, h.ms.pos.z);
	for i = 1, 150 do
		T_Tick(2, 0.5);
		if TRF.live.tr[id].wd == 3 then break; end;
	end;
	local lead = x2.sh[1];
	HOST_Check(TRF.live.tr[id].wd == 3 and lead.cp ~= nil and TRF_Rec(id) and HOST_Count("f_object_inside", "TRF_OnExit("..id..","..TRF.gen..")--") >= 1,
		"stuck trader in view: stage 2 -> ComeToPortal and an exit trigger");
	T_MoveTr(id, 3000, 0, 3000);
	T_Tick(22, 0.5);
	HOST_Check(TRF_Rec(id) == nil and T_Stat("remove_stuck") == 2 and not x2.fl:IsAlive(), "stage 3: deleted once out of view");
end;

-- d: attack, T_deliberate, response, kills, pirate recovery, leg clock (spec 7, 10.3) ------

function T_D()
	local h = HOST();
	T_Cfg({guard=0});
	T_Begin("gredos");
	local id = T_Spawn();
	local r = TRF.live.tr[id];
	local x = TRF_H().tr[id];
	local pre = "TRF_OnAttack("..id..",1,"..TRF.gen..")--";
	-- Three events in one second count as one stamp.
	HOST_Fire("attack", pre); HOST_Fire("attack", pre); HOST_Fire("attack", pre);
	HOST_Check(getn(r.fs) == 1 and TRF.std.heat == 0 and r.pa == TRF.clock.gt, "same second: one stamp, pa set");
	-- v02 8.1: the response starts at the counted attack, graded by heat tier.
	HOST_Check(T_Msgs("#L_SOS_Replica_00") == 0 and r.resp == nil and TRF.live.patk == nil, "first attack: no response before the counted attack");
	for i = 1, 3 do T_Tick(2, 0.5); HOST_Fire("attack", pre); end;
	HOST_Check(getn(r.fs) == 4 and TRF.std.heat == 0 and not r.cnt, "T_deliberate: 4 seconds with attacks -> no heat");
	-- 21 s later the stamps are out of the 20 s window.
	T_Tick(42, 0.5);
	HOST_Fire("attack", pre);
	HOST_Check(getn(r.fs) == 1 and TRF.std.heat == 0 and h.choice == 0, "T_deliberate: stamps older than 20 s dropped, no response yet");
	local idx = TRF_CurIdx();
	-- pro of trf_region (0 when the module is missing).
	local pro = function(i) if type(TRF_Pro) == "function" then return TRF_Pro(i); end; return 0; end;
	local pro0 = pro(idx);
	for i = 1, 4 do T_Tick(2, 0.5); HOST_Fire("attack", pre); end;
	HOST_Check(TRF.std.heat == 1 and r.cnt == 1 and T_Lines("^Cease fire! This is a civilian freighter%.$") == 1, "T_deliberate: 5th second -> heat 1 and the cease-fire line");
	HOST_Check(r.resp == 1 and T_Msgs("#L_SOS_Replica_00") == 1 and TRF.live.patk == 1 and pro(idx) == max(pro0 - 1, 0),
		"counted attack: leader says #L_SOS_Replica_00, patk set, pro -1 ("..pro0.." -> "..pro(idx)..")");
	-- Heat 1 = tier 0: the __sys_SOS_3 roll, then 50 % for one owner flight (both draws forced).
	T_Tick(15, 0.5);
	h.rq = {0, 0};
	T_Tick(2, 0.5);
	h.rq = {};
	HOST_Check(h.choice == 1 and h.glows == 1 and getn(TRF_H().resp[1]) == 1, "response: 8 s later one owner flight and one glow (heat tier 0)");
	T_Tick(10, 0.5);
	HOST_Check(T_Msgs("#L_SOS_Replica_01") == 1, "response: #L_SOS_Replica_01 5 s after the flights");
	local lg = T_LeftGlobals();
	HOST_Check(lg == "", "response leaves no group or flight globals"..lg);
	local resp = TRF_H().resp[1];
	for i = 1, 6 do T_Tick(2, 0.5); HOST_Fire("attack", pre); end;
	HOST_Check(TRF.std.heat == 1 and T_Lines("^Cease fire") == 1 and h.choice == 1, "counted once per trader; no second response");
	-- Player kill: last transport dies within 10 s of a player attack.
	local k = r.k;
	for t = 1, getn(x.tp) do
		x.tp[t].alive = nil;
		HOST_Fire("died", "TRF_OnShipDied("..id..","..t..","..TRF.gen..")--");
	end;
	HOST_Check(TRF_Dis(idx) == 2 and TRF.std.heat == 2 and TRF.live.kills == 1 and TRF_Rec(id) == nil and T_Stat("remove_kill") == 1
		and TRF.live.grp[k] == 0, "player kill: dis +2, heat +1, kills 1, record closed, group slot freed");
	-- Kill by others: no attack event.
	local id2 = T_Spawn();
	local x2 = TRF_H().tr[id2];
	for t = 1, getn(x2.tp) do
		x2.tp[t].alive = nil;
		HOST_Fire("died", "TRF_OnShipDied("..id2..","..t..","..TRF.gen..")--");
	end;
	HOST_Check(TRF_Dis(idx) == 4 and TRF.std.heat == 2 and TRF.live.kills == 1 and T_Stat("remove_kill") == 2, "kill by others: dis +2 only");
	-- Pirate kills: Case_Eject watches the flight; dead at the next step -> dis -1, at most 2 per visit.
	local pg = HOST_Group("TRF_TestPir", "Pirates");
	local e0 = h.eject;
	local mk = function(n)
		local f = %pg:CreateFlight("pir"..n);
		local s = CreateCarcass("Raptor_merc1", Vector3(500 + 40 * n, 0, 500), Vector3(0, 0, 1));
		local p = CreatePilot("PirateAce");
		s:AssignPilot(p);
		f:AddShip(s);
		return s, p;
	end;
	local s1, p1 = mk(1);
	HOST_Check(Case_Eject(p1) == 2 and Case_Eject(p1) == 2 and h.eject == e0 + 2 and getn(TRF_H().pir) == 1, "Case_Eject: vanilla result, pirate flight watched once");
	HOST_Check(Case_Eject(x2.sh[getn(x2.sh)]:GetPilot()) == 2 and getn(TRF_H().pir) == 1, "Case_Eject: trader pilot not watched");
	s1.alive = nil;
	T_Tick(22, 0.5);
	HOST_Check(TRF_Dis(idx) == 3 and TRF.live.rec == 1, "pirate flight killed: dis -1");
	local s2, p2 = mk(2);
	local s3, p3 = mk(3);
	Case_Eject(p2); Case_Eject(p3);
	s2.alive = nil; s3.alive = nil;
	T_Tick(22, 0.5);
	HOST_Check(TRF_Dis(idx) == 2 and TRF.live.rec == 2 and T_Stat("pirate_kill") == 3, "recovery capped at 2 per visit (dis "..TRF_Dis(idx)..")");
	-- Leg clock: 3 jumps with 900 s each = 12 legs; heat -1 after 10 legs, dis -1 per 3 legs.
	local L0, H0 = TRF.clock.legs, TRF.std.heat_t;
	T_Jump("aurora");
	HOST_Check(resp[1].deleted and TRF.clock.legs == L0 + 1 and T_Open() == 0, "jump: response flights deleted, entry leg, visit reset");
	T_Tick(450, 2);
	T_Jump("gredos");
	T_Tick(450, 2);
	T_Jump("aurora");
	T_Tick(450, 2);
	HOST_Check(TRF.clock.legs == L0 + 12 and TRF.std.heat == 1 and TRF.std.heat_t == H0 + 10 and TRF_Dis(idx) == 0,
		"3 jumps, 12 legs: heat 2 -> 1, dis 2 -> 0 (legs="..TRF.clock.legs.." heat="..TRF.std.heat..")");
end;

-- e: focus and arrival lines (spec 8.3, 8.4) ---------------------------------------------

function T_E()
	local h = HOST();
	T_Cfg({guard=0});
	T_Begin("gredos");
	T_Tick(12, 0.5);
	HOST_Check(T_Lines() == 0 and TRF.live.arr == 1, "dis 0: no arrival line, arr done");
	-- dis is read when the line is due (entry legs may decay it first), so it is set after the entry.
	T_Jump("aurora");
	TRF.sys[9] = {dis=2};
	T_Tick(12, 0.5);
	HOST_Check(T_Lines() == 0, "dis 2: no arrival line");
	T_Jump("gredos");
	TRF.sys[46] = {dis=3};
	T_Tick(9, 0.5);
	HOST_Check(T_Lines() == 0, "dis 3: nothing before 5 s");
	T_Tick(2, 0.5);
	-- v02 9.6: tier word of the clan (tier 1 in the guard); the v0.1 text without trf_region.
	local want = "FTU reports raids on the lanes in this system";
	if type(TRF_EffTier) == "function" then want = "FTU reports scavengers on the lanes in this system"; end;
	HOST_Check(T_Lines() == 1 and h.screen[1].t == want, "dis 3: band 1 line after 5 s ("..tostring(h.screen[1] and h.screen[1].t)..")");
	T_Tick(40, 0.5);
	HOST_Check(T_Lines() == 1, "arrival line once per entry");
	-- Suppressed at that moment: not shown and not retried.
	T_Jump("aurora");
	TRF.sys[9] = {dis=7};
	__sys_SOS = TRUE;
	T_Tick(12, 0.5);
	__sys_SOS = FALSE;
	T_Tick(20, 0.5);
	HOST_Check(T_Lines() == 0 and TRF.live.arr == 1, "dis 7 under __sys_SOS: no line, no retry");
	-- Focus line: once per trader, 6 s apart.
	T_Jump("gredos");
	T_Tick(12, 0.5);
	local n0 = T_Lines();
	local a = T_Spawn();
	local b = T_Spawn();
	HOST_Check(a and b, "two traders for the focus test");
	HOST_Fire("focus", "TRF_OnFocus("..a..",");
	local pat = "^FTU freighters? %a+: [%a ]+, .+$";
	HOST_Check(T_Lines() == n0 + 1 and T_Lines(pat) == 1 and TRF.live.tr[a].met == 1, "focus: one line in the 8.2 format ("..h.screen[getn(h.screen)].t..")");
	local t1 = h.gt;
	HOST_Fire("f_object_inside", "TRF_OnNear("..a..",");
	HOST_Check(T_Lines() == n0 + 1, "proximity on the same trader: no second line");
	T_Tick(2, 0.5);
	HOST_Fire("focus", "TRF_OnFocus("..b..",");
	HOST_Check(T_Lines() == n0 + 1, "second trader within 6 s: line delayed");
	T_Tick(8, 0.5);
	HOST_Check(T_Lines() == n0 + 1, "still delayed 5 s after the first line");
	T_Tick(4, 0.5);
	local q = h.screen[getn(h.screen)];
	HOST_Check(T_Lines() == n0 + 2 and T_Lines(pat) == 2 and q.gt - t1 >= 6 and TRF.live.tr[b].met == 1, "second line shown 6 s after the first");
	HOST_Check(T_Stat("ui_focus") == 2 and T_Stat("ui_near") == 1, "focus and proximity events counted");
	HOST_Fire("f_object_inside", "TRF_OnNear("..b..",");
	T_Tick(20, 0.5);
	HOST_Check(T_Lines() == n0 + 2, "no line after both traders were shown");
	-- Meeting trigger: vanilla _FTrader_Action unless a flag is set.
	__sys_SOS = TRUE;
	HOST_Fire("f_object_inside", "TRF_OnMeet("..a..",");
	__sys_SOS = FALSE;
	HOST_Fire("f_object_inside", "TRF_OnMeet("..b..",");
	HOST_Check(h.meet == 1, "meeting: _FTrader_Action once, not under __sys_SOS");
end;

-- f: save/load round trip (spec 3.1, 5.5) -------------------------------------------------

function T_F()
	local h = HOST();
	T_Cfg({guard=0});
	T_Begin("gredos");
	T_Tick(20, 0.5);
	local a = T_Spawn();
	local b = T_Spawn();
	HOST_Check(a and b, "two traders before the save");
	TRF_AddHeat(3, "test");
	TRF.sys[9] = {dis=4};
	TRF.sys[46] = {dis=2};
	TRF.live.kills = 1;
	T_MoveTr(a, h.ms.pos.x + 60, 0, h.ms.pos.z);
	T_MoveTr(b, 2500, 0, 2500);
	local xa, xb = TRF_H().tr[a], TRF_H().tr[b];
	-- Orphan: a labelled traffic ship in the scan window without a record.
	local o = TRF.seq - 3;
	if o < 1 then o = o + 9999; end;
	local of = HOST_Group("TRF_Trade_X", "Trade"):CreateFlight("orphan");
	local os = CreateCarcass("Btransport", Vector3(h.ms.pos.x - 60, 0, h.ms.pos.z), Vector3(0, 0, 1));
	os:AssignPilot(CreatePilot("Trader"));
	of:AddShip(os);
	SetObjectLabel(os, "trf_"..o.."_1");
	local c = TRF.clock;
	local snap = {gen=TRF.gen, legs=c.legs, gt=c.gt, dd=c.dd, seq=TRF.seq, heat=TRF.std.heat, ht=TRF.std.heat_t, en=TRF.exp.cnt.enter};
	local oldpre = "TRF_OnAttack("..a..",1,"..TRF.gen..")--";
	local olddied = "TRF_OnShipDied("..b..",1,"..TRF.gen..")--";
	local n0 = T_Lines();
	T_SaveLoad();
	c = TRF.clock;
	HOST_Check(TRF.version == 3 and TRF.gen == snap.gen + 1 and c.legs == snap.legs and c.gt == snap.gt and c.dd == snap.dd and TRF.seq == snap.seq,
		"load: version 3, gen + 1, legs, gt, dd and seq kept (no leg on load)");
	HOST_Check(TRF.std.heat == 3 and TRF.std.heat_t == snap.ht and TRF.sys[9].dis == 4 and TRF.sys[46].dis == 2
		and TRF.exp.cnt.enter == snap.en and TRF.exp.cnt.load == 1, "load: heat, dis and the entry/load counters kept");
	HOST_Check(TRF.live.g == TRF.gen and TRF.live.kills == 0 and getn(TRF.live.due) == 0, "load: visit table reset (kills 0, no due call, no arrival line)");
	HOST_Check(TRF.live.tr[a] and TRF.live.tr[a].st == "wind" and xa.sh[1].cp ~= nil
		and HOST_Count("f_object_inside", "TRF_OnExit("..a..","..TRF.gen..")--") == 1, "load pass: trader in view winds down to a portal");
	HOST_Check(TRF.live.tr[b] == nil and not xb.fl:IsAlive() and T_Stat("remove_load") == 1 and T_Stat("wind_load") == 1, "load pass: trader out of view deleted");
	HOST_Check(TRF.live.tr[o] and TRF.live.tr[o].st == "wind" and os.cp ~= nil and T_Stat("remove_orphan") == 1, "orphan scan: labelled ship without a record winds down");
	local e0 = h.errors;
	HOST_Fire("attack", oldpre);
	HOST_Fire("died", olddied);
	HOST_Check(TRF.std.heat == 3 and TRF.sys[46].dis == 2 and h.errors == e0, "triggers restored with the old gen do nothing");
	T_Tick(20, 0.5);
	HOST_Check(T_Lines() - T_Lines("Breaking off") == n0, "no arrival line after a load (heat 3 flee line excepted, v02 8.1)");
	-- Review O1: an error in a callback body stays in its shim; logged once per name, every one counted.
	local body, lg, e1, er = TRF_OnExit_Body, TRF_Log, h.errors, T_Stat("err");
	h.cb_log = 0;
	TRF_Log = function(s)
		if strfind(s, " ERROR cb TRF_OnExit: ", 1, 1) then HOST().cb_log = HOST().cb_log + 1; end;
		print("HOST expected error (mod log): "..s);
	end;
	local act = "TRF_OnExit("..a..","..TRF.gen..")--";
	TRF_OnExit_Body = function(id, g) error("test error in body"); end;
	local ne = T_Expect(function() dostring(%act); dostring(%act); end);
	TRF_OnExit_Body, TRF_Log = body, lg;
	HOST_Check(ne == 0 and h.cb_log == 1 and h.errors == e1 and T_Stat("err_TRF_OnExit") == 2 and T_Stat("err") == er + 2 and TRF_Rec(a) ~= nil,
		"callback error: not propagated, one ERROR log line, err_TRF_OnExit 2, record kept");
	HOST_Fire("f_object_inside", "TRF_OnExit("..a..","..TRF.gen..")--");
	HOST_Check(TRF_Rec(a) == nil and not xa.fl:IsAlive() and T_Stat("remove_exit") == 1, "wound-down trader removed at its exit");
	HOST_Check(HOST_Reserved(TRF, "TRF") == "", "no reserved key in TRF after the load");
	-- Save made without the mod: TRF nil at OnLoad.
	T_SaveLoad(function() TRF = nil; end);
	HOST_Check(TRF.version == 3 and TRF.gen == 1 and TRF.clock.legs == 0 and TRF.live.g == 1 and TRF.std.heat == 0, "load without TRF: v3 defaults");
	-- Phase 0 (v1) save.
	T_SaveLoad(function() TRF = {version=1, active=1, gen=5, clock={game=123, real=4}, exp={cnt={enter=3}}}; end);
	HOST_Check(TRF.version == 3 and TRF.clock.gt == 123 and TRF.clock.game == nil and TRF.gen == 6 and TRF.clock.legs == 0
		and TRF.std.heat == 0 and TRF.exp.cnt.enter == 3 and TRF.live.g == 6, "v1 save migrated: clock.gt from clock.game, gen + 1, exp kept");
	-- Unknown version: reset, heat and gen kept.
	T_SaveLoad(function() TRF = {version=9, gen=8, std={heat=4}, foo=1, clock={gt=7}}; end);
	HOST_Check(TRF.version == 3 and TRF.std.heat == 4 and TRF.gen == 9 and TRF.foo == nil and TRF.clock.gt == 0, "unknown version: reset, heat and gen kept");
	T_Tick(20, 0.5);
	HOST_Check(TRF.clock.gt == 10, "ticks run after the reset");
end;

-- g: safety predicates reject what they should (spec 2.3, 5.1, 5.2, 6) ---------------------

function T_G()
	local h = HOST();
	T_Cfg({guard=1});
	T_Begin("gredos");
	foreachi({{nil, 0}, {"", 0}, {"1", 1}, {"4_2", 4}, {"5_1", 5}, {"12a", 12}, {"20c", 20}, {"x", 0}}, function(i, t)
		HOST_Check(TRF_ChapterOf(t[1]) == t[2], "TRF_ChapterOf("..tostring(t[1])..") = "..t[2]);
	end);
	local base = function(t)
		local s = {enabled=1, override=1, guard=1, sys={name="corrino", start=0}, off={}, deny=TRF_Deny(), deny2={}, qs=1, ch=5};
		for k, v in t do s[k] = v; end;
		return s;
	end;
	local cases = {
		{{}, "mod", nil},
		{{enabled=0}, "vanilla", "off"},
		{{override=0}, "vanilla", "off"},
		{{override=2}, "vanilla", "observe"},
		{{override=3}, "vanilla", "off"},
		{{sys=0}, "vanilla", "nomap"},
		{{off={"corrino"}}, "vanilla", "sys_off"},
		{{off={"CORRINO"}}, "vanilla", "sys_off"},
		{{inval="nomatch 1 ci=1"}, "vanilla", "inval"},
		{{sys={name="elio", start=1}}, "vanilla", "deny"},
		{{sys={name="x297"}}, "vanilla", "deny"},
		{{sys={name="gefest", start=1}}, "vanilla", "deny"},
		{{sys={name="elio", start=1}, qs=0, ch=5}, "mod", nil},
		{{deny2={"corrino"}}, "vanilla", "deny"},
		{{deny2={"corrino"}, qs=0}, "mod", nil},
		{{sys={name="gredos", start=1}, ch=4}, "vanilla", "guard"},
		{{sys={name="gredos", start=1}, ch=0}, "vanilla", "guard"},
		{{sys={name="gredos", start=1}, ch=4, qs=0}, "mod", nil},
		{{sys={name="gredos", start=1}, ch=4, qs=0, guard=2}, "vanilla", "guard"},
		{{sys={name="gredos", start=1}, ch=1, guard=0}, "mod", nil},
		{{sys={name="gredos", start=1}, ch=5}, "mod", nil},
		{{ch=1}, "mod", nil}
	};
	for i = 1, getn(cases) do
		local t = cases[i];
		local s = base(t[1]);
		if s.sys == 0 then s.sys = nil; end;
		if s.qs == 0 then s.qs = nil; end;
		local m, why = TRF_SysModeOf(s);
		HOST_Check(m == t[2] and why == t[3], "TRF_SysModeOf case "..i.." -> "..m.." "..tostring(why));
	end;
	-- Suppression: 0 none, 1 pause, 2 wind-down.
	foreachi({{nil, nil, 100, nil, nil, 0}, {1, nil, 100, nil, nil, 2}, {1, 1, 100, 0, nil, 2}, {nil, 1, 100, nil, nil, 1},
		{nil, 1, 100, 71, nil, 1}, {nil, 1, 100, 70, nil, 2}, {nil, 1, 100, 0, 1, 1}}, function(i, t)
		HOST_Check(TRF_SuppOf(t[1], t[2], t[3], t[4], t[5], 30) == t[6], "TRF_SuppOf case "..i.." = "..t[6]);
	end);
	-- Spawn gate.
	local sp = function(t)
		local s = {supp=0, ntr=0, nsh=0, n=3, capt=2, caps=10, kills=0, kcap=3};
		for k, v in t do s[k] = v; end;
		return s;
	end;
	local ok, r = TRF_CanSpawnOf(sp({}));
	HOST_Check(ok == 1 and r == 7, "TRF_CanSpawnOf: free -> 1, 7 spare ships");
	foreachi({{{supp=1}, "supp"}, {{supp=2}, "supp"}, {{kills=3}, "kills"}, {{ntr=2}, "cap"}, {{ntr=1, capt=1}, "cap"},
		{{nsh=8}, "ships"}, {{nsh=0, n=11}, "ships"}}, function(i, t)
		local ok, r = TRF_CanSpawnOf(%sp(t[1]));
		HOST_Check(not ok and r == t[2], "TRF_CanSpawnOf rejects case "..i.." ("..tostring(r)..")");
	end);
	ok, r = TRF_CanSpawnOf(sp({kills=5, kcap=0}));
	HOST_Check(ok == 1, "TRF_CanSpawnOf: kill cap 0 is off");
	ok, r = TRF_CanSpawnOf(sp({nsh=7}));
	HOST_Check(ok == 1 and r == 0, "TRF_CanSpawnOf: exactly at the ship cap -> 1, 0 spare");
	-- Governor.
	local ct, cs = TRF_GovernorOf(41, 2, 10, 40);
	HOST_Check(ct == 1 and cs == 10, "governor: 41 carcasses -> 1 trader");
	ct, cs = TRF_GovernorOf(40, 2, 10, 40);
	HOST_Check(ct == 2 and cs == 10, "governor: 40 carcasses -> unchanged");
	ct, cs = TRF_GovernorOf(nil, 2, 10, 40);
	HOST_Check(ct == 2 and cs == 10, "governor: count unknown -> unchanged");
	ct, cs = TRF_GovernorOf(99, 1, 14, 40);
	HOST_Check(ct == 1 and cs == 12, "governor: never below 1 trader, ships <= 12");
	-- Wind-down choice.
	foreachi({{"A", nil, 10, "delete"}, {"A", 601, 10, "delete"}, {"A", 600, 300, "dock"}, {"A", 100, 301, "portal"},
		{"B", 100, 10, "portal"}, {"C", 100, nil, "portal"}}, function(i, t)
		HOST_Check(TRF_WindChoiceOf(t[1], t[2], t[3], 600, 300) == t[4], "TRF_WindChoiceOf case "..i.." = "..t[4]);
	end);
	-- Config clamps (v02 10.2: caps 0..5 / 0..20, spawn_scale 0..1.5 replace the v0.1 2 / 10 / 1).
	h.cfg.spawn_scale = 5; h.cfg.cap_traders = 9; h.cfg.cap_ships = 50; h.cfg.override = 7; h.cfg.guard = "x";
	HOST_Check(TRF_Opt("spawn_scale") == 1.5 and TRF_Opt("cap_traders") == 5 and TRF_Opt("cap_ships") == 20 and TRF_Opt("override") == 1
		and TRF_Opt("guard") == 1, "TRF_Opt clamps spawn_scale, caps, override and guard");
	h.cfg.spawn_scale = nil; h.cfg.cap_traders = nil; h.cfg.cap_ships = nil; h.cfg.override = nil; h.cfg.guard = 1;
	-- Game-side inputs: mission state, suppression, extortion debounce, station.
	h.labels.CurrentQuest = "3"; h.qs = TRUE;
	local m, why = TRF_SysMode();
	HOST_Check(m == "vanilla" and why == "guard", "TRF_SysMode: gredos chapter 3 with a mission -> guard");
	local gq = GetPlayerQuestState;
	GetPlayerQuestState = nil;
	h.labels.CurrentQuest = "5_1"; h.no_st = 1;
	T_Jump("elio");
	m, why = TRF_SysMode();
	HOST_Check(m == "vanilla" and why == "deny", "missing GetPlayerQuestState counts as a mission (deny list stays vanilla)");
	GetPlayerQuestState = gq;
	h.qs = FALSE;
	__sys_SOS = TRUE;
	T_Tick(2, 0.5);
	HOST_Check(TRF_Supp() == 1 and not TRF_CanSpawn(0), "__sys_SOS: pause, no spawn");
	__sys_Pirate_Money = 500;
	flight_pir_mon_1 = HOST_Flight("flight_pir_mon_1", HOST_Group("group_Pirate_money", "Pirates"));
	flight_pir_mon_1:AddShip(CreateCarcass("Raptor_merc1", Vector3(0, 0, 900), Vector3(0, 0, 1)));
	T_Tick(70, 0.5);
	HOST_Check(TRF.live.ext_seen == 1 and TRF_Supp() == 1, "extortion flight alive: still a pause after 35 s");
	flight_pir_mon_1.ships[1].alive = nil;
	HOST_Check(TRF_Supp() == 2, "extortion flight dead after 30 s of __sys_SOS: wind-down");
	__sys_SOS = FALSE; __sys_Pirate_Money = nil; flight_pir_mon_1 = nil;
	T_Tick(2, 0.5);
	HOST_Check(TRF_Supp() == 0 and TRF.live.wind == nil, "flags clear: no suppression, wind cleared");
	HOST_Check(TRF_Station() == nil and TRF.live.stok == 0, "no st field in the map: no station");
	h.st_label = "TRADE STATION"; h.no_st = nil;
	T_Jump("gredos");
	HOST_Check(TRF_Station() == h.station and TRF.live.stok == 1, "st label: station found");
	h.station.alive = nil;
	HOST_Check(TRF_Station() == nil and TRF.live.stok == 0, "station destroyed: lost");
	h.station.alive = 1;
	HOST_Check(TRF_Station() == nil, "a lost station stays off for the visit");
	-- Visit kill cap: 3 player kills stop spawning until the next entry.
	TRF.live.kills = 3;
	ok, r = TRF_CanSpawn(0);
	HOST_Check(not ok and r == "kills", "visit kill cap 3 -> no spawn");
	T_Jump("aurora");
	ok, r = TRF_CanSpawn(0);
	HOST_Check(ok == 1, "next entry: spawning allowed again");
	h.extra_carcass = 50;
	TRF_Governor();
	HOST_Check(TRF.live.capt == 1 and TRF.live.caps == 10, "governor with 50 carcasses: cap 1 trader");
	h.extra_carcass = nil;
	-- Wind-down (R3): __disableAction mid-visit -> once per onset, in view to a portal, out of view deleted.
	TRF_Governor();
	local a = T_Spawn();
	local b = T_Spawn();
	T_MoveTr(a, h.ms.pos.x + 40, 0, h.ms.pos.z);
	T_MoveTr(b, 2500, 0, 2500);
	local xb = TRF_H().tr[b];
	__disableAction = TRUE;
	T_Tick(22, 0.5);
	HOST_Check(TRF.live.wind == 1 and TRF.live.tr[a].st == "wind" and TRF_H().tr[a].sh[1].cp ~= nil and TRF_Rec(b) == nil
		and not xb.fl:IsAlive(), "wind-down: in view to a portal, out of view deleted");
	local nw = T_Stat("wind_portal");
	local s0 = TRF.seq;
	T_Gen();
	T_Tick(22, 0.5);
	HOST_Check(T_Stat("wind_portal") == nw and TRF.seq == s0, "wind-down runs once per onset; no spawn while __disableAction");
	__disableAction = FALSE;
	T_Tick(2, 0.5);
	HOST_Check(TRF.live.wind == nil, "flag cleared: wind reset for the next onset");
end;

local fn = getglobal("T_"..strupper(HOST().scen));
if strsub(HOST().scen, 1, 4) == "v02-" then
	-- host_v02.lua (loaded next by host_stubs.lua) runs the scenario with these helpers.
elseif type(fn) == "function" then
	fn();
	HOST_Check(T_LeftGlobals() == "", "no handle globals left at the end"..T_LeftGlobals());
else
	HOST_Check(nil, "unknown scenario "..tostring(HOST().scen));
end;
