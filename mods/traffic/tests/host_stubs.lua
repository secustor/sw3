-- Host harness for the traffic mod scripts under stock Lua 4.0.1 (no game, no DLL).
-- Emulates the engine parts the loader depends on: ExecuteScriptFile, ClearGlobals with the T3 carry,
-- the save writer's skip rule, string trigger callbacks (s.."();"), the vanilla includes the v0.1 modules
-- wrap or call (generator action, Case_Eject, NewAllFlight, CreateChoiceFlight, builder tables) and the
-- natives as stubs that check the argument shapes the game scripts use (HOST_Want).
-- Env: TRF_DIR (mod script dir, trailing slash), TRF_EXP (0..3; unset = use the repo config.script),
-- TRF_BIG, TRF_DEL, TRF_AUTOSAVE (config big / del_on_jump / autosave), TRF_SCEN (unset: loader scenario
-- below; a..g: traffic scenario of host_traffic.lua; v02-a..n: v0.2 scenario of host_v02.lua; both found
-- through TRF_TESTS; v1-a..n: v1 scenario of host_v1.lua, loaded after both). Exit code 1 on any script error,
-- mod-log ERROR line or failed check.

-- Host state lives in an upvalue: emulated ClearGlobals deletes table globals.
local H = {
	dir = getenv("TRF_DIR") or "./",
	tests = getenv("TRF_TESTS") or "./",
	scen = getenv("TRF_SCEN"),
	exp = tonumber(getenv("TRF_EXP") or ""),
	big = tonumber(getenv("TRF_BIG") or "0"),
	del = tonumber(getenv("TRF_DEL") or "0"),
	autosave = tonumber(getenv("TRF_AUTOSAVE") or "0"),
	labels = {}, autosaves = {},
	errors = 0, fails = 0, gt = 0, rt = 0,
	loc = "gredos", last = "aurora",
	triggers = {}, ships = {}, nflight = 0,
	protected = {}, objs = {},
	-- v0.1 stubs: RAND state and draw count, forced draws, screen lines, radio lines, vanilla generator
	-- calls, glows, choice flights, meetings, ejections, quest state, difficulty, block radius, config.
	seed = 12345, rand = 0, rq = {}, screen = {}, msgs = {}, vgen = {}, van_built = 0,
	glows = 0, choice = 0, meet = 0, eject = 0, qs = 0, diff = 1, block_r = 3, cfg = nil,
	-- v0.2 stubs: message boxes (and boxes opened inside a box callback), markets and their writes, shops
	-- created, UpdateTradeSystem flags, dialogs, nav points, credits, player level, news posts, relations,
	-- team per location, vanilla dock originals run.
	boxes = {}, in_box = nil, box_nested = 0, markets = {}, mwrites = {}, shops_made = {}, upd = {}, dlgs = {},
	pdlgs = {}, navs = {}, credits = 0, level = 4, posts = {}, rel = {}, teams = {}, trade_ok = 0, patrol_ok = 0,
	ftrader = 0, speak = 0,
	-- v1 stubs: quest states by id, stations made, docks of CreatePirateStationDocking, groups by name, vanilla
	-- relation and pirate dock originals run, modules added (AddModule), mothership inventory.
	quests = {}, stations = {}, pdocks = {}, groups = {}, cst = {}, pir_ok = 0, mods = {},
	-- hail dialog stubs: StartTradeDialog calls {d, init}, the mod dialog loaded (HOST().dlg), answer calls.
	tdlgs = {}, dlg = nil, dlg_calls = {}
};

function HOST() return %H; end;

function HOST_Check(c, msg)
	if c then print("HOST ok   "..msg); else HOST().fails = HOST().fails + 1; print("HOST FAIL "..msg); end;
end;

-- Like HOST_Check, silent when it passes (argument checks in the stubs).
function HOST_Want(c, msg)
	if not c then HOST_Check(c, msg); end;
end;

_ERRORMESSAGE = function(m) HOST().errors = HOST().errors + 1; print("HOST SCRIPT ERROR: "..tostring(m)); end;
_ALERT = _ERRORMESSAGE;

-- Engine globals and constants ----------------------------------------------------
TRUE = 1; FALSE = 0;
PLAYER_TEAM = "PlayerTeam"; PLAYER_GROUP = "PlayerGroup"; PLAYER_MOTHERSHIP = "PlayerMothership";
_script_path = "DATA/Scripts/";
_CLASS = {};
PI = 3.1415926535897932;
-- Engine values (mod-research/lua-natives.md, constants).
EASY = 0; NORMAL = 1; HARD = 2; NOINIT = 0;
_EVENT_TIMER = 1; ROLE_ATTACK = 2; ROLE_DEFEND = 3; ROLE_MISSLEDEFENCE = 6; ROLE_REPAIR = 7; ROLE_CLOACKING = 5;
RELATION_NEUTRAL = 0; RELATION_WAR = 1; RELATION_FRIEND = 2;
QUEST_DONE = 0; QUEST_FAILED = 1; QUEST_PROCESS = 2; QUEST_NOINIT = 3;
HOST().qs = FALSE;

-- 0x7acae8 list plus the engine-constant names used here.
function HOST_IsProtected(k)
	if type(k) ~= "string" then return nil; end;
	if HOST().protected[k] then return 1; end;
	if strfind(k, "^_EVENT_") or strfind(k, "^ROLE_") or strfind(k, "^RELATION_") or strfind(k, "^QUEST_") or strfind(k, "^MISSION_") then return 1; end;
	return nil;
end;
foreachi({"_CLASS", "PI", "_VERSION", "_INPUT", "_OUTPUT", "_STDERR", "_STDIN", "_STDOUT",
	"_script_error_output", "sys_IncludeFileList", "_script_path", "_script_error_filename",
	"TRUE", "FALSE", "PLAYER_TEAM", "PLAYER_GROUP", "PLAYER_MOTHERSHIP", "EASY", "NORMAL", "HARD", "NOINIT"},
	function(i, k) HOST().protected[k] = 1; end);

-- Natives -------------------------------------------------------------------------
function LOG(s) print("LOG: "..tostring(s)); end;
function SLOG(s) print("SLOG: "..tostring(s)); end;

function TRF_Version() return 1; end;
function TRF_GameTime() return HOST().gt; end;
function TRF_RealTime() return HOST().rt; end;
-- Movie and UI reads (traffic.c TRF_InMovie / TRF_UiState, game MovieIsPlaying): undefined by default; the
-- save kit's cutscene-guard block installs these, driven by HOST().mov, HOST().ui and HOST().mip.
function HOST_InMovie() return HOST().mov; end;
function HOST_UiState() return HOST().ui; end;
function HOST_MovieIsPlaying() return HOST().mip; end;
-- Object list (traffic.c TRF_Carcasses): undefined by default, so every run stays on the count path; a
-- scenario sets TRF_Carcasses = HOST_Carcasses. HOST().carc is the record list of the location, HOST().carc_why
-- makes the native answer nil, why ("off", "sig", ...). With a sphere (four numbers) only records with a
-- position within r, as the native; calls counted in HOST().carc_n.
function HOST_Carcasses(...)
	local h = HOST();
	h.carc_n = (h.carc_n or 0) + 1;
	HOST_Want(arg.n == 0 or (arg.n == 4 and type(arg[1]) == "number" and type(arg[2]) == "number"
		and type(arg[3]) == "number" and type(arg[4]) == "number"), "TRF_Carcasses() or TRF_Carcasses(cx, cy, cz, r)");
	if h.carc_why then return nil, h.carc_why; end;
	local out = {};
	for i = 1, getn(h.carc or {}) do
		local c = h.carc[i];
		if arg.n == 0 then tinsert(out, c);
		elseif type(c.x) == "number" and HOST_Dist(c, Vector3(arg[1], arg[2], arg[3])) <= arg[4] then tinsert(out, c); end;
	end;
	return out;
end;
-- An " ERROR " or " event=error " line (TRF_Err, TRF_CbErr, TRF_GnErr: a mod error caught by a protected call)
-- counts as a script error.
function TRF_Log(s)
	if type(s) ~= "string" and type(s) ~= "number" then print("traffic: TRF_Log bad argument"); return nil; end;
	print("traffic: lua: "..s);
	if HOST().logs then tinsert(HOST().logs, s); end;
	if type(s) == "string" and (strfind(s, " ERROR ", 1, 1) or strfind(s, " event=error ", 1, 1)) then
		HOST().errors = HOST().errors + 1;
		print("HOST SCRIPT ERROR (mod log): "..s);
		HOST_Trace();
	end;
end;

-- Call stack at an error (the handler of call(..., "x", h) runs at the error point): one line per frame.
function HOST_Trace()
	local s = "";
	for l = 3, 14 do
		local i = getinfo(l, "Sln");
		if not i then break; end;
		local src = i.short_src or i.source or "?";
		s = s.." < "..gsub(tostring(src), "^.*/", "")..":"..tostring(i.currentline).." "..tostring(i.name);
	end;
	print("HOST trace:"..s);
end;

function GetCurrentLocation() return HOST().loc; end;

-- 0x5e6ff0: exactly one string argument ("invalid params!" otherwise). Records the save text.
function AutoSave(...)
	HOST_Want(arg.n == 1 and type(arg[1]) == "string", "AutoSave(text)");
	print("HOST AutoSave "..tostring(arg[1]));
	tinsert(HOST().autosaves, arg[1]);
end;
-- Quest labels: nil for a label that was never set.
function GetQuestLabel(k) return HOST().labels[k]; end;
function GetLastLocation() return HOST().last; end;
-- No argument, as OutOfMission.script 386 calls it; TRUE while a story mission runs (host: HOST().qs).
function GetPlayerQuestState(...)
	HOST_Want(arg.n == 0, "GetPlayerQuestState()");
	return HOST().qs;
end;
function GetLevelDifficult() return HOST().diff; end;
-- Owner team; HOST().teams[loc] overrides the default "Neutral".
function GetLocationTeam(loc)
	HOST_Want(type(loc) == "string", "GetLocationTeam(location)");
	return HOST().teams[loc] or "Neutral";
end;

-- RAND(n): 0..n-1 (Park-Miller, exact in doubles; high-order part, the low bits of successive draws
-- correlate). HOST().rq holds forced draws (taken first, mod n).
function RAND(n)
	local h = HOST();
	HOST_Want(type(n) == "number" and n >= 1, "RAND(n >= 1)");
	h.rand = h.rand + 1;
	if getn(h.rq) > 0 then return mod(tremove(h.rq, 1), n); end;
	h.seed = mod(h.seed * 16807, 2147483647);
	return floor(h.seed * n / 2147483647);
end;

function OutputToScreenLog(text, secs)
	HOST_Want(type(text) == "string" and type(secs) == "number", "OutputToScreenLog(text, secs)");
	print("HOST screen: "..tostring(text));
	tinsert(HOST().screen, {t=text, gt=HOST().gt});
end;

function HOST_TeleportToLocation(...)
	print("HOST TeleportToLocation n="..arg.n.." dest="..tostring(arg[1]));
	HOST().jumped = arg[1];
end;
function HOST_CustomTeleportate(...)
	print("HOST CustomTeleportate n="..arg.n.." from="..tostring(arg[1]).." to="..tostring(arg[2]).." fx="..tostring(arg[3]));
	HOST().jumped = arg[2];
end;
TeleportToLocation = HOST_TeleportToLocation;
CustomTeleportate = HOST_CustomTeleportate;

-- Vector3 with the "+" the vanilla builder uses (Create_flight_2.script: Vector3(0,0,d) + location).
HOST().vtag = newtag();
function Vector3(x, y, z)
	local v = {x=x or 0, y=y or 0, z=z or 0};
	settag(v, HOST().vtag);
	return v;
end;
settagmethod(HOST().vtag, "add", function(a, b) return Vector3(a.x + b.x, a.y + b.y, a.z + b.z); end);

