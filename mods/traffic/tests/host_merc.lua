-- Mercenary clans scenarios (design/merc-spec.md 10) under stock Lua 4.0.1: TRF_MC=a..f, run by run_host.sh as its own
-- entry point. a registration, toggles, tune, static clan table, fixed hash, record creation and accessors (digits, packed
-- fields at their bounds), b fortune and stages (income, upkeep, the two-tick streak, down, closure, big-ship loss, the
-- stage 4 slots with the reserved elite slot, the elite floor, the event cap, the fielded stage), c presence, off-screen
-- losses, the elite hp floor, break and re-form, hp recovery by ticks and jumps, d the decays (rel, g, bk, owe, w) and the
-- blacklist, e the rival candidate rule and its rv_enabled gate, f repair, enabled 2, config off, the region tick hook,
-- save and load, dump, the save bound.
-- Loads host_station.lua up to its first scenario, as host_nest.lua does. Stub added in host_stubs.lua:
-- GetRecruitGroupName (HOST().recruit, else "").

local f = openfile((getenv("TRF_TESTS") or "./").."host_station.lua", "r");
if not f then print("HOST FAIL host_merc.lua: cannot open host_station.lua"); exit(1); end;
local src = read(f, "*a");
closefile(f);
local cut = strfind(src, "\n-- a: install (12.1, 6.1)", 1, 1);
if not cut then print("HOST FAIL host_merc.lua: marker '-- a: install (12.1, 6.1)' missing in host_station.lua"); exit(1); end;
dostring(strsub(src, 1, cut), "host_station.lua");

-- Helpers ----------------------------------------------------------------------------------

-- Config of these runs: the repo defaults with merc on, the entry events and the other worldbuilding features off, log 2,
-- plus t.
function MC_Cfg(t)
	local c = {merc=1, cap_enable=0, sweeps=0, sweep_ct=0, feq=0, staged=0, seed=0, queue=0, parked=0, voice_events=0,
		dconv=0, carriers=0, po=0, enable_survivors=0, lad_enabled=0, enable_stashes=0, enable_freight=0, charter=0, log=2, tune={}};
	if t then for k, v in t do c[k] = v; end; end;
	return c;
end;

function MC_Set(k, v) HOST().cfg[k] = v; end;

function MC_Tune(k, v)
	local h = HOST();
	local o = {};
	for a, b in h.cfg.tune do o[a] = b; end;
	o[k] = v;
	h.cfg.tune = o;
end;

-- Scenario start in gaoba at chapter label ch (default 5_1): every region in phase ph (default Quiet) without a sweep,
-- no clan record.
function MC_Begin(ch, t, ph)
	local h = HOST();
	h.labels.CurrentQuest = ch or "5_1";
	h.recruit = nil;
	S_Begin("gaoba", MC_Cfg(t));
	for s = 1, TRF_RgMap().n do MC_Phase(s, ph or 0); end;
	TRF.mc = nil;
end;

function MC_Phase(slot, ph, sl)
	local rg = TRF.rg[slot];
	rg.ph = ph; rg.pt = TRF.clock.legs; rg.sl = sl or 0;
end;

function MC_Slot(name) return TRF_RgOf(V_Idx(name)); end;

-- n region ticks of the module alone (rg_tick legs each); returns the last leg.
function MC_Tick(n)
	local L = TRF.clock.legs;
	for i = 1, (n or 1) do
		L = L + TRF_McRgTick();
		TRF.clock.legs = L;
		TRF_Mc_RegionTick(L);
	end;
	return L;
end;

function MC_V(c) return TRF_McGet(c); end;

-- Sets fields of clan c (digit and packed) from t.
function MC_Put(c, t)
	local v = TRF_McGet(c);
	for k, x in t do v[k] = x; end;
	TRF_McPut(c, v);
end;

function MC_Has(s, t) return strfind(s or "", t, 1, 1); end;

-- Number of clans with digit field k equal to x.
function MC_Count(k, x)
	local n = 0;
	for c = 1, 12 do if TRF_McDig(c, k) == x then n = n + 1; end; end;
	return n;
end;

function MC_Jump(n) TRF.clock.j = TRF.clock.j + (n or 1); end;

-- a: registration, toggles, tune, static table, hash, record and accessors -------------------------------------

