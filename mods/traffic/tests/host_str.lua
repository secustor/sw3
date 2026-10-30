-- Strength scale scenarios (design/strength-spec.md 8) under stock Lua 4.0.1: TRF_STR=a..e, run by run_host.sh as its own
-- entry point. a registration, tune keys and clamps, the score of the three kinds, b the tier with hysteresis (plain
-- band, up and down across the thresholds, prev nil, tuned thresholds), c the tier table (raid rows identical to the old
-- literal table, the dp, cap and cls columns and their readers in trf_haunt, trf_captain and trf_stash), d the chance
-- curve (every score, a 10,000-roll frequency check, a fixed roll, the trader distribution per prosperity, pro 0-2 without
-- RAND, the TRF_TierPick caps after the roll, the log lines), e the clan tier digit (init, region tick, TRF_ClanAdd,
-- repair, save and load, the TRF_EffTier overrides, the save bytes).
-- Loads host_station.lua up to its first scenario, as host_haunt.lua does. No new stub.

local f = openfile((getenv("TRF_TESTS") or "./").."host_station.lua", "r");
if not f then print("HOST FAIL host_str.lua: cannot open host_station.lua"); exit(1); end;
local src = read(f, "*a");
closefile(f);
local cut = strfind(src, "\n-- a: install (12.1, 6.1)", 1, 1);
if not cut then print("HOST FAIL host_str.lua: marker '-- a: install (12.1, 6.1)' missing in host_station.lua"); exit(1); end;
dostring(strsub(src, 1, cut), "host_station.lua");

-- Helpers ----------------------------------------------------------------------------------

-- Config of these runs: the repo defaults with the entry events and the worldbuilding features off, log 2, plus t.
function ST_Cfg(t)
	local c = {cap_enable=0, sweeps=0, sweep_ct=0, feq=0, staged=0, seed=0, queue=0, parked=0, voice_events=0, raids=0,
		dconv=0, carriers=0, po=0, enable_survivors=0, lad_enabled=0, enable_stashes=0, enable_freight=0, charter=0, log=2, tune={}};
	if t then for k, v in t do c[k] = v; end; end;
	return c;
end;

function ST_Begin(sys, ch, t)
	local h = HOST();
	h.labels.CurrentQuest = ch or "9_1";
	h.quests = {}; h.qlog = {};
	h.qs = FALSE;
	S_Begin(sys or "gredos", ST_Cfg(t));
end;

-- Replaces the cfg tune table (TRF_Tune and the module caches rebuild on a new table).
function ST_Tune(t) HOST().cfg.tune = t or {}; end;

function ST_Pro(p) TRF_SetPro(TRF_CurIdx(), p); end;

-- The raid tier table of trf_raid before the strength scale (v02 5.3, v1 6.1), for the identity check.
function ST_OldRows()
	return {
		{lo=1, hi=4, plo=1, phi=6, off=-3, lead=1, wing=1, ns=2},
		{lo=5, hi=9, plo=4, phi=11, off=0, lead=2, wing=1, ns=4},
		{lo=10, hi=14, plo=8, phi=15, off=2, lead=3, wing=2, ns=4, ns2=3},
		{lo=15, hi=18, plo=11, phi=18, off=3, lead=4, wing=3, ns=4, ns2=4}
	};
end;

-- Trader tier distribution per prosperity 0..9 in % of rolls (TT1, TT2, TT3, TT4), the table of design/strength-spec.md 4.5.
function ST_Dist()
	return {{100, 0, 0, 0}, {100, 0, 0, 0}, {100, 0, 0, 0}, {13, 68, 19, 0}, {4, 51, 45, 0},
		{0, 16, 72, 12}, {0, 7, 55, 38}, {0, 0, 18, 82}, {0, 0, 9, 91}, {0, 0, 0, 100}};
end;

-- a: registration, tune, score -----------------------------------------------------------------------------------