function HOST_Dist(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z;
	return sqrt(dx*dx + dy*dy + dz*dz);
end;

-- Map objects: portals and the trade station of the emulated system.
function HOST_Obj(label, x, y, z)
	local o = {__obj=1, kind="obj", label=label, pos=Vector3(x, y, z), alive=1};
	o.GetPosition = function(self) return Vector3(self.pos.x, self.pos.y, self.pos.z); end;
	o.GetOrientation = function(self) return Vector3(0, 0, 1); end;
	o.GetEntryPoint = function(self, d)
		HOST_Want(type(d) == "number", "Portal:GetEntryPoint(distance)");
		return Vector3(self.pos.x, self.pos.y, self.pos.z + d);
	end;
	o.GetDockingPosition = function(self) return Vector3(self.pos.x + 40, self.pos.y, self.pos.z); end;
	o.IsAlive = function(self) if self.alive then return 1; end; return nil; end;
	o.Start = function(self, a, b)
		HOST_Want(type(a) == "number" and type(b) == "number", "Portal:Start(n, m)");
		print("HOST Portal:Start "..self.label.." "..tostring(a)..","..tostring(b));
	end;
	return o;
end;
HOST().objs["PORTAL L"] = HOST_Obj("PORTAL L", -1000, 0, 700);
HOST().objs["PORTAL D"] = HOST_Obj("PORTAL D", 200, 0, -900);
HOST().objs["TRADE STATION"] = HOST_Obj("TRADE STATION", 50, -30, -150);
function GetObjectByLabel(l)
	HOST_Want(type(l) == "string", "GetObjectByLabel(label)");
	return HOST().objs[l];
end;
function SetObjectLabel(o, l)
	HOST_Want(type(o) == "table" and o.__obj and type(l) == "string", "SetObjectLabel(object, label)");
	o.label = l;
	HOST().objs[l] = o;
end;
-- GetObjectLabel 0x5dd9c0 (never called by vanilla): the class tag is checked on argument 2 and the id read
-- from argument 1, so the mod calls (o, o); without an object as argument 2 it returns that argument.
-- Label string, or nil for a dead or unlabelled object.
function GetObjectLabel(o, c)
	if not HOST_IsObj(c) then return c; end;
	if not HOST_IsObj(o) or not o.alive then return nil; end;
	return o.label;
end;

-- Argument shapes as the game scripts pass them (include/NewTriggers.script, Create_flight_2.script).
function HOST_IsVec(v) return type(v) == "table" and type(v.x) == "number" and type(v.y) == "number" and type(v.z) == "number"; end;
function HOST_IsFlight(v) return type(v) == "table" and v.AddShip ~= nil; end;
function HOST_IsObj(v) return type(v) == "table" and v.__obj ~= nil and v.GetPosition ~= nil; end;
function HOST_IsShip(v) return type(v) == "table" and v.kind == "ship"; end;
function HOST_IsGroup(v) return type(v) == "table" and v.kind == "group"; end;

function HOST_Pilot(tpl)
	local p = {__obj=1, kind="pilot", tpl=tpl};
	p.GetShip = function(self) return self.ship; end;
	p.GetFlight = function(self) if self.ship then return self.ship.flight; end; return nil; end;
	-- Team name of the pilot's group ("Trade" when unknown). CHECK in the game: "Pirates" for pirates.
	p.GetSide = function(self)
		local f = self:GetFlight();
		if f and f.group and f.group.team then return f.group.team; end;
		return "Trade";
	end;
	p.Message = function(self, text, secs)
		HOST_Want(type(text) == "string" and type(secs) == "number", "Pilot:Message(text, secs)");
		print("HOST Message "..tostring(text));
		tinsert(HOST().msgs, {t=text, gt=HOST().gt});
	end;
	p.SetPerk = function(self, k) HOST_Want(type(k) == "string", "Pilot:SetPerk(perk)"); self.perks = (self.perks or 0) + 1; end;
	return p;
end;
function CreatePilot(tpl)
	HOST_Want(type(tpl) == "string", "CreatePilot(template) "..tostring(tpl));
	return HOST_Pilot(tpl);
end;

-- A spot within block_r of a live ship counts as blocked: CreateCarcass returns nil. dir is optional
-- (NewAllFlight passes two arguments).
function CreateCarcass(tpl, pos, dir)
	HOST_Want(type(tpl) == "string" and HOST_IsVec(pos) and (dir == nil or HOST_IsVec(dir)), "CreateCarcass(template, Vector3[, Vector3]) "..tostring(tpl));
	local ships = HOST().ships;
	for i = 1, getn(ships) do
		if ships[i].alive and HOST_Dist(ships[i].pos, pos) < HOST().block_r then print("HOST CreateCarcass blocked"); return nil; end;
	end;
	local s = {__obj=1, kind="ship", tpl=tpl, pos=Vector3(pos.x, pos.y, pos.z), alive=1, inv={}, spawn=Vector3(pos.x, pos.y, pos.z)};
	if dir then s.ori = Vector3(dir.x, dir.y, dir.z); end;
	s.AssignPilot = function(self, p)
		HOST_Want(type(p) == "table" and p.kind == "pilot", "Carcass:AssignPilot(pilot)");
		self.pilot = p; p.ship = self;
	end;
	s.ComeToTradeStation = function(self, st)
		HOST_Want(HOST_IsObj(st), "Carcass:ComeToTradeStation(station)");
		print("HOST ComeToTradeStation"); self.cts = st; self.pos = st:GetDockingPosition();
	end;
	s.ComeToPortal = function(self, p)
		HOST_Want(HOST_IsObj(p), "Carcass:ComeToPortal(portal)");
		print("HOST ComeToPortal "..tostring(p.label)); self.cp = p; self.pos = p:GetPosition();
	end;
	-- IsAlive pushes 1 or nil (lint_lua.py NIL_NATIVES; the game tests it bare: "if (x:IsAlive()) then").
	s.IsAlive = function(self) if self.alive then return 1; end; return nil; end;
	s.GetPosition = function(self) return Vector3(self.pos.x, self.pos.y, self.pos.z); end;
	s.GetOrientation = function(self) return Vector3(0, 0, 1); end;
	s.GetPilot = function(self) return self.pilot; end;
	s.Delete = function(self) self.alive = nil; end;
	s.SetRole = function(self, r) HOST_Want(type(r) == "number", "Carcass:SetRole(ROLE_*)"); self.role = r; end;
	-- 1 for transports (Walrus and Arba hulls included, v1 CHECK), nil for fighters (vanilla tests it bare).
	s.ImBigShip = function(self)
		if strfind(self.tpl, "_tr", 1, 1) or strfind(self.tpl, "transport", 1, 1) or strfind(self.tpl, "Walrus_", 1, 1) then return 1; end;
		return nil;
	end;
	s.AddModuleToInventory = function(self, it, n)
		HOST_Want(type(it) == "string" and type(n) == "number", "Carcass:AddModuleToInventory(item, count)");
		tinsert(self.inv, {it, n});
	end;
	-- v0.2: ClearInventory (FloodTradeStations.script), SetHP/GetCurHP (absolute HP, 1000 at spawn),
	-- GetName (template name), SetMaxSpeed (mothership use in vanilla; NPC use is a CHECK).
	s.hp = 1000;
	s.ClearInventory = function(self) self.inv = {}; self.cleared = (self.cleared or 0) + 1; end;
	s.SetHP = function(self, v) HOST_Want(type(v) == "number", "Carcass:SetHP(hp)"); self.hp = v; end;
	s.GetName = function(self) return self.tpl; end;
	s.SetMaxSpeed = function(self, v) HOST_Want(type(v) == "number", "Carcass:SetMaxSpeed(v)"); self.vmax = v; end;
	-- v1: heading (the spawn direction, or s.ori set by a scenario), teleport, move order, module fit (never
	-- used in vanilla), destruction, effect, speed (never used in vanilla; 100 or vmax).
	s.GetVectorOrientation = function(self) local o = self.ori or Vector3(0, 0, 1); return Vector3(o.x, o.y, o.z); end;
	s.SetPosition = function(self, v) HOST_Want(HOST_IsVec(v), "Carcass:SetPosition(Vector3)"); self.pos = Vector3(v.x, v.y, v.z); end;
	s.Move = function(self, v) HOST_Want(HOST_IsVec(v), "Carcass:Move(Vector3)"); self.mv = v; end;
	s.AddModule = function(self, m)
		HOST_Want(type(m) == "string", "Carcass:AddModule(module)");
		tinsert(HOST().mods, m); self.mods = (self.mods or 0) + 1;
	end;
	s.Blow = function(self) self.alive = nil; self.blown = 1; end;
	s.PlayFX = function(self, fx) HOST_Want(type(fx) == "string", "Carcass:PlayFX(effect)"); self.fx = fx; end;
	s.GetMaxSpeed = function(self) return self.vmax or 100; end;
	tinsert(HOST().ships, s);
	return s;
end;
-- The player arrived through PORTAL L and sits near it (not counted as a carcass here).
-- hp: hull HP (GetCurHP, SetHP), id: the Carcass table's id field (combat sample, combat-state.md 4).
HOST().ms = {__obj=1, kind="ms", pos=Vector3(-950, 0, 650), alive=1, hp=1000, id=1};
HOST().ms.GetPosition = function(self) return Vector3(self.pos.x, self.pos.y, self.pos.z); end;
HOST().ms.IsAlive = function(self) return 1; end;
-- GetName: the hull name in model (nil: an unlisted hull for GetPlayerLevel).
HOST().ms.GetName = function(self) return self.model; end;
HOST().ms.SetHP = function(self, v) HOST_Want(type(v) == "number", "Mothership:SetHP(hp)"); self.hp = v; end;
HOST().ms.inv = {};
HOST().ms.AddModuleToInventory = function(self, it, n)
	HOST_Want(type(it) == "string" and type(n) == "number", "Mothership:AddModuleToInventory(item, count)");
	print("HOST ms inventory +"..n.." "..it);
	tinsert(self.inv, {it, n});
end;
-- Player inventory (lua-natives.md 264, 507, 510; sealed parcels, CHECK E-PCL.1): GetInventory() over HOST().ms.inv
-- ({item, count} stacks). IsExist(name) pushes 1 while a stack of name holds a unit, else nil; DeleteModule(name) removes
-- one unit (the 01 section 6 inference), the whole stack with HOST().inv_del_stack = 1 (the E-PCL.1 failure case).
function GetInventory(...)
	HOST_Want(arg.n == 0, "GetInventory()");
	local inv = {__obj=1};
	inv.IsExist = function(self, it)
		HOST_Want(type(it) == "string", "Inventory:IsExist(module)");
		local l = HOST().ms.inv;
		for i = 1, getn(l) do if l[i][1] == it and l[i][2] > 0 then return 1; end; end;
		return nil;
	end;
	inv.DeleteModule = function(self, it)
		HOST_Want(type(it) == "string", "Inventory:DeleteModule(module)");
		local l = HOST().ms.inv;
		for i = 1, getn(l) do
			if l[i][1] == it and l[i][2] > 0 then
				if HOST().inv_del_stack == 1 then l[i][2] = 0; else l[i][2] = l[i][2] - 1; end;
				return;
			end;
		end;
	end;
	return inv;
end;
-- Units of item it in the mothership inventory (scenario helper).
function HOST_InvCount(it)
	local l, n = HOST().ms.inv, 0;
	for i = 1, getn(l) do if l[i][1] == it then n = n + l[i][2]; end; end;
	return n;
end;
-- The mothership's pilot (side "Player") and flight: pwing lists the pilots of that flight after the mothership's
-- (fighters, HOST_PlayerShip); crew maps a pilot name to a pilot for GetPilot (vanilla GetPilot("Hero")).
HOST().pwing = {}; HOST().crew = {};
HOST().ms.GetPilot = function(self)
	local fl = {Stop = function(self) HOST().ms_stops = (HOST().ms_stops or 0) + 1; end};
	fl.GetPilotCount = function(self) return getn(HOST().pwing); end;
	fl.GetPilotByNumber = function(self, i) HOST_Want(type(i) == "number", "Flight:GetPilotByNumber(i)"); return HOST().pwing[i]; end;
	return {kind="pilot", GetFlight = function(self) return %fl; end, GetSide = function(self) return "Player"; end,
		GetShip = function(self) return HOST().ms; end};
end;
function GetPilot(name)
	HOST_Want(type(name) == "string", "GetPilot(name)");
	return HOST().crew[name];
end;
-- A player fighter at (x, y, z): a live ship with a pilot of side "Player" (flight fl, default none), counted by
-- GetCarcassCountInSphere through cc_ships while alive (the scenario adds its position).
function HOST_PlayerShip(x, y, z, fl)
	local s = HOST_Obj("pf", x, y, z);
	s.kind = "ship";
	local q = {kind="pilot", ship=s};
	q.GetShip = function(self) return self.ship; end;
	q.GetSide = function(self) return "Player"; end;
	q.GetFlight = function(self) return %fl; end;
	s.pilot = q;
	s.GetPilot = function(self) return self.pilot; end;
	return s, q;
end;
-- in_tick: depth of TRF_OnTick (HOST_Tick); gpm_tick counts calls from a tick (crash-load-5adc5e.md: none allowed).
function GetPlayerMotherShip()
	local h = HOST();
	if (h.in_tick or 0) > 0 then h.gpm_tick = (h.gpm_tick or 0) + 1; end;
	return h.ms;
end;

-- 0x5e68f0: at least 2 args, x/y/z read from arg 1, radius from arg 2. The native counts every carcass
-- (ships, stations, portals, wrecks) whose bounding sphere touches the query sphere (carcass-count.md):
-- cc_static (default 1) stands for the portal or station that is always in a spawn spot's sphere, cc_ships
-- adds positions counted like ships (a ship parked at a spot without a handle), extra_carcass a flat count.
HOST().cc_static = 1; HOST().cc_ships = {};
function GetCarcassCountInSphere(pos, r)
	HOST_Want(HOST_IsVec(pos) and type(r) == "number", "GetCarcassCountInSphere(Vector3, radius)");
	local h = HOST();
	local n = 0;
	local ships = h.ships;
	for i = 1, getn(ships) do
		if ships[i].alive and HOST_Dist(ships[i].pos, pos) <= r then n = n + 1; end;
	end;
	for i = 1, getn(h.cc_ships) do
		if HOST_Dist(h.cc_ships[i], pos) <= r then n = n + 1; end;
	end;
	return n + (h.cc_static or 0) + (h.extra_carcass or 0);
end;

function HOST_Flight(fname, grp)
	local f = {__obj=1, kind="flight", name=fname, ships={}, group=grp};
	f.AddShip = function(self, s)
		HOST_Want(HOST_IsShip(s), "Flight:AddShip(carcass)");
		tinsert(self.ships, s); s.flight = self;
	end;
	f.SetFormation = function(self, x) HOST_Want(type(x) == "string", "Flight:SetFormation(name)"); end;
	f.SetOrientation = function(self, x) HOST_Want(HOST_IsVec(x), "Flight:SetOrientation(Vector3)"); end;
	f.Lead = function(self)
		for i = 1, getn(self.ships) do if self.ships[i].alive then return self.ships[i]; end; end;
		return nil;
	end;
	f.IsAlive = function(self) if self:Lead() then return 1; end; return nil; end;
	f.GetPosition = function(self) local s = self:Lead(); if s then return s:GetPosition(); end; return Vector3(0, 0, 0); end;
	f.Delete = function(self) print("HOST Flight:Delete "..self.name); foreachi(self.ships, function(i, s) s.alive = nil; end); self.deleted = 1; end;
	-- Patrol(points, loop): FALSE flies once (v0.1 lanes), TRUE loops (location garrisons, v1 clan sides).
	f.Patrol = function(self, pts, loop)
		local ok = type(pts) == "table" and getn(pts) >= 1 and (loop == FALSE or loop == TRUE);
		if ok then for i = 1, getn(pts) do if not HOST_IsVec(pts[i]) then ok = nil; end; end; end;
		HOST_Want(ok, "Flight:Patrol({Vector3, ...}, FALSE|TRUE)");
		self.patrol = pts;
	end;
	f.Move = function(self, v) HOST_Want(HOST_IsVec(v), "Flight:Move(Vector3)"); self.mv = v; end;
	f.Stop = function(self) self.stopped = (self.stopped or 0) + 1; end;
	f.Attack = function(self, o) HOST_Want(HOST_IsObj(o), "Flight:Attack(object)"); self.att = o; end;
	f.Escort = function(self, o) HOST_Want(HOST_IsObj(o), "Flight:Escort(object)"); self.esc = o; end;
	f.GetLeader = function(self) local s = self:Lead(); if s then return s.pilot; end; return nil; end;
	f.GetPilotCount = function(self) return getn(self.ships); end;
	f.GetPilotByNumber = function(self, i)
		HOST_Want(type(i) == "number" and self.ships[i] ~= nil, "Flight:GetPilotByNumber(1..n)");
		if self.ships[i] then return self.ships[i].pilot; end;
		return nil;
	end;
	return f;
end;

function HOST_Group(name, team)
	local g = {__obj=1, kind="group", name=name, team=team or "Trade"};
	HOST().groups[name] = g;
	g.CreateFlight = function(self, fname)
		HOST_Want(type(fname) == "string", "Group:CreateFlight(name)");
		return HOST_Flight(fname, self);
	end;
	return g;
end;
function CreateTeam(name)
	HOST_Want(type(name) == "string", "CreateTeam(name)");
	local t = {__obj=1, kind="team", name=name};
	t.CreateGroup = function(self, gname)
		HOST_Want(type(gname) == "string", "Team:CreateGroup(name)");
		return HOST_Group(gname, self.name);
	end;
	return t;
end;
-- (teamA, teamB) -> RELATION_*: HOST().rel_team["A|B"], else Pirates at war with Trade and the player,
-- everything else friendly (2).
function GetTeamRelation(a, b)
	HOST_Want(type(a) == "string" and type(b) == "string", "GetTeamRelation(team, team)");
	local t = HOST().rel_team;
	if t and t[a.."|"..b] then return t[a.."|"..b]; end;
	if a == "Pirates" and (b == "Trade" or b == PLAYER_TEAM) then return RELATION_WAR; end;
	return RELATION_FRIEND;
end;
-- (groupA, groupB, RELATION_*): group objects or group names (OutOfMission.script 407), PLAYER_GROUP;
-- one direction per call. Recorded in HOST().rel as {a, b, rel}.
function SetGroupRelation(g, pg, rel)
	local ok = function(x) return HOST_IsGroup(x) or type(x) == "string"; end;
	HOST_Want(ok(g) and ok(pg) and type(rel) == "number", "SetGroupRelation(group, group, relation)");
	local nm = function(x) if type(x) == "table" then return x.name; end; return x; end;
	tinsert(HOST().rel, {nm(g), nm(pg), rel});
end;
-- (name) -> group created under that name, else nil (lua-natives.md, never used in vanilla).
function GetGroupByName(n) HOST_Want(type(n) == "string", "GetGroupByName(name)"); return HOST().groups[n]; end;
-- (groupA, groupB) -> the last SetGroupRelation of the pair, else nil when the stub has no record.
function GetGroupRelation(a, b)
	HOST_Want((HOST_IsGroup(a) or type(a) == "string") and (HOST_IsGroup(b) or type(b) == "string"), "GetGroupRelation(group, group)");
	local nm = function(x) if type(x) == "table" then return x.name; end; return x; end;
	local q, r = HOST().rel, nil;
	for i = 1, getn(q) do if q[i][1] == nm(a) and q[i][2] == nm(b) then r = q[i][3]; end; end;
	return r;
end;
function CreatePortalGlow(pos, dir, n)
	HOST_Want(HOST_IsVec(pos) and HOST_IsVec(dir) and type(n) == "number", "CreatePortalGlow(Vector3, Vector3, n)");
	HOST().glows = HOST().glows + 1;
end;

-- v0.2 natives ---------------------------------------------------------------------
-- ShowMsgBox(titleKey, text, onOk[, onCancel]) (lua-natives.md; DockStation.script 178): callbacks are
-- function values. Recorded in HOST().boxes; HOST_Press runs a button. A box opened while a button
-- callback runs counts in HOST().box_nested (v02 6.1: the next box comes from a due call).
function ShowMsgBox(...)
	local h = HOST();
	HOST_Want((arg.n == 3 or arg.n == 4) and type(arg[1]) == "string" and type(arg[2]) == "string" and type(arg[3]) == "function"
		and (arg[4] == nil or type(arg[4]) == "function"), "ShowMsgBox(title, text, ok[, cancel])");
	if h.in_box then h.box_nested = h.box_nested + 1; end;
	print("HOST box "..tostring(arg[1]).." | "..tostring(arg[2]));
	tinsert(h.boxes, {title=arg[1], text=arg[2], ok=arg[3], cancel=arg[4], gt=h.gt});
end;
-- Press "ok" or "cancel" on box b (default: the newest); a box without a Cancel callback closes on Cancel.
function HOST_Press(which, b)
	local h = HOST();
	b = b or h.boxes[getn(h.boxes)];
	HOST_Want(b and not b.done, "HOST_Press: an open box");
	if not b or b.done then return nil; end;
	b.done = which;
	local f = b.ok;
	if which == "cancel" then f = b.cancel; end;
	print("HOST press "..which.." on "..tostring(b.text));
	h.in_box = 1;
	if f then f(); end;
	h.in_box = nil;
	return 1;
end;
function HOST_Box() local h = HOST(); return h.boxes[getn(h.boxes)]; end;

-- Markets (InitTradeSystem.script, FloodTradeStations.script): GetWhiteMarket(name) -> Market with
-- ModuleGoodsState(item, count, sell, buy) and ClearGoodsState(item). Station markets exist for every name
-- except HOST().no_market[name]; trf_ shops only after CreateShop. Writes go to HOST().mwrites.
function HOST_Market(name)
	local m = {__obj=1, kind="market", name=name, goods={}};
	m.ModuleGoodsState = function(self, it, n, sk, bk)
		HOST_Want(type(it) == "string" and type(n) == "number" and type(sk) == "number" and type(bk) == "number",
			"Market:ModuleGoodsState(item, count, sell, buy)");
		self.goods[it] = {n=n, s=sk, b=bk};
		tinsert(HOST().mwrites, {shop=self.name, i=it, n=n, s=sk, b=bk});
	end;
	m.ClearGoodsState = function(self, it)
		HOST_Want(type(it) == "string", "Market:ClearGoodsState(item)");
		self.goods[it] = nil;
		tinsert(HOST().mwrites, {shop=self.name, i=it, clear=1});
	end;
	return m;
end;
function GetWhiteMarket(name)
	local h = HOST();
	HOST_Want(type(name) == "string", "GetWhiteMarket(name)");
	if type(name) ~= "string" or (h.no_market and h.no_market[name]) then return nil; end;
	if not h.markets[name] and strsub(name, 1, 4) ~= "trf_" then h.markets[name] = HOST_Market(name); end;
	return h.markets[name];
end;
function CreateShop(name)
	local h = HOST();
	HOST_Want(type(name) == "string", "CreateShop(name)");
	h.shops_made[name] = (h.shops_made[name] or 0) + 1;
	if not h.markets[name] then h.markets[name] = HOST_Market(name); end;
end;
function UpdateTradeSystem(f) HOST_Want(f == TRUE or f == FALSE, "UpdateTradeSystem(TRUE|FALSE)"); tinsert(HOST().upd, f); end;
function TradeStationDlg(name) HOST_Want(type(name) == "string", "TradeStationDlg(shop)"); tinsert(HOST().dlgs, name); end;
function SetTraderFlag(f) HOST_Want(f == TRUE or f == FALSE, "SetTraderFlag(TRUE|FALSE)"); HOST().trflag = f; end;
-- PatrolStationDlg() or (dialog name), DockStation.script 220-232.
function PatrolStationDlg(...)
	HOST_Want(arg.n == 0 or type(arg[1]) == "string", "PatrolStationDlg([dialog])");
	tinsert(HOST().pdlgs, arg[1] or "");
end;
-- StartTradeDialog(dialog[, init]) (mod-research/hail-dialog.md 1.4): loads DATA\Scripts\Trade\<dialog>.xml and
-- runs the global init (by name) before the window opens. Recorded in HOST().tdlg (name) and HOST().tdlgs
-- ({d, init}). A mod dialog file (TRF_DIR../../Trade/<dialog>.xml) becomes HOST().dlg = {name, msg, ans = {answer
-- name -> {t, fn, hidden}}, order, rv = {token -> value}, open}: HideAnswer, ShowAnswer and SetReplaceValue act
-- on it (an unknown answer name fails), HOST_DlgPick(answer) closes it and calls the answer's lua_function,
-- HOST_DlgEsc() closes it without an answer. While it is open a HOST().ui of 0 reads 4 (dialog flag).
function StartTradeDialog(...)
	local h = HOST();
	HOST_Want((arg.n == 1 or arg.n == 2) and type(arg[1]) == "string" and (arg[2] == nil or type(arg[2]) == "string"),
		"StartTradeDialog(dialog[, init])");
	h.tdlg = arg[1];
	tinsert(h.tdlgs, {d=arg[1], init=arg[2]});
	local x = HOST_DlgXml(arg[1]);
	if x then x.init = arg[2]; h.dlg = x; end;
	if arg[2] then
		local f = getglobal(arg[2]);
		HOST_Want(type(f) == "function", "StartTradeDialog init "..tostring(arg[2]).." defined");
		if type(f) == "function" then f(); end;
	end;
	if x then
		x.open = 1;
		x.ui0 = h.ui;
		if h.ui == 0 then h.ui = 4; end;
	end;
end;
-- Mod dialog file of name parsed (message, answers with text and lua_function), or nil.
function HOST_DlgXml(name)
	local f = openfile(HOST().dir.."../../Trade/"..name..".xml", "r");
	if not f then return nil; end;
	local s = read(f, "*a");
	closefile(f);
	local x = {name=name, ans={}, order={}, rv={}};
	local _, _, msg = strfind(s, "<message>([^<]*)</message>");
	x.msg = msg;
	gsub(s, '<DialogAnswer name="([^"]+)">%s*<answer>([^<]*)</answer>%s*<lua_function>([^<]*)</lua_function>',
		function(n, t, fn) local y = %x; y.ans[n] = {t=t, fn=fn}; tinsert(y.order, n); end);
	return x;
end;
function HOST_DlgAns(n, hide, what)
	local d = HOST().dlg;
	HOST_Want(type(n) == "string", what.."(answer)");
	tinsert(HOST().dlg_calls, what.." "..tostring(n));
	HOST_Want(d and d.ans[n], what..": answer '"..tostring(n).."' in the current dialog");
	if d and d.ans[n] then d.ans[n].hidden = hide; end;
end;
function HideAnswer(n) HOST_DlgAns(n, 1, "HideAnswer"); end;
function ShowAnswer(n) HOST_DlgAns(n, nil, "ShowAnswer"); end;
function SetReplaceValue(k, v)
	local d = HOST().dlg;
	HOST_Want(type(k) == "string" and type(v) == "string", "SetReplaceValue(key, value)");
	HOST_Want(d, "SetReplaceValue: a dialog is loaded");
	if d then d.rv[k] = v; end;
end;
-- Visible answers of the open dialog in file order, space separated ("" without one).
function HOST_DlgVis()
	local d, s = HOST().dlg, "";
	if not d or not d.open then return ""; end;
	for i = 1, getn(d.order) do if not d.ans[d.order[i]].hidden then s = s..(s ~= "" and " " or "")..d.order[i]; end; end;
	return s;
end;
-- Text with the #tokens# replaced (unknown ones kept): the message, or answer n.
function HOST_DlgText(n)
	local d = HOST().dlg;
	if not d then return nil; end;
	local s = d.msg;
	if n then s = d.ans[n] and d.ans[n].t; end;
	if not s then return nil; end;
	local dv = d.rv;
	local r = gsub(s, "#(%w+)#", function(k) return %dv[k] or "#"..k.."#"; end);
	return r;
end;
function HOST_DlgEsc()
	local h = HOST();
	local d = h.dlg;
	HOST_Want(d and d.open, "HOST_DlgEsc: an open dialog");
	if not d or not d.open then return nil; end;
	d.open = nil;
	h.ui = d.ui0;
	return 1;
end;
-- Pick visible answer n of the open dialog: the dialog closes (no go_message_name), then its lua_function runs.
function HOST_DlgPick(n)
	local h = HOST();
	local d = h.dlg;
	HOST_Want(d and d.open and d.ans[n] and not d.ans[n].hidden, "HOST_DlgPick: visible answer "..tostring(n));
	if not d or not d.open or not d.ans[n] then return nil; end;
	HOST_DlgEsc();
	local f = getglobal(d.ans[n].fn);
	HOST_Want(type(f) == "function", "lua_function "..tostring(d.ans[n].fn).." defined");
	print("HOST dialog pick "..n);
	h.in_box = 1;
	if type(f) == "function" then f(); end;
	h.in_box = nil;
	return 1;
end;

-- Nav points: CreateNavPoint(textKey, Vector3, icon, RGB(), attachObj) -> NavPoint with Delete; obj keeps the attached
-- object (wanted captains, design/captain-spec.md 5.3).
function RGB(r, g, b) HOST_Want(type(r) == "number" and type(g) == "number" and type(b) == "number", "RGB(r, g, b)"); return r * 65536 + g * 256 + b; end;
function CreateNavPoint(t, pos, icon, col, obj)
	HOST_Want(type(t) == "string" and HOST_IsVec(pos) and type(icon) == "string" and (col == nil or type(col) == "number") and (obj == nil or HOST_IsObj(obj)),
		"CreateNavPoint(text, Vector3, icon, RGB, object)");
	local n = {__obj=1, kind="nav", pos=pos, text=t, alive=1, obj=obj, icon=icon};
	n.Delete = function(self) self.alive = nil; self.deleted = 1; end;
	n.GetPosition = function(self) return self.pos; end;
	tinsert(HOST().navs, n);
	return n;
end;
function SetNavPointLabel(n, l)
	HOST_Want(type(n) == "table" and n.kind == "nav" and type(l) == "string", "SetNavPointLabel(navpoint, label)");
	n.label = l;
end;
function GetNavPointByLabel(l)
	HOST_Want(type(l) == "string", "GetNavPointByLabel(label)");
	local q = HOST().navs;
	for i = 1, getn(q) do if q[i].label == l and q[i].alive then return q[i]; end; end;
	return nil;
end;
function HOST_Navs()
	local n, q = 0, HOST().navs;
	for i = 1, getn(q) do if q[i].alive then n = n + 1; end; end;
	return n;
end;

-- (carcass) -> current HP.
function GetCurHP(o) HOST_Want(type(o) == "table" and o.__obj, "GetCurHP(carcass)"); return o.hp; end;

-- v1 natives -----------------------------------------------------------------------
-- (questId) -> QUEST_* state: HOST().quests[id], QUEST_NOINIT for an unknown id (CHECK v1 10.4).
function GetQuestState(id)
	HOST_Want(type(id) == "string", "GetQuestState(questId)");
	return HOST().quests[id] or QUEST_NOINIT;
end;
-- Logbook (lua-natives.md 134-137, 147; charter goals): AddQuest(id, title, desc, state) -> HOST().quests[id] = state,
-- HOST().qlog[id] = {t, d}; SetQuestState(id, state); RemoveQuest(id); ClearQuests() empties both (CHECK EC.3).
function AddQuest(id, t, d, s)
	HOST_Want(type(id) == "string" and type(t) == "string" and type(d) == "string" and type(s) == "number", "AddQuest(id, title, desc, state)");
	local h = HOST();
	if type(h.qlog) ~= "table" then h.qlog = {}; end;
	h.quests[id] = s;
	h.qlog[id] = {t=t, d=d};
end;
function SetQuestState(id, s)
	HOST_Want(type(id) == "string" and type(s) == "number", "SetQuestState(id, state)");
	HOST().quests[id] = s;
end;
function RemoveQuest(id)
	HOST_Want(type(id) == "string", "RemoveQuest(id)");
	local h = HOST();
	h.quests[id] = nil;
	if type(h.qlog) == "table" then h.qlog[id] = nil; end;
end;
function ClearQuests(...)
	HOST_Want(arg.n == 0, "ClearQuests()");
	HOST().quests = {};
	HOST().qlog = {};
end;
-- CreateStation(model, pos, dir[, flag]) -> station object: HP 100000, SetHP, Blow (wreck flag), Delete, IsAlive,
-- docking position; counted by GetCarcassCountInSphere like a carcass. ClearInventory and AddModuleToInventory as on a
-- carcass (the clan stash cache, Asteroid_inv_Val, design/stash-spec.md 5.4).
function CreateStation(model, pos, dir, fl)
	HOST_Want(type(model) == "string" and HOST_IsVec(pos) and HOST_IsVec(dir), "CreateStation(model, Vector3, Vector3[, flag])");
	local s = HOST_Obj("station", pos.x, pos.y, pos.z);
	s.label = nil; s.kind = "station"; s.model = model; s.hp = 100000;
	s.SetHP = function(self, v) HOST_Want(type(v) == "number", "Station:SetHP(hp)"); self.hp = v; end;
	s.Blow = function(self) self.alive = nil; self.blown = 1; end;
	s.Delete = function(self) self.alive = nil; self.deleted = 1; end;
	s.GetName = function(self) return self.model; end;
	s.inv = {};
	s.ClearInventory = function(self) self.inv = {}; self.cleared = (self.cleared or 0) + 1; end;
	s.AddModuleToInventory = function(self, it, n)
		HOST_Want(type(it) == "string" and type(n) == "number", "Station:AddModuleToInventory(item, count)");
		tinsert(self.inv, {it, n});
	end;
	tinsert(HOST().stations, s);
	tinsert(HOST().ships, s);
	print("HOST CreateStation "..model);
	return s;
end;
-- DockStation.script CreateDocking(action, pos, ship, r, param, obj), recorded in HOST().pdocks.
function CreateDocking(a, pos, ship, r, p, o)
	HOST_Want(type(a) == "string" and HOST_IsVec(pos) and type(r) == "number", "CreateDocking(action, Vector3, ship, r, param, obj)");
	tinsert(HOST().pdocks, {a=a, pos=pos, r=r, p=p, o=o});
end;
function AddPlayerCredits(n) HOST_Want(type(n) == "number", "AddPlayerCredits(n)"); HOST().credits = HOST().credits + n; end;
function GetPlayerCredits() return HOST().credits; end;
function SubPlayerCredits(n) HOST().credits = HOST().credits - n; end;
-- Office unit of the player (LN line 206; mercenary clans, TR F.17): HOST().recruit, else "" (no unit).
function GetRecruitGroupName() return HOST().recruit or ""; end;
function GetPlayerLevel() return HOST().level; end;
function AddPlayerExperience(x) HOST().xp = (HOST().xp or 0) + x; end;
-- News: (mailId) strings; recorded as "+id" / "-id".
function AddPost(id) HOST_Want(type(id) == "string", "AddPost(mailId)"); tinsert(HOST().posts, "+"..id); end;
function RemovePost(id) HOST_Want(type(id) == "string", "RemovePost(mailId)"); tinsert(HOST().posts, "-"..id); end;
-- CombineStr(key, value) (lua-natives.md 115): the loc text of key with the value; the host joins them.
function CombineStr(k, v) HOST_Want(type(k) == "string", "CombineStr(key, value)"); return k.." "..tostring(v); end;
-- SetInitTeamRelation(teamA, teamB, RELATION_*) (DockStation.script 464): both directions in HOST().rel_team, which
-- GetTeamRelation reads.
function SetInitTeamRelation(a, b, rel)
	HOST_Want(type(a) == "string" and type(b) == "string" and type(rel) == "number", "SetInitTeamRelation(team, team, relation)");
	local h = HOST();
	if type(h.rel_team) ~= "table" then h.rel_team = {}; end;
	h.rel_team[a.."|"..b] = rel;
	h.rel_team[b.."|"..a] = rel;
end;
-- Timer_Seq(seconds, function) (vanilla timer helper): recorded in HOST().tseq as {t, f}; HOST_TimerRun runs them.
function Timer_Seq(t, f)
	HOST_Want(type(t) == "number" and type(f) == "function", "Timer_Seq(seconds, function)");
	local h = HOST();
	if type(h.tseq) ~= "table" then h.tseq = {}; end;
	tinsert(h.tseq, {t=t, f=f});
end;

-- Create_flight_2.script CreateChoiceFlight(team, group global name, sign, pos, type, power, orient):
-- a flight in getglobal(group) with flight_/ship_/pilot_<sign> globals; FALSE without the group.
function CreateChoiceFlight(team, gname, sign, pos, ty, pw, dir)
	HOST_Want(type(team) == "string" and type(gname) == "string" and type(sign) == "string" and HOST_IsVec(pos)
		and type(ty) == "number" and type(pw) == "number" and HOST_IsVec(dir), "CreateChoiceFlight(team, group, sign, pos, type, power, dir)");
	local g = getglobal(gname);
	if not HOST_IsGroup(g) then return FALSE; end;
	local fl = g:CreateFlight("flight_"..sign);
	setglobal("flight_"..sign, fl);
	for i = 1, 2 do
		local s = CreateCarcass("Raptor_merc1", Vector3(pos.x, pos.y, pos.z + 5 * i), dir);
		local p = CreatePilot("GreenRecruitAce");
		s:AssignPilot(p);
		fl:AddShip(s);
		setglobal("ship_"..sign.."_"..i, s);
		setglobal("pilot_"..sign.."_"..i, p);
	end;
	HOST().choice = HOST().choice + 1;
	return fl;
end;

-- Create_flight_2.script NewAllFlight (66-139): same lookups, globals and placement; FALSE without a
-- group; a nil carcass raises an error (ship:AssignPilot on nil), as in the game.
function NewAllFlight(tab_pilot, tab_flight, group, sign, location, power, orient2, formation)
	HOST_Want(type(tab_pilot) == "table" and type(tab_flight) == "table" and type(group) == "string" and type(sign) == "string"
		and HOST_IsVec(location) and type(power) == "number", "NewAllFlight(pilots, ships, group name, sign, Vector3, power, orient, formation)");
	local tl, tp;
	if GetLevelDifficult() == EASY then
		tl = {1,1,1,2,3,4,5,6,7,7,8,9,9,10,11,11,12,13,13,14}; tp = {1,1,2,2,3};
	elseif GetLevelDifficult() == NORMAL then
		tl = {1,1,2,3,4,5,6,6,7,8,9,10,11,12,12,13,14,15,16,17}; tp = {1,2,2,3,4};
	else
		tl = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20}; tp = {1,2,3,4,5};
	end;
	local grp = getglobal(group);
	local level = power or 1;
	if level < 1 then level = 1; end;
	if level > 20 then level = 20; end;
	if not grp then LOG("No Group to create flight!"); return FALSE; end;
	local flight = grp:CreateFlight("flight_"..sign);
	setglobal("flight_"..sign, flight);
	local row = tab_flight[tl[level]];
	for i1 = 1, getn(row) do
		local sh = row[i1];
		local ship = CreateCarcass(sh[1], Vector3(0, 0, (i1 - 1) * 5) + location);
		local pilot = CreatePilot(tab_pilot[tp[sh[2]]]);
		ship:AssignPilot(pilot);
		flight:AddShip(ship);
		if i1 > 1 then ship:SetRole(ROLE_ATTACK); end;
		setglobal("ship_"..sign.."_"..i1, ship);
		setglobal("pilot_"..sign.."_"..i1, pilot);
	end;
	flight:SetFormation(formation or "shipFormation");
	flight:SetOrientation(orient2 or Vector3(0, 0, 1));
	return flight;