function T_MC_A()
	local h = HOST();
	MC_Begin("5_1");
	HOST_Check(S_Logs(0, "module=core event=loaded map=true module_count=18 extra_count=12") >= 1, "trf_merc loads last (extra_count=12)");
	local ml, tf, uf = TRF_ModList(), TRF_Loc_TextFns(), TRF_UI_TextFns();
	local tfs, ufs = "", "";
	for i = 1, getn(tf) do tfs = tfs..tf[i]..","; end;
	for i = 1, getn(uf) do ufs = ufs..uf[i]..","; end;
	HOST_Check(ml[getn(ml)] == "Mc" and MC_Has(tfs, "TRF_Pc_Text,TRF_Mc_Text,TRF_Loc_Text,") and MC_Has(ufs, "TRF_Pc_Text,TRF_Mc_Text,"),
		"TRF_ModList ends with Mc; TRF_Mc_Text after the parcel table in both text lists");
	HOST_Check(TRF_Mc_OptDef().merc == 0 and TRF_McOpt("merc") == 1 and TRF_McOpt("rv_enabled") == 0 and TRF_McOpt("mc_el_c") == 8
		and TRF_McOpt("merc_war") == 0 and TRF_McOpt("merc_hostile") == 0 and TRF_McOpt("merc_board") == 1 and TRF_McOpt("mc_launch") == 0,
		"merc off by default (on in these runs), rivals off, elite clan 8, group war off, board on, launches off");
	MC_Set("mc_el_c", 13); HOST_Check(TRF_McOpt("mc_el_c") == 8, "mc_el_c outside 0..12 reads 8");
	MC_Set("mc_el_c", 0); HOST_Check(TRF_McOpt("mc_el_c") == 0 and TRF_McElite() == 0, "mc_el_c 0: no elite clan");
	MC_Set("mc_el_c", nil);
	MC_Set("merc_war", 5); HOST_Check(TRF_McOpt("merc_war") == 0, "merc_war other than 1 reads 0");
	MC_Set("merc_war", nil);
	local T = TRF_McTune();
	HOST_Check(T.c_hire == 700 and T.merc_p[4] == 55 and T.mc_up[2] == 0.5 and T.mc_st_up[3] == 78 and T.mc_st_dn[1] == 22 and T.mc_ships == 7
		and T.mc_ms_max == 2 and T.mc_bs_j[2] == 40 and T.mc_el_fo[2] == 78 and T.rv_cd_legs == 24 and T.merc_owe_j == 60 and T.mc_size_k[3] == 1.25,
		"tune defaults of 12 section 6 and 11.1");
	MC_Tune("mc_ms_max", 99); MC_Tune("mc_st_up", {-5, 200, 78}); MC_Tune("mc_up", {0, 0.5, 1, 2.5});
	T = TRF_McTune();
	HOST_Check(T.mc_ms_max == 12 and T.mc_st_up[1] == 0 and T.mc_st_up[2] == 99 and T.mc_up[4] == 2.5, "tune clamps; mc_up keeps fractions");
	h.cfg.tune = {};
	-- Static clan table: the vanilla order and blocs, the homes by region, the pilot list.
	local ks, bs = "", "";
	for c = 1, 12 do ks = ks..TRF_McClan(c).k..","; bs = bs..TRF_McClan(c).b; end;
	HOST_Check(ks == "morgenstern,angelrevenge,fireaxe,stardragoon,kimmeria,kismet,nomads,blacklegion,shinegard,stardust,apocalypserider,goldgrifon,"
		and bs == "121212121212" and TRF_McClan(13) == nil, "clans in the _Fmerc_names order, blocs 1/2");
	HOST_Check(TRF_McHome(1) == MC_Slot("gefest") and TRF_McHome(4) == MC_Slot("kadi") and TRF_McHome(5) == MC_Slot("kadi")
		and TRF_McHome(8) == MC_Slot("torr") and TRF_McHome(6) == MC_Slot("dionis") and TRF_McHome(11) == MC_Slot("xt24") and TRF_McHome(12) == MC_Slot("elinor"),
		"homes: the region holding each clan's home system (Dionis and XT24 inside merged regions)");
	local p = TRF_McPilots(8);
	HOST_Check(getn(p) == 5 and p[1] == "RecruitPilot_blacklegion" and p[2] == "RecruitOfficer_blacklegion" and p[5] == "RecruitAce_blacklegion" and TRF_McPilots(0) == nil,
		"pilot list as RegisterNaemnik builds it");
	_Fmerc_names = {"morgenstern", "angelrevenge", "fireaxe", "stardragoon", "kimmeria", "kismet", "nomads", "blacklegion", "shinegard", "stardust", "apocalypserider", "x"};
	_Fmerc_groups = {1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2};
	TRF_McMC().cl = nil;
	local n0 = S_Mark();
	HOST_Check(TRF_McClan(12).k == "goldgrifon" and TRF_McMC().clv == "differs" and S_Logs(n0, "module=merc event=static vanilla=differs result=own_table") == 1,
		"a changed vanilla table is reported, the module keeps its own (saved indices never shift)");
	_Fmerc_names[12] = "goldgrifon";
	TRF_McMC().cl = nil;
	TRF_McClan(1);
	HOST_Check(TRF_McMC().clv == "match", "vanilla table compared: match");
	_Fmerc_names = nil; _Fmerc_groups = nil;
	-- Fixed hash: deterministic, in range, about uniform.
	local lo, hi, below, same = 99999, -1, 0, 1;
	for i = 1, 1000 do
		local x = TRF_McHash(i, i * 7, 3);
		if x < lo then lo = x; end;
		if x > hi then hi = x; end;
		if TRF_McRoll(i, i * 7, 3) < 50 then below = below + 1; end;
		if TRF_McHash(i, i * 7, 3) ~= x then same = nil; end;
	end;
	HOST_Check(same and lo >= 0 and hi <= 10008 and below > 400 and below < 600 and TRF_McHash(-5, 2, 1) >= 0,
		"fixed hash: same answer every call, 0..10008, rolls about uniform ("..below.." of 1000 below 50)");
	for c = 1, 12 do local x = TRF_McFo0Of(c, 20, 31); if x < 20 or x > 50 then same = nil; end; end;
	HOST_Check(same, "mc_fo0 = 20 + hash(c) mod 31 in 20..50");
	-- Creation: not before chapter 5, not with merc 0; at chapter 5 with the creation values.
	h.labels.CurrentQuest = "4_1";
	MC_Tick(1);
	HOST_Check(TRF.mc == nil and TRF_McDig(4, "hp") == 4 and TRF_McDig(4, "at") == TRF_McHome(4), "chapter 4: no record; accessors read the creation values");
	h.labels.CurrentQuest = "5_1";
	MC_Set("merc", 0);
	MC_Tick(1);
	HOST_Check(TRF.mc == nil, "merc 0: no record");
	MC_Set("merc", 1);
	n0 = S_Mark();
	TRF_McRec(1);
	HOST_Check(type(TRF.mc) == "table" and strlen(TRF.mc.s) == 240 and S_Logs(n0, "module=merc event=create ") == 1 and S_Logs(n0, "elite=8") == 1
		and TRF.mc.e == "8,0,0,0,0", "created: 12 x 20 digits, the elite record");
	local ok = 1;
	for c = 1, 12 do
		local v = MC_V(c);
		local fo0 = TRF_McFo0Of(c, 20, 31);
		if c == 8 then fo0 = max(fo0, 55); end;
		if v.rel ~= 0 or v.hp ~= 4 or v.at ~= TRF_McHome(c) or v.fo ~= fo0 or v.sg ~= TRF_McStageOfFo(fo0, {30, 55, 78}, 3) or v.rl ~= 0 or v.jobs ~= 0 then ok = nil; end;
	end;
	HOST_Check(ok and TRF_McDig(8, "sg") == 3 and TRF_McDig(8, "fo") >= 55, "creation values: rel 0, hp 4, at home, fo0 (elite at its floor 55: stage 3), stage by fortune");
	-- Digit accessors: clamped, never spilling into the next field.
	local sg4 = TRF_McDig(4, "sg");
	HOST_Check(TRF_McSetDig(4, "fo", 150) == 99 and TRF_McDig(4, "fo") == 99 and TRF_McDig(4, "sg") == sg4, "fo 150 written as 99, the stage digit unchanged");
	HOST_Check(TRF_McSetDig(4, "rel", -5) == -3 and TRF_McRel(4) == -3 and strsub(TRF.mc.s, 61, 61) == "0" and TRF_McSetDig(4, "rel", 2) == 2 and strsub(TRF.mc.s, 61, 61) == "5",
		"rel stored as rel + 3 (clamped to -3..3)");
	HOST_Check(TRF_McSetDig(4, "at", 11) == 11 and TRF_McDig(4, "at") == 11 and TRF_McDig(4, "es") == 0 and TRF_McSetDig(13, "fo", 1) == nil
		and TRF_McSetDig(4, "zz", 1) == nil and TRF_McDig(4, "zz") == nil and TRF_McDig(0, "fo") == nil, "two-digit fields; bad clan or key refused");
	-- Packed fields: every key at its bound round-trips; out of bounds clamped; all zero removes the entry.
	local B = TRF_McTB();
	local r = {};
	for k, b in B do if b[1] < 0 then r[k] = b[1]; else r[k] = b[2]; end; end;
	TRF_McPutT(4, r);
	local r2 = TRF_McTOf(4);
	local diff = "";
	for k, b in B do if r2[k] ~= r[k] then diff = diff.." "..k; end; end;
	HOST_Check(diff == "" and getn(TRF_McTKeys()) == 29 and strlen(TRF.mc.t[4]) <= 11 * 29, "t[c]: 29 keys round-trip at their bounds ("..strlen(TRF.mc.t[4]).." chars)"..diff);
	TRF_McPutT(4, {jobs=5000, owe=-5, met=1e12, su=7});
	r2 = TRF_McTOf(4);
	HOST_Check(r2.jobs == 999 and r2.owe == 0 and r2.met == 9999999 and r2.su == 1 and r2.cd == 0, "t[c]: values clamped, missing keys 0");
	TRF_McPutT(4, {});
	HOST_Check(TRF.mc.t[4] == nil and TRF_McTOf(4).jobs == 0, "t[c] of zeros removed");
	HOST_Check(TRF_TpMax() == 2147483647 and B.ue[2] < TRF_TpMax() and B.px[2] < TRF_TpMax() and TRF_McPhaseKey(1) < 2000000, "every bound below 2^31-1; the phase key stays small");
