-- Host harness for the traffic mod scripts under stock Lua 4.0.1 (no game, no DLL).
-- Emulates the engine parts the loader depends on: ExecuteScriptFile, ClearGlobals with the T3 carry,
-- the save writer's skip rule, string trigger callbacks (s.."();") and a few natives as stubs.
-- Env: TRF_DIR (mod script dir, trailing slash), TRF_EXP (0..3; unset = use the repo config.script),
-- TRF_BIG, TRF_DEL (config big / del_on_jump). Exit code 1 on any script error or failed check.

-- Host state lives in an upvalue: emulated ClearGlobals deletes table globals.
local H = {
	dir = getenv("TRF_DIR") or "./",
	exp = tonumber(getenv("TRF_EXP") or ""),
	big = tonumber(getenv("TRF_BIG") or "0"),
	del = tonumber(getenv("TRF_DEL") or "0"),
	errors = 0, fails = 0, gt = 0, rt = 0,
	loc = "gredos", last = "aurora",
	triggers = {}, ships = {}, nflight = 0,
	protected = {}, objs = {}
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
_EVENT_TIMER = 1; ROLE_ATTACK = 1; RELATION_WAR = 0;

-- 0x7acae8 list plus the engine-constant names used here.
function HOST_IsProtected(k)
	if type(k) ~= "string" then return nil; end;
	if HOST().protected[k] then return 1; end;
	if strfind(k, "^_EVENT_") or strfind(k, "^ROLE_") or strfind(k, "^RELATION_") then return 1; end;
	return nil;
end;
foreachi({"_CLASS", "PI", "_VERSION", "_INPUT", "_OUTPUT", "_STDERR", "_STDIN", "_STDOUT",
	"_script_error_output", "sys_IncludeFileList", "_script_path", "_script_error_filename",
	"TRUE", "FALSE", "PLAYER_TEAM", "PLAYER_GROUP", "PLAYER_MOTHERSHIP"},
	function(i, k) HOST().protected[k] = 1; end);

-- Natives -------------------------------------------------------------------------
function LOG(s) print("LOG: "..tostring(s)); end;
function SLOG(s) print("SLOG: "..tostring(s)); end;

function TRF_Version() return 1; end;
function TRF_GameTime() return HOST().gt; end;
function TRF_RealTime() return HOST().rt; end;
function TRF_Log(s)
	if type(s) ~= "string" and type(s) ~= "number" then print("traffic: TRF_Log bad argument"); return nil; end;
	print("traffic: lua: "..s);
end;

function GetCurrentLocation() return HOST().loc; end;
function GetLastLocation() return HOST().last; end;

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

function Vector3(x, y, z) return {x=x or 0, y=y or 0, z=z or 0}; end;

function HOST_Dist(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z;
	return sqrt(dx*dx + dy*dy + dz*dz);
end;

-- Map objects: portals and the trade station of the emulated system (same layout everywhere).
function HOST_Obj(label, x, y, z)
	local o = {__obj=1, label=label, pos=Vector3(x, y, z)};
	o.GetPosition = function(self) return Vector3(self.pos.x, self.pos.y, self.pos.z); end;
	o.GetOrientation = function(self) return Vector3(0, 0, 1); end;
	o.GetEntryPoint = function(self, d) return Vector3(self.pos.x, self.pos.y, self.pos.z + d); end;
	o.GetDockingPosition = function(self) return Vector3(self.pos.x + 40, self.pos.y, self.pos.z); end;
	o.Start = function(self, a, b) print("HOST Portal:Start "..self.label.." "..tostring(a)..","..tostring(b)); end;
	return o;
end;
HOST().objs["PORTAL L"] = HOST_Obj("PORTAL L", -1000, 0, 700);
HOST().objs["PORTAL D"] = HOST_Obj("PORTAL D", 200, 0, -900);
HOST().objs["TRADE STATION"] = HOST_Obj("TRADE STATION", 50, -30, -150);
function GetObjectByLabel(l) return HOST().objs[l]; end;

-- Argument shapes as the game scripts pass them (include/NewTriggers.script, Create_flight_2.script).
function HOST_IsVec(v) return type(v) == "table" and type(v.x) == "number" and type(v.y) == "number" and type(v.z) == "number"; end;
function HOST_IsFlight(v) return type(v) == "table" and v.AddShip ~= nil; end;
function HOST_IsObj(v) return type(v) == "table" and v.__obj ~= nil and v.GetPosition ~= nil; end;

-- A spot within 20 units of a live ship counts as blocked: CreateCarcass returns nil.
function CreateCarcass(tpl, pos, dir)
	HOST_Want(type(tpl) == "string" and HOST_IsVec(pos) and HOST_IsVec(dir), "CreateCarcass(template, Vector3, Vector3) "..tostring(tpl));
	local ships = HOST().ships;
	for i = 1, getn(ships) do
		if ships[i].alive and HOST_Dist(ships[i].pos, pos) < 20 then print("HOST CreateCarcass blocked"); return nil; end;
	end;
	local s = {__obj=1, tpl=tpl, pos=Vector3(pos.x, pos.y, pos.z), alive=1};
	s.AssignPilot = function(self, p) self.pilot = p; end;
	s.ComeToTradeStation = function(self, st) print("HOST ComeToTradeStation"); self.pos = st:GetDockingPosition(); end;
	s.ComeToPortal = function(self, p) print("HOST ComeToPortal "..p.label); self.pos = p:GetPosition(); end;
	-- IsAlive pushes 1 or nil (lint_lua.py NIL_NATIVES; the game tests it bare: "if (x:IsAlive()) then").
	s.IsAlive = function(self) if self.alive then return 1; end; return nil; end;
	s.GetPosition = function(self) return Vector3(self.pos.x, self.pos.y, self.pos.z); end;
	tinsert(HOST().ships, s);
	return s;
end;
-- The player arrived through PORTAL L and sits near it (not counted as a carcass here).
function GetPlayerMotherShip() return {__obj=1, GetPosition=function(self) return Vector3(-950, 0, 650); end}; end;
function CreatePilot(tpl) return {__obj=1, tpl=tpl}; end;

-- 0x5e68f0: at least 2 args, x/y/z read from arg 1, radius from arg 2.
function GetCarcassCountInSphere(pos, r)
	HOST_Want(HOST_IsVec(pos) and type(r) == "number", "GetCarcassCountInSphere(Vector3, radius)");
	local n = 0;
	local ships = HOST().ships;
	for i = 1, getn(ships) do
		if ships[i].alive and HOST_Dist(ships[i].pos, pos) <= r then n = n + 1; end;
	end;
	return n;
end;

function HOST_Group(name)
	local g = {__obj=1, name=name};
	g.CreateFlight = function(self, fname)
		local f = {__obj=1, name=fname, ships={}};
		f.AddShip = function(self, s) tinsert(self.ships, s); end;
		f.SetFormation = function(self, x) end;
		f.SetOrientation = function(self, x) end;
		f.IsAlive = function(self) if self.ships[1] and self.ships[1].alive then return 1; end; return nil; end;
		f.GetPosition = function(self) return self.ships[1]:GetPosition(); end;
		f.Delete = function(self) print("HOST Flight:Delete "..self.name); foreachi(self.ships, function(i, s) s.alive = nil; end); end;
		return f;
	end;
	return g;
end;

-- include/NewTriggers.script NewTrigger, reduced to recording the trigger. The argument shapes per kind
-- follow its Set* calls and the game's callers: timer (seconds), f_inside (flight, Vector3, r),
-- f_object_inside (flight, object, r), f_died (flight), attack (group, object). Conditions and actions
-- must be named global functions or strings (AttachCondition/AttachAction, fact 1.14).
function NewTrigger(t, cond, func, v1, v2, v3, v4)
	local shape = {
		timer = function(a, b, c) return type(a) == "number"; end,
		f_inside = function(a, b, c) return HOST_IsFlight(a) and HOST_IsVec(b) and type(c) == "number"; end,
		f_object_inside = function(a, b, c) return HOST_IsFlight(a) and HOST_IsObj(b) and type(c) == "number"; end,
		f_died = function(a, b, c) return HOST_IsFlight(a); end,
		attack = function(a, b, c) return a == PLAYER_GROUP and HOST_IsObj(b); end
	};
	local ok = shape[t];
	HOST_Want(ok, "NewTrigger kind "..tostring(t).." known to the stub");
	if ok then HOST_Want(ok(v1, v2, v3), "NewTrigger "..t.." argument shapes"); end;
	HOST_Want(cond == nil or type(cond) == "function" or type(cond) == "string", "NewTrigger "..tostring(t).." condition type");
	HOST_Want(type(func) == "string" or type(func) == "function", "NewTrigger "..tostring(t).." action type");
	if not func then return nil; end;
	local tr = {__obj=1, kind=t, action=func, v1=v1, v2=v2, v3=v3};
	tinsert(HOST().triggers, tr);
	print("HOST NewTrigger "..t.." action="..tostring(func));
	return tr;
end;

-- Fire the first pending trigger of a kind, the way Trigger::OnEvent runs a string action.
function HOST_Fire(kind)
	local q = HOST().triggers;
	for i = 1, getn(q) do
		local tr = q[i];
		if not tr.fired and tr.kind == kind then
			tr.fired = 1;
			print("HOST fire "..kind.." action="..tostring(tr.action));
			if type(tr.action) == "string" then dostring(tr.action.."();"); else tr.action(); end;
			return 1;
		end;
	end;
	print("HOST fire "..kind..": none pending");
	return nil;
end;

-- Script loading ------------------------------------------------------------------
function ExecuteScriptFile(path)
	print("ExecuteScriptFile - "..path);
	local pre = "DATA/Scripts/Mods/Traffic/";
	if strsub(path, 1, strlen(pre)) ~= pre then return nil; end;
	local name = strsub(path, strlen(pre) + 1);
	local h = HOST();
	if name == "config.script" and h.exp then
		dostring(format("function TRF_Config() return {exp=%d, log=1, big=%d, del_on_jump=%d} end", h.exp, h.big, h.del));
		return 1;
	end;
	local f = openfile(h.dir..name, "r");
	if not f then print("[ScriptSystem] cannot load script file "..path); return nil; end;
	closefile(f);
	if dofile(h.dir..name) then return 1; end;
	return nil;
end;

-- Engine emulation ----------------------------------------------------------------

function HOST_Count(kind)
	local n = 0;
	local q = HOST().triggers;
	for i = 1, getn(q) do
		if q[i].kind == kind then n = n + 1; end;
	end;
	return n;
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
function HOST_SaveCopy(t)
	local r = {};
	for k, v in t do
		local kt, vt = type(k), type(v);
		if (kt == "number" or kt == "string") and not HOST_IsProtected(k) then
			if vt == "number" or vt == "string" then r[k] = v;
			elseif vt == "table" and not v.__obj then r[k] = HOST_SaveCopy(v); end;
		end;
	end;
	return r;
end;

-- MapInitialization: system.lst, then (T2a) Mods/Traffic/traffic.script.
function HOST_MapInit()
	return ExecuteScriptFile("DATA/Scripts/".."Mods/Traffic/traffic.script");
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

-- Scenario ------------------------------------------------------------------------
local h = HOST();
print("HOST ==== exp="..tostring(h.exp).." big="..h.big.." del="..h.del.." dir="..h.dir);

-- Globals before the first load, to check that top level defines functions only.
local before = {};
for k, v in globals() do before[k] = 1; end;
HOST_Check(HOST_MapInit(), "traffic.script loads");
local bad = "";
for k, v in globals() do
	if not before[k] then
		if type(v) ~= "function" then bad = bad.." "..k.."("..type(v)..")";
		elseif strsub(k, 1, 4) ~= "TRF_" then bad = bad.." "..k.."(no TRF_ prefix)"; end;
	end;
end;
HOST_Check(bad == "", "top level defines only TRF_ functions"..bad);
HOST_Check(TeleportToLocation == TRF_Wrap_Teleport and TRF_orig_TeleportToLocation == HOST_TeleportToLocation, "TeleportToLocation wrapped once");

-- Second MapInitialization in the same process (menu -> new game): no double wrap.
HOST_ClearGlobals();
HOST_MapInit();
HOST_Check(TRF_orig_TeleportToLocation == HOST_TeleportToLocation and TRF_orig_CustomTeleportate == HOST_CustomTeleportate, "no double wrap after a second load");

TRF_OnTick(0.5, 0.5);
HOST_Check(TRF == nil, "OnTick before OnEnter leaves TRF nil");

-- New game: first entry.
HOST_Enter("gredos");
HOST_Check(type(TRF) == "table" and TRF.active == 1 and TRF.version == 1, "OnEnter creates TRF");
HOST_Ticks(12, 0.5);
HOST_Check(TRF.clock.game == 6 and TRF.clock.real == 6, "OnTick accumulates the clock (game="..tostring(TRF.clock.game).." real="..tostring(TRF.clock.real)..")");
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
HOST_Enter("elio");
HOST_Check(TRF.exp.cnt.enter == 2, "TRF carried across the clear (enter=2)");
CustomTeleportate("elio", "gredos", "long_jump");
-- Block the farthest portal's entry point so the next spawn has to fall back to PORTAL L.
CreateCarcass("Blocker", HOST().objs["PORTAL D"]:GetEntryPoint(10), Vector3(0, 0, 1));
HOST_Check(h.jumped == "gredos", "CustomTeleportate wrapper passes 3 args");
HOST_Enter("gredos");

-- Save, quit, load: clear, MapInitialization, clear (0x4a7e70), restore, functions.script (T2d).
local rk = HOST_Reserved(TRF, "TRF");
if h.exp == 2 then
	HOST_Check(rk == " TRF.exp.state.PI", "only the deliberate reserved key in TRF before the save:"..rk);
else
	HOST_Check(rk == "", "no reserved key in TRF before the save"..rk);
end;
local save = HOST_SaveCopy(globals());
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
HOST_Ticks(4, 0.5);
HOST_Check(HOST_Reserved(TRF, "TRF") == "", "no reserved key in TRF after the load");
print("HOST TRF = "..TRF_Dump(TRF, 5));

-- Load of a save made without the mod: TRF is nil when OnLoad runs.
HOST_ClearGlobals();
HOST_MapInit();
HOST_ClearGlobals();
TRF_OnLoad();
HOST_Check(type(TRF) == "table" and TRF.active == 1 and TRF.exp.cnt.load == 1 and TRF.clock.game == 0, "OnLoad creates TRF for a save without it");

-- Load of a save whose TRF has another layout (the mod-options 7.2 table, clock a number).
HOST_ClearGlobals();
HOST_MapInit();
HOST_ClearGlobals();
TRF = {version=1, n=4, s="x", t={1, 2, {3}}, clock=0};
TRF_OnLoad();
HOST_Ticks(2, 0.5);
HOST_Check(TRF.n == 4 and TRF.clock.game == 1 and TRF.clock.real == 1 and TRF.active == 1, "OnLoad repairs a pre-set TRF and keeps its data");
TRF_BeforeJump("x");
HOST_Check(TRF.active == nil, "BeforeJump clears TRF.active on the repaired TRF");
TRF = {};
TRF_OnTick(0.5, 0.5);
TRF_BeforeJump("x");
HOST_Check(TRF.active == nil and TRF.exp.cnt.jump == 1, "OnTick ignores and BeforeJump survives an empty TRF");
print("HOST errors="..h.errors.." fails="..h.fails);
if h.errors > 0 or h.fails > 0 then exit(1); end;