end;

-- Create_flight_2.script FillCargoFlight (141-159).
function FillCargoFlight(flight, CType, power, ver, num)
	local V = ver or 100;
	local X = num or 5;
	local P = power or 10;
	local numcargo = getn(CType);
	if (V > RAND(100)) and (X > 0) and (numcargo > 10) then
		P = floor(P / 4);
		for i = 1, flight:GetPilotCount() do
			local _ship = flight:GetPilotByNumber(i):GetShip();
			if (_ship:ImBigShip()) then
				if X > 2 then _ship:AddModuleToInventory(CType[RAND(numcargo - 5) + P + 1], RAND(2) + 1); end;
				_ship:AddModuleToInventory(CType[RAND(numcargo - 5) + P + 1], RAND(X) + 1);
			end;
		end;
	end;
end;

function R_CreateTraderFlight(group, sign, location, power, orient)
	local fl = NewAllFlight(Trad_merc_Pilots, Trad_merc_Ships, group, sign, location, power, orient, "shipFormationConvoy");
	FillCargoFlight(fl, Trad_CargoType, power, 100, 6);
	return fl;
end;
function R_CreatePirateFlight(group, sign, location, power, orient)
	return NewAllFlight(Trad_merc_Pilots, Trad_merc_Ships, group, sign, location, power, orient, "shipFormation");