end;

-- b: fortune and stages ---------------------------------------------------------------------------------------

function T_MC_B()
	local h = HOST();
	MC_Begin("5_1");
	local T = TRF_McTune();
	-- Pure rules.
	HOST_Check(TRF_McUpOf(0.5, 0) == 1 and TRF_McUpOf(0.5, 1) == 0 and TRF_McUpOf(1, 3) == 1 and TRF_McUpOf(2, 3) == 2 and TRF_McUpOf(0, 2) == 0,
		"upkeep: 0.5 = 1 every second tick");
	local up, dn = {30, 55, 78}, {22, 47, 70};
	local a1, s1 = TRF_McStageOf(30, 1, 0, up, dn, 4);
	local a2, s2 = TRF_McStageOf(30, 1, 1, up, dn, 4);
	local a3, s3 = TRF_McStageOf(29, 1, 1, up, dn, 4);
	local a4, s4 = TRF_McStageOf(21, 2, 1, up, dn, 4);
	local a5 = TRF_McStageOf(10, 4, 0, up, dn, 4);
	local a6, s6 = TRF_McStageOf(90, 3, 1, up, dn, 3);
	local a7 = TRF_McStageOf(90, 4, 0, up, dn, 3);
	local a8 = TRF_McStageOf(48, 3, 0, up, dn, 4);
	HOST_Check(a1 == 1 and s1 == 1 and a2 == 2 and s2 == 0 and a3 == 1 and s3 == 0 and a4 == 1 and s4 == 0 and a5 == 1 and a6 == 3 and s6 == 0 and a7 == 3 and a8 == 3,
		"stage rule: up after two ticks in a row, a blip resets the streak, down at the first tick below, as far as the fortune goes, the closure caps");
	HOST_Check(TRF_McCapOf(10, 4, 49, {20, 40}) == 3 and TRF_McCapOf(10, 4, 50, {20, 40}) == 4 and TRF_McCapOf(10, 3, 29, {20, 40}) == 2
		and TRF_McCapOf(10, 3, 30, {20, 40}) == 4 and TRF_McCapOf(0, 0, 0, {20, 40}) == 4, "closure: stage mk and above closed for mc_bs_j jumps");
	local f1, g1, p1 = TRF_McBigLossOf(80, 4, 4);
	local f2, g2, p2 = TRF_McBigLossOf(50, 2, 3);
	local f3, g3, p3 = TRF_McBigLossOf(30, 0, 3);
	HOST_Check(f1 == 62 and g1 == 3 and p1 == 3 and f2 == 42 and g2 == 2 and p2 == 1 and f3 == 30 and p3 == 0, "big-ship loss values: fo 62 / 42, stage 3 / 2, hp -1");
	local ga, ue = TRF_McGainOf(3, 0, 5, 12, 100);
	local gs = ga;
	for i = 1, 4 do ga, ue = TRF_McGainOf(3, ue, 5, 12, 100); gs = gs..","..ga; end;
	local gn, un = TRF_McGainOf(3, ue, 6, 12, 100);
	HOST_Check(gs == "3,3,3,3,0" and ue == 512 and gn == 3 and un == 603, "event cap: 12 per phase, a new phase key starts again ("..gs..")");
	-- Income and the streak at the tick: the Nomads at home in Golkonda (Boom), every other region Quiet.
	local g = MC_Slot("golkonda");
	MC_Phase(g, 1);
	TRF_McRec(1);
	MC_Put(7, {fo=24, sg=1, su=0});
	local n0 = S_Mark();
	MC_Tick(1);
	local v = MC_V(7);
	HOST_Check(v.at == g and v.fo == 27 and v.sg == 1 and v.su == 0, "Boom +3 at stage 1 (no upkeep): 27");
	MC_Tick(1);
	v = MC_V(7);
	HOST_Check(v.fo == 30 and v.sg == 1 and v.su == 1, "first tick at 30: streak set, stage kept");
	MC_Tick(1);
	v = MC_V(7);
	HOST_Check(v.sg == 2 and v.su == 0 and S_Logs(n0, "module=merc event=stage clan=7 stage_before=1 stage=2") == 1, "second tick in a row: stage 2, logged");
	local fa = v.fo;
	MC_Tick(2);
	HOST_Check(MC_V(7).fo == fa + 6 - 1, "stage 2 upkeep 0.5: 1 on every second tick ("..fa.." -> "..MC_V(7).fo..")");
	-- A blip below the threshold resets the streak; down at the first tick below 22.
	MC_Put(7, {fo=28, sg=1, su=0});
	MC_Tick(1);
	HOST_Check(MC_V(7).su == 1 and MC_V(7).fo == 31, "31: streak");
	MC_Phase(g, 4);
	MC_Tick(1);
	HOST_Check(MC_V(7).su == 0 and MC_V(7).sg == 1 and MC_V(7).fo == 29, "Bust -2 to 29: streak reset");
	MC_Put(7, {fo=23, sg=2, su=0});
	MC_Tick(1);
	HOST_Check(MC_V(7).sg == 1 and MC_V(7).fo <= 21, "Bust: below 22 at the first tick, stage 1");
	-- Stage 4 slots: three clans and the elite clan qualify; slot 1 is the elite clan's, one other clan gets slot 2.
	h.labels.CurrentQuest = "9_1";
	for s = 1, TRF_RgMap().n do MC_Phase(s, 1); end;
	for c = 1, 12 do MC_Put(c, {fo=10, sg=1, su=0}); end;
	MC_Put(1, {fo=95, sg=3, su=1}); MC_Put(4, {fo=95, sg=3, su=1}); MC_Put(7, {fo=95, sg=3, su=1}); MC_Put(8, {fo=90, sg=3, su=1});
	n0 = S_Mark();
	MC_Tick(1);
	local w4 = 0;
	for i, c in {1, 4, 7} do if TRF_McDig(c, "sg") == 4 then w4 = w4 + 1; elseif TRF_McDig(c, "sg") ~= 3 or TRF_McTOf(c).su ~= 1 then w4 = 99; end; end;
	HOST_Check(TRF_McDig(8, "sg") == 4 and w4 == 1 and MC_Count("sg", 4) == 2, "stage 4: the elite clan in slot 1, one of three others in slot 2, the rest wait at 3 with the streak");
	local first = nil;
	for i, c in {1, 4, 7} do if TRF_McDig(c, "sg") == 4 then first = c; end; end;
	MC_Tick(1);
	HOST_Check(TRF_McDig(first, "sg") == 4 and MC_Count("sg", 4) == 2, "the same clan keeps slot 2 at equal fortune (fixed hash)");
	-- Without the elite clan below stage 4 the reserved slot stays empty.
	MC_Put(8, {fo=60, sg=3, su=0});
	h.labels.CurrentQuest = "5_1";
	MC_Tick(1);
	HOST_Check(TRF_McDig(8, "sg") == 3 and MC_Count("sg", 4) == 1, "elite clan at stage 3 (chapter 5 floor 55): slot 1 empty, still one other clan at 4");
	-- mc_el_c 0: no reserved slot, two others.
	MC_Set("mc_el_c", 0);
	for i, c in {1, 4, 7} do MC_Put(c, {fo=95, sg=3, su=1}); end;
	MC_Tick(1);
	HOST_Check(MC_Count("sg", 4) == 2 and TRF_McDig(8, "sg") ~= 4, "mc_el_c 0: both stage 4 slots for the other clans");
	MC_Set("mc_el_c", nil);
	-- Elite floor 55 from chapter 5, 78 from chapter 7; the closure after a mothership loss holds against the floor.
	for s = 1, TRF_RgMap().n do MC_Phase(s, 0); end;
	for c = 1, 12 do MC_Put(c, {fo=10, sg=1, su=0}); end;
	MC_Tick(1);
	HOST_Check(TRF_McDig(8, "fo") == 55 and TRF_McDig(1, "fo") == 10, "chapter 5: elite fortune floor 55");
	h.labels.CurrentQuest = "7_1";
	MC_Tick(1);
	HOST_Check(TRF_McDig(8, "fo") == 78, "chapter 7: elite floor 78");
	MC_Put(8, {sg=3, su=0});
	TRF_Mc_BigLoss(8, 4);
	local J = TRF_Jumps();
	v = MC_V(8);
	HOST_Check(v.fo == 62 and v.sg == 3 and v.mk == 4 and v.ml == J and v.hp == 3, "mothership loss: fo 62, stage 3, closed from this jump, hp -1");
	MC_Tick(4);
	HOST_Check(TRF_McDig(8, "fo") == 78 and TRF_McDig(8, "sg") == 3, "floor 78 again, but stage 4 closed for 40 jumps");
	MC_Jump(40);
	MC_Tick(1);
	HOST_Check(TRF_McDig(8, "sg") == 3 and TRF_McTOf(8).su == 1, "closure over: the streak starts");
	MC_Tick(1);
	HOST_Check(TRF_McDig(8, "sg") == 4 and TRF_Mc_Fielded(8) == 2, "two ticks later stage 4; fielded stage 2 in this step");
	-- Fortune events: the per-phase cap; losses on screen.
	MC_Put(7, {fo=40, ue=0, at=g});
	local s = "";
	for i = 1, 5 do s = s..TRF_Mc_Fortune(7, 3, "hire")..","; end;
	HOST_Check(s == "3,3,3,3,0," and TRF_McDig(7, "fo") == 52 and TRF_Mc_Fortune(7, -5, "outbid") == -5, "positive events capped at 12 per phase, negative in full ("..s..")");
	MC_Put(7, {hp=2, fo=20, rl=0});
	TRF_Mc_Lost(7, 1, "test");
	HOST_Check(TRF_McDig(7, "hp") == 1 and TRF_McDig(7, "fo") == 17, "ship lost on screen: hp -1, fo -3");
	TRF_Mc_Lost(7, 1, "test");
	HOST_Check(TRF_McDig(7, "rl") == 2 and TRF_McTOf(7).bh == TRF_McHome(7), "hp 0: broken, bh its home");
