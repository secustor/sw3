-- Pirate fit variety scenarios (design/fits-spec.md 10) under stock Lua 4.0.1: TRF_FT=a..f, run by run_host.sh as its own
-- entry point. a registration, toggles, tune clamps, hash quality, the roll (determinism, bounds per score and tier, the
-- base factor, scrap only at tier 2 below 35, elites only at tiers 3-4), b the row copy (count, roles, order, explicit
-- indices, the maps, the rank clamp, captured within tolerance, one captured ship, the input unchanged), c the haunt build
-- with the graded row (both build sites, the global tables unchanged, the saved grade across a load, -3 on an elite kill
-- inside the -6 cap), d the raid roll once per flight (pilots one rank up, RAND draws unchanged) and the garrison roll,
-- e the quest-gated visit (captured only, value-neutral, vanilla group and power, fits_gate 1, the scan deny list),
-- f fits 0 gives byte-identical haunt call lines, the debug test ship with mocks, the save bytes; step 2 (fits-spec 14):
-- g the new-fit data (holders, pools, flags), the R2 filter by tier and fits_hull_pct, the gate, fits_new 0 = step 1,
-- h the build of a captured new fit (bare carcass, AddModule right after NewAllFlight, a nil return, an unused hull,
-- the raid path, fits 0 identical). Stub change: AddModule returns the module name (E-BB1), HOST().am_nil[m] nil.
-- Loads host_station.lua up to its first scenario and the helpers of host_haunt.lua (its dispatch cut off). Stub change:
-- NewAllFlight in host_stubs.lua checks the row keys as vanilla's next() loop needs them and records the rows by sign.

local f = openfile((getenv("TRF_TESTS") or "./").."host_station.lua", "r");
if not f then print("HOST FAIL host_fits.lua: cannot open host_station.lua"); exit(1); end;
local src = read(f, "*a");
closefile(f);
local cut = strfind(src, "\n-- a: install (12.1, 6.1)", 1, 1);
if not cut then print("HOST FAIL host_fits.lua: marker '-- a: install (12.1, 6.1)' missing in host_station.lua"); exit(1); end;
dostring(strsub(src, 1, cut), "host_station.lua");
f = openfile((getenv("TRF_TESTS") or "./").."host_haunt.lua", "r");
if not f then print("HOST FAIL host_fits.lua: cannot open host_haunt.lua"); exit(1); end;
src = read(f, "*a");
closefile(f);
local a0 = strfind(src, "\n-- Helpers ---", 1, 1);
local a1 = strfind(src, "\n-- a: registration, toggles, tune, static table, pure rules", 1, 1);
if not a0 or not a1 then print("HOST FAIL host_fits.lua: helper markers missing in host_haunt.lua"); exit(1); end;
dostring(strsub(src, a0, a1), "host_haunt.lua");

-- Helpers ----------------------------------------------------------------------------------

-- The haunt configuration with fits on and region ticks off (cycle 0: the score, phase and pt stay as set), plus t.
function FT_Begin(sys, t)
	local c = {fits=1, cycle=0};
	if t then for k, v in t do c[k] = v; end; end;
	HA_Begin(sys or "xb13", nil, c);
	-- Phase start legs up to 4000 must survive the repair (pt <= legs).
	TRF.clock.legs = 5000;
	HOST().nafs = {};
end;

-- Region slot of system nm in phase ph with score sc and the tier digit of that score.
function FT_Clan(nm, ph, sc)
	local s = HA_Slot(nm);
	HA_Phase(s, ph, sc);
	TRF.clan[s].tr = TRF_StrTier(sc);
	return s, V_Idx(nm);
end;

-- Grades of the graded rows of system nm (unpinned, type 1 / 2) at phase start pt: list g[i] (nil for the others), the
-- number of elite flights and of flights whose captured roll hits a row with a pool (gate 1: the gate salt and the
-- vanilla power, else the haunt power p + dp of the tier).
function FT_Grades(nm, pt, gate)
	local d = HA_Data(nm);
	local idx, slot = V_Idx(nm), HA_Slot(nm);
	local g, ne, nc = {}, 0, 0;
	for i = 1, getn(d.f) do
		local r = d.f[i];
		if r.pin ~= 1 and r.t ~= 3 then
			local salt, dp = TRF_FtK().salt_haunt, TRF_StrRow(TRF_EffTier(idx)).dp;
			if gate == 1 then salt = TRF_FtK().salt_gate; dp = 0; end;
			local R = TRF_FtRoll(idx, i, pt, slot, salt, nil, gate);
			g[i] = R;
			if R.g == 1 then ne = ne + 1; end;
			if R.c then
				local tab, form, ri = TRF_FtTab(r.t, r.p + dp);
				local row, cj = TRF_FtRow(tab[ri], R.g, R.sel, nil, R.nw);
				if cj then nc = nc + 1; end;
			end;
		end;
	end;
	return g, ne, nc;
end;

-- First phase start leg 1..4000 where FT_Grades(nm) gives at least ne elites and nc captured flights.
function FT_FindPt(nm, ne, nc, gate)
	for pt = 1, 4000 do
		local g, e, c = FT_Grades(nm, pt, gate);
		if e >= ne and c >= nc then return pt, g; end;
	end;
	return nil;
end;

-- First phase start leg 1..4000 and flight index of system nm whose graded row (haunt power) is of kind w: "cap" a
-- normal flight with a captured ship, "scrap" a scrap flight. Returns pt, i and the roll record, or nil.
function FT_Find(nm, w)
	local d = HA_Data(nm);
	local dp = TRF_StrRow(TRF_EffTier(V_Idx(nm))).dp;
	for pt = 1, 4000 do
		local G = FT_Grades(nm, pt);
		for i = 1, getn(d.f) do
			local R = G[i];
			if R then
				local tab, form, ri = TRF_FtTab(d.f[i].t, d.f[i].p + dp);
				local sel = nil;
				if R.c then sel = R.sel; end;
				local row, cj = TRF_FtRow(tab[ri], R.g, sel, 1, R.nw);
				if (w == "cap" and R.g == 0 and cj) or (w == "scrap" and R.g == -1) then return pt, i, R; end;
			end;
		end;
	end;
	return nil;
end;

-- Fit names of a row.
function FT_Names(row) return TRF_FtNames(row); end;

-- Gear value of a row from the data table.
function FT_Val(row)
	local v, D = 0, TRF_FtD();
	for j = 1, getn(row) do v = v + (D.val[row[j][1]] or 0); end;
	return v;
end;

-- Snapshot of the global Pir_* rows (names joined) for the unchanged check.
function FT_PirSnap()
	local s = "";
	for r = 1, 20 do s = s..FT_Names(Pir_Fighters[r]).."/"..FT_Names(Pir_Bombers[r]).."|"; end;
	return s;
end;

-- Mod log lines with pat after n0, joined by "|" (the byte-identical comparison).
function FT_Lines(n0, pat)
	local s, q = "", HOST().logs;
	for i = n0 + 1, getn(q) do if strfind(q[i], pat, 1, 1) then s = s..q[i].."|"; end; end;
	return s;
end;

-- a: registration, toggles, tune, hash, roll -------------------------------------------------------------------