end;

-- RandomContacts.script trigger_generator_Action (197-303), reduced: re-arm, __disableAction, contact draw,
-- probability roll, portals, strength, builder, patrol. Records every call (argument count, contact list,
-- RAND draws so far) in HOST().vgen; HOST().van_error raises an error after the re-arm.
function HOST_VanGen(a)
	local h = HOST();
	tinsert(h.vgen, {n=a.n, list=__sys_LevelRegisteredContacts, rand=h.rand});
	local this = GetTriggerContext();
	this:SetTime(_sys_RandomContactsInterval);
	this:Activate();
	if h.van_error then error("vanilla generator error (host)"); end;
	if __disableAction == TRUE then return; end;
	local list = __sys_LevelRegisteredContacts;
	local c = list[RAND(getn(list)) + 1];
	if not (c[5] > RAND(100)) then return; end;
	local ps = c[3];
	local si, ei = 1, 1;
	if getn(ps) > 1 then
		si = RAND(getn(ps)) + 1; ei = si;
		while ei == si do ei = RAND(getn(ps)) + 1; end;
	end;
	local strength = c[6] - 4 + RAND(8);
	if strength > 20 then strength = 20; end;
	if strength < 1 then strength = 1; end;
	ps[si]:Start(8, 0);
	local fl = getglobal(c[1])(c[2], "randomformation_"..__formation_number, ps[si]:GetEntryPoint(10), strength, ps[si]:GetOrientation());
	__formation_number = __formation_number + 1;
	fl:Patrol({ps[si]:GetEntryPoint(70), ps[ei]:GetEntryPoint(50), ps[ei]:GetEntryPoint(1)}, FALSE);
	-- The vanilla trader flies off (host ships do not move): clear the spawn spot.
	foreachi(fl.ships, function(i, s) s.pos = Vector3(s.pos.x, s.pos.y + 2000 + 20 * __formation_number, s.pos.z); end);
	h.van_built = h.van_built + 1;
end;
-- AI/Case_Eject.script: 2 for an NPC pilot.
function HOST_VanEject(p)
	HOST().eject = HOST().eject + 1;
	return 2;
end;