end;

-- c: presence, losses, break and re-form, hp recovery -----------------------------------------------------------

function T_MC_C()
	local h = HOST();
	MC_Begin("6_1");
	-- Pure presence rule.
	local d = {0, 3, 2, 3, 0};
	HOST_Check(TRF_McPresenceOf(3, {0, 0, 2}, {}, {}, 3, 6, 2) == 3 and TRF_McPresenceOf(1, d, {0, 5, 2, 7, 1}, {}, 5, 6, 2) == 2
		and TRF_McPresenceOf(1, d, {0, 5, 2, 7, 1}, {0, 2}, 5, 6, 2) == 3 and TRF_McPresenceOf(1, d, {0, 7, 7, 9, 1}, {}, 5, 6, 2) == 1
		and TRF_McPresenceOf(1, {0, 3, 3}, {0, 4, 2}, {}, 3, 6, 2) == 3, "presence: home with demand, else the highest demand within reach and below 2 units (ties nearer), else home");
	-- At the tick: Kadi in Raids with a sweep scheduled, Elinor in Build-up, the rest Quiet.
	local kd, el = MC_Slot("kadi"), MC_Slot("elinor");
	MC_Phase(kd, 3, 4); MC_Phase(el, 2);
	MC_Tune("mc_loss_p", 0);
	MC_Tick(1);
	local mv, all, bad = {}, {}, "";
	for c = 1, 12 do local a = MC_V(c).at; all[a] = (all[a] or 0) + 1; end;
	for c = 1, 12 do
		local v = MC_V(c);
		local hm = TRF_McHome(c);
		if v.at ~= hm then
			mv[v.at] = (mv[v.at] or 0) + 1;
			if TRF_McSlotDist(c, v.at, TRF_RgMap()) > 6 or (v.at ~= kd and v.at ~= el) then bad = bad.." "..c; end;
		elseif TRF_McDemand(hm) < 2 then
			for i, s in {kd, el} do
				local x = TRF_McSlotDist(c, s, TRF_RgMap());
				if x and x <= 6 and (all[s] or 0) < 2 then bad = bad.." home:"..c; end;
			end;
		end;
	end;
	HOST_Check(bad == "" and (mv[kd] or 0) <= 2 and (mv[el] or 0) <= 2 and TRF_McDig(4, "at") == kd and TRF_McDig(5, "at") == kd and TRF_McDemand(kd) == 5,
		"presence: homes with demand keep their clans; the others move within 6 jumps to Kadi (Raids + sweep, demand 5) or Elinor, at most 2 each"..bad);
	local s1 = TRF.mc.s;
	local L = TRF.clock.legs;
	TRF.mc.s = s1;
	TRF_Mc_RegionTick(L);
	local s2 = TRF.mc.s;
	TRF.mc.s = s1;
	TRF_Mc_RegionTick(L);
	HOST_Check(TRF.mc.s == s2, "the same tick from the same record gives the same record (no RAND)");
	-- Off-screen losses in Raids: 8 % x T_eff by the fixed hash of (clan, tick); fo -3 per hp.
	h.cfg.tune = {};
	for c = 1, 12 do MC_Put(c, {hp=4, fo=50}); end;
	local tier = TRF_McTier(kd);
	local want, got = "", "";
	for i = 1, 12 do
		L = TRF.clock.legs + TRF_McRgTick();
		local tk = floor(L / TRF_McRgTick());
		local v0 = MC_V(4);
		if v0.hp > 0 and TRF_McRoll(4, tk, 7) < 8 * tier then want = want.."1"; else want = want.."0"; end;
		MC_Tick(1);
		if MC_V(4).hp < v0.hp then got = got.."1"; else got = got.."0"; end;
		if MC_V(4).rl == 2 then break; end;
	end;
	HOST_Check(want == got and strfind(got, "1"), "Raids losses follow the fixed hash at 8 % x T"..tier.." ("..got..")");
	-- The elite clan's off-screen losses stop at hp 2.
	local tr = MC_Slot("torr");
	MC_Phase(tr, 3);
	MC_Tune("mc_loss_p", 25);
	TRF.clan[tr].sc = 99;
	MC_Put(8, {hp=4, rl=0});
	MC_Tick(5);
	HOST_Check(MC_V(8).hp == 2 and MC_V(8).rl == 0, "elite clan: off-screen losses stop at mc_el_hp 2");
	-- Break at hp 0: rl 2, fo -30 (at least 10), cd and cj, bh; absent from income; re-form after both clocks.
	TRF.clan[kd].sc = 99;
	MC_Put(4, {hp=1, fo=50, sg=1, su=0, rl=0, g=7});
	local n0 = S_Mark();
	MC_Tick(1);
	local v = MC_V(4);
	local L0, J0 = TRF.clock.legs, TRF_Jumps();
	HOST_Check(v.rl == 2 and v.hp == 0 and v.fo == 50 + 2 - 3 - 30 and v.cd == L0 + 24 and v.cj == J0 + 8 and v.bh == kd and v.at == 0
		and S_Logs(n0, "module=merc event=break clan=4 region="..kd) == 1, "break: role 2, fortune -30, re-form after 24 legs and 8 jumps, bh Kadi ("..v.fo..")");
	local fb = v.fo;
	MC_Tick(13);
	HOST_Check(MC_V(4).rl == 2 and MC_V(4).fo == fb, "broken: no income or upkeep; jumps not yet passed");
	MC_Jump(8);
	n0 = S_Mark();
	MC_Tick(1);
	v = MC_V(4);
	HOST_Check(v.rl == 0 and v.hp == 4 and v.at ~= kd and v.at >= 1 and v.g == 3 and v.sg == TRF_McStageOfFo(v.fo, {30, 55, 78}, 2)
		and S_Logs(n0, "module=merc event=reform clan=4") == 1, "re-form: free, hp 4, stage by fortune, g at most 3, a region other than bh ("..v.at..")");
	-- hp recovery: one step needs 3 region ticks and 3 jumps since the last one, never in Raids.
	h.cfg.tune = {};
	for s = 1, TRF_RgMap().n do MC_Phase(s, 0); end;
	MC_Put(9, {hp=2, hl=TRF.clock.legs, hj=TRF_Jumps()});
	MC_Tick(3);
	HOST_Check(MC_V(9).hp == 2, "3 ticks without jumps: no recovery");
	MC_Jump(3);
	MC_Tick(1);
	HOST_Check(MC_V(9).hp == 3, "3 ticks and 3 jumps: hp +1");
	MC_Jump(3);
	MC_Tick(2);
	HOST_Check(MC_V(9).hp == 3, "the next step needs 3 more ticks");
	MC_Tick(1);
	HOST_Check(MC_V(9).hp == 4, "then hp 4");
	MC_Phase(TRF_McHome(9), 3);
	MC_Tune("mc_loss_p", 0);
	MC_Put(9, {hp=2, hl=0, hj=0});
	MC_Jump(5);
	MC_Tick(4);
	HOST_Check(MC_V(9).hp == 2, "no recovery while its region is in Raids");