function T_FT_A()
	FT_Begin("xb13");
	HOST_Check(S_Logs(0, "module=core event=loaded map=true module_count=18 extra_count=15") >= 1, "trf_fits loads (extra_count=15)");
	local ml, ok = TRF_ModList(), nil;
	for i = 1, getn(ml) do if ml[i] == "Ft" and ml[i - 1] == "Str" then ok = 1; end; end;
	HOST_Check(ok and type(TRF_Ft_TuneDef) == "function" and type(TRF_FtData) == "function", "Ft in the module list after Str");
	local d = TRF_Ft_OptDef();
	HOST_Check(d.fits == 0 and d.fits_gate == 0 and d.fits_test == "" and TRF_FtOpt("fits") == 1 and TRF_FtOn() == 1,
		"cfg defaults fits 0, fits_gate 0, fits_test empty; on in these runs");
	HA_Set("fits", 2);
	HOST_Check(TRF_FtOpt("fits") == 0 and not TRF_FtOn(), "fits 2 reads as the default 0");
	HA_Set("fits", 1);
	local T = TRF_FtTune();
	HOST_Check(T.fits_elite_max == 5 and T.fits_base_a == 10 and T.fits_base_p == 3 and T.fits_cap_pct == 5 and T.fits_scrap_sc == 35
		and getn(T.fits_test_mods) == 3 and T.fits_test_mods[1] == "PC2" and TRF_Tune().fits_cap_pct == 5, "tune defaults, merged into TRF_Tune");
	HA_Tune("fits_cap_pct", 50); HA_Tune("fits_elite_max", -3); HA_Tune("fits_test_mods", {"VC2", 3, ""});
	T = TRF_FtTune();
	HOST_Check(T.fits_cap_pct == 10 and T.fits_elite_max == 0 and getn(T.fits_test_mods) == 1 and T.fits_test_mods[1] == "VC2",
		"clamps: fits_cap_pct 50 -> 10, fits_elite_max -3 -> 0, only string modules");
	HOST().cfg.tune = {};
	-- Hash: 0..99, below 2^31 inside, not an arithmetic sequence for consecutive inputs, uniform within 2 pp.
	local dec, okr = {}, 1;
	for k = 0, 9 do dec[k] = 0; end;
	for k = 0, 9999 do
		local x = TRF_FtHash(45, k, 120, 1);
		if x < 0 or x > 99 or x ~= floor(x) then okr = nil; end;
		dec[floor(x / 10)] = dec[floor(x / 10)] + 1;
	end;
	local okd, ds = 1, "";
	for k = 0, 9 do if dec[k] < 800 or dec[k] > 1200 then okd = nil; end; ds = ds..dec[k].." "; end;
	HOST_Check(okr and okd, "10,000 hashes in 0..99, every decile within 10 +- 2 %: "..ds);
	local okc = 1;
	for kind = 1, 4 do
		local seq, df = {}, {};
		for k = 1, 21 do
			local v = {45, 3, 120, 1};
			v[kind] = k;
			seq[k] = TRF_FtHash(v[1], v[2], v[3], v[4]);
		end;
		local nd = 0;
		for k = 1, 20 do
			local x = mod(seq[k + 1] - seq[k] + 100, 100);
			if not df[x] then df[x] = 1; nd = nd + 1; end;
		end;
		if nd < 10 then okc = nil; end;
	end;
	HOST_Check(okc, "consecutive inputs in each argument: at least 10 distinct steps in 20 (not an arithmetic sequence)");
	HOST_Check(TRF_FtHash(-7, 2.6, nil, 1) == TRF_FtHash(7, 2, 0, 1) and TRF_FtHash(1e9, 5, 5, 5) == TRF_FtHash(mod(1e9, 46337), 5, 5, 5),
		"negative, fractional, nil and large inputs fold to floor(|x|) mod 46337");
	-- Roll: determinism and bounds per score and tier.
	local gs, gi = FT_Clan("golkonda", 3, 80);
	local R1, R2 = TRF_FtRoll(gi, 4, 300, gs), TRF_FtRoll(gi, 4, 300, gs);
	HOST_Check(R1.g == R2.g and R1.r == R2.r and R1.r2 == R2.r2 and R1.sel == R2.sel and R1.up == R2.up and R1.t == 4 and R1.sc == 80,
		"same saved state, same roll (no RAND, no TRF.gen): grade "..R1.g.." roll "..R1.r);
	local g0 = TRF.gen;
	TRF.gen = TRF.gen + 7;
	local R3 = TRF_FtRoll(gi, 4, 300, gs);
	TRF.gen = g0;
	HOST_Check(R3.r == R1.r and R3.r2 == R1.r2, "TRF.gen does not enter the roll");
	local okb, okm, bad = 1, 1, "";
	for t = 1, 4 do
		local prev = -1;
		for sc = 0, 99 do
			TRF.clan[gs].sc = sc;
			local R = TRF_FtRoll(gi, 1, 300, gs, 1, t);
			if R.up < 0 or R.up > 15 or (t < 3 and R.up ~= 0) or (R.dn > 0 and (t ~= 2 or sc >= 35)) or R.up + R.dn > 100 then okb = nil; bad = bad.." t"..t.."sc"..sc; end;
			if t == 2 and sc >= 25 and sc < 35 and (R.dn < 12 or R.dn > 20) then okb = nil; bad = bad.." dn"..sc; end;
			if t >= 3 and sc >= 50 then
				if R.up < prev then okm = nil; end;
				prev = R.up;
			end;
			if (R.g == 1 and R.r >= R.up) or (R.g == -1 and R.r < 100 - R.dn) or (R.g == 0 and (R.r < R.up or R.r >= 100 - R.dn)) then okb = nil; bad = bad.." g"..sc; end;
		end;
	end;
	HOST_Check(okb, "bounds: up 0..15 only at tiers 3-4, down only at tier 2 below score 35 (12-20 %), grade matches the roll"..bad);
	HOST_Check(okm, "up rises with the score over tiers 3-4");
	TRF.clan[gs].sc = 99;
	HOST_Check(TRF_FtRoll(gi, 1, 300, gs, 1, 4).up == 5 and TRF_FtRoll(gi, 1, 300, gs, 1, 3).up == 5, "score 99: fits_elite_max 5 %");
	TRF.clan[gs].sc = 75;
	local u75 = TRF_FtRoll(gi, 1, 300, gs, 1, 4).up;
	TRF.clan[gs].sc = 74;
	local u74 = TRF_FtRoll(gi, 1, 300, gs, 1, 3).up;
	HOST_Check(u75 >= u74 and u75 == 2, "no drop at the tier-4 border: score 74 "..u74.." %, 75 "..u75.." %");
	-- Base factor: A +10, P +3, cap 15; only at tiers 3-4.
	TRF.base = {{s=gi, k=2, h=9, t=0, w=0}};
	TRF.clan[gs].sc = 99;
	local ua = TRF_FtRoll(gi, 1, 300, gs, 1, 4).up;
	TRF.base[1].k = 1;
	local up_ = TRF_FtRoll(gi, 1, 300, gs, 1, 4).up;
	TRF.base[1].k = 3;
	local ud = TRF_FtRoll(gi, 1, 300, gs, 1, 4).up;
	TRF.base[1].k = 2;
	local u2 = TRF_FtRoll(gi, 1, 300, gs, 1, 2).up;
	HA_Tune("fits_base_a", 15);
	local uc = TRF_FtRoll(gi, 1, 300, gs, 1, 4).up;
	HOST().cfg.tune = {};
	HOST_Check(ua == 15 and up_ == 8 and ud == 5 and u2 == 0 and uc == 15, "base factor: A 5 + 10 = 15, P 5 + 3, D 0, none at tier 2, cap 15 (A 15: "..uc..")");
	TRF.base = nil;
	-- gate 1: no elite, no scrap; the captured roll stays.
	TRF.clan[gs].sc = 30;
	local Rg = TRF_FtRoll(gi, 1, 300, gs, 1, 2, 1);
	local Rn = TRF_FtRoll(gi, 1, 300, gs, 1, 2);
	HOST_Check(Rg.up == 0 and Rg.dn == 0 and Rg.g == 0 and Rn.dn == 16 and Rg.r2 == Rn.r2, "gate: up and down 0, the captured roll unchanged");
	-- Share of captured hits and elite hits over many flights (about fits_cap_pct and up).
	local nc, nel = 0, 0;
	TRF.clan[gs].sc = 99;
	for i = 1, 31 do for pt = 1, 200 do
		local R = TRF_FtRoll(gi, i, pt, gs, 1, 4);
		if R.c then nc = nc + 1; end;
		if R.g == 1 then nel = nel + 1; end;
	end; end;
	HOST_Check(nc >= 0.03 * 6200 and nc <= 0.07 * 6200 and nel >= 0.03 * 6200 and nel <= 0.07 * 6200,
		"over 6,200 flights: captured "..nc.." (5 %), elite "..nel.." (5 %)");
end;

-- b: row copy -------------------------------------------------------------------------------------------------

function T_FT_B()
	FT_Begin("xb13");
	local D = TRF_FtD();
	local src = Pir_Fighters[8];
	local before = FT_Names(src);
	local out, cj = TRF_FtRow(src, 1, nil, 1);
	local ok, keys = 1, 0;
	for k, v in out do
		keys = keys + 1;
		if type(k) ~= "number" or k < 1 or k > getn(src) then ok = nil; end;
	end;
	HOST_Check(ok and keys == getn(src) and out.n == nil and getn(out) == getn(src) and cj == nil, "copy by explicit index: keys 1..n only, no field n");
	local okr = 1;
	for j = 1, getn(src) do
		if out[j][3] ~= src[j][3] or out[j][1] ~= (D.up[src[j][1]] or src[j][1]) or out[j][2] ~= min(5, src[j][2] + 1) then okr = nil; end;
	end;
	HOST_Check(okr and FT_Names(src) == before, "elite: the up map per ship, rank + 1, roles and order kept, the source row unchanged: "..FT_Names(out));
	local r20 = TRF_FtRow(Pir_Fighters[20], 1, nil, 1);
	HOST_Check(r20[1][2] == 5 and r20[2][2] == 5 and r20[6][2] == 5 and r20[1][1] == "Gunslinger_pir3", "rank clamp 5 -> 5, 4 -> 5; an L4 fit without an up entry stays");
	local rn = TRF_FtRow(Pir_Fighters[20], 1, nil, nil);
	HOST_Check(rn[2][2] == 4, "rank step only with rk 1 (raid rows keep their 5 / 1 ranks)");
	local sc = TRF_FtRow(Pir_Fighters[9], -1, nil, 1);
	HOST_Check(sc[1][1] == "Yari_pir2" and sc[2][1] == "Excalibur_pir1" and sc[3][1] == "Hatchet_pir1" and sc[1][2] == Pir_Fighters[9][1][2],
		"scrap: the dn map, ranks unchanged: "..FT_Names(sc));
	local sc1 = TRF_FtRow(Pir_Fighters[1], -1, nil, 1);
	HOST_Check(sc1[1][1] == "Brigand_pir1", "scrap of an L1 fit: unchanged");
	-- Captured: one ship at most, from the selector; value within 5 %.
	local b10 = Pir_Bombers[11];
	local okc, n1 = 1, 0;
	for sel = 0, 99 do
		local c, j = TRF_FtRow(b10, 0, sel, 1);
		if not j then okc = nil; end;
		local diff = 0;
		for k = 1, getn(b10) do if c[k][1] ~= b10[k][1] then diff = diff + 1; end; end;
		if diff ~= 1 then okc = nil; end;
		if j and abs(D.val[c[j][1]] - D.val[b10[j][1]]) > 0.05 * D.val[b10[j][1]] then okc = nil; end;
		if j == 1 then n1 = n1 + 1; end;
	end;
	HOST_Check(okc and n1 > 0, "captured: exactly one ship swapped for every selector, within +-5 % of its value");
	-- The captured fit is never one the row already carries (fighter row 4 has Yari and Brigand, bomber row 10 Bident and
	-- Hatchet: no captured ship).
	local okn = 1;
	for sel = 0, 99 do
		local c4, j4 = TRF_FtRow(Pir_Fighters[4], 0, sel, 1);
		local c10, j10 = TRF_FtRow(Pir_Bombers[10], 0, sel, 1);
		if j4 or j10 or FT_Names(c4) ~= FT_Names(Pir_Fighters[4]) then okn = nil; end;
		for r = 1, 20 do
			local tb = {Pir_Fighters[r], Pir_Bombers[r]};
			for q = 1, 2 do
				local cr, jr = TRF_FtRow(tb[q], 0, sel, 1);
				if jr then for k = 1, getn(tb[q]) do if tb[q][k][1] == cr[jr][1] then okn = nil; end; end; end;
			end;
		end;
	end;
	HOST_Check(okn, "captured: never a fit the row carries; rows with both fits of a pool get no captured ship");
	local np = TRF_FtRow(Pir_Fighters[12], 0, 37, 1);
	local same = FT_Names(np) == FT_Names(Pir_Fighters[12]);
	HOST_Check(same, "captured hit on a row without a pool: unchanged");
	local okp = 1;
	for k, alt in D.cap do
		for q = 1, getn(alt) do
			if abs(D.val[alt[q]] - D.val[k]) > 0.05 * D.val[k] or alt[q] == k then okp = nil; end;
		end;
	end;
	HOST_Check(okp, "every captured pool of the data within +-5 % of its fit");
	-- A raid row built with tinsert (field n): the copy has no n, the same entries.
	local rr = {};
	tinsert(rr, {"Stormcrow_pir1", 5, "A"}); tinsert(rr, {"Raptor_pir1", 1, "A"});
	local rc = TRF_FtRow(rr, 1, nil, nil);
	HOST_Check(rr.n == 2 and rc.n == nil and getn(rc) == 2 and rc[1][1] == "EvilEye_pir1" and rc[2][1] == "Bident_pir1" and rc[1][2] == 5,
		"a tinsert row: the copy without n, ranks kept");
	-- Digits.
	HOST_Check(TRF_FtDigit(0) == 0 and TRF_FtDigit(1) == 1 and TRF_FtDigit(-1) == 2 and TRF_FtDigit(1, 2) == 4 and TRF_FtDigit(-1, 1) == 5
		and TRF_Ft_Elite("1") and TRF_Ft_Elite("4") and not TRF_Ft_Elite("3") and not TRF_Ft_Elite(""), "grade digits 0..5, elite 1 and 4");
	-- Every fit of every row has a value; maps never point at the unused hulls.
	local okv = 1;
	for r = 1, 20 do
		for j = 1, getn(Pir_Fighters[r]) do if not D.val[Pir_Fighters[r][j][1]] then okv = nil; end; end;
		for j = 1, getn(Pir_Bombers[r]) do if not D.val[Pir_Bombers[r][j][1]] then okv = nil; end; end;
	end;
	for k, v in D.up do if strfind(v, "Panthera", 1, 1) or strfind(v, "Puma", 1, 1) or strfind(v, "TieFly", 1, 1) or strfind(v, "_mk2", 1, 1) then okv = nil; end; end;
	HOST_Check(okv and D.bare.Panthera_pir0 == 1, "values for every row fit; no unused hull in the maps; bare list has the pir0 hulls");
