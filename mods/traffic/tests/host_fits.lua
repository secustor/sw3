-- Pirate fit variety scenarios (design/fits-spec.md 10) under stock Lua 4.0.1: TRF_FT=a..f, run by run_host.sh as its own
-- entry point. a registration, toggles, tune clamps, hash quality, the roll (determinism, bounds per score and tier, the
-- base factor, scrap only at tier 2 below 35, elites only at tiers 3-4), b the row copy (count, roles, order, explicit
-- indices, the maps, the rank clamp, captured within tolerance, one captured ship, the input unchanged), c the nest build
-- with the graded row (both build sites, the global tables unchanged, the saved grade across a load, -3 on an elite kill
-- inside the -6 cap), d the raid roll once per flight (pilots one rank up, RAND draws unchanged) and the garrison roll,
-- e the quest-gated visit (captured only, value-neutral, vanilla group and power, fits_gate 1, the scan deny list),
-- f fits 0 gives byte-identical nest call lines, the debug test ship with mocks, the save bytes.
-- Loads host_station.lua up to its first scenario and the helpers of host_nest.lua (its dispatch cut off). Stub change:
-- NewAllFlight in host_stubs.lua checks the row keys as vanilla's next() loop needs them and records the rows by sign.

local f = openfile((getenv("TRF_TESTS") or "./").."host_station.lua", "r");
if not f then print("HOST FAIL host_fits.lua: cannot open host_station.lua"); exit(1); end;
local src = read(f, "*a");
closefile(f);
local cut = strfind(src, "\n-- a: install (12.1, 6.1)", 1, 1);
if not cut then print("HOST FAIL host_fits.lua: marker '-- a: install (12.1, 6.1)' missing in host_station.lua"); exit(1); end;
dostring(strsub(src, 1, cut), "host_station.lua");
f = openfile((getenv("TRF_TESTS") or "./").."host_nest.lua", "r");
if not f then print("HOST FAIL host_fits.lua: cannot open host_nest.lua"); exit(1); end;
src = read(f, "*a");
closefile(f);
local a0 = strfind(src, "\n-- Helpers ---", 1, 1);
local a1 = strfind(src, "\n-- a: registration, toggles, tune, static table, pure rules", 1, 1);
if not a0 or not a1 then print("HOST FAIL host_fits.lua: helper markers missing in host_nest.lua"); exit(1); end;
dostring(strsub(src, a0, a1), "host_nest.lua");

-- Helpers ----------------------------------------------------------------------------------

-- The nest configuration with fits on and region ticks off (cycle 0: the score, phase and pt stay as set), plus t.
function FT_Begin(sys, t)
	local c = {fits=1, cycle=0};
	if t then for k, v in t do c[k] = v; end; end;
	NE_Begin(sys or "xb13", nil, c);
	-- Phase start legs up to 4000 must survive the repair (pt <= legs).
	TRF.clock.legs = 5000;
	HOST().nafs = {};
end;

-- Region slot of system nm in phase ph with score sc and the tier digit of that score.
function FT_Clan(nm, ph, sc)
	local s = NE_Slot(nm);
	NE_Phase(s, ph, sc);
	TRF.clan[s].tr = TRF_StrTier(sc);
	return s, V_Idx(nm);
end;

-- Grades of the graded rows of system nm (unpinned, type 1 / 2) at phase start pt: list g[i] (nil for the others), the
-- number of elite flights and of flights whose captured roll hits a row with a pool (gate 1: the gate salt and the
-- vanilla power, else the nest power p + dp of the tier).
function FT_Grades(nm, pt, gate)
	local d = NE_Data(nm);
	local idx, slot = V_Idx(nm), NE_Slot(nm);
	local g, ne, nc = {}, 0, 0;
	for i = 1, getn(d.f) do
		local r = d.f[i];
		if r.pin ~= 1 and r.t ~= 3 then
			local salt, dp = TRF_FtK().salt_nest, TRF_StrRow(TRF_EffTier(idx)).dp;
			if gate == 1 then salt = TRF_FtK().salt_gate; dp = 0; end;
			local R = TRF_FtRoll(idx, i, pt, slot, salt, nil, gate);
			g[i] = R;
			if R.g == 1 then ne = ne + 1; end;
			if R.c then
				local tab, form, ri = TRF_FtTab(r.t, r.p + dp);
				local row, cj = TRF_FtRow(tab[ri], R.g, R.sel, nil);
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