end;

-- d: decays and the blacklist -----------------------------------------------------------------------------------

function T_MC_D()
	local h = HOST();
	MC_Begin("6_1");
	TRF_McRec(1);
	local L = TRF.clock.legs;
	MC_Put(2, {rel=2, met=L});
	MC_Tick(9);
	HOST_Check(TRF_McRel(2) == 2, "positive rel: no decay within merc_rel_decay legs of the meeting");
	MC_Tick(1);
	HOST_Check(TRF_McRel(2) == 1 and MC_V(2).rd == TRF.clock.legs, "20 legs without a meeting: rel 2 -> 1");
	MC_Tick(10);
	HOST_Check(TRF_McRel(2) == 0, "another 20 legs: 0");
	MC_Jump(5);
	TRF_Mc_Mark(3, "rel", -2); TRF_Mc_Mark(3, "g", 5); TRF_Mc_Mark(3, "bk", 3);
	local v = MC_V(3);
	HOST_Check(v.rj == TRF_Jumps() and v.rd == TRF.clock.legs and v.gt == TRF.clock.legs and v.bj == TRF_Jumps() and v.rel == -2 and v.g == 5 and v.bk == 3
		and TRF_Mc_Mark(3, "zz", 1) == nil, "TRF_Mc_Mark writes the value with the stamp its decay counts from");
	MC_Tick(4);
	HOST_Check(MC_V(3).g == 5, "g kept for 8 legs");
	MC_Tick(1);
	HOST_Check(MC_V(3).g == 4 and MC_V(3).rel == -2, "g -1 per rv_g_decay 10 legs; negative rel waits for jumps (8x idling clears nothing)");
	MC_Jump(20);
	MC_Tick(1);
	HOST_Check(MC_V(3).rel == -1 and MC_V(3).bk == 3, "20 jumps: rel -2 -> -1; bk needs 60");
	MC_Jump(40);
	MC_Tick(1);
	HOST_Check(MC_V(3).bk == 2 and MC_V(3).rel == 0, "60 jumps: bk 3 -> 2, rel 0");
	-- An unpaid debt is written off after merc_owe_j jumps with rel := -3.
	MC_Put(5, {rel=1});
	TRF_Mc_Mark(5, "owe", 5000);
	TRF_Mc_Mark(5, "owe", 6000);
	HOST_Check(MC_V(5).oj == TRF_Jumps() and MC_V(5).owe == 6000, "a debt keeps the stamp of its start");
	TRF_Mc_Mark(5, "owe", 5000);
	MC_Jump(59);
	MC_Tick(1);
	HOST_Check(MC_V(5).owe == 5000, "owe kept for 59 jumps");
	MC_Jump(1);
	local n0 = S_Mark();
	MC_Tick(1);
	v = MC_V(5);
	HOST_Check(v.owe == 0 and v.rel == -3 and v.rj == TRF_Jumps() and S_Logs(n0, "module=merc event=owe clan=5 amount=5000 jumps=60 result=written_off") == 1, "60 jumps: written off, rel -3");
	-- Wolves ratings decay per rv_w_decay legs.
	TRF.mc.w = "30010000000"; TRF.mc.wt = TRF.clock.legs;
	MC_Tick(3);
	HOST_Check(TRF.mc.w == "30010000000", "w kept for 7 legs");
	MC_Tick(1);
	HOST_Check(TRF.mc.w == "20000000000" and TRF.mc.wt == TRF.clock.legs, "8 legs: every rating -1");
	MC_Tick(8);
	HOST_Check(TRF.mc.w == nil and TRF.mc.wt == nil, "all ratings 0: w and wt removed");
	-- Blacklist: merc_black x bk jumps, at most 90.
	MC_Put(6, {bk=2});
	local J = TRF_Jumps();
	HOST_Check(TRF_Mc_Black(6) == J + 60 and TRF_Mc_Blacked() == 1, "bk 2: blacklist 60 jumps");
	MC_Jump(60);
	HOST_Check(TRF_Mc_Blacked() == nil, "over after 60 jumps");
	MC_Put(6, {bk=5});
	HOST_Check(TRF_Mc_Black(6) == TRF_Jumps() + 90 and TRF_McBlackOf(9, 30, 90) == 90, "bk 5: at most 90 jumps");