end;

-- c: haunt build, saved grade, kill cost ------------------------------------------------------------------------

function T_FT_C()
	local h = HOST();
	FT_Begin("xb13");
	local gs, gi = FT_Clan("golkonda", 3, 99);
	local pt, G = FT_FindPt("golkonda", 2, 0);
	HOST_Check(pt ~= nil, "a phase start with two elite flights in Golkonda (Raids, score 99)");
	if not pt then return; end;
	TRF.rg[gs].pt = pt;
	local snap = FT_PirSnap();
	local n0 = S_Mark();
	HA_Jump("golkonda");
	local d = HA_Data("golkonda");
	local e = TRF.nv and TRF.nv.e;
	local ok, el, bad = 1, {}, "";
	for i = 1, getn(d.f) do
		local R = G[i];
		local nf = h.nafs[d.f[i].s];
		if R and R.g == 1 then
			tinsert(el, i);
			local tab, form, ri = TRF_FtTab(d.f[i].t, d.f[i].p + 1);
			local want = TRF_FtRow(tab[ri], 1, R.c and R.sel, 1, R.nw);
			if not nf or FT_Names(nf.row) ~= FT_Names(want) or nf.group ~= "TRF_GHaunt_1" or nf.power ~= d.f[i].p + 1 then ok = nil; bad = bad.." "..i; end;
			if strsub(e or "", i, i) ~= "1" and strsub(e or "", i, i) ~= "4" then ok = nil; bad = bad.." e"..i; end;
		elseif R then
			if not R.c and strsub(e or "", i, i) ~= "0" then ok = nil; bad = bad.." z"..i; end;
		end;
	end;
	HOST_Check(ok and getn(el) >= 2, "elite flights built through NewAllFlight with the graded row at the haunt power in TRF_GHaunt_1, digits in TRF.nv.e "..tostring(e)..bad);
	HOST_Check(S_Logs(n0, "module=fits event=roll system=golkonda") == 10 and S_Logs(n0, "grade=1 captured_roll=") == getn(el)
		and S_Logs(n0, "module=fits event=row system=golkonda") >= getn(el), "one roll line per flight, a row line per graded flight");
	HOST_Check(FT_PirSnap() == snap, "the global Pir_Fighters / Pir_Bombers rows unchanged");
	HOST_Check(S_Logs(n0, "result=substituted") == 10 and HA_Kv(HA_Line(n0, "module=haunt event=activate "), "fielded") == "10", "ten flights fielded");
	local v = HA_V();
	local s0 = getglobal("ship_"..d.f[el[1]].s.."_1");
	HOST_Check(v.fl[el[1]] and s0 and v.fl[el[1]].ships[1] == s0 and s0.tpl == h.nafs[d.f[el[1]].s].row[1][1], "elite flight's globals and fits real");
	-- Kill cost: elite -3 (player fire), normal -2, the second elite only -1 (cap 6 per visit).
	local sc0 = TRF.clan[gs].sc;
	local ni = nil;
	for i = 1, getn(d.f) do if G[i] and G[i].g == 0 and not ni then ni = i; end; end;
	local n1 = S_Mark();
	HA_Kill(el[1], 1);
	local s1 = TRF.clan[gs].sc;
	HA_Kill(ni, 1);
	local s2 = TRF.clan[gs].sc;
	HA_Kill(el[2], 1);
	local s3 = TRF.clan[gs].sc;
	HOST_Check(sc0 - s1 == 3 and s1 - s2 == 2 and s2 - s3 == 1, "kills: elite -3, normal -2, the second elite -1 inside the -6 cap ("..sc0..","..s1..","..s2..","..s3..")");
	HOST_Check(S_Logs(n1, "module=fits event=kill system=golkonda") == 2 and S_Logs(n1, "reason=\"pirate kill haunt_elite\"") == 2,
		"event=kill per elite flight, the elite reason on the clan score line");
	-- Save and load: the digits stay (the dead flights' bits are 0, their digits kept).
	T_SaveLoad();
	HOST_Check(TRF.nv.e == e and HA_Kv(S_Line(n1, "module=haunt event=load "), "rearmed") == "7", "grade digits survive save and load");
	-- Without player fire: TRF_ClanAdd -3 in a new visit.
	HA_Jump("xb13");
	TRF.haunt = nil;
	TRF.clan[gs].sc = 99;
	HA_Jump("golkonda");
	local s4 = TRF.clan[gs].sc;
	HA_Kill(el[1], 0);
	HOST_Check(s4 - TRF.clan[gs].sc == 3, "elite kill without player fire: -3 ("..s4.." -> "..TRF.clan[gs].sc..")");
	-- haunt_mode 2: the replace site builds the graded rows too.
	HA_Jump("xb13");
	TRF.haunt = nil;
	TRF.clan[gs].sc = 99;
	HA_Set("haunt_mode", 2);
	h.nafs = {};
	n0 = S_Mark();
	HA_Jump("golkonda");
	local ok2 = 1;
	for q = 1, getn(el) do
		local i = el[q];
		local nf = h.nafs[d.f[i].s];
		local tab, form, ri = TRF_FtTab(d.f[i].t, d.f[i].p + 1);
		if not nf or FT_Names(nf.row) ~= FT_Names(TRF_FtRow(tab[ri], 1, G[i].c and G[i].sel, 1, G[i].nw)) or nf.group ~= "TRF_GHaunt_1" then ok2 = nil; end;
	end;
	HOST_Check(ok2 and HA_Kv(HA_Line(n0, "module=haunt event=replace "), "spawned") == "10" and TRF.nv.e == e, "haunt_mode 2: the rebuilt flights take the graded rows, same digits");
	HA_Set("haunt_mode", 1);
	-- A repair drops bad digits.
	TRF.nv.e = "9x";
	TRF_Haunt_Fix();
	HOST_Check(TRF.nv and TRF.nv.e == nil and TRF.nv.b ~= nil, "repair: bad digits dropped, the visit record kept");
	-- A captured-only flight (Raids, score 99) and a scrap flight (Boom, tier 2, score 30): the graded row through
	-- NewAllFlight in TRF_GHaunt_1, digit 3 (captured) or 2 / 5 (scrap) in TRF.nv.e, a kill costs -2.
	local cs = {{3, 99, "cap"}, {1, 30, "scrap"}};
	for q = 1, 2 do
		HA_Jump("xb13");
		TRF.haunt = nil;
		FT_Clan("golkonda", cs[q][1], cs[q][2]);
		local cp, ci, CR = FT_Find("golkonda", cs[q][3]);
		HOST_Check(cp ~= nil, "a phase start with a "..cs[q][3].." flight in Golkonda");
		if cp then
			TRF.rg[gs].pt = cp;
			h.nafs = {};
			HA_Jump("golkonda");
			local fq = d.f[ci];
			local tab, form, ri = TRF_FtTab(fq.t, fq.p + TRF_StrRow(TRF_EffTier(gi)).dp);
			local sel = nil;
			if CR.c then sel = CR.sel; end;
			local want, cj = TRF_FtRow(tab[ri], CR.g, sel, 1, CR.nw);
			local nf = h.nafs[fq.s];
			local ch = strsub(TRF.nv.e or "", ci, ci);
			local okd = (q == 1 and ch == "3" and cj) or (q == 2 and (ch == "2" or (ch == "5" and cj)));
			HOST_Check(nf and FT_Names(nf.row) == FT_Names(want) and FT_Names(want) ~= FT_Names(tab[ri]) and nf.group == "TRF_GHaunt_1" and okd,
				cs[q][3].." flight "..ci.." built with the graded row, digit "..ch..": "..FT_Names(want));
			local k0 = TRF.clan[gs].sc;
			HA_Kill(ci, 1);
			HOST_Check(k0 - TRF.clan[gs].sc == 2, cs[q][3].." flight kill: -2 ("..k0.." -> "..TRF.clan[gs].sc..")");
		end;
	end;
	HA_Jump("xb13");
end;

-- d: raids and garrisons -------------------------------------------------------------------------------------------

function T_FT_D()
	local h = HOST();
	FT_Begin("xb13");
	HA_Jump("golkonda");
	local gs, gi = FT_Clan("golkonda", 3, 80);
	local pt = TRF.rg[gs].pt;
	local tm = CreateTeam("Pirates");
	local grp = tm:CreateGroup("TRF_Raid_7");
	TRF_GRaid_7 = grp;
	local n0 = S_Mark();
	h.seed = 4242;
	local r0 = h.rand;
	local fls = TRF_Rd_Comp(7, {tier=4}, "TRF_GRaid_7", "trf_rd_7", Vector3(100, 0, 100), Vector3(0, 0, 1), 14, gi);
	local d1 = h.rand - r0;
	HOST_Check(type(fls) == "table" and getn(fls) == 2 and S_Logs(n0, "module=fits event=roll system=golkonda flight=raid_7_1 source=raid") == 1
		and S_Logs(n0, "flight=raid_7_2 source=raid") == 1 and S_Logs(n0, "module=fits event=roll ") == 2, "T4 raid: one roll per flight (2)");
	for i = 1, getn(fls) do fls[i]:Delete(); end;
	-- RAND draws with fits 0 are the same.
	HA_Set("fits", 0);
	h.seed = 4242;
	r0 = h.rand;
	n0 = S_Mark();
	fls = TRF_Rd_Comp(7, {tier=4}, "TRF_GRaid_7", "trf_rd_7", Vector3(100, 0, 100), Vector3(0, 0, 1), 14, gi);
	HOST_Check(h.rand - r0 == d1 and S_Logs(n0, "module=fits event=roll ") == 0, "fits 0: no roll, the same RAND draws ("..d1..")");
	for i = 1, getn(fls) do fls[i]:Delete(); end;
	-- A T2 raid draws RAND for fighters or bombers: the same draws with fits 1 and 0.
	TRF.clan[gs].sc = 30;
	local dr = {};
	for q = 0, 1 do
		HA_Set("fits", q);
		h.seed = 777;
		r0 = h.rand;
		n0 = S_Mark();
		fls = TRF_Rd_Comp(9, {tier=2}, "TRF_GRaid_7", "trf_rd_9", Vector3(100, 0, 100), Vector3(0, 0, 1), 8, gi);
		dr[q] = {h.rand - r0, S_Logs(n0, "module=fits event=roll system=golkonda flight=raid_9_1 source=raid score=30 tier=2 up=0 down=16 ")};
		if type(fls) == "table" then for i = 1, getn(fls) do fls[i]:Delete(); end; end;
	end;
	HOST_Check(dr[0][1] == dr[1][1] and dr[0][1] >= 1 and dr[1][2] == 1 and dr[0][2] == 0, "T2 raid: one roll (scrap chance 16 %), RAND draws "..dr[1][1].." with fits 1 = "..dr[0][1].." with fits 0");
	TRF.clan[gs].sc = 80;
	HA_Set("fits", 1);
	-- A captain's raid: no roll on any of its flights.
	n0 = S_Mark();
	fls = TRF_Rd_Comp(8, {tier=4, n1x=2, nosv=1}, "TRF_GRaid_7", "trf_rd_8", Vector3(100, 0, 100), Vector3(0, 0, 1), 14, gi);
	HOST_Check(type(fls) == "table" and getn(fls) == 2 and S_Logs(n0, "module=fits event=roll ") == 0, "captain's raid: no flight rolled");
	if type(fls) == "table" then for i = 1, getn(fls) do fls[i]:Delete(); end; end;
	-- An elite raid flight: graded row and pilots one rank up (lead, wing).
	TRF.clan[gs].sc = 99;
	local nn = nil;
	for n = 1, 3000 do
		if not nn and TRF_FtRoll(gi, 2 * n + 1, pt, gs, TRF_FtK().salt_raid, 4).g == 1 then nn = n; end;
	end;
	local gr = TRF_Ft_Grade(gi, 2 * nn + 1, "raid", "raid_x", 4);
	local row, pilots, form, p, lead, wing = TRF_Rd_PirRow(4, 14, 1, nil, gr);
	local row0, pil0, f0, p0, lead0, wing0 = TRF_Rd_PirRow(4, 14, 1, nil, nil);
	local b = TRF_Rd_TierRows()[4];
	HOST_Check(gr.g == 1 and lead == Pir_Pilots[min(5, b.lead + 1)] and wing == Pir_Pilots[min(5, b.wing + 1)] and lead0 == Pir_Pilots[b.lead]
		and getn(row) == getn(row0) and row[1][1] == (TRF_FtD().up[row0[1][1]] or row0[1][1]) and row[1][2] == 5 and row[2][2] == 1,
		"elite raid flight: graded row (ranks 5 / 1 kept), lead and wing pilots one rank up: "..FT_Names(row));
	-- TRF_PirFlight with the elite grade and maxn 2: the trimmed flight keeps the graded fits and the lead one rank up.
	local tf = TRF_PirFlight(4, 14, "TRF_GRaid_7", "trf_rd_t", Vector3(100, 0, 100), Vector3(0, 0, 1), 1, 2, nil, gr);
	local okt = tf and getn(tf.ships) == 2;
	for k = 1, 2 do if not okt or tf.ships[k].tpl ~= row[k][1] then okt = nil; end; end;
	HOST_Check(okt and tf.ships[1].pilot.tpl == lead and row[2][1] ~= row0[2][1], "TRF_PirFlight maxn 2: the graded fits kept after the trim, lead one rank up");
	if tf then tf:Delete(); end;
	-- Garrison through TRF_PirFlight: TRF_Ba_ClanFlight rolls the slot, a salvaged flight is not rolled.
	local oh = TRF_Ba_H;
	TRF_Ba_H = function() return {grp=HOST_Group("TRF_PBase_9", "Pirates")}; end;
	n0 = S_Mark();
	local fl = TRF_Ba_ClanFlight(gi, 4, 14, 2, Vector3(0, 0, 0), Vector3(0, 0, 1), nil);
	TRF_Ba_H = oh;
	HOST_Check(fl and S_Logs(n0, "module=fits event=roll system=golkonda flight=trf_pb_"..gi.."_2 source=base") == 1, "garrison: one roll for its slot");
	if fl then fl:Delete(); end;
	-- An elite garrison slot: the built flight carries the up-mapped fits and the lead one rank up.
	local gj = nil;
	for j = 1, 400 do
		if not gj and TRF_FtRoll(gi, j, pt, gs, TRF_FtK().salt_base, 4).g == 1 then gj = j; end;
	end;
	HOST_Check(gj ~= nil, "an elite garrison slot at score 99");
	if gj then
		TRF_Ba_H = function() return {grp=HOST_Group("TRF_PBase_9", "Pirates")}; end;
		h.seed = 515;
		local gf = TRF_Ba_ClanFlight(gi, 4, 14, gj, Vector3(0, 0, 0), Vector3(0, 0, 1), nil);
		TRF_Ba_H = oh;
		h.seed = 515;
		local g2 = TRF_Ft_Grade(gi, gj, "base", "trf_pb_"..gi.."_"..gj, 4);
		local wr, wp, wf, wq, wl = TRF_Rd_PirRow(4, 14, nil, nil, g2);
		h.seed = 515;
		local w0 = TRF_Rd_PirRow(4, 14, nil, nil, nil);
		local okg = gf and g2.g == 1 and getn(gf.ships) == getn(wr) and FT_Names(wr) ~= FT_Names(w0);
		for k = 1, getn(wr) do
			if not okg or gf.ships[k].tpl ~= wr[k][1] then okg = nil; end;
		end;
		HOST_Check(okg and gf.ships[1].pilot.tpl == wl and wl == Pir_Pilots[min(5, b.lead + 1)],
			"elite garrison: the graded fits "..FT_Names(wr).." (vanilla "..FT_Names(w0).."), lead one rank up");
		if gf then gf:Delete(); end;
	end;
	-- Determinism of the garrison slot: the same grade again.
	local R1, R2 = TRF_FtRoll(gi, 2, pt, gs, TRF_FtK().salt_base, 4), TRF_FtRoll(gi, 2, pt, gs, TRF_FtK().salt_base, 4);
	HOST_Check(R1.r == R2.r and R1.g == R2.g, "garrison slot roll fixed for the phase");
	TRF_GRaid_7 = nil;
	HA_Jump("xb13");
end;

-- e: quest-gated visit -------------------------------------------------------------------------------------------------

function T_FT_E()
	local h = HOST();
	FT_Begin("hanoi");
	local ks, ki = FT_Clan("kadi", 3, 99);
	local pt = FT_FindPt("kadi", 0, 2, 1);
	HOST_Check(pt ~= nil, "a phase start with two captured flights in Kadi");
	if not pt then return; end;
	TRF.rg[ks].pt = pt;
	local G = FT_Grades("kadi", pt, 1);
	local qi = TRF_DenyQ(ki);
	h.quests[qi[1]] = QUEST_PROCESS;
	local n0 = S_Mark();
	h.nafs = {};
	HA_Jump("kadi");
	local d = HA_Data("kadi");
	HOST_Check(HA_Kv(HA_Line(n0, "module=haunt event=mode "), "reason") == "gate_quest", "Kadi with a quest in process: gate_quest");
	local ok, nb, bad = 1, 0, "";
	for i = 1, getn(d.f) do
		local R = G[i];
		local nf = h.nafs[d.f[i].s];
		local fl = getglobal("flight_"..d.f[i].s);
		if not fl or fl.group.name ~= d.g then ok = nil; bad = bad.." g"..i; end;
		if R and R.c then
			local tab, form, ri = TRF_FtTab(d.f[i].t, d.f[i].p);
			local want, cj = TRF_FtRow(tab[ri], 0, R.sel, nil, R.nw);
			if cj then
				nb = nb + 1;
				if not nf or FT_Names(nf.row) ~= FT_Names(want) or nf.power ~= d.f[i].p or nf.group ~= d.g then ok = nil; bad = bad.." r"..i; end;
				if abs(FT_Val(want) - FT_Val(tab[ri])) > 0.05 * FT_Val(tab[ri]) then ok = nil; bad = bad.." v"..i; end;
			end;
		end;
	end;
	HOST_Check(ok and nb >= 2, "gate visit: captured rows in the vanilla group at the vanilla power, value within 5 % ("..nb.." flights)"..bad);
	HOST_Check(S_Logs(n0, "module=fits event=roll system=kadi") == 13 and S_Logs(n0, "source=gate") == 13 and S_Logs(n0, " up=0 down=0 ") == 13
		and S_Logs(n0, "grade=1") == 0 and S_Logs(n0, "grade=-1") == 0, "gate rolls: no elite, no scrap");
	HOST_Check(HA_Kv(S_Line(n0, "module=fits event=gate "), "built") == tostring(nb) and S_Logs(n0, "module=haunt event=call") == 0
		and S_Logs(n0, "module=haunt event=activate") == 0, "gate line built="..nb.."; no haunt call or activate line");
	HOST_Check(TRF.nv == nil and HA_Trigs("f_died", "TRF_Haunt_Died(") == 0 and TRF_HaHA().a == nil and HA_V().fl[1] == nil, "no TRF.nv, no triggers, the record disarmed");
	-- fits_gate 1: vanilla rows.
	HA_Jump("hanoi");
	HA_Set("fits_gate", 1);
	n0 = S_Mark();
	HA_Jump("kadi");
	HOST_Check(S_Logs(n0, "module=fits event=roll") == 0 and S_Logs(n0, "module=fits event=skip system=kadi reason=gate via=fits_gate") == 1,
		"fits_gate 1: no roll, skip reason=gate");
	HA_Set("fits_gate", 0);
	-- The scan's deny list.
	HA_Jump("hanoi");
	local od = TRF_FtGateDeny;
	n0 = S_Mark();
	HA_Jump("kadi", {pre=function() TRF_FtGateDeny = function() return {kadi=1}; end; end});
	TRF_FtGateDeny = od;
	HOST_Check(S_Logs(n0, "module=fits event=roll") == 0 and S_Logs(n0, "reason=gate via=scan") == 1, "a deny-listed system keeps vanilla rows");
	-- A quest scene at entry (__disableAction): gate_quest, but no fits record and no captured flight.
	HA_Jump("hanoi");
	h.nafs = {};
	n0 = S_Mark();
	HA_Jump("kadi", {pre=function() __disableAction = TRUE; end});
	__disableAction = nil;
	local nn = 0;
	for i = 1, getn(d.f) do
		local nf = h.nafs[d.f[i].s];
		local tab, form, ri = TRF_FtTab(d.f[i].t, d.f[i].p);
		if nf and tab and FT_Names(nf.row) ~= FT_Names(tab[ri]) then nn = nn + 1; end;
	end;
	HOST_Check(HA_Kv(HA_Line(n0, "module=haunt event=mode "), "reason") == "gate_quest" and S_Logs(n0, "module=fits event=roll") == 0
		and S_Logs(n0, "module=fits event=gate") == 0 and nn == 0, "quest scene at a gate_quest entry: no roll, no captured flight");
	h.quests[qi[1]] = QUEST_DONE;
	HA_Jump("hanoi");
end;

-- f: fits 0 identical, debug test ship, save bytes -------------------------------------------------------------------

function T_FT_F()
	local h = HOST();
	FT_Begin("xb13", {fits=0});
	local gs, gi = FT_Clan("golkonda", 2, 62);
	TRF.rg[gs].pt = 5;
	local n0 = S_Mark();
	h.seed = 99; local r0 = h.rand;
	HA_Jump("golkonda");
	local L0, d0 = FT_Lines(n0, "module=haunt event=call "), h.rand - r0;
	HOST_Check(S_Logs(n0, "module=fits event=skip system=golkonda") == 10 and HA_Has(S_Line(n0, "module=fits event=skip "), "reason=off")
		and S_Logs(n0, "module=fits event=roll") == 0 and TRF.nv.e == nil, "fits 0: skip reason=off per flight, no roll, no digits");
	HA_Jump("xb13");
	TRF.haunt = nil;
	local ofn = TRF_Ft_Haunt;
	TRF_Ft_Haunt = nil;
	n0 = S_Mark();
	h.seed = 99; r0 = h.rand;
	HA_Jump("golkonda", {pre=function() TRF_Ft_Haunt = nil; end});
	local L1, d1 = FT_Lines(n0, "module=haunt event=call "), h.rand - r0;
	TRF_Ft_Haunt = ofn;
	HOST_Check(L0 == L1 and L0 ~= "" and d0 == d1, "fits 0: the haunt call lines byte-identical to a run without trf_fits, same RAND draws");
	-- fits 1 at a phase start where no flight is graded or captured: the same lines again.
	HA_Jump("xb13");
	TRF.haunt = nil;
	HA_Set("fits", 1);
	local qp = nil;
	for pt = 1, 4000 do
		local G, e, c = FT_Grades("golkonda", pt);
		local any = nil;
		for i = 1, 10 do if G[i] and (G[i].g ~= 0 or G[i].c) then any = 1; end; end;
		if not any and not qp then qp = pt; end;
	end;
	TRF.rg[gs].pt = qp;
	h.nafs = {};
	n0 = S_Mark();
	HA_Jump("golkonda");
	local L2 = FT_Lines(n0, "module=haunt event=call ");
	HOST_Check(qp and L2 == L0 and TRF.nv.e == nil and S_Logs(n0, "module=fits event=row") == 0, "fits 1 with every grade 0: identical call lines, the vanilla builder, no digits");
	-- Save bytes: the worst-case digit string.
	local z0 = HOST_SaveSize(TRF.nv);
	TRF.nv.e = strrep("4", 31);
	local z1 = HOST_SaveSize(TRF.nv);
	print("HOST info fits worst case: nv without e="..z0.." with 31 digits="..z1.." (+"..(z1 - z0)..")");
	HOST_Check(z1 - z0 <= 50, "31 grade digits add "..(z1 - z0).." bytes (<= 50)");
	TRF.nv.e = nil;
	-- Debug test ship: a bare carcass gets the modules, the HP is logged, 2 s later the TRF_Carcasses record.
	HA_Jump("xb13");
	HA_Set("fits_test", "Panthera_pir0");
	TRF_Carcasses = HOST_Carcasses;
	h.carc = {};
	n0 = S_Mark();
	local m0 = getn(h.mods);
	HA_Jump("golkonda");
	local tf = TRF_H().ft;
	HOST_Check(tf and tf.s and tf.s.tpl == "Panthera_pir0" and S_Logs(n0, "module=fits event=test name=Panthera_pir0 step=create result=ok") == 1
		and S_Logs(n0, "step=hull bare=true hp=1000") == 1 and S_Logs(n0, "step=add_module module=PC2 ret=PC2 hp=1000") == 1
		and S_Logs(n0, "step=add_module module=ShAmp3 ") == 1 and getn(h.mods) - m0 == 3, "test ship: created, three AddModule calls logged with return value and HP");
	local ms = TRF_Ms():GetPosition();
	HOST_Check(abs(tf.s.pos.z - (ms.z + 200)) < 1 and abs(tf.s.pos.x - ms.x) < 1, "200 units ahead of the mothership");
	local neu = 0;
	for i = 1, getn(h.rel) do if h.rel[i][1] == "TRF_FtTest" and h.rel[i][3] == RELATION_NEUTRAL then neu = neu + 1; end; end;
	HOST_Check(neu == 1 and tf.fl.group.team == "Pirates", "neutral to the player, team Pirates");
	tf.s.id = 4711;
	h.carc = {{id=4711, cls=6, tpl="Panthera_pir0", team="Pirates", hp=588, hpmax=600, x=0, y=0, z=0}};
	n0 = S_Mark();
	T_Tick(2, 0.5);
	HOST_Check(S_Logs(n0, "step=read") == 0, "no read before 2 s");
	T_Tick(4, 0.5);
	HOST_Check(S_Logs(n0, "module=fits event=test name=Panthera_pir0 step=read result=ok tpl=Panthera_pir0 cls=6 hp=588 hpmax=600") == 1
		and S_Logs(n0, "step=read") == 1, "2 s later: the TRF_Carcasses record (tpl, hp) once");
	-- Jump deletes it; a ShipDescription name has no AddModule; without the native: no_native.
	HA_Jump("xb13");
	HOST_Check(not tf.s.alive and TRF_H().ft ~= tf, "jump: the test flight deleted");
	TRF_Carcasses = nil;
	HA_Set("fits_test", "Gunslinger_pir1");
	n0 = S_Mark();
	m0 = getn(h.mods);
	HA_Jump("golkonda");
	T_Tick(6, 0.5);
	HOST_Check(S_Logs(n0, "step=hull bare=false") == 1 and getn(h.mods) == m0 and S_Logs(n0, "step=read result=no_native") == 1,
		"a ShipDescription: no AddModule; no native: result=no_native");
	HA_Set("fits_test", "");
	HA_Jump("xb13");
	h.carc = nil;
end;

-- g: step 2 data, the R2 filter, the gate, fits_new 0 ----------------------------------------------------------------

-- Holders of the new fits' carcasses (clone Data/Game/Carcasses.xml HolderProperties: b big guns, s small guns, r rockets,
-- y systems) and the holder kind of each module the new fits use (Modules.xml class), a second source beside gen_fits.py.
function FT_S2()
	return {hold={Stormcrow_pir0={b=1, s=0, r=1, y=2}, Cleaner_pir0={b=2, s=0, r=0, y=2}, Raptor_pir0={b=0, s=4, r=0, y=3},
	Hammerhead_pir0={b=0, s=2, r=2, y=1}, TieFly_pir0={b=0, s=2, r=1, y=2}, Stormcrow_mk2_pir0={b=2, s=0, r=1, y=2},
	EvilEye_pir0={b=1, s=0, r=1, y=3}, Tiger_pir0={b=2, s=0, r=0, y=3}, Bident_pir0={b=0, s=2, r=4, y=2},
	Cleaner_mk2_pir0={b=2, s=0, r=1, y=3}, Panthera_pir0={b=2, s=0, r=0, y=3}, Puma_pir0={b=2, s=0, r=1, y=3}},
	kind={HC2="b", LC1="b", LC2="b", PC1="b", PC2="b", VC1="b", VC2="b", VC3="b", AC1="s", CG1="s", SRM1="r", SRM2="r",
	SRM3="r", LRM1="r", LRM2="r", MM="r", SM3="r", ECM1="y", ECM2="y", ECM3="y", AMS1="y", AMS2="y", ShAmp1="y", ShAmp2="y",
	EngAmp1="y", EngAmp2="y"},
	unused={TieFly_pir0=1, Stormcrow_mk2_pir0=1, Cleaner_mk2_pir0=1}, boss={Panthera_pir0=1, Puma_pir0=1},
	-- The captured pools of step 1 (fits-spec 3.3), the reference for fits_new 0.
	cap1={Bident_pir1={"Hatchet_pir1"}, Brigand_pir1={"Yari_pir1"}, Hatchet_pir1={"Bident_pir1"}, Yari_pir1={"Brigand_pir1"}}};