function T_ST_A()
	local h = HOST();
	ST_Begin();
	-- design/fits-spec.md 7: trf_fits counts as an extra module (13 -> 14).
	HOST_Check(S_Logs(0, "module=core event=loaded map=true module_count=18 extra_count=14") >= 1, "trf_str loads (extra_count=14, module_count unchanged)");
	local ml, ok = TRF_ModList(), nil;
	for i = 1, getn(ml) do if ml[i] == "Str" and ml[i - 1] == "Rg" then ok = 1; end; end;
	HOST_Check(ok and type(TRF_Str_TuneDef) == "function" and type(TRF_StrRows) == "function", "Str in the module list after Rg");
	local T = TRF_StrTune();
	HOST_Check(T.str_up == 60 and T.str_dn == 20 and T.str_up_t[1] == 25 and T.str_up_t[3] == 75 and T.str_dn_t[1] == 20 and T.str_dn_t[3] == 70,
		"tune defaults: str_up 60, str_dn 20, str_up_t 25/50/75, str_dn_t 20/45/70");
	HOST_Check(TRF_Tune().str_up == 60 and type(TRF_Tune().str_up_t) == "table", "TRF_Tune merges TRF_Str_TuneDef (numbers and lists)");
	ST_Tune({str_up=150, str_dn=-5});
	T = TRF_StrTune();
	HOST_Check(T.str_up == 100 and T.str_dn == 0, "clamps: str_up 150 -> 100, str_dn -5 -> 0");
	ST_Tune({str_up_t={30, 20, 80}});
	T = TRF_StrTune();
	HOST_Check(T.str_up_t[1] == 25 and T.str_up_t[2] == 50 and T.str_dn_t[2] == 45, "thresholds not rising: both lists read as the defaults");
	ST_Tune({str_up_t={30, 55, 80}, str_dn_t={40, 50, 75}});
	T = TRF_StrTune();
	HOST_Check(T.str_up_t[1] == 25 and T.str_dn_t[1] == 20, "a down threshold above its up threshold: defaults");
	ST_Tune({str_up_t={30, 55, 80}, str_dn_t={25, 50, 75}});
	T = TRF_StrTune();
	HOST_Check(T.str_up_t[1] == 30 and T.str_dn_t[3] == 75 and TRF_StrTier(29) == 1 and TRF_StrTier(30) == 2 and TRF_StrTier(26, 2) == 2
		and TRF_StrTier(24, 2) == 1, "tuned thresholds 30/55/80 and 25/50/75 act");
	ST_Tune({str_up_t={0, 50}, str_dn_t={-5}});
	T = TRF_StrTune();
	HOST_Check(T.str_up_t[1] == 1 and T.str_up_t[2] == 50 and T.str_up_t[3] == 75 and T.str_dn_t[1] == 1 and T.str_dn_t[2] == 45,
		"list entries clamped 1..99, a missing one from the default");
	ST_Tune({});
	-- Score of the three kinds.
	local cur = TRF_CurIdx();
	local slot = TRF_RgOf(cur);
	TRF.clan[slot].sc = 63;
	HOST_Check(TRF_StrScore("clan", slot) == 63 and TRF_StrScore("clan", 99) == 0, "clan: the clan score, 0 without a record");
	local okp = 1;
	for p = 0, 9 do
		ST_Pro(p);
		if TRF_Pro(cur) == p and TRF_StrScore("trade", cur) ~= p * 11 then okp = nil; end;
	end;
	ST_Pro(9);
	HOST_Check(okp and TRF_StrScore("trade", cur) == 99 and TRF_StrScore("trade", -1) == 0, "trade: prosperity x 11 (pro 9 -> 99), 0 for an unknown system");
	HOST_Check(TRF.mc == nil and TRF_StrScore("merc", 3) == TRF_StrSc(TRF_McDig(3, "fo")) and TRF.mc == nil, "merc without a record: the creation fortune, nothing written");
	TRF_McRec(1);
	local v = TRF_McGet(3);
	v.fo = 77;
	TRF_McPut(3, v);
	HOST_Check(TRF_StrScore("merc", 3) == 77 and TRF_StrScore("merc", 0) == 0 and TRF_StrScore("nope", 1) == 0 and TRF_StrScore(nil, 1) == 0,
		"merc: the fortune; bad clan, unknown kind -> 0");
	HOST_Check(TRF_StrSc(-4) == 0 and TRF_StrSc(150) == 99 and TRF_StrSc(41.7) == 41 and TRF_StrSc("x") == 0, "score values floor within 0..99");
	TRF.mc = nil;
end;

-- b: tier with hysteresis ----------------------------------------------------------------------------------------