-- The vanilla includes the modules depend on. Run on every MapInitialization before traffic.script, as
-- system.lst does; the chunk name is a vanilla path, so TRF_IsMine(getinfo source) is false for them.
function HOST_Includes()
	dostring([[
TRADER_FLIGHT = "R_CreateTraderFlight";
Trad_merc_Pilots = {"Trader", "GreenRecruitPilot", "GreenRecruitOfficer", "GreenRecruitAce", "GreenRecruitSuperAce", "GreenRecruitHyperAce"};
Trad_merc_Ships = {
	{{"HMQueen_tr1",1,"A"},{"Hatchet_merc1",2,"A"}},
	{{"HMQueen_tr2",1,"A"},{"Hatchet_merc1",2,"A"},{"Hatchet_merc1",2,"A"}},
	{{"HMQueen_tr3",1,"A"},{"Hatchet_merc1",2,"A"},{"Hatchet_merc1",2,"A"},{"Hatchet_merc1",2,"D"}},
	{{"HMQueen_tr6",1,"A"},{"HMQueen_tr7",1,"A"},{"Hatchet_merc1",3,"A"},{"Hatchet_merc1",2,"D"}},
	{{"HMQueen_tr8",1,"A"},{"HMQueen_tr9",1,"A"},{"Hatchet_merc1",3,"A"},{"Hatchet_merc1",2,"A"},{"Hatchet_merc1",2,"D"}},
	{{"Walrus_tr11",1,"A"},{"Excalibur_merc1",2,"A"}},
	{{"Walrus_tr13",1,"A"},{"Stormcrow_merc1",2,"A"}},
	{{"Walrus_tr15",1,"A"},{"Walrus_tr2",1,"A"},{"TieFly_merc1",3,"A"},{"Stormcrow_merc1",2,"A"}},
	{{"Walrus_tr17",1,"A"},{"Walrus_tr4",1,"A"},{"Raptor_merc1",3,"A"},{"Cleaner_merc1",2,"A"}},
	{{"Btransport",1,"A"},{"Stormcrow_merc2",2,"A"}},
	{{"Btransport",1,"A"},{"Cleaner_merc2",2,"A"}},
	{{"Btransport",1,"A"},{"Stormcrow_merc3",3,"A"}},
	{{"Btransport2",1,"A"},{"Cleaner_merc2",2,"A"},{"Stormcrow_merc2",2,"A"},{"Raptor_merc1",2,"M"}},
	{{"Btransport2",1,"A"},{"EvilEye_merc1",3,"A"},{"Cleaner_merc2",2,"A"},{"Raptor_merc1",3,"M"}},
	{{"Arba_tr",1,"A"},{"Tiger_merc1",3,"A"},{"Raptor_merc1",2,"A"}},
	{{"Arba_tr1",1,"A"},{"Tiger_merc1",3,"A"},{"Raptor_merc1",3,"A"},{"Trident_merc1",2,"M"}},
	{{"Arba_tr2",1,"A"},{"Puma_merc1",3,"A"},{"Tiger_merc1",3,"A"},{"Trident_merc1",2,"M"}},
	{{"Arba_tr4",1,"A"},{"Puma_merc1",3,"A"},{"Puma_merc1",3,"A"},{"Trident_merc1",3,"M"}},
	{{"Arba_tr5",1,"A"},{"Gunslinger_merc1",3,"A"},{"Puma_merc1",3,"A"},{"Trident_merc1",3,"M"}},
	{{"Btransport2",1,"A"},{"Btransport",1,"A"},{"Gunslinger_merc1",3,"A"},{"Puma_merc1",3,"A"},{"Tiger_merc1",3,"D"},{"Trident_merc1",3,"M"}}};
Trad_CargoType = {"Cargo_01", "Cargo_02", "Cargo_03", "Cargo_04", "Cargo_05", "Cargo_06", "Cargo_07", "Cargo_08", "Cargo_09", "Cargo_10",
	"Barrel_02", "Uranium", "Cargo_06", "Cargo_07", "Cargo_08", "Cargo_09", "Cargo_10"};
function trigger_generator_Action(...) return HOST_VanGen(arg); end;
function Case_Eject(p) return HOST_VanEject(p); end;
function _FTrader_Action() HOST().meet = HOST().meet + 1; end;
SpeakList_TraderDialog = {"DialogTrader1", "DialogTrader2", "DialogTrader3"};
SpeakList_TraderDialog_nocost = {"DialogTrader1n", "DialogTrader2n", "DialogTrader3n"};
function On_FTrader_Start()
	HOST().ftrader = HOST().ftrader + 1;
	local x = getn(ShopList_Trader);
	rn_x = RAND(x) + 1;
	UpdateTradeSystem(FALSE);
	SetTraderFlag(TRUE);
	TradeStationDlg(ShopList_Trader[rn_x]);
end;
function _Trader_Speak()
	HOST().speak = HOST().speak + 1;
	local x = getn(SpeakList_TraderDialog);
	Rnd_speak = RAND(x) + 1;
	if GetPlayerCredits() >= 5000 then StartTradeDialog(SpeakList_TraderDialog[Rnd_speak]);
	else StartTradeDialog(SpeakList_TraderDialog_nocost[Rnd_speak]); end;
end;
]], "DATA/Scripts/include/RandomContacts.script");
	-- Create_flight_2.script and FloodTradeStations.script data tables (copied from the game files).
	dostring([[
Pir_Pilots = {"PirateRookie", "PirateTough", "PirateCaptain", "PirateSuperAce", "PirateHyperAce"};
Pir_Fighters = { {{"Brigand_pir1",1,"A"}}, {{"Excalibur_pir1",1,"A"}}, {{"Excalibur_pir1",1,"A"},{"Brigand_pir1",1,"A"}}, {{"Excalibur_pir1",1,"A"},{"Yari_pir1",1,"A"},{"Brigand_pir1",1,"A"}}, {{"Stormcrow_pir1",2,"A"},{"Brigand_pir1",1,"A"}}, {{"Stormcrow_pir1",2,"A"},{"Raptor_pir1",2,"A"}}, {{"Stormcrow_pir1",2,"A"},{"Raptor_pir1",2,"A"},{"Hatchet_pir1",2,"M"}}, {{"Stormcrow_pir1",2,"A"},{"Raptor_pir1",2,"A"},{"Raptor_pir1",2,"A"},{"Hatchet_pir1",1,"M"}}, {{"Stormcrow_pir1",2,"A"},{"Cleaner_pir1",2,"A"},{"Raptor_pir1",2,"A"},{"Raptor_pir1",2,"M"}}, {{"EvilEye_pir1",3,"A"},{"Tiger_pir1",3,"A"},{"Raptor_pir1",2,"M"}}, {{"EvilEye_pir1",3,"A"},{"Stormcrow_pir1",3,"A"},{"EvilEye_pir1",2,"M"}}, {{"EvilEye_pir2",3,"A"},{"Tiger_pir1",3,"A"},{"Cleaner_pir1",2,"A"},{"EvilEye_pir1",2,"M"}}, {{"EvilEye_pir2",3,"A"},{"Tiger_pir2",3,"A"},{"Stormcrow_pir1",3,"A"},{"EvilEye_pir1",2,"M"}}, {{"EvilEye_pir3",3,"A"},{"EvilEye_pir2",3,"A"},{"Tiger_pir2",3,"A"},{"Tiger_pir2",2,"A"},{"EvilEye_pir1",3,"M"}}, {{"Gunslinger_pir1",4,"A"},{"Tiger_pir2",4,"A"},{"EvilEye_pir1",3,"M"}}, {{"Gunslinger_pir1",4,"A"},{"Gunslinger_pir1",4,"A"},{"EvilEye_pir1",3,"M"}}, {{"Gunslinger_pir2",4,"A"},{"Tiger_pir2",3,"A"},{"Tiger_pir2",3,"A"},{"Trident_pir1",3,"M"}}, {{"Gunslinger_pir2",4,"A"},{"Gunslinger_pir1",4,"A"},{"Tiger_pir2",3,"A"},{"Trident_pir1",3,"M"}}, {{"Gunslinger_pir2",4,"A"},{"Gunslinger_pir2",4,"A"},{"Tiger_pir2",4,"A"},{"Tiger_pir2",3,"A"},{"Trident_pir1",4,"M"}}, {{"Gunslinger_pir3",5,"A"},{"Gunslinger_pir2",4,"A"},{"Gunslinger_pir1",4,"A"},{"Gunslinger_pir1",4,"A"},{"Gunslinger_pir1",3,"A"},{"Trident_pir1",4,"M"}}};
Pir_Bombers = { {{"Naginata_pir1",1,"A"}}, {{"Excalibur_pir2",1,"A"}}, {{"Naginata_pir1",1,"A"},{"Naginata_pir1",1,"A"}}, {{"Excalibur_pir2",1,"A"},{"Naginata_pir1",1,"A"},{"Naginata_pir1",1,"A"}}, {{"Excalibur_pir2",2,"A"},{"Hammerhead_pir1",2,"A"}}, {{"Hammerhead_pir1",2,"A"},{"Hammerhead_pir1",2,"A"}}, {{"Excalibur_pir2",2,"A"},{"Hammerhead_pir1",2,"A"},{"Hatchet_pir1",1,"M"}}, {{"Hammerhead_pir1",2,"A"},{"Hammerhead_pir1",2,"A"},{"Hatchet_pir1",2,"M"}}, {{"Hammerhead_pir1",2,"A"},{"Hammerhead_pir1",2,"A"},{"Excalibur_pir2",2,"A"},{"Hatchet_pir1",2,"M"}}, {{"Bident_pir1",3,"A"},{"Bident_pir1",2,"A"},{"Hatchet_pir1",2,"M"}}, {{"Bident_pir1",3,"A"},{"Bident_pir1",2,"A"},{"EvilEye_pir1",2,"M"}}, {{"Bident_pir1",3,"A"},{"Bident_pir1",2,"A"},{"EvilEye_pir1",2,"M"},{"EvilEye_pir3",2,"C"}}, {{"Bident_pir1",3,"A"},{"Hammerhead_pir1",2,"A"},{"Hammerhead_pir1",2,"A"},{"EvilEye_pir1",2,"M"}}, {{"Bident_pir1",3,"A"},{"Bident_pir1",3,"A"},{"Bident_pir1",3,"A"},{"EvilEye_pir1",3,"M"}}, {{"Hrimturs_pir1",4,"A"},{"Bident_pir1",4,"A"},{"EvilEye_pir1",3,"M"}}, {{"Hrimturs_pir1",4,"A"},{"Hrimturs_pir1",4,"A"},{"Trident_pir1",3,"M"}}, {{"Hrimturs_pir1",4,"A"},{"Hrimturs_pir1",4,"A"},{"EvilEye_pir2",3,"D"},{"Trident_pir1",3,"M"}}, {{"Hrimturs_pir1",4,"A"},{"Hrimturs_pir1",4,"A"},{"Hrimturs_pir1",3,"A"},{"Trident_pir1",3,"M"}}, {{"Hrimturs_pir1",4,"A"},{"Hrimturs_pir1",4,"A"},{"Bident_pir1",3,"A"},{"Bident_pir1",3,"A"},{"Trident_pir1",4,"M"}}, {{"Hrimturs_pir2",5,"A"},{"Hrimturs_pir2",4,"A"},{"Hrimturs_pir1",4,"A"},{"Hrimturs_pir1",3,"A"},{"EvilEye_pir3",4,"C"},{"Trident_pir1",4,"M"}}};
Gun_List_Unknown = { {"HC1","VC1","CG1","AC1"}, {"HC2","VC2","CG2","AC2"}, {"VC3","CG3","AC3"}};
Gun_List_Uss = { {"VC1","CG1","AC1"}, {"VC2","CG2","AC2"}, {"VC3","VC4","CG3","CG4"}};
Gun_List_Triada = { {"VC1","PLC1","PC1","AC1"}, {"VC2","PLC2","PC2","AC2"}, {"VC3","PLC3","PC3","VC4","AC3","AC4"}};
Gun_List_InoCo = { {"LC1","PLC1","RG1"}, {"LC2","PLC2","RG2"}, {"LC3","LC4","PLC3","RG3"}};
Gun_List_Vks = { {"HC1","VC1","PLC1","PC1","RG1","CG1","AC1"}, {"HC2","VC2","PLC2","PC2","RG2","CG2","AC2"}, {"HC3","VC3","CG3","AC3"}};
Gun_List_Kfni = { {"HC1","VC1","PLC1","CG1","AC1"}, {"HC2","VC2","PLC2","CG2","AC2"}, {"HC3","VC3","CG3","AC3","HC4","VC4","CG4","AC4"}};
Gun_List_Uft = { {"HC2","VC2","LC1","PLC1","PC1","RG1","CG2","AC2"}, {"HC3","VC3","LC2","PLC2","PC2","RG2","CG3","AC3"}, {"HC4","VC4","LC3","PLC3","PC3","RG3","CG4","AC4"}};
Gun_List_Patrol = { {"HC1","VC1","PC1","CG1","AC1"}, {"HC2","VC2","PC2","CG2","AC2"}, {"HC3","VC3","PC3","CG3","AC3"}};
Syst_List = { "LRS2","LRS3", "ECM2","ECM3","AMS2","AMS3", "Stealth2","Stealth3","CloD1","CloD2", "LRRNB2","LRRNB3", "RNBot2","RNBot3", "RBot2","RBot3", "ShAmp3","ShAmp4", "EngBoost2","EngAmp2","EngAmp3","ManAmp2", "WBoost2","WBoost3","GunAmp2", "ALS1","ALS2"};
Location_SideList = { aurora = "Vks", argon = "Vks", ahilles = "Kfni", vulcan = "Inoco", gefest = "Kfni", golkonda = "Triada", debris1 = "Neutral", debris2 = "Neutral", debris3 = "Triada", debris4 = "Uss", debris6 = "Triada", callipso = "Vks", corrino = "Vks", kron = "Vks", pegas = "Neutral", poseidon = "Vks", haron = "Neutral", gredos = "Vks", dionis = "Kfni", kruger = "Vks", llanovar1 = "Kfni", llanovar2 = "Kfni", nk = "Kfni", pandora = "Neutral", proserpina = "Kfni", simeiz = "Kfni", solpuga = "Kfni", torr = "Kfni", elinor = "Kfni", elio = "Kfni", endoria1 = "Vks", endoria2 = "Vks", escaflon = "Vks", valensia = "Kfni", kassilia = "Kfni", avalon = "Kfni", gideon = "Kfni", fort_russ = "Vks", moscowia = "Vks", solncevka = "Vks", nd = "Vks", angarsk = "Kfni", xk10 = "Inoco", altair = "Vks", altrabon = "Vks", ashelon = "Inoco", b_leftera1 = "Triada", b_leftera2 = "Triada", b_leftera3 = "Triada", ergelan = "Uss", kadi = "Vks", nj1 = "Vks", nj2 = "Vks", nj3 = "Vks", prien = "Vks", sunji = "Uss", taira = "Vks", hafa = "Inoco", shula = "Vks", eridan = "Kfni", vuadil = "Uss", hanoi = "Vks", alzed = "Neutral", el_ariash = "Uss", xk16 = "Vks", xt05 = "Triada", xt11 = "Uss", xt17 = "Neutral", xt20 = "Neutral", xt23 = "Neutral", xt24 = "Neutral", xt26 = "Neutral", xt27 = "Neutral", xt39 = "Triada", xt41 = "Vks", xt45 = "Triada", xt52 = "Triada", xt54 = "Neutral", xt81 = "Vks", xt86 = "Vks", xt93 = "Triada", xb13 = "Uss", xb15 = "Uss", xb17 = "Neutral", xb19 = "Neutral", dalled = "Uss", deosis = "Uss", dosis = "Triada", kadenoa = "Uss", kondel = "Triada", kitaro = "Triada", ule = "Triada", fiasar = "Uss", fronn = "Triada", kadenoa_tri = "Triada", areko = "Inoco", gaeon = "Inoco", gaoba = "Inoco", danstag = "Inoco", lasad = "Inoco", lidau = "Inoco", tarrot = "Neutral", farles = "Inoco", heos = "Inoco", zebos = "Inoco", egleon = "Inoco", x220 = "Neutral", x203 = "Neutral", x213 = "Neutral", x244 = "Neutral", x297 = "Neutral", precursors = "Neutral", disonsphere = "Neutral", earth = "Neutral"};
ShopList_Trader = {"trader1", "trader2", "trader3", "trader4", "trader5", "trader6", "trader7", "trader8", "trader9", "trader10", "trader11", "trader12"};
]], "DATA/Scripts/include/FloodTradeStations.script");
	-- DockStation.script 173-238 and CostOfPirates.script InitExpForSaved/ExpForSaved, reduced to records.
	dostring([[
function __TradeStation_Action(param)
	if param == "" then _param = GetCurrentLocation(); else _param = param; end;
	ShowMsgBox("#UI_TradeStationWndCaption", "#UI_TradeStationDockRequest", __TradeStationDock_Ok, __TradeStationDock_Cancel);
end;
function __TradeStationDock_Ok()
	HOST().trade_ok = HOST().trade_ok + 1;
	local f = GetPlayerMotherShip():GetPilot():GetFlight();
	f:Stop();
	UpdateTradeSystem(FALSE);
	TradeStationDlg(_param);
end;
function __TradeStationDock_Cancel() end;
function __PSDock_Action(param)
	if param == "" then _param = GetCurrentLocation(); else _param = param; end;
	ShowMsgBox("#UI_PatrolStationWndCaption", "#UI_PatrolStationDockRequest", __PatrolStationDock_Ok, __PatrolStationDock_Cancel);
end;
function __PatrolStationDock_Ok()
	HOST().patrol_ok = HOST().patrol_ok + 1;
	InitExpForSaved(_param);
	if GetLocationTeam(_param) == "Neutral" then PatrolStationDlg("DialogSystem"); else PatrolStationDlg(); end;
	ExpForSaved();
end;
function __PatrolStationDock_Cancel() end;
function InitExpForSaved(param) saved_expirience = 0.0; _current_location_COP = param; end;
function ExpForSaved() if saved_expirience > 0.05 then AddPlayerExperience(saved_expirience); end; end;
]], "DATA/Scripts/include/DockStation.script");
	-- v1: faction, recruit, robot and cargo tables (host_v1_tables.lua, from Create_flight_2.script).
	local f = openfile(HOST().tests.."host_v1_tables.lua", "r");
	if f then
		local src = read(f, "*a");
		closefile(f);
		dostring(src, "DATA/Scripts/include/Create_flight_2.script");
	end;
	-- Create_flight_2.script NewPiratesFlight / NewPirateFlight (671-689), as in the game: redefined by every
	-- MapInitialization (system.lst), so trf_nest's TRF_InstallNest wraps this run's function (design/nest-spec.md 9).
	-- HOST().npf counts the calls that reached the builder.
	dostring([[
function NewPiratesFlight(group, sign, location, type, power, orient)
  return NewPirateFlight(group, sign, location, type, power, orient);
end;
function NewPirateFlight(group, sign, location, type, power, orient)
	HOST().npf = (HOST().npf or 0) + 1;
	if (type==1) then
		return NewAllFlight(Pir_Pilots, Pir_Fighters, group, sign, location, power, orient);
	elseif (type==2) then
		return NewAllFlight(Pir_Pilots, Pir_Bombers, group, sign, location, power, orient, "shipFormationClaw");
	elseif (type==3) then
		local flight=NewAllFlight(Pir_Pilots, Pir_BigShips, group, sign, location, power, orient);
		FillCargoFlight(flight, Pir_CargoType, power, 30, 3);
		return flight;
	else
		LOG("bad flight type");
		return FALSE;
	end;
end;
]], "DATA/Scripts/include/Create_flight_2.script");
	-- v1: DockStation.script 1-20, 403-470, 562-603 (relation station, pirate dock) and Create_flight_2.script
	-- NewFlight / NewRobotFlight, reduced to records: HOST().cst (relation docks run), pir_ok (pirate dock Ok).
	dostring([[
_tab_sid = {
	{"Kfni","KFNI_AllowChange","ans00","ans000",700000,"New Empire"},
	{"Vks","VKS_AllowChange","ans01","ans001",650000,"MSF"},
	{"Triada","Triada_AllowChange","ans02","ans002",850000,"Triada"},
	{"Uss","USS_AllowChange","ans03","ans003",800000,"USS"},
	{"Inoco","InoCo_AllowChange","ans04","ans004",900000,"InoCo"},
	{"Hunter","Hunter_AllowChange","ans07","ans007",600000,"Border Sector"},
	{"Guard","Merc_AllowChange","ans08","ans008",750000,"mercenaries"},
	{"Trade","Trade_AllowChange","ans09","ans009",950000,"FTU"}};
DialogList_Rep = {"DialogC1","DialogC2","DialogC3","DialogC4","DialogC5","DialogC6","DialogC7","DialogC8"};
ShopList_Kontraband = {"pirate1", "pirate2", "pirate3", "pirate4", "pirate5", "pirate6", "pirate7"};
function CStation_Action(param)
	tinsert(HOST().cst, param);
	_param = param;
	ShowMsgBox("#UI_StationC_confirm", "#UI_StationC_dock", OnCStationStart, OnCStationCancel);
end;
function OnCStationCancel() end;
function OnCStationStart() StartTradeDialog(DialogList_Rep[tonumber(_param)] or "DialogC1"); end;
function _temp_change(nameAI)
	local N = GetPlayerCredits();
	local moneyAI = 0;
	for i, _x in _tab_sid do if _x[1] == nameAI then moneyAI = _x[5]; end; end;
	local tip = tonumber(_param);
	if (tip == 1) or (tip == 5) then moneyAI = 0; end;
	if N >= moneyAI then
		SetInitTeamRelation(PLAYER_TEAM, nameAI, RELATION_NEUTRAL);
		SetGroupRelation(nameAI.."Group_1", PLAYER_GROUP, RELATION_NEUTRAL);
		SubPlayerCredits(moneyAI);
		OutputToScreenLog("#UI_CStationOk", 7);
	else
		OutputToScreenLog("#UI_CStationNot", 7);
	end;
end;
function CreatePirateStationDocking(__PirateStation, ship, radius, param1, boolUseRadius)
	local boolUse = boolUseRadius or FALSE;
	local rd = radius or 110;
	if boolUse == FALSE then rd = 5; end;
	if (__PirateStation) then
		local xyz_st = Vector3(0, 0, 0);
		if (boolUse == FALSE) then xyz_st = __PirateStation:GetDockingPosition(); else xyz_st = __PirateStation:GetPosition(); end;
		CreateDocking("__PirDock_Action", xyz_st, ship, rd, param1 or "", __PirateStation);
	end;
end;
function __PirDock_Action(param)
	if (param == "") then _param = ShopList_Kontraband[RAND(getn(ShopList_Kontraband)) + 1]; else _param = param; end;
	ShowMsgBox("#UI_StationC_confirm", "#UI_StationC_dock", __PirStationDock_Ok, __PirStationDock_Cancel);
end;
function __PirStationDock_Ok()
	HOST().pir_ok = HOST().pir_ok + 1;
	UpdateTradeSystem(FALSE);
	SetTraderFlag(TRUE);
	TradeStationDlg(_param);
end;
function __PirStationDock_Cancel() end;
]], "DATA/Scripts/include/DockStation.script");
	dostring([[
function NewFlight(group, sign, carcas, pil, location, orient2, formation)
	local grp = getglobal(group);
	if not grp then return FALSE; end;
	local flight = grp:CreateFlight("flight_"..sign);
	setglobal("flight_"..sign, flight);
	local ship = CreateCarcass(carcas, location, orient2 or Vector3(0, 0, 1));
	local pilot = CreatePilot(pil);
	ship:AssignPilot(pilot);
	flight:AddShip(ship);
	setglobal("ship_"..sign.."_1", ship);
	setglobal("pilot_"..sign.."_1", pilot);
	flight:SetFormation(formation or "shipFormation");
	return flight;
end;
function NewRobotFlight(group, sign, location, type, power, orient)
	local level = power or 1;
	if level < 1 then level = 1; end;
	if level > 20 then level = 20; end;
	if type == 1 then return NewFlight(group, sign, Robot_Fighters[level][1][1], "AutoGun", location, orient); end;
	if type == 2 then return NewFlight(group, sign, Robot_Fighters2[level][1][1], "AutoGun", location, orient); end;
	return FALSE;
end;
]], "DATA/Scripts/include/Create_flight_2.script");
	-- OutOfMission.script 352-378 (the portal patrol fine and its exit), reduced to records: HOST().prava counts the
	-- vanilla exit, the fine box is the ShowMsgBox stub.
	dostring([[
function _PatrolGIBDD_shtraf()
	if (_f_PatrolGIBDD == 0) then
		if (__sys_SOS == FALSE) then
			local cost = floor(GetPlayerCredits() / 10);
			local str1 = CombineStr("#UI_PatrolGIBDD_cost", cost);
			SubPlayerCredits(cost);
			ShowMsgBox("#UI_PatrolGIBDD_confirm", str1, On_PatrolGIBDD_shtraf_Start);
		else
			Timer_Seq(10, _PatrolGIBDD_prava);
		end;
	else
		Timer_Seq(6, _PatrolGIBDD_prava);
	end;
end;
function On_PatrolGIBDD_shtraf_Start() Timer_Seq(1, _PatrolGIBDD_prava); end;
function _PatrolGIBDD_prava()
	HOST().prava = (HOST().prava or 0) + 1;
	local mship = GetPlayerMotherShip();
	local xyz_mship = mship:GetPosition();
	flight_pat_gibdd_1:Move(xyz_mship + Vector3(-100, 300, 100));
	Timer_Seq(10, _PatrolGIBDD_out);
end;
function _PatrolGIBDD_out() end;
]], "DATA/Scripts/include/OutOfMission.script");
	-- CostOfPirates.script 29-70 (CostOfHead with the station owner's own pilots at 0), unconditional and
	-- conditional enemy lists reduced to Pir_Pilots and the faction lists of host_v1_tables.lua.
	dostring([[
function _tempCost(_tab, _name)
	local ce = 0;
	for i, pn in _tab do
		if (pn == _name) then ce = (i * i) * 200; end;
	end;
	return ce;
end;
function CostOfHead(pilot_name, count)
	local price = 0;
	local curloc = GetLocationTeam(_current_location_COP);
	if (price == 0) then price = _tempCost(Pir_Pilots, pilot_name); end;
	if (price == 0) then price = _tempCost(USS_Pilots, pilot_name); end;
	if (price == 0) then price = _tempCost(Tri_Pilots, pilot_name); end;
	if (price == 0) then price = _tempCost(Ino_Pilots, pilot_name); end;
	if (price == 0) then price = _tempCost(Vks_Pilots, pilot_name); end;
	if (price == 0) then price = _tempCost(Kfni_Pilots, pilot_name); end;
	if (curloc == "Kfni") then
		if (_tempCost(Kfni_Pilots, pilot_name) > 0) then price = 0; end;
	elseif (curloc == "Vks") then
		if (_tempCost(Vks_Pilots, pilot_name) > 0) then price = 0; end;
	elseif (curloc == "Triada") then
		if (_tempCost(Tri_Pilots, pilot_name) > 0) then price = 0; end;
	elseif (curloc == "Uss") then
		if (_tempCost(USS_Pilots, pilot_name) > 0) then price = 0; end;
	elseif (curloc == "Inoco") then
		if (_tempCost(Ino_Pilots, pilot_name) > 0) then price = 0; end;
	end;
	return price;
end;
]], "DATA/Scripts/include/CostOfPirates.script");
end;

-- Trigger context of the action being run (GetTriggerContext); the generator's timer has SetTime/Activate.
function GetTriggerContext() return HOST().ctx; end;
HOST().gen_trig = {__obj=1, kind="generator", acts=0};
HOST().gen_trig.SetTime = function(self, t) HOST_Want(type(t) == "number", "Trigger:SetTime(seconds)"); self.time = t; end;
HOST().gen_trig.Activate = function(self) self.acts = self.acts + 1; self.on = 1; end;

-- One generator timer event: the engine looks the action up by its global name (AttachAction stores
-- "trigger_generator_Action") and runs it with the trigger as context.
function HOST_GenTick()
	local h = HOST();
	h.gen_trig.on = nil;
	h.ctx = h.gen_trig;
	trigger_generator_Action();
	h.ctx = nil;
	return h.gen_trig.on;
end;

-- include/NewTriggers.script NewTrigger, reduced to recording the trigger. The argument shapes per kind
-- follow its Set* calls and the game's callers: timer (seconds), f_inside (flight, Vector3, r),
-- f_object_inside (flight, object, r), died (object), f_died (flight), focus (object), attack (group name or
-- Group table, object; the object may be the mothership), inside (object, Vector3, r: the clan stash find trigger).
-- Conditions and actions must be named global functions or strings (AttachCondition/AttachAction, fact 1.14).
function NewTrigger(t, cond, func, v1, v2, v3, v4)
	local shape = {
		timer = function(a, b, c) return type(a) == "number"; end,
		f_inside = function(a, b, c) return HOST_IsFlight(a) and HOST_IsVec(b) and type(c) == "number"; end,
		inside = function(a, b, c) return HOST_IsObj(a) and HOST_IsVec(b) and type(c) == "number"; end,
		f_object_inside = function(a, b, c) return HOST_IsFlight(a) and HOST_IsObj(b) and type(c) == "number"; end,
		died = function(a, b, c) return HOST_IsObj(a); end,
		f_died = function(a, b, c) return HOST_IsFlight(a); end,
		focus = function(a, b, c) return HOST_IsObj(a); end,
		attack = function(a, b, c) return (type(a) == "string" or HOST_IsGroup(a)) and HOST_IsObj(b); end,
		HP = function(a, b, c) return HOST_IsObj(a) and type(b) == "number"; end
	};
	local ok = shape[t];
	HOST_Want(ok, "NewTrigger kind "..tostring(t).." known to the stub");
	if ok then HOST_Want(ok(v1, v2, v3), "NewTrigger "..t.." argument shapes"); end;
	HOST_Want(cond == nil or type(cond) == "function" or type(cond) == "string", "NewTrigger "..tostring(t).." condition type");
	HOST_Want(type(func) == "string" or type(func) == "function", "NewTrigger "..tostring(t).." action type");
	if not func then return nil; end;
	local tr = {__obj=1, kind=t, action=func, v1=v1, v2=v2, v3=v3};
	tr.GetFlight = function(self) return self.v1; end;
	-- Trigger methods as the action uses them on GetTriggerContext(): SetTime + Activate re-arm the fired
	-- trigger (RandomContacts.script trigger_generator_Action), Delete removes it (trigger_exit_point_Action).
	tr.SetTime = function(self, t) HOST_Want(type(t) == "number", "Trigger:SetTime(seconds)"); self.v1 = t; end;
	tr.Activate = function(self) HOST_Want(not self.deleted, "Trigger:Activate on a live trigger"); self.fired = nil; end;
	tr.Delete = function(self) HOST_Want(not self.deleted, "Trigger:Delete once"); self.deleted = 1; self.fired = 1; end;
	tinsert(HOST().triggers, tr);
	print("HOST NewTrigger "..t.." action="..tostring(func));
	return tr;
end;

-- True when a trigger's string action starts with pre (nil pre matches every trigger except the save kit's).
function HOST_Is(tr, pre)
	local saves = type(tr.action) == "string" and strsub(tr.action, 1, 14) == "TRF_Saves_Fire";
	if not pre then return not saves; end;
	return type(tr.action) == "string" and strsub(tr.action, 1, strlen(pre)) == pre;
