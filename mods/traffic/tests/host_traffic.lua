-- Traffic scenarios (v0.1 modules) for host_stubs.lua: TRF_SCEN=a..g, run by run_host.sh.
-- a vanilla parity of declines, b caps over many generator calls, c lifetime and watchdog, d attack, heat,
-- response, kills, pirate recovery and the leg clock, e focus and arrival lines, f save/load round trip,
-- g safety predicates. Uses the stubs and engine emulation of host_stubs.lua; state in HOST().

-- Helpers ---------------------------------------------------------------------------

-- Config for the scenario: the repo defaults plus t (TRF_Config returns HOST().cfg). The v0.1 scenarios a..g
-- run with the v0.2 features off (band 0 = v0.1, v02-spec 9.1), so they keep checking the v0.1 behaviour;
-- T_Cfg2 (host_v02.lua) starts from the v0.2 defaults instead.
-- v1 features off and the v0.2 tier cap (v1-spec 10.5), so the v0.1 and v0.2 scenarios keep checking their
-- behaviour with the v1 files loaded; host_v1.lua starts from the v1 defaults.
function T_V1Off()
	return {tier_cap=2, track=0, conv=0, demand=0, heat_offer=0, carriers=0, salvage=0, sweeps=0, sweep_ct=0,
		po=0, tt4=0, feq=0, forced_bust=0, dconv=0, bases=0, cap_enable=0};
end;
function T_V01()
	return {prosperity=0, seed=0, parked=0, queue=0, raids=0, staged=0, contracts=0, meet=1, board=0,
		shop_mode=0, short_price=0, news_mode=0, esc_flight=0};
end;
function T_Cfg(t)
	local c = {exp=0, log=1, traffic=1};
	for k, v in T_V1Off() do c[k] = v; end;
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
	local save = HOST_SaveCopy(globals(), 1);
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

-- Handle globals kept for the save (v01 3.3): NewAllFlight's flight_/ship_/pilot_ and TRF_ship_ of an open
-- trader record (or one waiting in the load retry), TRF_pk_<j> of a parked entry. 1 or nil.
function T_HandleOk(k)
	if type(TRF) ~= "table" or type(TRF.live) ~= "table" then return nil; end;
	local L = TRF.live;
	local a, b, id = strfind(k, "^flight_trf_(%d+)$");
	if not id then a, b, id = strfind(k, "^ship_trf_(%d+)_%d+$"); end;
	if not id then a, b, id = strfind(k, "^pilot_trf_(%d+)_%d+$"); end;
	if not id then a, b, id = strfind(k, "^TRF_ship_trf_(%d+)_%d+$"); end;
	if id then
		id = tonumber(id);
		local r = nil;
		if type(L.tr) == "table" then r = L.tr[id]; end;
		if type(r) == "table" and r.st ~= "gone" then return 1; end;
		if type(L.lw) == "table" and type(L.lw.rec) == "table" and L.lw.rec[id] then return 1; end;
		return nil;
	end;
	local c, d, j = strfind(k, "^TRF_pk_(%d+)$");
	if j and type(L.pk) == "table" then
		j = tonumber(j);
		for i = 1, getn(L.pk) do if L.pk[i] == j then return 1; end; end;
	end;
	return nil;
end;

-- Group globals of the worldbuilding group prefixes (00 section 6, trf_plumb TRF_PlGroups; the lint list is
-- GROUP_PREFIXES in tools/lint_lua.py): TRF_G<name>_<n> is set only around a build.
function T_GroupPfx()
	return {"Cust", "Scv", "Cap", "Esc", "Def", "Pick", "Push", "Merc", "Rival", "Fw", "Drop", "Sh", "Nest"};
end;

-- Globals the spawn and the response must not leave behind: group globals, and handle globals of a closed
-- record or parked entry (T_HandleOk).
function T_LeftGlobals()
	local s = "";
	local gp = T_GroupPfx();
	for k, v in globals() do
		if type(k) == "string" and not T_HandleOk(k) and (strfind(k, "^flight_trf") or strfind(k, "^ship_trf") or strfind(k, "^pilot_trf")
			or strfind(k, "^TRF_ship_trf") or strfind(k, "^TRF_pk_") or strfind(k, "^TRF_GTrade_") or strfind(k, "^TRF_GResp_")) then s = s.." "..k; end;
		if type(k) == "string" and strsub(k, 1, 5) == "TRF_G" then
			for i = 1, getn(gp) do if strfind(k, "^TRF_G"..gp[i].."_") then s = s.." "..k; end; end;
		end;
	end;
	return s;
end;