function T_ST_B()
	ST_Begin();
	local okb = 1;
	for sc = 0, 99 do
		if TRF_StrTier(sc) ~= min(4, floor(sc / 25) + 1) or TRF_StrTier(sc, nil) ~= TRF_StrTier(sc) then okb = nil; end;
	end;
	HOST_Check(okb, "prev nil: the plain band floor(sc / 25) + 1 for 0..99");
	HOST_Check(TRF_StrTier(24, 1) == 1 and TRF_StrTier(25, 1) == 2 and TRF_StrTier(49, 2) == 2 and TRF_StrTier(50, 2) == 3
		and TRF_StrTier(74, 3) == 3 and TRF_StrTier(75, 3) == 4, "up at 25, 50, 75");
	HOST_Check(TRF_StrTier(20, 2) == 2 and TRF_StrTier(19, 2) == 1 and TRF_StrTier(45, 3) == 3 and TRF_StrTier(44, 3) == 2
		and TRF_StrTier(70, 4) == 4 and TRF_StrTier(69, 4) == 3, "down below 20, 45, 70");
	HOST_Check(TRF_StrTier(22, 2) == 2 and TRF_StrTier(22, 1) == 1 and TRF_StrTier(72, 4) == 4 and TRF_StrTier(72, 3) == 3,
		"inside the gap the previous tier holds");
	HOST_Check(TRF_StrTier(90, 1) == 4 and TRF_StrTier(5, 4) == 1 and TRF_StrTier(60, 9) == 3 and TRF_StrTier(60, 0) == 3 and TRF_StrTier(-3, 3) == 1,
		"several steps in one call; prev clamped 1..4, score clamped 0..99");
	-- A walk up and down: the tier changes only past the thresholds.
	local seq, t, got = {18, 24, 25, 22, 19, 30, 48, 51, 46, 44, 74, 76, 71, 69, 99, 0}, nil, "";
	for i = 1, getn(seq) do t = TRF_StrTier(seq[i], t); got = got..t; end;
	HOST_Check(got == "1122122332344341", "walk 18..0: "..got);
end;

-- c: the tier table and its readers -------------------------------------------------------------------------------

function T_ST_C()
	ST_Begin();
	local R, O, A = TRF_StrRows(), ST_OldRows(), TRF_Rd_TierRows();
	local same, nx = 1, 0;
	local new = {dp=1, cap=1, cls=1};
	for i = 1, 4 do
		for k, v in O[i] do if A[i][k] ~= v or R[i][k] ~= v then same = nil; end; end;
		for k, v in A[i] do
			if O[i][k] == nil then
				if new[k] and v == R[i][k] then nx = nx + 1; else same = nil; end;
			end;
		end;
	end;
	HOST_Check(getn(R) == 4 and getn(A) == 4 and same and nx == 12, "TRF_Rd_TierRows = TRF_StrRows: the old raid rows unchanged, extra columns dp, cap, cls only");
	local cols = "";
	for i = 1, 4 do cols = cols..R[i].dp..","..R[i].cap..","..R[i].cls..";"; end;
	HOST_Check(cols == "-1,1,1;0,1,1;1,1,2;1,1,3;", "columns dp {-1,0,1,1}, cap 1, cls {1,1,2,3}: "..cols);
	HOST_Check(TRF_StrRow(0).ns == 2 and TRF_StrRow(7).ns2 == 4 and TRF_StrRow(nil).lo == 1 and TRF_StrRow(2.6).lo == 5, "TRF_StrRow clamps 1..4");
	-- Raid readers: pilots and the pirate row.
	local l1, w1 = TRF_Rd_TierPilots(3);
	HOST_Check(l1 == Pir_Pilots[3] and w1 == Pir_Pilots[2], "TRF_Rd_TierPilots(3) reads lead 3 / wing 2 (NORMAL)");
	-- Stash class from cls with the salvage step (stash-spec 6).
	HOST_Check(TRF_ShClsOf(1, 0) == 1 and TRF_ShClsOf(2, 0) == 1 and TRF_ShClsOf(3, 0) == 2 and TRF_ShClsOf(4, 0) == 3 and TRF_ShClsOf(2, 4) == 2
		and TRF_ShClsOf(4, 9) == 3, "stash class from the cls column, salvage >= 4 one up, at most 3");
	-- Captain hull: the cap column gives the old "one row up" for every tier, power and difficulty table.
	local okh = 1;
	for d = 1, 3 do
		local lv = {1,1,1,2,3,4,5,6,7,7,8,9,9,10,11,11,12,13,13,14};
		if d == 2 then lv = {1,1,2,3,4,5,6,6,7,8,9,10,11,12,12,13,14,15,16,17}; end;
		if d == 3 then lv = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20}; end;
		for T = 1, 4 do
			local b = O[T];
			for sb = 1, 20 do
				local pw = TRF_CapCl(TRF_CapCl(floor(sb + b.off + 1), b.plo, b.phi + 1), 1, 20);
				local hr, p2 = TRF_CapHullOf(R[T], sb, lv);
				if hr ~= TRF_CapCl(lv[pw], b.lo, b.hi + 1) or p2 ~= pw then okh = nil; end;
			end;
		end;
	end;
	HOST_Check(okh, "captain hull row: cap 1 = the old one row up (3 difficulty tables, T1..T4, sys_base 1..20)");
	local b2 = {lo=5, hi=9, plo=4, phi=11, off=0, ns=4, cap=2};
	HOST_Check(TRF_CapHullOf(b2, 9, {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20}) == 11, "cap 2: two rows up (row 11 at power 11)");
	-- Haunt power step from dp; an explicit cfg tune haunt_dp wins.
	local tn = TRF_HaTune();
	HOST_Check(TRF_HaDpOf(1, tn) == -1 and TRF_HaDpOf(2, tn) == 0 and TRF_HaDpOf(3, tn) == 1 and TRF_HaDpOf(4, tn) == 1 and TRF_HaDpOf(nil, tn) == -1,
		"haunt dp from the dp column");
	ST_Tune({haunt_dp={-2, 1, 2, 3}});
	tn = TRF_HaTune();
	HOST_Check(TRF_HaDpOf(1, tn) == -2 and TRF_HaDpOf(2, tn) == 1 and TRF_HaDpOf(4, tn) == 3, "an explicit cfg tune haunt_dp overrides the table");
	ST_Tune({});