end;

-- Run one trigger's action the way Trigger::OnEvent runs a string action, with the trigger as context.
function HOST_Run(tr)
	tr.fired = 1;
	print("HOST fire "..tr.kind.." action="..tostring(tr.action));
	local p = HOST().ctx;
	HOST().ctx = tr;
	if type(tr.action) == "string" then dostring(tr.action.."();"); else tr.action(); end;
	HOST().ctx = p;
end;

-- Fire the first pending trigger of a kind. pre selects triggers by action prefix; without it the save
-- kit's timers are left alone.
function HOST_Fire(kind, pre)
	local q = HOST().triggers;
	for i = 1, getn(q) do
		local tr = q[i];
		if not tr.fired and tr.kind == kind and HOST_Is(tr, pre) then
			HOST_Run(tr);
			return 1;
		end;
	end;
	print("HOST fire "..kind..": none pending");
	return nil;
end;

-- Fire every trigger pending now (kind nil = any kind) whose action starts with pre; returns the count.
function HOST_FireAll(kind, pre)
	local q = HOST().triggers;
	local run = {};
	for i = 1, getn(q) do
		local tr = q[i];
		if not tr.fired and (not kind or tr.kind == kind) and HOST_Is(tr, pre) then tinsert(run, tr); end;
	end;
	for i = 1, getn(run) do HOST_Run(run[i]); end;
	return getn(run);