end;

-- Captured ship of row r (rk 1) for selector sel at pool level nw: the copy, its index and the new fit name or nil.
function FT_Cap(r, sel, nw)
	local out, cj, dr = TRF_FtRow(r, 0, sel, 1, nw);
	local nm = nil;
	if dr and cj then nm = dr[cj]; end;
	return out, cj, nm;
end;

-- First phase start leg 1..4000 and flight index of system nm (haunt power) whose captured ship is a new fit (hull 1: on
-- an unused hull, else on an existing hull). Returns pt, i, the roll record, the graded row, the new fit name, its index.
function FT_FindNew(nm, hull)
	local d = HA_Data(nm);
	local dp = TRF_StrRow(TRF_EffTier(V_Idx(nm))).dp;
	local N = TRF_FtD().new;
	for pt = 1, 4000 do
		local G = FT_Grades(nm, pt);
		for i = 1, getn(d.f) do
			local R = G[i];
			if R and R.c then
				local tab, form, ri = TRF_FtTab(d.f[i].t, d.f[i].p + dp);
				local row, cj, dr = TRF_FtRow(tab[ri], R.g, R.sel, 1, R.nw);
				if dr and cj and ((hull == 1) == (N[dr[cj]].h == 1)) then return pt, i, R, row, dr[cj], cj; end;
			end;
		end;
	end;
	return nil;
