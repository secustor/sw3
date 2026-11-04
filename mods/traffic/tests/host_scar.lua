-- Battle scars scenarios (design/scar-spec.md 9) under stock Lua 4.0.1: TRF_SC=a..g, run by run_host.sh as its own
-- entry point. a registration and sources 1-3 (Bust entry, Raids tick, off-screen sweep) with the pure rules (TT
-- rows, V_cap, cargo), b one scar per system (refresh once, kept), scar_cd, scar_max replacement order and the
-- scar_fight_max cap, c placement order, cargo and marker, the site rule and the site pick, a blocked spot, the
-- arrival line through the queue, d the reconcile table (orphan, hide, create, reuse, opened, shrink, expired), e
-- source 7 (the 3-deaths rule, a named fight end, the centroid at the jump, the move-away rule, the survivors link),
-- f gates and toggles (deny list, current system, chapter modes and the chapter 5 rule, guard, enable_scars,
-- enable_scar_loot, wind-down), g hulk death (trigger, poll, jump), load, dump, repair and TRF.scar at its bound.
-- Loads host_station.lua up to its first scenario, as host_survive.lua does. No new native stub: CreateCarcass,
-- SetObjectLabel, GetObjectByLabel, GetObjectLabel, ClearInventory, AddModuleToInventory, Delete, IsAlive,
-- CreateNavPoint and NewTrigger exist in host_stubs.lua.

local f = openfile((getenv("TRF_TESTS") or "./").."host_station.lua", "r");
if not f then print("HOST FAIL host_scar.lua: cannot open host_station.lua"); exit(1); end;
local src = read(f, "*a");
closefile(f);
local cut = strfind(src, "\n-- a: install (12.1, 6.1)", 1, 1);
if not cut then print("HOST FAIL host_scar.lua: marker '-- a: install (12.1, 6.1)' missing in host_station.lua"); exit(1); end;
dostring(strsub(src, 1, cut), "host_station.lua");

-- Helpers ----------------------------------------------------------------------------------