end;

-- Script loading ------------------------------------------------------------------
-- config.script: TRF_EXP set -> the experiment config of install-test.sh; HOST().cfg set (traffic
-- scenarios) -> TRF_Config returns that table; else the repo file.
function ExecuteScriptFile(path)
	print("ExecuteScriptFile - "..path);
	local pre = "DATA/Scripts/Mods/Traffic/";
	if strsub(path, 1, strlen(pre)) ~= pre then return nil; end;
	local name = strsub(path, strlen(pre) + 1);
	local h = HOST();
	if name == "config.script" and h.cfg then
		dostring("function TRF_Config() return HOST().cfg; end");
		return 1;
	end;
	if name == "config.script" and h.exp then
		dostring(format("function TRF_Config() return {exp=%d, log=1, big=%d, del_on_jump=%d, autosave=%d} end", h.exp, h.big, h.del, h.autosave));
		return 1;
	end;
	local f = openfile(h.dir..name, "r");
	-- HOST().hide[name]: the file counts as missing (v1-a: v0.2 behaviour without the v1 files).
	if f and h.hide and h.hide[name] then closefile(f); f = nil; end;
	if not f then print("[ScriptSystem] cannot load script file "..path); return nil; end;
	closefile(f);
	if dofile(h.dir..name) then
		if name == "traffic.script" then HOST_WrapTick(); end;
		return 1;
	end;
	return nil;
end;

-- Wrap the freshly loaded TRF_OnTick so GetPlayerMotherShip can tell tick calls (HOST().in_tick).
function HOST_WrapTick()
	if type(TRF_OnTick) ~= "function" or TRF_OnTick == HOST_Tick then return; end;
	HOST().tick_fn = TRF_OnTick;
	TRF_OnTick = HOST_Tick;
end;

function HOST_Tick(a, b)
	local h = HOST();
	h.in_tick = (h.in_tick or 0) + 1;
	local r = call(h.tick_fn, {a, b});
	h.in_tick = h.in_tick - 1;
	return r;
end;

-- Engine emulation ----------------------------------------------------------------

function HOST_Count(kind, pre)
	local n = 0;
	local q = HOST().triggers;
	for i = 1, getn(q) do
		if q[i].kind == kind and HOST_Is(q[i], pre) then n = n + 1; end;
	end;
	return n;
end;

-- Triggers of a kind not deleted (a fired, not re-armed trigger still counts: the engine keeps it).
function HOST_Live(kind, pre)
	local n = 0;
	local q = HOST().triggers;
	for i = 1, getn(q) do
		if q[i].kind == kind and HOST_Is(q[i], pre) and not q[i].deleted then n = n + 1; end;
	end;
	return n;
end;

-- Save kit: timers created so far, timers still in the trigger list, AutoSave calls with a given text (or all).
function HOST_Armed() return HOST_Count("timer", "TRF_Saves_Fire"); end;
function HOST_Kit() return HOST_Live("timer", "TRF_Saves_Fire"); end;
function HOST_Saved(key)
	local n = 0;
	local q = HOST().autosaves;
	for i = 1, getn(q) do
		if not key or q[i] == key then n = n + 1; end;
	end;
	return n;
end;
function HOST_FireSave() return HOST_Fire("timer", "TRF_Saves_Fire"); end;
-- Fire the save timer, let the quiet window (10 s) pass, fire the quiet timer: the save of a clear system.
function HOST_FireSaveQuiet()
	if not HOST_FireSave() then return nil; end;
	HOST_Ticks(24, 0.5);
	HOST_FireSave();
	return 1;
end;

-- Reserved string keys (HOST_IsProtected) anywhere below t, as " path.key" entries.
function HOST_Reserved(t, path)
	local r = "";
	for k, v in t do
		if HOST_IsProtected(k) then r = r.." "..path.."."..k; end;
		if type(v) == "table" and not v.__obj then r = r..HOST_Reserved(v, path.."."..tostring(k)); end;
	end;
	return r;
end;

-- ClearGlobals 0x5c6c60: delete number/string/table globals that are not protected.
function HOST_ClearGlobals()
	local del = {};
	for k, v in globals() do
		local t = type(v);
		if (t == "number" or t == "string" or t == "table") and not HOST_IsProtected(k) then tinsert(del, k); end;
	end;
	foreachi(del, function(i, k) setglobal(k, nil); end);
	return getn(del);
end;

-- T3 around the location-entry clear.
function HOST_ClearWithCarry()
	if type(TRF) == "table" then _CLASS.__trf_carry = TRF; end;
	local n = HOST_ClearGlobals();
	TRF = _CLASS.__trf_carry;
	_CLASS.__trf_carry = nil;
	return n;
end;