-- First phase start leg 1..4000 and flight index of system nm whose graded row (nest power) is of kind w: "cap" a
-- normal flight with a captured ship, "scrap" a scrap flight. Returns pt, i and the roll record, or nil.
function FT_Find(nm, w)
	local d = NE_Data(nm);
	local dp = TRF_StrRow(TRF_EffTier(V_Idx(nm))).dp;
	for pt = 1, 4000 do
		local G = FT_Grades(nm, pt);
		for i = 1, getn(d.f) do
			local R = G[i];
			if R then
				local tab, form, ri = TRF_FtTab(d.f[i].t, d.f[i].p + dp);
				local sel = nil;
				if R.c then sel = R.sel; end;
				local row, cj = TRF_FtRow(tab[ri], R.g, sel, 1);
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
	HOST_Check(S_Logs(0, "module=core event=loaded map=true module_count=18 extra_count=14") >= 1, "trf_fits loads (extra_count=14)");
	local ml, ok = TRF_ModList(), nil;
	for i = 1, getn(ml) do if ml[i] == "Ft" and ml[i - 1] == "Str" then ok = 1; end; end;
	HOST_Check(ok and type(TRF_Ft_TuneDef) == "function" and type(TRF_FtData) == "function", "Ft in the module list after Str");
	local d = TRF_Ft_OptDef();
	HOST_Check(d.fits == 0 and d.fits_gate == 0 and d.fits_test == "" and TRF_FtOpt("fits") == 1 and TRF_FtOn() == 1,
		"cfg defaults fits 0, fits_gate 0, fits_test empty; on in these runs");
	NE_Set("fits", 2);
	HOST_Check(TRF_FtOpt("fits") == 0 and not TRF_FtOn(), "fits 2 reads as the default 0");
	NE_Set("fits", 1);
	local T = TRF_FtTune();
	HOST_Check(T.fits_elite_max == 5 and T.fits_base_a == 10 and T.fits_base_p == 3 and T.fits_cap_pct == 5 and T.fits_scrap_sc == 35
		and getn(T.fits_test_mods) == 3 and T.fits_test_mods[1] == "PC2" and TRF_Tune().fits_cap_pct == 5, "tune defaults, merged into TRF_Tune");
	NE_Tune("fits_cap_pct", 50); NE_Tune("fits_elite_max", -3); NE_Tune("fits_test_mods", {"VC2", 3, ""});
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
	NE_Tune("fits_base_a", 15);
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