end;

-- e: rival candidate rule and its gate ---------------------------------------------------------------------------

function MC_Cand(c, t)
	local e = {c=c, rl=0, rel=0, sg=2, ek=0, ok=1, b=1, fo=40, hz=c, el=0, tk=0};
	if t then for k, v in t do e[k] = v; end; end;
	return e;
end;

function T_MC_E()
	local h = HOST();
	MC_Begin("6_1");
	local R = TRF_McRivalOf;
	HOST_Check(R({MC_Cand(1, {fo=40}), MC_Cand(2, {fo=60}), MC_Cand(3, {fo=50})}) == 2, "highest fortune among rel <= 0, stage >= 2");
	HOST_Check(R({MC_Cand(1, {fo=60, rel=1}), MC_Cand(2, {fo=60, sg=1}), MC_Cand(3, {fo=60, ek=1}), MC_Cand(4, {fo=60, ok=0}), MC_Cand(5, {fo=60, el=1}),
		MC_Cand(6, {fo=60, tk=1}), MC_Cand(7, {fo=60, rl=2}), MC_Cand(8, {fo=10})}) == 8,
		"excluded: rel 1, stage 1, Wolves retainer, ineligible home, the elite clan, a taken home, not free");
	HOST_Check(R({MC_Cand(1, {fo=50, hz=9}), MC_Cand(2, {fo=50, hz=3})}) == 2, "ties: the lower fixed hash");
	HOST_Check(R({MC_Cand(1, {fo=90, b=1}), MC_Cand(2, {fo=10, b=2})}, 1) == 2 and R({MC_Cand(1, {b=1})}, 1) == nil, "office unit of bloc 1: only bloc 2 clans");
	HOST_Check(R({MC_Cand(1, {rel=1, fo=90}), MC_Cand(2, {rel=1, fo=20}), MC_Cand(3, {rel=2})}) == 1 and R({MC_Cand(1, {rel=2})}) == nil,
		"no candidate at rel <= 0: the lowest rel at rel <= 1 (ties fortune)");
	-- rv_enabled 0 (default): no rivals; a saved rival is released.
	TRF_McRec(1);
	for c = 1, 12 do MC_Put(c, {rel=-1, sg=2, fo=40 + c}); end;
	MC_Put(3, {rl=1});
	local n0 = S_Mark();
	MC_Tick(1);
	HOST_Check(MC_Count("rl", 1) == 0 and S_Logs(n0, "module=merc event=role clan=3 role=0 role_before=1 reason=off") == 1, "rv_enabled 0: no clan is a rival");
	-- rv_enabled 1: three rivals by fortune with distinct homes, never the elite clan.
	MC_Set("rv_enabled", 1);
	for c = 1, 12 do MC_Put(c, {rel=-1, sg=2, fo=30 + c}); end;
	MC_Tick(1);
	local hs, nr, bad = {}, 0, "";
	for c = 1, 12 do
		if TRF_McDig(c, "rl") == 1 then
			nr = nr + 1;
			if hs[TRF_McHome(c)] then bad = bad.." dup"..c; end;
			hs[TRF_McHome(c)] = 1;
			if c == 8 then bad = bad.." elite"; end;
			if TRF_McDig(c, "at") ~= TRF_McHome(c) then bad = bad.." at"..c; end;
		end;
	end;
	HOST_Check(nr == 3 and bad == "" and TRF_McDig(12, "rl") == 1 and TRF_McDig(11, "rl") == 1, "three rivals, the richest first, distinct homes, at home"..bad);
	-- Exit by standing; the slot refills.
	MC_Put(12, {rel=1});
	n0 = S_Mark();
	MC_Tick(1);
	HOST_Check(TRF_McDig(12, "rl") == 0 and MC_Count("rl", 1) == 3 and S_Logs(n0, "clan=12 role=0 role_before=1 reason=standing") == 1, "rel 1: the rival leaves, the slot refills");
	-- Stage 1 also ends the rival role.
	local rv = nil;
	for c = 1, 12 do if TRF_McDig(c, "rl") == 1 then rv = c; end; end;
	MC_Put(rv, {sg=1, fo=5});
	MC_Tick(1);
	HOST_Check(TRF_McDig(rv, "rl") == 0, "stage 1: the rival role ends");
	-- An office unit of bloc 2: only bloc 1 clans become rivals.
	for c = 1, 12 do MC_Put(c, {rl=0, rel=-1, sg=2, fo=30 + c}); end;
	h.recruit = "stardragoon";
	MC_Tick(1);
	local b2 = 0;
	for c = 1, 12 do if TRF_McDig(c, "rl") == 1 and TRF_McClan(c).b == 2 then b2 = b2 + 1; end; end;
	HOST_Check(TRF_McOfficeBloc() == 2 and b2 == 0 and MC_Count("rl", 1) >= 1, "office unit Star Dragoons (bloc 2): only bloc 1 rivals");
	h.recruit = nil;
	MC_Set("rv_enabled", nil);