-- Save writer: numbers, strings and tables; string keys on the skip list are dropped at every level.
-- top (the globals): an engine handle is kept as the object itself. The game saves a handle global as its
-- {id=} table with the class tag (mod-options 1.10; vanilla's ship_<sign>_<i> survive a load). Handles
-- inside tables are dropped, so a handle in TRF still fails the tests.
function HOST_SaveCopy(t, top)
	local r = {};
	for k, v in t do
		local kt, vt = type(k), type(v);
		if (kt == "number" or kt == "string") and not HOST_IsProtected(k) then
			if vt == "number" or vt == "string" then r[k] = v;
			elseif vt == "table" and v.__obj then if top then r[k] = v; end;
			elseif vt == "table" then r[k] = HOST_SaveCopy(v); end;
		end;
	end;
	return r;
end;

-- Bytes the save writer would emit for value v (save-format.md 3: type code 4, number 8, string 4 + n,
-- table 03 .. 04 + tag; entries with a skipped key, a key other than number/string or a value other than
-- number/string/table are dropped). Engine handles count as tables here (none may be in TRF).
function HOST_SaveSize(v)
	local t = type(v);
	if t == "number" then return 12; end;
	if t == "string" then return 8 + strlen(v); end;
	if t ~= "table" then return 0; end;
	local n = 12;
	for k, x in v do
		local kt, xt = type(k), type(x);
		if (kt == "number" or (kt == "string" and not HOST_IsProtected(k))) and (xt == "number" or xt == "string" or xt == "table") then
			if kt == "number" then n = n + 12; else n = n + 8 + strlen(k); end;
			n = n + HOST_SaveSize(x);
		end;
	end;
	return n;
end;

-- MapInitialization: system.lst (the vanilla includes), then (T2a) Mods/Traffic/traffic.script.
-- HOST().st_label: the map cache gets st={{label=<label>, kind="trade"}} in every system (overrides gen_map.py); HOST().no_st: no st anywhere.
function HOST_MapInit()
	HOST_Includes();
	local ok = ExecuteScriptFile("DATA/Scripts/".."Mods/Traffic/traffic.script");
	local h = HOST();
	if (h.st_label or h.no_st) and type(TRF_Map) == "function" then
		local m = TRF_Map();
		if m then for i = 1, getn(m.sys) do if h.no_st then m.sys[i].st = nil; else m.sys[i].st = {{label=h.st_label, kind="trade"}}; end; end; end;
	end;
	return ok;
end;

-- Location entry: clear (+T3), MapInitialization, functions.script (T2b), activate.script (T2c).
function HOST_Enter(dest)
	local h = HOST();
	h.last = h.loc; h.loc = dest;
	print("HOST ---- enter "..dest.." (cleared "..HOST_ClearWithCarry().." globals)");
	HOST_MapInit();
	TRF_OnEnter();
	Trade_Group_1 = HOST_Group("Trade_Group_1");
	TRF_OnActivate();
end;

function HOST_Ticks(n, dt)
	for i = 1, n do
		HOST().gt = HOST().gt + dt; HOST().rt = HOST().rt + dt;
		TRF_OnTick(dt, dt);
	end;
end;

-- 4 when the traffic modules are loaded (v4 TRF, v1-spec 3.1), else 1.
function HOST_V()
	if type(TRF_State_Tick) == "function" then return 4; end;
	return 1;
end;

if H.scen then
	print("HOST ==== traffic scenario "..H.scen.." dir="..H.dir);
	dofile(H.tests.."host_traffic.lua");
	if strsub(H.scen, 1, 4) == "v02-" or strsub(H.scen, 1, 3) == "v1-" then dofile(H.tests.."host_v02.lua"); end;
	if strsub(H.scen, 1, 3) == "v1-" then dofile(H.tests.."host_v1.lua"); end;
	HOST_Check((H.gpm_tick or 0) == 0, "no GetPlayerMotherShip from a tick (n="..tostring(H.gpm_tick or 0)..")");
	print("HOST errors="..H.errors.." fails="..H.fails);
	if H.errors > 0 or H.fails > 0 then exit(1); end;
	exit(0);
end;

-- Scenario ------------------------------------------------------------------------
local h = HOST();
print("HOST ==== exp="..tostring(h.exp).." big="..h.big.." del="..h.del.." dir="..h.dir);

-- Globals before the first load, to check that top level defines functions only.
HOST_Includes();
local before = {};
for k, v in globals() do before[k] = 1; end;
local vga = trigger_generator_Action;
HOST_Check(ExecuteScriptFile("DATA/Scripts/Mods/Traffic/traffic.script"), "traffic.script loads");
local bad = "";
for k, v in globals() do
	if not before[k] then
		if type(v) ~= "function" then bad = bad.." "..k.."("..type(v)..")";
		elseif strsub(k, 1, 4) ~= "TRF_" then bad = bad.." "..k.."(no TRF_ prefix)"; end;
	end;
end;
HOST_Check(bad == "", "top level defines only TRF_ functions"..bad);
HOST_Check(TeleportToLocation == TRF_Wrap_Teleport and TRF_orig_TeleportToLocation == HOST_TeleportToLocation, "TeleportToLocation wrapped once");
-- logfmt helpers (design/log-format.md 5).
HOST_Check(TRF_KvV("abc") == "abc" and TRF_KvV("a b") == '"a b"' and TRF_KvV('say "hi"') == '"say \\"hi\\""'
	and TRF_KvV("k=v") == '"k=v"' and TRF_KvV(nil) == "nil" and TRF_KvV(2.5) == "2.5" and TRF_KvV(3) == "3"
	and TRF_KvV("") == '""' and TRF_KvV({1}) == '"{1=1}"', "TRF_KvV: bare, quoted (space, =, escaped quote, empty), nil, number, table");
HOST_Check(TRF_Kv("a", 1, "b", nil, "c", "x y") == 'a=1 b=nil c="x y"' and TRF_Kv("k") == "k=nil" and TRF_Kv() == "",
	"TRF_Kv: nil in the middle kept, odd key =nil, empty");
HOST_Check(TRF_KvB(1) == "true" and TRF_KvB(TRUE) == "true" and TRF_KvB(0) == "false" and TRF_KvB(nil) == "false", "TRF_KvB: 1/TRUE true, 0/nil false");
h.logs = {};
TRF_Lf("core", "host_check", "a", 1, "b", nil);
TRF_Lf("core", "host_bare");
HOST_Check(getn(h.logs) == 2 and strfind(h.logs[1], "^exp=[^ ]+ module=core event=host_check a=1 b=nil$")
	and strfind(h.logs[2], "^exp=[^ ]+ module=core event=host_bare$"), "TRF_Lf: exp= first, then module=core event=, then the pairs");
h.logs = nil;
-- v0.1 modules: loaded with exp 0 only (spec 10.1, decision 20); the generator thunk replaces the vanilla action.
if (h.exp or 0) == 0 then
	HOST_Check(HOST_V() == 4 and type(TRF_InstallGen) == "function" and type(TRF_Events_Step) == "function", "exp 0 loads the traffic modules");
	HOST_Check(type(TRF_RegionTick) == "function" and type(TRF_BuildFlight) == "function" and type(TRF_RaidRoll) == "function"
		and type(TRF_ShopOpen) == "function" and type(TRF_OnHail) == "function", "exp 0 loads the v0.2 modules (region, tier, raid, shop, hail)");
	HOST_Check(TRF_orig_GenAction == vga and trigger_generator_Action ~= vga and TRF_IsMine(trigger_generator_Action) and not TRF_IsMine(vga), "generator thunk installed, original kept");
else
	HOST_Check(HOST_V() == 1 and TRF_InstallGen == nil and trigger_generator_Action == vga, "exp "..h.exp.." loads no traffic module and keeps the vanilla generator");
end;

-- Second MapInitialization in the same process (menu -> new game): no double wrap.
HOST_ClearGlobals();
HOST_MapInit();
HOST_Check(TRF_orig_TeleportToLocation == HOST_TeleportToLocation and TRF_orig_CustomTeleportate == HOST_CustomTeleportate, "no double wrap after a second load");
if HOST_V() == 4 then
	HOST_Check(TRF_orig_GenAction ~= vga and not TRF_IsMine(TRF_orig_GenAction) and TRF_IsMine(trigger_generator_Action), "generator re-wrapped around the redefined vanilla action");
end;

TRF_OnTick(0.5, 0.5);
HOST_Check(TRF == nil, "OnTick before OnEnter leaves TRF nil");

-- New game: first entry.
HOST_Enter("gredos");
HOST_Check(type(TRF) == "table" and TRF.active == 1 and TRF.version == HOST_V(), "OnEnter creates TRF (v"..HOST_V()..")");
HOST_Ticks(12, 0.5);
if h.autosave > 0 then HOST_Check(HOST_Armed() == 0, "saves: first system arms no save"); end;
HOST_Check(TRF.clock.gt == 6 and TRF.clock.real == 6 and TRF.clock.game == nil, "OnTick accumulates the clock (gt="..tostring(TRF.clock.gt).." real="..tostring(TRF.clock.real)..")");
if h.exp == 1 then
	HOST_Check(type(TRF.exp.hooks) == "table" and TRF.exp.hooks.ticks == 12 and TRF.exp.hooks.prec == 1, "E0.1 hooks dispatched (12 ticks)");
elseif h.exp == 2 then
	HOST_Check(type(TRF.exp.state) == "table" and TRF.exp.state.n == 1, "E0.2 OnEnter dispatched (n=1)");
elseif h.exp == 3 then
	HOST_Check(type(TRF.exp.trader) == "table" and TRF.exp.trader.seq == 1 and TRF_Live()[1] ~= nil, "E0.3 OnActivate dispatched (trader 1 live)");
else
	HOST_Check(TRF_Exp_OnEnter == nil and TRF_Exp_OnTick == nil, "exp 0 defines no experiment hooks");
end;

if h.exp == 3 then
	HOST_Fire("f_object_inside");   -- trader 1 at the station
	HOST_Fire("f_inside");          -- trader 1 at the dock point: second arrival, ignored
	HOST_Check(HOST_Count("timer") == 1, "one dwell timer for two arrival triggers");
	HOST_Fire("timer");             -- dwell over: ComeToPortal + exit trigger
	HOST_Fire("attack");            -- player attacks trader 1
	HOST_Fire("f_object_inside");   -- trader 1 at the exit portal: deleted, trader 2 spawns
	HOST_Fire("f_object_inside");   -- trader 2 at the station
	HOST_Check(HOST_Count("timer") == 1, "trader 2 (stay) arms no dwell timer");
	HOST_Ticks(12, 0.5);
end;

-- Jump through the wrapper, then through the T3-carried clear.
TeleportToLocation("elio");
HOST_Check(h.jumped == "elio" and TRF.active == nil, "wrapper calls BeforeJump and the original");
TRF_BeforeJump("x");
h.labels.CurrentQuest = "2";    -- past mission 1
HOST_Enter("elio");
HOST_Check(TRF.exp.cnt.enter == 2, "TRF carried across the clear (enter=2)");
if h.autosave > 0 then HOST_Check(HOST_Armed() == 1 and TRF.exp.saves.elio.st == 1, "saves: second system arms one timer"); end;
CustomTeleportate("elio", "gredos", "long_jump");
-- Block the farthest portal's entry point so the next spawn has to fall back to PORTAL L.
CreateCarcass("Blocker", HOST().objs["PORTAL D"]:GetEntryPoint(10), Vector3(0, 0, 1));
HOST_Check(h.jumped == "gredos", "CustomTeleportate wrapper passes 3 args");
HOST_Enter("gredos");
if h.autosave > 0 then HOST_Check(HOST_Armed() == 2 and HOST_Saved() == 0, "saves: third system armed, nothing saved yet"); end;

-- Save, quit, load: clear, MapInitialization, clear (0x4a7e70), restore, functions.script (T2d).
local rk = HOST_Reserved(TRF, "TRF");
if h.exp == 2 then
	HOST_Check(rk == " TRF.exp.state.PI", "only the deliberate reserved key in TRF before the save:"..rk);
else
	HOST_Check(rk == "", "no reserved key in TRF before the save"..rk);
end;
local save = HOST_SaveCopy(globals(), 1);
HOST_ClearGlobals();
HOST_MapInit();
HOST_ClearGlobals();
for k, v in save do rawset(globals(), k, v); end;
TRF_OnLoad();
HOST_Check(TRF.exp.cnt.load == 1, "OnLoad sees the restored TRF");
if h.exp == 2 then
	HOST_Check(TRF.exp.state.PI == nil and TRF.exp.state.n == 3, "save drops nested PI, keeps n=3");
end;
if h.exp == 3 then
	HOST_Fire("f_died");            -- trigger restored from the save: stale id
end;
if h.autosave > 0 then
	HOST_FireSave();                -- elio timer restored from the save
	HOST_FireSave();                -- gredos timer restored from the save
	HOST_Check(HOST_Saved() == 0, "saves: timers restored from a save are stale");
	HOST_Check(HOST_Kit() == 0, "saves: stale timers delete themselves ("..HOST_Kit().." left)");
end;
HOST_Ticks(4, 0.5);
HOST_Check(HOST_Reserved(TRF, "TRF") == "", "no reserved key in TRF after the load");
print("HOST TRF = "..TRF_Dump(TRF, 5));

-- Load of a save made without the mod: TRF is nil when OnLoad runs.
HOST_ClearGlobals();
HOST_MapInit();
HOST_ClearGlobals();
TRF_OnLoad();
HOST_Check(type(TRF) == "table" and TRF.active == 1 and TRF.exp.cnt.load == 1 and TRF.clock.gt == 0 and TRF.version == HOST_V(), "OnLoad creates TRF for a save without it");

-- Load of a save whose TRF has another layout (the mod-options 7.2 table, clock a number).
HOST_ClearGlobals();
HOST_MapInit();
HOST_ClearGlobals();
TRF = {version=1, n=4, s="x", t={1, 2, {3}}, clock=0};
TRF_OnLoad();
HOST_Ticks(2, 0.5);
HOST_Check(TRF.n == 4 and TRF.clock.gt == 1 and TRF.clock.real == 1 and TRF.active == 1 and TRF.version == HOST_V(), "OnLoad repairs a pre-set TRF and keeps its data");
-- A Phase 0 (v1) save with clock.game: the game time moves to clock.gt.
HOST_ClearGlobals();
HOST_MapInit();
HOST_ClearGlobals();
TRF = {version=1, active=1, gen=3, clock={game=40, real=2}, exp={cnt={enter=5}}};
TRF_OnLoad();
HOST_Check(TRF.clock.gt == 40 and TRF.clock.game == nil and TRF.gen == 4 and TRF.exp.cnt.enter == 5 and TRF.version == HOST_V(), "v1 save: clock.game -> clock.gt, gen + 1, exp kept");
TRF_BeforeJump("x");
HOST_Check(TRF.active == nil, "BeforeJump clears TRF.active on the repaired TRF");
TRF = {};
TRF_OnTick(0.5, 0.5);
TRF_BeforeJump("x");
HOST_Check(TRF.active == nil and TRF.exp.cnt.jump == 1, "OnTick ignores and BeforeJump survives an empty TRF");

-- Save kit over a new game: one AutoSave per new system, never two for the same one, at most 6.
if h.autosave > 0 then
	print("HOST ---- save kit, new game");
	TRF = nil; h.triggers = {}; h.autosaves = {}; h.labels.CurrentQuest = nil;
	HOST_Enter("aurora");
	HOST_Check(HOST_Armed() == 0, "saves: new game's first system arms no save");
	HOST_Enter("elio");
	if h.autosave == 1 then HOST_Check(HOST_Armed() == 0, "saves: mission 1 (CurrentQuest unset) arms no save"); end;
	h.labels.CurrentQuest = "2";
	HOST_Enter("gredos");
	HOST_FireSaveQuiet();
	HOST_Check(HOST_Saved("TRF E0 gredos") == 1 and HOST_Saved() == 1, "saves: AutoSave once for gredos");
	HOST_Check(not HOST_FireSave(), "saves: the timer is one-shot");
	HOST_Check((h.autosave ~= 1 or HOST_Armed() == 1) and HOST_Kit() == 0, "saves: the gredos trigger re-armed for the quiet window and deleted at the save");
	HOST_Enter("elio");
	TeleportToLocation("aurora");   -- jump before the timer fires
	HOST_FireSave();
	HOST_Check(HOST_Saved() == 1, "saves: a timer that fires during a jump does nothing");
	HOST_Enter("aurora");
	HOST_FireSaveQuiet();
	HOST_Check(HOST_Saved("TRF E0 aurora") == 1, "saves: AutoSave once for aurora");
	local armed = HOST_Armed();
	HOST_Enter("gredos");
	HOST_Check(HOST_Armed() == armed and not HOST_FireSave() and HOST_Saved("TRF E0 gredos") == 1, "saves: no second save for gredos");
	foreachi({"s1", "s2", "s3", "s4", "s5", "s6"}, function(i, s) HOST_Enter(s); HOST_FireSaveQuiet(); end);
	HOST_Check(HOST_Saved() == 6 and HOST_Saved("TRF E0 s5") == 0 and HOST_Saved("TRF E0 s4") == 1, "saves: capped at 6 ("..HOST_Saved()..")");
	HOST_Check(HOST_Kit() == 0, "saves: no kit trigger left after the new game ("..HOST_Kit()..")");
	local want = "";
	if h.exp == 2 then want = " TRF.exp.state.PI"; end;
	HOST_Check(HOST_Reserved(TRF, "TRF") == want, "saves: no reserved key in TRF.exp.saves");
	print("HOST TRF.exp.saves = "..TRF_Dump(TRF.exp.saves, 3));

	-- Cutscene guard: a mission movie sets __sys_SOS (_FTrader_exclude), DisableRandom __disableAction.
	print("HOST ---- save kit, cutscene guard");
	TRF = nil; h.triggers = {}; h.autosaves = {}; h.labels.CurrentQuest = nil;
	HOST_Enter("aurora");
	h.labels.CurrentQuest = "2";
	HOST_Enter("elio");
	__sys_SOS = TRUE;
	HOST_FireSave();
	local e = TRF.exp.saves.elio;
	HOST_Check(HOST_Saved() == 0 and e.st == 1 and e.try == 1 and HOST_Armed() == 1 and HOST_Kit() == 1, "saves: __sys_SOS defers and re-arms the same trigger");
	__sys_SOS = FALSE; __disableAction = TRUE;
	HOST_FireSave();
	HOST_Check(HOST_Saved() == 0 and e.try == 2 and HOST_Armed() == 1 and HOST_Kit() == 1, "saves: __disableAction defers and re-arms the same trigger");
	__disableAction = FALSE;
	HOST_FireSave();
	HOST_Check(HOST_Saved() == 0 and type(e.q) == "number" and HOST_Armed() == 1 and HOST_Kit() == 1, "saves: flags clear, quiet window armed on the same trigger");
	__sys_SOS = TRUE;
	HOST_Ticks(24, 0.5);
	HOST_FireSave();
	HOST_Check(HOST_Saved() == 0 and e.q == nil and e.try == 3, "saves: flags up in the quiet window clear it and count a retry");
	__sys_SOS = FALSE;
	HOST_FireSave();
	HOST_FireSave();
	HOST_Check(HOST_Saved() == 0 and e.try == 4 and e.st == 1, "saves: quiet window not over, no save");
	HOST_Ticks(24, 0.5);
	HOST_FireSave();
	HOST_Check(HOST_Saved("TRF E0 elio") == 1 and HOST_Saved() == 1 and e.st == 2, "saves: one AutoSave after the quiet window");
	HOST_Check(not HOST_FireSave() and HOST_Saved() == 1 and HOST_Armed() == 1 and HOST_Kit() == 0, "saves: no timer left after the save, the trigger deleted");
	HOST_Enter("gredos");
	__sys_SOS = TRUE;
	local n = 0;
	while HOST_FireSave() do n = n + 1; end;
	e = TRF.exp.saves.gredos;
	HOST_Check(n == 46 and e.st == 3 and e.try == 46 and HOST_Saved() == 1, "saves: gave up after 45 retries (fires="..n..")");
	HOST_Check(HOST_Armed() == 2 and HOST_Kit() == 0, "saves: 46 fires on one trigger, deleted at gave up (created "..HOST_Armed()..", left "..HOST_Kit()..")");
	HOST_Enter("elio");
	HOST_Enter("gredos");
	HOST_Check(TRF.exp.saves.gredos.st == 1 and TRF.exp.saves.gredos.try == nil, "saves: a later visit arms a system that gave up");
	HOST_FireSaveQuiet();
	HOST_Check(HOST_Saved("TRF E0 gredos") == 1 and HOST_Saved() == 2, "saves: later visit saves gredos");

	-- Movie guard: TRF_InMovie (1/0, -1 unknown), else MovieIsPlaying(); TRF_UiState modal/dialog flags.
	print("HOST ---- save kit, movie guard");
	TRF_InMovie = HOST_InMovie; MovieIsPlaying = HOST_MovieIsPlaying;
	h.mov = 1; h.mip = FALSE;
	HOST_Enter("aurora");
	e = TRF.exp.saves.aurora;
	HOST_FireSave();
	HOST_Check(HOST_Saved() == 2 and e.st == 1 and e.try == 1 and e.q == nil, "saves: TRF_InMovie() == 1 defers");
	h.mov = -1; h.mip = TRUE;
	HOST_FireSave();
	HOST_Check(HOST_Saved() == 2 and e.try == 2 and e.q == nil, "saves: TRF_InMovie() == -1 falls back to MovieIsPlaying() == TRUE, defers");
	TRF_InMovie = nil;
	HOST_FireSave();
	HOST_Check(HOST_Saved() == 2 and e.try == 3 and e.q == nil, "saves: no TRF_InMovie, MovieIsPlaying() == TRUE defers");
	TRF_InMovie = HOST_InMovie; h.mov = 0;
	HOST_FireSave();
	HOST_Check(HOST_Saved() == 2 and e.try == 3 and type(e.q) == "number", "saves: TRF_InMovie() == 0 wins over MovieIsPlaying(), quiet window armed");
	TRF_UiState = HOST_UiState; h.ui = 4;
	HOST_Ticks(24, 0.5);
	HOST_FireSave();
	HOST_Check(HOST_Saved() == 2 and e.try == 4 and e.q == nil, "saves: TRF_UiState() dialog flag defers");
	h.ui = 2;
	HOST_FireSave();
	HOST_Check(HOST_Saved() == 2 and e.try == 5 and e.q == nil, "saves: TRF_UiState() modal flag defers");
	h.mov = -1; h.mip = FALSE; h.ui = -1;
	HOST_FireSave();
	HOST_Check(HOST_Saved() == 2 and e.try == 5 and type(e.q) == "number", "saves: all clear (InMovie -1, MovieIsPlaying FALSE, UiState -1), quiet window armed");
	h.ui = 0;
	HOST_Ticks(24, 0.5);
	HOST_FireSave();
	HOST_Check(HOST_Saved("TRF E0 aurora") == 1 and HOST_Saved() == 3 and e.st == 2, "saves: one AutoSave after the movie and the dialog");
	HOST_Check(not HOST_FireSave() and HOST_Saved() == 3, "saves: no timer left after the movie-guard save");
	HOST_Check(HOST_Kit() == 0, "saves: no kit trigger left after the movie-guard save ("..HOST_Kit()..")");
	TRF_InMovie = nil; TRF_UiState = nil; MovieIsPlaying = nil;
	print("HOST TRF.exp.saves = "..TRF_Dump(TRF.exp.saves, 3));
end;
HOST_Check((h.gpm_tick or 0) == 0, "no GetPlayerMotherShip from a tick (n="..tostring(h.gpm_tick or 0)..")");
print("HOST errors="..h.errors.." fails="..h.fails);
if h.errors > 0 or h.fails > 0 then exit(1); end;
