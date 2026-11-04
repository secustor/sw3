-- Clan stashes scenarios (design/stash-spec.md 9) under stock Lua 4.0.1: TRF_SH=a..h, run by run_host.sh as its own
-- entry point. a registration, toggles, tune, slots, texts and the pure rules (value, class, fill, price, gaps, area,
-- delay), b the region tick (creation gates: guard, mission, stash_live, stash_gap and stash_open_gap in legs and jumps,
-- the prize gap, phases and chances, the oldest region first, so and the open sweep; expiry: ttl, the open gap, the
-- dead records, banked salvage returned, the moved notice; the record bound), c entry reconciliation (create, reuse with
-- the same fill, lost, delete, orphan, enable_stashes 0, a mission entry, a load without creation), d triggers (died with
-- and without the player's hit, the mission gate, the source rewards, stale generation, the poll and the jump poll) and
-- nav points (area marker, inside trigger, attached marker, the arrival line), e the pirate dock (intel box, price,
-- purchase, poor, declined, own clan, range, grudge line), f the patrol dock (tip roll, thanks with fst, moved line), g
-- the treasurer (spawn at the home-facing enabled portal, war, ships counted, kills, leave, window, skips: write-back,
-- no war, caps, portal, retrieval off; jump void, load re-arm), h dump, repair, the load orphan rule, debug, config off,
-- the save size at the record bound.
-- Loads host_station.lua up to its first scenario, as host_captain.lua does. Stubs added in host_stubs.lua for this
-- module: ClearInventory and AddModuleToInventory on CreateStation objects, the NewTrigger kind "inside".

local f = openfile((getenv("TRF_TESTS") or "./").."host_station.lua", "r");
if not f then print("HOST FAIL host_stash.lua: cannot open host_station.lua"); exit(1); end;
local src = read(f, "*a");
closefile(f);
local cut = strfind(src, "\n-- a: install (12.1, 6.1)", 1, 1);
if not cut then print("HOST FAIL host_stash.lua: marker '-- a: install (12.1, 6.1)' missing in host_station.lua"); exit(1); end;
dostring(strsub(src, 1, cut), "host_station.lua");

-- Helpers ----------------------------------------------------------------------------------

-- Config of these runs: the repo defaults with stashes on, captains, the entry events, the pirate-dock offer, survivors
-- and the ladder off, log 2, no creation by the automatic region ticks (stash_chance 0), plus t.
function SH_Cfg(t)
	local c = {enable_stashes=1, cap_enable=0, sweeps=0, sweep_ct=0, feq=0, staged=0, seed=0, queue=0, parked=0, voice_events=0,
		dconv=0, carriers=0, po=0, enable_survivors=0, lad_enabled=0, log=2, tune={stash_chance={0, 0}}};
	if t then for k, v in t do c[k] = v; end; end;
	return c;
end;

-- Tune override k = v (TRF_Tune rebuilds on a changed cfg tune).
function SH_Tune(k, v)
	local h = HOST();
	local o = {};
	for a, b in h.cfg.tune do o[a] = b; end;
	o[k] = v;
	h.cfg.tune = o;
end;

-- Scenario start in sys at chapter label ch: every region in Build-up, no sweep planned, no stash state.
function SH_Begin(sys, ch, t)
	local h = HOST();
	h.labels.CurrentQuest = ch or "9_1";
	h.quests = {}; h.qlog = {};
	h.qs = FALSE;
	h.shsnap = {};
	h.rel_team = nil;
	S_Begin(sys, SH_Cfg(t));
	h.credits = 100000;
	for s = 1, TRF_RgMap().n do
		local rg = TRF.rg[s];
		rg.ph = 2; rg.pt = TRF.clock.legs; rg.sl = 0; rg.sn = 0; rg.sw = 0; rg.sr = nil;
		TRF.clan[s].so = nil; TRF.clan[s].sk = nil;
	end;
	TRF.stash = nil; TRF.stx = nil;
	TRF.clock.pz = nil;
end;

function SH_Idx(name) return V_Idx(name); end;
function SH_Slot(name) return TRF_RgOf(V_Idx(name)); end;

-- Record fixture at index i in system sys (defaults: a cls 2 cache at slot 1, st 0), fields of t override.
function SH_Rec(i, sys, t)
	local idx = V_Idx(sys);
	local r = {sys=idx, slot=1, clan=TRF_RgOf(idx), cls=2, v=200, seed=4711, leg=TRF.clock.legs, st=0, src=0, sf=0, sv=0, rf=0};
	if t then for k, v in t do r[k] = v; end; end;
	if type(TRF.stash) ~= "table" then TRF.stash = {}; end;
	TRF.stash[i] = r;
	return r;
end;

function SH_R(i) return TRF.stash and TRF.stash[i]; end;

-- Live cache object of index i in the scene, or nil.
function SH_Obj(i)
	local o = HOST().objs["TRF_STASH_"..i];
	if o and o.alive then return o; end;
	return nil;
end;

-- Jump to sys; keep = 1 emulates the location snapshot: the stash objects of sys left on the last visit (alive, and dead
-- with keep_dead) are back in the scene and in the label table.
function SH_Jump(sys, keep, pre)
	local h = HOST();
	TeleportToLocation(sys);
	local l = {};
	for i = 1, getn(h.ships) do
		local s = h.ships[i];
		if type(s.label) == "string" and strsub(s.label, 1, 10) == "TRF_STASH_" and (s.alive or h.keep_dead) then tinsert(l, s); end;
	end;
	h.shsnap[h.loc] = l;
	h.last = h.loc; h.loc = sys;
	h.triggers = {}; h.ships = {}; h.screen = {}; h.msgs = {};
	if keep == 1 and h.shsnap[sys] then
		for i = 1, getn(h.shsnap[sys]) do tinsert(h.ships, h.shsnap[sys][i]); end;
	end;
	print("HOST ---- enter "..sys.." (cleared "..HOST_ClearWithCarry().." globals)");
	HOST_MapInit();
	T_Scene(sys);
	for i = 1, getn(h.ships) do
		local s = h.ships[i];
		if type(s.label) == "string" then h.objs[s.label] = s; end;
	end;
	if pre then pre(); end;
	TRF_OnEnter();
	TRF_OnActivate();
end;

-- Mothership next to (x, y, z).
function SH_MsTo(x, y, z)
	HOST().ms.pos = Vector3(x, y, z);
end;

-- Slot position of record r.
function SH_Pos(r)
	return TRF_ShSlotPos(r);
end;

-- Kills the cache of index i with the player's hit first (hit = 1) or without; fires its died trigger.
function SH_Kill(i, hit)
	if hit == 1 then HOST_Fire("attack", "TRF_ShHit("..i..","); end;
	local o = SH_Obj(i);
	if o then o.alive = nil; end;
	return HOST_Fire("died", "TRF_ShDied("..i..",");
end;

-- Pirate docking (the vanilla Ok as __PirDock_Action leaves it, through trf_faction's wrapper and the dispatcher):
-- screen lines joined by "|", boxes opened, the newest box.
function SH_PirDock()
	local h = HOST();
	local s0, b0 = getn(h.screen), getn(h.boxes);
	_param = "pirate1";
	__PirStationDock_Ok();
	local r = {scr="", nb=getn(h.boxes) - b0, s0=s0};
	for i = s0 + 1, getn(h.screen) do r.scr = r.scr..h.screen[i].t.."|"; end;
	if r.nb > 0 then r.box = h.boxes[getn(h.boxes)]; end;
	return r;
end;

-- Patrol docking through the wrapper chain: screen lines and boxes as SH_PirDock.
function SH_PatDock()
	local h = HOST();
	local s0, b0 = getn(h.screen), getn(h.boxes);
	_param = GetCurrentLocation();
	__PatrolStationDock_Ok();
	local r = {scr="", nb=getn(h.boxes) - b0, s0=s0};
	for i = s0 + 1, getn(h.screen) do r.scr = r.scr..h.screen[i].t.."|"; end;
	if r.nb > 0 then r.box = h.boxes[getn(h.boxes)]; end;
	return r;
end;

-- Screen lines after the press of which on the box of dock result r.
function SH_Press(r, which)
	local h = HOST();
	if r.nb > 0 then HOST_Press(which, r.box); end;
	local s = "";
	for i = r.s0 + 1, getn(h.screen) do s = s..h.screen[i].t.."|"; end;
	return s;
end;

function SH_Has(s, t) return strfind(s or "", t, 1, 1); end;

-- Radio and screen texts since index m0, joined.
function SH_Msgs(m0)
	local s, q = "", HOST().msgs;
	for i = (m0 or 0) + 1, getn(q) do s = s..q[i].t.."|"; end;
	return s;
end;
function SH_Scr(s0)
	local s, q = "", HOST().screen;
	for i = (s0 or 0) + 1, getn(q) do s = s..q[i].t.."|"; end;
	return s;
end;

-- Live treasurer ships of index i.
function SH_Ret(i)
	local n = 0;
	for j = 1, 6 do
		local o = HOST().objs["trf_sh_"..i.."_"..j];
		if o and o.alive then n = n + 1; end;
	end;
	return n;
end;

function SH_Kv(line, k)
	local a, b, v = strfind(line, " "..k.."=([^ ]*)");
	return v;
end;

-- The last log line containing pat since mark n0, or nil.
function SH_Line(n0, pat)
	local q, l = HOST().logs, nil;
	for i = n0 + 1, getn(q) do if strfind(q[i], pat, 1, 1) then l = q[i]; end; end;
	return l;
end;

-- Marker labels of TRF.mk ("label=owner;...").
function SH_Mk(label)
	return type(TRF.mk) == "string" and strfind(TRF.mk, label.."=", 1, 1);
end;

-- Live nav point of label, or nil.
function SH_Nav(label)
	local q = HOST().navs;
	for i = 1, getn(q) do if q[i].alive and q[i].label == label then return q[i]; end; end;
	return nil;
end;

-- a: registration, toggles, tune, slots, texts, pure rules ---------------------------------------------

function T_SH_A()
	local h = HOST();
	SH_Begin("gaoba", "9_1");
	-- design/strength-spec.md 5.6: trf_str counts as an extra module (12 -> 13).
	-- design/fits-spec.md 7: trf_fits counts as an extra module (13 -> 14).
	HOST_Check(S_Logs(0, "module=core event=loaded map=true module_count=18 extra_count=18") >= 1, "trf_stash loads after trf_captain (extra_count=18 with trf_freight, trf_haunt, trf_parcel, trf_merc, trf_wq, trf_warn and trf_remark)");
	local ml = TRF_ModList();
	HOST_Check(ml[getn(ml) - 8] == "Sh" and TRF_Opt("enable_stashes") == 1 and TRF_Opt("enable_stash_retrieval") == 1 and TRF_Opt("enable_stash_decoys") == 0
		and TRF_Opt("stash_ret_war") == 0 and TRF_Opt("stash_at") == "", "TRF_ModList has Sh; toggles: stashes and retrieval on, decoys and ret_war off");
	SH_Tune("stash_chance", nil);
	h.cfg.tune = {};
	local T = TRF_ShTune();
	HOST_Check(T.stash_max == 4 and T.stash_live == 2 and T.stash_gap[1] == 15 and T.stash_gap[2] == 6 and T.stash_open_gap[1] == 30
		and T.stash_open_gap[2] == 10 and T.stash_ttl == 20 and T.stash_dead_legs == 10 and T.stash_chance[1] == 25 and T.stash_chance[2] == 35
		and T.stash_k == 3 and T.stash_cap[1] == 6000 and T.stash_cap[4] == 45000 and T.stash_intel_k == 150 and T.stash_intel_range == 4
		and T.stash_board_pct == 30 and T.stash_rumour_pct == 15 and T.stash_area_r == 150 and T.stash_find_r == 200
		and T.stash_ret_delay[1] == 60 and T.stash_ret_delay[2] == 150 and T.stash_ret_window == 180, "tune defaults of design 6");
	h.cfg.tune = {stash_max=9, stash_live=7, stash_ret_delay={200, 100}};
	T = TRF_ShTune();
	HOST_Check(T.stash_max == 4 and T.stash_live == 4 and T.stash_ret_delay[2] == 200, "clamps: stash_max at most 4, live at most max, delay hi >= lo");
	h.cfg.tune = {stash_chance={0, 0}};
	-- Registrations (trf_plumb).
	local P = TRF_PlReg();
	local lp, lb, ll, cg = "", "", "", 0;
	for i = 1, getn(P.dock.pir.box) do lb = lb..P.dock.pir.box[i].o..":"..TRF_PlName(P.dock.pir.box[i].f)..","; end;
	for i = 1, getn(P.dock.pir.line) do lp = lp..P.dock.pir.line[i].o..":"..TRF_PlName(P.dock.pir.line[i].f)..","; end;
	for i = 1, getn(P.dock.patrol.line) do ll = ll..P.dock.patrol.line[i].o..","; end;
	for i = 1, getn(P.cap) do if P.cap[i].g == "stash" and P.cap[i].t == 0 then cg = cg + 1; end; end;
	HOST_Check(SH_Has(lb, "100:TRF_Sh_PirBox,") and SH_Has(lb, "400:TRF_FcPoBox,") and SH_Has(lp, "20:TRF_Sh_PirLine,") and SH_Has(ll, "35,40,45,47,50,")
		and cg == 1, "pirate box 100 below S35 400, pirate line 20, patrol line 40 between 35 and 50, ship-cap group never trimmed ("..lb.." "..lp.." "..ll..")");
	-- Slots: every slot system is an allow-list system of a region, 1..4 slots each; the excluded systems have none.
	local sd = TRF_ShSlotData();
	local n, bad, regs = 0, "", {};
	for nm, l in sd do
		n = n + 1;
		local idx = V_Idx(nm);
		if not idx or not TRF_RgOf(idx) or getn(l) < 1 or getn(l) > 4 or TRF_Map().sys[idx].q ~= 0 then bad = bad.." "..nm; end;
		if idx then regs[TRF_RgOf(idx) or 0] = 1; end;
	end;
	local nr = 0;
	for k, v in regs do nr = nr + 1; end;
	HOST_Check(n == 11 and bad == "" and nr == 6 and not sd.fronn and not sd.tarrot and not sd.xb19 and not sd.llanovar2 and not sd.x244 and not sd.golkonda,
		"11 slot systems in 6 regions, never named in Quests.xml; Fronn, Tarrot, XB-19, Llanowar 2, X244 and Golkonda (no slot passes the rules) excluded"..bad);
	-- Texts: the per-system keys of every slot system, the fixed keys.
	local tx = TRF_Sh_Text();
	local miss, nt = "", 0;
	for k, v in tx do nt = nt + 1; end;
	for nm, l in sd do
		local key = gsub(nm, "[^%w]", "");
		for i, pre in {"stashintel", "stashtip", "stashthanks", "stashmoved", "stashgrudge"} do
			if type(tx[pre..key]) ~= "string" then miss = miss.." "..pre..key; end;
		end;
	end;
	HOST_Check(miss == "" and nt == 65 and type(tx.stasharrive) == "string" and type(tx.stashret2) == "string", "65 text keys: 5 per slot system and 10 fixed"..miss);
	HOST_Check(TRF_Txt("stashintelgaoba", "Black Comets", "1500 cr") == "Psst. Pirates (Black Comets) stuffed a hollow rock in the Gaoba belt with other people's goods. For a fee (1500 cr) I'll tell you which belt. What you do there is your business.",
		"the worked example's offer text");
	-- Pure: value budget (design 5 with 00 A3 lk; no d_k): early L_w 4 T1 R 4: 3 x 900 x 4 x 0.5 x 0.75 x 1.2 = 4860; mid L_w 10 T3 R 4:
	-- capped 20000; late L_w 15 T4 R 3 capped 45000.
	local v1, V1 = TRF_ShVOf(3, 4, 0.5, 0.75, 4, 6000);
	local v2, V2 = TRF_ShVOf(3, 10, 1, 1.5, 4, 20000);
	local v3, V3 = TRF_ShVOf(3, 15, 1, 2, 3, 45000);
	local v4 = TRF_ShVOf(0, 15, 1, 2, 3, 45000);
	HOST_Check(V1 == 4860 and v1 == 48 and V2 == 20000 and v2 == 200 and V3 == 45000 and v3 == 450 and v4 == 10, "V: 4860 early, 20000 mid cap, 45000 late cap, v = V / 100 within 10..450");
	HOST_Check(TRF_ShClsOf(1, 0) == 1 and TRF_ShClsOf(2, 0) == 1 and TRF_ShClsOf(3, 0) == 2 and TRF_ShClsOf(4, 0) == 3 and TRF_ShClsOf(2, 4) == 2
		and TRF_ShClsOf(3, 5) == 3 and TRF_ShClsOf(4, 9) == 3, "class: T1-T2 1, T3 2, T4 3; salvage >= 4 one up, at most 3");
	-- Fill: deterministic, within 100 x v, rare2 at most once for cls 3, never a ship, the remainder cargo.
	local L = {TRF_ShList(1), TRF_ShList(2), TRF_ShList(3), TRF_ShCargo()};
	local costs = TRF_Map().it;
	local K = TRF_ShK();
	local la, sa = TRF_ShFillOf(4711, 200, 2, L, nil, costs, K);
	local lb2, sb2 = TRF_ShFillOf(4711, 200, 2, L, nil, costs, K);
	local lc, sc2 = TRF_ShFillOf(4712, 200, 2, L, nil, costs, K);
	HOST_Check(TRF_ShItemsOf(la) == TRF_ShItemsOf(lb2) and sa == sb2 and sa <= 20000 and sa > 0 and TRF_ShItemsOf(la) ~= TRF_ShItemsOf(lc),
		"fill: the same seed and value give the same list ("..TRF_ShItemsOf(la).." "..sa.."), another seed another list, sum <= 100 v");
	local ships = {Trident_pl0=1, Hrimturs_pl0=1, Gunslinger_pl0=1, Wyvern_pl0=1, Wyvern_mk2_pl0=1, Dragon_pl0=1};
	local okf, r2c, fmok = 1, 0, 1;
	local fm = TRF_Map().fm[1];
	for s = 1, 60 do
		local l, sm = TRF_ShFillOf(s * 97, 450, 3, L, fm, costs, K);
		if sm > 45000 then okf = nil; end;
		local inr2, infm = 0, {};
		for j = 1, getn(l) do
			if ships[l[j].i] then okf = nil; end;
			local isfm = nil;
			for k = 1, getn(fm) do if fm[k] == l[j].i then isfm = 1; end; end;
			local iscg = strsub(l[j].i, 1, 6) == "Cargo_";
			if not isfm and not iscg then inr2 = inr2 + l[j].n; end;
		end;
		if inr2 > 1 then fmok = nil; end;
		if inr2 == 1 then r2c = r2c + 1; end;
	end;
	HOST_Check(okf and fmok and r2c > 0, "cls 3: the salvage modules, at most one rare2 item ("..r2c.." of 60 fills had one), never a ship, sum <= cap");
	local l1 = TRF_ShFillOf(5, 60, 1, L, nil, costs, K);
	local one = 0;
	for j = 1, getn(l1) do one = one + l1[j].n; end;
	local ll2, s2 = TRF_ShFillOf(5, 10, 2, L, nil, costs, K);
	HOST_Check(one >= 1 and s2 <= 1000, "cls 1 fill at v 60 ("..TRF_ShItemsOf(l1).."); v 10: within 1000 ("..TRF_ShItemsOf(ll2)..")");
	HOST_Check(TRF_ShPriceOf(150, 10, 1) == 1500 and TRF_ShPriceOf(150, 4, 1) == 600 and TRF_ShPriceOf(150, 15, 1) == 2250 and TRF_ShPriceOf(150, 10, 0.7) == 1050,
		"intel price 150 x L_w x d_k: 1500, 600, 2250, HARD 1050");
	HOST_Check(TRF_ShGapOf(20, 10, 5, 4, 15, 6) == 1 and not TRF_ShGapOf(19, 10, 5, 4, 15, 6) and not TRF_ShGapOf(40, 9, 5, 4, 15, 6)
		and TRF_ShGapOf(1, 1, nil, nil, 15, 6) == 1, "gaps need both legs and jumps; no stamp passes");
	local amax, ok3 = 0, 1;
	for s = 1, 50 do
		local a, d = TRF_ShAreaOf({x=100, y=5, z=-200}, s * 31, 150);
		local dd = sqrt((a.x - 100) * (a.x - 100) + (a.z + 200) * (a.z + 200));
		if dd > 151 or a.y ~= 5 then ok3 = nil; end;
		if dd > amax then amax = dd; end;
		local dl = TRF_ShDelayOf(s, 7, 60, 150);
		if dl < 60 or dl > 150 then ok3 = nil; end;
	end;
	HOST_Check(ok3 and amax > 50, "area point within 150 of the slot ("..floor(amax).." max), delay within 60..150");
	HOST_Check(TRF_ShRetKeyOf(1) == "stashret1" and TRF_ShRetKeyOf(2) == "stashret3" and TRF_ShRetKeyOf(3) == "stashret2" and TRF_ShRetKeyOf(4) == "stashret2",
		"treasurer lines: T1 ret1, T2 ret3, T3+ ret2");
end;

-- b: region tick: creation and expiry ----------------------------------------------------------------

function T_SH_B()
	local h = HOST();
	SH_Begin("aurora", "9_1");
	SH_Tune("stash_chance", {100, 100});
	SH_Tune("stash_ttl", 200);
	local L = TRF.clock.legs;
	local kadi = SH_Slot("gaoba");
	local mos = SH_Slot("areko");
	-- Only Build-up and Raids create: every region in Quiet first.
	for s = 1, TRF_RgMap().n do TRF.rg[s].ph = 0; end;
	TRF_Sh_RegionTick(L);
	HOST_Check(TRF_ShRecN() == 0, "Quiet everywhere: no record");
	TRF.rg[kadi].ph = 1;
	TRF_Sh_RegionTick(L);
	HOST_Check(TRF_ShRecN() == 0, "Boom: no record");
	TRF.rg[kadi].ph = 2;
	-- Guard (chapter 4) and a mission in progress: none.
	h.labels.CurrentQuest = "4_1";
	local n0 = S_Mark();
	TRF_Sh_RegionTick(L);
	HOST_Check(TRF_ShRecN() == 0 and S_Logs(n0, "event=create leg="..L.." result=none reason=guard") == 1, "guard: no record");
	h.labels.CurrentQuest = "9_1";
	h.qs = TRUE;
	n0 = S_Mark();
	TRF_Sh_RegionTick(L);
	HOST_Check(TRF_ShRecN() == 0 and S_Logs(n0, "reason=quest") == 1, "mission in progress: no record");
	h.qs = FALSE;
	-- Build-up, chance 100: one record per tick, never the current system, an allow-list system of the region.
	n0 = S_Mark();
	TRF_Sh_RegionTick(L);
	local r = SH_R(1);
	HOST_Check(r and r.clan == kadi and TRF_RgOf(r.sys) == kadi and TRF_ShSlots(TRF_ShName(r.sys)) and r.st == 0 and r.leg == L and r.seed >= 1
		and r.slot >= 1 and TRF_ShRecN() == 1 and S_Logs(n0, "module=stash event=create index=1") == 1, "Build-up: one record in the Kadi region ("..
		(r and TRF_ShName(r.sys) or "nil")..")");
	local x = TRF.stx;
	HOST_Check(x.n == 1 and x.lc == L and x.jc == TRF_Jumps() and TRF.clan[kadi].sk == L, "stx.n, lc, jc and the clan's sk stamped");
	-- One record per clan; the gap holds both counters.
	TRF.rg[mos].ph = 3;
	TRF_Sh_RegionTick(L + 1);
	HOST_Check(TRF_ShRecN() == 1 and S_Logs(n0, "reason=gap") == 1, "stash_gap: 15 legs and 6 jumps");
	TRF.clock.legs = L + 15;
	TRF_Sh_RegionTick(L + 15);
	HOST_Check(TRF_ShRecN() == 1, "15 legs but no jumps: still the gap");
	TRF.clock.j = TRF.clock.j + 6;
	TRF_Sh_RegionTick(L + 15);
	local r2 = SH_R(2);
	HOST_Check(r2 and r2.clan == mos and TRF_ShRecN() == 2, "after 15 legs and 6 jumps: the Moscowia region (Raids) gets the second record");
	-- stash_live 2: no third.
	TRF.clock.legs = L + 30; TRF.clock.j = TRF.clock.j + 6;
	TRF_Sh_RegionTick(L + 30);
	HOST_Check(TRF_ShRecN() == 2 and S_Logs(n0, "reason=live") >= 1, "stash_live 2 unopened records");
	-- Never the current system: the only candidate of a region is the current system.
	SH_Jump("gaoba");
	TRF.stash = nil; TRF.stx = nil;
	for s = 1, TRF_RgMap().n do TRF.rg[s].ph = 0; end;
	TRF.rg[kadi].ph = 2;
	L = TRF.clock.legs;
	SH_Rec(1, "b_leftera3", {clan=99});
	SH_Rec(2, "altair", {clan=98});
	TRF_Sh_RegionTick(L);
	HOST_Check(TRF_ShRecN() == 2 and S_Logs(0, "reason=no_region") >= 1, "the only free Kadi system is the current one: no record");
	-- The oldest region first (clan.sk).
	TRF.stash = nil; TRF.stx = nil;
	TRF.rg[mos].ph = 2;
	TRF.clan[kadi].sk = L - 5; TRF.clan[mos].sk = L - 9;
	TRF_Sh_RegionTick(L);
	HOST_Check(SH_R(1) and SH_R(1).clan == mos, "the region whose last cache is oldest rolls first");
	-- so and an open sweep attempt block the region.
	TRF.stash = nil; TRF.stx = nil;
	TRF.clan[mos].so = 1;
	TRF.rg[kadi].sl = L; TRF.rg[kadi].sn = 0;
	TRF_Sh_RegionTick(L);
	HOST_Check(TRF_ShRecN() == 0, "so = 1 (Moscowia) and an open sweep (Kadi): no record");
	TRF.rg[kadi].sl = 0;
	-- so clears when the region is in Quiet.
	TRF.rg[mos].ph = 0;
	n0 = S_Mark();
	TRF_Sh_RegionTick(L);
	HOST_Check(TRF.clan[mos].so == nil and S_Logs(n0, "event=so region="..mos.." result=cleared") == 1, "so cleared in Quiet");
	-- Chance: Build-up 25, Raids 35 (stash_chance), by the hash of leg, region and stx.n.
	h.cfg.tune = {};
	local hits = {0, 0};
	for k = 1, 200 do
		TRF.stash = nil; TRF.stx = {n=k, op=0, opp=0};
		TRF.rg[kadi].ph = 2 + mod(k, 2);
		for s = 1, TRF_RgMap().n do if s ~= kadi then TRF.rg[s].ph = 0; end; end;
		TRF_Sh_RegionTick(L + k);
		if TRF_ShRecN() == 1 then hits[1 + mod(k, 2)] = hits[1 + mod(k, 2)] + 1; end;
	end;
	HOST_Check(hits[1] >= 10 and hits[1] <= 45 and hits[2] >= 15 and hits[2] <= 55, "chance about 25 % in Build-up ("..hits[1].."/100) and 35 % in Raids ("..hits[2].."/100)");
	-- Deterministic: the same saved state gives the same answer.
	TRF.stash = nil; TRF.stx = {n=5, op=0, opp=0};
	SH_Tune("stash_chance", {100, 100});
	TRF_Sh_RegionTick(L + 1000);
	local a1 = SH_R(1) and (SH_R(1).sys..":"..SH_R(1).slot..":"..SH_R(1).seed);
	TRF.stash = nil; TRF.stx = {n=5, op=0, opp=0};
	TRF.clan[kadi].sk = nil;
	TRF_Sh_RegionTick(L + 1000);
	local a2 = SH_R(1) and (SH_R(1).sys..":"..SH_R(1).slot..":"..SH_R(1).seed);
	HOST_Check(a1 and a1 == a2, "a reload before the tick gives the same system, slot and seed ("..tostring(a1)..")");
	-- The prize gap (00 B1): no creation while TRF_PrizeWait() > 0.
	TRF.stash = nil; TRF.stx = nil;
	TRF.clock.pz = TRF.clock.rs;
	TRF_Sh_RegionTick(L + 2000);
	HOST_Check(TRF_ShRecN() == 0 and S_Logs(0, "reason=prize") >= 1, "shared prize gap running: no record");
	TRF.clock.pz = nil;
	-- The open gap: 30 legs and 10 jumps after an on-screen opening.
	TRF.stx = {n=0, op=1, opp=1, lo=L + 2000, jo=TRF.clock.j};
	TRF_Sh_RegionTick(L + 2029);
	HOST_Check(TRF_ShRecN() == 0 and S_Logs(0, "reason=open_gap") >= 1, "stash_open_gap: 29 legs");
	TRF.clock.j = TRF.clock.j + 10;
	TRF_Sh_RegionTick(L + 2030);
	HOST_Check(TRF_ShRecN() == 1, "after 30 legs and 10 jumps a record again");
	-- cls 3 banks one salvage point (sv = the faction), returned at the expiry; the moved notice for a known cache.
	TRF.stash = nil; TRF.stx = nil;
	SH_Tune("stash_ttl", 20);
	TRF.clan[kadi].sc = 99; TRF.clan[kadi].sv = 5; TRF.clan[kadi].sf = 4;
	for s = 1, TRF_RgMap().n do if s ~= kadi then TRF.rg[s].ph = 0; end; end;
	TRF.rg[kadi].ph = 3;
	TRF_Sh_RegionTick(L + 3000);
	r = SH_R(1);
	HOST_Check(r and r.cls == 3 and r.sv == 4 and TRF.clan[kadi].sv == 4, "T4 with salvage 5: cls 3, one point banked (sv = faction 4)");
	r.st = 1;
	n0 = S_Mark();
	TRF_Sh_RegionTick(r.leg + 20);
	HOST_Check(SH_R(1) == nil and TRF.clan[kadi].sv == 5 and TRF.stx.ms == r.sys and TRF.stx.mc == kadi and S_Logs(n0, "event=expire index=1") == 1
		and S_Logs(n0, "reason=ttl") == 1, "stash_ttl 20: expired, salvage returned, the moved notice kept");
	-- The open-gap expiry: every other unopened record created before the opening goes at the next tick.
	TRF.stash = nil; TRF.stx = {n=3, op=1, opp=1, lo=L + 3100, jo=TRF.clock.j};
	SH_Rec(1, "areko", {leg=L + 3090});
	SH_Rec(2, "fiasar", {leg=L + 3101});
	TRF_Sh_RegionTick(L + 3102);
	HOST_Check(SH_R(1) == nil and SH_R(2) ~= nil and S_Logs(0, "reason=open_gap") >= 1, "after an opening older unopened records move");
	-- Opened records are kept stash_dead_legs (10), then removed.
	TRF.stash = nil;
	SH_Rec(1, "areko", {st=2, leg=L + 3200});
	TRF_Sh_RegionTick(L + 3209);
	HOST_Check(SH_R(1) ~= nil, "opened record kept 9 legs");
	TRF_Sh_RegionTick(L + 3210);
	HOST_Check(SH_R(1) == nil, "removed after stash_dead_legs 10");
	-- The current system's record never expires at the tick.
	SH_Rec(1, "gaoba", {leg=L - 100});
	TRF_Sh_RegionTick(L + 4000);
	HOST_Check(SH_R(1) ~= nil, "the current system's record waits");
	-- Record bound: stash_max 4 indices.
	h.cfg.tune = {stash_chance={100, 100}, stash_live=4, stash_gap={0, 0}};
	TRF.stash = nil; TRF.stx = nil;
	for s = 1, TRF_RgMap().n do TRF.rg[s].ph = 2; TRF.clan[s].so = nil; end;
	for k = 1, 12 do TRF_Sh_RegionTick(L + 5000 + k); end;
	local ci = 0;
	for k, v in TRF.stash do ci = ci + 1; if type(k) ~= "number" or k < 1 or k > 4 then ci = 99; end; end;
	HOST_Check(ci == 4 and S_Logs(0, "reason=live") >= 1, "at most 4 records, indices 1..4 ("..ci..")");
end;

-- c: entry reconciliation ----------------------------------------------------------------------------

function T_SH_C()
	local h = HOST();
	SH_Begin("aurora", "9_1");
	local r = SH_Rec(1, "gaoba", {st=0, seed=4711, v=200});
	local n0 = S_Mark();
	SH_Jump("gaoba");
	local o = SH_Obj(1);
	local p = SH_Pos(SH_R(1));
	HOST_Check(o and o.kind == "station" and o.model == "Asteroid_inv_Val" and o.pos.x == p.x and o.pos.z == p.z and getn(o.inv) >= 1
		and S_Logs(n0, "event=reconcile index=1 system=gaoba label=TRF_STASH_1 state=0 object=missing") == 1 and S_Logs(n0, "result=create") == 1,
		"entry: CreateStation(Asteroid_inv_Val) at the slot, labelled TRF_STASH_1, filled");
	local fl = SH_Line(n0, "module=stash event=fill index=1");
	HOST_Check(fl and SH_Kv(fl, "seed") == "4711" and SH_Kv(fl, "value") == "200" and tonumber(SH_Kv(fl, "sum")) <= 20000, "fill line: "..tostring(fl));
	HOST_Check(HOST_Count("died", "TRF_ShDied(1,") == 1 and HOST_Count("attack", "TRF_ShHit(1,") == 1 and HOST_Count("inside") == 0
		and T_BadCallbacks() == "", "died and attack triggers with the generation; unknown cache: no nav, no inside trigger");
	-- Slot clearance (E7.6): 60 s after the entry, the HP and the distance moved, once.
	n0 = S_Mark();
	T_Tick(130, 0.5);
	HOST_Check(S_Logs(n0, "module=stash event=slot system=gaoba slot=1 hp=100000 moved=0") == 1, "slot clearance line after 60 s, once");
	-- Re-entry with the object kept: reuse and the same fill (E7.4).
	SH_Jump("heos", nil);
	n0 = S_Mark();
	SH_Jump("gaoba", 1);
	local f2 = SH_Line(n0, "module=stash event=fill index=1");
	HOST_Check(SH_Obj(1) == o and S_Logs(n0, "result=reuse") == 1 and o.cleared >= 2 and SH_Kv(f2, "items") == SH_Kv(fl, "items")
		and SH_Kv(f2, "sum") == SH_Kv(fl, "sum"), "re-entry: reuse, ClearInventory and the identical fill");
	SH_Jump("heos", nil);
	n0 = S_Mark();
	SH_Jump("gaoba", 1);
	HOST_Check(SH_Kv(SH_Line(n0, "module=stash event=fill index=1"), "items") == SH_Kv(fl, "items"), "third entry: identical fill");
	-- Dead while away: opened without the player (st 2, clan loss -2 x cls, no so, no treasurer).
	SH_Jump("heos", nil);
	o.alive = nil;
	h.keep_dead = 1;
	local kadi = SH_Slot("gaoba");
	local sc0 = TRF.clan[kadi].sc;
	n0 = S_Mark();
	SH_Jump("gaoba", 1);
	h.keep_dead = nil;
	r = SH_R(1);
	HOST_Check(r.st == 2 and r.rf == 0 and TRF.clan[kadi].so == nil and S_Logs(n0, "result=lost") == 1
		and S_Logs(n0, "event=open index=1 system=gaoba player=false clan_score_change=-4 reason=entry") == 1, "dead at entry: st 2, clan -4, no so, no treasurer");
	-- st 2 with a live object (E2-negative): deleted.
	SH_Jump("heos", nil);
	local zombie = CreateStation("Asteroid_inv_Val", Vector3(p.x, p.y, p.z), Vector3(0, 0, 1));
	SetObjectLabel(zombie, "TRF_STASH_1");
	h.shsnap.gaoba = {zombie};
	n0 = S_Mark();
	SH_Jump("gaoba", 1);
	HOST_Check(not zombie.alive and S_Logs(n0, "state=2 object=alive") == 1 and S_Logs(n0, "result=delete") == 1, "st 2, object alive: deleted");
	-- Orphan: the label of index 2 answers here, record 2 is elsewhere (a moved cache).
	SH_Rec(2, "areko");
	SH_Jump("heos", nil);
	local orph = CreateStation("Asteroid_inv_Val", Vector3(0, 0, 900), Vector3(0, 0, 1));
	SetObjectLabel(orph, "TRF_STASH_2");
	h.shsnap.gaoba = {orph};
	n0 = S_Mark();
	SH_Jump("gaoba", 1);
	HOST_Check(not orph.alive and S_Logs(n0, "event=orphan_delete index=2 system=gaoba") == 1, "orphan: deleted at entry");
	-- enable_stashes 0: every TRF_STASH_<i> object deleted at entry; records kept.
	TRF.stash = nil;
	SH_Rec(1, "gaoba");
	SH_Jump("heos", nil);
	SH_Jump("gaoba", nil);
	o = SH_Obj(1);
	SH_Jump("heos", nil);
	h.cfg.enable_stashes = 0;
	n0 = S_Mark();
	SH_Jump("gaoba", 1);
	HOST_Check(o and not o.alive and SH_R(1) ~= nil and S_Logs(n0, "module=stash event=disabled system=gaoba deleted=1") == 1, "enable_stashes 0: object deleted, record kept");
	-- Off: no region tick creation, no dock lines.
	SH_Tune("stash_chance", {100, 100});
	TRF.stash = nil; TRF.stx = nil;
	TRF_Sh_RegionTick(TRF.clock.legs);
	HOST_Check(TRF_ShRecN() == 0, "enable_stashes 0: no record at the tick");
	h.cfg.enable_stashes = 1;
	SH_Tune("stash_chance", {0, 0});
	-- A mission entry: the object is created (transit), no line, no nav point.
	TRF.stash = nil;
	SH_Rec(1, "gaoba", {st=1, src=1, sf=6});
	SH_Jump("heos", nil);
	h.qs = TRUE;
	n0 = S_Mark();
	SH_Jump("gaoba", nil);
	HOST_Check(SH_Obj(1) and not SH_Mk("TRF_STASH_AR_1") and HOST_Count("inside") == 0 and S_Logs(n0, "owner=stash") == 0,
		"mission entry: the object exists, no area marker, no inside trigger, no arrival line");
	h.qs = FALSE;
	-- Load inside the system: no creation for a missing object, reuse of the live one.
	TRF.stash = nil;
	SH_Rec(1, "gaoba", {st=0});
	local o1 = SH_Obj(1);
	o1.alive = nil; o1.label = nil;
	h.objs["TRF_STASH_1"] = nil;
	n0 = S_Mark();
	T_SaveLoad();
	HOST_Check(not SH_Obj(1) and SH_R(1).st == 0 and S_Logs(n0, "result=create") == 0 and S_Logs(n0, "event=reconcile index=1 system=gaoba label=TRF_STASH_1 state=0 object=missing hp=nil result=none") == 1,
		"load: the missing object is not created");
	-- Index reuse: a new record with the index of an expired one in the same system takes over neither its rock
	-- (alive: deleted, the new cache placed at its own slot) nor its hulk (dead: not lost, placed).
	TRF.stash = nil; TRF.stx = nil;
	SH_Rec(1, "gaoba", {st=0, slot=1});
	SH_Jump("heos", nil);
	SH_Jump("gaoba", nil);
	local old = SH_Obj(1);
	SH_Jump("heos", nil);
	TRF.stash = nil;
	r = SH_Rec(1, "gaoba", {st=0, slot=3});
	n0 = S_Mark();
	SH_Jump("gaoba", 1);
	r = SH_R(1);
	p = SH_Pos(r);
	local nw = SH_Obj(1);
	HOST_Check(old and not old.alive and nw and nw ~= old and nw.pos.x == p.x and nw.pos.z == p.z and r.pl == 1
		and S_Logs(n0, "event=orphan_delete index=1 system=gaoba object=alive reason=index") == 1 and S_Logs(n0, "result=create") == 1,
		"index reuse, old rock alive: deleted, the new record's cache created at its slot");
	SH_Jump("heos", nil);
	nw.alive = nil;
	TRF.stash = nil;
	r = SH_Rec(1, "gaoba", {st=0, slot=1});
	h.keep_dead = 1;
	n0 = S_Mark();
	SH_Jump("gaoba", 1);
	h.keep_dead = nil;
	r = SH_R(1);
	HOST_Check(r.st == 0 and SH_Obj(1) and S_Logs(n0, "event=open index=1") == 0 and S_Logs(n0, "result=lost") == 0 and S_Logs(n0, "object=dead reason=index") == 1,
		"index reuse, old hulk dead: not lost, the cache created");
	SH_Jump("heos");
end;

-- d: triggers and nav points --------------------------------------------------------------------------

function T_SH_D()
	local h = HOST();
	SH_Begin("aurora", "9_1");
	local kadi, mos = SH_Slot("gaoba"), SH_Slot("areko");
	SH_Rec(1, "gaoba", {st=1, src=1, sf=mos, cls=2});
	local n0 = S_Mark();
	SH_Jump("gaoba");
	local r = SH_R(1);
	local p = SH_Pos(r);
	local nav = SH_Nav("TRF_STASH_AR_1");
	local dx = nav and sqrt((nav.pos.x - p.x) * (nav.pos.x - p.x) + (nav.pos.z - p.z) * (nav.pos.z - p.z));
	HOST_Check(nav and dx <= 150 and nav.icon == "nav_Asteroid_inv.dds" and nav.obj == nil and SH_Mk("TRF_STASH_AR_1") and HOST_Count("inside", "TRF_ShIn(1,") == 1,
		"known cache: area nav point within 150 of the slot ("..tostring(dx and floor(dx))..", vanilla icon), inside trigger");
	HOST_Check(S_Logs(n0, "module=plumb event=arrival_line owner=stash line_index=1") == 1, "the stash arrival line is queued through the plumbing");
	local s0 = getn(h.screen);
	T_Tick(30, 0.5);
	HOST_Check(SH_Has(SH_Scr(s0), "Beacon ping detected in this system's belt"), "arrival line shown");
	-- Inside trigger: the attached nav point and the found line, once.
	s0 = getn(h.screen);
	HOST_Fire("inside", "TRF_ShIn(1,");
	local np = SH_Nav("TRF_STASH_NP_1");
	HOST_Check(np and np.obj == SH_Obj(1) and np.text == "#M_Name_Asteroid_inv_Val" and SH_Has(SH_Scr(s0), "This rock is hollow"), "inside: nav point attached to the rock, found line");
	TRF_ShFound(1, "poll");
	HOST_Check(S_Logs(0, "event=found index=1") == 1, "found once a visit");
	-- Open without the player's hit: st 2, so, clan -2 x cls, lo/jo, op; no opp, no treasurer, nav points gone.
	local sc0, sc6 = TRF.clan[kadi].sc, TRF.clan[mos].sc;
	n0 = S_Mark();
	SH_Kill(1, nil);
	r = SH_R(1);
	local x = TRF.stx;
	HOST_Check(r.st == 2 and r.leg == TRF.clock.legs and TRF.clan[kadi].so == 1 and TRF.clan[kadi].sc == max(0, sc0 - 4) and TRF.clan[mos].sc == sc6
		and x.lo == TRF.clock.legs and x.jo == TRF.clock.j and x.op == 1 and (x.opp or 0) == 0 and r.rf == 0 and not SH_Mk("TRF_STASH_AR_1")
		and not SH_Mk("TRF_STASH_NP_1"), "died without a hit: opened (so, clan -4, open stamps), no seller bonus, no treasurer, nav points gone");
	HOST_Check(S_Logs(n0, "module=stash event=died index=1 generation="..TRF.gen.." system=gaoba hit=false class=2") == 1, "died line (E7.2)");
	SH_Kill(1, nil);
	HOST_Check(TRF.stx.op == 1, "a second died event does nothing");
	-- With the player's hit and pirate-dock intel: opp, seller clan +2, open line, rf 1 and the timer, the prize stamp.
	TRF.stash = nil; TRF.stx = nil; TRF.clan[kadi].so = nil;
	SH_Rec(1, "gaoba", {st=1, src=1, sf=mos, cls=1});
	SH_Jump("heos");
	SH_Jump("gaoba");
	sc0, sc6 = TRF.clan[kadi].sc, TRF.clan[mos].sc;
	s0 = getn(h.screen);
	n0 = S_Mark();
	SH_Kill(1, 1);
	r = SH_R(1);
	HOST_Check(r.st == 2 and r.rf == 1 and TRF.stx.opp == 1 and TRF.clan[mos].sc == min(99, sc6 + 2) and TRF.clan[kadi].sc == max(0, sc0 - 2)
		and SH_Has(SH_Scr(s0), "Cache cracked") and TRF.clock.pz == TRF.clock.rs and S_Logs(n0, "event=ret index=1 delay=") == 1
		and S_Logs(n0, "hit=true") == 1, "died after a hit: opp, seller +2, clan -2 (cls 1), open line, prize stamp, treasurer due");
	-- Patrol source: stx.pt and ps; a mission in progress: rf 2.
	TRF.stash = nil; TRF.stx = nil; TRF.clan[kadi].so = nil;
	SH_Rec(1, "gaoba", {st=1, src=2, sf=5});
	SH_Jump("heos");
	SH_Jump("gaoba");
	h.qs = TRUE;
	n0 = S_Mark();
	SH_Kill(1, 1);
	h.qs = FALSE;
	r = SH_R(1);
	HOST_Check(r.rf == 2 and getn(TRF.stx.pt) == 1 and TRF.stx.pt[1].f == 5 and TRF.stx.pt[1].s == V_Idx("gaoba") and TRF.stx.ps == nil
		and S_Logs(n0, "treasurer=2 quest=true") == 1, "patrol tip source: pt = {{f=5, s=gaoba}}; during a mission rf 2 at once (E7.10)");
	-- Stale generation (E7.5): an old trigger after a load.
	TRF.stash = nil; TRF.stx = nil; TRF.clan[kadi].so = nil;
	SH_Rec(1, "gaoba", {st=0});
	SH_Jump("heos");
	SH_Jump("gaoba");
	local g0 = TRF.gen;
	local old = nil;
	for i = 1, getn(h.triggers) do if h.triggers[i].kind == "died" and SH_Has(h.triggers[i].action, "TRF_ShDied(1,") then old = h.triggers[i]; end; end;
	T_SaveLoad();
	n0 = S_Mark();
	SH_Obj(1).alive = nil;
	HOST_Run(old);
	HOST_Check(SH_R(1).st == 0 and S_Logs(n0, "module=stash event=stale index=1 generation="..g0) == 1, "old-gen trigger: stale line, nothing changes");
	HOST_Fire("died", "TRF_ShDied(1,"..TRF.gen);
	HOST_Check(SH_R(1).st == 2 and S_Logs(n0, "event=died index=1 generation="..TRF.gen) == 1, "the re-armed trigger of the load opens it, exactly once");
	-- Poll: an object gone without its died event; the jump poll.
	TRF.stash = nil; TRF.stx = nil; TRF.clan[kadi].so = nil;
	SH_Rec(1, "gaoba", {st=0});
	SH_Jump("heos");
	SH_Jump("gaoba");
	SH_Obj(1).alive = nil;
	T_Tick(4, 0.5);
	HOST_Check(SH_R(1).st == 2 and S_Logs(0, "reason=poll") >= 1, "poll: dead object opened");
	TRF.stash = nil; TRF.stx = nil; TRF.clan[kadi].so = nil;
	SH_Rec(1, "gaoba", {st=0});
	SH_Jump("heos");
	SH_Jump("gaoba");
	HOST_Fire("attack", "TRF_ShHit(1,");
	SH_Obj(1).alive = nil;
	n0 = S_Mark();
	SH_Jump("heos");
	HOST_Check(SH_R(1).st == 2 and SH_R(1).rf == 2 and S_Logs(n0, "reason=jump") >= 1, "jump poll: opened before the jump, treasurer void (jump)");
	-- Find poll (fallback of the inside trigger) and nav points re-added after a load.
	TRF.stash = nil; TRF.stx = nil; TRF.clan[kadi].so = nil;
	SH_Rec(1, "gaoba", {st=1, src=1, sf=mos});
	SH_Jump("gaoba");
	p = SH_Pos(SH_R(1));
	T_SaveLoad();
	HOST_Check(SH_Mk("TRF_STASH_AR_1") and HOST_Count("inside", "TRF_ShIn(1,"..TRF.gen) == 1, "load: area marker and inside trigger again");
	SH_MsTo(p.x + 100, p.y, p.z);
	T_Tick(4, 0.5);
	HOST_Check(SH_Mk("TRF_STASH_NP_1") and S_Logs(0, "event=found index=1 system=gaoba reason=poll") == 1, "find poll within 200: attached marker");
	SH_Jump("heos");
end;

-- e: pirate dock -------------------------------------------------------------------------------------

function T_SH_E()
	local h = HOST();
	SH_Begin("moscowia", "9_1");
	local kadi, mos = SH_Slot("gaoba"), SH_Slot("moscowia");
	SH_Rec(1, "gaoba", {st=0, seed=4711});
	local c0 = h.credits;
	local n0 = S_Mark();
	local p0 = h.pir_ok;
	local d = SH_PirDock();
	HOST_Check(d.nb == 1 and SH_Has(d.box.text, "Psst. Pirates ("..TRF_ClanName(kadi)..") stuffed a hollow rock in the Gaoba belt") and SH_Has(d.box.text, "(1500 cr)")
		and S_Logs(n0, "event=intel index=1 system=gaoba price=1500 jumps=3 result=offered") == 1 and h.pir_ok == p0,
		"Moscowia pirate dock, Gaoba 3 jumps: intel box, 150 x L_w 10 = 1500 (the vanilla shop waits for the answer)");
	local s = SH_Press(d, "ok");
	local r = SH_R(1);
	HOST_Check(h.credits == c0 - 1500 and r.st == 1 and r.src == 1 and r.sf == mos and SH_Has(s, "Look for the rock that pings") and h.pir_ok == p0 + 1
		and S_Logs(n0, "event=intel index=1 price=1500 credits_before="..c0.." credits_after="..(c0 - 1500).." seller="..mos.." result=ok") == 1,
		"OK: 1500 credits, st 1, src 1, sf the seller clan, the bought line, then the shop (E7.8)");
	d = SH_PirDock();
	HOST_Check(d.nb == 0, "intel only for st 0: no second offer");
	-- Declined: not offered again in this visit; offered in the next.
	r.st = 0; r.src = 0; r.sf = 0;
	d = SH_PirDock();
	SH_Press(d, "cancel");
	HOST_Check(r.st == 0 and S_Logs(0, "event=intel index=1 result=declined") == 1, "Cancel: nothing bought");
	d = SH_PirDock();
	HOST_Check(d.nb == 0, "declined: not again this visit");
	SH_Jump("fort_russ");
	SH_Jump("moscowia");
	d = SH_PirDock();
	HOST_Check(d.nb == 1, "next visit: offered again");
	SH_Press(d, "cancel");
	-- Poor.
	h.credits = 100;
	SH_Jump("fort_russ"); SH_Jump("moscowia");
	d = SH_PirDock();
	s = SH_Press(d, "ok");
	HOST_Check(SH_R(1).st == 0 and h.credits == 100 and SH_Has(s, "No credits, no secrets"), "not enough credits: poor line, nothing changes");
	h.credits = 100000;
	-- Own clan's cache never offered; beyond stash_intel_range not offered; mission and guard none.
	TRF.stash = nil;
	SH_Rec(1, "areko", {st=0});
	SH_Jump("fort_russ"); SH_Jump("moscowia");
	d = SH_PirDock();
	HOST_Check(d.nb == 0, "the dock's own clan: no offer");
	TRF.stash = nil;
	SH_Rec(1, "b_leftera3", {st=0});
	SH_Jump("fort_russ"); SH_Jump("moscowia");
	d = SH_PirDock();
	HOST_Check(d.nb == 0, "Beta Lethera 3, 8 jumps: beyond stash_intel_range 4");
	TRF.stash = nil;
	SH_Rec(1, "gaoba", {st=0});
	SH_Jump("fort_russ"); SH_Jump("moscowia");
	h.qs = TRUE;
	d = SH_PirDock();
	h.qs = FALSE;
	HOST_Check(d.nb == 0, "mission in progress: no offer");
	h.labels.CurrentQuest = "4_1";
	SH_Jump("fort_russ"); SH_Jump("moscowia");
	d = SH_PirDock();
	HOST_Check(d.nb == 0, "guard: no offer");
	h.labels.CurrentQuest = "9_1";
	-- S35 above: with the pirate-side offer on and an offer to make, the S35 box wins (priority 400).
	h.cfg.po = 1;
	SH_Jump("fort_russ"); SH_Jump("moscowia");
	d = SH_PirDock();
	HOST_Check(d.nb <= 1 and (d.nb == 0 or not SH_Has(d.box.text, "hollow rock") or S_Logs(0, "box=stash_intel") >= 1), "one box per docking with S35 on");
	h.cfg.po = 0;
	-- Grudge: the victim clan's own dock while its opened record (player) is kept.
	TRF.stash = nil;
	SH_Rec(1, "egleon", {st=2, rf=2});
	SH_Jump("fort_russ"); SH_Jump("moscowia");
	d = SH_PirDock();
	HOST_Check(SH_Has(d.scr, "Somebody cracked our rock in Egleon") and d.nb == 0, "grudge line at the victim's dock, no box");
	d = SH_PirDock();
	HOST_Check(not SH_Has(d.scr, "Somebody cracked"), "grudge once a visit");
	SH_R(1).rf = 0;
	SH_Jump("fort_russ"); SH_Jump("moscowia");
	d = SH_PirDock();
	HOST_Check(not SH_Has(d.scr, "Somebody cracked"), "opened without the player: no grudge");
end;

-- f: patrol dock -------------------------------------------------------------------------------------

function T_SH_F()
	local h = HOST();
	SH_Begin("moscowia", "9_1");
	SH_Tune("stash_board_pct", 100);
	SH_Rec(1, "egleon", {st=0, seed=4711});
	local n0 = S_Mark();
	local d = SH_PatDock();
	local r = SH_R(1);
	HOST_Check(SH_Has(d.scr, "Patrol note: smugglers keep pinging a beacon in the Egleon asteroid belt") and r.st == 1 and r.src == 2 and r.sf == 1
		and S_Logs(n0, "event=tip index=1 system=egleon faction=1") == 1, "tip within 3 jumps (board 100 %): st 1, src 2, sf = Vks (1)");
	d = SH_PatDock();
	HOST_Check(not SH_Has(d.scr, "Patrol note"), "known: no second tip");
	-- One roll per record per visit at 0 %; out of range none.
	SH_Tune("stash_board_pct", 0);
	r.st = 0; r.src = 0; r.sf = 0;
	SH_Jump("fort_russ"); SH_Jump("moscowia");
	d = SH_PatDock();
	HOST_Check(r.st == 0, "board 0 %: no tip");
	SH_Tune("stash_board_pct", 100);
	d = SH_PatDock();
	HOST_Check(r.st == 0, "one roll per record per visit");
	TRF.stash = nil;
	SH_Rec(1, "lasad", {st=0});
	SH_Jump("fort_russ"); SH_Jump("moscowia");
	d = SH_PatDock();
	HOST_Check(SH_R(1).st == 0, "Lasad 6 jumps: no tip (3 jumps)");
	-- Mission: no tip.
	TRF.stash = nil;
	SH_Rec(1, "egleon", {st=0});
	SH_Jump("fort_russ"); SH_Jump("moscowia");
	h.qs = TRUE;
	d = SH_PatDock();
	h.qs = FALSE;
	HOST_Check(SH_R(1).st == 0, "mission in progress: no tip");
	-- Thanks: fst +1 at the first patrol docking of the faction owed, after the opening.
	TRF.stx = {n=1, op=1, opp=1, pt={{f=1, s=V_Idx("egleon")}}};
	local f0 = TRF_Fst(1);
	TRF.stash = nil;
	SH_Jump("gaoba");
	d = SH_PatDock();
	HOST_Check(TRF.stx.pt and TRF.stx.pt[1].f == 1 and TRF_Fst(1) == f0, "a patrol station of another faction (Inoco): no thanks");
	SH_Jump("fort_russ"); SH_Jump("moscowia");
	h.qs = TRUE;
	d = SH_PatDock();
	h.qs = FALSE;
	HOST_Check(not SH_Has(d.scr, "Report on the Egleon cache") and TRF.stx.pt and TRF.stx.pt[1].f == 1 and TRF_Fst(1) == f0, "mission in progress: no thanks, pt kept");
	n0 = S_Mark();
	d = SH_PatDock();
	HOST_Check(SH_Has(d.scr, "Report on the Egleon cache received") and TRF_Fst(1) == min(9, f0 + 1) and TRF.stx.pt == nil
		and S_Logs(n0, "event=thanks faction=1 system=egleon") == 1, "Vks patrol dock: thanks, fst +1, pt cleared");
	-- Two tipped caches opened before a docking: both thanks owed (oldest first); a dock pays only its faction's entry.
	local fi = TRF_FacIdx(TRF_FcTeamOf(V_Idx("gaoba")));
	TRF.stash = nil; TRF.stx = nil;
	SH_Rec(1, "egleon", {st=1, src=2, sf=1});
	SH_Rec(2, "gaoba", {st=1, src=2, sf=fi});
	SH_Jump("egleon"); SH_Kill(1, 1);
	SH_Jump("gaoba"); SH_Kill(2, 1);
	local pt = TRF.stx.pt;
	HOST_Check(fi and fi ~= 1 and pt and getn(pt) == 2 and pt[1].f == 1 and pt[1].s == V_Idx("egleon") and pt[2].f == fi and pt[2].s == V_Idx("gaoba"),
		"two tipped caches opened before docking: two owed thanks, oldest first (faction "..tostring(fi)..")");
	local g0, v0 = TRF_Fst(fi), TRF_Fst(1);
	n0 = S_Mark();
	d = SH_PatDock();
	pt = TRF.stx.pt;
	HOST_Check(SH_Has(d.scr, "Report on the Gaoba cache received") and not SH_Has(d.scr, "Egleon cache") and TRF_Fst(fi) == min(9, g0 + 1)
		and TRF_Fst(1) == v0 and pt and getn(pt) == 1 and pt[1].f == 1 and pt[1].s == V_Idx("egleon")
		and S_Logs(n0, "event=thanks faction="..fi.." system=gaoba") == 1, "the Gaoba patrol dock pays its faction and leaves the Vks entry");
	SH_Jump("fort_russ"); SH_Jump("moscowia");
	n0 = S_Mark();
	d = SH_PatDock();
	HOST_Check(SH_Has(d.scr, "Report on the Egleon cache received") and TRF_Fst(1) == min(9, v0 + 1) and TRF_Fst(fi) == min(9, g0 + 1)
		and TRF.stx.pt == nil and S_Logs(n0, "event=thanks faction=1 system=egleon") == 1, "the Vks patrol dock pays the other entry: both factions paid");
	-- The same faction twice: two lines, fst +2; past stash_live (2) entries the oldest is dropped.
	TRF.stash = nil;
	TRF.stx.pt = {{f=1, s=V_Idx("egleon")}, {f=1, s=V_Idx("lasad")}};
	v0 = TRF_Fst(1);
	d = SH_PatDock();
	HOST_Check(SH_Has(d.scr, "Report on the Egleon cache received") and SH_Has(d.scr, "Report on the Lasad cache received") and TRF_Fst(1) == min(9, v0 + 2)
		and TRF.stx.pt == nil, "two entries of one faction: two thanks lines, fst +2");
	n0 = S_Mark();
	TRF_ShOwe(TRF.stx, 1, V_Idx("egleon")); TRF_ShOwe(TRF.stx, 2, V_Idx("lasad")); TRF_ShOwe(TRF.stx, 3, V_Idx("gaoba"));
	pt = TRF.stx.pt;
	HOST_Check(getn(pt) == 2 and pt.n == nil and pt[1].f == 2 and pt[2].f == 3 and S_Logs(n0, "event=thanks faction=1 system=egleon result=dropped reason=cap") == 1,
		"a third owed entry drops the oldest (stash_live 2), logged");
	TRF.stx.pt = nil;
	-- Moved notice: one line at the next patrol board.
	TRF.stx.ms = V_Idx("gaoba"); TRF.stx.mc = SH_Slot("gaoba");
	h.qs = TRUE;
	d = SH_PatDock();
	h.qs = FALSE;
	HOST_Check(not SH_Has(d.scr, "moved their cache") and TRF.stx.ms == V_Idx("gaoba"), "mission in progress: the moved line waits");
	d = SH_PatDock();
	HOST_Check(SH_Has(d.scr, "Pirates ("..TRF_ClanName(SH_Slot("gaoba"))..") moved their cache. The old ping in Gaoba is dead.") and TRF.stx.ms == nil, "moved line once");
	d = SH_PatDock();
	HOST_Check(not SH_Has(d.scr, "moved their cache"), "the moved line is shown once");
	-- Lines run after the owed payers (30) and before the rank line (50): patrol order 40.
	local P = TRF_PlReg();
	local at = nil;
	for i = 1, getn(P.dock.patrol.line) do if TRF_PlName(P.dock.patrol.line[i].f) == "TRF_Sh_PatrolLine" then at = P.dock.patrol.line[i].o; end; end;
	HOST_Check(at == 40, "patrol line order 40");
end;

-- g: treasurer --------------------------------------------------------------------------------------

function T_SH_G()
	local h = HOST();
	SH_Begin("aurora", "9_1");
	local kadi = SH_Slot("gaoba");
	TRF.clan[kadi].sc = 60;
	SH_Rec(1, "gaoba", {st=1, src=1, sf=6});
	SH_Jump("gaoba");
	local m0 = getn(h.msgs);
	local s0 = getn(h.screen);
	local n0 = S_Mark();
	SH_Kill(1, 1);
	local dl = SH_Line(n0, "event=ret index=1 delay=");
	local dt = tonumber(SH_Kv(dl, "delay"));
	HOST_Check(dt and dt >= 60 and dt <= 150 and SH_R(1).rf == 1, "rf 1 and a delay of 60..150 s ("..tostring(dt)..")");
	T_Tick(floor(dt * 2) - 4, 0.5);
	HOST_Check(SH_Ret(1) == 0, "nothing before the delay");
	T_Tick(8, 0.5);
	local sl = SH_Line(n0, "event=ret index=1 group=TRF_Sh_1");
	HOST_Check(SH_Ret(1) >= 1 and sl and SH_Kv(sl, "result") == "spawn" and SH_Kv(sl, "relation") == "war" and SH_R(1).rf == 2,
		"spawn after the delay: group TRF_Sh_1, ships labelled trf_sh_1_<j>, rf 2 ("..tostring(sl)..")");
	-- Portal on the shortest path toward the Kadi home (jumps), started; war both ways at group level.
	local war1, war2 = nil, nil;
	for i = 1, getn(h.rel) do
		local e = h.rel[i];
		if e[1] == "TRF_Sh_1" and e[2] == PLAYER_GROUP and e[3] == RELATION_WAR then war1 = 1; end;
		if e[1] == PLAYER_GROUP and e[2] == "TRF_Sh_1" and e[3] == RELATION_WAR then war2 = 1; end;
	end;
	HOST_Check(war1 and war2, "SetGroupRelation war with PLAYER_GROUP both ways");
	local ms = SH_Msgs(m0)..SH_Scr(s0);
	HOST_Check(SH_Has(ms, "That cargo belongs to our clan ("..TRF_ClanName(kadi)..")"), "T3 leader line: "..ms);
	-- Counted in cap_ships (TRF_CapShips) and raid_live_cap (TRF_Rd_ClanAlive).
	HOST_Check(TRF_CapShips() == SH_Ret(1) and TRF_Rd_ClanAlive() >= SH_Ret(1), "the treasurer counts in cap_ships and raid_live_cap");
	-- Kills: a flight with every ship dead is a clan kill (TRF_Ev_Recover: score -2).
	local sc0 = TRF.clan[kadi].sc;
	n0 = S_Mark();
	local nk = 0;
	for j = 1, 6 do
		local o = h.objs["trf_sh_1_"..j];
		if o and o.alive then o.alive = nil; nk = nk + 1; HOST_Fire("died", "TRF_ShRetDied(1,"..j..","); end;
	end;
	HOST_Check(S_Logs(n0, "event=ret index=1 flight=1 result=killed") == 1 and TRF.clan[kadi].sc == max(0, sc0 - 2) and S_Logs(n0, "result=dead") == 1,
		"flight killed: clan score -2 (normal clan kill)");
	HOST_Check(nk > 0 and S_Logs(n0, "module=scar event=dead class=3 faction=0 mine=1") == nk and S_Logs(n0, "module=scar event=dead class=3 faction=0 mine=0") == 0,
		"every treasurer death feeds battle scars with mine 1 ("..nk.." ships)");
	T_Tick(4, 0.5);
	HOST_Check(TRF_Sh_Alive() == 0, "no live treasurer");
	-- Window: leave after stash_ret_window, deleted out of view.
	TRF.stash = nil; TRF.stx = nil; TRF.clan[kadi].so = nil; TRF.clock.pz = nil;
	SH_Rec(1, "gaoba", {st=1, src=1, sf=6});
	SH_Jump("heos"); SH_Jump("gaoba");
	SH_Kill(1, 1);
	T_Tick(320, 0.5);
	HOST_Check(SH_Ret(1) >= 1, "second treasurer spawned");
	n0 = S_Mark();
	T_Tick(370, 0.5);
	HOST_Check(S_Logs(n0, "event=ret index=1 portal=") == 1 and S_Logs(n0, "result=leave reason=window") == 1, "leave after 180 s");
	h.ms.pos = Vector3(5000, 0, 5000);
	T_Tick(4, 0.5);
	HOST_Check(SH_Ret(1) == 0 and S_Logs(n0, "result=gone") == 1, "deleted at the portal or out of view");
	-- Jump before the timer: rf 2 (void), nothing spawns later.
	TRF.stash = nil; TRF.stx = nil; TRF.clan[kadi].so = nil;
	SH_Rec(1, "gaoba", {st=1, src=1, sf=6});
	SH_Jump("heos"); SH_Jump("gaoba");
	SH_Kill(1, 1);
	n0 = S_Mark();
	SH_Jump("heos");
	HOST_Check(SH_R(1).rf == 2 and S_Logs(n0, "event=ret index=1 result=void reason=jump") == 1, "jump before the timer: void");
	-- Load with rf 1: the timer again with a fresh delay, one spawn (E7.11).
	TRF.stash = nil; TRF.stx = nil; TRF.clan[kadi].so = nil;
	SH_Rec(1, "gaoba", {st=1, src=1, sf=6});
	SH_Jump("gaoba");
	SH_Kill(1, 1);
	n0 = S_Mark();
	T_SaveLoad();
	HOST_Check(SH_R(1).rf == 1 and S_Logs(n0, "event=ret index=1 delay=") == 1 and S_Logs(n0, "result=rearm") == 1, "load: rearm with a fresh delay");
	T_Tick(320, 0.5);
	HOST_Check(SH_Ret(1) >= 1 and S_Logs(n0, "result=spawn") == 1, "one spawn after the load");
	SH_Jump("heos");
	HOST_Check(SH_Ret(1) == 0 and S_Logs(0, "result=gone reason=jump") >= 1, "the jump deletes the treasurer (M3)");
	-- Skips: write-back system with Pirates neutral at team level (E7.9), no war elsewhere (stash_ret_war 0), caps,
	-- retrieval off, every portal closed.
	TRF.stash = nil; TRF.stx = nil;
	SH_Rec(1, "xb13", {st=1, src=1, sf=6});
	h.rel_team = {["Pirates|"..PLAYER_TEAM] = RELATION_NEUTRAL};
	SH_Jump("xb13");
	s0 = getn(h.screen);
	n0 = S_Mark();
	SH_Kill(1, 1);
	T_Tick(320, 0.5);
	HOST_Check(SH_Ret(1) == 0 and SH_R(1).rf == 2 and S_Logs(n0, "event=ret index=1 result=skipped reason=writeback") == 1 and SH_Has(SH_Scr(s0), "clan ("..TRF_ClanName(SH_Slot("xb13"))..")"),
		"write-back system, Pirates neutral: skipped, the leader line on screen");
	TRF.stash = nil; TRF.stx = nil;
	SH_Rec(1, "gaoba", {st=1, src=1, sf=6});
	SH_Jump("gaoba");
	n0 = S_Mark();
	SH_Kill(1, 1);
	T_Tick(320, 0.5);
	HOST_Check(SH_Ret(1) == 0 and S_Logs(n0, "reason=no_war") == 1, "stash_ret_war 0 and Pirates neutral: skipped");
	h.cfg.stash_ret_war = 1;
	TRF.stash = nil; TRF.stx = nil;
	SH_Rec(1, "gaoba", {st=1, src=1, sf=6});
	SH_Jump("heos"); SH_Jump("gaoba");
	n0 = S_Mark();
	SH_Kill(1, 1);
	T_Tick(320, 0.5);
	HOST_Check(SH_Ret(1) >= 1 and S_Logs(n0, "result=spawn") == 1, "stash_ret_war 1: group war while Pirates are neutral");
	h.cfg.stash_ret_war = 0;
	h.rel_team = nil;
	SH_Jump("heos");
	TRF.stash = nil; TRF.stx = nil;
	SH_Rec(1, "gaoba", {st=1, src=1, sf=6});
	SH_Jump("gaoba");
	SH_Tune("raid_live_cap", 1);
	n0 = S_Mark();
	SH_Kill(1, 1);
	T_Tick(320, 0.5);
	HOST_Check(SH_Ret(1) == 0 and S_Logs(n0, "reason=caps") == 1, "raid_live_cap full: skipped, never queued");
	SH_Tune("raid_live_cap", 8);
	TRF.stash = nil; TRF.stx = nil;
	SH_Rec(1, "gaoba", {st=1, src=1, sf=6});
	SH_Jump("heos"); SH_Jump("gaoba");
	for i = 1, getn(h.portals) do h.portals[i].IsEnabled = function(self) return FALSE; end; end;
	n0 = S_Mark();
	SH_Kill(1, 1);
	T_Tick(320, 0.5);
	HOST_Check(SH_Ret(1) == 0 and S_Logs(n0, "reason=portal") == 1, "every portal closed (IsEnabled false): skipped");
	TRF.stash = nil; TRF.stx = nil;
	SH_Rec(1, "gaoba", {st=1, src=1, sf=6});
	SH_Jump("heos"); SH_Jump("gaoba");
	h.portals[1].IsEnabled = function(self) return FALSE; end;
	n0 = S_Mark();
	SH_Kill(1, 1);
	T_Tick(320, 0.5);
	local pl = SH_Line(n0, "result=spawn");
	HOST_Check(pl and SH_Kv(pl, "portal") ~= gsub(h.portals[1].label, " ", "_"), "the first portal closed: the next one ("..tostring(pl and SH_Kv(pl, "portal"))..")");
	SH_Jump("heos");
	h.cfg.enable_stash_retrieval = 0;
	TRF.stash = nil; TRF.stx = nil;
	SH_Rec(1, "gaoba", {st=1, src=1, sf=6});
	SH_Jump("gaoba");
	SH_Kill(1, 1);
	HOST_Check(SH_R(1).rf == 2, "enable_stash_retrieval 0: rf 2 at the opening");
	h.cfg.enable_stash_retrieval = 1;
	-- Gates: an open sweep attempt against the clan, a due or live carrier (not a skipped or finished one), parked
	-- ships in cap_ships; a skip while the visible gate fails says no leader line.
	TRF.stash = nil; TRF.stx = nil;
	SH_Rec(1, "gaoba", {st=2, rf=1});
	SH_Jump("heos"); SH_Jump("gaoba");
	local r = SH_R(1);
	local gi = V_Idx("gaoba");
	HOST_Check(TRF_ShRetGate(r, gi, 1) == nil, "gate open in Gaoba");
	TRF.rg[kadi].sl = TRF.clock.legs + 1;
	HOST_Check(TRF_ShRetGate(r, gi, 1) == "sweep", "open sweep attempt against the clan: sweep");
	TRF.rg[kadi].sl = 0;
	TRF.live.cr = {i=1, n=9, st="skip"};
	HOST_Check(TRF_ShRetGate(r, gi, 1) == nil, "a skipped carrier does not block");
	TRF.live.cr.st = "done";
	HOST_Check(TRF_ShRetGate(r, gi, 1) == nil, "a finished carrier does not block");
	TRF.live.cr.st = "hold";
	HOST_Check(TRF_ShRetGate(r, gi, 1) == "carrier", "a live carrier blocks");
	TRF.live.cr = nil;
	local ca, pk0 = TRF.live.caps, TRF.live.pk;
	local nt, ns = TRF_SafeCountOf(TRF.live.tr);
	TRF.live.caps = ns + TRF_CapShips() + 2;
	TRF.live.pk = {};
	HOST_Check(TRF_ShCaps(2), "room for 2 without parked ships");
	TRF.live.pk = {1};
	HOST_Check(not TRF_ShCaps(2), "a parked ship counts in cap_ships");
	TRF.live.caps = ca; TRF.live.pk = pk0;
	s0 = getn(h.screen);
	h.qs = TRUE;
	TRF_ShRetSkip(1, r, "disabled");
	h.qs = FALSE;
	HOST_Check(getn(h.screen) == s0 and r.rf == 2, "skip during a mission: no leader line");
	SH_Jump("heos");
	-- Wind-down: a live treasurer leaves.
	TRF.stash = nil; TRF.stx = nil;
	SH_Rec(1, "gaoba", {st=1, src=1, sf=6});
	SH_Jump("heos"); SH_Jump("gaoba");
	SH_Kill(1, 1);
	T_Tick(320, 0.5);
	n0 = S_Mark();
	TRF_Sh_WindDown();
	HOST_Check(S_Logs(n0, "result=leave reason=wind") == 1, "wind-down: the treasurer leaves");
end;

-- h: dump, repair, load orphan, debug, save size --------------------------------------------------------

function T_SH_H()
	local h = HOST();
	SH_Begin("aurora", "9_1");
	SH_Rec(1, "gaoba", {st=1, src=1, sf=6, rf=0});
	SH_Rec(2, "areko", {st=0});
	TRF.stx = {n=7, op=2, opp=1, lc=TRF.clock.legs - 3, jc=TRF.clock.j, lo=TRF.clock.legs - 40, jo=TRF.clock.j - 10, pt={{f=3, s=V_Idx("gaoba")}, {f=1, s=V_Idx("egleon")}}};
	TRF.clan[SH_Slot("areko")].so = 1;
	local n0 = S_Mark();
	TRF_Sh_Dump();
	local dl = SH_Line(n0, "module=stash event=dump ");
	HOST_Check(S_Logs(n0, "module=stash event=dump_rec index=1 system=gaoba slot=1") == 1 and S_Logs(n0, "event=dump_rec index=2 system=areko") == 1
		and dl and SH_Kv(dl, "record_count") == "2" and strlen(SH_Kv(dl, "so")) == 11 and SH_Kv(dl, "gap") == "12/6" and SH_Kv(dl, "open_gap") == "0/0"
		and SH_Kv(dl, "quest") == "0" and SH_Kv(dl, "patrol_owed") == "3:gaoba,1:egleon", "dump lines: records, so digits, stx, owed thanks and the gate state ("..tostring(dl)..")");
	TRF_DumpState("test");
	HOST_Check(S_Logs(n0, "module=stash event=dump ") >= 2, "TRF_DumpState calls the stash dump");
	-- Repair: wrong fields read their defaults, duplicates and unknown systems dropped, stx and so cleaned.
	TRF.stash = {
		{sys=V_Idx("gaoba"), slot=9, clan=SH_Slot("gaoba"), cls=7, v=9999, seed=-1, leg=TRF.clock.legs + 50, st=5, src=9, sf=40, sv=8, rf=7},
		{sys=V_Idx("gaoba"), slot=1, clan=SH_Slot("gaoba"), cls=2, v=100, seed=4, leg=1, st=0, src=0, sf=0, sv=0, rf=0},
		"x",
		{sys=V_Idx("areko"), slot=2, clan=SH_Slot("areko"), cls=3, v=450, seed=9999, leg=1, st=2, src=2, sf=5, sv=5, rf=2}};
	TRF.stx = {n=-3, op="x", lc=TRF.clock.legs + 10, pt=8, ms=V_Idx("gaoba")};
	TRF.clan[1].so = 7; TRF.clan[2].sk = TRF.clock.legs + 99;
	TRF_Sh_Fix();
	local a, b = TRF.stash[1], TRF.stash[4];
	HOST_Check(a == nil and TRF.stash[2] and TRF.stash[2].sys == V_Idx("gaoba") and TRF.stash[3] == nil and b and b.cls == 3 and b.sv == 5
		and TRF.stx.n == 0 and TRF.stx.op == 0 and TRF.stx.lc == nil and TRF.stx.pt == nil and TRF.stx.ms == V_Idx("gaoba") and TRF.stx.mc
		and TRF.clan[1].so == nil and TRF.clan[2].sk == nil, "repair: a bad slot drops the record, one per system, fields and stx within their ranges");
	-- Repair of the owed thanks: the old single-slot shape becomes a one-entry list; bad entries dropped, the newest 2 kept.
	TRF.stx = {pt=3, ps=V_Idx("gaoba")};
	TRF_Sh_Fix();
	local pt = TRF.stx.pt;
	HOST_Check(pt and getn(pt) == 1 and pt[1].f == 3 and pt[1].s == V_Idx("gaoba") and TRF.stx.ps == nil, "repair: old pt/ps slot becomes {{f=3, s=gaoba}}");
	TRF.stx = {pt=4, ps=9999};
	TRF_Sh_Fix();
	pt = TRF.stx.pt;
	HOST_Check(pt and getn(pt) == 1 and pt[1].f == 4 and pt[1].s == nil, "repair: old slot with a bad system keeps the faction");
	TRF.stx = {pt={{f=8}, "x", {f=2, s=9999}, {f=1, s=V_Idx("gaoba")}, {f=4.5, s=V_Idx("areko")}}};
	TRF.stx.pt.n = 5;
	TRF_Sh_Fix();
	pt = TRF.stx.pt;
	HOST_Check(pt and getn(pt) == 2 and pt.n == nil and pt[1].f == 1 and pt[1].s == V_Idx("gaoba") and pt[2].f == 4 and pt[2].s == V_Idx("areko"),
		"repair: owed list entries within range, the newest 2 kept");
	TRF.stx = {pt={"x"}};
	TRF_Sh_Fix();
	HOST_Check(TRF.stx.pt == nil, "repair: an owed list with no valid entry is dropped");
	TRF.stash = 5; TRF.stx = 3;
	TRF_Sh_Fix();
	HOST_Check(TRF.stash == nil and type(TRF.stx) == "table" and TRF.stx.n == 0, "repair: non-table stash and stx");
	-- Load orphan rule: a label whose record went to another system is deleted at the entry (moved cache).
	TRF.stash = nil; TRF.stx = nil;
	SH_Rec(1, "gaoba", {st=0});
	SH_Jump("gaoba");
	local o = SH_Obj(1);
	SH_Jump("heos");
	TRF.stash[1] = nil;
	SH_Rec(1, "areko", {st=0});
	n0 = S_Mark();
	SH_Jump("gaoba", 1);
	HOST_Check(o and not o.alive and S_Logs(n0, "event=orphan_delete index=1 system=gaoba") == 1, "moved cache: the old object is deleted at the entry, not in view");
	-- Debug: cfg stash_at creates a known record at the entry of that system.
	TRF.stash = nil; TRF.stx = nil;
	h.cfg.stash_at = "egleon";
	n0 = S_Mark();
	SH_Jump("egleon");
	local i, r = TRF_ShAt(V_Idx("egleon"));
	HOST_Check(r and r.st == 1 and SH_Obj(i) and S_Logs(n0, "event=debug") == 1 and SH_Mk("TRF_STASH_AR_"..i), "stash_at: a known record placed at the entry");
	h.cfg.stash_at = nil;
	-- Visit globals: the treasurer's group global is never left.
	HOST_Check(T_LeftGlobals() == "", "no TRF_GSh_ global left"..T_LeftGlobals());
	-- Save size at the record bound (spec 3.3): 4 records at their widest, stx with every field, so and sk in 11 slots.
	TRF.stash = {};
	for k = 1, 4 do
		TRF.stash[k] = {sys=113, slot=4, clan=11, cls=3, v=450, seed=9999, leg=-99999, st=2, src=4, sf=11, sv=5, rf=2, pl=1};
	end;
	TRF.stx = {n=9999, op=9999, opp=9999, lc=-99999, jc=99999, lo=-99999, jo=99999, pt={{f=5, s=113}, {f=5, s=113}}, ms=113, mc=11};
	local sz = HOST_SaveSize(TRF.stash) + 8 + strlen("stash") + HOST_SaveSize(TRF.stx) + 8 + strlen("stx");
	local cz = 11 * (2 * 8 + strlen("so") + strlen("sk") + 2 * 12);
	print("HOST info stash save size "..sz.." + clan fields "..cz);
	HOST_Check(sz <= 1700 and sz + cz <= 2200, "worst case: TRF.stash and TRF.stx "..sz.." bytes <= 1700, with the clan fields "..(sz + cz).." <= 2200");
	HOST_Check(HOST_Reserved(TRF, "TRF") == "", "no reserved key");
end;

-- Dispatch ---------------------------------------------------------------------------------

local sc = getenv("TRF_SH") or "";
local fn = getglobal("T_SH_"..strupper(sc));
print("HOST ==== clan stashes scenario sh-"..sc.." dir="..HOST().dir);
if type(fn) == "function" then
	fn();
	HOST_Check(T_LeftGlobals() == "", "no handle globals left at the end"..T_LeftGlobals());
	local q = T_BadCallbacks();
	HOST_Check(q == "", "every mod callback string carries the current gen"..q);
else
	HOST_Check(nil, "unknown clan stashes scenario "..sc);
end;
HOST_Check((HOST().gpm_tick or 0) == 0, "no GetPlayerMotherShip from a tick (n="..tostring(HOST().gpm_tick or 0)..")");
print("HOST errors="..HOST().errors.." fails="..HOST().fails);
if HOST().errors > 0 or HOST().fails > 0 then exit(1); end;
exit(0);