end;

-- f: repair, enabled 2, config off, hook, save and load, dump, save bound --------------------------------------

function T_MC_F()
	local h = HOST();
	MC_Begin("6_1");
	TRF_McRec(1);
	-- Config off: the tick changes nothing.
	MC_Set("merc", 0);
	local s0 = TRF.mc.s;
	MC_Tick(5);
	HOST_Check(TRF.mc.s == s0, "merc 0: no tick");
	MC_Set("merc", 1);
	-- The hook in trf_region's TRF_RegionTick.
	local n0 = S_Mark();
	TRF_RegionTick(TRF.clock.legs);
	HOST_Check(S_Logs(n0, "module=merc event=tick ") == 1, "TRF_RegionTick runs TRF_Mc_RegionTick once");
	-- Repair.
	MC_Put(4, {jobs=3, owe=700});
	local t4 = TRF.mc.t[4];
	TRF.mc.s = strsub(TRF.mc.s, 1, 60).."9"..strsub(TRF.mc.s, 62);
	TRF.mc.t[3] = "x"; TRF.mc.t[99] = "1"; TRF.mc.t.z = "1";
	TRF.mc.h = TRF_TpPackK({c=4, sys=10, n=3, tr=300}, TRF_McHKeys()); TRF.mc.hb = "999";
	TRF.mc.r = "1,2"; TRF.mc.n = TRF_TpPackK({c=2, a=500}, TRF_McNKeys()); TRF.mc.x = -4; TRF.mc.w = "123"; TRF.mc.zz = 1;
	n0 = S_Mark();
	TRF_Mc_Fix();
	local R = TRF.mc;
	HOST_Check(TRF_McRel(4) == 3 and R.t[4] == t4 and R.t[3] == nil and R.t[99] == nil and R.t.z == nil and R.h ~= nil and R.hb == "999"
		and R.r == nil and R.n ~= nil and R.x == nil and R.w == nil and R.zz == nil and S_Logs(n0, "module=merc event=fix field=r result=dropped") == 1,
		"repair: rel digit 9 clamped to 3, bad t entries and r dropped, unknown keys gone, the rest kept");
	TRF.mc.h = "1,2"; TRF.mc.hb = "123";
	TRF_Mc_Fix();
	HOST_Check(TRF.mc.h == nil and TRF.mc.hb == nil, "an unreadable hire record goes with its bands");
	TRF.mc.h = TRF_TpPackK({c=4}, TRF_McHKeys()); TRF.mc.hb = "12a";
	TRF_Mc_Fix();
	HOST_Check(TRF.mc.h ~= nil and TRF.mc.hb == nil, "bad bands dropped alone");
	TRF.mc.s = "123";
	n0 = S_Mark();
	TRF_Mc_Fix();
	HOST_Check(strlen(TRF.mc.s) == 240 and TRF.mc.s == TRF_McDefS() and S_Logs(n0, "module=merc event=fix field=s result=reset") == 1 and TRF.mc.t[4] == t4,
		"a wrong-length digit string is reset to the creation values; t kept");
	TRF.mc = 5;
	TRF_Mc_Fix();
	HOST_Check(TRF.mc == nil, "a record that is not a table is dropped");
	TRF_McRec(1);
	-- cfg enabled 2: the record goes with the restore-and-stop repair.
	MC_Set("enabled", 2);
	TRF_Repair();
	HOST_Check(TRF.mc == nil, "enabled 2: TRF.mc removed");
	MC_Set("enabled", nil);
	-- Save and load: the record comes back unchanged.
	TRF_McRec(1);
	MC_Put(7, {rel=2, jobs=4, fo=61, sg=3, met=99});
	TRF.mc.x = TRF_Jumps() + 30;
	local ss, st7, sx = TRF.mc.s, TRF.mc.t[7], TRF.mc.x;
	T_SaveLoad();
	HOST_Check(TRF.mc.s == ss and TRF.mc.t[7] == st7 and TRF.mc.x == sx and TRF_McRel(7) == 2 and TRF_McDig(7, "sg") == 3, "save and load: record unchanged");
	-- Dump.
	n0 = S_Mark();
	TRF_DumpState("test");
	HOST_Check(S_Logs(n0, "module=merc event=dump on=true clan_count=12 ") == 1 and S_Logs(n0, "module=merc event=dump_clan ") == 12
		and S_Logs(n0, "event=dump_clan clan=7 key=nomads name=Nomads bloc=1") == 1 and S_Logs(n0, "fortune=61 stage=3 fielded=2 role=0 met=99") == 1,
		"dump: a summary line and one line per clan");
	TRF.mc = nil;
	n0 = S_Mark();
	TRF_Mc_Dump();
	HOST_Check(S_Logs(n0, "module=merc event=dump on=true result=none") == 1, "dump without a record");
	-- Save bound (merc-spec 3.3): typical and worst case.
	TRF_McRec(1);
	for c = 1, 5 do MC_Put(c, {jobs=2, met=400, rd=380, rj=40}); end;
	local typ = HOST_SaveSize(TRF.mc);
	local B = TRF_McTB();
	for c = 1, 12 do
		local r = {};
		for k, b in B do if b[1] < 0 then r[k] = b[1]; else r[k] = b[2]; end; end;
		TRF_McPutT(c, r);
	end;
	local ts = HOST_SaveSize(TRF.mc.t);
	TRF.mc.h = TRF_TpPackK({c=12, sys=113, ty=2, pw=20, n=7, tr=660, fee=30000, sh=999999, bm=999999, k=99, lo=7, g=99999}, TRF_McHKeys());
	TRF.mc.hb = "99999991";
	TRF.mc.r = TRF_TpPackK({c=12, ej=-9999999, lj=-9999999}, TRF_McRKeys());
	TRF.mc.n = TRF_TpPackK({c=12, a=9999999}, TRF_McNKeys());
	TRF.mc.e = TRF_TpPackK({el=8, dj1=9999999, dc1=20, djl=9999999, dn=1}, TRF_McEKeys());
	TRF.mc.x = 9999999; TRF.mc.w = strrep("9", 11); TRF.mc.wt = -9999999;
	local wz = HOST_SaveSize(TRF.mc);
	print("HOST info merc save size: typical "..typ.." worst "..wz.." (s "..HOST_SaveSize(TRF.mc.s).." t "..ts.." h "..HOST_SaveSize(TRF.mc.h).." hb "..HOST_SaveSize(TRF.mc.hb)
		.." r "..HOST_SaveSize(TRF.mc.r).." n "..HOST_SaveSize(TRF.mc.n).." e "..HOST_SaveSize(TRF.mc.e).." w "..HOST_SaveSize(TRF.mc.w)..")");
	HOST_Check(typ <= 1000 and wz <= 3400 and HOST_Reserved(TRF, "TRF") == "", "save bound: typical "..typ.." <= 1000, worst "..wz.." <= 3400 bytes, no reserved key");
	T_SaveLoad();
	HOST_Check(HOST_SaveSize(TRF.mc) == wz, "worst case survives a load and the repair");
end;

-- Dispatch ---------------------------------------------------------------------------------

local sc = getenv("TRF_MC") or "";
local fn = getglobal("T_MC_"..strupper(sc));
print("HOST ==== mercenary clans scenario mc-"..sc.." dir="..HOST().dir);
if type(fn) == "function" then
	fn();
	HOST_Check(T_LeftGlobals() == "", "no handle globals left at the end"..T_LeftGlobals());
	local q = T_BadCallbacks();
	HOST_Check(q == "", "every mod callback string carries the current gen"..q);
else
	HOST_Check(nil, "unknown mercenary clans scenario "..sc);
end;
HOST_Check((HOST().gpm_tick or 0) == 0, "no GetPlayerMotherShip from a tick (n="..tostring(HOST().gpm_tick or 0)..")");
print("HOST errors="..HOST().errors.." fails="..HOST().fails);
if HOST().errors > 0 or HOST().fails > 0 then exit(1); end;
exit(0);