-- c: nest build, saved grade, kill cost ------------------------------------------------------------------------

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
	NE_Jump("golkonda");
	local d = NE_Data("golkonda");
	local e = TRF.nv and TRF.nv.e;
	local ok, el, bad = 1, {}, "";
	for i = 1, getn(d.f) do
		local R = G[i];
		local nf = h.nafs[d.f[i].s];
		if R and R.g == 1 then
			tinsert(el, i);
			local tab, form, ri = TRF_FtTab(d.f[i].t, d.f[i].p + 1);
			local want = TRF_FtRow(tab[ri], 1, R.c and R.sel, 1);
			if not nf or FT_Names(nf.row) ~= FT_Names(want) or nf.group ~= "TRF_GNest_1" or nf.power ~= d.f[i].p + 1 then ok = nil; bad = bad.." "..i; end;
			if strsub(e or "", i, i) ~= "1" and strsub(e or "", i, i) ~= "4" then ok = nil; bad = bad.." e"..i; end;
		elseif R then
			if not R.c and strsub(e or "", i, i) ~= "0" then ok = nil; bad = bad.." z"..i; end;
		end;
	end;
	HOST_Check(ok and getn(el) >= 2, "elite flights built through NewAllFlight with the graded row at the nest power in TRF_GNest_1, digits in TRF.nv.e "..tostring(e)..bad);
	HOST_Check(S_Logs(n0, "module=fits event=roll system=golkonda") == 10 and S_Logs(n0, "grade=1 captured_roll=") == getn(el)
		and S_Logs(n0, "module=fits event=row system=golkonda") >= getn(el), "one roll line per flight, a row line per graded flight");
	HOST_Check(FT_PirSnap() == snap, "the global Pir_Fighters / Pir_Bombers rows unchanged");
	HOST_Check(S_Logs(n0, "result=substituted") == 10 and NE_Kv(NE_Line(n0, "module=nest event=activate "), "fielded") == "10", "ten flights fielded");
	local v = NE_V();
	local s0 = getglobal("ship_"..d.f[el[1]].s.."_1");
	HOST_Check(v.fl[el[1]] and s0 and v.fl[el[1]].ships[1] == s0 and s0.tpl == h.nafs[d.f[el[1]].s].row[1][1], "elite flight's globals and fits real");
	-- Kill cost: elite -3 (player fire), normal -2, the second elite only -1 (cap 6 per visit).
	local sc0 = TRF.clan[gs].sc;
	local ni = nil;
	for i = 1, getn(d.f) do if G[i] and G[i].g == 0 and not ni then ni = i; end; end;
	local n1 = S_Mark();
	NE_Kill(el[1], 1);
	local s1 = TRF.clan[gs].sc;
	NE_Kill(ni, 1);
	local s2 = TRF.clan[gs].sc;
	NE_Kill(el[2], 1);
	local s3 = TRF.clan[gs].sc;
	HOST_Check(sc0 - s1 == 3 and s1 - s2 == 2 and s2 - s3 == 1, "kills: elite -3, normal -2, the second elite -1 inside the -6 cap ("..sc0..","..s1..","..s2..","..s3..")");
	HOST_Check(S_Logs(n1, "module=fits event=kill system=golkonda") == 2 and S_Logs(n1, "reason=\"pirate kill nest_elite\"") == 2,
		"event=kill per elite flight, the elite reason on the clan score line");
	-- Save and load: the digits stay (the dead flights' bits are 0, their digits kept).
	T_SaveLoad();
	HOST_Check(TRF.nv.e == e and NE_Kv(S_Line(n1, "module=nest event=load "), "rearmed") == "7", "grade digits survive save and load");
	-- Without player fire: TRF_ClanAdd -3 in a new visit.
	NE_Jump("xb13");
	TRF.nest = nil;
	TRF.clan[gs].sc = 99;
	NE_Jump("golkonda");
	local s4 = TRF.clan[gs].sc;
	NE_Kill(el[1], 0);
	HOST_Check(s4 - TRF.clan[gs].sc == 3, "elite kill without player fire: -3 ("..s4.." -> "..TRF.clan[gs].sc..")");
	-- nest_mode 2: the replace site builds the graded rows too.
	NE_Jump("xb13");
	TRF.nest = nil;
	TRF.clan[gs].sc = 99;
	NE_Set("nest_mode", 2);
	h.nafs = {};
	n0 = S_Mark();
	NE_Jump("golkonda");
	local ok2 = 1;
	for q = 1, getn(el) do
		local i = el[q];
		local nf = h.nafs[d.f[i].s];
		local tab, form, ri = TRF_FtTab(d.f[i].t, d.f[i].p + 1);
		if not nf or FT_Names(nf.row) ~= FT_Names(TRF_FtRow(tab[ri], 1, G[i].c and G[i].sel, 1)) or nf.group ~= "TRF_GNest_1" then ok2 = nil; end;
	end;
	HOST_Check(ok2 and NE_Kv(NE_Line(n0, "module=nest event=replace "), "spawned") == "10" and TRF.nv.e == e, "nest_mode 2: the rebuilt flights take the graded rows, same digits");
	NE_Set("nest_mode", 1);
	-- A repair drops bad digits.
	TRF.nv.e = "9x";
	TRF_Nest_Fix();
	HOST_Check(TRF.nv and TRF.nv.e == nil and TRF.nv.b ~= nil, "repair: bad digits dropped, the visit record kept");
	-- A captured-only flight (Raids, score 99) and a scrap flight (Boom, tier 2, score 30): the graded row through
	-- NewAllFlight in TRF_GNest_1, digit 3 (captured) or 2 / 5 (scrap) in TRF.nv.e, a kill costs -2.
	local cs = {{3, 99, "cap"}, {1, 30, "scrap"}};
	for q = 1, 2 do
		NE_Jump("xb13");
		TRF.nest = nil;
		FT_Clan("golkonda", cs[q][1], cs[q][2]);
		local cp, ci, CR = FT_Find("golkonda", cs[q][3]);
		HOST_Check(cp ~= nil, "a phase start with a "..cs[q][3].." flight in Golkonda");
		if cp then
			TRF.rg[gs].pt = cp;
			h.nafs = {};
			NE_Jump("golkonda");
			local fq = d.f[ci];
			local tab, form, ri = TRF_FtTab(fq.t, fq.p + TRF_StrRow(TRF_EffTier(gi)).dp);
			local sel = nil;
			if CR.c then sel = CR.sel; end;
			local want, cj = TRF_FtRow(tab[ri], CR.g, sel, 1);
			local nf = h.nafs[fq.s];
			local ch = strsub(TRF.nv.e or "", ci, ci);
			local okd = (q == 1 and ch == "3" and cj) or (q == 2 and (ch == "2" or (ch == "5" and cj)));
			HOST_Check(nf and FT_Names(nf.row) == FT_Names(want) and FT_Names(want) ~= FT_Names(tab[ri]) and nf.group == "TRF_GNest_1" and okd,
				cs[q][3].." flight "..ci.." built with the graded row, digit "..ch..": "..FT_Names(want));
			local k0 = TRF.clan[gs].sc;
			NE_Kill(ci, 1);
			HOST_Check(k0 - TRF.clan[gs].sc == 2, cs[q][3].." flight kill: -2 ("..k0.." -> "..TRF.clan[gs].sc..")");
		end;
	end;
	NE_Jump("xb13");
end;

-- d: raids and garrisons -------------------------------------------------------------------------------------------

function T_FT_D()
	local h = HOST();
	FT_Begin("xb13");
	NE_Jump("golkonda");
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
	NE_Set("fits", 0);
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
		NE_Set("fits", q);
		h.seed = 777;
		r0 = h.rand;
		n0 = S_Mark();
		fls = TRF_Rd_Comp(9, {tier=2}, "TRF_GRaid_7", "trf_rd_9", Vector3(100, 0, 100), Vector3(0, 0, 1), 8, gi);
		dr[q] = {h.rand - r0, S_Logs(n0, "module=fits event=roll system=golkonda flight=raid_9_1 source=raid score=30 tier=2 up=0 down=16 ")};
		if type(fls) == "table" then for i = 1, getn(fls) do fls[i]:Delete(); end; end;
	end;
	HOST_Check(dr[0][1] == dr[1][1] and dr[0][1] >= 1 and dr[1][2] == 1 and dr[0][2] == 0, "T2 raid: one roll (scrap chance 16 %), RAND draws "..dr[1][1].." with fits 1 = "..dr[0][1].." with fits 0");
	TRF.clan[gs].sc = 80;
	NE_Set("fits", 1);
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
	NE_Jump("xb13");
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
	NE_Jump("kadi");
	local d = NE_Data("kadi");
	HOST_Check(NE_Kv(NE_Line(n0, "module=nest event=mode "), "reason") == "gate_quest", "Kadi with a quest in process: gate_quest");
	local ok, nb, bad = 1, 0, "";
	for i = 1, getn(d.f) do
		local R = G[i];
		local nf = h.nafs[d.f[i].s];
		local fl = getglobal("flight_"..d.f[i].s);
		if not fl or fl.group.name ~= d.g then ok = nil; bad = bad.." g"..i; end;
		if R and R.c then
			local tab, form, ri = TRF_FtTab(d.f[i].t, d.f[i].p);
			local want, cj = TRF_FtRow(tab[ri], 0, R.sel, nil);
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
	HOST_Check(NE_Kv(S_Line(n0, "module=fits event=gate "), "built") == tostring(nb) and S_Logs(n0, "module=nest event=call") == 0
		and S_Logs(n0, "module=nest event=activate") == 0, "gate line built="..nb.."; no nest call or activate line");
	HOST_Check(TRF.nv == nil and NE_Trigs("f_died", "TRF_Nest_Died(") == 0 and TRF_NeNE().a == nil and NE_V().fl[1] == nil, "no TRF.nv, no triggers, the record disarmed");
	-- fits_gate 1: vanilla rows.
	NE_Jump("hanoi");
	NE_Set("fits_gate", 1);
	n0 = S_Mark();
	NE_Jump("kadi");
	HOST_Check(S_Logs(n0, "module=fits event=roll") == 0 and S_Logs(n0, "module=fits event=skip system=kadi reason=gate via=fits_gate") == 1,
		"fits_gate 1: no roll, skip reason=gate");
	NE_Set("fits_gate", 0);
	-- The scan's deny list.
	NE_Jump("hanoi");
	local od = TRF_FtGateDeny;
	n0 = S_Mark();
	NE_Jump("kadi", {pre=function() TRF_FtGateDeny = function() return {kadi=1}; end; end});
	TRF_FtGateDeny = od;
	HOST_Check(S_Logs(n0, "module=fits event=roll") == 0 and S_Logs(n0, "reason=gate via=scan") == 1, "a deny-listed system keeps vanilla rows");
	-- A quest scene at entry (__disableAction): gate_quest, but no fits record and no captured flight.
	NE_Jump("hanoi");
	h.nafs = {};
	n0 = S_Mark();
	NE_Jump("kadi", {pre=function() __disableAction = TRUE; end});
	__disableAction = nil;
	local nn = 0;
	for i = 1, getn(d.f) do
		local nf = h.nafs[d.f[i].s];
		local tab, form, ri = TRF_FtTab(d.f[i].t, d.f[i].p);
		if nf and tab and FT_Names(nf.row) ~= FT_Names(tab[ri]) then nn = nn + 1; end;
	end;
	HOST_Check(NE_Kv(NE_Line(n0, "module=nest event=mode "), "reason") == "gate_quest" and S_Logs(n0, "module=fits event=roll") == 0
		and S_Logs(n0, "module=fits event=gate") == 0 and nn == 0, "quest scene at a gate_quest entry: no roll, no captured flight");
	h.quests[qi[1]] = QUEST_DONE;
	NE_Jump("hanoi");
end;

-- f: fits 0 identical, debug test ship, save bytes -------------------------------------------------------------------

function T_FT_F()
	local h = HOST();
	FT_Begin("xb13", {fits=0});
	local gs, gi = FT_Clan("golkonda", 2, 62);
	TRF.rg[gs].pt = 5;
	local n0 = S_Mark();
	h.seed = 99; local r0 = h.rand;
	NE_Jump("golkonda");
	local L0, d0 = FT_Lines(n0, "module=nest event=call "), h.rand - r0;
	HOST_Check(S_Logs(n0, "module=fits event=skip system=golkonda") == 10 and NE_Has(S_Line(n0, "module=fits event=skip "), "reason=off")
		and S_Logs(n0, "module=fits event=roll") == 0 and TRF.nv.e == nil, "fits 0: skip reason=off per flight, no roll, no digits");
	NE_Jump("xb13");
	TRF.nest = nil;
	local ofn = TRF_Ft_Nest;
	TRF_Ft_Nest = nil;
	n0 = S_Mark();
	h.seed = 99; r0 = h.rand;
	NE_Jump("golkonda", {pre=function() TRF_Ft_Nest = nil; end});
	local L1, d1 = FT_Lines(n0, "module=nest event=call "), h.rand - r0;
	TRF_Ft_Nest = ofn;
	HOST_Check(L0 == L1 and L0 ~= "" and d0 == d1, "fits 0: the nest call lines byte-identical to a run without trf_fits, same RAND draws");
	-- fits 1 at a phase start where no flight is graded or captured: the same lines again.
	NE_Jump("xb13");
	TRF.nest = nil;
	NE_Set("fits", 1);
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
	NE_Jump("golkonda");
	local L2 = FT_Lines(n0, "module=nest event=call ");
	HOST_Check(qp and L2 == L0 and TRF.nv.e == nil and S_Logs(n0, "module=fits event=row") == 0, "fits 1 with every grade 0: identical call lines, the vanilla builder, no digits");
	-- Save bytes: the worst-case digit string.
	local z0 = HOST_SaveSize(TRF.nv);
	TRF.nv.e = strrep("4", 31);
	local z1 = HOST_SaveSize(TRF.nv);
	print("HOST info fits worst case: nv without e="..z0.." with 31 digits="..z1.." (+"..(z1 - z0)..")");
	HOST_Check(z1 - z0 <= 50, "31 grade digits add "..(z1 - z0).." bytes (<= 50)");
	TRF.nv.e = nil;
	-- Debug test ship: a bare carcass gets the modules, the HP is logged, 2 s later the TRF_Carcasses record.
	NE_Jump("xb13");
	NE_Set("fits_test", "Panthera_pir0");
	TRF_Carcasses = HOST_Carcasses;
	h.carc = {};
	n0 = S_Mark();
	local m0 = getn(h.mods);
	NE_Jump("golkonda");
	local tf = TRF_H().ft;
	HOST_Check(tf and tf.s and tf.s.tpl == "Panthera_pir0" and S_Logs(n0, "module=fits event=test name=Panthera_pir0 step=create result=ok") == 1
		and S_Logs(n0, "step=hull bare=true hp=1000") == 1 and S_Logs(n0, "step=add_module module=PC2 ret=nil hp=1000") == 1
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
	NE_Jump("xb13");
	HOST_Check(not tf.s.alive and TRF_H().ft ~= tf, "jump: the test flight deleted");
	TRF_Carcasses = nil;
	NE_Set("fits_test", "Gunslinger_pir1");
	n0 = S_Mark();
	m0 = getn(h.mods);
	NE_Jump("golkonda");
	T_Tick(6, 0.5);
	HOST_Check(S_Logs(n0, "step=hull bare=false") == 1 and getn(h.mods) == m0 and S_Logs(n0, "step=read result=no_native") == 1,
		"a ShipDescription: no AddModule; no native: result=no_native");
	NE_Set("fits_test", "");
	NE_Jump("xb13");
	h.carc = nil;
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