end;

function T_FT_G()
	FT_Begin("xb13");
	local D = TRF_FtD();
	local S2 = FT_S2();
	-- Every new fit: a bare pirate carcass, known modules, at most the holders of each kind, the h / b flags.
	local okh, nn, bad = 1, 0, "";
	for nm, e in D.new do
		nn = nn + 1;
		local H = S2.hold[e.c];
		local cnt = {b=0, s=0, r=0, y=0};
		if not H or D.bare[e.c] ~= 1 or type(e.m) ~= "table" or getn(e.m) == 0 or not D.val[nm] then
			okh = nil; bad = bad.." "..nm;
		else
			for k = 1, getn(e.m) do
				local q = S2.kind[e.m[k]];
				if not q then okh = nil; bad = bad.." "..nm..":"..e.m[k]; else cnt[q] = cnt[q] + 1; end;
			end;
			for q, v in cnt do if v > H[q] then okh = nil; bad = bad.." "..nm..":"..q; end; end;
		end;
		if (e.h == 1) ~= (S2.unused[e.c] == 1) or (e.b == 1) ~= (S2.boss[e.c] == 1) then okh = nil; bad = bad.." flag:"..nm; end;
	end;
	HOST_Check(okh and nn == 14, "14 new fits, each on a bare pirate carcass within its holders, unused hulls h=1, boss hulls b=1"..bad);
	-- Pools: every entry within 5 %; every new fit but the boss fits in a pool, the boss fits in none; no new fit is a pool
	-- key or in the up / dn maps (R1, R3).
	local inp, okp = {}, 1;
	for k, alt in D.cap do
		if D.new[k] then okp = nil; end;
		for q = 1, getn(alt) do
			if abs(D.val[alt[q]] - D.val[k]) > 0.05 * D.val[k] then okp = nil; end;
			inp[alt[q]] = 1;
		end;
	end;
	for nm, e in D.new do
		if (e.b == 1 and inp[nm]) or (e.b ~= 1 and not inp[nm]) then okp = nil; bad = bad.." pool:"..nm; end;
	end;
	for k, v in D.up do if D.new[k] or D.new[v] then okp = nil; end; end;
	for k, v in D.dn do if D.new[k] or D.new[v] then okp = nil; end; end;
	HOST_Check(okp and D.new.Panthera_pir1.b == 1 and D.new.Puma_pir1.b == 1, "pools within 5 %; new fits only as pool entries, boss fits in no pool or map"..bad);
	-- The XT band (NORMAL powers 7-16, rows 6-13): every fighter row and the bomber rows with an EvilEye_pir1 (11-13; rows
	-- 6-10 carry Hammerhead, Hatchet, Excalibur and Bident) get a captured new fit for some selector; step 1 had pools in
	-- fighter rows 7, 8 only.
	local fr, br = 0, 0;
	for r = 6, 13 do
		local hf, hb = nil, nil;
		for sel = 0, 99 do
			local a, j, nm = FT_Cap(Pir_Fighters[r], sel, 1);
			if nm then hf = 1; end;
			a, j, nm = FT_Cap(Pir_Bombers[r], sel, 1);
			if nm then hb = 1; end;
		end;
		if hf then fr = fr + 1; end;
		if hb then br = br + 1; end;
	end;
	HOST_Check(fr == 8 and br == 3, "XT band: "..fr.." of 8 fighter rows and "..br.." of 8 bomber rows (6-13) can carry a captured new fit");
	-- R2: the pool selector. nw 0 no new fit, nw 1 no unused hull, nw 2 both; a captured ship is one ship, never a fit
	-- the row carries, and a new fit enters as its bare carcass.
	local l0, l1, l2 = TRF_FtLeft(D.cap.Raptor_pir1, {}, 0), TRF_FtLeft(D.cap.Raptor_pir1, {}, 1), TRF_FtLeft(D.cap.Raptor_pir1, {}, 2);
	local hasT = nil;
	for q = 1, getn(l2) do if l2[q] == "TieFly_pir1" then hasT = 1; end; end;
	local noT = 1;
	for q = 1, getn(l1) do if l1[q] == "TieFly_pir1" then noT = nil; end; end;
	HOST_Check(getn(l0) == 0 and getn(l1) == 3 and noT and getn(l2) == 4 and hasT, "pool filter: nw 0 none, nw 1 no unused hull, nw 2 with TieFly_pir1");
	local okr, nh1, nh2, nbare = 1, 0, 0, 1;
	for r = 1, 20 do
		local tb = {Pir_Fighters[r], Pir_Bombers[r]};
		for q = 1, 2 do
			for sel = 0, 99 do
				local o1, j1, m1 = FT_Cap(tb[q], sel, 1);
				local o2, j2, m2 = FT_Cap(tb[q], sel, 2);
				if m1 and D.new[m1].h == 1 then okr = nil; end;
				if m1 then nh1 = nh1 + 1; end;
				if m2 and D.new[m2].h == 1 then nh2 = nh2 + 1; end;
				if m2 and o2[j2][1] ~= D.new[m2].c then nbare = nil; end;
				local diff = 0;
				for k = 1, getn(tb[q]) do if o2[k][1] ~= tb[q][k][1] then diff = diff + 1; end; end;
				if (j2 and diff ~= 1) or (not j2 and diff ~= 0) then okr = nil; end;
			end;
		end;
	end;
	HOST_Check(okr and nbare and nh1 > 0 and nh2 > 0, "nw 1 never an unused hull ("..nh1.." new-fit picks), nw 2 picks one ("..nh2..
		"); one ship at most, the bare carcass in the row");
	-- The roll: pool 1 at tiers 1-2, 2 at tiers 3-4 exactly when r3 < fits_hull_pct (50); r3 is the hash at i + 192, salt + 3.
	local gs, gi = FT_Clan("golkonda", 3, 99);
	local pt = 77;
	local okn, n34, h34 = 1, 0, 0;
	for t = 1, 4 do
		for i = 1, 1000 do
			local R = TRF_FtRoll(gi, i, pt, gs, 1, t);
			if R.r3 ~= TRF_FtHash(gi, i + 192, pt, 4) then okn = nil; end;
			if t <= 2 and R.nw ~= 1 then okn = nil; end;
			if t >= 3 then
				n34 = n34 + 1;
				if (R.nw == 2) ~= (R.r3 < 50) then okn = nil; end;
				if R.nw == 2 then h34 = h34 + 1; end;
			end;
		end;
	end;
	HOST_Check(okn and h34 >= 0.45 * n34 and h34 <= 0.55 * n34, "pool level: 1 at tiers 1-2, 2 at tiers 3-4 iff r3 < 50 ("..h34.." of "..n34..")");
	-- A Boom clan (tier 2): no phase start of Golkonda places an unused hull; a Raids clan (tier 4): one does.
	FT_Clan("golkonda", 1, 30);
	local b2 = FT_FindNew("golkonda", 1);
	local n2 = FT_FindNew("golkonda", 0);
	FT_Clan("golkonda", 3, 99);
	local b4 = FT_FindNew("golkonda", 1);
	HOST_Check(b2 == nil and n2 ~= nil and b4 ~= nil, "tier 2: new fits on existing hulls only, never an unused hull; tier 4: unused hulls appear");
	-- Tune: fits_hull_pct 0 / 100 and the clamps; fits_new 0 gives pool level 0.
	HA_Tune("fits_hull_pct", 0);
	local z0 = 1;
	for i = 1, 300 do if TRF_FtRoll(gi, i, pt, gs, 1, 4).nw ~= 1 then z0 = nil; end; end;
	HA_Tune("fits_hull_pct", 100);
	local z1 = 1;
	for i = 1, 300 do if TRF_FtRoll(gi, i, pt, gs, 1, 4).nw ~= 2 then z1 = nil; end; end;
	HA_Tune("fits_hull_pct", 150); HA_Tune("fits_new", 7);
	local T1 = TRF_FtTune();
	HA_Tune("fits_hull_pct", -5); HA_Tune("fits_new", -1);
	local T2 = TRF_FtTune();
	HOST().cfg.tune = {};
	local T0 = TRF_FtTune();
	HOST_Check(z0 and z1 and T1.fits_hull_pct == 100 and T1.fits_new == 1 and T2.fits_hull_pct == 0 and T2.fits_new == 0
		and T0.fits_hull_pct == 50 and T0.fits_new == 1 and TRF_Tune().fits_hull_pct == 50, "fits_hull_pct 0 / 100, clamps 0..100 and 0..1, defaults 50 and 1");
	-- The gate (quest-gated visit): pool level 0, so no new fit and no dress for any row and selector.
	local okg = 1;
	for i = 1, 200 do if TRF_FtRoll(gi, i, pt, gs, 41, 4, 1).nw ~= 0 then okg = nil; end; end;
	for r = 1, 20 do
		for sel = 0, 99 do
			local a, j, nm = FT_Cap(Pir_Fighters[r], sel, 0);
			local b, k, nb = FT_Cap(Pir_Bombers[r], sel, 0);
			if nm or nb then okg = nil; end;
		end;
	end;
	HOST_Check(okg, "gate rolls: pool level 0, existing fits only, no dress");
	-- fits_new 0: the step 1 rows for every row and selector (data with the step 1 pools as the reference).
	HA_Tune("fits_new", 0);
	local okz = 1;
	for i = 1, 100 do if TRF_FtRoll(gi, i, pt, gs, 1, 4).nw ~= 0 then okz = nil; end; end;
	local cur = {};
	for r = 1, 20 do
		for sel = 0, 99 do
			local a, j, nm = FT_Cap(Pir_Fighters[r], sel, 0);
			local b, k, nb = FT_Cap(Pir_Bombers[r], sel, 0);
			cur[r * 100 + sel] = FT_Names(a).."/"..tostring(j).."|"..FT_Names(b).."/"..tostring(k);
			if nm or nb then okz = nil; end;
		end;
	end;
	local h = TRF_H();
	local D1 = {up=D.up, dn=D.dn, cap=S2.cap1, val=D.val, bare=D.bare};
	h.ftd = D1;
	for r = 1, 20 do
		for sel = 0, 99 do
			local a, j = TRF_FtRow(Pir_Fighters[r], 0, sel, 1);
			local b, k = TRF_FtRow(Pir_Bombers[r], 0, sel, 1);
			if cur[r * 100 + sel] ~= FT_Names(a).."/"..tostring(j).."|"..FT_Names(b).."/"..tostring(k) then okz = nil; end;
		end;
	end;
	h.ftd = nil;
	HOST().cfg.tune = {};
	HOST_Check(okz, "fits_new 0: pool level 0 and the captured rows of the step 1 pools for every row and selector");
	-- Shares (info for spec 14.4): over phase starts 1..400 of four haunt systems at Raids score 99 (tier 4) and Boom score
	-- 30 (tier 2), the flights whose captured ship is a new fit on an existing hull and those with an unused hull.
	local sy = {"golkonda", "xb13", "escaflon", "xt54"};
	for q = 1, 2 do
		local nf, nn, nu = 0, 0, 0;
		for k = 1, getn(sy) do
			if q == 1 then FT_Clan(sy[k], 3, 99); else FT_Clan(sy[k], 1, 30); end;
			local dk = HA_Data(sy[k]);
			local dp = TRF_StrRow(TRF_EffTier(V_Idx(sy[k]))).dp;
			for p2 = 1, 400 do
				local G = FT_Grades(sy[k], p2);
				for i = 1, getn(dk.f) do
					local R = G[i];
					if R then
						nf = nf + 1;
						if R.c then
							local tab, form, ri = TRF_FtTab(dk.f[i].t, dk.f[i].p + dp);
							local o, j, dr = TRF_FtRow(tab[ri], R.g, R.sel, 1, R.nw);
							if dr and j then
								if D.new[dr[j]].h == 1 then nu = nu + 1; else nn = nn + 1; end;
							end;
						end;
					end;
				end;
			end;
		end;
		print(format("HOST info fits step 2 shares (%s): %d graded flights, new fit on an existing hull %.2f %%, unused hull %.2f %%",
			q == 1 and "tier 4" or "tier 2", nf, 100 * nn / nf, 100 * nu / nf));
		if q == 2 then HOST_Check(nu == 0, "tier 2 share: no unused hull in "..nf.." flights"); end;
	end;
	FT_Clan("golkonda", 3, 99);
	-- The roll line carries pool= (old, new, hull).
	local n0 = S_Mark();
	TRF_Ft_Grade(gi, 1, "haunt", "x1", 2);
	TRF_Ft_Grade(gi, 1, "gate", "x2", 4, 1);
	HOST_Check(S_Logs(n0, "flight=x1 source=haunt") == 1 and HA_Kv(S_Line(n0, "flight=x1 "), "pool") == "new"
		and HA_Kv(S_Line(n0, "flight=x2 "), "pool") == "old" and TRF_FtPool(2) == "hull", "event=roll pool=new at tier 2, old in a gate roll, hull for level 2");