-- Handle globals of trader id (flight_/ship_/pilot_/TRF_ship_ of sign trf_<id>), as " name" entries.
function T_SignGlobals(id)
	local s = "";
	local sign = "trf_"..id;
	for k, v in globals() do
		if type(k) == "string" and (k == "flight_"..sign or strfind(k, "^ship_"..sign.."_%d") or strfind(k, "^pilot_"..sign.."_%d")
			or strfind(k, "^TRF_ship_"..sign.."_%d")) then s = s.." "..k; end;
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
	HOST_Check(ExecuteScriptFile("DATA/Scripts/Mods/Traffic/traffic.script") and HOST_V() == 4, "traffic.script loads the traffic modules");
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
	-- GetPlayerQuestState not TRUE (in game: nil during mission 3 in Argon and after every jump): guard 1 and 2
	-- still decline in a start system while the chapter is <= 4.
	h.labels.CurrentQuest = "3"; h.qs = FALSE;
	foreachi({1, 2}, function(i, g)
		local h = HOST();
		h.cfg.guard = g;
		local nv, r0 = getn(h.vgen), h.rand;
		T_Gen();
		HOST_Check(getn(h.vgen) == nv + 1 and h.vgen[nv + 1].list == %list and h.vgen[nv + 1].rand == r0, "guard "..g..", chapter 3, no quest state: untouched original");
	end);
	h.cfg.guard = 1;
	-- Chapter 5 in a start system: the mod decides; a trader contact never reaches the original.
	h.labels.CurrentQuest = "5_1";
	nv, a0 = getn(h.vgen), h.gen_trig.acts;
	h.rq = {0, 0};
	T_Gen();
	h.rq = {};
	HOST_Check(getn(h.vgen) == nv and h.gen_trig.acts == a0 + 1 and T_Stat("spawn") == 1, "guard 1, chapter 5: mod path, re-armed by TRF_GenRearm, trader spawned");
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
	HOST_Check(TRF.version == 4 and TRF.gen == snap.gen + 1 and c.legs == snap.legs and c.gt == snap.gt and c.dd == snap.dd and TRF.seq == snap.seq,
		"load: version 4, gen + 1, legs, gt, dd and seq kept (no leg on load)");
	HOST_Check(TRF.std.heat == 3 and TRF.std.heat_t == snap.ht and TRF.sys[9].dis == 4 and TRF.sys[46].dis == 2
		and TRF.exp.cnt.enter == snap.en and TRF.exp.cnt.load == 1, "load: heat, dis and the entry/load counters kept");
	HOST_Check(TRF.live.g == TRF.gen and TRF.live.kills == 0 and getn(TRF_H().due) == 0 and TRF.live.due == nil, "load: visit table reset (kills 0, no due call, no arrival line)");
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
		if strfind(s, " module=core event=error source=TRF_OnExit ", 1, 1) then HOST().cb_log = HOST().cb_log + 1; end;
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
	HOST_Check(TRF.version == 4 and TRF.gen == 1 and TRF.clock.legs == 0 and TRF.live.g == 1 and TRF.std.heat == 0, "load without TRF: v4 defaults");
	-- Phase 0 (v1) save.
	T_SaveLoad(function() TRF = {version=1, active=1, gen=5, clock={game=123, real=4}, exp={cnt={enter=3}}}; end);
	HOST_Check(TRF.version == 4 and TRF.clock.gt == 123 and TRF.clock.game == nil and TRF.gen == 6 and TRF.clock.legs == 0
		and TRF.std.heat == 0 and TRF.exp.cnt.enter == 3 and TRF.live.g == 6, "v1 save migrated: clock.gt from clock.game, gen + 1, exp kept");
	-- Unknown version: reset, heat and gen kept.
	T_SaveLoad(function() TRF = {version=9, gen=8, std={heat=4}, foo=1, clock={gt=7}}; end);
	HOST_Check(TRF.version == 4 and TRF.std.heat == 4 and TRF.gen == 9 and TRF.foo == nil and TRF.clock.gt == 0, "unknown version: reset, heat and gen kept");
	T_Tick(20, 0.5);
	HOST_Check(TRF.clock.gt == 10, "ticks run after the reset");
	T_LoadAdopt();
	T_LoadHandles();
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
		{{sys={name="elio", start=1}, strict=0, ch=5}, "mod", nil},
		{{sys={name="elio", start=1}, strict=1}, "vanilla", "deny"},
		{{deny2={"corrino"}}, "vanilla", "deny"},
		{{deny2={"corrino"}, qs=0}, "mod", nil},
		{{sys={name="gredos", start=1}, ch=4}, "vanilla", "guard"},
		{{sys={name="gredos", start=1}, ch=0}, "vanilla", "guard"},
		{{sys={name="gredos", start=1}, ch=4, qs=0}, "vanilla", "guard"},
		{{sys={name="gredos", start=1}, ch=4, qs=0, guard=2}, "vanilla", "guard"},
		{{sys={name="gredos", start=1}, ch=1, guard=0}, "mod", nil},
		{{sys={name="gredos", start=1}, ch=5}, "mod", nil},
		{{sys={name="gredos", start=1}, ch=5, qs=0}, "mod", nil},
		{{ch=1}, "mod", nil},
		{{ch=1, qs=0}, "mod", nil},
		-- Transit rule: tq (teleport target) entries are vanilla only while a quest naming the system runs.
		{{sys={name="taira"}, deny={"taira"}, denyq={"taira"}, qa=0, transit=1}, "mod", nil},
		{{sys={name="taira"}, deny={"taira"}, denyq={"taira"}, qa=1, transit=1}, "vanilla", "deny_tq"},
		{{sys={name="taira"}, deny={"taira"}, denyq={"taira"}, transit=1}, "vanilla", "deny_tq"},
		{{sys={name="taira"}, deny={"taira"}, denyq={"taira"}, qa=0, transit=0}, "vanilla", "deny_tq"},
		{{sys={name="taira"}, deny={"taira"}, denyq={"taira"}, qa=0, transit=1, qs=0}, "mod", nil},
		{{sys={name="taira"}, deny={"taira"}, denyq={"taira"}, qa=0, transit=1, strict=0}, "mod", nil},
		{{sys={name="taira"}, deny={"taira"}, denyq={"taira"}, qa=0, transit=1, deny2={"taira"}}, "vanilla", "deny"},
		{{sys={name="elio", start=1}, qa=0, transit=1}, "vanilla", "deny"}
	};
	for i = 1, getn(cases) do
		local t = cases[i];
		local s = base(t[1]);
		if s.sys == 0 then s.sys = nil; end;
		if s.qs == 0 then s.qs = nil; end;
		local m, why = TRF_SysModeOf(s);
		HOST_Check(m == t[2] and why == t[3], "TRF_SysModeOf case "..i.." -> "..m.." "..tostring(why));
	end;
	-- Strict gate, transit rule: a tq entry with transit 1 and qa 0 opens every feature during a mission.
	local gfs = {"seed", "raid", "staged", "contract", "parked", "tt3", "band", "board", "track", "conv", "tt4",
		"sweep", "carrier", "feq", "dconv", "offer"};
	local gate = function(t)
		local s = {mode=1, qs=1, q=1, qa=0, ent={m=1, tq=1, why="teleport target"}, transit=1};
		for k, v in t do s[k] = v; end;
		if s.qa == -1 then s.qa = nil; end;
		local n, why = 0, nil;
		for i = 1, getn(%gfs) do
			s.f = %gfs[i];
			local ok, w = TRF_StrictOkOf(s);
			if ok then n = n + 1; elseif not why then why = w; end;
		end;
		return n, why;
	end;
	local gn, gw = gate({});
	HOST_Check(gn == getn(gfs) and gw == nil, "strict gate: tq entry, mission, qa 0, transit 1 -> every feature ok");
	gn, gw = gate({transit=0});
	HOST_Check(gn == 0 and gw == "mission_deny", "strict gate: tq entry, transit 0 -> mission_deny ("..tostring(gw)..")");
	gn, gw = gate({qa=1});
	HOST_Check(gn == 0 and gw == "quest", "strict gate: tq entry, qa 1 -> quest ("..tostring(gw)..")");
	gn, gw = gate({qa=-1});
	HOST_Check(gn == 0 and gw == "mission_q", "strict gate: tq entry, qa nil -> mission_q ("..tostring(gw)..")");
	gn, gw = gate({ent=TRF_DenyEntry("elio")});
	HOST_Check(gn == 0 and gw == "mission_deny", "strict gate: authored elio, qa 0, transit 1 -> mission_deny ("..tostring(gw)..")");
	h.cfg.sys_deny = {"taira"};
	local sde = TRF_DenyEntry("taira");
	HOST_Check(sde.m == 1 and sde.tq == nil, "cfg sys_deny drops tq from a teleport-target entry");
	gn, gw = gate({ent=sde});
	HOST_Check(gn == 0 and gw == "mission_deny", "strict gate: cfg sys_deny teleport target -> mission_deny ("..tostring(gw)..")");
	h.cfg.sys_deny = nil;
	gn, gw = gate({ent={m=1, tq=1, feq=0, why="teleport target"}});
	HOST_Check(gn == getn(gfs) - 1 and gw == "deny_feq", "strict gate: transit keeps a feature set to 0 in the entry off");
	-- Suppression: 0 none, 1 pause, 2 wind-down. {dis, sos, gt, sos_t, ext, scene, sos_mode, level}.
	foreachi({{nil, nil, 100, nil, nil, nil, nil, 0}, {1, nil, 100, nil, nil, nil, 1, 2}, {1, 1, 100, 0, nil, nil, 2, 2},
		{nil, 1, 100, nil, nil, nil, 1, 0}, {nil, 1, 100, 0, nil, nil, 1, 0}, {nil, 1, 100, 0, nil, nil, nil, 0},
		{nil, 1, 100, nil, nil, nil, 2, 1}, {nil, 1, 100, 71, nil, nil, 2, 1}, {nil, 1, 100, 70, nil, nil, 2, 2},
		{nil, 1, 100, 0, 1, nil, 2, 1}, {nil, nil, 100, nil, nil, 1, 1, 1}, {1, nil, 100, nil, nil, 1, 1, 2},
		{nil, 1, 100, 0, nil, 1, 1, 1}, {nil, 1, 100, 0, nil, 1, 2, 2}, {nil, nil, 100, nil, nil, 1, 2, 1}}, function(i, t)
		HOST_Check(TRF_SuppOf(t[1], t[2], t[3], t[4], t[5], 30, t[6], t[7]) == t[8], "TRF_SuppOf case "..i.." = "..t[8]);
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
	h.qs = FALSE;
	m, why = TRF_SysMode();
	HOST_Check(m == "vanilla" and why == "guard", "TRF_SysMode: gredos chapter 3, GetPlayerQuestState not TRUE -> guard");
	local gq = GetPlayerQuestState;
	GetPlayerQuestState = nil;
	h.labels.CurrentQuest = "5_1"; h.no_st = 1;
	T_Jump("elio");
	m, why = TRF_SysMode();
	HOST_Check(m == "vanilla" and why == "deny", "missing GetPlayerQuestState counts as a mission (deny list stays vanilla)");
	GetPlayerQuestState = gq;
	-- Transit rule in the game: taira (campaign-pass teleport target) during a mission.
	h.qs = TRUE; h.logs = {};
	local lg = 0;
	T_Jump("taira");
	local te = TRF_DenyList().taira;
	HOST_Check(type(te) == "table" and te.m == 1 and te.tq == 1 and TRF_DenyList().x297.tq == nil and TRF_DenyEntry("taira").tq == 1,
		"deny list: teleport target taira marked tq, authored x297 not");
	m, why = TRF_SysMode();
	HOST_Check(m == "mod" and TRF_SafeModeIn().qa == 0, "transit: taira during a mission, no taira quest in process -> mod");
	local ti = TRF_CurIdx();
	local pr0, pk0, p0 = h.cfg.prosperity, h.cfg.parked, TRF_Pro(ti);
	h.cfg.prosperity = 1; h.cfg.parked = 1;
	TRF_SetPro(ti, 6);
	local ct, cs, cp = TRF_SafeCaps(0);
	HOST_Check(TRF_SafeGateSum(nil) == "ok" and TRF_StrictOk(ti, "band") == 1 and TRF_StrictOk(ti, "parked") == 1
		and ct > 2 and cs > 10 and cp >= 1, "transit: taira gate ok, band 2 row "..tostring(ct).."/"..tostring(cs).."/"..tostring(cp)..", parked allowed");
	h.logs = {};
	TRF_Safety_Dump();
	lg = 0;
	for i = 1, getn(h.logs) do
		if strfind(h.logs[i], "module=safety event=dump gate=ok system=taira", 1, 1) and strfind(h.logs[i], "quest_active=0 deny_reason=\"teleport target\"", 1, 1) then lg = lg + 1; end;
	end;
	HOST_Check(lg == 1, "transit: taira dump line gate=ok with deny=teleport target");
	h.cfg.transit = 0;
	HOST_Check(strfind(TRF_SafeGateSum(nil), "^mission_deny:") and not TRF_StrictOk(ti, "band"), "transit 0: taira gate mission_deny");
	h.cfg.transit = nil;
	TRF_SetPro(ti, p0); h.cfg.prosperity = pr0; h.cfg.parked = pk0;
	h.logs = {};
	h.cfg.transit = 0;
	local v0 = T_Stat("van_deny_tq");
	m, why = TRF_SysMode();
	lg = 0;
	for i = 1, getn(h.logs) do if strfind(h.logs[i], "event=mode system=taira mode=vanilla reason=deny_tq", 1, 1) then lg = lg + 1; end; end;
	HOST_Check(m == "vanilla" and why == "deny_tq" and T_Stat("van_deny_tq") == v0 + 1 and lg == 1,
		"transit 0: taira during a mission -> deny_tq, counted and logged ("..tostring(why)..")");
	h.cfg.transit = nil;
	h.quests.quest_6c_01 = QUEST_PROCESS;
	T_Jump("taira");
	m, why = TRF_SysMode();
	HOST_Check(m == "vanilla" and why == "deny_tq" and TRF_SafeModeIn().qa == 1, "transit: taira quest 6c_01 in process -> deny_tq");
	h.quests.quest_6c_01 = nil; h.logs = nil;
	h.qs = FALSE;
	-- sos_mode 1 (default): __sys_SOS alone does not suppress; logged once with sos=1, quiet for lines.
	h.logs = {};
	__sys_SOS = TRUE;
	T_Tick(2, 0.5);
	local ln = 0;
	for i = 1, getn(h.logs) do if strfind(h.logs[i], "module=safety event=suppression old=0 new=0 disable_action=false sos=true scene=false sos_mode=1", 1, 1) then ln = ln + 1; end; end;
	HOST_Check(TRF_Supp() == 0 and TRF_CanSpawn(0) and TRF_Quiet() == 1 and ln == 1, "__sys_SOS, sos_mode 1: no suppression, spawn allowed, quiet, one supp line");
	__sys_SOS = FALSE;
	T_Tick(2, 0.5);
	h.logs = nil;
	-- sos_mode 2: the old rule (pause, wind-down after sos_db 30 s unless the extortion flight lives).
	h.cfg.sos_mode = 2;
	__sys_SOS = TRUE;
	T_Tick(2, 0.5);
	HOST_Check(TRF_Supp() == 1 and not TRF_CanSpawn(0), "__sys_SOS, sos_mode 2: pause, no spawn");
	__sys_Pirate_Money = 500;
	flight_pir_mon_1 = HOST_Flight("flight_pir_mon_1", HOST_Group("group_Pirate_money", "Pirates"));
	flight_pir_mon_1:AddShip(CreateCarcass("Raptor_merc1", Vector3(0, 0, 900), Vector3(0, 0, 1)));
	T_Tick(70, 0.5);
	HOST_Check(TRF.live.ext_seen == 1 and TRF_Supp() == 1, "extortion flight alive: still a pause after 35 s");
	flight_pir_mon_1.ships[1].alive = nil;
	HOST_Check(TRF_Supp() == 2, "extortion flight dead after 30 s of __sys_SOS: wind-down");
	__sys_SOS = FALSE; __sys_Pirate_Money = nil; flight_pir_mon_1 = nil;
	h.cfg.sos_mode = nil;
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
	T_SceneSupp();
	T_Combat();
	T_CombatArm();
	T_Spot();
	T_Gov();
end;

-- Governor (5.2, carcass-count.md): the count at entry is the visit baseline (scenery), the rule applies to
-- the excess; the baseline is retaken after a reset and survives gen's load-pass live reset.
function T_Gov()
	local h = HOST();
	h.extra_carcass = 99;
	h.logs = {};
	T_Jump("gredos");
	local L = TRF.live;
	local n0 = L.gvn0;
	HOST_Check(type(n0) == "number" and n0 >= 100 and L.gvr == n0 and L.gvn == 0, "activate: baseline "..tostring(n0).." (>= 100), excess 0");
	HOST_Check(T_LogN("module=safety event=governor_base carcass_count="..n0.." radius=3000") == 1, "baseline logged");
	local ct0, cs0 = TRF_SafeCaps(0);
	local ct, cs = TRF_Governor();
	HOST_Check(ct == ct0 and cs == cs0 and not TRF_GovActive(), "baseline 100, no excess: caps unchanged ("..ct.."/"..cs..")");
	HOST_Check(T_LogN("module=safety event=governor excess_count=0 carcass_count="..n0.." radius=3000 trader_cap=") >= 1, "governor line shows excess/raw");
	h.extra_carcass = 99 + 41;
	ct, cs = TRF_Governor();
	HOST_Check(ct == max(1, ct0 - 1) and ct0 > 1 and cs <= 12 and TRF_GovActive() == 1 and L.gvn == 41,
		"excess 41: one trader fewer ("..ct0.."->"..ct.."), ships "..cs.." <= 12");
	HOST_Check(T_LogN("module=safety event=governor excess_count=41 carcass_count="..(n0 + 41).." radius=3000") == 1, "governor line n=41/"..(n0 + 41));
	HOST_Check(T_LogN("module=safety event=governor_base carcass_count=") == 1, "baseline logged once per visit");
	TRF_SafeVisitReset();
	ct, cs = TRF_Governor();
	HOST_Check(L.gvn0 == n0 + 41 and L.gvn == 0 and ct == ct0 and not TRF_GovActive(), "after a reset: baseline retaken ("..tostring(L.gvn0).."), caps back");
	HOST_Check(T_LogN("module=safety event=governor_base carcass_count=") == 2, "new baseline logged");
	-- Load: OnLoad takes the baseline, gen's load pass rebuilds live; the next governor run keeps it (H.gvn0).
	T_SaveLoad();
	local nb = T_LogN("module=safety event=governor_base carcass_count=");
	h.extra_carcass = 99 + 41 + 41;
	TRF.live.gv = nil;
	TRF_CanSpawn(0);
	HOST_Check(TRF.live.gvn0 == TRF_H().gvn0 and TRF.live.gvn == 41 and T_LogN("module=safety event=governor_base carcass_count=") == nb,
		"after load: baseline kept across the live reset, excess "..tostring(TRF.live.gvn));
	h.extra_carcass = nil; h.logs = nil;
	T_Jump("gredos");
	HOST_Check(TRF.live.gvn == 0 and not TRF_GovActive(), "next entry: new baseline, governor off");
end;

-- Spawn spot rule (R12, carcass-count.md): the native also counts the portal or station next to a spot
-- (stub cc_static 1), so a spot is busy only above its visit baseline; arrival spacing stays.
function T_Spot()
	local h = HOST();
	h.cc_ships = {};
	T_Jump("gredos");
	local T = TRF_GnT();
	local c, cv = __sys_LevelRegisteredContacts[1], TRF.live.cv[1];
	local key, pos = cv.pn[1], c[3][1]:GetEntryPoint(10);
	local b = TRF.live.base[key];
	HOST_Check(type(b) == "table" and getn(b) == 1 and b[1].n == 1, "activate: baseline 1 at portal "..key.." (static carcass)");
	local np = TRF_GnApproach(c, TRF_GnStation(), T);
	HOST_Check(np ~= nil and type(TRF.live.base.station) == "table" and TRF.live.base.station[1].n == 1, "activate: baseline 1 at the station approach point");
	TRF.live.port = {};
	h.logs = {};
	HOST_Check(TRF_GnFree(key, pos, T) == 1, "count 1, baseline 1: spot free");
	tinsert(h.cc_ships, pos);
	HOST_Check(TRF_GnFree(key, pos, T) == nil, "baseline 1 plus a ship: spot busy");
	HOST_Check(TRF_GnFree(key, pos, T) == nil, "still busy");
	local line = "module=generator event=spot spot="..key.." carcass_count=2 base_count=1 result=busy";
	HOST_Check(T_LogN(line) == 1, "refusal logged once per key per minute ("..T_LogN(line)..")");
	TRF.live.port[key] = TRF_GnGt();
	h.cc_ships = {};
	HOST_Check(TRF_GnFree(key, pos, T) == nil, "ship gone, inside the arrival spacing: busy");
	T_Tick(floor(T.spacing * 2) + 2, 0.5);
	HOST_Check(TRF_GnFree(key, pos, T) == 1, "after the spacing window, ship gone: free");
	tinsert(h.cc_ships, pos);
	T_Tick(80, 0.5);
	HOST_Check(TRF_GnFree(key, pos, T) == nil and T_LogN(line) == 2, "busy again a minute later: logged again");
	h.logs = nil;
	-- A ship parked at the spot at activation is part of the baseline for the visit (accepted).
	T_Jump("gredos");
	cv = TRF.live.cv[1];
	key = cv.pn[1];
	TRF.live.port = {};
	HOST_Check(TRF.live.base[key][1].n == 2 and TRF_GnFree(key, pos, T) == 1, "ship at the spot at activation: baseline 2, spot free");
	h.cc_ships = {};
	-- A spot first seen in TRF_Plan (convoy offset) takes its baseline on first use.
	local p2 = c[3][1]:GetEntryPoint(40);
	HOST_Check(TRF_GnFree(key, p2, T) == 1 and getn(TRF.live.base[key]) == 2, "new position: baseline on first use, free");
	local id = T_Spawn();
	HOST_Check(id ~= nil, "generator spawns with the static count");
end;

-- Scene-based suppression (R2): TRF_Quiet and the scene flag (movie, UI natives), spawning under __sys_SOS.
function T_SceneSupp()
	local h = HOST();
	print("HOST ---- scene-based suppression");
	HOST_Check(TRF_Quiet() == nil and TRF_Supp() == 0, "no flag, no scene: not quiet, level 0");
	__sys_SOS = TRUE;
	HOST_Check(TRF_Quiet() == 1, "__sys_SOS: quiet");
	h.logs = {};
	local said = TRF_Say("host quiet line", 5);
	HOST_Check(not said and getn(h.logs) == 1 and strfind(h.logs[1], "module=ui event=say result=skipped reason=quiet message=\"host quiet line\"", 1, 1), "__sys_SOS: TRF_Say skips (quiet)");
	h.logs = nil;
	__sys_SOS = FALSE;
	TRF_InMovie = HOST_InMovie; MovieIsPlaying = HOST_MovieIsPlaying; TRF_UiState = HOST_UiState;
	h.mov = 1; h.mip = FALSE; h.ui = 0;
	HOST_Check(TRF_Quiet() == 1 and TRF_Supp() == 1, "TRF_InMovie() == 1: quiet, pause");
	h.mov = 0; h.mip = TRUE;
	HOST_Check(TRF_Quiet() == nil and TRF_Supp() == 0, "TRF_InMovie() == 0 wins over MovieIsPlaying()");
	h.mov = -1;
	HOST_Check(TRF_Quiet() == 1 and TRF_Supp() == 1, "TRF_InMovie() == -1: MovieIsPlaying() == TRUE counts");
	TRF_InMovie = nil;
	HOST_Check(TRF_Quiet() == 1, "no TRF_InMovie: MovieIsPlaying() == TRUE counts");
	h.mip = FALSE; h.ui = 4;
	HOST_Check(TRF_Quiet() == 1 and TRF_Supp() == 1, "TRF_UiState() dialog flag: quiet, pause");
	h.ui = -1;
	HOST_Check(TRF_Quiet() == nil and TRF_Supp() == 0, "TRF_UiState() == -1 (unknown): ignored");
	h.ui = 2;
	__disableAction = TRUE;
	HOST_Check(TRF_Supp() == 2, "scene and __disableAction: wind-down");
	__disableAction = FALSE;
	h.logs = {};
	T_Tick(2, 0.5);
	local ln = 0;
	for i = 1, getn(h.logs) do if strfind(h.logs[i], "module=safety event=suppression old=0 new=1 disable_action=false sos=false scene=true sos_mode=1", 1, 1) then ln = ln + 1; end; end;
	HOST_Check(ln == 1 and not TRF_CanSpawn(0), "scene: supp 0->1 logged with scene=1, no spawn");
	h.logs = nil;
	TRF_UiState = nil; MovieIsPlaying = nil;
	h.mov = nil; h.mip = nil; h.ui = nil;
	T_Tick(2, 0.5);
	-- Spawn gate under __sys_SOS: sos_mode 1 spawns (generator and seed), sos_mode 2 skips the seed.
	T_Jump("gredos");
	__sys_SOS = TRUE;
	T_Tick(2, 0.5);
	local k0 = T_Stat("skip_seed_supp");
	local s0 = TRF.seq;
	h.rq = {0, 0};
	local sid = TRF_SeedSpawn();
	h.rq = {};
	HOST_Check(sid ~= nil and TRF.seq ~= s0 and TRF_Rec(sid) and TRF_Rec(sid).seed == 1 and T_Stat("skip_seed_supp") == k0,
		"__sys_SOS, sos_mode 1: seed spawns ("..tostring(sid).." "..TRF_Dump(TRF.live.stat, 1)..")");
	h.cfg.sos_mode = 2;
	sid = TRF_SeedSpawn();
	HOST_Check(sid == nil and T_Stat("skip_seed_supp") == k0 + 1, "__sys_SOS, sos_mode 2: seed skipped (skip_seed_supp)");
	h.cfg.sos_mode = nil;
	sid = T_Spawn();
	HOST_Check(TRF_Supp() == 0 and sid ~= nil, "__sys_SOS, sos_mode 1: the generator spawns a trader");
	__sys_SOS = FALSE;
end;

-- Mod log lines containing pat (plain find) since h.logs was set.
function T_LogN(pat)
	local n, q = 0, HOST().logs or {};
	for i = 1, getn(q) do if strfind(q[i], pat, 1, 1) then n = n + 1; end; end;
	return n;
end;

-- Combat state (design/mod-research/combat-state.md): hull sample, hit shims, raid source, cfg combat 0,
-- and the read sites (raid gate, hail on focus, attack response).
function T_Combat()
	local h = HOST();
	local ms = h.ms;
	print("HOST ---- combat state");
	T_Jump("gredos");
	T_Tick(2, 0.5);
	HOST_Check(TRF_Combat() == nil and TRF.live.cbh == 1000 and TRF.live.cbi == 1, "no hostile event: not in combat, hull sampled (1000, id 1)");
	-- Hull drop: combat for combat_hold (25 s), one line per transition.
	h.logs = {};
	ms.hp = ms.hp - 50;
	T_Tick(1, 0.5);
	HOST_Check(TRF_Combat() == 1 and TRF.live.cbw == "hp" and T_LogN("module=safety event=combat_on reason=hp") == 1, "hull drop 50: combat on (why hp)");
	ms.hp = ms.hp - 20;
	T_Tick(1, 0.5);
	HOST_Check(T_LogN("module=safety event=combat_on") == 1, "second drop while in combat: no second line");
	T_Tick(48, 0.5);
	HOST_Check(TRF_Combat() == 1 and T_LogN("module=safety event=combat_off") == 0, "24 s after the last drop: still in combat");
	T_Tick(4, 0.5);
	HOST_Check(TRF_Combat() == nil and T_LogN("module=safety event=combat_off") == 1, "26 s after the last drop: combat off, logged once");
	T_Tick(4, 0.5);
	HOST_Check(T_LogN("module=safety event=combat_off") == 1 and T_LogN("module=safety event=combat_on") == 1, "no further transition lines");
	-- A drop of half the hull or more in one sample (quest SetHP restore) is ignored; so is a gain.
	ms:SetHP(100000);
	T_Tick(1, 0.5);
	ms:SetHP(1000);
	T_Tick(1, 0.5);
	HOST_Check(TRF_Combat() == nil and TRF.live.cbh == 1000, "SetHP 100000 -> 1000 (>= 50 % in one sample): ignored");
	-- A drop within combat_scene (3 s) after a visible scene is ignored, a later one counts.
	TRF_InMovie = HOST_InMovie; h.mov = 1;
	T_Tick(1, 0.5);
	TRF_InMovie = nil; h.mov = nil;
	ms.hp = ms.hp - 50;
	T_Tick(2, 0.5);
	HOST_Check(TRF_Combat() == nil, "drop 1 s after a scene: ignored");
	T_Tick(6, 0.5);
	ms.hp = ms.hp - 50;
	T_Tick(1, 0.5);
	HOST_Check(TRF_Combat() == 1, "drop 4 s after the scene: combat");
	TRF.live.cbt = nil;
	-- Mothership swap (id change): no comparison across it.
	ms.id = 2; ms.hp = ms.hp - 50;
	T_Tick(1, 0.5);
	HOST_Check(TRF_Combat() == nil and TRF.live.cbi == 2, "mothership id change: drop ignored");
	ms.id = 1; ms.hp = 1000;
	T_Tick(1, 0.5);
	-- Hit shims through TRF_Cb mark combat; other callbacks do not. Hits count once seen in combat_hit_n (2)
	-- distinct seconds within combat_hit_win (6 s); a stale gen never counts.
	local nop = function() end;
	h.cfg.log = 2;
	TRF_Cb("TRF_SwDied", nop, {1, 1, TRF.gen});
	HOST_Check(TRF_Combat() == nil, "TRF_Cb TRF_SwDied: no combat");
	TRF_Cb("TRF_OnRaidHit", nop, {1, 1, TRF.gen - 1});
	TRF_Cb("TRF_OnRaidHit", nop, {1, 1, TRF.gen - 1});
	T_Tick(2, 0.5);
	TRF_Cb("TRF_OnRaidHit", nop, {1, 1, TRF.gen - 1});
	HOST_Check(TRF_Combat() == nil and TRF.live.cbk == nil and T_LogN("event=combat_hit_pending") == 0, "stale gen hits in two seconds: no combat, not counted");
	TRF_Cb("TRF_OnRaidHit", nop, {1, 1, TRF.gen});
	HOST_Check(TRF_Combat() == nil and T_LogN("module=safety event=combat_hit_pending hit_count=1 hits_needed=2") == 1, "one hit: no combat, pending line");
	TRF_Cb("TRF_OnRaidHit", nop, {1, 1, TRF.gen});
	HOST_Check(TRF_Combat() == nil and T_LogN("event=combat_hit_pending") == 1, "second hit in the same second: no combat, no second line");
	T_Tick(14, 0.5);
	TRF_Cb("TRF_OnAttack", nop, {7, 1, TRF.gen});
	HOST_Check(TRF_Combat() == nil and T_LogN("event=combat_hit_pending") == 2, "hit 7 s after the last one: no combat, new window line");
	T_Tick(2, 0.5);
	TRF_Cb("TRF_OnRaidHit", nop, {1, 1, TRF.gen});
	HOST_Check(TRF_Combat() == 1 and TRF.live.cbw == "hit" and T_LogN("module=safety event=combat_on reason=hit source=TRF_OnRaidHit") == 1, "hits in two distinct seconds within 6 s: combat (why hit)");
	h.cfg.log = nil;
	-- Raid gate: closed while in combat, open after the hold; __sys_SOS alone keeps it open.
	local idx = TRF_CurIdx();
	local ok, why = TRF_Rd_Gate(idx, "raid");
	HOST_Check(not ok and why == "combat", "raid gate in combat: combat ("..tostring(why)..")");
	-- Hail on focus: skipped in combat (reason combat).
	local id = T_Spawn();
	local hr, hw = TRF_HailOpen(id, "test");
	HOST_Check(id and hr == nil and hw == "combat" and T_LogN("module=hail event=hail trader_id="..tostring(id).." via=test result=skipped reason=combat") == 1, "hail in combat: skipped (combat)");
	-- Attack response: starts in combat (vanilla parity) and under __sys_SOS.
	__sys_SOS = TRUE;
	TRF_RespStart(id);
	__sys_SOS = FALSE;
	HOST_Check(TRF_Rec(id) and TRF_Rec(id).resp == 1, "attack response starts in combat and under __sys_SOS");
	T_Tick(54, 0.5);
	HOST_Check(TRF_Combat() == nil, "27 s later: combat off");
	ok, why = TRF_Rd_Gate(idx, "raid");
	HOST_Check(ok == 1, "raid gate after the hold: open ("..tostring(why)..")");
	__sys_SOS = TRUE;
	ok, why = TRF_Rd_Gate(idx, "raid");
	__sys_SOS = FALSE;
	HOST_Check(ok == 1, "raid gate under __sys_SOS alone: open ("..tostring(why)..")");
	-- Raid in fight: combat within combat_r (1500) of the mothership, not beyond.
	local ship = {__obj=1, pos=Vector3(ms.pos.x + 1000, ms.pos.y, ms.pos.z)};
	ship.IsAlive = function(self) return 1; end;
	ship.GetPosition = function(self) return self.pos; end;
	TRF.live.rd[9] = {n=9, st="fight"};
	TRF_H().rd[9] = {sh={ship}, dk={}};
	TRF_CombatSample(nil);
	HOST_Check(TRF_Combat() == 1 and TRF.live.cbw == "raid", "raid in fight 1000 from the mothership: combat (why raid)");
	TRF.live.cbt = nil;
	ship.pos = Vector3(ms.pos.x + 2000, ms.pos.y, ms.pos.z);
	TRF_CombatSample(nil);
	HOST_Check(TRF_Combat() == nil, "raid in fight 2000 from the mothership: no combat");
	TRF.live.rd[9].st = "come";
	ship.pos = Vector3(ms.pos.x + 100, ms.pos.y, ms.pos.z);
	TRF_CombatSample(nil);
	HOST_Check(TRF_Combat() == nil, "raid in st come: no combat");
	TRF.live.rd[9] = nil; TRF_H().rd[9] = nil;
	-- cfg combat 0: never in combat.
	h.cfg.combat = 0;
	TRF_CombatMark("hit", "test");
	ms.hp = ms.hp - 50;
	T_Tick(1, 0.5);
	HOST_Check(TRF_Combat() == nil and TRF.live.cbt == nil, "cfg combat 0: TRF_Combat nil, nothing marked");
	h.cfg.combat = nil;
	ms.hp = 1000;
	T_Tick(1, 0.5);
	h.logs = nil;
end;

-- Tick object reads wait for the armed visit (design/mod-research/crash-load-5adc5e.md): no GetCurHP on the
-- mothership between entry and activate.script, none from GetPlayerMotherShip in the safety tick at all,
-- armed again by the load callback, and a failing GetCurHP stays inside the sample.
function T_CombatArm()
	local h = HOST();
	print("HOST ---- combat arm");
	h.n_hp = 0; h.n_gpm = 0;
	local ghp, gpm = GetCurHP, GetPlayerMotherShip;
	GetCurHP = function(o) if o == HOST().ms then HOST().n_hp = HOST().n_hp + 1; end; return %ghp(o); end;
	GetPlayerMotherShip = function() HOST().n_gpm = HOST().n_gpm + 1; return %gpm(); end;
	-- Entry without activate.script yet (T_Enter up to TRF_OnEnter).
	TeleportToLocation("gredos");
	h.last = h.loc; h.loc = "gredos";
	h.triggers = {}; h.ships = {}; h.screen = {}; h.msgs = {};
	HOST_MapInit();
	T_Scene("gredos");
	TRF_OnEnter();
	T_Tick(4, 0.5);
	HOST_Check(h.n_hp == 0 and TRF_SafeArmed() == nil and TRF.live.cbh == nil, "tick before OnActivate: no GetCurHP on the mothership, not armed");
	TRF_OnActivate();
	HOST_Check(TRF_SafeArmed() == 1 and TRF_H().sms == h.ms, "OnActivate arms the visit with the mothership handle");
	h.n_hp = 0; h.n_gpm = 0;
	TRF_Safety_Tick();
	HOST_Check(h.n_hp == 1 and h.n_gpm == 0 and TRF.live.cbh == h.ms.hp, "armed safety tick: one GetCurHP, no GetPlayerMotherShip");
	-- The vanilla global mothership wins over the cached handle (quest swap: mothership = SetPlayerMotherShip(..)).
	local sw = {__obj=1, hp=500, id=7};
	sw.IsAlive = function(self) return 1; end;
	mothership = sw;
	TRF_Safety_Tick();
	HOST_Check(TRF.live.cbi == 7 and TRF.live.cbh == 500, "live global mothership is sampled first");
	mothership = nil;
	TRF_Safety_Tick();
	HOST_Check(TRF.live.cbi == 1, "dead or missing global mothership: cached handle");
	-- A GetCurHP error stays inside the sample (handler TRF_SafePErr, no hull value, the tick goes on).
	local ok, pe = GetCurHP, TRF_PErr;
	GetCurHP = function(o) error("host GetCurHP failure"); end;
	h.pe = {};
	TRF_PErr = function(m) tinsert(HOST().pe, m); end;
	TRF_Safety_Tick();
	GetCurHP = ok; TRF_PErr = pe;
	HOST_Check(TRF.live.cbh == nil and getn(h.pe) == 1 and strfind(h.pe[1], "host GetCurHP failure", 1, 1), "GetCurHP error: caught by the sample, one handler call, no hull value");
	h.pe = nil;
	-- Load: the reset clears the arming, TRF_Safety_OnLoad arms again.
	TRF_SafeVisitReset();
	HOST_Check(TRF_SafeArmed() == nil and TRF_H().sms == nil, "visit reset clears the arming");
	T_SaveLoad();
	HOST_Check(TRF_SafeArmed() == 1, "OnLoad arms the visit");
	h.n_hp = 0;
	T_Tick(2, 0.5);
	HOST_Check(h.n_hp >= 1 and TRF.live.cbh == h.ms.hp, "tick after load: hull sampled");
	GetCurHP = ghp; GetPlayerMotherShip = gpm;
end;

-- f, load pass adoption (spec 5.5; design/mod-research/crash-load-432500.md 8): traders whose ships answer
-- the label lookup at OnLoad are adopted, ships that answer IsAlive only after OnLoad are adopted by the
-- retry, a record without ships is stripped, labels that never give a live ship (IsAlive nil, or a value
-- that is not an object) are dropped after load_wait (10 s), the parked ship found late is kept.
function T_LateAlive(self)
	if HOST().late then return nil; end;
	if self.alive then return 1; end;
	return nil;
end;
function T_NeverAlive(self) return nil; end;
function T_LogN(pat)
	local n = 0;
	local q = HOST().logs or {};
	for i = 1, getn(q) do if strfind(q[i], pat, 1, 1) then n = n + 1; end; end;
	return n;
end;
function T_LabelShip(label, x, z, grp)
	local s = CreateCarcass("Btransport", Vector3(x, 0, z), Vector3(0, 0, 1));
	s:AssignPilot(CreatePilot("Trader"));
	HOST_Group(grp, "Trade"):CreateFlight(label):AddShip(s);
	SetObjectLabel(s, label);
	return s;
end;

function T_LoadAdopt()
	local h = HOST();
	print("HOST ---- load adopt");
	-- A new scene: no labelled ship of the earlier steps is left.
	T_Enter("gredos");
	T_Tick(20, 0.5);
	local ms = h.ms.pos;
	TRF.std.heat = 0;
	local ids = {T_Spawn()};
	HOST_Check(ids[1], "a trader before the save");
	if not ids[1] then return; end;
	T_MoveTr(ids[1], ms.x + 60, 0, ms.z + 40);
	local fl1 = TRF_H().tr[ids[1]].fl;
	-- Records w (two labelled ships, no spawn), v (ship answers IsAlive only after OnLoad), x (ship never
	-- answers IsAlive), y (no ship), z (label answers with a non-object).
	local v, w, x, y, z = TRF.seq + 99, TRF.seq + 100, TRF.seq + 101, TRF.seq + 102, TRF.seq + 103;
	ids[2] = v;
	foreachi({v, w, x, y, z}, function(i, id)
		TRF.live.tr[id] = {id=id, st="out", path="C", nm=0, cls=6, from=-1, to=-1, k=0, np=1, nt=2, esc=0, born=TRF.clock.gt, wd=0};
	end);
	local ws = T_LabelShip("trf_"..w.."_1", ms.x - 60, ms.z - 40, "TRF_Trade_W");
	local ws2 = CreateCarcass("Btransport", Vector3(ms.x - 60, 0, ms.z - 20), Vector3(0, 0, 1));
	ws2:AssignPilot(CreatePilot("Trader"));
	ws.flight:AddShip(ws2);
	SetObjectLabel(ws2, "trf_"..w.."_2");
	local vs = T_LabelShip("trf_"..v.."_1", ms.x + 120, ms.z + 40, "TRF_Trade_V");
	vs.IsAlive = T_LateAlive;
	local xs = T_LabelShip("trf_"..x.."_1", ms.x - 60, ms.z + 60, "TRF_Trade_Y");
	xs.IsAlive = T_NeverAlive;
	local ps = T_LabelShip("trf_pk_1", ms.x - 80, ms.z - 80, "TRF_Park");
	ps.IsAlive = T_LateAlive;
	h.zl = "trf_"..z.."_1";
	h.logs = {};
	T_SaveLoad(function()
		HOST().late = 1;
		HOST().gobl = GetObjectByLabel;
		GetObjectByLabel = function(l) if l == HOST().zl then return l; end; return HOST().gobl(l); end;
	end);
	local L, H = TRF.live, TRF_H();
	HOST_Check(L.tr[ids[1]] and L.tr[ids[1]].st == "wind" and L.tr[w] and L.tr[w].st == "wind" and H.tr[ids[1]].fl == fl1
		and H.tr[w].fl == ws.flight and getn(H.tr[w].sh) == 2 and H.tr[w].sh[2] == ws2 and L.tr[w].np == 2
		and H.tr[ids[1]].sh[1].cp ~= nil and HOST_Count("f_object_inside", "TRF_OnExit("..ids[1]..","..TRF.gen..")--") == 1,
		"load pass: found traders adopted (flight from the ship, wind-down with a new-gen exit trigger)");
	HOST_Check(L.grp[TRF.live.tr[ids[1]].k] == ids[1], "load pass: group slot of an adopted trader stays taken");
	HOST_Check(L.tr[ids[2]] == nil and type(L.lw) == "table" and L.lw.rec[ids[2]] and L.lw.rec[x] and L.lw.rec[z] and L.lw.rec[y] == nil
		and L.tr[y] == nil, "load pass: labels found but not alive wait, a record without ships is stripped");
	HOST_Check(T_LogN("event=load_pass ") == 1 and T_LogN(" adopted_count=2 wait_count=3 ") == 1 and T_LogN("module=generator event=load trader_id="..y.." result=gone reason=label") == 1
		and T_LogN("module=generator event=load trader_id="..x.." result=wait reason=alive label_count=1") == 1 and T_LogN("module=generator event=load trader_id="..z.." result=wait reason=obj label_count=1") == 1,
		"load pass log: adopted=2 wait=3, reasons label, alive and obj");
	HOST_Check(T_LogN("module=state event=dump source=load ") == 1 and T_LogN(" trader_count=2 ") == 1, "dump load: tr=2 before the retry");
	HOST_Check(TRF_ParkedN() == 0 and type(L.pkw) == "table" and getn(L.pkw.j) == 1, "parked ship found but not alive: waits");
	-- Objects answer alive from the first tick: the retry adopts the late trader and the parked ship.
	h.late = nil;
	T_Tick(1, 0.5);
	HOST_Check(TRF_Rec(ids[2]) and L.tr[ids[2]].st == "wind" and H.tr[ids[2]] and H.tr[ids[2]].sh[1].cp ~= nil
		and HOST_Count("f_object_inside", "TRF_OnExit("..ids[2]..","..TRF.gen..")--") == 1 and T_LogN("event=load_retry try_count=1 adopted_count=1 dropped_count=0 wait_count=2") == 1,
		"load retry: late trader adopted on the first tick");
	HOST_Check(TRF_ParkedN() == 1 and H.pk[1] and H.pk[1].sh == ps and L.pkw == nil and HOST_Count("died", "TRF_ParkDied(1,"..TRF.gen..")--") == 1,
		"load retry: parked ship kept with a new handle and a died trigger of the new gen");
	T_Tick(24, 0.5);
	HOST_Check(L.lw == nil and T_LogN("module=generator event=load trader_id="..x.." result=gone reason=alive try_count=") == 1 and T_LogN("module=generator event=load trader_id="..z.." result=gone reason=obj try_count=") == 1
		and L.tr[x] == nil and L.tr[z] == nil, "load retry: labels never alive dropped after load_wait with their reason");
	TRF_DumpState("adopt");
	HOST_Check(T_LogN("module=state event=dump source=adopt ") == 1 and T_LogN(" trader_count=3 ") >= 1, "dump after the retry: tr=3");
	GetObjectByLabel = h.gobl;
	h.gobl = nil; h.zl = nil; h.logs = nil;
end;

-- f, load pass through the handle globals (v01 3.3; design/mod-research/crash-load-432500.md 10). After a
-- load the game's GetObjectByLabel returns the label string for mod ships (emulated here for trf_<a|b>_*).
-- Trader a: its ship_ globals come back with the save and it is adopted through them (via=global, no label
-- probe). Record w: no globals (a save made before them), adopted by label (via=label), and its handles are
-- kept for the next save. Trader b: globals whose ships never answer IsAlive wait, then are dropped after
-- load_wait together with their globals. A closed record leaves no handle global.
function T_LoadHandles()
	local h = HOST();
	print("HOST ---- load handles");
	T_Enter("gredos");
	T_Tick(20, 0.5);
	local ms = h.ms.pos;
	TRF.std.heat = 0;
	local a = T_Spawn();
	local b = T_Spawn();
	HOST_Check(a and b, "two traders before the save");
	if not a or not b then return; end;
	T_MoveTr(a, ms.x + 60, 0, ms.z + 40);
	T_MoveTr(b, ms.x + 90, 0, ms.z - 40);
	local Ha, Hb = TRF_H().tr[a], TRF_H().tr[b];
	local na, nb = getn(Ha.sh), getn(Hb.sh);
	local kept = 1;
	for i = 1, na do
		local g = getglobal("TRF_ship_trf_"..a.."_"..i) or getglobal("ship_trf_"..a.."_"..i);
		if g ~= Ha.sh[i] then kept = nil; end;
	end;
	HOST_Check(kept and getglobal("ship_trf_"..a.."_1") == Ha.sh[1] and getglobal("flight_trf_"..a) == Ha.fl,
		"spawn: NewAllFlight's ship_/flight_ globals and TRF_ship_ for the rest kept for the save");
	local w = TRF.seq + 200;
	TRF.live.tr[w] = {id=w, st="out", path="C", nm=0, cls=6, from=-1, to=-1, k=0, np=1, nt=1, esc=0, born=TRF.clock.gt, wd=0};
	local ws = T_LabelShip("trf_"..w.."_1", ms.x - 60, ms.z - 40, "TRF_Trade_HW");
	h.lgp = {"trf_"..a.."_", "trf_"..b.."_"};
	h.lgn = 0;
	h.logs = {};
	T_SaveLoad(function()
		HOST().gobl = GetObjectByLabel;
		GetObjectByLabel = function(l)
			local q = HOST().lgp;
			for i = 1, getn(q) do
				if strsub(l, 1, strlen(q[i])) == q[i] then
					HOST().lgn = HOST().lgn + 1;
					if HOST().gobl(l) then return l; end;
					return nil;
				end;
			end;
			return HOST().gobl(l);
		end;
		for i = 1, getn(%Hb.sh) do %Hb.sh[i].IsAlive = T_NeverAlive; end;
	end);
	local L, H = TRF.live, TRF_H();
	HOST_Check(L.tr[a] and L.tr[a].st == "wind" and H.tr[a].fl == Ha.fl and getn(H.tr[a].sh) == na and H.tr[a].sh[1] == Ha.sh[1]
		and T_LogN("event=load trader_id="..a.." result=adopted ship_count="..na.." via=global escort_flight=false state=wind") == 1 and h.lgn == 0,
		"load pass: trader adopted through its saved ship_ globals (via=global), no label probe");
	HOST_Check(L.tr[w] and L.tr[w].st == "wind" and H.tr[w].sh[1] == ws and T_LogN("event=load trader_id="..w.." result=adopted ship_count=1 via=label escort_flight=false state=wind") == 1
		and getglobal("TRF_ship_trf_"..w.."_1") == ws, "load pass: record without globals adopted by label (via=label), its handle kept for the next save");
	HOST_Check(L.tr[b] == nil and type(L.lw) == "table" and L.lw.rec[b] and T_LogN("event=load trader_id="..b.." result=wait reason=alive label_count=0 global_count="..nb.." via=global") == 1
		and T_LogN(" adopted_count=2 wait_count=1 ") == 1, "load pass: globals of ships that do not answer IsAlive wait (via=global)");
	T_Tick(24, 0.5);
	HOST_Check(L.lw == nil and L.tr[b] == nil and T_LogN("event=load trader_id="..b.." result=gone reason=alive try_count=") == 1 and T_SignGlobals(b) == "",
		"load retry: dead handles dropped after load_wait with their globals"..T_SignGlobals(b));
	HOST_Check(T_SignGlobals(a) ~= "", "adopted trader keeps its globals while open");
	TRF_Remove(a, "test");
	HOST_Check(T_SignGlobals(a) == "", "record closed: its handle globals cleared"..T_SignGlobals(a));
	GetObjectByLabel = h.gobl;
	h.gobl = nil; h.lgp = nil; h.lgn = nil; h.logs = nil;
end;

local fn = getglobal("T_"..strupper(HOST().scen));
if strsub(HOST().scen, 1, 4) == "v02-" or strsub(HOST().scen, 1, 3) == "v1-" then
	-- host_v02.lua or host_v1.lua (loaded next by host_stubs.lua) runs the scenario with these helpers.
elseif type(fn) == "function" then
	fn();
	HOST_Check(T_LeftGlobals() == "", "no handle globals left at the end"..T_LeftGlobals());
else
	HOST_Check(nil, "unknown scenario "..tostring(HOST().scen));
end;