end;

-- d: the chance curve and the trader roll ---------------------------------------------------------------------------

function T_ST_D()
	local h = HOST();
	ST_Begin();
	local okc, bad = 1, "";
	for sc = 0, 99 do
		local f = mod(sc, 25);
		local b, cu, cd = TRF_StrChance(sc);
		if b ~= min(4, floor(sc / 25) + 1) or cu ~= floor(f * 60 / 25) or cd ~= floor((25 - f) * 20 / 25) then okc = nil; bad = bad.." "..sc; end;
	end;
	HOST_Check(okc, "every score 0..99: up floor(f x 60), down floor((1 - f) x 20), f = mod(sc, 25) / 25"..bad);
	local b, cu, cd = TRF_StrChance(55);
	HOST_Check(b == 3 and cu == 12 and cd == 16, "score 55: T3, up 12 %, down 16 %");
	local t1, s1, u1, d1, b1 = TRF_StrRoll(55, 11);
	local t2, s2 = TRF_StrRoll(55, 12);
	local t3, s3 = TRF_StrRoll(55, 84);
	local t4, s4 = TRF_StrRoll(55, 83);
	local t5, s5 = TRF_StrRoll(55, nil);
	HOST_Check(t1 == 4 and s1 == 1 and u1 == 12 and d1 == 16 and b1 == 3 and t2 == 3 and s2 == 0 and t3 == 2 and s3 == -1 and t4 == 3 and s4 == 0
		and t5 == 3 and s5 == 0, "roll < up: +1; roll >= 100 - down: -1; else 0; nil: no step");
	local ta, sa = TRF_StrRoll(99, 0);
	local tb, sb = TRF_StrRoll(0, 99);
	HOST_Check(ta == 4 and sa == 1 and tb == 1 and sb == -1, "tier clamped 1..4, the raw step returned");
	local same = 1;
	for r = 0, 99 do
		local x, y = TRF_StrRoll(66, r);
		local x2, y2 = TRF_StrRoll(66, r);
		if x ~= x2 or y ~= y2 then same = nil; end;
	end;
	HOST_Check(same, "a fixed roll gives the same step every time");
	HOST_Check(TRF_StrRollUseful(0) == nil and TRF_StrRollUseful(11) and TRF_StrRollUseful(99) == nil and TRF_StrRollUseful(77), "a roll is useful only when it can change the tier");
	-- 10,000 RAND rolls per score: frequencies within 2 pp of the chances.
	h.seed = 12345;
	local okf, worst = 1, 0;
	for sc = 0, 99 do
		local bb, up, dn = TRF_StrChance(sc);
		local nu, nd = 0, 0;
		for k = 1, 10000 do
			local x, st = TRF_StrRoll(sc, RAND(100));
			if st == 1 then nu = nu + 1; elseif st == -1 then nd = nd + 1; end;
		end;
		local e = max(abs(nu / 100 - up), abs(nd / 100 - dn));
		if e > worst then worst = e; end;
		if e > 2 then okf = nil; end;
	end;
	HOST_Check(okf, "10,000 rolls per score 0..99: up and down frequencies within 2 pp (worst "..worst.." pp)");
	-- Trader distribution per prosperity: the spec table (every roll 0..99; pro 0-2 TT1 without a roll).
	local D, okd, got = ST_Dist(), 1, "";
	for p = 0, 9 do
		local n = {0, 0, 0, 0};
		for r = 0, 99 do
			local t = 1;
			if p >= 3 then t = TRF_StrRoll(p * 11, r); end;
			n[t] = n[t] + 1;
		end;
		got = got.." "..p..":"..n[1].."/"..n[2].."/"..n[3].."/"..n[4];
		for i = 1, 4 do if n[i] ~= D[p + 1][i] then okd = nil; end; end;
	end;
	HOST_Check(okd, "trader distribution per prosperity matches strength-spec 4.5:"..got);
	-- TRF_TierPick: pro 0-2 draw nothing, pro 3 draws once.
	local cur = TRF_CurIdx();
	local okn = 1;
	for p = 0, 2 do
		ST_Pro(p);
		local r0 = h.rand;
		local t, why, sc, ro, st = TRF_TierPick(cur, 8, nil);
		if t ~= 1 or why ~= "pro" or h.rand ~= r0 or sc ~= p * 11 or ro ~= nil or st ~= 0 then okn = nil; end;
	end;
	HOST_Check(okn, "pro 0-2: TT1, reason pro, no RAND");
	ST_Pro(3);
	local r0 = h.rand;
	h.rq = {50};
	local t, why, sc, ro, st = TRF_TierPick(cur, 8, nil);
	HOST_Check(t == 2 and why == "pro" and sc == 33 and ro == 50 and st == 0 and h.rand == r0 + 1, "pro 3, roll 50: TT2, one draw");
	h.rq = {90};
	t, why, sc, ro, st = TRF_TierPick(cur, 8, nil);
	HOST_Check(t == 1 and why == "roll" and st == -1, "pro 3, roll 90: TT1 (down 13 %), reason roll");
	ST_Tune({str_up=0, str_dn=0});
	ST_Pro(4);
	r0 = h.rand;
	t, why = TRF_TierPick(cur, 8, nil);
	HOST_Check(t == 2 and h.rand == r0, "str_up 0, str_dn 0: pro 4 TT2 without a draw");
	ST_Tune({});
	-- Caps after the roll: pro 6 roll 0 = TT4 (score 66 T3 + 1); heat 5 blocks TT4, then caps TT3 -> TT2.
	ST_Pro(6);
	TRF.std.heat = 5; h.rq = {0};
	local m0 = S_Mark();
	t, why, sc, ro, st = TRF_TierPick(cur, 8, nil);
	HOST_Check(t == 2 and why == "heat" and st == 1 and sc == 66, "pro 6 roll 0 -> TT4, tt4 cap -> TT3, heat 5 -> TT2 ("..tostring(why)..")");
	HOST_Check(S_Logs(m0, "module=str event=roll kind=trade id="..cur.." score=66 roll=0 step=1 rolled_tier=4 tier=2 reason=heat") == 1, "roll line at log 2");
	TRF.std.heat = 0;
	TRF.live.patk = 1; h.rq = {50};
	t, why = TRF_TierPick(cur, 8, nil);
	HOST_Check(t == 2 and why == "patk", "pro 6 roll 50 -> TT3, counted attack -> TT2");
	TRF.live.patk = nil;
	h.rq = {50};
	t, why = TRF_TierPick(cur, 8, 3);
	HOST_Check(t == 1 and why == "ships", "3 free ships -> TT1");
	h.rq = {0};
	t, why = TRF_TierPick(cur, 8, nil);
	HOST_Check(t == 4 or strsub(why, 1, 4) == "tt4_", "pro 6 roll 0 without caps: TT4 or a named TT4 condition ("..tostring(why)..")");
	h.cfg.tt4 = 0; h.rq = {0};
	t, why = TRF_TierPick(cur, 8, nil);
	HOST_Check(t == 3 and why == "tt4_cfg", "cfg tt4 0: a TT4 roll gives TT3 (tt4_cfg)");
	h.cfg.tt4 = nil;
	h.cfg.prosperity = 0;
	r0 = h.rand;
	t, why = TRF_TierPick(cur, 8, nil);
	HOST_Check(t == 1 and why == "off" and h.rand == r0, "cfg prosperity 0: TT1, no draw");
	h.cfg.prosperity = nil;
	-- The plan line carries score, roll and step.
	m0 = S_Mark();
	h.rq = {50};
	local plan = {strength=8, free=20, esc=0};
	TRF_TierPlan(plan);
	HOST_Check(S_Logs(m0, "module=tier event=plan tier=3 reason=pro strength=8") == 1 and S_Logs(m0, "escorts_added=0 score=66 roll=50 step=0") == 1, "plan line: score, roll, step");
	ST_Pro(1);
	m0 = S_Mark();
	plan = {strength=8, free=20, esc=0};
	TRF_TierPlan(plan);
	HOST_Check(S_Logs(m0, "escorts_added=0 score=11 roll=none step=0") == 1, "plan line without a draw: roll=none");
	h.rq = {};
	-- Band maximum (spec 10 item 7): TRF_BandCaps.tmax is the highest tier the roll can give.
	local tm, okm = {1, 1, 1, 3, 3, 4, 4, 4, 4, 4}, 1;
	for p = 0, 9 do ST_Pro(p); if TRF_BandCaps(cur).tmax ~= tm[p + 1] then okm = nil; end; end;
	HOST_Check(okm, "tmax by pro: TT1 at 0-2, TT3 at 3-4, TT4 from 5");