end;

-- h: build and dress -------------------------------------------------------------------------------------------------

-- Index of the first log line after n0 with pat, or nil.
function FT_At(n0, pat)
	local q = HOST().logs;
	for i = n0 + 1, getn(q) do if strfind(q[i], pat, 1, 1) then return i; end; end;
	return nil;
end;

-- Modules fitted on ship s (the stub's list) joined with ",".
function FT_Mods(s)
	if type(s) == "table" and type(s.modl) == "table" then return FT_Join(s.modl); end;
	return "";
end;

function FT_Join(l)
	local x = "";
	for k = 1, getn(l) do if k > 1 then x = x..","; end; x = x..l[k]; end;
	return x;
end;

function T_FT_H()
	local h = HOST();
	FT_Begin("xb13");
	local D = TRF_FtD();
	local gs, gi = FT_Clan("golkonda", 3, 99);
	local d = HA_Data("golkonda");
	-- A captured new fit on an existing hull through the haunt build (NewAllFlight with the bare carcass name), dressed by
	-- AddModule right after the build and before the flight's call line.
	local pt, i, R, row, nm, cj = FT_FindNew("golkonda", 0);
	HOST_Check(pt ~= nil, "a phase start with a captured new fit in Golkonda (Raids, score 99)");
	if not pt then return; end;
	local e = D.new[nm];
	local sign = d.f[i].s;
	TRF.rg[gs].pt = pt;
	local n0 = S_Mark();
	local m0 = getn(h.mods);
	HA_Jump("golkonda");
	local nf = h.nafs[sign];
	local s = getglobal("ship_"..sign.."_"..cj);
	local want = "module=fits event=dress system=golkonda flight="..sign.." ship="..cj.." fit="..nm.." carcass="..e.c.." hull=false modules="..getn(e.m)
		.." ok="..getn(e.m).." failed=none";
	HOST_Check(nf and nf.row[cj][1] == e.c and FT_Names(nf.row) == FT_Names(row) and s and s.tpl == e.c and FT_Mods(s) == FT_Join(e.m),
		"captured "..nm.." built as the bare "..e.c.." in NewAllFlight, its modules fitted in order: "..FT_Mods(s));
	local ad, ac = FT_At(n0, want), FT_At(n0, "module=haunt event=call sign="..sign.." ");
	HOST_Check(S_Logs(n0, want) == 1 and ad and ac and ad < ac and getn(h.mods) - m0 == getn(e.m)
		and S_Logs(n0, "new_fit="..nm) == 1, "event=dress ok="..getn(e.m).." failed=none before the flight's call line; one AddModule per module");
	local ch = strsub(TRF.nv.e or "", i, i);
	HOST_Check((ch == "3" or ch == "4" or ch == "5") and HA_Kv(HA_Line(n0, "module=haunt event=activate "), "fielded") == "10"
		and HA_Kv(HA_Line(n0, "module=haunt event=activate "), "failed") == "0", "grade digit "..ch.." (captured +3), ten flights fielded, none failed");
	-- A nil AddModule return: logged at level 1 with the first failing module, the rest still fitted, no retry, the ship kept.
	HA_Jump("xb13");
	TRF.haunt = nil;
	TRF.clan[gs].sc = 99;
	HA_Set("log", 1);
	h.am_nil = {};
	h.am_nil[e.m[2]] = 1;
	n0 = S_Mark();
	m0 = getn(h.mods);
	HA_Jump("golkonda");
	s = getglobal("ship_"..sign.."_"..cj);
	local fl = "module=fits event=dress system=golkonda flight="..sign.." ship="..cj.." fit="..nm.." carcass="..e.c.." hull=false modules="..getn(e.m)
		.." ok="..(getn(e.m) - 1).." failed="..e.m[2];
	HOST_Check(S_Logs(n0, fl) == 1 and getn(h.mods) - m0 == getn(e.m) and s and s.alive and s.tpl == e.c and getn(s.modl or {}) == getn(e.m) - 1
		and HA_Kv(HA_Line(n0, "module=haunt event=activate "), "fielded") == "10", "AddModule nil for "..e.m[2]..": failed= logged at log 1, no retry, the ship flies partly dressed");
	h.am_nil = nil;
	HA_Jump("xb13");
	TRF.haunt = nil;
	TRF.clan[gs].sc = 99;
	n0 = S_Mark();
	HA_Jump("golkonda");
	HOST_Check(S_Logs(n0, "module=fits event=dress ") == 0 and getn(getglobal("ship_"..sign.."_"..cj).modl or {}) == getn(e.m), "a clean dress is level 2 (no line at log 1)");
	HA_Set("log", 2);
	-- An unused hull at tier 4: hull=true on the dress line, the flight's roll line has tier=4 pool=hull.
	HA_Jump("xb13");
	TRF.haunt = nil;
	TRF.clan[gs].sc = 99;
	local hp, hi, HR, hrow, hnm, hj = FT_FindNew("golkonda", 1);
	HOST_Check(hp ~= nil, "a phase start with an unused hull in Golkonda");
	if hp then
		TRF.rg[gs].pt = hp;
		n0 = S_Mark();
		HA_Jump("golkonda");
		local hs = d.f[hi].s;
		local he = D.new[hnm];
		local sh = getglobal("ship_"..hs.."_"..hj);
		HOST_Check(S_Logs(n0, "module=fits event=dress system=golkonda flight="..hs.." ship="..hj.." fit="..hnm.." carcass="..he.c.." hull=true ") == 1
			and S_Logs(n0, "module=fits event=roll system=golkonda flight="..hs.." source=haunt score=99 tier=4 ") == 1
			and HA_Kv(S_Line(n0, "event=roll system=golkonda flight="..hs.." "), "pool") == "hull" and sh and sh.tpl == he.c and FT_Mods(sh) == FT_Join(he.m),
			"unused hull "..hnm.." ("..he.c..") at tier 4: hull=true, roll line tier=4 pool=hull");
	end;
	-- TRF_FtDress directly: a mocked ship global, a missing ship, an unknown fit, a FALSE return and an AddModule error.
	local mk = {n=0, AddModule=function(self, m) self.n = self.n + 1; if m == "ECM1" then return FALSE; end; if m == "EngAmp1" then error("x"); end; return m; end};
	setglobal("ship_ftx_2", mk);
	n0 = S_Mark();
	local nb = TRF_FtDress("ftx", {[2]="Tiger_pir3"}, "golkonda", "ftx");
	local nb2 = TRF_FtDress("ftx", {[3]="Tiger_pir3", [2]="Nope_pir9"}, "golkonda", "ftx");
	setglobal("ship_ftx_2", nil);
	HOST_Check(nb == 1 and mk.n == 4 and S_Logs(n0, "event=dress system=golkonda flight=ftx ship=2 fit=Tiger_pir3 carcass=Tiger_pir0 hull=false modules=4 ok=2 failed=ECM1") == 1
		and nb2 == 2 and S_Logs(n0, "ship=3 fit=Tiger_pir3 carcass=Tiger_pir0 hull=false modules=4 ok=0 failed=no_ship") == 1
		and S_Logs(n0, "ship=2 fit=Nope_pir9 carcass=? hull=false modules=0 ok=0 failed=no_data") == 1 and S_Logs(n0, "event=error") == 0,
		"dress: FALSE and an error count as failed (no retry), a missing ship no_ship, an unknown fit no_data");
	-- The raid path: a captured new fit in a T4 raid row, built by TRF_PirFlight and dressed there; a maxn trim that drops
	-- the captured ship dresses nothing (skip reason=trim), nor a failed build (reason=build); the local builder (no TRF_BuildFlight) dresses by its ship list too.
	local tm = CreateTeam("Pirates");
	TRF_GRaid_7 = tm:CreateGroup("TRF_Raid_7");
	local row0 = TRF_Rd_PirRow(4, 14, 1, nil, nil);
	local rn, rR, rj, rnm = nil, nil, nil, nil;
	for n = 1, 3000 do
		if not rn then
			local Q = TRF_FtRoll(gi, 2 * n + 1, TRF.rg[gs].pt, gs, TRF_FtK().salt_raid, 4);
			if Q.c then
				local o, j, dr = TRF_FtRow(row0, Q.g, Q.sel, nil, Q.nw);
				if dr and j and j > 1 then rn = n; rj = j; rnm = dr[j]; end;
			end;
		end;
	end;
	HOST_Check(rn ~= nil, "a T4 raid flight number with a captured new fit (not the lead)");
	if rn then
		local gr = TRF_Ft_Grade(gi, 2 * rn + 1, "raid", "raid_"..rn.."_1", 4);
		local re = D.new[rnm];
		n0 = S_Mark();
		local rf = TRF_PirFlight(4, 14, "TRF_GRaid_7", "trf_rd_h", Vector3(100, 0, 100), Vector3(0, 0, 1), 1, nil, nil, gr);
		HOST_Check(rf and rf.ships[rj].tpl == re.c and FT_Mods(rf.ships[rj]) == FT_Join(re.m)
			and S_Logs(n0, "module=fits event=dress system=golkonda flight=raid_"..rn.."_1 ship="..rj.." fit="..rnm.." ") == 1,
			"raid: "..rnm.." built bare in the raid row, dressed by TRF_PirFlight, the dress line names the raid flight");
		if rf then rf:Delete(); end;
		n0 = S_Mark();
		local rt = TRF_PirFlight(4, 14, "TRF_GRaid_7", "trf_rd_h", Vector3(100, 0, 100), Vector3(0, 0, 1), 1, rj - 1, nil, gr);
		HOST_Check(rt and getn(rt.ships) == rj - 1 and S_Logs(n0, "module=fits event=dress ") == 0
			and S_Logs(n0, "module=fits event=skip system=golkonda flight=raid_"..rn.."_1 ship="..rj.." fit="..rnm.." reason=trim") == 1,
			"raid maxn trim below the captured ship: no dress, a skip line reason=trim");
		if rt then rt:Delete(); end;
		local obd = TRF_Rd_Build;
		TRF_Rd_Build = function() return nil; end;
		n0 = S_Mark();
		local rb = TRF_PirFlight(4, 14, "TRF_GRaid_7", "trf_rd_h", Vector3(100, 0, 100), Vector3(0, 0, 1), 1, nil, nil, gr);
		TRF_Rd_Build = obd;
		HOST_Check(rb == nil and S_Logs(n0, "module=fits event=dress ") == 0
			and S_Logs(n0, "module=fits event=skip system=golkonda flight=raid_"..rn.."_1 ship="..rj.." fit="..rnm.." reason=build") == 1,
			"raid build failure: no dress, a skip line reason=build");
		local ob = TRF_BuildFlight;
		TRF_BuildFlight = nil;
		n0 = S_Mark();
		local rl = TRF_PirFlight(4, 14, "TRF_GRaid_7", "trf_rd_h", Vector3(100, 0, 100), Vector3(0, 0, 1), 1, nil, nil, gr);
		TRF_BuildFlight = ob;
		HOST_Check(rl and FT_Mods(rl.ships[rj]) == FT_Join(re.m) and S_Logs(n0, "ok="..getn(re.m).." failed=none") == 1, "raid fallback builder: dressed by its ship list");
		if rl then rl:Delete(); end;
	end;
	TRF_GRaid_7 = nil;
	-- fits 0 at the same phase start: no roll or dress line, no AddModule, the haunt call lines byte-identical to a run
	-- without trf_fits and the same RAND draws.
	HA_Jump("xb13");
	TRF.haunt = nil;
	TRF.clan[gs].sc = 99;
	TRF.rg[gs].pt = pt;
	HA_Set("fits", 0);
	n0 = S_Mark();
	m0 = getn(h.mods);
	h.seed = 99; local r0 = h.rand;
	HA_Jump("golkonda");
	local L0, d0 = FT_Lines(n0, "module=haunt event=call "), h.rand - r0;
	local z = S_Logs(n0, "module=fits event=dress") + S_Logs(n0, "module=fits event=roll") + getn(h.mods) - m0;
	HA_Jump("xb13");
	TRF.haunt = nil;
	TRF.clan[gs].sc = 99;
	local ofn = TRF_Ft_Haunt;
	n0 = S_Mark();
	h.seed = 99; r0 = h.rand;
	HA_Jump("golkonda", {pre=function() TRF_Ft_Haunt = nil; end});
	local L1, d1 = FT_Lines(n0, "module=haunt event=call "), h.rand - r0;
	TRF_Ft_Haunt = ofn;
	HOST_Check(z == 0 and L0 == L1 and L0 ~= "" and d0 == d1, "fits 0: no roll, dress or AddModule; the call lines byte-identical to a run without trf_fits");
	HA_Set("fits", 1);
	HA_Jump("xb13");
end;

-- Dispatch ---------------------------------------------------------------------------------

local sc = getenv("TRF_FT") or "";
local fn = getglobal("T_FT_"..strupper(sc));
print("HOST ==== pirate fits scenario ft-"..sc.." dir="..HOST().dir);
if type(fn) == "function" then
	fn();
	HOST_Check(T_LeftGlobals() == "", "no handle globals left at the end"..T_LeftGlobals());
	local q = T_BadCallbacks();
	HOST_Check(q == "", "every mod callback string carries the current gen"..q);
else
	HOST_Check(nil, "unknown pirate fits scenario "..sc);
end;
HOST_Check((HOST().gpm_tick or 0) == 0, "no GetPlayerMotherShip from a tick (n="..tostring(HOST().gpm_tick or 0)..")");
print("HOST errors="..HOST().errors.." fails="..HOST().fails);
if HOST().errors > 0 or HOST().fails > 0 then exit(1); end;
exit(0);