-- Config of these runs: the repo defaults with the entry events that would claim the slot or spawn on their own
-- turned off, survivors off (sc-e turns them on), crew remarks off (the scar line as trf_scar builds it; the age sentence
-- and the voice are host_remark.lua's rm-e), log 2, plus t.
function SC_Cfg(t)
	local c = {sweeps=0, feq=0, staged=0, seed=0, queue=0, parked=0, voice_events=0, dconv=0, carriers=0, po=0,
		enable_survivors=0, remarks=0, log=2};
	if t then for k, v in t do c[k] = v; end; end;
	return c;
end;

-- Scenario start in sys at chapter label ch.
function SC_Begin(sys, ch, t)
	local h = HOST();
	h.labels.CurrentQuest = ch or "9_1";
	h.quests = {};
	h.qs = FALSE;
	h.scsnap = {};
	h.block_r = 3;
	S_Begin(sys, SC_Cfg(t));
	TRF.scar = nil;
end;

-- Record fixture of system idx (defaults: an off-screen trader wreck, TT2, not placed), fields of t override.
function SC_Rec(idx, t)
	local r = {sys=idx, k=0, kind=1, fac=0, x=0, y=0, z=0, leg=TRF.clock.legs, ttl=12, on=0, mine=0, lv=2, seed=1234, nd=3, st=0,
		hid=0, scv=1, rec=1, nm=1, rf=0};
	if t then for k, v in t do r[k] = v; end; end;
	if type(TRF.scar) ~= "table" then TRF.scar = {}; end;
	tinsert(TRF.scar, r);
	return r;
end;

-- Live scar objects of sid (all scar objects when sid is nil), and the hulk.
function SC_Objs(sid)
	local n, q = 0, HOST().ships;
	local p = "TRF_SCAR_";
	if sid then p = "TRF_SCAR_"..sid.."_"; end;
	for i = 1, getn(q) do
		if q[i].alive and type(q[i].label) == "string" and strsub(q[i].label, 1, strlen(p)) == p then n = n + 1; end;
	end;
	return n;
end;
-- The hulk of sid in the scene, else in a system's snapshot (SC_Jump).
function SC_Hulk(sid)
	local h = HOST();
	local q = h.ships;
	for i = 1, getn(q) do if q[i].label == "TRF_SCAR_"..sid.."_H" then return q[i]; end; end;
	for k, l in h.scsnap or {} do
		for i = 1, getn(l) do if l[i].label == "TRF_SCAR_"..sid.."_H" then return l[i]; end; end;
	end;
	return nil;
end;

-- Live object with label l in the current scene, or nil.
function SC_Find(l)
	local o = HOST().objs[l];
	if o and o.alive then return o; end;
	return nil;
end;

-- Jump to sys; keep = 1 emulates the location snapshot: the scar objects of sys left alive on the last visit are
-- back in the scene (6.5; CHECK EW2.1), otherwise the scene starts without them.
function SC_Jump(sys, keep, pre)
	local h = HOST();
	TeleportToLocation(sys);
	local l = {};
	for i = 1, getn(h.ships) do
		local s = h.ships[i];
		if s.alive and type(s.label) == "string" and strsub(s.label, 1, 9) == "TRF_SCAR_" then tinsert(l, s); end;
	end;
	h.scsnap[h.loc] = l;
	h.last = h.loc; h.loc = sys;
	h.triggers = {}; h.ships = {}; h.screen = {}; h.msgs = {};
	if keep == 1 and h.scsnap[sys] then
		for i = 1, getn(h.scsnap[sys]) do if h.scsnap[sys][i].alive then tinsert(h.ships, h.scsnap[sys][i]); end; end;
	end;
	print("HOST ---- enter "..sys.." (cleared "..HOST_ClearWithCarry().." globals)");
	HOST_MapInit();
	T_Scene(sys);
	if pre then pre(); end;
	TRF_OnEnter();
	TRF_OnActivate();
end;

-- Deaths for source 7: a dead object at x, y, z of class c, through TRF_Sc_Dead.
function SC_Dead(c, x, z, fac, mine)
	local o = HOST_Obj("SCAR DEAD", x, 0, z);
	TRF_Sc_Dead(c, fac or 0, o, mine);
end;

-- One FTU trader on path C with no raid armed.
function SC_Trader()
	V_ClearTr();
	TRF.live.port = {};
	local id = T_Spawn("C");
	if id then V_NoRaid(id); end;
	return id;
end;

-- Trader id killed by others at x, y, z (no player attack event).
function SC_Kill(id, x, y, z)
	T_MoveTr(id, x, y, z);
	local hx = TRF_H().tr[id];
	for t = 1, getn(hx.tp) do
		hx.tp[t].alive = nil;
		HOST_Fire("died", "TRF_OnShipDied("..id..","..t..",");
	end;
end;

-- Record of system idx (TRF_Repair replaces the record tables at every entry and load, so a test re-reads it).
function SC_R(idx)
	local i, r = TRF_ScAt(idx);
	return r;
end;

-- A live ship next to every spot (CreateCarcass answers nil while block_r is large).
function SC_Block()
	local b = HOST_Obj("BLOCK", 0, 0, 0);
	b.kind = "ship";
	tinsert(HOST().ships, b);
end;

function SC_Kv(line, k)
	local a, b, v = strfind(line, " "..k.."=([^ ]*)");
	return v;
end;

-- Item names of a cargo list as "a,b,".
function SC_Names(l)
	local s = "";
	for i = 1, getn(l) do s = s..l[i].i..","; end;
	return s;
end;

-- a: registration, sources 1-3, pure rules ----------------------------------------------------------

function T_SC_A()
	local h = HOST();
	SC_Begin("gaoba", "9_1");
	-- design/strength-spec.md 5.6: trf_str counts as an extra module (12 -> 13).
	-- design/fits-spec.md 7: trf_fits counts as an extra module (13 -> 14).
	HOST_Check(S_Logs(0, "module=core event=loaded map=true module_count=18 extra_count=22") >= 1, "trf_scar loads after trf_charter (extra_count=22 with trf_captain, trf_stash, trf_freight, trf_haunt, trf_parcel, trf_merc, trf_wq, trf_warn and trf_remark)");
	local ml = TRF_ModList();
	HOST_Check(ml[getn(ml) - 14] == "Sc" and type(TRF_Sc_TuneDef) == "function" and TRF_Opt("enable_scars") == 1 and TRF_Opt("enable_scar_loot") == 1
		and TRF_Opt("enable_scavengers") == 1 and TRF_Opt("enable_scar_recorder") == 1 and TRF_Opt("enable_salvage_licence") == 1,
		"TRF_ModList has Sc; the five toggles of 6.8 default to 1");
	local T = TRF_ScTune();
	HOST_Check(T.scar_max == 12 and T.scar_ttl[1] == 12 and T.scar_ttl[5] == 8 and T.scar_cd == 4 and T.scar_fight_max == 4 and T.vcap_lw == 6
		and T.rec_fee_k == 0.3 and T.site_k == 0.6 and T.scar_radius == 300 and T.scar_min_dead == 3 and T.scar_fresh_legs == 4,
		"tune defaults of 6.8 (fractions kept)");
	-- Pure rules: TT rows, V_cap, kind values.
	local K = TRF_ScK();
	HOST_Check(TRF_ScTTOf(3) == 1 and TRF_ScTTOf(4) == 2 and TRF_ScTTOf(6) == 3 and TRF_ScTTOf(8) == 4 and TRF_ScTTOf(nil) == 1, "TT(pro): TT2 at 4, TT3 at 6, TT4 at 8");
	HOST_Check(TRF_ScVcapOf(2, 1, 10, 6, K) == 8000 and TRF_ScVcapOf(2, 1, 4, 6, K) == 5333 and TRF_ScVcapOf(2, 1, 3, 6, K) == 4000
		and TRF_ScVcapOf(3, 3, 10, 6, K) == 7800 and TRF_ScVcapOf(0, 1, 10, 6, K) == 0 and TRF_ScVcapOf(2, 5, 10, 6, K) == 0
		and TRF_ScVcapOf(4, 2, 16, 6, K) == 50000, "V_cap = hold x kv x min(1, L_w / vcap_lw): TT2 8000, L_w 4 5333, sweep 0.6, lv 0 and fight 0");
	-- Cargo from the seed: within V_cap, at least 0.6 V_cap where the list allows, at most 8 items, never a quest-handled name.
	local m = TRF_Map();
	local l, v = TRF_ScCargoOf(4321, TRF_ScListDef(1), nil, 8000, 10, m.it, K);
	local l2, v2 = TRF_ScCargoOf(4321, TRF_ScListDef(1), nil, 8000, 10, m.it, K);
	local ni = 0;
	for i = 1, getn(l) do ni = ni + l[i].n; end;
	HOST_Check(v <= 8000 and v >= 4800 and ni <= 8 and SC_Names(l) == SC_Names(l2) and v == v2, "cargo from seed 4321: "..SC_Names(l).." "..v.." cr (<= V_cap, >= 0.6 V_cap, fixed)");
	local ql = {"Cargo_Doc_1", "PREC_artifact_box1", "bomb_m", "Escape_PodAUSS", "Cargo_Alex_04", "Satellite_for_mission8b", "Disk_for_mission8c", "Cargo_01"};
	local bad = 0;
	for s = 1, 40 do
		local q = TRF_ScCargoOf(s * 97, ql, {"Cargo_USS_06"}, 50000, 4, m.it, K);
		for i = 1, getn(q) do if q[i].i ~= "Cargo_01" then bad = bad + 1; end; end;
	end;
	HOST_Check(bad == 0 and TRF_ScQuestOf("Cargo_Doc_2") and TRF_ScQuestOf("PREC_x") and not TRF_ScQuestOf("Cargo_01"), "cargo never holds a quest-handled name (40 seeds)");
	local nv = TRF_ScCargoOf(77, TRF_ScListDef(2), {"VC3", "EngAmp2", "ShAmp3"}, 4800, 10, m.it, K);
	local hasbig = 0;
	for s = 1, 30 do
		local q = TRF_ScCargoOf(s * 31, TRF_ScListDef(2), {"VC3", "ShAmp3"}, 7800, 10, m.it, K);
		for i = 1, getn(q) do if q[i].i == "VC3" or q[i].i == "ShAmp3" then hasbig = hasbig + 1; end; end;
	end;
	HOST_Check(hasbig == 0, "VC3 32000 and ShAmp3 29000 never fit a sweep wreck (V_cap 7800)");
	-- Source 1: forced Bust (TT1, no recorder) and a Bust after Raids (TT(pro), recorder) in the Golkonda region.
	local gs = V_Slot("golkonda");
	local L = TRF.clock.legs;
	local n0 = S_Mark();
	TRF_RgForce(gs, L, 4);
	local made = 0;
	for i = 1, getn(TRF.scar or {}) do
		local r = TRF.scar[i];
		if TRF_RgOf(r.sys) == gs and r.kind == 1 and r.lv == 1 and r.rec == 0 and r.on == 0 and r.st == 0 then made = made + 1; end;
	end;
	HOST_Check(made >= 1 and S_Logs(n0, "module=scar event=source source=1 ") >= 1, "source 1, forced Bust: "..made.." trader records, TT1 row, no recorder");
	TRF.scar = nil;
	local rm = TRF_RgMap();
	for i = 1, getn(rm[gs].sys) do if rm.ts[rm[gs].sys[i]] then TRF_SetPro(rm[gs].sys[i], 6); end; end;
	local r0 = TRF.rg[gs];
	r0.ph = 3;
	n0 = S_Mark();
	TRF_RgAdvance(gs, L, r0, TRF.clan[gs], nil, rm, TRF_RgTune());
	local r = TRF.scar and TRF.scar[1];
	HOST_Check(r0.ph == 4 and r and r.lv == 3 and r.rec == 1 and r.kind == 1 and r.nm >= 1 and r.nm <= 40 and r.x == 0 and r.st == 0
		and r.ttl == 12 and r.nd >= 2 and r.nd <= 4, "source 1 after Raids: TT(pro 6) = 3, recorder, a trader name, site chosen at placement");
	-- Source 2: the Raids tick roll scar_raid_pct (fixed hash of system and leg).
	TRF.scar = nil;
	local hit, miss = 0, 0;
	for s = 1, 113 do
		if TRF_ScM(TRF_ScHash(s, L, 22), 100) < 25 then hit = hit + 1; else miss = miss + 1; end;
	end;
	HOST_Check(hit > 10 and hit < 50, "Raids roll: about 25 % of 113 systems at one leg ("..hit..")");
	local cs = V_Idx("callipso");
	local pick = nil;
	for k = 0, 60 do if not pick and TRF_ScM(TRF_ScHash(cs, L + k, 22), 100) < 25 then pick = L + k; end; end;
	local miss2 = nil;
	for k = 0, 60 do if not miss2 and TRF_ScM(TRF_ScHash(cs, L + k, 22), 100) >= 25 then miss2 = L + k; end; end;
	n0 = S_Mark();
	HOST_Check(TRF_Sc_Source(2, cs, gs, miss2) == nil and S_Logs(n0, "event=source source=2 system=callipso roll=") == 1 and S_Logs(n0, "result=none reason=roll") == 1,
		"source 2: a roll above 25 writes nothing");
	HOST_Check(TRF_Sc_Source(2, cs, gs, pick) ~= nil and TRF_ScAt(cs), "source 2: a roll below 25 writes a trader record in callipso");
	-- The hook: TRF_RgTickSlot in Raids with scar_raid_pct 100.
	TRF.scar = nil;
	h.cfg.tune = {scar_raid_pct=100};
	r0.ph = 3; r0.pt = L;
	n0 = S_Mark();
	TRF_RgTickSlot(gs, L, r0, TRF.clan[gs], rm, TRF_RgTune(), TRF_Rg_Phases());
	HOST_Check(S_Logs(n0, "event=source source=2 ") >= 2 and getn(TRF.scar or {}) >= 1, "source 2 through the region tick: the two highest-pro systems ("..getn(TRF.scar or {}).." new)");
	h.cfg.tune = {};
	-- Source 3: off-screen sweep attempt in its target (base system, else the home): navy on a failure, pirates on a success.
	TRF.scar = nil;
	local tg = TRF_SweepTarget(gs);
	TRF_Sc_Sweep(gs, L, nil, 2);
	local a, ra = TRF_ScAt(tg);
	HOST_Check(ra and ra.kind == 3 and ra.fac == 2 and ra.rec == 0 and ra.ttl == 16, "source 3, failed attempt: sweep wreck in the target, faction 2, no recorder, ttl 16");
	TRF.scar = nil;
	n0 = S_Mark();
	TRF_RgSweepOut(gs, L, 1, 1, "off", 50);
	a, ra = TRF_ScAt(tg);
	HOST_Check(ra and ra.kind == 3 and ra.fac == 0 and S_Logs(n0, "event=source source=3 ") == 1, "source 3 through TRF_RgSweepOut (success): pirate hulls, faction 0");
	TRF.scar = nil;
	n0 = S_Mark();
	TRF_RgSweepOut(gs, L, 1, 1, "on", 50);
	HOST_Check(S_Logs(n0, "event=source source=3 ") == 0, "an on-screen attempt is not source 3 (it is source 7)");
	-- A won off-screen sweep over an active base: the target is read before the outcome destroys the base, so the wreck
	-- lies in the base system, not in the home (scar-spec 5.2; crew-remarks-spec 16, owner decision 6).
	local home, bi = TRF_RgMap()[gs].home, nil;
	for i = 1, getn(TRF_RgMap()[gs].sys) do
		local x = TRF_RgMap()[gs].sys[i];
		if x ~= home and x ~= TRF_CurIdx() and not TRF_ScDenyOf(TRF_ScName(x)) then bi = x; end;
	end;
	local b0 = TRF.base;
	TRF.base = {{s=bi, k=2, h=9, t=0, w=0}};
	TRF.scar = nil;
	HOST_Check(bi and TRF_SweepTarget(gs) == bi, "an active base in "..tostring(bi)..": the sweep target");
	TRF_RgSweepOut(gs, L, 1, 1, "off", 50);
	local ib, rb = TRF_ScAt(bi);
	local ih, rh = TRF_ScAt(home);
	HOST_Check(TRF.base[1].k == 3 and rb and rb.kind == 3 and rb.fac == 0 and rh == nil, "won sweep over the base: the wreck in the base system, none at home");
	TRF.base = b0;
	-- Sources 4-6 are step 2.
	n0 = S_Mark();
	HOST_Check(TRF_Sc_Source(4, cs, gs, L) == nil and S_Logs(n0, "result=none reason=step2") == 1, "sources 4-6: step 2");
end;

-- b: one scar per system, scar_cd, scar_max, scar_fight_max ----------------------------------------------

function T_SC_B()
	SC_Begin("gaoba", "9_1");
	local L = TRF.clock.legs;
	local cs = V_Idx("callipso");
	local gs = V_Slot("callipso");
	TRF_SetPro(cs, 4);
	local i = TRF_ScWrite(cs, {src=1, kind=1, fac=0, lv=2, rec=1, on=0, mine=0});
	local r = TRF.scar[i];
	local seed, lv, k0 = r.seed, r.lv, r.k;
	HOST_Check(r.leg == L and r.rf == 0 and TRF.sys[cs].sk == k0 + 1, "new record, k from TRF.sys sk (next "..TRF.sys[cs].sk..")");
	TRF.clock.legs = L + 3;
	local n0 = S_Mark();
	TRF_ScWrite(cs, {src=2, kind=1, fac=0, lv=1, rec=0, on=0, mine=0});
	HOST_Check(getn(TRF.scar) == 1 and r.leg == L + 3 and r.rf == 1 and r.seed == seed and r.lv == lv and r.rec == 1 and S_Logs(n0, "state=0 leg="..(L + 3).." result=refresh") == 1,
		"a second source refreshes leg once; lv, seed and rec kept");
	TRF.clock.legs = L + 6;
	n0 = S_Mark();
	TRF_ScWrite(cs, {src=1, kind=1, fac=0, lv=3, rec=1, on=0, mine=0});
	HOST_Check(r.leg == L + 3 and S_Logs(n0, "result=kept") == 1, "a third source: kept (at most 2 x ttl)");
	r.rf = 0; r.st = 2;
	n0 = S_Mark();
	TRF_ScWrite(cs, {src=1, kind=1, fac=0, lv=3, rec=1, on=0, mine=0});
	HOST_Check(r.leg == L + 3 and S_Logs(n0, "result=kept") == 1, "an opened record (st 2) is never refreshed");
	-- Expiry at the region tick, then scar_cd 4 legs.
	TRF.clock.legs = r.leg + 13;
	TRF_Sc_RegionTick(TRF.clock.legs);
	local Lx = TRF.clock.legs;
	HOST_Check(getn(TRF.scar) == 0 and TRF.sys[cs].scd == Lx + 4, "expired after ttl 12: dropped, scd = legs + 4");
	n0 = S_Mark();
	HOST_Check(TRF_ScWrite(cs, {src=1, kind=1, fac=0, lv=2, rec=1, on=0, mine=0}) == nil and S_Logs(n0, "result=none reason=cooldown") == 1, "scar_cd: no new record for 4 legs");
	TRF.clock.legs = Lx + 4;
	i = TRF_ScWrite(cs, {src=1, kind=1, fac=0, lv=2, rec=1, on=0, mine=0});
	HOST_Check(i and TRF.scar[i].k == k0 + 1, "after scar_cd a new record with the next k (new labels)");
	-- scar_max: order oldest lv 0 with mine 0, oldest lv 0, oldest lootable.
	TRF.scar = nil;
	local Lb = TRF.clock.legs;
	local ss = {};
	local nm = {"ahilles", "altair", "argon", "aurora", "avalon", "callipso", "danstag", "egleon", "farles", "fiasar", "golkonda", "kitaro", "lasad"};
	for j = 1, 13 do ss[j] = V_Idx(nm[j]); end;
	-- 1: lootable oldest; 2: lv 0 mine 1; 3: lv 0 mine 0 (newer than 2); 4..12 lootable.
	SC_Rec(ss[1], {leg=Lb - 20, lv=2});
	SC_Rec(ss[2], {leg=Lb - 15, lv=0, on=1, mine=1, kind=5});
	SC_Rec(ss[3], {leg=Lb - 10, lv=0, on=1, mine=0, kind=5});
	for j = 4, 12 do SC_Rec(ss[j], {leg=Lb - 9 + j, lv=1}); end;
	local T = TRF_ScTune();
	TRF_ScAdd({sys=ss[13], k=0, kind=1, fac=0, x=0, y=0, z=0, leg=Lb, ttl=12, on=0, mine=0, lv=1, seed=1, nd=2, st=0, hid=0, scv=1, rec=1, nm=1, rf=0}, T);
	HOST_Check(getn(TRF.scar) == 12 and not TRF_ScAt(ss[3]) and TRF_ScAt(ss[2]) and TRF_ScAt(ss[1]), "scar_max: the oldest lv 0 record with mine 0 goes first");
	TRF_ScAdd({sys=V_Idx("ule"), k=0, kind=1, fac=0, x=0, y=0, z=0, leg=Lb, ttl=12, on=0, mine=0, lv=1, seed=1, nd=2, st=0, hid=0, scv=1, rec=1, nm=1, rf=0}, T);
	HOST_Check(getn(TRF.scar) == 12 and not TRF_ScAt(ss[2]) and TRF_ScAt(ss[1]), "then the oldest lv 0 record");
	TRF_ScAdd({sys=V_Idx("heos"), k=0, kind=1, fac=0, x=0, y=0, z=0, leg=Lb, ttl=12, on=0, mine=0, lv=1, seed=1, nd=2, st=0, hid=0, scv=1, rec=1, nm=1, rf=0}, T);
	HOST_Check(getn(TRF.scar) == 12 and not TRF_ScAt(ss[1]) and TRF_ScAt(ss[4]), "then the oldest lootable record");
	-- The current system's record is never replaced (its objects may be in view).
	TRF.scar = nil;
	local g = TRF_CurIdx();
	SC_Rec(g, {leg=Lb - 30, lv=0, on=1, mine=0, kind=5});
	for j = 1, 11 do SC_Rec(ss[j], {leg=Lb - 5, lv=2}); end;
	TRF_ScAdd({sys=ss[12], k=0, kind=1, fac=0, x=0, y=0, z=0, leg=Lb, ttl=12, on=0, mine=0, lv=1, seed=1, nd=2, st=0, hid=0, scv=1, rec=1, nm=1, rf=0}, T);
	HOST_Check(TRF_ScAt(g) and not TRF_ScAt(ss[1]), "the current system's record is not a replacement candidate");
	-- scar_fight_max: the fifth on-screen record replaces the oldest on-screen one; lootable records stay.
	TRF.scar = nil;
	for j = 1, 4 do SC_Rec(ss[j], {leg=Lb - 10 + j, lv=0, on=1, mine=1, kind=1}); end;
	SC_Rec(ss[5], {leg=Lb - 20, lv=2});
	n0 = S_Mark();
	TRF_ScAdd({sys=ss[6], k=0, kind=1, fac=0, x=0, y=0, z=0, leg=Lb, ttl=8, on=1, mine=0, lv=0, seed=1, nd=2, st=0, hid=0, scv=1, rec=0, nm=0, rf=0}, T);
	HOST_Check(getn(TRF.scar) == 5 and not TRF_ScAt(ss[1]) and TRF_ScAt(ss[5]) and S_Logs(n0, "reason=fight_cap") == 1, "scar_fight_max 4: the oldest on-screen record goes, the lootable one stays");
	T.scar_fight_max = 0;
	local ia, ra = TRF_ScAdd({sys=ss[7], k=0, kind=1, fac=0, x=0, y=0, z=0, leg=Lb, ttl=8, on=1, mine=0, lv=0, seed=1, nd=2, st=0, hid=0, scv=1, rec=0, nm=0, rf=0}, T);
	HOST_Check(ia == nil and ra == "fight_cap" and getn(TRF.scar) == 1 and TRF_ScAt(ss[5]) and not TRF_ScAt(ss[7]),
		"scar_fight_max 0: the on-screen records go, no new one is added");
	T.scar_fight_max = 4;
	-- An expired record elsewhere is dropped before a source could refresh it; scar_cd then applies.
	TRF.scar = nil;
	TRF.sys[cs].scd = nil;
	SC_Rec(cs, {leg=TRF.clock.legs - 13, ttl=12});
	n0 = S_Mark();
	HOST_Check(TRF_ScWrite(cs, {src=2, kind=1, fac=0, lv=1, rec=0, on=0, mine=0}) == nil and not TRF_ScAt(cs) and S_Logs(n0, "module=scar event=expire") == 1
		and S_Logs(n0, "reason=cooldown") == 1, "an expired record is not refreshed: dropped, then scar_cd");
	-- Pure victim order and ttl.
	HOST_Check(TRF_ScTtlOf(1, 0, 0, T.scar_ttl) == 12 and TRF_ScTtlOf(4, 0, 0, T.scar_ttl) == 20 and TRF_ScTtlOf(3, 1, 0, T.scar_ttl) == 8
		and TRF_ScTtlOf(3, 1, 1, T.scar_ttl) == 12 and TRF_ScTtlOf(4, 0, 1, T.scar_ttl) == 30, "ttl: per kind, fight 8 on-screen, mine x 1.5, at most 30");
	HOST_Check(TRF_ScScvOf(10, 1, nil, nil, 2) == 0 and TRF_ScScvOf(35, 1, nil, nil, 2) == 1 and TRF_ScScvOf(35, 2, nil, nil, 2) == 0
		and TRF_ScScvOf(59, 4, 1, nil, 2) == 0 and TRF_ScScvOf(60, 4, 1, nil, 2) == 1 and TRF_ScScvOf(10, 1, nil, 1, 2) == 1
		and TRF_ScScvOf(10, 1, nil, nil, 0) == 1, "scavenger roll: 30 % + 10 % per tier, Bust +10 %, at most 60 %; none under the guard or without cargo");
end;

-- c: placement order, cargo, marker, site rule, site pick, blocked spot, arrival line ------------------------

function T_SC_C()
	local h = HOST();
	SC_Begin("heos", "9_1");
	local g = V_Idx("gaoba");
	TRF_SetPro(g, 4);
	local r = SC_Rec(g, {kind=1, lv=2, seed=4321, nd=3, nm=1, rec=1});
	local sid = g * 10;
	local n0 = S_Mark();
	SC_Jump("gaoba");
	local s0 = 0;
	-- Placement order: hulk first, then decorations, then ClearInventory and the cargo.
	local q, ord = h.ships, "";
	for i = 1, getn(q) do
		if type(q[i].label) == "string" and strsub(q[i].label, 1, 9) == "TRF_SCAR_" then ord = ord..strsub(q[i].label, strlen("TRF_SCAR_"..sid.."_") + 1)..","; end;
	end;
	local hk = SC_Hulk(sid);
	HOST_Check(ord == "H,D1,D2,D3," and hk and hk.tpl == "Btransport_destroyed_inv", "placement order: hulk, then decorations D1..D3 ("..ord..")");
	r = SC_R(g);
	HOST_Check(r.st == 1 and r.x ~= 0 and r.hid == 0 and getglobal("TRF_SCH_"..sid.."_0") == hk, "st 0 -> 1, site written, handle global");
	local Lw = TRF_LPay(g);
	local vcap = TRF_ScVcapOf(2, 1, Lw, 6, TRF_ScK());
	local tot = 0;
	for i = 1, getn(hk.inv) do tot = tot + (TRF_Map().it[hk.inv[i][1]] or 1000) * hk.inv[i][2]; end;
	local cl = TRF_ScCargo(r, g, "full");
	HOST_Check(hk.cleared == 1 and getn(hk.inv) == getn(cl) and getn(cl) >= 1 and tot <= vcap, "ClearInventory, then the seed's cargo: "..getn(cl).." names, "..tot.." <= V_cap "..vcap);
	local tr = nil;
	for i = 1, getn(h.triggers) do if h.triggers[i].kind == "died" and h.triggers[i].v1 == hk then tr = h.triggers[i]; end; end;
	HOST_Check(tr and tr.action == "TRF_ScarDied("..sid..","..TRF.gen..")--", "died trigger on the hulk with the generation");
	-- Site rule: 400 from map stations, 300 from portals, 150 from nav points.
	local S = TRF_ScSiteIn(g, sid);
	local K = TRF_ScK();
	local d = 99999;
	for i = 1, getn(S.sts) do d = min(d, TRF_ScDist(r, S.sts[i])); end;
	local dp = 99999;
	for i = 1, getn(S.ports) do dp = min(dp, TRF_ScDist(r, S.ports[i])); end;
	local dn = 99999;
	for i = 1, getn(S.navs) do dn = min(dn, TRF_ScDist(r, S.navs[i])); end;
	HOST_Check(not TRF_ScSiteOf(r, S, K) and d >= 400 and dp >= 300 and dn >= 150, "site passes the rule (station "..floor(d)..", portal "..floor(dp)..", nav "..floor(dn)..")");
	local P = {sts={{x=0, y=0, z=0}}, ports={{x=1000, y=0, z=0}}, navs={{x=0, y=0, z=1000}}, objs={{x=-1000, y=0, z=0}}, st_r=400};
	HOST_Check(TRF_ScSiteOf({x=399, y=0, z=0}, P, K) == "station" and TRF_ScSiteOf({x=401, y=0, z=0}, P, K) == nil
		and TRF_ScSiteOf({x=701, y=0, z=0}, P, K) == "portal" and TRF_ScSiteOf({x=0, y=0, z=851}, P, K) == "nav"
		and TRF_ScSiteOf({x=-851, y=0, z=0}, P, K) == "object" and TRF_ScSiteOf({x=-500, y=0, z=500}, P, K) == nil,
		"site rule: station 400, portal 300, nav point 150, other mod object 150");
	local mp, mv = TRF_ScMoveOf({x=350, y=0, z=0}, P, K);
	HOST_Check(mp and mv == 50 and mp.x == 400, "on-screen centroid 350 from a station moves 50 away");
	HOST_Check(TRF_ScMoveOf({x=50, y=0, z=0}, P, K) == nil, "a centroid more than 300 inside the station rule: no scar");
	HOST_Check(TRF_ScMoveOf({x=-500, y=0, z=500}, P, K), "a passing centroid stays");
	-- Marker: TRF_SCAR_<sid>_NP while st 1 and fresh, the vanilla wreckage key and icon.
	local nav = nil;
	for i = 1, getn(h.navs) do if h.navs[i].label == "TRF_SCAR_"..sid.."_NP" and h.navs[i].alive then nav = h.navs[i]; end; end;
	HOST_Check(nav and nav.text == "#M_Name_Crash_site" and type(TRF.mk) == "string" and strfind(TRF.mk, "TRF_SCAR_"..sid.."_NP=scar;", 1, 1),
		"nav marker TRF_SCAR_<sid>_NP (owner scar), text #M_Name_Crash_site");
	-- Arrival line through the plumbing queue (the first mod line here, 8 s after the entry).
	T_Tick(20, 0.5);
	local line = TRF_Txt("scararrivet0", TRF_Names()[r.nm]);
	HOST_Check(S_Screen(s0, line) and strfind(line, "Kestrel", 1, 1) and S_Logs(n0, "module=plumb event=arrival_line owner=scar") >= 1, "scar line queued: "..line);
	-- Site pick of a sweep wreck: the nav point farthest from the stations (plus the 150-250 offset).
	local rs = {sys=g, k=1, kind=3, seed=4321};
	local p = TRF_ScSitePick(rs, g);
	local far, fd = nil, -1;
	for i = 1, getn(S.navs) do
		local m = 99999;
		for j = 1, getn(S.sts) do m = min(m, TRF_ScDist(S.navs[i], S.sts[j])); end;
		if m > fd and m < 99999 then fd = m; far = S.navs[i]; end;
	end;
	local dfar = TRF_ScDist(p, far);
	HOST_Check(p and dfar >= 150 and dfar <= 250, "sweep site: 150-250 from the nav point farthest from stations ("..floor(dfar or -1)..")");
	-- A blocked spot: CreateCarcass nil everywhere -> nothing placed, the record waits.
	TRF.scar = nil;
	SC_Jump("heos");
	local r2 = SC_Rec(g, {kind=2, lv=2, seed=99, nd=2, k=3});
	h.block_r = 100000;
	n0 = S_Mark();
	SC_Jump("gaoba", nil, SC_Block);
	h.block_r = 3;
	r2 = SC_R(g);
	HOST_Check(r2.st == 0 and S_Logs(n0, "result=failed reason=blocked") == 1 and SC_Objs(g * 10 + 3) == 0, "blocked spot: no hulk, st stays 0");
	SC_Jump("heos");
	SC_Jump("gaoba");
	r2 = SC_R(g);
	HOST_Check(r2.st == 1 and SC_Objs(g * 10 + 3) >= 2, "next entry with free space: placed (convoy hulk and decorations)");
end;

-- d: the reconcile table --------------------------------------------------------------------------

function T_SC_D()
	local h = HOST();
	SC_Begin("heos", "9_1");
	local g = V_Idx("gaoba");
	SC_Rec(g, {kind=1, lv=2, seed=555, nd=3});
	local sid = g * 10;
	SC_Jump("gaoba");
	HOST_Check(SC_R(g).st == 1 and SC_Objs(sid) == 4, "st 0 -> create: hulk and 3 decorations");
	-- Orphan: an object of sid g*10+5 without a record in the snapshot.
	local o = CreateCarcass("Btransport_destroyed", Vector3(100, 0, 100), Vector3(0, 0, 1));
	SetObjectLabel(o, "TRF_SCAR_"..(g * 10 + 5).."_D2");
	-- st 1 alive, snapshot kept: reuse, no duplicate.
	SC_Jump("heos");
	local n0 = S_Mark();
	SC_Jump("gaoba", 1);
	HOST_Check(S_Logs(n0, "module=scar event=orphan sid="..(g * 10 + 5)) == 1 and not o.alive, "orphan probe: object of a sid without a record deleted");
	HOST_Check(S_Logs(n0, "lookup=alive mode=full result=reuse") == 1 and SC_Objs(sid) == 4 and SC_R(g).st == 1, "st 1, hulk alive: reuse, dup=0");
	HOST_Check(SC_Hulk(sid) and getglobal("TRF_SCH_"..sid.."_0") == SC_Hulk(sid), "reuse re-fetches the hulk by label and sets the handle global");
	-- st 1, hulk killed while away (dead in the snapshot): opened, no refill.
	SC_Jump("heos");
	SC_Hulk(sid).alive = nil;
	n0 = S_Mark();
	SC_Jump("gaoba", 1);
	HOST_Check(SC_R(g).st == 2 and S_Logs(n0, "module=scar event=open sid="..sid.." system=gaoba reason=entry") == 1 and S_Logs(n0, "mode=full result=opened") == 1,
		"st 1, hulk dead: opened while away (st 2), no penalty");
	T_Tick(20, 0.5);
	HOST_Check(S_Screen(0, TRF_Txt("scarold")), "picked-clean line for an opened wreck");
	-- st 2: leave it until age > ttl / 2, then one decoration fewer per entry, never the last.
	SC_R(g).leg = TRF.clock.legs;
	SC_Jump("heos");
	n0 = S_Mark();
	SC_Jump("gaoba", 1);
	HOST_Check(S_Logs(n0, "mode=full result=leave") == 1 and SC_Objs(sid) == 3, "st 2, young: leave (3 decorations)");
	SC_R(g).leg = TRF.clock.legs - 6;
	SC_Jump("heos");
	SC_Jump("gaoba", 1);
	HOST_Check(SC_Objs(sid) == 2 and SC_R(g).nd == 2, "st 2, age > ttl / 2: one decoration deleted");
	SC_Jump("heos");
	SC_Jump("gaoba", 1);
	SC_Jump("heos");
	n0 = S_Mark();
	SC_Jump("gaoba", 1);
	HOST_Check(SC_Objs(sid) == 1 and SC_R(g).nd == 1 and S_Logs(n0, "mode=full result=shrink") == 0, "never the last decoration");
	-- st 1, snapshot not kept (hulk nil): opened.
	TRF.scar = nil;
	SC_Rec(g, {kind=1, lv=2, seed=777, nd=2, k=2});
	SC_Jump("heos");
	SC_Jump("gaoba");
	SC_Jump("heos");
	SC_Jump("gaoba");
	HOST_Check(SC_R(g).st == 2, "st 1, hulk nil (not in the snapshot): opened");
	-- Gate fails (a quest naming heos in process): hidden, state and loot kept; free entry: created again.
	TRF.scar = nil;
	local he = V_Idx("heos");
	SC_Rec(he, {kind=3, fac=2, lv=2, seed=321, nd=2, k=4});
	sid = he * 10 + 4;
	SC_Jump("gaoba");
	SC_Jump("heos");
	HOST_Check(SC_R(he).st == 1 and SC_Objs(sid) == 3, "heos placed (sweep hulk, 2 decorations)");
	SC_Jump("gaoba");
	local qi = TRF_SafeQIds(he, TRF_Map().sys[he]);
	HOST_Check(type(qi) == "table" and qi[1] ~= nil, "heos has quest ids");
	h.qs = TRUE;
	h.quests[qi[1]] = QUEST_PROCESS;
	n0 = S_Mark();
	SC_Jump("heos", 1);
	local r = SC_R(he);
	HOST_Check(r.hid == 1 and r.st == 1 and SC_Objs(sid) == 0 and S_Logs(n0, "module=scar event=hide sid="..sid) == 1
		and S_Logs(n0, "reason=gate:quest") == 1, "gate fails: objects deleted before the first frame, hid 1, st kept");
	HOST_Check(not (type(TRF.mk) == "string" and strfind(TRF.mk, "TRF_SCAR_", 1, 1)), "no marker in a hidden visit");
	SC_Jump("gaoba");
	h.qs = FALSE; h.quests = {};
	n0 = S_Mark();
	SC_Jump("heos", 1);
	r = SC_R(he);
	local hk = SC_Hulk(sid);
	HOST_Check(r.hid == 0 and r.st == 1 and SC_Objs(sid) == 3 and S_Logs(n0, "mode=full result=create") == 1 and hk and getn(hk.inv) >= 1,
		"free entry: created again with its cargo, hid 0");
	-- hid 1 with st 2: comes back without the hulk.
	r.hid = 1; r.st = 2;
	SC_Jump("gaoba");
	SC_Jump("heos");
	r = SC_R(he);
	HOST_Check(SC_Objs(sid) == 2 and SC_Objs(sid) == SC_R(he).nd and not SC_Find("TRF_SCAR_"..sid.."_H") and r.hid == 0 and r.st == 2, "hidden opened wreck: decorations only");
	-- st 3 (stripped, step 2) with hid 1: an empty hulk.
	r.hid = 1; r.st = 3;
	SC_Jump("gaoba");
	SC_Jump("heos");
	hk = SC_Hulk(sid);
	HOST_Check(hk and hk.alive and getn(hk.inv) == 0 and hk.cleared == 1, "hidden stripped wreck: the hulk without cargo");
	-- Expired: deleted and dropped at entry.
	-- (The region tick at the entry elsewhere drops it; the next entry's orphan probe deletes its objects.)
	SC_R(he).leg = TRF.clock.legs - 20;
	n0 = S_Mark();
	SC_Jump("gaoba");
	SC_Jump("heos", 1);
	HOST_Check(not TRF_ScAt(he) and SC_Objs(sid) == 0 and S_Logs(n0, "module=scar event=expire sid="..sid.." system=heos") == 1
		and S_Logs(n0, "module=scar event=orphan sid="..sid.." system=heos deleted=3") == 1, "expired: record dropped, objects deleted at the next entry");
	-- Expiry at the entry itself (no region tick between): deleted and dropped in TRF_Sc_OnActivate.
	SC_Rec(he, {kind=1, lv=2, seed=11, nd=2, k=6, leg=TRF.clock.legs - 30});
	n0 = S_Mark();
	TRF_Sc_OnActivate();
	HOST_Check(not TRF_ScAt(he) and S_Logs(n0, "module=scar event=expire sid="..(he * 10 + 6).." system=heos") == 1, "expired at the entry: dropped in the activate hook");
end;

-- e: source 7 ------------------------------------------------------------------------------------

function T_SC_E()
	local h = HOST();
	SC_Begin("gaoba", "9_1", {enable_survivors=1});
	local g = TRF_CurIdx();
	-- Two deaths only: no scar; far apart: no cluster.
	SC_Dead(3, -400, 300);
	SC_Dead(3, -380, 320);
	local n0 = S_Mark();
	SC_Jump("heos");
	HOST_Check(not TRF_ScAt(g) and S_Logs(n0, "module=scar event=fight system=gaoba death_count=2 cluster=2") == 1 and S_Logs(n0, "reason=few") == 1,
		"two deaths: no scar (scar_min_dead 3)");
	SC_Jump("gaoba");
	SC_Dead(3, -400, 300); SC_Dead(3, 400, 300); SC_Dead(3, 0, -500);
	n0 = S_Mark();
	SC_Jump("heos");
	HOST_Check(not TRF_ScAt(g) and S_Logs(n0, "cluster=1") == 1, "three deaths more than 300 apart: no scar");
	-- Three deaths within 300: an on-screen record at the centroid, written at the jump; no cargo, ttl 8.
	SC_Jump("gaoba");
	SC_Dead(3, -400, 300); SC_Dead(3, -300, 300); SC_Dead(1, -350, 400);
	HOST_Check(not TRF_ScAt(g), "nothing written before the jump");
	n0 = S_Mark();
	SC_Jump("heos");
	local i, r = TRF_ScAt(g);
	HOST_Check(r and r.on == 1 and r.lv == 0 and r.rec == 0 and r.nm == 0 and r.scv == 1 and r.ttl == 8 and r.mine == 0 and r.kind == 3
		and r.x == -350 and r.z == 333 and r.st == 0, "3 deaths within 300: on-screen record at the centroid (-350, 333), kind by the dead, no loot, ttl 8");
	SC_Jump("gaoba");
	r = SC_R(g);
	local sid = TRF_ScSid(r);
	HOST_Check(r.st == 1 and not SC_Hulk(sid) and SC_Objs(sid) == r.nd and r.nd >= 2 and r.nd <= 3, "placed at the next entry: 2-3 decorations, no hulk");
	HOST_Check(not (type(TRF.mk) == "string" and strfind(TRF.mk, "TRF_SCAR_", 1, 1)), "no beacon marker for an on-screen scar");
	HOST_Check(getn(TRF_ScCargo(r, g, "full")) == 0, "no cargo for an on-screen wreck (exploit 1)");
	-- An on-screen record shrinks from age > ttl / 2 (one decoration per entry, never the last); it stays st 1.
	local nd0 = r.nd;
	r.ttl = 30; r.leg = TRF.clock.legs - 16;
	SC_Jump("heos");
	n0 = S_Mark();
	SC_Jump("gaoba", 1);
	r = SC_R(g);
	HOST_Check(r.st == 1 and r.nd == nd0 - 1 and SC_Objs(sid) == nd0 - 1 and S_Logs(n0, "module=scar event=shrink sid="..sid) == 1,
		"on-screen record past ttl / 2: one decoration fewer ("..r.nd.." of "..nd0..")");
	-- A named fight end with one death; player fire: mine 1, ttl 12. The system's record is refreshed instead.
	TRF.scar = nil;
	SC_Dead(1, 300, -300, 0, 1);
	TRF_Sc_Fight("raid", 1);
	n0 = S_Mark();
	SC_Jump("heos");
	i, r = TRF_ScAt(g);
	HOST_Check(r and r.mine == 1 and r.ttl == 12 and r.kind == 1 and S_Logs(n0, "fights=raid") == 1, "raid end with one death: scar, mine 1, ttl 8 x 1.5");
	-- The move-away rule: a centroid at the station moves away or gives no scar.
	TRF.scar = nil;
	SC_Jump("gaoba");
	local st = TRF_Map().sys[g].st[1];
	SC_Dead(3, st.x, st.z + 350); SC_Dead(3, st.x, st.z + 350); SC_Dead(3, st.x, st.z + 350);
	n0 = S_Mark();
	SC_Jump("heos");
	i, r = TRF_ScAt(g);
	HOST_Check(r and S_Logs(n0, "moved=50") == 1, "centroid 350 from the trade station: moved 50 away");
	TRF.scar = nil;
	SC_Jump("gaoba");
	SC_Dead(3, st.x + 10, st.z); SC_Dead(3, st.x, st.z + 10); SC_Dead(3, st.x, st.z);
	n0 = S_Mark();
	SC_Jump("heos");
	HOST_Check(not TRF_ScAt(g) and S_Logs(n0, "reason=site") == 1, "centroid at the station: no scar");
	-- Real hooks: trader transports through TRF_OnShipDied, the raid end through TRF_Rd_End; the survivors link.
	TRF.scar = nil;
	TRF.sys[g] = TRF.sys[g] or {};
	TRF.sys[g].scd = nil;
	SC_Jump("gaoba");
	TRF_SetDis(g, 0);
	local id = SC_Trader();
	HOST_Check(id ~= nil, "trader spawned");
	local rn = V_Raid(id);
	TRF.live.rd[rn].hit = 1;
	n0 = S_Mark();
	SC_Kill(id, 300, 0, 0);
	T_Tick(12, 0.5);
	HOST_Check(S_Logs(n0, "module=scar event=dead class=1 ") >= 1 and TRF.sv and TRF.sv.b[1] and TRF.sv.b[1].src == 1, "trader death recorded by trf_events; survivors' witnessed record");
	TRF.live.rd[rn].st = "fight";
	TRF.live.rd[rn].hit = 1;
	TRF.live.rd[rn].tk = nil;
	TRF_Rd_End(rn, "stale");
	HOST_Check(S_Logs(n0, "module=scar event=fight_end") == 0, "raid end without a fight (no raid ship dead, target alive): no fight end");
	TRF.live.rd[rn].st = "fight";
	TRF.live.rd[rn].hit = 1;
	TRF.live.rd[rn].tk = 1;
	TRF_Rd_End(rn, "left");
	HOST_Check(S_Logs(n0, "module=scar event=fight_end fight=raid") == 1, "raid end after its target was killed recorded by trf_raid");
	-- A leg passes during the visit: the witnessed loss is still this visit's (stamped at or after the entry leg).
	TRF.clock.legs = TRF.clock.legs + 1;
	TRF.clock.vl = (TRF.clock.vl or 0) + 1;
	n0 = S_Mark();
	SC_Jump("heos");
	i, r = TRF_ScAt(g);
	local b = TRF.sv.b[1];
	HOST_Check(r and r.on == 1 and r.kind == 1 and r.mine == 1 and S_Logs(n0, "linked=true") == 1 and b.si == TRF_ScSid(r),
		"witnessed trader loss: scar at the loss site, linked to the survivors record (si = "..tostring(b.si)..")");
	HOST_Check(TRF_Sv_Site(g).si == TRF_ScSid(r) and TRF_ScDist(TRF_Sv_Site(g), r) <= 300, "TRF_Sv_Site: the shared site record (s, x, y, z, lg, src, si)");
	-- Cluster and class pure parts.
	local m, c = TRF_ScClusterOf({{x=0, y=0, z=0, c=1}, {x=100, y=0, z=0, c=3}, {x=200, y=0, z=0, c=3}, {x=900, y=0, z=0, c=2}}, 300);
	HOST_Check(getn(m) == 3 and c.x == 100, "cluster: the densest group within 300");
	local k1, f1, m1 = TRF_ScClassOf({{c=2, f=4}, {c=2, f=4}, {c=3, f=1}}, {});
	local k2 = TRF_ScClassOf({{c=4}, {c=1}}, {{w="base", m=1}});
	HOST_Check(k1 == 2 and f1 == 4 and m1 == 0 and k2 == 4, "class: the most common, ties base > convoy > trader > sweep; owner of the class");
	-- Hooks of trf_base, trf_clan, trf_faction, trf_convoy and trf_danger are one-line calls (grep in the spec); a
	-- death without a position (and no survivors site) is kept but cannot centre a scar.
	TRF.scar = nil;
	SC_Jump("gaoba");
	TRF_Sc_Dead(3, 0, nil, nil);
	TRF_Sc_Fight("carrier", nil);
	n0 = S_Mark();
	SC_Jump("heos");
	HOST_Check(not TRF_ScAt(g) and S_Logs(n0, "reason=position") == 1, "deaths without a position: no scar");
	-- trf_danger: a danger convoy that ends without a loss is no fight end; one with a loss (TRF_DcLoss) is.
	n0 = S_Mark();
	TRF.live.dc = {};
	TRF.live.dc[7] = {id={}, a={}, st="go", n=2, ns=2, ok=0, ct=0, e=3, m=1, k=1};
	TRF_DcEnd(7);
	HOST_Check(S_Logs(n0, "module=danger event=end convoy_id=7") == 1 and S_Logs(n0, "module=scar event=fight_end") == 0, "danger convoy end without a loss: no fight end");
	TRF.live.dc[8] = {id={}, a={}, st="go", n=2, ns=2, ok=0, ct=0, e=3, m=1, k=1};
	HOST_Check(TRF_DcLoss(8) == 1 and TRF.live.dc[8].dd == 1, "TRF_DcLoss counts the member death");
	TRF_DcEnd(8);
	HOST_Check(S_Logs(n0, "module=scar event=fight_end fight=convoy") == 1, "danger convoy end after a loss: fight end");
end;

-- f: gates, chapters, toggles --------------------------------------------------------------------

function T_SC_F()
	local h = HOST();
	SC_Begin("gaoba", "9_1");
	local g = TRF_CurIdx();
	local cs = V_Idx("callipso");
	local gs = V_Slot("callipso");
	-- W1: no off-screen source in the current system; the deny list.
	local n0 = S_Mark();
	HOST_Check(TRF_ScWrite(g, {src=1, kind=1, lv=2, rec=1, on=0}) == nil and S_Logs(n0, "result=none reason=current") == 1, "no off-screen source in the current system (W1)");
	local dn = {"earth", "precursors", "disonsphere", "fronn", "b_leftera1", "nk", "x203", "x213", "x220", "x297", "elio", "gefest"};
	local bad = "";
	for i = 1, getn(dn) do
		if TRF_ScWrite(V_Idx(dn[i]), {src=1, kind=1, lv=2, rec=1, on=0}) ~= nil then bad = bad.." "..dn[i]; end;
	end;
	HOST_Check(bad == "" and TRF_ScDenyOf("gaoba") == nil and TRF_ScDenyOf("Earth") == "deny", "deny list: no record in Earth, Precursors, DisonSphere, Fronn, B_leftera1, NK, the Border, the S5 names"..bad);
	-- Chapter 5 rule: no trader scar in Corrino and Debris 1/2/4/6; source 1 picks another region system or none.
	h.labels.CurrentQuest = "5_1";
	TRF.scar = nil;
	local co = V_Idx("corrino");
	n0 = S_Mark();
	HOST_Check(TRF_ScWrite(co, {src=1, kind=1, lv=2, rec=1, on=0}) == nil and S_Logs(n0, "reason=chapter5") == 1, "chapter 5: no trader scar in Corrino");
	HOST_Check(TRF_ScWrite(co, {src=3, kind=3, fac=1, lv=2, rec=0, on=0}) ~= nil, "chapter 5: a sweep scar in Corrino stays");
	TRF.scar = nil;
	local cg = TRF_RgOf(co);
	n0 = S_Mark();
	TRF_Sc_Source(1, co, cg, TRF.clock.legs);
	local moved = 0;
	for i = 1, getn(TRF.scar or {}) do if TRF.scar[i].sys ~= co and TRF_RgOf(TRF.scar[i].sys) == cg then moved = moved + 1; end; end;
	HOST_Check((moved == 1 and S_Logs(n0, "result=moved reason=chapter5") == 1) or (moved == 0 and S_Logs(n0, "alternative=nil result=none reason=chapter5") == 1),
		"chapter 5: source 1 moves to another region system or none");
	HOST_Check(TRF_ScLineOf({on=0, st=1, hid=0, kind=2, rec=0, fac=0}, "full", 5, "corrino", 1) == nil
		and TRF_ScLineOf({on=0, st=1, hid=0, kind=2, rec=0, fac=0}, "full", 6, "corrino", 1) == "scararrivec", "chapter 5: no convoy line in Corrino");
	HOST_Check(TRF_ScLineOf({on=0, st=1, hid=0, kind=1, rec=1, fac=0}, "full", 5, "corrino", 1) == nil
		and TRF_ScLineOf({on=0, st=1, hid=0, kind=1, rec=1, fac=0}, "full", 6, "corrino", 1) == "scararrivet0"
		and TRF_ScNav({sys=co, k=0, on=0, st=1, kind=1, leg=TRF.clock.legs, x=0, y=0, z=0}, "full") == nil,
		"chapter 5: no recorder line and no marker for a trader record written before");
	-- Chapter modes: 3 visual (hulk without cargo, no marker, no line), 4 free time (TT1 row, marker), 4 without.
	TRF.scar = nil;
	h.labels.CurrentQuest = "3";
	local r = SC_Rec(g, {kind=1, lv=3, seed=4321, k=1});
	local sid = g * 10 + 1;
	SC_Jump("heos");
	local s0 = 0;
	n0 = S_Mark();
	SC_Jump("gaoba");
	T_Tick(20, 0.5);
	r = SC_R(g);
	local hk = SC_Hulk(sid);
	HOST_Check(r.st == 0 and not hk and SC_Objs(sid) == 0 and not (type(TRF.mk) == "string" and strfind(TRF.mk, "TRF_SCAR_", 1, 1))
		and S_Logs(n0, "module=scar event=enter system=gaoba mode=visual") == 1 and S_Logs(n0, "mode=visual result=wait") == 1
		and S_Logs(n0, "module=plumb event=arrival_line owner=scar") == 0, "chapter 3: an off-screen record waits unplaced (no empty hulk, no marker, no line)");
	h.labels.CurrentQuest = "4_1";
	h.quests.quest_Help = QUEST_PROCESS;
	SC_Jump("heos");
	SC_Jump("gaoba");
	hk = SC_Hulk(sid);
	HOST_Check(SC_R(g).st == 1 and hk and getn(hk.inv) >= 1, "the same record in chapter 4 free time: placed with its cargo");
	h.quests = {};
	TRF.scar = nil;
	h.labels.CurrentQuest = "4_1";
	h.quests.quest_Help = QUEST_PROCESS;
	r = SC_Rec(g, {kind=1, lv=3, seed=4321, k=2});
	sid = g * 10 + 2;
	SC_Jump("heos");
	SC_Jump("gaoba");
	hk = SC_Hulk(sid);
	local Lw = TRF_LPay(g);
	local tot = 0;
	for i = 1, getn(hk.inv) do tot = tot + (TRF_Map().it[hk.inv[i][1]] or 1000) * hk.inv[i][2]; end;
	HOST_Check(getn(hk.inv) >= 1 and tot <= TRF_ScVcapOf(1, 1, Lw, 6, TRF_ScK()) and type(TRF.mk) == "string" and strfind(TRF.mk, "TRF_SCAR_"..sid.."_NP", 1, 1),
		"chapter 4 free time: cargo at the TT1 row ("..tot.."), marker");
	h.quests = {};
	SC_Jump("heos");
	SC_Jump("gaoba");
	HOST_Check(TRF_ScChMode() == "visual", "chapter 4 outside free time: visual");
	h.labels.CountPauseQuest = "2";
	HOST_Check(TRF_ScChMode() == "ch4", "chapter 4 with CountPauseQuest > 0: free time");
	h.labels.CountPauseQuest = nil;
	-- Guard: a record written in chapter 4 never gets scavengers (scv 1) whatever the seed.
	TRF.scar = nil;
	TRF_SetPro(cs, 4);
	local scv = "";
	for L = 1, 12 do
		TRF.scar = nil;
		TRF.sys[cs] = TRF.sys[cs] or {}; TRF.sys[cs].scd = nil;
		TRF.clock.legs = TRF.clock.legs + 1;
		local i = TRF_ScWrite(cs, {src=1, kind=1, lv=2, rec=1, on=0});
		if i then scv = scv..TRF.scar[i].scv; end;
	end;
	HOST_Check(scv == "111111111111", "guard (chapter <= 4): scv 1 at creation ("..scv..")");
	-- Marker only while fresh: age 5 at the entry -> no marker, no line.
	h.labels.CurrentQuest = "9_1";
	TRF.scar = nil;
	SC_Jump("heos");
	r = SC_Rec(g, {kind=1, lv=2, seed=4321, k=3, leg=TRF.clock.legs - 4});
	n0 = S_Mark();
	SC_Jump("gaoba");
	r = SC_R(g);
	HOST_Check(r.st == 1 and not (type(TRF.mk) == "string" and strfind(TRF.mk, "TRF_SCAR_", 1, 1)) and S_Logs(n0, "line=nil") == 1, "older than scar_fresh_legs: no marker, no line");
	-- Wind-down: the gate fails during the visit (a mission begins): marker deleted, objects kept until the jump.
	TRF.scar = nil;
	SC_Jump("heos");
	r = SC_Rec(g, {kind=1, lv=2, seed=4321, k=4});
	sid = g * 10 + 4;
	SC_Jump("gaoba");
	HOST_Check(type(TRF.mk) == "string" and strfind(TRF.mk, "TRF_SCAR_"..sid.."_NP", 1, 1), "fresh: marker");
	TRF_Map().sys[g].q = 1;
	h.qs = TRUE;
	local qi = TRF_SafeQIds(g, TRF_Map().sys[g]);
	if qi and qi[1] then h.quests[qi[1]] = QUEST_PROCESS; end;
	TRF.live.qa = nil; TRF.live.qai = nil; TRF_H().loc = nil;
	n0 = S_Mark();
	TRF_Sc_Step();
	HOST_Check(SC_Objs(sid) == 4 and not (type(TRF.mk) == "string" and strfind(TRF.mk, "TRF_SCAR_", 1, 1)) and S_Logs(n0, "module=scar event=wind_down sid="..sid) == 1,
		"mission starts in the visit: marker gone, objects stay");
	h.qs = FALSE; h.quests = {};
	TRF_Map().sys[g].q = 0;
	-- S2: __disableAction at the entry hides the scar (state kept, no marker, no line).
	SC_Jump("heos");
	n0 = S_Mark();
	SC_Jump("gaoba", 1, function() __disableAction = TRUE; end);
	r = SC_R(g);
	HOST_Check(r.hid == 1 and r.st == 1 and SC_Objs(sid) == 0 and S_Logs(n0, "reason=hold:disable_action") == 1
		and not (type(TRF.mk) == "string" and strfind(TRF.mk, "TRF_SCAR_", 1, 1)), "S2 __disableAction at the entry: hidden, state kept");
	__disableAction = FALSE;
	HOST_Check(TRF_ScHold() == nil, "hold ends with the flag");
	-- Toggles: enable_scar_loot 0 (hulk without cargo); enable_scars 0 (nothing).
	SC_Begin("heos", "9_1", {enable_scar_loot=0});
	r = SC_Rec(g, {kind=1, lv=2, seed=4321, k=5});
	SC_Jump("gaoba");
	hk = SC_Hulk(g * 10 + 5);
	HOST_Check(hk and getn(hk.inv) == 0 and hk.cleared == 1, "enable_scar_loot 0: the hulk without cargo");
	SC_Begin("heos", "9_1", {enable_scars=0});
	r = SC_Rec(g, {kind=1, lv=2, seed=4321, k=6});
	HOST_Check(TRF_Sc_Source(1, cs, gs, TRF.clock.legs) == nil and TRF_Sc_Sweep(gs, TRF.clock.legs, nil, 2) == nil, "enable_scars 0: no source");
	SC_Jump("gaoba");
	r = SC_R(g);
	HOST_Check(r.st == 0 and SC_Objs(g * 10 + 6) == 0, "enable_scars 0: no placement");
end;

-- g: hulk death, load, dump, repair, bound ------------------------------------------------------------

function T_SC_G()
	local h = HOST();
	SC_Begin("heos", "9_1");
	local g = V_Idx("gaoba");
	local r = SC_Rec(g, {kind=1, lv=2, seed=4321, k=0});
	local sid = g * 10;
	SC_Jump("gaoba");
	r = SC_R(g);
	-- died trigger: st 2 at once, marker gone.
	local hk = SC_Hulk(sid);
	hk.alive = nil;
	local n0 = S_Mark();
	HOST_Fire("died", "TRF_ScarDied(");
	HOST_Check(r.st == 2 and S_Logs(n0, "module=scar event=open sid="..sid.." system=gaoba reason=died") == 1 and not (type(TRF.mk) == "string" and strfind(TRF.mk, "TRF_SCAR_", 1, 1)),
		"died trigger: st 2 at once, marker deleted");
	HOST_Fire("died", "TRF_ScarDied(");
	HOST_Check(S_Logs(n0, "event=open") == 1, "a second death event changes nothing");
	-- A stale callback of another generation is ignored.
	r.st = 1;
	TRF_ScarDied(sid, TRF.gen - 1);
	HOST_Check(r.st == 1, "stale generation ignored");
	-- Poll (10 s step) as the backup.
	n0 = S_Mark();
	TRF_Sc_Step();
	HOST_Check(r.st == 2 and S_Logs(n0, "reason=poll") == 1, "10 s poll: st 2");
	-- Expiry deletes a dead hulk that the label lookup still answers (EW2.2).
	hk.Delete = function(self) self.deleted = 1; end;
	r.leg = TRF.clock.legs - 31;
	n0 = S_Mark();
	TRF_ScExpireAll(nil);
	HOST_Check(hk.deleted == 1 and not SC_R(g) and S_Logs(n0, "module=scar event=expire sid="..sid) == 1, "expiry deletes a dead hulk the label still answers");
	-- Jump read.
	TRF.scar = nil;
	SC_Jump("heos");
	r = SC_Rec(g, {kind=1, lv=2, seed=4321, k=1});
	sid = g * 10 + 1;
	SC_Jump("gaoba");
	SC_Hulk(sid).alive = nil;
	n0 = S_Mark();
	SC_Jump("heos");
	r = SC_R(g);
	HOST_Check(r.st == 2 and S_Logs(n0, "module=scar event=open sid="..sid.." system=gaoba reason=jump") == 1, "pre-jump read: st 2");
	-- Load in the system: objects re-fetched by the handle global, no placement, marker again.
	TRF.scar = nil;
	r = SC_Rec(g, {kind=1, lv=2, seed=4321, k=2});
	sid = g * 10 + 2;
	SC_Jump("gaoba");
	local nship = getn(h.ships);
	n0 = S_Mark();
	T_SaveLoad();
	HOST_Check(getn(h.ships) == nship and SC_Objs(sid) == 4 and S_Logs(n0, "module=scar event=load sid="..sid.." system=gaoba state=1 hulk=true decorations=3") == 1,
		"load: objects re-fetched (handle globals), no placement");
	HOST_Check(type(TRF.mk) == "string" and strfind(TRF.mk, "TRF_SCAR_"..sid.."_NP", 1, 1), "load: marker re-added");
	local tn = 0;
	for i = 1, getn(h.triggers) do if h.triggers[i].kind == "died" and h.triggers[i].action == "TRF_ScarDied("..sid..","..TRF.gen..")--" then tn = tn + 1; end; end;
	HOST_Check(tn == 1, "load: died trigger armed with the new generation");
	-- Dump.
	n0 = S_Mark();
	TRF_DumpState("test");
	HOST_Check(S_Logs(n0, "module=scar event=dump record_count=") == 1 and S_Logs(n0, sid..":gaoba:trader:") == 1 and S_Logs(n0, "module=scar event=dump_rec sid="..sid) == 1
		and S_Logs(n0, "module=scar event=dump_probe system=gaoba sid="..sid.." expected=4 found=4") == 1, "dump: records, per-record line with cargo, label probe");
	-- Repair: bad records dropped, fields clamped, one per system, step 2 fields bounded.
	local L = TRF.clock.legs;
	TRF.scar = {{sys=9999, x=1, y=1, z=1}, {sys=g, x=1.5, y=2, z=3, k=12, kind=9, fac=7, leg=L + 50, ttl=99, on=1, mine=2, lv=3, seed=-1, nd=9, st=7,
		hid=3, scv=8, rec=1, nm=99, rf=4}, {sys=g, x=1, y=1, z=1}, "x", {sys=V_Idx("heos"), y=1, z=1}};
	TRF.std.slog = {{sid=1, sys=g, leg=L, pay=100}, {sid=9999}, {sid=2, sys=g, leg=L, pay=100}, {sid=3, sys=g, leg=L, pay=100}, {sid=4, sys=g, leg=L, pay=100}};
	TRF.std.rpay = {L, "a", L, L};
	TRF.std.lic = "x";
	TRF.rg[1].bsc = L + 99; TRF.rg[1].bsh = L;
	TRF.sys[g].scd = L + 500;
	TRF_Repair();
	local q = TRF.scar;
	HOST_Check(getn(q) == 1 and q[1].x == 1 and q[1].k == 0 and q[1].kind == 1 and q[1].fac == 0 and q[1].leg == L and q[1].ttl == 8 and q[1].on == 1
		and q[1].lv == 0 and q[1].rec == 0 and q[1].seed == 1 and q[1].nd == 1 and q[1].st == 0 and q[1].hid == 0 and q[1].scv == 1 and q[1].nm == 0 and q[1].rf == 0,
		"repair: bad records dropped, fields clamped, on-screen without loot");
	HOST_Check(getn(TRF.std.slog) == 3 and getn(TRF.std.rpay) == 2 and TRF.std.lic == nil and TRF.rg[1].bsc == nil and TRF.rg[1].bsh == L
		and (TRF.sys[g] == nil or TRF.sys[g].scd == nil), "repair: slog 3, rpay 2, lic, bsc/bsh legs, stale scd dropped");
	TRF.scar = {{sys=g, x=1, y=1, z=1, kind=5, on=1}};
	TRF_Repair();
	HOST_Check(TRF.scar[1].kind == 3, "repair: kind 5 (fight) takes the sweep hulls (kind 3)");
	TRF.scar = 5;
	TRF_Repair();
	HOST_Check(TRF.scar == nil, "repair: a non-table TRF.scar becomes absent");
	-- Debug keys of the in-game checks: scar_at writes a trader record there at an entry elsewhere; scar_gate_fail
	-- fails the scar gate there (EW2.5: hide before the first frame).
	SC_Begin("heos", "9_1", {scar_at="gaoba"});
	TRF.scar = nil;
	n0 = S_Mark();
	SC_Jump("kadenoa");
	HOST_Check(SC_R(g) and SC_R(g).kind == 1 and S_Logs(n0, "module=scar event=source source=9 system=gaoba ") == 1, "cfg scar_at: a trader record in gaoba");
	SC_Jump("gaoba");
	sid = TRF_ScSid(SC_R(g));
	HOST_Check(SC_R(g).st == 1 and SC_Objs(sid) >= 3, "placed on entry");
	h.cfg.scar_gate_fail = "gaoba";
	SC_Jump("kadenoa");
	n0 = S_Mark();
	SC_Jump("gaoba", 1);
	HOST_Check(SC_R(g).hid == 1 and SC_Objs(sid) == 0 and S_Logs(n0, "module=scar event=hide sid="..sid.." system=gaoba state=1 deleted=") == 1
		and S_Logs(n0, "reason=gate:debug") == 1, "cfg scar_gate_fail: hidden at the entry");
	h.cfg.scar_gate_fail = nil;
	h.cfg.scar_at = nil;
	-- TRF.scar at its bound (scar_max 12, every field at its widest), plus the step 2 fields and the TRF.sys stamps.
	TRF.scar = {};
	for i = 1, 12 do
		tinsert(TRF.scar, {sys=100 + i, k=9, kind=5, fac=5, x=-99999, y=-99999, z=-99999, leg=L, ttl=30, on=1, mine=1, lv=4, seed=9999, nd=4, st=3, hid=1,
			scv=4, rec=1, nm=40, rf=1});
	end;
	local sz = HOST_SaveSize(TRF.scar) + 8 + strlen("scar");
	local s2 = {slog={{sid=1139, sys=113, leg=L, pay=30000}, {sid=1139, sys=113, leg=L, pay=30000}, {sid=1139, sys=113, leg=L, pay=30000}}, rpay={L, L}, lic=L};
	local sz2 = HOST_SaveSize(s2) - 12 + 2 * (8 + 3);
	local sk = {};
	for i = 1, 113 do sk[i] = {sk=9}; end;
	for i = 1, 12 do sk[i].scd = L; end;
	local sz3 = HOST_SaveSize(sk) - 12;
	local sz4 = 11 * 2 * (8 + 3 + 12);
	print("HOST info TRF.scar worst case "..sz.." bytes; step 2 std fields "..sz2.."; TRF.sys sk/scd (113 new entries, 12 stamps) "..sz3.."; rg bsc/bsh "..sz4);
	HOST_Check(sz <= 5800, "TRF.scar at scar_max 12: "..sz.." bytes <= 5800 (spec 3.3)");
	HOST_Check(HOST_Reserved(TRF, "TRF") == "", "no reserved key in TRF");
	TRF.scar = nil;
end;

-- Dispatch ---------------------------------------------------------------------------------

local sc = getenv("TRF_SC") or "";
local fn = getglobal("T_SC_"..strupper(sc));
print("HOST ==== battle scars scenario sc-"..sc.." dir="..HOST().dir);
if type(fn) == "function" then
	fn();
	HOST_Check(T_LeftGlobals() == "", "no handle globals left at the end"..T_LeftGlobals());
else
	HOST_Check(nil, "unknown battle scars scenario "..sc);
end;
HOST_Check((HOST().gpm_tick or 0) == 0, "no GetPlayerMotherShip from a tick (n="..tostring(HOST().gpm_tick or 0)..")");
print("HOST errors="..HOST().errors.." fails="..HOST().fails);
if HOST().errors > 0 or HOST().fails > 0 then exit(1); end;
exit(0);