end;

-- e: the clan tier digit ------------------------------------------------------------------------------------------

function T_ST_E()
	local h = HOST();
	ST_Begin();
	local m = TRF_RgMap();
	local okt = 1;
	for s = 1, m.n do
		local c = TRF.clan[s];
		if c.tr ~= min(4, floor(c.sc / 25) + 1) then okt = nil; end;
	end;
	HOST_Check(okt, "init: tr = the plain band of every clan score");
	local c = TRF.clan[1];
	c.sc = 76; c.tr = 3;
	HOST_Check(TRF_ClanTier(1) == 4, "score 76 over tr 3: tier 4 at once");
	local m0 = S_Mark();
	TRF_Str_RegionTick(TRF.clock.legs);
	HOST_Check(c.tr == 4 and S_Logs(m0, "module=str event=tier slot=1 score=76 tier=4 prev=3 via=tick result=changed") == 1, "region tick commits tr 4 (level 1 line)");
	c.sc = 72;
	m0 = S_Mark();
	TRF_Str_RegionTick(TRF.clock.legs);
	HOST_Check(TRF_ClanTier(1) == 4 and c.tr == 4 and S_Logs(m0, "module=str event=tier slot=1 score=72 tier=4 prev=4 via=tick result=kept") == 1,
		"score 72 after tier 4: kept across the tick (hysteresis), level 2 line");
	-- Forced Bust (spec 10 item 8): sc < 75 forces it although the hysteresis tier is 4.
	local r1 = TRF.rg[1];
	local ph0, pt0 = r1.ph, r1.pt;
	r1.ph = 1;
	TRF_RgCtSet(1, 4);
	local fz = TRF_RgForcedBust(TRF.clock.legs, {1}, {n=1});
	HOST_Check(fz[1] == 1 and r1.ph == 4 and TRF_ClanTier(1) == 4, "score 72 at tier 4: the kill still forces Bust");
	r1.ph = ph0; r1.pt = pt0;
	c.sc = 69;
	TRF_Str_RegionTick(TRF.clock.legs);
	HOST_Check(c.tr == 3 and TRF_ClanTier(1) == 3, "score 69: tier 3");
	c.sc = 74;
	TRF_Str_RegionTick(TRF.clock.legs);
	HOST_Check(c.tr == 3, "score 74 after tier 3: still 3 (up at 75)");
	-- TRF_ClanAdd commits at once (via=event).
	m0 = S_Mark();
	TRF_ClanAdd(1, 3, "test");
	HOST_Check(c.sc == 77 and c.tr == 4 and S_Logs(m0, "module=str event=tier slot=1 score=77 tier=4 prev=3 via=event result=changed") == 1, "TRF_ClanAdd +3 to 77: tr 4 (via event)");
	-- The full region tick calls the hook for every slot.
	m0 = S_Mark();
	TRF_RegionTick(TRF.clock.legs);
	HOST_Check(S_Logs(m0, "module=str event=tier ") == m.n, "TRF_RegionTick: one tier line per slot ("..S_Logs(m0, "module=str event=tier ")..")");
	-- Repair: bad digit -> plain band, out of range clamped.
	c.sc = 40; c.tr = "x";
	TRF.clan[2].tr = 7;
	TRF.clan[3].tr = nil;
	TRF.clan[4].tr = 2.6;
	TRF_Rg_Fix();
	HOST_Check(c.tr == 2 and TRF.clan[2].tr == 4 and TRF.clan[3].tr == min(4, floor(TRF.clan[3].sc / 25) + 1) and TRF.clan[4].tr == 2,
		"repair: 'x' -> band 2, 7 -> 4, nil -> band, 2.6 -> 2");
	-- Save and load keep the digit.
	c.sc = 72; c.tr = 4;
	T_SaveLoad();
	HOST_Check(TRF.clan[1].tr == 4 and TRF_ClanTier(1) == 4, "save and load keep tr 4 at score 72");
	-- TRF_EffTier keeps its overrides.
	local cur = TRF_CurIdx();
	local sl = TRF_RgOf(cur);
	if sl then
		TRF.clan[sl].sc = 10; TRF.clan[sl].tr = 1;
		TRF.lr = {{t=cur, e=TRF.clock.legs + 5}};
		HOST_Check(TRF_EffTier(cur) == 4, "carrier raid target: EffTier 4 over tier 1");
		TRF.lr = {};
		HOST_Check(TRF_EffTier(cur) == 1, "without the carrier record: the clan tier 1");
	end;
	local gi = nil;
	for i = 1, getn(TRF_Map().sys) do
		if not gi and TRF_Map().sys[i].start == 1 and TRF_RgOf(i) then gi = i; end;
	end;
	if gi then
		local gs = TRF_RgOf(gi);
		TRF.clan[gs].sc = 90; TRF.clan[gs].tr = 4;
		h.labels.CurrentQuest = "1_1";
		local g1 = TRF_EffTier(gi);
		h.labels.CurrentQuest = "9_1";
		HOST_Check(g1 == 1 and TRF_EffTier(gi) == 4, "start system: EffTier 1 under the guard (chapter 1), 4 after it");
	end;
	HOST_Check(TRF_EffTier(-1) == 1, "no region: EffTier 1");
	-- Save bytes of the digit: every slot at its widest.
	local z1 = HOST_SaveSize(TRF.clan);
	for s = 1, m.n do TRF.clan[s].tr = nil; end;
	local z0 = HOST_SaveSize(TRF.clan);
	for s = 1, m.n do TRF.clan[s].tr = 4; end;
	print("HOST info tier digit bytes: "..(z1 - z0).." for "..m.n.." slots");
	HOST_Check(z1 - z0 == 22 * m.n, "tier digit: "..(z1 - z0).." bytes, 22 per slot (key 10 + number 12)");
	TRF.lr = nil;
end;

-- Dispatch ---------------------------------------------------------------------------------

local sc = getenv("TRF_STR") or "";
local fn = getglobal("T_ST_"..strupper(sc));
print("HOST ==== strength scale scenario str-"..sc.." dir="..HOST().dir);
if type(fn) == "function" then
	fn();
	HOST_Check(T_LeftGlobals() == "", "no handle globals left at the end"..T_LeftGlobals());
	local q = T_BadCallbacks();
	HOST_Check(q == "", "every mod callback string carries the current gen"..q);
else
	HOST_Check(nil, "unknown strength scale scenario "..sc);
end;
HOST_Check((HOST().gpm_tick or 0) == 0, "no GetPlayerMotherShip from a tick (n="..tostring(HOST().gpm_tick or 0)..")");
print("HOST errors="..HOST().errors.." fails="..HOST().fails);
if HOST().errors > 0 or HOST().fails > 0 then exit(1); end;
exit(0);
