-- Mercenary clans scenarios (design/merc-spec.md 10) under stock Lua 4.0.1: TRF_MC=a..f, run by run_host.sh as its own
-- entry point. a registration, toggles, tune, static clan table, fixed hash, record creation and accessors (digits, packed
-- fields at their bounds), b fortune and stages (income, upkeep, the two-tick streak, down, closure, big-ship loss, the
-- stage 4 slots with the reserved elite slot, the elite floor, the event cap, the fielded stage), c presence, off-screen
-- losses, the elite hp floor, break and re-form, hp recovery by ticks and jumps, d the decays (rel, g, bk, owe, w) and the
-- blacklist, e the rival candidate rule and its rv_enabled gate, f repair, enabled 2, config off, the region tick hook,
-- save and load, dump, the save bound.
-- Loads host_station.lua up to its first scenario, as host_haunt.lua does. Stub added in host_stubs.lua:
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
	-- design/strength-spec.md 5.6: trf_str counts as an extra module (12 -> 13).
	-- design/fits-spec.md 7: trf_fits counts as an extra module (13 -> 14).
	HOST_Check(S_Logs(0, "module=core event=loaded map=true module_count=18 extra_count=15") >= 1, "trf_merc loads before trf_wq (extra_count=15)");
	local ml, tf, uf = TRF_ModList(), TRF_Loc_TextFns(), TRF_UI_TextFns();
	local tfs, ufs = "", "";
	for i = 1, getn(tf) do tfs = tfs..tf[i]..","; end;
	for i = 1, getn(uf) do ufs = ufs..uf[i]..","; end;
	HOST_Check(ml[getn(ml) - 1] == "Mc" and MC_Has(tfs, "TRF_Pc_Text,TRF_Mc_Text,TRF_Wq_Text,TRF_Loc_Text,") and MC_Has(ufs, "TRF_Pc_Text,TRF_Mc_Text,TRF_Wq_Text,"),
		"TRF_ModList ends with Mc, Wq; TRF_Mc_Text after the parcel table in both text lists");
	HOST_Check(TRF_Mc_OptDef().merc == 0 and TRF_McOpt("merc") == 1 and TRF_McOpt("rv_enabled") == 0 and TRF_McOpt("mc_el_c") == 8
		and TRF_McOpt("merc_war") == 1 and TRF_McOpt("merc_hostile") == 0 and TRF_McOpt("merc_hunt") == 0 and TRF_McOpt("merc_board") == 1 and TRF_McOpt("mc_launch") == 0,
		"merc off by default (on in these runs), rivals off, elite clan 8, merc_war on and the other group-war keys off, board on, launches off");
	MC_Set("mc_el_c", 13); HOST_Check(TRF_McOpt("mc_el_c") == 8, "mc_el_c outside 0..12 reads 8");
	MC_Set("mc_el_c", 0); HOST_Check(TRF_McOpt("mc_el_c") == 0 and TRF_McElite() == 0, "mc_el_c 0: no elite clan");
	MC_Set("mc_el_c", nil);
	MC_Set("merc_war", 5); HOST_Check(TRF_McOpt("merc_war") == 1, "merc_war other than 0/1 reads the default 1");
	MC_Set("merc_war", 0); HOST_Check(TRF_McOpt("merc_war") == 0, "merc_war 0 reads 0");
	MC_Set("merc_war", nil);
	local T = TRF_McTune();
	HOST_Check(T.c_hire == 700 and T.merc_p[4] == 55 and T.mc_up[2] == 0.5 and T.mc_st_up[3] == 78 and T.mc_st_dn[1] == 22 and T.mc_ships == 14 and T.merc_ext_k == 0.75
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
	local r2 = TRF_McT(4);
	local diff = "";
	for k, b in B do if r2[k] ~= r[k] then diff = diff.." "..k; end; end;
	HOST_Check(diff == "" and getn(TRF_McTKeys()) == 29 and strlen(TRF.mc.t[4]) <= 11 * 29, "t[c]: 29 keys round-trip at their bounds ("..strlen(TRF.mc.t[4]).." chars)"..diff);
	TRF_McPutT(4, {jobs=5000, owe=-5, met=1e12, su=7});
	r2 = TRF_McT(4);
	HOST_Check(r2.jobs == 999 and r2.owe == 0 and r2.met == 9999999 and r2.su == 1 and r2.cd == 0, "t[c]: values clamped, missing keys 0");
	TRF_McPutT(4, {});
	HOST_Check(TRF.mc.t[4] == nil and TRF_McT(4).jobs == 0, "t[c] of zeros removed");
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
	local f1, g1, p1 = TRF_McBigLossOf(80, 4, 4, 4);
	local f2, g2, p2 = TRF_McBigLossOf(50, 3, 2, 3);
	local f3, g3, p3 = TRF_McBigLossOf(30, 2, 0, 3);
	local f4, g4 = TRF_McBigLossOf(10, 1, 4, 3);
	HOST_Check(f1 == 62 and g1 == 3 and p1 == 3 and f2 == 42 and g2 == 2 and p2 == 1 and f3 == 30 and p3 == 0 and f4 == 10 and g4 == 1,
		"big-ship loss values: fo 62 / 42, stage 3 / 2 (a lower stage stays), hp -1");
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
	for i, c in {1, 4, 7} do if TRF_McDig(c, "sg") == 4 then w4 = w4 + 1; elseif TRF_McDig(c, "sg") ~= 3 or TRF_McT(c).su ~= 1 then w4 = 99; end; end;
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
	HOST_Check(TRF_McDig(8, "sg") == 3 and TRF_McT(8).su == 1, "closure over: the streak starts");
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
	HOST_Check(TRF_McDig(7, "rl") == 2 and TRF_McT(7).bh == TRF_McHome(7), "hp 0: broken, bh its home");
	MC_Put(5, {rl=0, hp=1, sg=4, fo=80});
	TRF_Mc_Lost(5, 1, "test");
	HOST_Check(TRF_McDig(5, "rl") == 2 and TRF_McDig(5, "sg") == 3, "a stage 4 clan that breaks drops to stage 3 (no stage 4 slot while broken)");
	-- The elite floor holds at the break and the re-form (chapter 7: 78; the closure is over, so stage 4).
	MC_Put(8, {rl=0, hp=1, fo=80});
	TRF_Mc_Lost(8, 1, "test");
	v = MC_V(8);
	HOST_Check(v.rl == 2 and v.fo == 78 and v.sg == 3, "elite break: fortune stays at the floor 78, stage 3");
	MC_Put(8, {cd=0, cj=0});
	MC_Tick(1);
	v = MC_V(8);
	HOST_Check(v.rl == 0 and v.fo >= 78 and v.sg == 4, "elite re-form: at its floor, stage 4 ("..v.fo..", "..v.sg..")");
	-- A bad clan index is refused and changes nothing.
	local s0, x0 = TRF.mc.s, TRF.mc.x;
	local ok = TRF_Mc_Mark(13, "g", 1) == nil and TRF_Mc_Mark(0, "rel", 1) == nil and TRF_Mc_Fortune(0, 3, "x") == 0 and TRF_Mc_Black(13) == nil
		and TRF_McPut(2.5, MC_V(2)) == nil and TRF_McSetDig(2.5, "fo", 1) == nil and TRF_McPutT(2.5, {jobs=1}) == nil and TRF_McDig(2.5, "fo") == nil;
	TRF_Mc_Lost(13, 1, "test"); TRF_Mc_BigLoss(0, 3);
	HOST_Check(ok and TRF.mc.s == s0 and TRF.mc.x == x0 and TRF.mc.t[2.5] == nil, "clan 0, 13 or 2.5: refused by every reader and writer, s and t unchanged");
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
	-- A rival released at rel 1 with no other candidate is not picked again in the same tick; the fallback takes it at
	-- the next one (V9).
	for c = 1, 12 do MC_Put(c, {rl=0, sg=2, fo=40}); TRF_Mc_Mark(c, "rel", 2); end;
	MC_Put(12, {rl=1});
	TRF_Mc_Mark(12, "rel", 1);
	n0 = S_Mark();
	MC_Tick(1);
	HOST_Check(MC_Count("rl", 1) == 0 and S_Logs(n0, "clan=12 role=0 role_before=1 reason=standing") == 1 and S_Logs(n0, "clan=12 role=1 role_before=0") == 0,
		"rel 1 and no other candidate: the rival leaves and stays out this tick");
	MC_Tick(1);
	HOST_Check(TRF_McDig(12, "rl") == 1 and MC_Count("rl", 1) == 1, "next tick: the fallback picks it at rel 1");
	-- Ineligible homes: too few trader systems, Vks systems in chapters 13-15, a guard region while the guard holds.
	for c = 1, 12 do MC_Put(c, {rl=0, sg=2, fo=30 + c}); TRF_Mc_Mark(c, "rel", -1); end;
	MC_Tick(1);
	local n3 = MC_Count("rl", 1);
	MC_Tune("rv_home_n", 20);
	n0 = S_Mark();
	MC_Tick(1);
	HOST_Check(n3 == 3 and MC_Count("rl", 1) == 0 and S_Logs(n0, "reason=home") == 3, "rv_home_n 20: every rival leaves (reason=home), none enters");
	MC_Tune("rv_home_n", nil);
	MC_Tick(1);
	rv = nil;
	for c = 1, 12 do if TRF_McDig(c, "rl") == 1 then rv = c; end; end;
	local m = TRF_RgMap();
	local hs = TRF_McHome(rv);
	for i = 1, getn(m[hs].sys) do h.teams[TRF_SysName(m[hs].sys[i])] = "Vks"; end;
	local T = TRF_McTune();
	HOST_Check(TRF_McHomeOk(hs, m, 12, T) and not TRF_McHomeOk(hs, m, 13, T), "Vks systems count in chapter 12, not in 13");
	h.labels.CurrentQuest = "13_1";
	n0 = S_Mark();
	MC_Tick(1);
	HOST_Check(TRF_McDig(rv, "rl") == 0 and S_Logs(n0, "clan="..rv.." role=0 role_before=1 reason=home") == 1, "chapter 13: a home of Vks systems is not eligible");
	h.teams = {};
	h.labels.CurrentQuest = "6_1";
	local gs = nil;
	for s = 1, m.n do if m[s].guard == 1 then gs = s; end; end;
	local T0 = {};
	for k, x in T do T0[k] = x; end;
	T0.rv_home_n = 0;
	local g6 = TRF_McHomeOk(gs, m, 6, T0);
	h.labels.CurrentQuest = "4_1";
	HOST_Check(gs and g6 and not TRF_McHomeOk(gs, m, 4, T0), "guard region: no rival home while the guard holds (chapter 4)");
	h.labels.CurrentQuest = "6_1";
	-- A rival's fortune -2 while the Wolves lead in its home region by 2 (w digit - floor(fo / 10)).
	for c = 1, 12 do MC_Put(c, {rl=0, sg=2, fo=40}); TRF_Mc_Mark(c, "rel", -1); end;
	MC_Tick(1);
	local ra, rb = nil, nil;
	for c = 1, 12 do if TRF_McDig(c, "rl") == 1 then if not ra then ra = c; elseif not rb then rb = c; end; end; end;
	MC_Put(ra, {fo=40}); MC_Put(rb, {fo=40});
	local ha = TRF_McHome(ra);
	TRF.mc.w = strrep("0", ha - 1).."6"..strrep("0", 11 - ha);
	TRF.mc.wt = TRF.clock.legs;
	MC_Tick(1);
	HOST_Check(rb and TRF_McDig(rb, "fo") - TRF_McDig(ra, "fo") == 2 and TRF_McLeadOf("06", 2, 49) == 2 and TRF_McLeadOf(nil, 1, 0) == 0,
		"Wolves lead 2 in a rival's home: fortune -2");
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
	TRF.mc.t[3] = "x"; TRF.mc.t[99] = "1"; TRF.mc.t.z = "1"; TRF.mc.t[2.5] = t4;
	TRF.mc.h = TRF_TpPackK({c=4, sys=10, n=3, tr=300}, TRF_McHKeys()); TRF.mc.hb = "100005501000";
	TRF.mc.r = "1,2"; TRF.mc.n = TRF_TpPackK({c=2, a=500}, TRF_McNKeys()); TRF.mc.x = -4; TRF.mc.w = "123"; TRF.mc.zz = 1;
	n0 = S_Mark();
	TRF_Mc_Fix();
	local R = TRF.mc;
	HOST_Check(TRF_McRel(4) == 3 and R.t[4] == t4 and R.t[3] == nil and R.t[99] == nil and R.t.z == nil and R.t[2.5] == nil and R.h ~= nil and R.hb == "100005501000"
		and R.r == nil and R.n ~= nil and R.x == nil and R.w == nil and R.zz == nil and S_Logs(n0, "module=merc event=fix field=r result=dropped") == 1,
		"repair: rel digit 9 clamped to 3, bad t entries and r dropped, unknown keys gone, the rest kept");
	TRF.mc.h = "1,2"; TRF.mc.hb = "123";
	TRF_Mc_Fix();
	HOST_Check(TRF.mc.h == nil and TRF.mc.hb == nil, "an unreadable hire record goes with its hull");
	TRF.mc.h = TRF_TpPackK({c=4, sys=10, n=3, tr=300, fee=900, sh=10, bm=40, k=1, lo=1, g=30}, TRF_McHKeys());
	TRF.mc.hb = "1000";
	local h12 = "4,10,0,0,3,300,900,10,40,1,1,30";
	HOST_Check(TRF_TpUnpackK(TRF.mc.h, TRF_McHKeys()).hj == 0 and TRF_TpUnpackK(h12, TRF_McHKeys()) == nil, "hire record of 14 values; a 12-value one is unreadable");
	TRF.mc.h = h12;
	TRF_Mc_Fix();
	HOST_Check(TRF.mc.h == nil and TRF.mc.hb == nil, "a hire record without hj and hg (before 2026-10-25) is dropped with its hull");
	TRF.mc.h = TRF_TpPackK({c=4}, TRF_McHKeys()); TRF.mc.hb = "12a";
	TRF_Mc_Fix();
	HOST_Check(TRF.mc.h ~= nil and TRF.mc.hb == nil, "bad hull dropped alone");
	TRF.mc.hb = "99999";
	TRF_Mc_Fix();
	HOST_Check(TRF.mc.h ~= nil and TRF.mc.hb == nil, "band digits of the old form dropped");
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
	TRF.mc.h = TRF_TpPackK({c=12, sys=113, ty=3, pw=20, n=6, tr=660, fee=30000, sh=999999, bm=999999, k=99, lo=6, g=99999, hj=99,
		hg=9999999}, TRF_McHKeys());
	TRF.mc.hb = strrep("1000", 6);
	TRF.mc.r = TRF_TpPackK({c=12, ej=-9999999, lj=-9999999}, TRF_McRKeys());
	TRF.mc.n = TRF_TpPackK({c=12, a=9999999}, TRF_McNKeys());
	TRF.mc.e = TRF_TpPackK({el=8, dj1=9999999, dc1=20, djl=9999999, dn=1}, TRF_McEKeys());
	TRF.mc.x = 9999999; TRF.mc.w = strrep("9", 11); TRF.mc.wt = -9999999;
	TRF.mc.o = TRF_TpPackK({c=12, s=113}, TRF_McOKeys());
	local wz = HOST_SaveSize(TRF.mc);
	print("HOST info merc save size: typical "..typ.." worst "..wz.." (s "..HOST_SaveSize(TRF.mc.s).." t "..ts.." h "..HOST_SaveSize(TRF.mc.h).." hb "..HOST_SaveSize(TRF.mc.hb)
		.." r "..HOST_SaveSize(TRF.mc.r).." n "..HOST_SaveSize(TRF.mc.n).." e "..HOST_SaveSize(TRF.mc.e).." w "..HOST_SaveSize(TRF.mc.w).." o "..HOST_SaveSize(TRF.mc.o)..")");
	HOST_Check(typ <= 1000 and wz <= 3420 and HOST_Reserved(TRF, "TRF") == "", "save bound: typical "..typ.." <= 1000, worst "..wz.." <= 3420 bytes, no reserved key");
	T_SaveLoad();
	HOST_Check(HOST_SaveSize(TRF.mc.t) == ts and TRF.mc.h ~= nil and HOST_SaveSize(TRF.mc) <= wz,
		"worst case survives a load and the repair (the rebuild in this system rewrites the hire record)");
end;

-- Hire role helpers (build step 3, merc-spec 10) -----------------------------------------------------------------

-- Handle globals of the visit's clan flight are expected while its ship lives (the load finds the wing through them).
MC_HandleOk0 = T_HandleOk;
function T_HandleOk(k)
	local a, b, n, j = strfind(k, "^TRF_ship_trf_merc_(%d+)_(%d+)$");
	if n then
		local v = TRF_McV();
		local o = getglobal(k);
		return type(v) == "table" and v.n == tonumber(n) and o and o.alive and v.del ~= 1;
	end;
	return MC_HandleOk0(k);
end;

-- Hire runs: chapter ch (6_1), no region tick (cfg cycle 0: the clans stay where a run puts them), every clan at home,
-- gaoba's region (Kadi, the home of clans 4 and 5) in Raids, merc_p 100 %, clans 4 and 5 at stage sg (default 1), wallet
-- 1,000,000, heat and help 0.
function MC_HBegin(ch, sg, t)
	local h = HOST();
	t = t or {};
	if t.cycle == nil then t.cycle = 0; end;
	MC_Begin(ch or "6_1", t);
	h.credits = 1000000;
	h.labels.OutMissionEscort = nil;
	h.qs = FALSE;
	MC_Tune("merc_reach", 0);
	MC_Tune("merc_p", {100, 100, 100, 100, 100, 100});
	MC_Tune("merc_p_max", 100);
	TRF_McRec(1);
	MC_Phase(MC_Slot("gaoba"), 3);
	MC_Put(4, {sg=sg or 1, met=0, rel=0, hp=4});
	MC_Put(5, {sg=sg or 1, met=0, rel=0, hp=4});
	TRF.std.heat = 0; TRF.std.help = 0;
end;

-- Dialog pages on (tune hail_box 2, cfg hail_xml 1, an idle UI) or off.
function MC_Dlg(on)
	local h = HOST();
	if on then
		MC_Tune("hail_box", 2);
		h.cfg.hail_xml = 1;
		TRF_UiState = HOST_UiState;
		h.ui = 0;
	else
		MC_Tune("hail_box", 1);
		h.cfg.hail_xml = nil;
		TRF_UiState = nil;
		h.ui = nil;
	end;
end;

-- Entry into sys by a jump, then the spawn delay (up to 96 s).
function MC_Enter(sys, wait)
	T_Jump(sys or "gaoba");
	if wait ~= 0 then T_Tick(wait or 192, 0.5); end;
end;

-- Live ships labelled trf_merc_<n>_<j> in the scene.
function MC_Ships(n)
	local l = {};
	for j = 1, 6 do
		local o = HOST().objs["trf_merc_"..(n or 1).."_"..j];
		if o and o.alive then tinsert(l, o); end;
	end;
	return l;
end;

-- The mothership next to the pack leader; the meeting poll, the offer line and the page or box 12 s later.
function MC_Meet()
	local s = TRF_McLead(TRF_McV());
	local p = s:GetPosition();
	HOST().ms.pos = Vector3(p.x + 20, p.y, p.z);
	T_Tick(32, 0.5);
end;

-- Spawn, meet, OK: a hired pack in gaoba (box mode). Returns the visit record.
function MC_Hire()
	MC_Enter("gaoba");
	MC_Meet();
	HOST_Press("ok");
	T_Tick(2, 0.5);
	return TRF_McV();
end;

-- Ends the visit's flight and any hire record (test reset), then jumps to sys (default heos) without waiting.
function MC_Reset(sys)
	local v = TRF_McV();
	if type(v) == "table" and v.st ~= "gone" then TRF_McDelAll(v, "test"); end;
	TRF.mc.h = nil; TRF.mc.hb = nil; TRF.mc.o = nil;
	TRF_McMC().v = nil; TRF_McMC().cv = nil;
	TRF_N("TRF_EscortFree", "merc");
	TRF_N("TRF_BoxFree", "merc");
	MC_Enter(sys or "heos", 0);
	MC_Put(4, {met=0}); MC_Put(5, {met=0});
end;

-- Kills pack ship j of the visit (its died trigger fires).
function MC_Kill(j)
	local v = TRF_McV();
	v.sh[j].alive = nil;
	HOST_Fire("died", "TRF_McDied("..v.n..","..j..",");
end;

-- n player hits on pack ship j, one game second apart.
function MC_Hits(j, n)
	local v = TRF_McV();
	for i = 1, n or 5 do
		HOST_Fire("attack", "TRF_McHit("..v.n..","..j..",");
		T_Tick(2, 0.5);
	end;
end;

-- The patrol dock of the scene through the dispatcher: screen lines since s0 joined by "|".
function MC_Dock()
	local h = HOST();
	local s0 = getn(h.screen);
	_param = GetCurrentLocation();
	__PatrolStationDock_Ok();
	local r = "";
	for i = s0 + 1, getn(h.screen) do r = r..h.screen[i].t.."|"; end;
	return r;
end;

-- Radio and screen texts since index m0 / s0, joined.
function MC_Txt(m0, s0)
	local r, h = "", HOST();
	for i = (m0 or 0) + 1, getn(h.msgs) do r = r..h.msgs[i].t.."|"; end;
	for i = (s0 or 0) + 1, getn(h.screen) do r = r..h.screen[i].t.."|"; end;
	return r;
end;

-- Last relation set for the pair a, b (HOST().rel), or nil.
function MC_Rel(a, b)
	local q, r = HOST().rel, nil;
	for i = 1, getn(q) do if q[i][1] == a and q[i][2] == b then r = q[i][3]; end; end;
	return r;
end;

-- 1 when the point lists a and b ({x, y, z}) are equal.
function MC_PtsEq(a, b)
	if getn(a) ~= getn(b) then return nil; end;
	for i = 1, getn(a) do if a[i].x ~= b[i].x or a[i].y ~= b[i].y or a[i].z ~= b[i].z then return nil; end; end;
	return 1;
end;

-- 1 when every flight of v patrols the points of v.pp in order (Vector3s), nil otherwise.
function MC_Patrols(v)
	if getn(v.fl) == 0 then return nil; end;
	for i = 1, getn(v.fl) do
		local p = v.fl[i].patrol;
		if type(p) ~= "table" or getn(p) ~= getn(v.pp) then return nil; end;
		for k = 1, getn(p) do if not HOST_IsVec(p[k]) or HOST_Dist(p[k], v.pp[k]) > 0.01 then return nil; end; end;
	end;
	return 1;
end;

-- Clears the recorded Patrol and Move orders of v's flights.
function MC_ClrOrd(v)
	for i = 1, getn(v.fl) do v.fl[i].patrol = nil; v.fl[i].mv = nil; end;
end;

-- The mothership at distance d from the pack leader along +x; returns the leader position.
function MC_MsAt(d)
	local p = TRF_McLead(TRF_McV()):GetPosition();
	HOST().ms.pos = Vector3(p.x + d, p.y, p.z);
	return p;
end;

-- g: pure rules, the roll and its gates, the spawn, caps ---------------------------------------------------------

function T_MC_G()
	local h = HOST();
	MC_HBegin("6_1", 1);
	-- Pure parts.
	HOST_Check(TRF_McPwOf(12, 3, 0, 4) == 14 and TRF_McPwOf(13, 4, 1, 4) == 17 and TRF_McPwOf(5, 1, -2, 2) == 1 and TRF_McPwOf(20, 4, 1, 4) == 20,
		"strength: sys_base + off(T) + stage offset - (4 - hp), clamped 1..20");
	HOST_Check(TRF_McOwnerKOf("Vks", 6) == 1 and TRF_McOwnerKOf("Vks", 7) == 0.5 and TRF_McOwnerKOf("Vks", 13) == 0 and TRF_McOwnerKOf("Vks", 17) == 0.5
		and TRF_McOwnerKOf("Kfni", 8) == 1.25 and TRF_McOwnerKOf("Kfni", 12) == 1 and TRF_McOwnerKOf("Neutral", 13) == 1, "owner factor by chapter");
	HOST_Check(TRF_McPOf(55, 25, 80, 1) == 80 and TRF_McPOf(35, 0, 80, 0.5) == 17.5 and TRF_McPOf(5, 25, 80, 0) == 0, "chance: phase + sweep, max 80, x owner");
	HOST_Check(TRF_McPickOf({{c=4, w=4}, {c=5, w=1}}, 3) == 4 and TRF_McPickOf({{c=4, w=4}, {c=5, w=1}}, 4) == 5, "weighted pick (rel + 4)");
	HOST_Check(TRF_McCompOf(1, 1) == 1 and TRF_McCompOf(2, 1) == 2 and TRF_McCompOf(1, 2) == 3 and TRF_McCompOf(2, 2) == 3, "composition by unit type and fielded stage");
	local r1, r3 = TRF_McRows(1, 14), TRF_McRows(3, 14);
	HOST_Check(getn(r1) == 1 and r1[1].m == 4 and r1[1].t == Rec_Fighters[12] and getn(r3) == 2 and r3[1].m == 3 and r3[2].t == Rec_Bombers[10] and r3[2].p == 12
		and TRF_McRowsN(r1) == 4 and TRF_McRowsN(r3) == 6, "rows: Rec_Fighters at most 4; fighters 3 plus bombers at pw - 2 (NORMAL __tablevel)");
	HOST_Check(TRF_McPmOf(1000, 1000) == 1000 and TRF_McPmOf(500, 1000) == 500 and TRF_McPmOf(1, 3000) == 1 and TRF_McPmOf(2, 3) == 667
		and TRF_McPmOf(0, 1000) == 0 and TRF_McPmOf(nil, 1000) == 0 and TRF_McPmOf(1200, 1000) == 1000, "hull per mille 1..1000, rounded up");
	HOST_Check(TRF_McHealOf(1, 0, 150, 1) == 150 and TRF_McHealOf(2, 20, 150, 1) == 320 and TRF_McHealOf(1, -5, 150, 1) == 150
		and TRF_McHealOf(0, 7, 0, 0.5) == 3 and TRF_McHealOf(nil, nil, 150, 1) == 0, "off-screen repair: mc_heal_j per jump plus mc_heal_s per suspended second");
	HOST_Check(TRF_McHullStr({1000, 0, 55}, 3) == "100000000055" and TRF_McHullStr({}, 0) == nil and TRF_McHullOk("1000") and TRF_McHullOk("0000")
		and TRF_McHullOk(strrep("1000", 6)) and not TRF_McHullOk(strrep("1000", 7)) and not TRF_McHullOk("1001") and not TRF_McHullOk("100")
		and not TRF_McHullOk("") and not TRF_McHullOk("10a0") and not TRF_McHullOk(1000), "hull string: 4 digits per slot, 1..6 slots, each at most 1000");
	MC_Tune("mc_heal_j", 5000); MC_Tune("mc_heal_s", -2);
	HOST_Check(TRF_McTn("mc_heal_j") == 1000 and TRF_McTn("mc_heal_s") == 0, "mc_heal_j and mc_heal_s clamped to 0..1000");
	MC_Tune("mc_heal_j", nil); MC_Tune("mc_heal_s", nil);
	HOST_Check(TRF_McTn("mc_heal_j") == 150 and TRF_McTn("mc_heal_s") == 1, "repair tune defaults 150 and 1 per mille");
	-- Gates (TRF_McAppear on the current system; the visit record cleared between tries).
	local cur = V_Idx("gaoba");
	local mc = TRF_McMC();
	TRF.mc.x = TRF_Jumps() + 10;
	local n0 = S_Mark();
	mc.v = nil; TRF_McAppear(cur);
	HOST_Check(not mc.v and S_Logs(n0, "event=roll system=gaoba result=none reason=black") == 1, "blacklist: no roll");
	TRF.mc.x = nil;
	h.labels.OutMissionEscort = "m18c_escort";
	n0 = S_Mark(); mc.v = nil; TRF_McAppear(cur);
	HOST_Check(not mc.v and S_Logs(n0, "reason=escort_mission") == 1, "OutMissionEscort running: no roll");
	h.labels.OutMissionEscort = nil;
	TRF.live.esc = "lad";
	n0 = S_Mark(); mc.v = nil; TRF_McAppear(cur);
	HOST_Check(not mc.v and S_Logs(n0, "reason=escort_slot") == 1, "escort slot held by #9: no roll");
	TRF.live.esc = nil;
	TRF.live.ev = "sweep";
	n0 = S_Mark(); mc.v = nil; TRF_McAppear(cur);
	HOST_Check(not mc.v and S_Logs(n0, "reason=event") == 1, "on-screen sweep event: no roll");
	TRF.live.ev = nil;
	MC_Tune("merc_p", {0, 0, 0, 0, 0, 0});
	n0 = S_Mark(); mc.v = nil; TRF_McAppear(cur);
	HOST_Check(not mc.v and S_Logs(n0, "reason=roll") == 1, "chance 0: the roll fails");
	MC_Tune("merc_p", {100, 100, 100, 100, 100, 100});
	MC_Put(4, {at=1}); MC_Put(5, {at=1});
	n0 = S_Mark(); mc.v = nil; TRF_McAppear(cur);
	HOST_Check(not mc.v and S_Logs(n0, "reason=no_clan") == 1, "no clan works the region: no roll");
	TRF.clock.legs = 20;
	MC_Put(4, {at=MC_Slot("gaoba"), met=18}); MC_Put(5, {at=MC_Slot("gaoba"), met=17});
	n0 = S_Mark(); mc.v = nil; TRF_McAppear(cur);
	HOST_Check(not mc.v and S_Logs(n0, "reason=no_clan") == 1, "met within merc_cd 4 legs: no candidate");
	MC_Put(4, {met=0}); MC_Put(5, {met=0});
	MC_Tune("mc_ships", 2);
	n0 = S_Mark(); mc.v = nil; TRF_McAppear(cur);
	HOST_Check(not mc.v and S_Logs(n0, "reason=cap:merc_cap") == 1, "mc_ships below the pack: no roll");
	MC_Tune("mc_ships", 14);
	HOST_Check(TRF_McSysWhy(V_Idx("kassilia")) == "excluded" and TRF_McSysWhy(V_Idx("nk")) == "excluded" and TRF_McSysWhy(cur) == nil,
		"permanent exclusions (Kassilia, NK)");
	-- The roll: deterministic per (system, leg); the same clan twice.
	n0 = S_Mark(); mc.v = nil; mc.nx = 0; local a1 = TRF_McAppear(cur); local c1 = mc.v.c;
	mc.v = nil; mc.nx = 0; local a2 = TRF_McAppear(cur);
	HOST_Check(a1 == 1 and a2 == 1 and mc.v.c == c1 and (c1 == 4 or c1 == 5) and S_Logs(n0, "result=planned") == 2, "fixed-hash roll: same clan twice ("..tostring(c1)..")");
	mc.v = nil; mc.nx = 0;
	-- Chapter 4 and merc 0: nothing at entry.
	h.labels.CurrentQuest = "4_1";
	n0 = S_Mark(); MC_Enter("gaoba", 0);
	HOST_Check(S_Logs(n0, "module=merc event=roll") == 0 and not TRF_McV(), "chapter 4: no roll");
	h.labels.CurrentQuest = "6_1";
	MC_Set("merc", 0);
	n0 = S_Mark(); MC_Enter("gaoba", 0);
	HOST_Check(S_Logs(n0, "module=merc event=roll") == 0 and TRF_PlAdopt().Merc == nil, "merc 0: no roll, no adoption registration");
	MC_Set("merc", 1);
	-- Through the entry: planned, spawned 30-90 s later at the portal toward Kadi (PORTAL D -> xk10).
	MC_Put(4, {met=0}); MC_Put(5, {met=0});
	n0 = S_Mark();
	MC_Enter("gaoba", 0);
	local v = TRF_McV();
	HOST_Check(v and v.st == "due" and v.n == 1 and S_Logs(n0, "module=merc event=roll system=gaoba chance=100.000 roll=") == 1 and TRF_PlAdopt().Merc == 1,
		"entry: planned (merc_p 100, merc_p_max 100), flight 1, Merc adopted at load");
	T_Tick(192, 0.5);
	local sh = MC_Ships(1);
	HOST_Check(v.st == "wait" and getn(sh) == v.ns and v.ns == TRF_McRowsN(TRF_McRows(1, v.pw)) and v.ns >= 1
		and S_Logs(n0, "module=merc event=spawn flight=1 clan="..v.c.." group=TRF_Merc_1 stage=1 composition=1 power="..v.pw) == 1
		and S_Logs(n0, "portal=PORTAL_D result=spawn") == 1, "spawn: the Rec_Fighters row at the pack's power ("..v.ns.." ships) of TRF_Merc_1 at the portal toward the home");
	HOST_Check(MC_Rel("TRF_Merc_1", PLAYER_GROUP) == RELATION_NEUTRAL and MC_Rel(PLAYER_GROUP, "TRF_Merc_1") == RELATION_NEUTRAL and TRF.live.esc == "merc",
		"relations neutral both ways; the escort slot taken");
	HOST_Check(HOST_Count("died", "TRF_McDied(1,") == v.ns and HOST_Count("attack", "TRF_McHit(1,") == v.ns and HOST_Count("f_object_inside", "TRF_McMeet(1,") == 1,
		"died and attack triggers per ship, the meeting trigger");
	HOST_Check(getglobal("TRF_ship_trf_merc_1_1") == sh[1] and getglobal("TRF_GMerc_1") == nil and HOST_Navs() >= 1 and TRF_McT(v.c).met == TRF.clock.legs,
		"handle globals by slot, no group global left, nav marker, met stamped");
	HOST_Check(MC_Has(MC_Txt(), TRF_McClanName(v.c)..", working these lanes."), "signature line");
	HOST_Check(sh[1].pilot.tpl == "RecruitPilot_"..TRF_McClan(v.c).k or sh[1].pilot.tpl == "RecruitOfficer_"..TRF_McClan(v.c).k, "clan pilot list");
	-- A second flight of the visit would fit beside the first within mc_ships 14 (not within 7).
	local nl = TRF_McLive();
	local ok14 = TRF_CanSpawn(8 - nl, "merc", nl);
	MC_Tune("mc_ships", 7);
	local ok7, w7 = TRF_CanSpawn(8 - nl, "merc", nl);
	MC_Tune("mc_ships", 14);
	HOST_Check(ok14 and not ok7 and w7 == "merc_cap" and TRF_Mc_Ships("merc") == v.ns and TRF_McAlloc() == 2, "a second flight fits with mc_ships 14 (not 7); flight number 2 next");
	-- Ship-cap trim takes unhired ships.
	HOST_Check(TRF_Mc_Trim("merc", 1) == 1 and TRF_McLive() == nl - 1, "trim: an unhired pack gives a ship");
	-- Stage 2: two flights, labels 1..6.
	MC_Put(4, {sg=2, met=0}); MC_Put(5, {sg=2, met=0});
	n0 = S_Mark();
	MC_Enter("gaoba");
	v = TRF_McV();
	HOST_Check(v and v.cp == 3 and getn(v.fl) == 2 and getn(MC_Ships(1)) == 6 and HOST().objs["trf_merc_1_6"] ~= nil, "stage 2: fighters and bombers, two flights, slots 1..6");
	-- The patrol loop (user decision 2026-10-29): gaoba has the mouth of PORTAL D, two stations, PORTAL L and R, 4 belt slots.
	local pd = TRF_GnPortalObj("PORTAL_D");
	local mo = TRF_McMouth(pd);
	local gap, s300 = 1, 0;
	for i = 1, getn(v.pp) do
		for k = i + 1, getn(v.pp) do if TRF_McD3(v.pp[i], v.pp[k]) < 200 then gap = nil; end; end;
		if abs(TRF_McD3(v.pp[i], {x=-304, y=0, z=1104}) - 300) < 0.01 or abs(TRF_McD3(v.pp[i], {x=600, y=0, z=600}) - 300) < 0.01 then s300 = s300 + 1; end;
	end;
	HOST_Check(getn(v.pp) == 5 and mo.x == 10 and mo.z == -1150 and MC_PtsEq({v.pp[1]}, {mo}) and s300 == 2 and gap
		and (MC_PtsEq({v.pp[4]}, {{x=-840, y=0, z=250}}) or MC_PtsEq({v.pp[4]}, {{x=860, y=0, z=1550}})) and MC_PtsEq({v.pp[5]}, {{x=102, y=-18, z=58}})
		and MC_Patrols(v) and S_Logs(n0, "event=patrol flight=1 clan="..v.c.." points=5 result=start") == 1,
		"patrol: both flights loop 5 points (the PORTAL D mouth, 300 off each station, the PORTAL L or R mouth, a belt slot), 200 apart, logged");
	local cg = TRF_McPtsCand(cur, pd, "PORTAL_D");
	local hh = TRF_McHash(cur, 1, 20);
	HOST_Check(getn(cg.st) == 2 and getn(cg.op) == 2 and getn(cg.ex) == 4 and MC_PtsEq(TRF_McPtsOf(cg, hh), TRF_McPtsOf(cg, hh))
		and MC_PtsEq(TRF_McPtsOf(TRF_McPtsCand(cur, pd, "PORTAL_D"), hh), TRF_McPtsOf(cg, hh)), "patrol points: candidates of gaoba, same hash same points");
	-- Without belt slots a haunt route point is the extra candidate (TRF_HaData rows f[i].r[k]).
	local sl1, nd1 = TRF_ShSlots, TRF_HaData;
	TRF_ShSlots = function(nm) return nil; end;
	TRF_HaData = function(nm) return {f={{r={{100, 0, 900}}}}}; end;
	local cn = TRF_McPtsCand(cur, pd, "PORTAL_D");
	local qn = TRF_McPtsOf(cn, hh);
	TRF_ShSlots = sl1; TRF_HaData = nd1;
	HOST_Check(getn(cn.ex) == 1 and MC_PtsEq(cn.ex, {{x=100, y=0, z=900}}) and getn(qn) == 5 and MC_PtsEq({qn[5]}, {{x=100, y=0, z=900}}),
		"patrol points: no belt slot, the haunt route point is the extra point");
	-- Pure: order, the standoff, dedupe within 200, at most two stations from h mod n, picks by floor(h / 7) and floor(h / 11), cap 5, no mouth.
	local O = {x=0, y=0, z=0};
	local q = TRF_McPtsOf({m=O, st={{x=1000, y=0, z=0}}, op={{x=0, y=0, z=1000}}, ex={{x=-1000, y=0, z=0}}}, 0);
	HOST_Check(MC_PtsEq(q, {O, {x=700, y=0, z=0}, {x=0, y=0, z=1000}, {x=-1000, y=0, z=0}}), "pure: mouth, standoff 300 toward the mouth, portal, extra");
	q = TRF_McPtsOf({m=O, st={{x=1000, y=0, z=0}}, op={{x=150, y=0, z=0}}, ex={{x=700, y=0, z=150}}}, 0);
	HOST_Check(MC_PtsEq(q, {O, {x=700, y=0, z=0}}), "pure: points within 200 of a kept point dropped");
	local S3 = {{x=1000, y=0, z=0}, {x=0, y=0, z=-1000}, {x=-1000, y=0, z=0}};
	local P3 = {{x=0, y=500, z=0}, {x=0, y=1000, z=0}, {x=0, y=1500, z=0}};
	local E2 = {{x=0, y=-500, z=0}, {x=0, y=-1000, z=0}};
	q = TRF_McPtsOf({m=O, st=S3, op=P3, ex=E2}, 1);
	HOST_Check(MC_PtsEq(q, {O, {x=0, y=0, z=-700}, {x=-700, y=0, z=0}, P3[1], E2[1]}), "pure: stations 2 and 3 for h 1, portal 1, extra 1, five points");
	q = TRF_McPtsOf({m=O, st=S3, op=P3, ex=E2}, 14);
	HOST_Check(MC_PtsEq(q, {O, {x=-700, y=0, z=0}, {x=700, y=0, z=0}, P3[3], E2[2]}), "pure: h 14 picks stations 3 and 1, portal floor(14/7) mod 3 = 2, extra floor(14/11) mod 2 = 1");
	HOST_Check(getn(TRF_McPtsOf({m=O}, 5)) == 1 and getn(TRF_McPtsOf({st=S3, op=P3}, 5)) == 0 and getn(TRF_McPtsOf(nil, 5)) == 0, "pure: the mouth alone; no mouth no points");
	-- The stay: not gone after 250 s; merc_wait_s 3600 (clamp 30..10800), merc_app_r 700.
	local m0 = getn(h.msgs);
	n0 = S_Mark();
	T_Tick(500, 0.5);
	HOST_Check(v.st == "wait" and S_Logs(n0, "event=leave") == 0 and TRF_McTn("merc_wait_s") == 3600 and TRF_McTn("merc_app_r") == 700,
		"unhired: still in the system after 250 s (merc_wait_s 3600, merc_app_r 700)");
	MC_Tune("merc_wait_s", 20000);
	local w1 = TRF_McTn("merc_wait_s");
	MC_Tune("merc_wait_s", 10);
	HOST_Check(w1 == 10800 and TRF_McTn("merc_wait_s") == 30, "merc_wait_s clamped to 30..10800");
	MC_Tune("merc_wait_s", nil);
	T_Tick(3300, 1);
	HOST_Check(v.st == "wait" and S_Logs(n0, "event=leave") == 0, "unhired: still waiting at 3550 s");
	T_Tick(120, 0.5);
	HOST_Check(S_Logs(n0, "event=leave flight=1 clan="..v.c.." portal=") == 1 and S_Logs(n0, "reason=wait") >= 1 and MC_Has(MC_Txt(m0), "No contract, no reason to stay.")
		and TRF.live.esc == nil, "unhired: leaves after 3600 game s, escort slot freed");
	T_Tick(4, 0.5);
	HOST_Check(v.st == "gone" and getn(MC_Ships(1)) == 0 and getglobal("TRF_ship_trf_merc_1_1") == nil, "deleted at the portal, handle globals cleared");
	-- Fallback: no station, no other portal, no belt slot: one Move off the portal mouth.
	MC_Reset();
	MC_Put(4, {sg=1, met=0}); MC_Put(5, {sg=1, met=0});
	n0 = S_Mark();
	MC_Enter("gaoba", 0);
	local gs = TRF_Map().sys[cur];
	local st0, ps0, sl0 = gs.st, gs.portals, TRF_ShSlots;
	gs.st = nil; gs.portals = {gs.pby.PORTAL_D};
	TRF_ShSlots = function(nm) return nil; end;
	T_Tick(192, 0.5);
	gs.st = st0; gs.portals = ps0; TRF_ShSlots = sl0;
	v = TRF_McV();
	HOST_Check(v and v.st == "wait" and getn(v.pp) == 1 and v.fl[1].patrol == nil and v.fl[1].mv and HOST_Dist(v.fl[1].mv, mo) < 0.01
		and S_Logs(n0, "event=patrol flight=1 clan="..v.c.." points=1 result=fallback") == 1, "fallback: one point, Move off the portal mouth, no Patrol");
	MC_Approach();
	MC_Enter("heos", 0);
end;

-- The approach rule (user decision 2026-10-29), part of mc-g: within merc_app_r 700 the pack moves to 60 units short of
-- the mothership, past 1400 it patrols again; the meeting at 70 still fires; a declined offer and state noh resume the
-- patrol; a hired pack gets neither.
function MC_Approach()
	local h = HOST();
	MC_Reset();
	MC_Put(4, {sg=2, met=0}); MC_Put(5, {sg=2, met=0});
	MC_Enter("gaoba");
	local v = TRF_McV();
	HOST_Check(v and v.st == "wait" and getn(v.fl) == 2 and MC_Patrols(v) and v.ap == nil, "approach: a fresh pack of two flights on patrol");
	local n0 = S_Mark();
	MC_ClrOrd(v);
	local lp = MC_MsAt(500);
	T_Tick(2, 0.5);
	local want = Vector3(lp.x + 440, lp.y, lp.z);
	HOST_Check(v.ap == 1 and v.fl[1].mv and v.fl[2].mv and HOST_Dist(v.fl[1].mv, want) < 0.01 and HOST_Dist(v.fl[2].mv, want) < 0.01 and v.fl[1].patrol == nil
		and S_Logs(n0, "event=approach flight=1 clan="..v.c.." distance=500 result=start") == 1, "within 700: every flight moves to 60 units short of the mothership, logged");
	MC_ClrOrd(v);
	h.ms.pos = Vector3(lp.x + 550, lp.y, lp.z);
	T_Tick(2, 0.5);
	local m1 = v.fl[1].mv;
	h.ms.pos = Vector3(lp.x + 700, lp.y, lp.z);
	T_Tick(2, 0.5);
	HOST_Check(m1 == nil and v.fl[1].mv and HOST_Dist(v.fl[1].mv, Vector3(lp.x + 640, lp.y, lp.z)) < 0.01 and S_Logs(n0, "result=start") == 1,
		"the point renewed only after the mothership moved more than 100 units");
	MC_ClrOrd(v);
	MC_MsAt(1300);
	T_Tick(2, 0.5);
	HOST_Check(v.ap == 1 and v.fl[1].patrol == nil, "at 1300: still approaching (resume past 2 x 700)");
	MC_MsAt(1500);
	T_Tick(2, 0.5);
	HOST_Check(v.ap == nil and MC_Patrols(v) and S_Logs(n0, "event=approach flight=1 clan="..v.c.." distance=1500 result=resume") == 1
		and S_Logs(n0, "event=patrol flight=1 clan="..v.c.." points=5 result=resume") == 1, "past 1400: the patrol again, logged");
	-- Approach, then the meeting at 70 (the poll), the box, Cancel: the patrol resumes with the re-arm.
	MC_MsAt(600);
	T_Tick(2, 0.5);
	HOST_Check(v.ap == 1, "within 700 again: approaching");
	-- A scene (TRF_Quiet, __sys_SOS): no approach, the patrol again; after it the approach again.
	MC_ClrOrd(v);
	n0 = S_Mark();
	__sys_SOS = TRUE;
	T_Tick(4, 0.5);
	HOST_Check(v.ap == nil and MC_Patrols(v) and v.fl[1].mv == nil and S_Logs(n0, "event=approach") == 0
		and S_Logs(n0, "event=patrol flight=1 clan="..v.c.." points=5 result=resume") == 1, "scene: no approach, the patrol resumes once");
	__sys_SOS = FALSE;
	T_Tick(2, 0.5);
	HOST_Check(v.ap == 1 and v.fl[1].mv and S_Logs(n0, "event=approach flight=1 clan="..v.c.." distance=600 result=start") == 1, "scene over: approaching again");
	MC_ClrOrd(v);
	n0 = S_Mark();
	local b0 = getn(h.boxes);
	MC_MsAt(65);
	T_Tick(32, 0.5);
	HOST_Check(S_Logs(n0, "event=meet flight=1 clan="..v.c) == 1 and getn(h.boxes) == b0 + 1 and v.st == "offer", "the meeting at 70 fires after the approach; the box");
	HOST_Press("cancel");
	T_Tick(2, 0.5);
	HOST_Check(v.st == "wait" and v.ap == nil and MC_Patrols(v) and S_Logs(n0, "rearm=true") == 1 and S_Logs(n0, "event=patrol flight=1 clan="..v.c.." points=5 result=resume") == 1,
		"declined with the re-arm: the patrol resumes");
	MC_ClrOrd(v);
	MC_MsAt(400);
	T_Tick(40, 0.5);
	HOST_Check(v.ap == nil and v.fl[1].mv == nil, "no approach before the 60 s re-arm");
	T_Tick(84, 0.5);
	HOST_Check(v.ap == 1 and v.fl[1].mv, "after the re-arm: approaching again");
	MC_ClrOrd(v);
	n0 = S_Mark();
	MC_MsAt(20);
	T_Tick(32, 0.5);
	HOST_Press("cancel");
	T_Tick(2, 0.5);
	HOST_Check(v.st == "noh" and S_Logs(n0, "rearm=false") == 1 and v.ap == nil and MC_Patrols(v) and S_Logs(n0, "result=resume") == 1,
		"second Cancel: state noh, the patrol resumes");
	MC_ClrOrd(v);
	MC_MsAt(300);
	T_Tick(6, 0.5);
	HOST_Check(v.ap == nil and v.fl[1].mv == nil and v.fl[1].patrol == nil, "state noh: no approach");
	-- A hired pack escorts: no patrol, no approach.
	MC_Reset();
	MC_Put(4, {sg=1, met=0}); MC_Put(5, {sg=1, met=0});
	v = MC_Hire();
	HOST_Check(v.st == "hired" and v.fl[1].esc == h.ms, "hired: escort");
	MC_ClrOrd(v);
	n0 = S_Mark();
	MC_MsAt(500);
	T_Tick(6, 0.5);
	MC_MsAt(1500);
	T_Tick(6, 0.5);
	HOST_Check(v.st == "hired" and v.fl[1].patrol == nil and v.fl[1].mv == nil and v.fl[1].esc == h.ms and S_Logs(n0, "event=approach") == 0 and S_Logs(n0, "event=patrol") == 0,
		"hired: no patrol or approach orders");
	MC_Reset();
end;

-- h: meeting and offer: fee terms, box and page, decline and re-arm, short wallet, refusals, Legion gate, owe ---------

function T_MC_H()
	local h = HOST();
	MC_HBegin("6_1", 1);
	-- Fee terms (12 section 5; the mid example 12,600 and friends' 11,300).
	local f = {ch=700, lk=10, tk=1.5, pro=4, sk=1, rel=0, help=0, heat=0, hp=4, ek=1, cap=30000};
	local a = TRF_McFeeOf(f);
	f.rel = 1; local b = TRF_McFeeOf(f);
	f.rel = -3; local c = TRF_McFeeOf(f);
	f.rel = 0; f.help = 15; local d = TRF_McFeeOf(f);
	f.help = 0; f.heat = 5; local e = TRF_McFeeOf(f);
	f.heat = 7; local e7 = TRF_McFeeOf(f);
	f.heat = 0; f.hp = 2; local g = TRF_McFeeOf(f);
	f.hp = 4; f.ek = 1.5; local l = TRF_McFeeOf(f);
	f.ek = 1; f.ch = 5000; local cp = TRF_McFeeOf(f);
	f.ch = 700; f.sk = 1.25; local s3 = TRF_McFeeOf(f);
	local sh, bm = TRF_McShareOf(25, 10, 1, 4);
	HOST_Check(a == 12600 and b == 11300 and c == 13900 and d == 11300 and e == 18900 and e7 == 12600 and g == 15100 and l == 18900 and cp == 30000
		and s3 == 15800 and sh == 2500 and bm == 10000,
		"fee: base 12600, rel 1 -10 %, rel -3 counts as -1, FTU help -10 %, heat 5-6 x1.5, grief +20 % at hp 2, Legion x1.5, pay_cap, mc_size_k; share 2500, blood 10000");
	-- Box mode: meet, the offer line, the box 12 s later; Cancel, the re-arm after 60 s, OK.
	MC_Enter("gaoba");
	local v = TRF_McV();
	local m0, n0, b0 = getn(h.msgs), S_Mark(), getn(h.boxes);
	MC_Meet();
	HOST_Check(S_Logs(n0, "module=merc event=meet flight=1 clan="..v.c) == 1 and S_Logs(n0, "event=offer flight=1") == 1 and MC_Has(MC_Txt(m0), "guns, one price: "..v.fee)
		and getn(h.boxes) == b0 + 1 and HOST_Box().title == "#UI_Fmerc_confirm" and MC_Has(HOST_Box().text, TRF_McClanName(v.c).." will fly with you for "..v.fee.." cr"),
		"meeting at 70 units: the offer line, the box 12 s later (caption #UI_Fmerc_confirm, fee in the text)");
	HOST_Check(TRF_BoxHolder() == "merc" and h.box_nested == 0, "box lock merc held; no box inside a callback");
	HOST_Press("cancel");
	T_Tick(2, 0.5);
	HOST_Check(v.st == "wait" and TRF_BoxHolder() == nil and S_Logs(n0, "event=hire flight=1 clan="..v.c.." result=declined reason=dec rearm=true") == 1,
		"Cancel: declined, the lock freed, one re-arm");
	T_Tick(40, 0.5);
	HOST_Check(getn(h.boxes) == b0 + 1, "no second box before the 60 s re-arm");
	T_Tick(120, 0.5);
	HOST_Check(getn(h.boxes) == b0 + 2, "the second box after the re-arm (mothership still near)");
	local cr = h.credits;
	HOST_Press("ok");
	T_Tick(2, 0.5);
	HOST_Check(v.st == "hired" and h.credits == cr - v.fee and type(TRF.mc.h) == "string" and MC_Rel("TRF_Merc_1", PLAYER_GROUP) == RELATION_FRIEND
		and MC_Rel(PLAYER_GROUP, "TRF_Merc_1") == RELATION_FRIEND and v.fl[1].esc == h.ms and S_Screen(0, "#UI_Fmerc_joined"),
		"OK: the fee charged, the hire record, relations friend both ways, escort, #UI_Fmerc_joined");
	local hr = TRF_McH();
	HOST_Check(hr.c == v.c and hr.sys == V_Idx("gaoba") and hr.tr >= 598 and hr.fee == v.fee and hr.n == 4 and TRF.mc.hb == "1000100010001000" and hr.hj == 0 and hr.hg == floor(TRF.clock.gt),
		"hire record: full hull per mille, no jump counted, hg the game clock of the write");
	-- Short wallet; two offers per visit at most.
	MC_Reset();
	MC_Enter("gaoba");
	v = TRF_McV();
	h.credits = 100;
	MC_Meet();
	n0 = S_Mark();
	HOST_Press("ok");
	T_Tick(2, 0.5);
	HOST_Check(v.st == "wait" and S_Screen(0, "#UI_Fmerc_nojoined3") and S_Logs(n0, "result=short") >= 1 and h.credits == 100, "short wallet: #UI_Fmerc_nojoined3, nothing charged, re-armed");
	T_Tick(170, 0.5);
	HOST_Press("cancel");
	T_Tick(2, 0.5);
	HOST_Check(v.st == "noh" and S_Logs(n0, "rearm=false") == 1, "second Cancel: no third offer");
	-- Page mode: the offer as a dialog page (Accept, Decline), Esc is a decline.
	h.credits = 1000000;
	MC_Reset();
	MC_Dlg(1);
	MC_Enter("gaoba");
	v = TRF_McV();
	n0 = S_Mark();
	b0 = getn(h.boxes);
	MC_Meet();
	HOST_Check(h.dlg and h.dlg.name == "TRF_MercPg" and h.dlg.open and HOST_DlgVis() == "a_acc a_dec" and getn(h.boxes) == b0
		and HOST_DlgText() == "Mercenaries "..TRF_McClanName(v.c)..": "..TRF_McClanName(v.c).." will fly with you for "..v.fee.." cr, plus "..v.sh1.." cr per pirate downed. Hire them?"
		and HOST_DlgText("a_acc") == "- Hire them" and HOST_DlgText("a_dec") == "- Not now",
		"page: TRF_MercPg with the text set in the init, Accept and Decline shown, Close hidden");
	HOST_DlgEsc();
	T_Tick(4, 0.5);
	HOST_Check(v.st == "wait" and S_Logs(n0, "event=answer kind=offer answer=esc via=dialog") == 1 and TRF_BoxHolder() == nil, "Esc on the page: a decline, lock freed");
	T_Tick(170, 0.5);
	cr = h.credits;
	HOST_DlgPick("a_acc");
	T_Tick(2, 0.5);
	HOST_Check(v.st == "hired" and h.credits == cr - v.fee and S_Logs(n0, "event=talk kind=offer flight=1 clan="..v.c.." via=dialog result=shown") == 2, "Accept on the page: hired");
	MC_Dlg(nil);
	-- Refusals at the meeting: standing -2, heat 7, the office bloc, the Legion gate.
	MC_Reset();
	MC_Put(4, {met=0, rel=-2}); MC_Put(5, {at=1});
	MC_Enter("gaoba");
	m0, b0 = getn(h.msgs), getn(h.boxes);
	MC_Meet();
	HOST_Check(getn(h.boxes) == b0 and MC_Has(MC_Txt(m0), "We don't fly for the Wolves. Try the ") and TRF_McV().st == "noh", "rel -2: the refusal line, no box");
	MC_Reset();
	MC_Put(4, {rel=0}); MC_Put(5, {at=1});
	MC_Enter("gaoba");
	TRF.std.heat = 7;
	m0, b0 = getn(h.msgs), getn(h.boxes);
	MC_Meet();
	HOST_Check(getn(h.boxes) == b0 and MC_Has(MC_Txt(m0), "Not for any price."), "heat 7: every unit refuses");
	TRF.std.heat = 0;
	MC_Reset();
	MC_Put(5, {at=1});
	h.recruit = "morgenstern";
	MC_Enter("gaoba");
	m0, b0 = getn(h.msgs), getn(h.boxes);
	v = TRF_McV();
	MC_Meet();
	local blocref = TRF_McClan(v.c).b ~= 1;
	HOST_Check(blocref and getn(h.boxes) == b0 and MC_Has(MC_Txt(m0), "You fly with the Morgenstern."), "office unit of the other bloc: refusal");
	h.recruit = nil;
	-- Legion (clan 8): chapter 6 refusal; chapter 7 with six completed hires: the box with x1.5.
	MC_Reset();
	for i = 1, 12 do MC_Put(i, {met=0}); end;
	MC_Put(4, {at=1}); MC_Put(5, {at=1}); MC_Put(8, {at=MC_Slot("gaoba"), sg=1, rel=0});
	MC_Enter("gaoba");
	m0, b0 = getn(h.msgs), getn(h.boxes);
	v = TRF_McV();
	MC_Meet();
	HOST_Check(v.c == 8 and getn(h.boxes) == b0 and MC_Has(MC_Txt(m0), "Black Legion. We are out on patrol.") and MC_Has(MC_Txt(m0), "Come back with a record, Wolves."),
		"Legion in chapter 6: elite signature and the refusal line, no box");
	h.labels.CurrentQuest = "7_1";
	MC_Put(1, {jobs=6});
	MC_Reset();
	MC_Put(4, {at=1}); MC_Put(5, {at=1});
	MC_Put(8, {met=0, at=MC_Slot("gaoba")});
	MC_Enter("gaoba");
	b0 = getn(h.boxes);
	v = TRF_McV();
	MC_Meet();
	local base = TRF_McPrice(4, V_Idx("gaoba"), TRF_Mc_Fielded(8)).fee;
	HOST_Check(v.c == 8 and getn(h.boxes) == b0 + 1 and v.fee > base, "Legion in chapter 7 with 6 hires: the box, fee x1.5 ("..v.fee.." > "..base..")");
	HOST_Press("cancel");
	T_Tick(2, 0.5);
	MC_Put(1, {owe=500});
	HOST_Check(TRF_McRefuseWhy(8) == "legion" and TRF_McRefuseWhy(4) == nil, "Legion gate: no owe anywhere");
	MC_Put(1, {owe=0});
	-- Owe added to the price; the hire pays it and clears every clan's debt.
	h.labels.CurrentQuest = "6_1";
	MC_Reset();
	MC_Put(8, {at=7}); MC_Put(4, {at=MC_Slot("gaoba"), met=0}); MC_Put(5, {at=MC_Slot("gaoba"), met=0});
	TRF_Mc_Mark(3, "owe", 2000);
	MC_Enter("gaoba");
	v = TRF_McV();
	m0 = getn(h.msgs);
	MC_Meet();
	cr = h.credits;
	HOST_Check(MC_Has(MC_Txt(m0), "The Exchange keeps one book: 2000 cr") and MC_Has(HOST_Box().text, "for "..(v.fee + 2000).." cr"), "owe: the debt goes on the price");
	HOST_Press("ok");
	T_Tick(2, 0.5);
	HOST_Check(v.st == "hired" and h.credits == cr - v.fee - 2000 and TRF_McOweAll() == 0, "the hire pays the fee and the debt");
	MC_Reset();
end;

-- i: seeding, share deaths (bus, vanilla died triggers), losses, the 8.5 factor, betrayal, robbery and heat ends -----

function T_MC_I()
	local h = HOST();
	MC_HBegin("6_1", 1);
	local v = MC_Hire();
	HOST_Check(v.st == "hired", "hired");
	local n0, m0 = S_Mark(), getn(h.msgs);
	-- A raid whose fight opened (rd.ph): seeded at the step; unopened raids not.
	TRF.live.rd[5] = {id=9998, st="fight", ph=1, ns=4, pw=12};
	TRF.live.rd[6] = {id=9999, st="come", ns=3, pw=12};
	TRF_McStepBody();
	HOST_Check(v.seed["TRF_Raid_5"] == "raid" and not v.seed["TRF_Raid_6"] and MC_Rel("TRF_Merc_1", "TRF_Raid_5") == RELATION_WAR and MC_Rel("TRF_Raid_5", "TRF_Merc_1") == RELATION_WAR
		and S_Logs(n0, "module=merc event=seed flight=1 clan="..v.c.." group=TRF_Raid_5 reason=raid") == 1 and MC_Has(MC_Txt(m0), "break and engage!"),
		"raid with an open fight: seeded at war both ways, the engage line");
	-- Death bus: share deaths of seeded groups once per ship; the player-fire flag marks the raid.
	local s = CreateCarcass("Yari_pir1", Vector3(5000, 0, 5000), Vector3(0, 0, 1));
	TRF_Dead("raid", {g="TRF_Raid_5", n=5, j=1}, s, 1);
	TRF_Dead("raid", {g="TRF_Raid_5", n=5, j=1}, s, 1);
	TRF_Dead("raid", {g="TRF_Raid_5", n=5, j=2}, s, nil);
	TRF_Dead("raid", {g="TRF_Raid_6", n=6, j=1}, s, nil);
	HOST_Check(v.k == 2 and TRF_McMC().rk[5] == 1 and not TRF_McMC().rk[6], "death bus: two counted kills (one per ship, seeded groups only); raid 5 marked by player fire");
	-- 8.5 factor: 0.5 with a player kill, nothing without; rd.pk wins when trf_raid keeps it; no hire, no factor.
	TRF.live.rd[6].ph = 1;
	TRF_McStepBody();
	HOST_Check(TRF_Mc_RaidHelp(5, TRF.live.rd[5], 8000) == 0.5 and TRF_Mc_RaidHelp(6, TRF.live.rd[6], 8000) == "cancel"
		and TRF_Mc_RaidHelp(5, {pk=0}, 8000) == "cancel" and TRF_Mc_RaidHelp(6, {pk=1}, 8000) == 0.5 and TRF_Mc_RaidHelp(77, {}, 8000) == nil,
		"8.5 resolver: 0.5 after a player kill, cancel without, rd.pk first, nil for a raid without a hire");
	n0 = S_Mark();
	local got = TRF_RaidHelp(5, TRF.live.rd[5], 8000);
	HOST_Check(got == 4000 and S_Logs(n0, "module=merc event=help_factor raid_id=5 credits=8000 factor=0.5 result=half") == 1, "through trf_plumb TRF_RaidHelp: 8000 -> 4000");
	TRF.live.rd[5] = nil; TRF.live.rd[6] = nil;
	-- The captain's fight opened (trf_captain visit op): seeded.
	local cp = TRF_CapCP();
	cp.v = {slot=3, cg=1, op=1, st="raid"};
	T_Tick(2, 0.5);
	HOST_Check(v.seed["TRF_Cap_3"] == "captain" and MC_Rel("TRF_Merc_1", "TRF_Cap_3") == RELATION_WAR, "captain's open fight: seeded");
	TRF_Dead("cap", {g="TRF_Cap_3", n=3, j=1}, s, nil);
	HOST_Check(v.k == 3, "the captain's death counts");
	cp.v = nil;
	-- Vanilla pirates at war with the player: seeded, their ships get died triggers (dedup), group_Pirate_money only at war.
	local fl = PiratesGroup_1:CreateFlight("flight_pir_a");
	local p1 = CreateCarcass("Yari_pir1", Vector3(6000, 0, 6000), Vector3(0, 0, 1));
	p1:AssignPilot(CreatePilot("Pirate")); fl:AddShip(p1);
	ship_pir_a_1 = p1;
	-- As vanilla (OutOfMission.script 388): the global P_Group holds the group named group_Pirate_money.
	P_Group = HOST_Group("group_Pirate_money", "Pirates");
	SetGroupRelation("PiratesGroup_1", PLAYER_GROUP, RELATION_WAR);
	T_Tick(2, 0.5);
	HOST_Check(v.seed["PiratesGroup_1"] == "vanilla" and not v.seed["group_Pirate_money"] and HOST_Count("died", "TRF_McVDied(1,1,") == 1, "vanilla group at war: seeded, its ship armed once");
	T_Tick(24, 0.5);
	HOST_Check(HOST_Count("died", "TRF_McVDied(") == 1, "the rescan arms no ship twice");
	p1.alive = nil;
	HOST_Fire("died", "TRF_McVDied(1,1,");
	HOST_Check(v.k == 4, "vanilla ship died: counted");
	SetGroupRelation("group_Pirate_money", PLAYER_GROUP, RELATION_WAR);
	T_Tick(2, 0.5);
	HOST_Check(v.seed["group_Pirate_money"] == "vanilla", "extortion group seeded once it is at war");
	ship_pir_a_1 = nil; P_Group = nil;
	-- A pack ship lost: hp -1, fo -3, blood money; the hire record keeps k and lo.
	local hp0, fo0 = TRF_McDig(v.c, "hp"), TRF_McDig(v.c, "fo");
	MC_Kill(2);
	local hr = TRF_McH();
	HOST_Check(v.lo == 1 and TRF_McDig(v.c, "hp") == hp0 - 1 and TRF_McDig(v.c, "fo") == fo0 - 3 and hr.k == 4 and hr.lo == 1 and strsub(TRF.mc.hb, 5, 8) == "0000",
		"pack ship lost: hp -1, fo -3, lo 1 in the record, hull 0");
	-- Half the pack lost: settled at once, leaves.
	h.credits = 1000000;
	local c = v.c;
	MC_Kill(3);
	n0 = S_Mark();
	T_Tick(2, 0.5);
	local s0, b0, t0 = TRF_McSettleOf(4, v.sh1, 2, v.bm);
	HOST_Check(v.st == "leave" and TRF.mc.h == nil and S_Logs(n0, "event=settle flight=1 clan="..c.." share="..s0.." blood="..b0.." total="..t0.." taken="..t0.." result=paid reason=half") == 1
		and h.credits == 1000000 - t0 and TRF_McT(c).jobs == 1, "half the pack lost: settled directly (share 4 x sh + blood 2 x bm), completed, leaves");
	-- Betrayal by counted fire (merc_war 0): rel -3, bk 1, bloc-mates -2, grudge 2, heat +1, blacklist, the pack leaves.
	MC_Set("merc_war", 0);
	MC_Enter("heos", 0);
	MC_Put(4, {met=0, rel=1}); MC_Put(5, {met=0, rel=1});
	v = MC_Hire();
	c = v.c;
	local mate = 4;
	if c == 4 then mate = 2; end;
	local rm, heat0, J = TRF_McRel(mate), TRF.std.heat, TRF_Jumps();
	n0 = S_Mark();
	MC_Hits(1, 5);
	HOST_Check(v.bt == 1 and TRF_McRel(c) == -3 and TRF_McDig(c, "bk") == 1 and TRF_McDig(c, "g") == 2 and TRF_McRel(mate) == max(-3, rm - 2) and TRF.std.heat == heat0 + 1
		and TRF.mc.x == J + 30 and TRF.mc.h == nil and (v.st == "leave" or v.st == "gone") and S_Logs(n0, "event=betray flight=1 clan="..c.." result=leave reason=fire") == 1,
		"counted fire: betrayal standing, blacklist 30 jumps, hire over, the pack leaves (merc_war 0)");
	HOST_Check(MC_Rel("TRF_Merc_1", PLAYER_GROUP) ~= RELATION_WAR, "merc_war 0: no group war");
	MC_Enter("heos", 0);
	HOST_Check(MC_Has(MC_Txt(), "struck the Wolves off its books") or S_Logs(n0, "event=arrival_line owner=merc") >= 1, "next entry: the blacklist note");
	n0 = S_Mark();
	MC_Enter("gaoba", 0);
	HOST_Check(S_Logs(n0, "reason=black") == 1, "blacklisted: no roll");
	-- merc_war 1 (the default): betrayal by a kill after a hit: grudge +3, war, attack, break-off at half.
	TRF.mc.x = nil;
	MC_Set("merc_war", nil);
	MC_Enter("heos", 0);
	MC_Put(4, {met=0, rel=0, bk=0, g=0}); MC_Put(5, {met=0, rel=0, bk=0, g=0});
	v = MC_Hire();
	c = v.c;
	HOST_Fire("attack", "TRF_McHit(1,1,");
	n0 = S_Mark();
	MC_Kill(1);
	HOST_Check(v.bt == 1 and TRF_McDig(c, "g") == 5 and v.st == "war" and MC_Rel("TRF_Merc_1", PLAYER_GROUP) == RELATION_WAR and v.fl[1].att == h.ms
		and S_Logs(n0, "result=war reason=kill") == 1, "kill after a hit (merc_war 1): grudge 3 + 2, group war, attack on the mothership");
	MC_Kill(2);
	T_Tick(2, 0.5);
	HOST_Check(v.st == "leave", "half down: the pack breaks off");
	MC_Set("merc_war", nil);
	-- A counted attack on a trader ends the hire (rel -1, no refund); heat 7 too.
	TRF.mc.x = nil;
	MC_Enter("heos", 0);
	MC_Put(4, {met=0, rel=0}); MC_Put(5, {met=0, rel=0});
	v = MC_Hire();
	c = v.c;
	TRF.live.stat.attack_counted = (TRF.live.stat.attack_counted or 0) + 1;
	n0, m0 = S_Mark(), getn(h.msgs);
	T_Tick(2, 0.5);
	HOST_Check(v.st == "leave" and TRF_McRel(c) == -1 and TRF.mc.h == nil and S_Logs(n0, "result=robbery reason=attack") == 1 and MC_Has(MC_Txt(m0), "we don't rob them. Contract's off."),
		"counted attack on a trader: rel -1, settled, no completion, leaves");
	MC_Enter("heos", 0);
	MC_Put(4, {met=0, rel=0}); MC_Put(5, {met=0, rel=0});
	v = MC_Hire();
	TRF.std.heat = 7;
	n0 = S_Mark();
	T_Tick(2, 0.5);
	HOST_Check(v.st == "leave" and S_Logs(n0, "result=robbery reason=heat") == 1, "heat 7: the hire ends");
	TRF.std.heat = 0;
	MC_Enter("heos", 0);
end;

-- j: time out, grace, extension, settlement (pay, short, refuse), across jumps, suspension, pre-mission, collection -----

function T_MC_J()
	local h = HOST();
	MC_HBegin("6_1", 1);
	-- Pure: settlement, completion, the refusal roll.
	local s, b, t = TRF_McSettleOf(3, 2500, 1, 10000);
	HOST_Check(s == 7500 and b == 10000 and t == 17500 and TRF_McDoneOf(300, 600, 0) and TRF_McDoneOf(10, 600, 1) and not TRF_McDoneOf(299, 600, 0),
		"settlement k x sh + lo x bm; completion after half the time or a kill");
	local r1 = TRF_McRollOf(10, 100, 0.5, 50);
	local r2 = TRF_McRollOf(100, 10, 1, 50);
	HOST_Check(r1 == "leave" and r2 == "attack", "refusal roll: a weak pack leaves, a strong one attacks");
	-- Across a jump: the wing is deleted before the jump and rebuilt at the arrival with its hull after the repair.
	local v = MC_Hire();
	local c = v.c;
	v.sh[2].hp = 500;
	MC_Kill(4);
	local n0 = S_Mark();
	T_Jump("heos");
	local v2 = TRF_McV();
	local sh = MC_Ships(1);
	HOST_Check(S_Logs(n0, "module=merc event=jump clan="..c.." destination=heos") == 1 and S_Logs(n0, "result=follow") == 1 and v2 and v2.st == "hired" and v2.c == c
		and getn(sh) == 3 and TRF_McH().sys == V_Idx("heos") and h.objs["trf_merc_1_4"] == nil,
		"jump: the wing follows, rebuilt at the arrival from the record (3 of 4, the lost one not)");
	HOST_Check(v2.sh[2].hp == 650 and v2.sh[1].hp == 1000 and S_Logs(n0, "heal=150 hull=1000065010000000 result=rebuilt via=arrival") == 1,
		"one jump with an immediate rebuild: 500 + mc_heal_j 150 per mille, SetHP 650 (HP "..tostring(v2.sh[2].hp)..")");
	HOST_Check(TRF.mc.hb == "1000065010000000" and TRF_McH().hj == 0 and TRF_McH().hg == floor(TRF.clock.gt), "the record written at the rebuild: hull, hj 0, hg now");
	HOST_Check(v2.fl[1].esc == h.ms and MC_Rel("TRF_Merc_1", PLAYER_GROUP) == RELATION_FRIEND and TRF.live.esc == "merc" and S_Logs(n0, "event=follow flight=1 clan="..c) == 1
		and S_Logs(n0, "event=arrival_line owner=merc") >= 1, "rebuilt wing escorts the mothership, friend, escort slot, the arrival line");
	HOST_Check(S_Logs(n0, "module=merc event=roll") == 0, "no hire offer rolled while the wing travels");
	-- Suspension: the ship cap denies the rebuild; the time stands, the next arrival resumes.
	local tr0 = TRF_McH().tr;
	MC_Tune("mc_ships", 1);
	n0 = S_Mark();
	T_Jump("gaoba");
	HOST_Check(TRF_McV().st == "susp" and getn(MC_Ships(1)) == 0 and S_Logs(n0, "event=suspend clan="..c.." system=gaoba") == 1 and S_Logs(n0, "reason=cap:merc_cap") == 1,
		"suspended: no wing here, the note");
	T_Tick(40, 0.5);
	HOST_Check(TRF_McH().tr == tr0 and TRF.live.esc == nil and TRF_McH().hj == 1 and TRF.mc.hb == "1000065010000000",
		"suspended: tr frozen, escort slot free, the hull and the jump count kept");
	MC_Tune("mc_ships", 14);
	local sg = floor(TRF.clock.gt) - TRF_McH().hg;
	n0 = S_Mark();
	T_Jump("heos");
	v2 = TRF_McV();
	HOST_Check(v2.st == "hired" and getn(MC_Ships(1)) == 3, "resumed at the next arrival");
	HOST_Check(sg >= 19 and sg <= 21 and S_Logs(n0, "heal="..(300 + sg).." hull=1000"..format("%04d", 950 + sg).."10000000 result=rebuilt") == 1 and v2.sh[2].hp == 950 + sg,
		"repair after a suspended visit: 2 jumps x 150 plus "..sg.." suspended s x 1 per mille; the lost slot stays 0");
	-- SetHP fallback: a ship below 550 per mille after the repair sits out when SetHP fails (300 + 150); 400 + 150 flies
	-- at full HP; 950 + sg + 150 is capped at 1000.
	v2.sh[1].hp = 300;
	v2.sh[3].hp = 400;
	local cc = CreateCarcass;
	CreateCarcass = function(a, b, d) local x = %cc(a, b, d); if x then x.SetHP = nil; end; return x; end;
	n0 = S_Mark();
	T_Jump("gaoba");
	CreateCarcass = cc;
	v2 = TRF_McV();
	HOST_Check(getn(MC_Ships(1)) == 2 and S_Logs(n0, "sit_out=1") == 1 and S_Logs(n0, "heal=150 hull=0450100005500000 result=rebuilt") == 1
		and v2.gone[1] == 1 and v2.sh[2].hp == 1000 and v2.sh[3].hp == 1000 and TRF.mc.hb == "0000100010000000",
		"without SetHP: 450 per mille sits out, 550 flies at full HP, the cap at 1000, the lost slot 0");
	-- Time out: no HP fall -> the extension (box mode); Extend charges 0.75 x fee and adds 600 s.
	v = TRF_McV();
	v.tr = 1;
	local b0, cr = getn(h.boxes), h.credits;
	T_Tick(6, 0.5);
	local fx = TRF_McR100(0.75 * v.fee);
	HOST_Check(v.st == "ask" and getn(h.boxes) == b0 + 1 and HOST_Box().text == "Time's up, Wolves. Another ten minutes for "..fx.." cr?", "time out: the extension question");
	HOST_Press("ok");
	T_Tick(2, 0.5);
	HOST_Check(v.st == "hired" and h.credits == cr - fx and v.tr > 590, "Extend: charged at once, tr + 600");
	-- Grace: HP fell in the last 30 s.
	v.tr = 3;
	v.sh[2].hp = v.sh[2].hp - 100;
	n0 = S_Mark();
	T_Tick(8, 0.5);
	HOST_Check(S_Logs(n0, "event=grace flight=1") == 1 and v.st == "hired" and v.tr > 50, "HP fell in the last 30 s: 60 s grace");
	v.tr = 1;
	T_Tick(70, 0.5);
	HOST_Check(v.st == "ask", "after the grace: the question");
	-- Extension with a short wallet -> the settlement; Pay: charged, completed, the share line, the pack leaves.
	v.k = 2;
	h.credits = 10;
	HOST_Press("ok");
	T_Tick(2, 0.5);
	local s1, b1, t1 = TRF_McSettleOf(2, v.sh1, v.lo, v.bm);
	HOST_Check(getn(h.boxes) == b0 + 3 and HOST_Box().text == "Share for 2 kills "..s1.." cr, blood money for "..v.lo.." of ours "..b1.." cr: "..t1.." cr.", "short at Extend: the settlement page");
	h.credits = 1000000;
	local rel0, jobs0, fo0 = TRF_McRel(c), TRF_McT(c).jobs, TRF_McDig(c, "fo");
	n0 = S_Mark();
	HOST_Press("ok");
	T_Tick(2, 0.5);
	HOST_Check(h.credits == 1000000 - t1 and TRF.mc.h == nil and (v.st == "leave" or v.st == "gone") and TRF_McRel(c) == min(3, rel0 + 1) and TRF_McT(c).jobs == jobs0 + 1
		and S_Logs(n0, "event=fortune clan="..c.." change=3") == 1 and S_Screen(0, TRF_McClanName(c)..": prize share for 2 pirates, "..t1.." credits."),
		"Pay: charged, rel +1, jobs +1, fortune +3, the share line, leave");
	T_Tick(4, 0.5);
	HOST_Check(v.st == "gone" and getn(MC_Ships(1)) == 0, "deleted at the portal");
	-- Pay short: the rest to owe with rel -1.
	MC_Enter("heos", 0);
	MC_Put(4, {met=0, rel=0}); MC_Put(5, {met=0, rel=0});
	v = MC_Hire(); c = v.c;
	v.k = 1; v.tr = 1;
	T_Tick(4, 0.5);
	HOST_Press("cancel");
	T_Tick(2, 0.5);
	local s2, b2, t2 = TRF_McSettleOf(1, v.sh1, 0, v.bm);
	h.credits = 1000;
	HOST_Press("ok");
	T_Tick(2, 0.5);
	HOST_Check(h.credits == 0 and TRF_McT(c).owe == t2 - 1000 and TRF_McRel(c) == 0, "Pay short: the wallet emptied, the rest owe, rel +1 - 1");
	h.credits = 1000000;
	-- Refuse with merc_war 0: the roll's attack degrades to leave; owe, rel -1.
	MC_Set("merc_war", 0);
	TRF_Mc_Mark(c, "owe", 0);
	MC_Enter("heos", 0);
	MC_Put(4, {met=0, rel=0}); MC_Put(5, {met=0, rel=0});
	v = MC_Hire(); c = v.c;
	v.k = 1; v.tr = 1;
	T_Tick(4, 0.5);
	HOST_Press("cancel");
	T_Tick(2, 0.5);
	local co = TRF_Rd_ComplyOf;
	TRF_Rd_ComplyOf = function(st, sr, br) return 0; end;
	n0 = S_Mark();
	HOST_Press("cancel");
	T_Tick(2, 0.5);
	HOST_Check(S_Logs(n0, "event=refuse flight=1 clan="..c.." kind=settle") == 1 and S_Logs(n0, "result=attack war=false") == 1 and TRF_McT(c).owe == v.sh1
		and TRF_McRel(c) == -1 and (v.st == "leave" or v.st == "gone"), "Refuse (merc_war 0): attack degrades to leave, the total owe, rel -1");
	-- Refuse with merc_war 1 and the roll's attack: betrayal consequences, group war.
	TRF_Mc_Mark(c, "owe", 0); TRF_Mc_Mark(c, "rel", 0);
	MC_Set("merc_war", nil);
	MC_Enter("heos", 0);
	MC_Put(4, {met=0, rel=0, bk=0}); MC_Put(5, {met=0, rel=0, bk=0});
	v = MC_Hire(); c = v.c;
	v.k = 1; v.tr = 1;
	T_Tick(4, 0.5);
	HOST_Press("cancel");
	T_Tick(2, 0.5);
	HOST_Press("cancel");
	T_Tick(2, 0.5);
	HOST_Check(v.st == "war" and TRF_McRel(c) == -3 and TRF_McDig(c, "bk") == 1 and MC_Rel("TRF_Merc_1", PLAYER_GROUP) == RELATION_WAR, "Refuse (merc_war 1) and attack: betrayal standing, group war");
	TRF_Rd_ComplyOf = co;
	MC_Set("merc_war", nil);
	TRF.mc.x = nil;
	-- Pre-mission: the mission signal turns on -> the line and the settlement page; the hire ends.
	MC_Enter("heos", 0);
	MC_Put(4, {met=0, rel=0, bk=0}); MC_Put(5, {met=0, rel=0, bk=0});
	v = MC_Hire(); c = v.c;
	v.k = 1;
	local m0 = getn(h.msgs);
	n0 = S_Mark();
	h.qs = TRUE;
	T_Tick(4, 0.5);
	HOST_Check(S_Logs(n0, "event=premission flight=1 clan="..c.." reason=signal") == 1 and MC_Has(MC_Txt(m0), "We don't fly into that, Wolves. Settle up first.")
		and MC_Has(HOST_Box().text, "Share for 1 kills"), "mission signal on: the line, the settlement page");
	HOST_Press("ok");
	T_Tick(2, 0.5);
	HOST_Check(TRF.mc.h == nil and (v.st == "leave" or v.st == "gone"), "settled before the mission: the hire ends");
	h.qs = FALSE;
	-- Pre-mission by a portal: avalon's portal to Kassilia (excluded) within 300 units.
	MC_Enter("heos", 0);
	MC_Put(4, {met=0}); MC_Put(5, {met=0});
	v = MC_Hire(); c = v.c;
	v.k = 1;
	T_Jump("avalon");
	v = TRF_McV();
	local m = TRF_Map();
	local ps = m.sys[V_Idx("avalon")].portals;
	local pk = nil;
	for i = 1, getn(ps) do if strlower(ps[i].to) == "kassilia" then pk = ps[i]; end; end;
	h.ms.pos = Vector3(pk.x + 100, pk.y or 0, pk.z or 0);
	n0 = S_Mark();
	T_Tick(4, 0.5);
	HOST_Check(v.st == "ask" and S_Logs(n0, "reason=portal") == 1, "near a portal into an excluded system: the settlement page");
	HOST_Press("ok");
	T_Tick(2, 0.5);
	-- A jump without settling (the jump into Kassilia while the hire runs): the total owe without rel loss, the collection
	-- flag, the note at the next entry, the collection page at the next meeting before the offer.
	MC_Enter("heos", 0);
	MC_Put(4, {met=0}); MC_Put(5, {met=0});
	v = MC_Hire(); c = v.c;
	v.k = 2;
	T_Tick(2, 0.5);
	local sk, bk2, tk = TRF_McSettleOf(2, v.sh1, 0, v.bm);
	local relj, ow0 = TRF_McRel(c), TRF_McT(c).owe;
	n0 = S_Mark();
	T_Jump("kassilia");
	local o = TRF_McO();
	HOST_Check(TRF.mc.h == nil and o and o.c == c and o.s == V_Idx("gaoba") and TRF_McT(c).owe == ow0 + tk and TRF_McRel(c) == relj + 1
		and S_Logs(n0, "event=jump clan="..c.." destination=kassilia total="..tk.." result=owe") == 1, "jump the wing cannot follow: owe, collection flag, completion, no rel loss");
	HOST_Check(S_Logs(n0, "event=note clan="..c.." kind=2") == 1 and getn(MC_Ships(1)) == 0, "the debt note at the next entry");
	MC_Enter("heos", 0);
	MC_Put(4, {met=0}); MC_Put(5, {met=0});
	MC_Enter("gaoba");
	v = TRF_McV();
	b0 = getn(h.boxes);
	MC_Meet();
	HOST_Check(getn(h.boxes) == b0 + 1 and HOST_Box().text == "You left Gaoba owing the "..TRF_McClanName(c).." "..TRF_McT(c).owe.." cr.", "collection page before any offer");
	cr = h.credits;
	local owe1 = TRF_McT(c).owe;
	HOST_Press("ok");
	T_Tick(30, 0.5);
	HOST_Check(h.credits == cr - owe1 and TRF_McT(c).owe == 0 and TRF_McO() == nil and getn(h.boxes) == b0 + 2 and MC_Has(HOST_Box().text, "will fly with you for"),
		"Pay: the debt charged, the flag cleared, the offer follows");
	-- The offer page of a flight deleted while it is open: the conversation dropped, the answer charges nothing.
	cr = h.credits;
	HOST_Check(type(TRF_McMC().cv) == "table", "offer page open");
	TRF_McDelAll(v, "test");
	HOST_Press("ok");
	T_Tick(2, 0.5);
	HOST_Check(TRF_McMC().cv == nil and h.credits == cr and v.st == "gone" and TRF.mc.h == nil, "flight deleted with its page open: Accept charges nothing");
	-- A leaving ship the engine removed at the portal (no died event): left, no loss; the last one: gone at the portal.
	MC_Reset("heos");
	v = MC_Hire(); c = v.c;
	local hp0 = TRF_McDig(c, "hp");
	TRF_McLeave(v, "test", nil);
	v.sh[1].alive = nil;
	n0 = S_Mark();
	T_Tick(2, 0.5);
	HOST_Check(v.gone[1] == 1 and not v.dead[1] and TRF_McDig(c, "hp") == hp0 and S_Logs(n0, "module=merc event=loss ") == 0,
		"leaving ship gone without its died event: left, no loss");
	for j = 2, v.nj do if v.sh[j] then v.sh[j].alive = nil; end; end;
	T_Tick(2, 0.5);
	HOST_Check(v.st == "gone" and S_Logs(n0, "event=gone flight="..v.n.." clan="..c) == 1 and S_Logs(n0, "reason=portal") == 1, "the last leaving ship gone: the flight ends at the portal");
	-- A jump after the pre-mission line, unsettled, into a system the wing could follow: owe and the flag, no follow.
	MC_Reset("heos");
	v = MC_Hire(); c = v.c;
	v.k = 1;
	T_Jump("avalon");
	v = TRF_McV();
	h.ms.pos = Vector3(pk.x + 100, pk.y or 0, pk.z or 0);
	T_Tick(4, 0.5);
	HOST_Check(v.st == "ask" and v.pm == 1, "pre-mission line by the portal");
	local ow1 = TRF_McT(c).owe;
	n0 = S_Mark();
	T_Jump("heos");
	o = TRF_McO();
	HOST_Check(TRF.mc.h == nil and o and o.c == c and TRF_McT(c).owe > ow1 and S_Logs(n0, "event=jump clan="..c.." destination=heos total=") == 1
		and S_Logs(n0, "event=follow ") == 0, "a jump after the pre-mission line: owe and the collection flag, the wing does not follow");
	HOST_Press("ok");
	T_Tick(2, 0.5);
	HOST_Check(TRF.mc.h == nil and TRF_McMC().cv == nil, "the stale settlement box after the jump: ignored");
	MC_Put(c, {owe=0}); TRF.mc.o = nil;
	-- OutMissionEscort running at an arrival: the hire suspended (S9), resumed at the next arrival without it.
	MC_Reset("heos");
	v = MC_Hire(); c = v.c;
	h.labels.OutMissionEscort = "m18c_escort";
	n0 = S_Mark();
	T_Jump("heos");
	HOST_Check(TRF_McV().st == "susp" and S_Logs(n0, "event=suspend clan="..c.." system=heos") == 1 and S_Logs(n0, "reason=escort_mission") == 1, "escort mission at the arrival: suspended");
	h.labels.OutMissionEscort = nil;
	T_Jump("gaoba");
	HOST_Check(TRF_McV().st == "hired" and getn(MC_Ships(1)) > 0, "resumed without the escort mission");
	-- 8.5: a raid ship the player killed without a hire open still marks the raid.
	MC_Reset("heos");
	local s2 = CreateCarcass("Yari_pir1", Vector3(5000, 0, 5000), Vector3(0, 0, 1));
	TRF_McMC().rh = {}; TRF_McMC().rk = {};
	TRF_McMC().rh[7] = 1;
	TRF_Dead("raid", {g="TRF_Raid_7", n=7, j=1}, s2, 1);
	HOST_Check(TRF_McMC().rk[7] == 1 and TRF_Mc_RaidHelp(7, {}, 8000) == 0.5, "raid kill by the player without a hire: the raid marked, the factor 0.5");
	-- A record without a live hull at an arrival (every ship lost before the jump): the hire ends as owe, no suspension.
	MC_Reset("heos");
	v = MC_Hire(); c = v.c;
	v.k = 1;
	for j = 1, v.nj do if v.sh[j] then v.sh[j].alive = nil; end; end;
	TRF_McWriteH(v);
	local ow2 = TRF_McT(c).owe;
	n0 = S_Mark();
	T_Jump("heos");
	HOST_Check(TRF.mc.h == nil and TRF_McV() == nil and TRF_McT(c).owe == ow2 + v.sh1
		and S_Logs(n0, "event=follow clan="..c.." total="..v.sh1.." result=ended reason=ships") == 1 and S_Logs(n0, "event=suspend") == 0,
		"arrival with no live hull: the hire ends with the total as owe, nothing suspended");
	HOST_Check(S_Logs(n0, "event=follow flight=") == 0, "no rebuild and no repair without a live hull");
	MC_Put(c, {owe=0});
	-- Every pack ship lost on screen: the flight ends and the escort slot is free again.
	MC_Reset("heos");
	v = MC_Hire(); c = v.c;
	for j = 1, v.nj do if v.sh[j] then MC_Kill(j); end; end;
	T_Tick(2, 0.5);
	HOST_Check(v.st == "gone" and TRF.mc.h == nil and TRF.live.esc == nil, "every ship lost: the flight gone, the hire settled, the escort slot freed");
	-- A zero price (c_hire 0) is not a short wallet: the hire proceeds without a charge.
	MC_Reset("heos");
	MC_Tune("c_hire", 0);
	local cr0 = h.credits;
	v = MC_Hire(); c = v.c;
	HOST_Check(v.st == "hired" and v.fee == 0 and h.credits == cr0, "c_hire 0: hired at no charge");
	MC_Tune("c_hire", 700);
	MC_Enter("heos", 0);
end;

-- k: load (adopt, rebuild, wait, unhired), wind-down refund, board line, legend, dump, save bound ----------------------

function T_MC_K()
	local h = HOST();
	MC_HBegin("6_1", 1);
	local v = MC_Hire();
	local c = v.c;
	-- Load in the same system: the ships found through the handle globals and re-adopted.
	TRF.live.esc = "merc";
	local n0 = S_Mark();
	T_SaveLoad();
	local v2 = TRF_McV();
	HOST_Check(v2 and v2.st == "hired" and v2.c == c and S_Logs(n0, "module=merc event=load flight=1 clan="..c.." ship_count=4") == 1 and S_Logs(n0, "result=adopt") == 1
		and TRF.live.esc == "merc" and HOST_Count("died", "TRF_McDied(1,1,"..TRF.gen..")--") == 1, "load: re-adopted through the handle globals, triggers with the new gen, escort slot again");
	HOST_Check(S_Logs(n0, "module=merc event=roll") == 0 and S_Logs(n0, "module=plumb event=orphan") == 0, "load: no re-roll; the orphan scan keeps the Merc labels");
	-- A damaged ship re-adopted after a load: hp0 from the saved per mille.
	v2.sh[2].hp = 600;
	T_Tick(3, 0.5);
	HOST_Check(strsub(TRF.mc.hb, 5, 8) == "0600", "the 1 s step writes the hull per mille");
	T_SaveLoad();
	v2 = TRF_McV();
	HOST_Check(v2 and v2.st == "hired" and v2.hp0[2] == 1000 and v2.sh[2].hp == 600, "load: re-adopted, hp0 1000 from HP 600 at 600 per mille");
	-- tr clamped to merc_hire_s + 60.
	local hr = TRF_McH(); hr.tr = 5000; TRF.mc.h = TRF_TpPackK(hr, TRF_McHKeys());
	T_SaveLoad();
	HOST_Check(TRF_McH().tr == 660, "load: tr clamped to 660");
	-- A load in another system than the wing's (a save made during a suspended visit): the rebuild there.
	-- The save was made 100 s into the suspended visit: those seconds repair the hull at the rebuild.
	hr = TRF_McH(); hr.sys = V_Idx("heos"); hr.hg = floor(TRF.clock.gt) - 100; TRF.mc.h = TRF_TpPackK(hr, TRF_McHKeys());
	TRF.mc.hb = "1000080010001000";
	n0 = S_Mark();
	T_SaveLoad();
	HOST_Check(S_Logs(n0, "module=merc event=load clan="..c.." result=rebuilt reason=other_system") == 1 and S_Logs(n0, "result=rebuilt via=load") == 1
		and TRF_McV().st == "hired" and getn(MC_Ships(1)) == 4 and TRF_McH().sys == V_Idx("gaoba"), "load in another system: the wing rebuilt here");
	HOST_Check(S_Logs(n0, "heal=100 hull=1000090010001000 result=rebuilt via=load") == 1 and TRF_McV().sh[2].hp == 900,
		"load in another system: 100 suspended s repair 100 per mille");
	-- No handle globals (NPC flights not in the save): rebuilt from the record; the old labelled ships deleted.
	n0 = S_Mark();
	T_SaveLoad(function() for j = 1, 6 do setglobal("TRF_ship_trf_merc_1_"..j, nil); end; end);
	HOST_Check(S_Logs(n0, "module=merc event=load result=rebuilt") == 1 and getn(MC_Ships(1)) == 4 and TRF_McV().st == "hired", "load without handles: rebuilt");
	HOST_Check(S_Logs(n0, "heal=0 hull=1000090010001000 result=rebuilt via=load") == 1 and TRF_McV().sh[2].hp == 900,
		"load in the hire's own system: no jump, no suspended second, no repair");
	-- Handles of dead objects: the wait, then the rebuild.
	n0 = S_Mark();
	T_SaveLoad(function() for j = 1, 6 do local o = getglobal("TRF_ship_trf_merc_1_"..j); if o then o.alive = nil; end; end; end);
	HOST_Check(S_Logs(n0, "event=load result=") == 0, "load: handles not alive yet: waiting");
	T_Tick(24, 0.5);
	HOST_Check(S_Logs(n0, "module=merc event=load result=rebuilt try_count=") == 1 and getn(MC_Ships(1)) == 4, "after load_wait: rebuilt");
	-- Wind-down before half the time and no kill: 50 % refund, direct settlement, leave.
	v = TRF_McV();
	local cr = h.credits;
	n0 = S_Mark();
	TRF_Mc_WindDown();
	HOST_Check(h.credits == cr + floor(v.fee / 2) and S_Logs(n0, "event=refund flight=1 clan="..c.." amount="..floor(v.fee / 2)) == 1 and v.st == "leave" and TRF.mc.h == nil,
		"wind-down: half the fee back, settled, leaves");
	-- An unhired pack at a load is deleted (no box again).
	T_Jump("heos");
	MC_Put(4, {met=0}); MC_Put(5, {met=0});
	MC_Enter("gaoba");
	local sh = MC_Ships(1);
	n0 = S_Mark();
	T_SaveLoad();
	HOST_Check(not sh[1].alive and S_Logs(n0, "module=merc event=load deleted_count=4 result=delete") == 1 and TRF_McV() == nil and getglobal("TRF_ship_trf_merc_1_1") == nil,
		"load: the unhired pack deleted, its handle globals cleared");
	-- Board line at the patrol dock (once per visit): a free clan working a region; chapter 3: a Legion legend line.
	T_Jump("heos");
	local d1 = MC_Dock();
	local d2 = MC_Dock();
	HOST_Check(MC_Has(d1, "Mercenaries for hire: ") and MC_Has(d1, " lanes.") and not MC_Has(d2, "Mercenaries for hire"), "patrol board line, once per visit");
	MC_Set("merc_board", 0);
	T_Jump("gaoba");
	HOST_Check(not MC_Has(MC_Dock(), "Mercenaries for hire"), "merc_board 0: no line");
	MC_Set("merc_board", nil);
	h.labels.CurrentQuest = "3_1";
	local got, bad = 0, nil;
	for L = 1, 30 do
		TRF.clock.legs = 100 + L;
		local t = TRF_McLegend(V_Idx("heos"), 3, 17);
		if t then got = got + 1; if MC_Has(t, "Torr") then bad = 1; end; end;
	end;
	local t4 = nil;
	for L = 1, 30 do if not t4 then TRF.clock.legs = 200 + L; t4 = TRF_McLegend(V_Idx("heos"), 4, 17); end; end;
	MC_Set("mc_el_c", 0);
	local t0 = TRF_McLegend(V_Idx("heos"), 3, 17);
	MC_Set("mc_el_c", nil);
	HOST_Check(got > 0 and got < 30 and not bad and t4 == "Black Legion winters in the Torr lanes. They don't take cheap contracts." and t0 == nil
		and TRF_McLegend(V_Idx("heos"), 5, 17) == nil, "legend: chapters 1-3 without a name, chapter 4 Torr, none with mc_el_c 0 or from chapter 5");
	local pv = TRF_Voice_Prov();
	local reg = nil;
	for i = 1, getn(pv) do if pv[i] == "TRF_Mc_VoiceProv" then reg = 1; end; end;
	HOST_Check(reg, "legend station lines registered as a mood provider");
	h.labels.CurrentQuest = "6_1";
	-- Dump with a hire, repair of the collection flag.
	MC_Put(4, {met=0}); MC_Put(5, {met=0});
	TRF.mc.x = nil;
	v = MC_Hire();
	n0 = S_Mark();
	TRF_Mc_Dump();
	HOST_Check(S_Logs(n0, "module=merc event=dump_hire clan="..v.c.." system=gaoba composition=1 power=") == 1 and S_Logs(n0, " visit=hired flight=1") == 1, "dump: the hire line");
	TRF.mc.o = "x";
	n0 = S_Mark();
	TRF_Mc_Fix();
	HOST_Check(TRF.mc.o == nil and S_Logs(n0, "event=fix field=o result=dropped") == 1, "repair: unreadable collection flag dropped");
	TRF_McPutO(12, 113);
	TRF_Mc_Fix();
	HOST_Check(TRF_McO().c == 12, "repair keeps a readable flag");
	-- Save bound: the hire record, the hull (6 ships at 1000 per mille) and the collection flag at their bounds.
	TRF.mc.h = TRF_TpPackK({c=12, sys=113, ty=3, pw=20, n=6, tr=660, fee=30000, sh=6400, bm=25600, k=999, lo=6, g=9999999, hj=99, hg=9999999},
		TRF_McHKeys());
	TRF.mc.hb = strrep("1000", 6);
	local hz, bz, oz = HOST_SaveSize(TRF.mc.h) + 9, HOST_SaveSize(TRF.mc.hb) + 10, HOST_SaveSize(TRF.mc.o) + 9;
	print("HOST info merc hire record bytes: h "..hz.." hb "..bz.." o "..oz);
	HOST_Check(hz <= 80 and bz <= 42 and oz <= 25, "save: h "..hz.." <= 80, hb "..bz.." <= 42, o "..oz.." <= 25 bytes (with keys)");
	MC_Enter("heos", 0);
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
