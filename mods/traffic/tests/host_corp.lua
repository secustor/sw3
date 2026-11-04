-- Corporation carriers scenarios (design/corp-carriers-spec.md 10, A22) under stock Lua 4.0.1: TRF_CO=a..h, run by
-- run_host.sh as its own entry point. a registration, defaults, clamps, texts and the pure functions (shares of the
-- 5.1 table, pick bounds, the label roll, the fixed hash, the block string, the signature items, the pull-out choice);
-- b labels and text surfaces (label rates against the shares over 200 names, the excluded record kinds, Elinor, a
-- trf_track rebuild, the generator and seed hooks, the spawn volume and RAND draws with and without the module, the
-- greeting with its standing variants, the owner word, the dialog head, the where-headed answer, crp_ch, corp 0);
-- c the carrier shop (gun list of the corporation and Syst_List, the signature first at count 1, Triada one item
-- more, coefficients equal to an independent's, crp_sig_ch); d counts and the pull-out (player, raid and robbery
-- losses, a counted carrier, chapter 4, fst once per visit, the region tick: start, news, labels during it, the end
-- and the return state, the cap, the Quiet reset, the off-screen roll over 200 legs); e the dock line (out and back
-- once per save across a load, identity once per visit, Elinor, the gates and the req order); f the supply run
-- (mark, posting, kind 9 deeds, the share and the offer floor, the pay with fst +1, the closes, chapter 19, the module
-- absent); g the save string at its bound, the repair and the full state; h the module absent and cfg corp 0.
-- Loads host_station.lua up to its first scenario (stubs of host_stubs.lua, the helpers of host_traffic.lua and
-- host_v02.lua, the DockStation.script stubs and the S_* helpers), as host_warn.lua does. No new native stub:
-- GetLocationTeam reads HOST().teams (the vanilla side list from S_Begin), Gun_List_* and Syst_List exist.

local f = openfile((getenv("TRF_TESTS") or "./").."host_station.lua", "r");
if not f then print("HOST FAIL host_corp.lua: cannot open host_station.lua"); exit(1); end;
local src = read(f, "*a");
closefile(f);
local cut = strfind(src, "\n-- a: install (12.1, 6.1)", 1, 1);
if not cut then print("HOST FAIL host_corp.lua: marker '-- a: install (12.1, 6.1)' missing in host_station.lua"); exit(1); end;
dostring(strsub(src, 1, cut), "host_station.lua");

-- Helpers ----------------------------------------------------------------------------------

-- Config of these runs: corporation carriers on, the features that claim boxes, lines, raid slots or entry events off
-- (captains, sweeps, carriers, parcels, the freight quest, stashes, survivors, temperaments, warnings, remarks), log 2,
-- plus t.
function CO_Cfg(t)
	local c = {corp=1, cap_enable=0, sweeps=0, sweep_ct=0, feq=0, staged=0, seed=0, queue=0, parked=0, voice_events=0, dconv=0,
		carriers=0, po=0, enable_parcels=0, enable_wq=0, enable_stashes=0, enable_survivors=0, enable_freight=0, temper=0, warn=0,
		remarks=0, log=2, tune={}};
	if t then for k, v in t do c[k] = v; end; end;
	return c;
end;

-- Scenario start in sys at chapter label ch (default 5_1): every region in Build-up with clan score 30, no state.
function CO_Begin(sys, ch, t)
	local h = HOST();
	h.labels.CurrentQuest = ch or "5_1";
	h.quests = {}; h.qlog = {};
	h.qs = FALSE;
	h.rel_team = nil;
	h.posts = {};
	S_Begin(sys, CO_Cfg(t));
	h.credits = 1000000;
	for s = 1, TRF_RgMap().n do
		TRF.clan[s].sc = 30;
		local rg = TRF.rg[s];
		rg.ph = 2; rg.pt = TRF.clock.legs; rg.sl = 0; rg.sn = 0; rg.sw = 0; rg.sr = nil;
	end;
	TRF.crp = nil;
	TRF.std.heat = 0;
end;

function CO_Has(s, t) return strfind(s or "", t, 1, 1); end;

function CO_N(t) local n = 0; for k, v in t do n = n + 1; end; return n; end;

-- corp log lines after mark n0 holding pat (plain).
function CO_Logs(n0, pat)
	local n, q = 0, HOST().logs;
	for i = n0 + 1, getn(q) do if strfind(q[i], "module=corp ", 1, 1) and strfind(q[i], pat, 1, 1) then n = n + 1; end; end;
	return n;
end;

-- Index of the first log line after n0 matching pat (plain), or nil.
function CO_At(n0, pat)
	local q = HOST().logs;
	for i = n0 + 1, getn(q) do if strfind(q[i], pat, 1, 1) then return i; end; end;
	return nil;
end;

function CO_Near(a, b) return abs(a - b) < 0.0005; end;

-- Visit flags of trf_corp cleared (a new visit without an entry), with the station's.
function CO_NewVisit()
	local cv = TRF_CrpCV();
	cv.pr = {}; cv.id = {}; cv.q = nil;
	S_NewVisit();
end;

-- A synthetic plain trader record id with name index nm in the current system (no ships), labelled.
function CO_Rec(id, nm, x)
	local r = {id=id, nm=nm, st="in", path="A", from=TRF_CurIdx(), to=0, cls=1};
	if x then for k, v in x do r[k] = v; end; end;
	TRF.live.tr[id] = r;
	return r;
end;

-- Labels of names 1..n in the current system: counts per corporation and of none; the records are removed again.
function CO_Rates(n)
	local c = {[3]=0, [4]=0, [5]=0, none=0};
	for k = 1, n do
		local r = CO_Rec(9000 + k, k);
		local f = TRF_Crp_Label(9000 + k);
		if f then c[f] = c[f] + 1; else c.none = c.none + 1; end;
		TRF.live.tr[9000 + k] = nil;
	end;
	return c;
end;

-- Shares in the current system: TRF_CrpSharesOf with the region counts, the owner, the block's pull-out and the open
-- runs (as the label reads them).
function CO_Shares()
	local idx = TRF_CurIdx();
	local slot = TRF_RgOf(idx);
	local b = TRF_CrpBlk(slot);
	local pl = {};
	if b.p ~= 0 then pl[b.p] = 1; end;
	return TRF_CrpSharesOf(TRF_CrpCache()[slot], TRF_CrpOwn(idx), TRF_CrpTune(), pl, TRF_N("TRF_Ch_RunOpen", slot));
end;

-- One FTU trader on path A in the current system without a raid (the C_Trader of host_charter.lua), or nil; f sets
-- its label.
function CO_Trader(f)
	V_ClearTr();
	local cur = TRF_CurIdx();
	TRF_SetDis(cur, 0);
	if TRF_Pro(cur) < 4 then TRF_SetPro(cur, 4); end;
	TRF.live.port = {};
	TRF.live.kills = 0;
	local id = T_Spawn("A") or T_Spawn("B");
	if id then
		V_NoRaid(id);
		TRF.live.tr[id].crp = f;
	end;
	return id;
end;

-- Hull word of trader id's record as TRF_UI_Who picks it (freighter, freighters).
function CO_Hull(r, id)
	if TRF_UI_Transports(r, id) >= 2 then return TRF_Txt("hull2"); end;
	return TRF_Txt("hull1");
end;

-- Kill of trader id without player fire (every transport dead, no attack event).
function CO_OtherKill(id)
	local x = TRF_H().tr[id];
	for t = 1, getn(x.tp) do
		x.tp[t].alive = nil;
		HOST_Fire("died", "TRF_OnShipDied("..id..","..t..","..TRF.gen..")--");
	end;
end;

-- Trade approach at the first trade station of the current system (dock array rebuilt), any box answered Cancel.
function CO_Dock()
	local h = HOST();
	local D = S_Setup();
	if not D.trade[1] then return nil; end;
	local b0 = getn(h.boxes);
	local r = S_Trade(D.trade[1]);
	for i = b0 + 1, getn(h.boxes) do if not h.boxes[i].done then HOST_Press("cancel", h.boxes[i]); end; end;
	return r;
end;

-- Block of region slot as "a3a4a5ptx/e".
function CO_B(slot)
	local b = TRF_CrpBlk(slot);
	return b.a[3]..b.a[4]..b.a[5]..b.p..b.t..b.x.."/"..b.e;
end;

-- Writes a block of slot from a table {a3, a4, a5, p, t, x, e}.
function CO_Put(slot, a3, a4, a5, p, t, x, e)
	TRF_CrpPut(slot, {a={[3]=a3, [4]=a4, [5]=a5}, p=p, t=t, x=x, e=e});
end;

-- Equipment items of the last shop fill (the log 2 items line of trader id) as a list.
function CO_Equip(n0, id)
	local q, o = HOST().logs, {};
	for i = n0 + 1, getn(q) do
		local a, b, l = strfind(q[i], "module=shop event=items trader_id="..id.." .* equip=([%w_,]*)");
		if a then
			o = {};
			gsub(l, "([%w_]+)", function(w) tinsert(%o, w); end);
		end;
	end;
	return o;
end;

-- Shop open lines after n0 holding pat (plain).
function CO_Shop(n0, pat)
	local n, q = 0, HOST().logs;
	for i = n0 + 1, getn(q) do if strfind(q[i], "module=shop event=open ", 1, 1) and strfind(q[i], pat, 1, 1) then n = n + 1; end; end;
	return n;
end;

-- Set of the gun list rows 1, 2 of a team and Syst_List.
function CO_Pool(gl)
	local s = {};
	local t = getglobal(gl);
	for g = 1, 2 do for j = 1, getn(t[g]) do s[t[g][j]] = 1; end; end;
	for j = 1, getn(Syst_List) do s[Syst_List[j]] = 1; end;
	return s;
end;

-- Charter unlocked (chapter of the label, help 3) and every region Quiet with clan score 10; w = {name = phase}.
function CO_Charter(w)
	TRF.std.help = 3;
	TRF_Ch_OnActivate();
	local L = TRF.clock.legs;
	for s = 1, TRF_RgMap().n do
		local r = TRF.rg[s];
		r.ph = 0; r.pt = L; r.sl = 0; r.sn = 0; r.sw = 0; r.ct = 0; r.sr = nil;
		TRF.clan[s].sc = 10;
	end;
	TRF.base = {};
	if w then for nm, ph in w do TRF.rg[V_Slot(nm)].ph = ph; end; end;
	-- Low pro: no Lanes posting competes with the run (R below lanes_R).
	for i = 1, getn(TRF_Map().sys) do if TRF_Pro(i) > 2 then TRF_SetPro(i, 2); end; end;
end;

-- Escort contract with trader id paid at its arrival (dock); returns the contract result of TRF_CtArrive.
function CO_Escort(id)
	local ct = V_Contract(id);
	if not ct then return nil; end;
	return TRF_CtArrive(id, "dock");
end;

-- a: registration, texts, pure functions -------------------------------------------------------------

function T_CO_A()
	local h = HOST();
	CO_Begin("golkonda", "1");
	HOST_Check(S_Logs(0, "module=core event=loaded map=true module_count=18 extra_count=22") >= 1, "trf_corp loads before trf_debrief (extra_count=22)");
	local ml, pm, tf, uf = TRF_ModList(), TRF_PlMods(), TRF_Loc_TextFns(), TRF_UI_TextFns();
	HOST_Check(ml[getn(ml) - 3] == "Crp" and pm[getn(pm) - 1] == "Crp" and tf[getn(tf) - 4] == "TRF_Crp_Text" and tf[getn(tf)] == "TRF_Loc_Text"
		and uf[getn(uf) - 3] == "TRF_Crp_Text", "Crp before Db at the end of TRF_ModList and TRF_PlMods; TRF_Crp_Text before TRF_Db_Text in both text lists");
	HOST_Check(TRF_Opt("corp") == 1 and TRF_Crp_OptDef().corp == 1 and TRF_OptEnum().corp == 1, "cfg corp 1 by default, enumerated 0..1");
	local T = TRF_CrpTune();
	HOST_Check(CO_N(TRF_Crp_TuneDef()) == 14 and T.crp_ch == 0 and T.crp_pull_ch == 5 and T.crp_sig_ch == 0 and T.crp_share == 0.8
		and T.crp_k[1] == 0.7 and T.crp_k[2] == 1.0 and T.crp_k[3] == 0.3 and T.crp_own == 2 and T.crp_max == 0.75 and T.crp_job_x == 2
		and T.crp_job_offer == 60 and T.crp_pull_n == 3 and T.crp_pull_legs == 24 and T.crp_pull_max == 2 and T.crp_off_pct == 20
		and T.crp_id_pct == 30 and TRF_Tune().crp_pull_legs == 24, "14 tune keys with the spec 7 defaults, merged into TRF_Tune");
	h.cfg.tune = {crp_ch=30, crp_share=1.5, crp_k={0.5, 3}, crp_own=0.5, crp_max=0.95, crp_job_x=9, crp_job_offer=-4, crp_pull_n=0,
		crp_pull_legs=2.7, crp_pull_max=12, crp_off_pct=80, crp_id_pct=101};
	T = TRF_CrpTune();
	HOST_Check(T.crp_ch == 20 and T.crp_share == 1 and T.crp_k[1] == 0.7 and T.crp_own == 1 and T.crp_max == 0.9 and T.crp_job_x == 4
		and T.crp_job_offer == 0 and T.crp_pull_n == 1 and T.crp_pull_legs == 4 and T.crp_pull_max == 8 and T.crp_off_pct == 50
		and T.crp_id_pct == 100, "tune clamps; a crp_k of the wrong length reads the default");
	h.cfg.tune = {crp_k={3, -1, 0.5}, crp_max=0.5};
	T = TRF_CrpTune();
	HOST_Check(T.crp_k[1] == 2 and T.crp_k[2] == 0 and T.crp_k[3] == 0.5 and T.crp_max == 0.5, "crp_k entries clamped 0..2; fractions kept");
	h.cfg.tune = {};
	h.cfg.corp = 3;
	HOST_Check(TRF_CrpOpt("corp") == 1, "cfg corp outside 0..1 reads as the default");
	h.cfg.corp = nil;
	-- Charter tune (spec 7): ch_k with 7 entries, a 6-entry list padded with the default, ch_run_legs.
	local C = TRF_ChTune();
	h.cfg.tune = {ch_k={0.5, 0.3, 0.4, 0.4, 0.4, 0.4}, ch_run_legs=200};
	local C6 = TRF_ChTune();
	h.cfg.tune = {};
	HOST_Check(getn(C.ch_k) == 7 and C.ch_k[7] == 0.4 and C.ch_run_legs == 20 and getn(C6.ch_k) == 7 and C6.ch_k[1] == 0.5 and C6.ch_k[7] == 0.4
		and C6.ch_run_legs == 100, "charter: ch_k 7 entries (a 6-entry tune padded), ch_run_legs 20, clamp 8..100");
	local ty = TRF_ChTypes()[7];
	HOST_Check(ty.n == "run" and ty.fam == 1 and ty.rq == 2 and ty.k == 2 and TRF_ChKinds()[9] == "run" and TRF_ChDeeds()[7][9] == 1
		and TRF_ChDeeds()[1][9] == nil and TRF_ChTrade()[7] == 1 and TRF_ChKillSet()[7] == 1 and TRF_ChCloseWhy().pull == 1,
		"charter type 7 run (family trade, rq 2, k 2), kind 9, closed with the trade family and by a player trader kill");
	-- Texts (6): byte-identical to the spec table, in the merged EN table, plain.
	local spec = {crpown="$1 contract", crpopen="FTU $1, $2 contract carrier, open for trade",
		crpopenlo="FTU $1, $2 contract carrier. $2 says the Wolves are trouble, but trade's trade",
		crpopenhi="FTU $1, $2 contract carrier. $2 speaks well of the Wolves. Open for trade",
		crphead="$1 contract carrier. What do you need, Wolves?", crpdir="$1 cargo, $2",
		crpdockout="Dockmaster: $1 pulled its contract carriers off the $2 lanes after the losses. Free traders fly the routes until they come back.",
		crpdockback="Dockmaster: $1 carriers are back on the $2 lanes. Business as usual.",
		crpdockid3="Dockmaster: Triada carriers work the $1 lanes. Fair prices, and nobody asks where the cargo came from.",
		crpdockid4="Dockmaster: USS moves its caravans through $1 on FTU contract carriers. Their holds carry USS stock.",
		crpdockid5="Dockmaster: InoCo hires a few free traders for the $1 runs. Top gear, top prices.",
		ncrpout="$3 pulls its contract carriers off the lanes near $1",
		chd73="Triada ships through this region on FTU contract carriers. Escort two Triada carriers to their dock or exit. Progress and pay at any FTU trade dock.",
		chd74="USS caravans in this region fly on FTU contract carriers and need guards. Escort two USS carriers to their dock or exit. Progress and pay at any FTU trade dock.",
		chd75="InoCo hired free traders for a run through this region. Escort two InoCo carriers to their dock or exit. Progress and pay at any FTU trade dock.",
		chdeed7="contract carriers escorted $1 of $2", chwhy7="Trade there has collapsed.", chwhypull="The corporation pulled its carriers out."};
	local tabs = {TRF_Crp_Text(), TRF_UI_Text(), TRF_Ch_Text()};
	local en = TRF_Loc_EN();
	local bad = "";
	for k, v in spec do
		local got = tabs[1][k] or tabs[2][k] or tabs[3][k];
		if got ~= v or en[TRF_LocKey(k)] ~= v or strfind(v, "[%%#\n]") then bad = bad.." "..k; end;
	end;
	HOST_Check(bad == "" and CO_N(TRF_Crp_Text()) == 11, "the 18 text keys of spec 6 byte-identical in the tables and TRF_Loc_EN, plain"..bad);
	-- Shares of the 5.1 table (side list fixture): region and own system.
	local rg = TRF_CrpCache();
	local S = function(nm, own, pl, job)
		return TRF_CrpSharesOf(TRF_CrpCache()[V_Slot(nm)], own, TRF_CrpTune(), pl, job);
	end;
	local d, g, k, mo, x = S("dosis"), S("golkonda"), S("kadi"), S("moscowia"), S("xt93");
	HOST_Check(CO_Near(d[3], 0.345) and CO_Near(d[4], 0.246) and d[5] == 0 and CO_Near(g[3], 0.172) and CO_Near(g[4], 0.246)
		and k[3] == 0 and CO_Near(k[4], 0.094) and CO_Near(k[5], 0.071) and CO_Near(mo[5], 0.103) and CO_Near(x[3], 0.093),
		"region shares: Dosis 0.345/0.246, Golkonda 0.172/0.246, Kadi 0.094/0.071, Moscowia 0.103, xt27 0.093");
	local e0 = 0;
	local ns = {"elinor", "gefest", "torr"};
	for i = 1, 3 do local e = S(ns[i]); e0 = e0 + e[3] + e[4] + e[5]; end;
	HOST_Check(e0 == 0 and rg[V_Slot("elinor")].N > 0, "Elinor, Gefest, Torr: no carriers");
	local d3, d4, g3, g4, k4, k5, m5, x3 = S("dosis", 3), S("dosis", 4), S("golkonda", 3), S("golkonda", 4), S("kadi", 4), S("kadi", 5), S("moscowia", 5), S("xt93", 3);
	HOST_Check(CO_Near(d3[3], 0.553) and CO_Near(d4[4], 0.441) and CO_Near(d3[3] + d3[4], 0.75) and CO_Near(g3[3], 0.345)
		and CO_Near(g4[4], 0.492) and CO_Near(k4[4], 0.188) and CO_Near(k5[5], 0.141) and CO_Near(m5[5], 0.206) and CO_Near(x3[3], 0.187),
		"own-system shares: Dosis 0.553/0.441 (capped at 0.75), Golkonda 0.345/0.492, Kadi 0.188/0.141, Moscowia 0.206, xt27 0.187");
	local dp, kj = S("dosis", nil, {[3]=1}), S("kadi", nil, nil, {[5]=1});
	HOST_Check(dp[3] == 0 and CO_Near(dp[4], 0.246) and CO_Near(kj[5], 0.141) and CO_Near(kj[4], 0.094), "pulled corporation 0; an open run doubles its share");
	-- Pick bounds, the label roll, the hash.
	local s = {[3]=0.2, [4]=0.3, [5]=0.1};
	HOST_Check(TRF_CrpPickOf(0, s) == 3 and TRF_CrpPickOf(0.1999, s) == 3 and TRF_CrpPickOf(0.2, s) == 4 and TRF_CrpPickOf(0.4999, s) == 4
		and TRF_CrpPickOf(0.5, s) == 5 and TRF_CrpPickOf(0.6, s) == nil and TRF_CrpPickOf(0, {[3]=0, [4]=0, [5]=0.5}) == 5,
		"TRF_CrpPickOf at the bounds");
	local r0 = h.rand;
	local ok = 1;
	for nm = 1, 40 do
		for sl = 1, 8 do
			local u = TRF_CrpUOf(nm, sl);
			if not (u >= 0 and u < 1) or u ~= TRF_CrpUOf(nm, sl) then ok = nil; end;
		end;
	end;
	local hok = 1;
	for sl = 1, 8 do
		for L = 0, 300, 7 do
			local v = TRF_CrpHashOf(sl, L, 1);
			if v < 0 or v > 9999 or v ~= floor(v) or v ~= TRF_CrpHashOf(sl, L, 1) then hok = nil; end;
		end;
	end;
	HOST_Check(ok and hok and h.rand == r0 and TRF_CrpHashOf(4, 100, 1) ~= TRF_CrpHashOf(4, 100, 2), "label roll in [0, 1) and hash in 0..9999, repeatable, no RAND draw");
	-- Block string round trip (3.1).
	ok = 1;
	local ps, ts, xs = {0, 3, 4, 5}, {0, 1, 3, 4, 5}, {0, 3, 4, 5};
	for i = 1, 4 do for j = 1, 5 do for q = 1, 4 do
		local b = {a={[3]=mod(i + j, 10), [4]=9, [5]=mod(q * 3, 10)}, p=ps[i], t=ts[j], x=xs[q], e=i * 12345 + j};
		local st = TRF_CrpBlkStr("", 3, b, 8);
		local b2 = TRF_CrpBlkOf(st, 3);
		if strlen(st) ~= 88 or b2.a[3] ~= b.a[3] or b2.a[4] ~= 9 or b2.a[5] ~= b.a[5] or b2.p ~= b.p or b2.t ~= b.t or b2.x ~= b.x or b2.e ~= b.e
			or TRF_CrpBlkOf(st, 2).e ~= 0 then ok = nil; end;
	end; end; end;
	HOST_Check(ok and TRF_CrpEncOf({a={[3]=12, [4]=0, [5]=0}, p=4, t=1, x=0, e=123456}) == "90041099999" and TRF_CrpZeroOf(strrep("0", 88))
		and not TRF_CrpZeroOf("00000000010") and TRF_CrpBlkOf("0a000000000", 1).p == 0, "block encode and decode for every field value; clamps; zero test");
	HOST_Check(TRF_CrpSigOf(3, 7) == nil and TRF_CrpSigOf(4, 7) == "WBoost3" and TRF_CrpSigOf(5, 0) == "RBot3" and TRF_CrpSigOf(5, 1) == "LRRNB3"
		and TRF_CrpSigOf(5, 2) == "PLC2" and TRF_CrpSigOf(5, 5) == "PLC2", "signature items: none, WBoost3, RBot3/LRRNB3/PLC2 by name");
	local pt = TRF_CrpTune();
	local bb = {a={[3]=3, [4]=3, [5]=1}, p=0};
	local f1 = TRF_CrpPullOf(bb, pt, 0, {[3]=4, [4]=4, [5]=0});
	local f2, w2 = TRF_CrpPullOf({a={[3]=2, [4]=4, [5]=5}, p=0}, pt, 0, {[3]=4, [4]=4, [5]=0});
	local f3, w3, fb = TRF_CrpPullOf(bb, pt, 2, {[3]=4, [4]=4, [5]=0});
	local f4, w4 = TRF_CrpPullOf({a={[3]=1, [4]=2, [5]=0}, p=0}, pt, 0, {[3]=4, [4]=4, [5]=0});
	HOST_Check(f1 == 3 and f2 == 4 and f3 == nil and w3 == "cap" and fb == 3 and f4 == nil and w4 == "none",
		"pull-out choice: a tie to the lower corporation, none without systems in the region, the cap");
end;

-- b: labels and text surfaces (5.1, 5.2) ------------------------------------------------------------

function T_CO_B()
	local h = HOST();
	CO_Begin("kondel", "5_1");
	local sl = V_Slot("kondel");
	-- 200 names in a Triada system of Dosis: rates within 3 points of the shares.
	local s = CO_Shares();
	local n0 = S_Mark();
	local c = CO_Rates(200);
	HOST_Check(abs(c[3] / 200 - s[3]) <= 0.03 and abs(c[4] / 200 - s[4]) <= 0.03 and c[5] == 0,
		"Dosis Triada system: Triada "..c[3].."/200 (share "..TRF_F(s[3]).."), USS "..c[4].."/200 (share "..TRF_F(s[4])..")");
	HOST_Check(CO_Logs(n0, "event=label trader_id=9001 ") == 1 and CO_Logs(n0, "event=label ") == 200, "one label line per record");
	-- The excluded record kinds.
	local ks = {own=4, fw=1, wq=1, cv=1, feq=1, sev=1, tier=4};
	local nk = 0;
	for k, v in ks do
		local x = {};
		x[k] = v;
		local r = CO_Rec(9500, 3, x);
		if TRF_Crp_Label(9500) == nil and r.crp == nil then nk = nk + 1; end;
		TRF.live.tr[9500] = nil;
	end;
	HOST_Check(nk == 7 and CO_Logs(n0, "reason=kind") == 7, "no label on supply, freight, quest, danger convoy, feq, station event or TT4 records");
	-- A labelled record keeps its label; the same name in the same region draws the same corporation.
	local r1 = CO_Rec(9600, 3);
	local f1 = TRF_Crp_Label(9600);
	local r2 = CO_Rec(9601, 3);
	HOST_Check(f1 and TRF_Crp_Label(9600) == nil and r1.crp == f1 and TRF_Crp_Label(9601) == f1, "label stored once; same name, same corporation");
	TRF.live.tr[9600] = nil; TRF.live.tr[9601] = nil;
	-- Kadi InoCo system and Elinor.
	T_Jump("gaoba");
	s = CO_Shares();
	c = CO_Rates(200);
	HOST_Check(abs(c[4] / 200 - s[4]) <= 0.03 and abs(c[5] / 200 - s[5]) <= 0.03 and c[3] == 0,
		"Kadi InoCo system: USS "..c[4]..", InoCo "..c[5].." of 200 (shares "..TRF_F(s[4])..", "..TRF_F(s[5])..")");
	T_Jump("elinor");
	n0 = S_Mark();
	c = CO_Rates(50);
	HOST_Check(c.none == 50 and CO_Logs(n0, "reason=nocorp") == 50, "Elinor: no label");
	-- The generator hook: real spawns in Dosis are labelled with their record's name.
	T_Jump("kondel");
	n0 = S_Mark();
	local lab, n = 0, 0;
	for k = 1, 12 do
		local id = T_Spawn("A");
		if id then
			n = n + 1;
			if TRF.live.tr[id].crp then lab = lab + 1; end;
			V_NoRaid(id);
			TRF_Remove(id, "test");
		end;
		TRF.live.port = {};
	end;
	HOST_Check(n >= 10 and CO_Logs(n0, "event=label ") >= n and lab >= 1, "trf_gen labels its plain spawns ("..lab.." of "..n..")");
	-- trf_track rebuild of a labelled trader in the same region keeps its corporation (TRF_TrackSpawn label hook).
	local nm = nil;
	for k = 1, 60 do
		local r = CO_Rec(9700, k);
		if TRF_Crp_Label(9700) then nm = k; end;
		TRF.live.tr[9700] = nil;
		if nm then break; end;
	end;
	local fx = CO_Rec(9700, nm);
	local fexp = TRF_Crp_Label(9700);
	TRF.live.tr[9700] = nil;
	V_ClearTr();
	local cur = TRF_CurIdx();
	TRF.tp = {TRF_TpPack({id=7400, nm=nm, o=0, c=1, tt=1, pw=3, n=1, e=0, s=cur, fr=cur, d=0, dm=0, fl=0, t=floor(TRF.clock.gt)})};
	local tid = TRF_TrackSpawn(7400, "dock");
	HOST_Check(tid and TRF.live.tr[tid].nm == nm and TRF.live.tr[tid].crp == fexp, "trf_track rebuild: name "..tostring(nm).." keeps corporation "..tostring(fexp));
	if tid then TRF_Remove(tid, "test"); end;
	-- A rebuild in another system of the region whose owner shares would draw another corporation: the pool record's fl
	-- carries the corporation (bits 64, 128), the label is kept.
	local fl = TRF_TkFlags(9800, CO_Rec(9800, 1, {crp=13}));
	TRF.live.tr[9800] = nil;
	local ui, oi = nil, nil;
	for i = 1, getn(TRF_RgMap()[sl].sys) do
		local k = TRF_RgMap()[sl].sys[i];
		if TRF_CrpOwn(k) == 4 and (TRF_RgMap().pc[k] or 0) > 0 then ui = ui or k; end;
	end;
	local rgc, T = TRF_CrpCache()[sl], TRF_CrpTune();
	local sa, sb = TRF_CrpSharesOf(rgc, 3, T, {}, nil), TRF_CrpSharesOf(rgc, 4, T, {}, nil);
	local nx = nil;
	for k = 1, 400 do
		local u = TRF_CrpUOf(k, sl);
		if not nx and TRF_CrpPickOf(u, sa) == 3 and TRF_CrpPickOf(u, sb) ~= 3 then nx = k; end;
	end;
	HOST_Check(fl == 64 and TRF_TkCrpOf(fl) == 3 and TRF_TkCrpOf(TRF_TkCrpFl(fl + 8, 5)) == 5 and TRF_TkCrpOf(TRF_TkCrpFl(fl, nil)) == nil
		and ui and nx, "pool fl holds the corporation; a USS system in Dosis ("..tostring(ui)..") and a name Triada only in kondel ("..tostring(nx)..")");
	if ui and nx then
		T_Jump(TRF_Map().sys[ui].name);
		V_ClearTr();
		n0 = S_Mark();
		TRF.tp = {TRF_TpPack({id=7401, nm=nx, o=0, c=1, tt=1, pw=3, n=1, e=0, s=ui, fr=cur, d=1, dm=0, fl=64, t=floor(TRF.clock.gt)})};
		tid = TRF_TrackSpawn(7401, "port");
		HOST_Check(tid and TRF.live.tr[tid].crp == 3 and CO_Logs(n0, "corp=Triada reason=kept") == 1,
			"trf_track rebuild in "..TRF_Map().sys[ui].name..": name "..nx.." stays Triada (kept)");
		if tid then TRF_Remove(tid, "test"); end;
		T_Jump("kondel");
	end;
	-- Spawn volume and RAND draws: the same generator run with and without the module.
	local runs = {};
	for pass = 1, 2 do
		h.cfg.corp = 2 - pass;
		for id, r in TRF.live.tr do V_NoRaid(id); end;
		V_ClearTr();
		TRF.live.port = {};
		h.seed = 4242;
		local r0, q0 = h.rand, TRF.seq;
		for k = 1, 40 do T_Gen(); TRF.live.port = {}; end;
		local nl = 0;
		for id, r in TRF.live.tr do if type(r) == "table" and r.crp then nl = nl + 1; end; end;
		runs[pass] = {d=h.rand - r0, s=TRF.seq - q0, l=nl};
	end;
	h.cfg.corp = nil;
	HOST_Check(runs[1].d == runs[2].d and runs[1].s == runs[2].s and runs[2].l == 0,
		"40 generator ticks: same spawns ("..runs[1].s.."/"..runs[2].s..") and RAND draws ("..runs[1].d.."/"..runs[2].d..", labels "..runs[2].l..") with corp 1 and 0; no label with corp 0");
	V_ClearTr();
	-- Text surfaces: an InoCo carrier "Kestrel".
	local id = CO_Trader(5);
	local r = TRF.live.tr[id];
	local nmn = TRF_UI_Name(r.nm);
	local hw = CO_Hull(r, id);
	local dir = TRF_UI_DirText(r);
	HOST_Check(TRF_Crp_Open(r) == "FTU "..nmn..", InoCo contract carrier, open for trade" and TRF_UI_Who(r, id) == "InoCo contract "..hw.." "..nmn
		and TRF_Crp_Head(r) == "InoCo contract carrier. What do you need, Wolves?", "greeting, who and head of an InoCo carrier ("..TRF_UI_Who(r, id)..")");
	HOST_Check(CO_Has(TRF_Headed(id), "InoCo cargo, "..dir..". ") == 1, "where headed: "..TRF_Headed(id));
	HOST_Check(CO_Has(TRF_UI_FocusText(r, id), "InoCo contract "..hw.." "..nmn..": ") == 1, "focus line: "..TRF_UI_FocusText(r, id));
	TRF.std.fst = "55552";
	local lo = TRF_Crp_Open(r);
	TRF.std.fst = "55558";
	local hi = TRF_Crp_Open(r);
	TRF.std.fst = "55555";
	HOST_Check(lo == "FTU "..nmn..", InoCo contract carrier. InoCo says the Wolves are trouble, but trade's trade"
		and hi == "FTU "..nmn..", InoCo contract carrier. InoCo speaks well of the Wolves. Open for trade", "standing variants at fst 2 and 8");
	-- The announce line through trf_ui (meet 2) and the dialog head (hail_box 2).
	local s0 = getn(h.screen);
	V_Hail(id);
	local said = "";
	for i = s0 + 1, getn(h.screen) do said = said..h.screen[i].t.."|"; end;
	HOST_Check(CO_Has(said, "FTU "..nmn..", InoCo contract carrier, open for trade") == 1, "announce names the corporation: "..said);
	V_HailEnd();
	-- A fresh carrier (the hail cooldown is per trader).
	local id2 = CO_Trader(5);
	local r2 = TRF.live.tr[id2];
	h.cfg.tune = {hail_box=2};
	h.cfg.hail_xml = 1;
	TRF_UiState = HOST_UiState; h.ui = 0;
	local us3 = __sys_FTrader_3;
	__sys_FTrader_3 = 0;
	r2.co = 1;
	TRF.std.heat = 0;
	T_MoveTr(id2, h.ms.pos.x + 40, h.ms.pos.y, h.ms.pos.z);
	TRF_HailOpen(id2, "focus");
	local st = TRF_HlStore();
	HOST_Check(st and st.dlg and st.dlg.head == "InoCo contract carrier. What do you need, Wolves?", "dialog head (hail_box 2): "..tostring(st and st.dlg and st.dlg.head));
	HOST_DlgPick("a_close");
	T_Tick(2, 0.5);
	__sys_FTrader_3 = us3;
	h.cfg.tune = {};
	h.cfg.hail_xml = nil;
	-- An independent and cfg corp 0 keep the built texts (the second carrier).
	nmn = TRF_UI_Name(r2.nm);
	hw = CO_Hull(r2, id2);
	local ri = {id=1, nm=r2.nm, path="A", from=r2.from, to=r2.to, cls=1, nt=r2.nt};
	h.cfg.corp = 0;
	local w0, o0 = TRF_UI_Who(r2, id2), TRF_Crp_Open(r2);
	h.cfg.corp = nil;
	HOST_Check(TRF_Crp_Open(ri) == nil and TRF_UI_Who(ri, id2) == "FTU "..hw.." "..nmn and w0 == "FTU "..hw.." "..nmn and o0 == nil
		and CO_Has(TRF_Headed(id2), "InoCo cargo") == 1, "independent and corp 0: the built FTU texts");
	-- crp_ch 4 at chapter 3: no label.
	h.labels.CurrentQuest = "3";
	h.cfg.tune = {crp_ch=4};
	n0 = S_Mark();
	c = CO_Rates(20);
	h.cfg.tune = {};
	HOST_Check(c.none == 20 and CO_Logs(n0, "reason=chapter") == 20, "crp_ch 4 at chapter 3: no label");
	V_ClearTr();
end;

-- c: carrier shop (5.2) ---------------------------------------------------------------------------

function T_CO_C()
	local h = HOST();
	-- Every system gets a usable trade station (path A and B spawns in Gaoba).
	h.st_label = "TRADE STATION";
	CO_Begin("gaoba", "5_1", {log=2});
	local res = {};
	local fs = {5, 4, 3, 0};
	for i = 1, 4 do
		local id = CO_Trader(fs[i]);
		local r = TRF.live.tr[id];
		r.hold = {};
		if fs[i] == 0 then r.crp = nil; end;
		local n0 = S_Mark();
		h.mwrites = {};
		h.rq = {2};
		TRF_ShopOpen(id);
		h.rq = {};
		local eq = CO_Equip(n0, id);
		local sh = TRF_ShopName(TRF_ShopSlot(r));
		local w = V_Writes(sh);
		local cnt, co = {}, {};
		for j = 1, getn(w) do if w[j].n and w[j].n > 0 then cnt[w[j].i] = w[j].n; co[w[j].i] = w[j].s..":"..w[j].b; end; end;
		res[i] = {id=id, r=r, eq=eq, cnt=cnt, co=co, n0=n0};
	end;
	-- InoCo: RBot3/LRRNB3/PLC2 by name first at count 1, the rest from Gun_List_InoCo and Syst_List, 5 items in all.
	local a = res[1];
	local sig = TRF_CrpSigOf(5, a.r.nm);
	local pool = CO_Pool("Gun_List_InoCo");
	local inpool = 1;
	for j = 1, getn(a.eq) do if not pool[a.eq[j]] then inpool = nil; end; end;
	HOST_Check(a.eq[1] == sig and a.cnt[sig] == 1 and getn(a.eq) == 5 and inpool and CO_Shop(a.n0, "corp=Inoco signature="..sig) == 1,
		"InoCo carrier: "..sig.." first at count 1, 5 items from its pool ("..TRF_KvV(a.eq)..")");
	local b = res[2];
	pool = CO_Pool("Gun_List_Uss");
	inpool = 1;
	for j = 1, getn(b.eq) do if not pool[b.eq[j]] then inpool = nil; end; end;
	HOST_Check(b.eq[1] == "WBoost3" and b.cnt.WBoost3 == 1 and getn(b.eq) == 5 and inpool, "USS carrier: WBoost3 first, USS pool ("..TRF_KvV(b.eq)..")");
	local c = res[3];
	pool = CO_Pool("Gun_List_Triada");
	inpool = 1;
	for j = 1, getn(c.eq) do if not pool[c.eq[j]] or c.cnt[c.eq[j]] ~= 2 then inpool = nil; end; end;
	HOST_Check(getn(c.eq) == 6 and inpool and CO_Shop(c.n0, "corp=Triada signature=nil") == 1, "Triada carrier: one item more (6), no signature, Triada pool");
	local d = res[4];
	pool = CO_Pool("Gun_List_InoCo");
	inpool = 1;
	for j = 1, getn(d.eq) do if not pool[d.eq[j]] or d.cnt[d.eq[j]] ~= 2 then inpool = nil; end; end;
	HOST_Check(getn(d.eq) == 5 and inpool and CO_Shop(d.n0, "owner=Inoco destination=") == 1 and CO_Shop(d.n0, "corp=nil signature=nil") == 1, "independent: the dock owner's pool (InoCo here), 5 items at count 2");
	-- Coefficients equal to the independent's.
	local cs = nil;
	for it, v in d.co do cs = v; end;
	local same = cs ~= nil;
	for i = 1, 3 do for it, v in res[i].co do if res[i].cnt[it] and v ~= cs then same = nil; end; end; end;
	HOST_Check(same, "coefficients of every carrier item equal to the independent's ("..tostring(cs)..")");
	-- crp_sig_ch 5 at chapter 4: no signature.
	h.labels.CurrentQuest = "4";
	h.cfg.tune = {crp_sig_ch=5};
	local id = CO_Trader(5);
	TRF.live.tr[id].hold = {};
	local n0 = S_Mark();
	TRF_ShopOpen(id);
	h.cfg.tune = {};
	local eq = CO_Equip(n0, id);
	HOST_Check(CO_Shop(n0, "corp=Inoco signature=nil") == 1 and getn(eq) >= 3 and getn(eq) <= 6, "crp_sig_ch 5 at chapter 4: no signature item");
	V_ClearTr();
end;

-- d: counts, standing and the pull-out (5.3, 5.4) -------------------------------------------------------

function T_CO_D()
	local h = HOST();
	CO_Begin("golkonda", "5_1");
	local gs = V_Slot("golkonda");
	TRF.std.fst = "55555";
	-- Three player kills of USS carriers.
	local n0 = S_Mark();
	for k = 1, 3 do
		local id = CO_Trader(4);
		V_PlayerKill(id);
	end;
	HOST_Check(CO_B(gs) == "030000/0" and TRF_Fst(4) == 4 and CO_Logs(n0, "event=hit ") == 3
		and CO_Logs(n0, "how=kill by=player count_before=2 count=3 player_caused=true result=counted") == 1,
		"three player kills: count 3, fst -1 once per visit ("..CO_B(gs)..", fst "..TRF_Fst(4)..")");
	-- A robbed carrier counts once, the later kill of it is skipped.
	TRF.crp = nil;
	n0 = S_Mark();
	local id = CO_Trader(4);
	local r = TRF.live.tr[id];
	TRF_SpComply(id, r, TRF_H().tr[id], TRF_CurIdx());
	HOST_Check(r.crp == 14 and CO_B(gs) == "010000/0" and CO_Logs(n0, "how=rob by=player count_before=0 count=1 player_caused=true result=counted") == 1,
		"robbery: counted, the record marked 14");
	V_PlayerKill(id);
	HOST_Check(CO_B(gs) == "010000/0" and CO_Logs(n0, "how=kill by=player result=skipped reason=counted") == 1, "the kill of a counted carrier is skipped");
	-- A raid kill (no player fire): counted, no standing hit.
	T_Enter("golkonda");
	TRF.std.fst = "55555";
	n0 = S_Mark();
	id = CO_Trader(3);
	CO_OtherKill(id);
	HOST_Check(CO_B(gs) == "110000/0" and TRF_Fst(3) == 5 and CO_Logs(n0, "how=kill by=other count_before=0 count=1 player_caused=false result=counted") == 1,
		"raid kill: counted, no standing change");
	-- Chapter 4: nothing.
	h.labels.CurrentQuest = "4";
	n0 = S_Mark();
	id = CO_Trader(4);
	V_PlayerKill(id);
	HOST_Check(CO_B(gs) == "110000/0" and CO_Logs(n0, "result=skipped reason=chapter") == 1, "chapter 4: no count");
	h.labels.CurrentQuest = "5_1";
	-- Region tick: USS 3 in Golkonda pulls out at the next tick.
	local L = TRF.clock.legs;
	CO_Put(gs, 1, 3, 0, 0, 0, 4, 0);
	TRF.newsx = nil;
	n0 = S_Mark();
	TRF_Crp_RegionTick(L);
	HOST_Check(CO_B(gs) == "100410/"..(L + 24) and TRF.newsx[gs].crp.v == "out_4" and TRF.newsx[gs].crp.n == 1
		and CO_Logs(n0, "event=pull region="..gs.." corp=Uss count=3 end_leg="..(L + 24).." leg="..L.." active_count=1 result=out") == 1,
		"pull-out: USS out of Golkonda for 24 legs, the news topic out_4, the count and the mark of USS reset ("..CO_B(gs)..")");
	HOST_Check(TRF_UI_NewsText("crp", "out_4", gs) == "USS pulls its contract carriers off the lanes near Golkonda", "news text: "..TRF_UI_NewsText("crp", "out_4", gs));
	-- Labels during it: no USS carrier in Golkonda; reason=pulled for a name USS would have taken.
	T_Jump("debris4");
	n0 = S_Mark();
	local c = CO_Rates(200);
	HOST_Check(c[4] == 0 and c[3] > 0 and CO_Logs(n0, "reason=pulled pulled=Uss") >= 1 and CO_Shares()[4] == 0, "USS pulled: no USS label, Triada still ("..c[3]..")");
	-- A USS carrier labelled before the pull-out and killed during it: the standing hit, no count.
	n0 = S_Mark();
	id = CO_Trader(4);
	V_PlayerKill(id);
	HOST_Check(CO_B(gs) == "100410/"..(L + 24) and CO_Logs(n0, "how=kill by=player count_before=0 count=0 player_caused=true result=pulled") == 1,
		"a kill of the pulled corporation's carrier: not counted ("..CO_B(gs)..")");
	-- The cap: two regions out, a third blocked.
	local ds, ks = V_Slot("dosis"), V_Slot("kadi");
	CO_Put(ds, 0, 0, 0, 3, 1, 0, L + 10);
	CO_Put(ks, 0, 0, 3, 0, 0, 0, 0);
	n0 = S_Mark();
	TRF_Crp_RegionTick(L + 1);
	HOST_Check(CO_B(ks) == "003000/0" and CO_Logs(n0, "event=pull region="..ks.." corp=Inoco count=3 leg="..(L + 1).." active_count=2 result=blocked reason=cap") == 1,
		"a third region while two are out: blocked (cap), the count stays");
	-- The end of the Dosis pull-out: untold, so it ends silently; the Golkonda one after 24 legs, told: t = 4.
	n0 = S_Mark();
	TRF_Crp_RegionTick(L + 10);
	HOST_Check(CO_B(ds) == "000000/0" and CO_Logs(n0, "event=return region="..ds.." corp=Triada leg="..(L + 10).." told=false") == 1
		and CO_B(ks) == "000510/"..(L + 34), "Dosis ends untold (t 0); Kadi starts once a slot is free ("..CO_B(ks)..")");
	CO_Put(gs, 1, 0, 0, 4, 0, 0, L + 24);
	n0 = S_Mark();
	TRF_Crp_RegionTick(L + 23);
	HOST_Check(CO_B(gs) == "100400/"..(L + 24), "before the end leg: still out");
	TRF_Crp_RegionTick(L + 24);
	HOST_Check(CO_B(gs) == "100040/0" and TRF.newsx[gs].crp == nil and CO_Logs(n0, "event=return region="..gs.." corp=Uss leg="..(L + 24).." told=true") == 1,
		"end after 24 legs: told pull-out, return pending (t 4), the news topic removed");
	-- A pull-out that ends while another count is at 3: no new one in the same tick, the return line stays pending.
	CO_Put(gs, 3, 0, 0, 4, 0, 0, L + 26);
	n0 = S_Mark();
	TRF_Crp_RegionTick(L + 26);
	HOST_Check(CO_B(gs) == "300040/0" and CO_Logs(n0, "event=pull ") == 0, "end and a count of 3 in one tick: the return stays pending ("..CO_B(gs)..")");
	-- Quiet: counts and the mark reset.
	CO_Put(gs, 2, 1, 0, 0, 4, 3, 0);
	TRF.rg[gs].ph = 0;
	n0 = S_Mark();
	TRF_Crp_RegionTick(L + 30);
	HOST_Check(CO_B(gs) == "000040/0" and CO_Logs(n0, "event=reset region="..gs) == 1, "Quiet: counts and run mark reset, the pending return stays");
	-- Off-screen roll: Golkonda in Raids at T4, 200 legs, no pull-out (crp_pull_n 9).
	TRF.crp = nil;
	h.cfg.tune = {crp_pull_n=9};
	TRF.rg[gs].ph = 3;
	TRF.clan[gs].sc = 95; TRF.clan[gs].tr = 4;
	local tier = TRF_ClanTier(gs);
	local r0 = h.rand;
	n0 = S_Mark();
	for k = 1, 200 do
		TRF.crp = nil;
		TRF_Crp_RegionTick(1000 + k);
	end;
	local no = CO_Logs(n0, "event=offscreen region="..gs.." tier=4 chance=40 ");
	local n3, n4 = CO_Logs(n0, "event=offscreen region="..gs.." tier=4 chance=40 hash="), 0;
	n4 = CO_Logs(n0, "corp=Uss count=1");
	local seq1 = "";
	for k = 1, 30 do seq1 = seq1..TRF_CrpHashOf(gs, 1000 + k, 1)..","; end;
	HOST_Check(tier == 4 and no >= 60 and no <= 100 and n4 > 0 and n4 < no and h.rand == r0, "T4 Raids: "..no.." off-screen losses in 200 legs (40 %), Triada and USS by share, no RAND draw");
	-- Determinism: the same leg sequence gives the same counts.
	TRF.crp = nil;
	for k = 1, 20 do TRF_Crp_RegionTick(2000 + k); end;
	local st1 = TRF.crp;
	TRF.crp = nil;
	for k = 1, 20 do TRF_Crp_RegionTick(2000 + k); end;
	HOST_Check(st1 == TRF.crp and st1 ~= nil, "deterministic for a fixed leg sequence ("..tostring(st1)..")");
	-- T2 and Build-up: none.
	TRF.clan[gs].sc = 10; TRF.clan[gs].tr = 1;
	n0 = S_Mark();
	TRF.crp = nil;
	for k = 1, 50 do TRF_Crp_RegionTick(3000 + k); end;
	TRF.clan[gs].sc = 95; TRF.clan[gs].tr = 4;
	TRF.rg[gs].ph = 2;
	for k = 1, 50 do TRF_Crp_RegionTick(4000 + k); end;
	HOST_Check(CO_Logs(n0, "event=offscreen") == 0 and TRF.crp == nil, "no off-screen loss at T1 or outside Raids");
	-- crp_off_pct 0: none; chapter 4: none.
	TRF.rg[gs].ph = 3;
	h.cfg.tune = {crp_pull_n=9, crp_off_pct=0};
	n0 = S_Mark();
	for k = 1, 30 do TRF_Crp_RegionTick(5000 + k); end;
	h.cfg.tune = {crp_pull_n=9};
	h.labels.CurrentQuest = "4";
	for k = 1, 30 do TRF_Crp_RegionTick(6000 + k); end;
	h.labels.CurrentQuest = "5_1";
	h.cfg.tune = {};
	HOST_Check(CO_Logs(n0, "event=offscreen") == 0, "crp_off_pct 0 and chapter 4: no off-screen roll");
	-- The tick runs inside TRF_RegionTick before the charter's.
	TRF.crp = nil;
	CO_Put(gs, 0, 3, 0, 0, 0, 0, 0);
	n0 = S_Mark();
	TRF_RegionTick(TRF.clock.legs);
	HOST_Check(CO_Logs(n0, "event=pull region="..gs.." corp=Uss") == 1, "TRF_RegionTick runs the corporation tick");
	V_ClearTr();
end;

-- e: dock line (5.5) ------------------------------------------------------------------------------------

function T_CO_E()
	local h = HOST();
	CO_Begin("golkonda", "5_1");
	TRF_SetPro(TRF_CurIdx(), 9);
	local gs = V_Slot("golkonda");
	local L = TRF.clock.legs;
	-- USS pulled out of Golkonda, untold: the out line once, after the station's req line.
	CO_Put(gs, 0, 0, 0, 4, 1, 0, L + 24);
	local n0 = S_Mark();
	local r = CO_Dock();
	local out = "Dockmaster: USS pulled its contract carriers off the Golkonda lanes after the losses. Free traders fly the routes until they come back.";
	local is, ic = CO_At(n0, "module=station event=dock "), CO_At(n0, "module=corp event=dock ");
	HOST_Check(r and CO_Has(r.scr, out) and r.nb == 1 and is and ic and is < ic and CO_Logs(n0, "event=dock system=golkonda region="..gs.." kind=out corp=Uss") == 1
		and CO_B(gs) == "000400/"..(L + 24), "out line once at the first approach, after the station's line; t 1 -> 0 ("..tostring(r and r.scr)..")");
	-- Saved across a load: told, so no second out line.
	T_SaveLoad();
	CO_NewVisit();
	h.cfg.tune = {crp_id_pct=0};
	n0 = S_Mark();
	r = CO_Dock();
	HOST_Check(not CO_Has(r.scr, "Dockmaster: USS") and CO_Logs(n0, "kind=none") == 1, "after a load: the told pull-out is not told again");
	-- The return: back line once.
	CO_Put(gs, 0, 0, 0, 0, 4, 0, 0);
	n0 = S_Mark();
	r = CO_Dock();
	local r2 = CO_Dock();
	HOST_Check(CO_Has(r.scr, "Dockmaster: USS carriers are back on the Golkonda lanes. Business as usual.") and not CO_Has(r2.scr, "back on")
		and CO_Logs(n0, "kind=back corp=Uss") == 1 and TRF.crp == nil, "back line once; the state string goes when all zero");
	-- Identity line: Triada owns Golkonda; crp_id_pct 100 once per visit, 0 never.
	h.cfg.tune = {crp_id_pct=100};
	CO_NewVisit();
	n0 = S_Mark();
	r = CO_Dock();
	r2 = CO_Dock();
	HOST_Check(CO_Has(r.scr, "Dockmaster: Triada carriers work the Golkonda lanes. Fair prices, and nobody asks where the cargo came from.")
		and not CO_Has(r2.scr, "Triada carriers") and CO_Logs(n0, "kind=id corp=Triada") == 1, "identity line once per visit");
	-- A USS dock in Dosis; a pulled corporation gets no identity line.
	T_Jump("dalled");
	CO_NewVisit();
	n0 = S_Mark();
	r = CO_Dock();
	HOST_Check(CO_Has(r.scr, "Dockmaster: USS moves its caravans through Dosis on FTU contract carriers. Their holds carry USS stock."), "USS identity line in Dosis: "..tostring(r.scr));
	CO_Put(V_Slot("dalled"), 0, 0, 0, 4, 0, 0, TRF.clock.legs + 5);
	CO_NewVisit();
	r = CO_Dock();
	HOST_Check(not CO_Has(r.scr, "USS moves"), "pulled corporation: no identity line");
	TRF.crp = nil;
	-- An Elinor dock: nothing.
	local es = V_Slot("elinor");
	local edock = nil;
	local m = TRF_Map();
	for i = 1, getn(TRF_RgMap()[es].sys) do
		local k = TRF_RgMap()[es].sys[i];
		for j = 1, getn(m.sys[k].st or {}) do if m.sys[k].st[j].kind == "trade" then edock = edock or m.sys[k].name; end; end;
	end;
	T_Jump(edock);
	n0 = S_Mark();
	r = CO_Dock();
	HOST_Check(CO_Logs(n0, "event=dock system="..edock.." region="..es.." kind=none") == 1, "Elinor dock ("..edock.."): no line");
	-- Gates: latch, strict denial, scene, flags, chapter, corp 0; one pass line per reason and visit.
	T_Jump("golkonda");
	local E2 = TRF.clock.legs + 24;
	CO_Put(gs, 0, 0, 0, 4, 1, 0, E2);
	h.qs = TRUE;
	n0 = S_Mark();
	CO_Dock(); CO_Dock();
	h.qs = FALSE;
	HOST_Check(CO_Logs(n0, "event=pass reason=latch at=dock") == 1 and CO_B(gs) == "000410/"..E2, "latch: no line, one pass line");
	-- Strict gate: a system that a quest names, with a trade station (the gate comes before the region).
	local qn = nil;
	local mq = TRF_Map();
	for i = 1, getn(mq.sys) do
		local sy = mq.sys[i];
		if not qn and type(sy.qi) == "table" and getn(sy.qi) > 0 then
			for j = 1, getn(sy.st or {}) do if sy.st[j].kind == "trade" then qn = sy.name; end; end;
		end;
	end;
	T_Jump(qn);
	CO_NewVisit();
	local qi = TRF_Map().sys[TRF_CurIdx()].qi;
	h.quests = {};
	h.quests[qi[1]] = QUEST_PROCESS;
	TRF.live.qa = nil; TRF.live.qai = nil; TRF_H().loc = nil; TRF.live.gl = nil;
	n0 = S_Mark();
	CO_Dock();
	h.quests = {};
	TRF.live.qa = nil; TRF.live.qai = nil; TRF_H().loc = nil; TRF.live.gl = nil;
	HOST_Check(CO_Logs(n0, "event=pass reason=gate:") == 1 and CO_Logs(n0, "event=dock ") == 0, "strict gate: a quest names the system ("..tostring(qn)..")");
	T_Jump("golkonda");
	CO_NewVisit();
	TRF_UiState = HOST_UiState; h.ui = 4;
	n0 = S_Mark();
	CO_Dock();
	h.ui = 0;
	HOST_Check(CO_Logs(n0, "event=pass reason=scene at=dock") == 1 and CO_Logs(n0, "event=dock ") == 0, "scene: no line");
	CO_NewVisit();
	__sys_SOS = TRUE;
	n0 = S_Mark();
	CO_Dock();
	__sys_SOS = FALSE;
	HOST_Check(CO_Logs(n0, "module=corp") == 0, "__sys_SOS: the dispatcher skips the line");
	h.cfg.tune = {crp_ch=6};
	n0 = S_Mark();
	CO_Dock();
	h.cfg.tune = {crp_id_pct=100};
	h.cfg.corp = 0;
	CO_Dock();
	h.cfg.corp = nil;
	HOST_Check(CO_Logs(n0, "event=pass reason=chapter at=dock") == 1 and CO_Logs(n0, "event=pass reason=off at=dock") == 1
		and CO_B(gs) == "000410/"..E2, "crp_ch above the chapter, corp 0: pass lines, nothing told ("..CO_B(gs)..")");
	n0 = S_Mark();
	r = CO_Dock();
	HOST_Check(CO_Has(r.scr, "Dockmaster: USS pulled") and not CO_Has(r.scr, "Triada carriers work"), "one corporation line per approach (out before identity)");
	h.cfg.tune = {};
end;

-- f: the supply run (5.7) --------------------------------------------------------------------------------

function T_CO_F()
	local h = HOST();
	h.st_label = "TRADE STATION";
	CO_Begin("gaoba", "9_1", {charter=1});
	CO_Charter();
	local ks = V_Slot("gaoba");
	local C = TRF.ch;
	HOST_Check(type(C) == "table", "charter unlocked at chapter 9, help 3");
	-- A completed escort of an InoCo carrier: the run mark (and the kind 1 note as before).
	local n0 = S_Mark();
	local id = CO_Trader(5);
	local paid = CO_Escort(id);
	HOST_Check(paid == 1 and TRF_Crp_Mark(ks) == 5 and CO_Logs(n0, "event=escort trader_id="..id.." corp=Inoco region="..ks.." result=marked") == 1
		and S_Logs(n0, "module=charter event=note kind=escort ") == 1, "escort of an InoCo carrier: run mark 5, the kind 1 note as built");
	-- The next generation posts a type 7 run of InoCo there; the mark is used up.
	n0 = S_Mark();
	local cur = TRF_CurIdx();
	TRF_ChGenerate(C, cur);
	local p, pi = nil, nil;
	for i = 1, 3 do if type(C.g[i]) == "table" and C.g[i].t == 7 then p = C.g[i]; pi = i; end; end;
	HOST_Check(p and p.f == 5 and p.d == 5 and p.r == ks and p.k == 2 and p.e == TRF.clock.legs + 20 and TRF_Crp_Mark(ks) == nil
		and CO_Logs(n0, "event=mark_use region="..ks.." corp=Inoco") == 1 and h.qlog and S_Logs(n0, "event=post slot="..tostring(pi).." type=run region="..ks) == 1,
		"type 7 posting: InoCo, 2 deeds, deadline 20 legs; the mark cleared");
	HOST_Check(TRF_ChDescKey(p) == "#TRF_chd75" and TRF_ChTxt("chdeed7", 0, 2) == "contract carriers escorted 0 of 2", "logbook description chd75, board line chdeed7");
	-- While open: the InoCo share doubled, the offer floor 60.
	local js = TRF_Ch_RunOpen(ks);
	local s = CO_Shares();
	local s0 = TRF_CrpSharesOf(TRF_CrpCache()[ks], TRF_CrpOwn(cur), TRF_CrpTune(), {}, nil);
	id = CO_Trader(5);
	local r = TRF.live.tr[id];
	r.co = nil;
	n0 = S_Mark();
	TRF_CtOfferRoll(id, r, cur, TRF_Map().sys[cur]);
	HOST_Check(js and js[5] == 1 and CO_Near(s[5], 2 * s0[5]) and TRF_Crp_OfferMin(r) == 60 and S_Logs(n0, "chance=60.0") == 1,
		"open run: InoCo share x2 ("..TRF_F(s[5])..") and the escort offer floor 60");
	r.crp = nil;
	HOST_Check(TRF_Crp_OfferMin(r) == 0, "an independent: no floor");
	-- Two escorts of InoCo carriers: kind 9 deeds, no kind 1 note.
	T_Enter("gaoba");
	C = TRF.ch;
	n0 = S_Mark();
	for k = 1, 2 do
		id = CO_Trader(5);
		CO_Escort(id);
	end;
	HOST_Check(C.g[pi].p == 2 and C.g[pi].st == 1 and S_Logs(n0, "module=charter event=note kind=run ") == 2 and S_Logs(n0, "module=charter event=note kind=escort") == 0
		and CO_Logs(n0, "result=run") == 2, "two InoCo escorts: kind 9 deeds, the posting complete, no kind 1 note");
	-- Pay through the owed payer: credits through TRF_Pay, fst +1.
	TRF.std.fst = "55555";
	local c0 = h.credits;
	n0 = S_Mark();
	TRF.ch.pt = nil;
	TRF_Ch_Owe("trade");
	HOST_Check(C.g[pi] == nil and h.credits > c0 and TRF_Fst(5) == 6 and S_Logs(n0, "module=charter event=pay slot="..pi.." type=run") == 1
		and S_Logs(n0, "reason=\"charter run\"") >= 1, "pay: credits, fst 5 -> 6 ("..(h.credits - c0).." cr)");
	-- A USS escort while an InoCo run is open counts as kind 1 only.
	local L = TRF.clock.legs;
	C.g[1] = {t=7, r=ks, f=5, d=5, k=2, p=0, w=0, a=L, e=L + 20, st=0, pay=5000, rq=2, l=10};
	T_Enter("gaoba");
	C = TRF.ch;
	n0 = S_Mark();
	id = CO_Trader(4);
	CO_Escort(id);
	HOST_Check(C.g[1].p == 0 and S_Logs(n0, "kind=run system=gaoba region="..ks.." visit_deeds=0 result=none reason=corp faction=4") == 1 and S_Logs(n0, "module=charter event=note kind=escort") == 1,
		"a USS escort while an InoCo run is open: no deed (reason corp), the kind 1 note");
	-- Closes: pull-out, Bust, heat 5, a player trader kill, chapter 19.
	TRF_CrpPut(ks, {a={[3]=0, [4]=0, [5]=0}, p=5, t=1, x=0, e=L + 24});
	n0 = S_Mark();
	TRF_Ch_RegionTick(ks, L);
	HOST_Check(C.g[1].st == 3 and C.g[1].c == "pull" and S_Logs(n0, "event=close slot=1 type=run region="..ks.." done=0 needed=2 state=3 reason=pull") == 1,
		"pull-out: the run withdrawn (pull)");
	r = TRF_ChDockBody(C, cur);
	HOST_Check(r and CO_Has(r[1], "The corporation pulled its carriers out.") ~= nil, "close line names the pull-out");
	-- cfg corp 0: no deed can reach the run, it is withdrawn (pull) instead of failing at its deadline.
	TRF.crp = nil;
	C.g[1] = {t=7, r=ks, f=5, d=5, k=2, p=0, w=0, a=L, e=L + 20, st=0, pay=5000, rq=2, l=10};
	h.cfg.corp = 0;
	TRF_Ch_RegionTick(ks, L);
	h.cfg.corp = 1;
	HOST_Check(C.g[1].st == 3 and C.g[1].c == "pull", "cfg corp 0: the run withdrawn (pull)");
	C.g[1] = nil; C.cd[1] = nil;
	TRF.crp = nil;
	C.g[1] = {t=7, r=ks, f=5, d=5, k=2, p=0, w=0, a=L, e=L + 20, st=0, pay=5000, rq=2, l=10};
	TRF.rg[ks].ph = 4;
	TRF_Ch_RegionTick(ks, L);
	HOST_Check(C.g[1].st == 3 and C.g[1].c == "phase" and TRF_ChTxt("chwhy7") == "Trade there has collapsed.", "Bust: withdrawn (phase, chwhy7)");
	TRF.rg[ks].ph = 0;
	C.g[1] = {t=7, r=ks, f=5, d=5, k=2, p=0, w=0, a=L, e=L + 20, st=0, pay=5000, rq=2, l=10};
	TRF.std.heat = 5;
	TRF_ChBoard(C, L);
	TRF.std.heat = 0;
	HOST_Check(C.g[1].st == 2 and C.g[1].c == "heat", "heat 5: closed with the trade family");
	C.g[1] = {t=7, r=ks, f=5, d=5, k=2, p=0, w=0, a=L, e=L + 20, st=0, pay=5000, rq=2, l=10};
	TRF_Ch_Note(7, cur, 0);
	HOST_Check(C.g[1].st == 2 and C.g[1].c == "kill", "a player trader kill in the region: closed (kill)");
	-- No candidate while the region has a player kill mark, in Bust, at heat 3, or when pulled out.
	C.g = {}; C.cd = {}; C.rs = {}; C.pk = {};
	TRF_CrpPut(ks, {a={[3]=0, [4]=0, [5]=0}, p=0, t=0, x=5, e=0});
	local ri = TRF_ChInfo(C, ks, {});
	local T = TRF_ChTune();
	local c1 = TRF_ChCandOf(ri, T, L, 0);
	ri.pk = L;
	local c2 = TRF_ChCandOf(ri, T, L, 0);
	ri.pk = nil; ri.ph = 4;
	local c3 = TRF_ChCandOf(ri, T, L, 0);
	ri.ph = 0;
	local c4 = TRF_ChCandOf(ri, T, L, 3);
	TRF_CrpPut(ks, {a={[3]=0, [4]=0, [5]=0}, p=5, t=0, x=5, e=L + 5});
	local ri5 = TRF_ChInfo(C, ks, {});
	local has7 = function(l) for i = 1, getn(l) do if l[i].t == 7 then return 1; end; end; return nil; end;
	HOST_Check(has7(c1) and not has7(c2) and not has7(c3) and not has7(c4) and ri5.run == nil, "candidate rule: player kill, Bust, heat 3, pulled out");
	-- Chapter 19: the board withdraws, nothing posts.
	TRF.crp = nil;
	TRF_CrpPut(ks, {a={[3]=0, [4]=0, [5]=0}, p=0, t=0, x=5, e=0});
	C.g[1] = {t=7, r=ks, f=5, d=5, k=2, p=0, w=0, a=L, e=L + 20, st=0, pay=5000, rq=2, l=10};
	h.labels.CurrentQuest = "19";
	TRF_ChBoard(C, L);
	C.g = {}; C.cd = {};
	n0 = S_Mark();
	r = TRF_ChDockBody(C, cur);
	HOST_Check(S_Logs(n0, "event=post ") == 0 and TRF_Crp_Mark(ks) == 5, "chapter 19: withdrawn, no posting");
	h.labels.CurrentQuest = "9_1";
end;

-- g: save and repair (3.1, 3.4) ---------------------------------------------------------------------------

function T_CO_G()
	local h = HOST();
	CO_Begin("golkonda", "5_1");
	local L = TRF.clock.legs;
	local gs, ks = V_Slot("golkonda"), V_Slot("kadi");
	-- Worst case: every block wide, two pull-outs with news topics in regions without other topics, 5 labelled records.
	TRF.newsx = {};
	for s = 1, 8 do CO_Put(s, 9, 9, 9, 0, 5, 5, 0); end;
	CO_Put(gs, 9, 9, 9, 4, 1, 5, L + 24);
	CO_Put(ks, 9, 9, 9, 5, 1, 5, L + 24);
	TRF_NewsPost("crp", "out_4", gs);
	TRF_NewsPost("crp", "out_5", ks);
	V_ClearTr();
	local ids = {};
	for k = 1, 5 do
		local r = CO_Rec(9100 + k, k, {crp=15});
		tinsert(ids, 9100 + k);
	end;
	local sz = 8 + 3 + HOST_SaveSize(TRF.crp) + 5 * (8 + 3 + 12) + (12 + HOST_SaveSize(TRF.newsx[gs])) + (12 + HOST_SaveSize(TRF.newsx[ks]));
	print("HOST corp worst case bytes "..sz);
	HOST_Check(strlen(TRF.crp) == 88 and sz <= 444, "worst case: 88-character string, 5 labels, 2 news topics: "..sz.." <= 444 bytes");
	-- Full state of this run.
	local size = 8 + 3 + HOST_SaveSize(TRF);
	print("HOST info TRF save size (corp run) "..size.." bytes, crp="..HOST_SaveSize(TRF.crp));
	HOST_Check(size <= 100000, "full state "..size.." <= 100000");
	-- Dump (log 2).
	local n0 = S_Mark();
	TRF_Crp_Dump();
	HOST_Check(CO_Logs(n0, "event=dump state="..TRF.crp.." active=2 labelled=9101:15,9102:15,9103:15,9104:15,9105:15") == 1, "dump at log 2");
	-- Repair (CD3).
	-- Blocks 2..8: zeros, then a count in the last block (so a reset block 1 leaves a non-zero string).
	local tl = strrep("0", 66).."10000000000";
	local cases = {
		{v=7, want=nil, pat="field=state result=dropped"},
		{v=strrep("0", 86).."1", want=nil, pat="field=state result=dropped"},
		{v=strrep("0", 98).."1", want=nil, pat="field=state result=cut"},
		{v="00100000000", want="00100000000"..strrep("0", 77), pat="field=state result=padded"},
		{v=strrep("0", 88).."00000000001", want=nil, pat="field=state result=cut"},
		{v="0010000000a"..tl, want=strrep("0", 11)..tl, pat="field=block region=1 result=reset"},
		{v="00070000123"..tl, want=strrep("0", 11)..tl, pat="field=p region=1 result=reset"},
		{v="00000000123"..tl, want=strrep("0", 11)..tl, pat="field=e region=1 result=reset"},
		{v="00040099999"..tl, want=format("000400%05d", L + 24)..tl, pat="field=e region=1 result=capped"},
		{v="00002700000"..tl, want=strrep("0", 11)..tl, pat="field=t region=1 result=reset"},
		{v="00000200000"..tl, want=strrep("0", 11)..tl, pat="field=x region=1 result=reset"},
	};
	local bad = "";
	for i = 1, getn(cases) do
		local e = cases[i];
		TRF.crp = e.v;
		n0 = S_Mark();
		TRF_Repair();
		if TRF.crp ~= e.want or CO_Logs(n0, "event=fix "..e.pat) ~= 1 then bad = bad.." "..i..":"..tostring(TRF.crp); end;
	end;
	HOST_Check(bad == "", "fix: a number and 87 characters dropped, 99 characters cut, a short string padded, a long one cut, a letter, p 7, e without p, e far ahead, t 2, x 2"..bad);
	-- Three pull-outs: the one with the largest e ends at once.
	TRF.crp = format("000400%05d", L + 10)..format("000500%05d", L + 20)..format("000300%05d", L + 5)..strrep("0", 55);
	n0 = S_Mark();
	TRF_Repair();
	local b1, b2, b3 = TRF_CrpBlk(1), TRF_CrpBlk(2), TRF_CrpBlk(3);
	HOST_Check(b1.p == 4 and b2.p == 0 and b2.e == 0 and b3.p == 3 and CO_Logs(n0, "event=fix field=p region=2 result=capped") == 1,
		"three pull-outs: the latest end (region 2) ends at once");
	-- Record labels: 6 and a gone record's label dropped; 13 kept.
	TRF.live.tr[9101].crp = 6;
	TRF.live.tr[9102].crp = 13;
	TRF.live.tr[9103].st = "gone";
	n0 = S_Mark();
	TRF_Repair();
	HOST_Check(TRF.live.tr[9101].crp == nil and TRF.live.tr[9102].crp == 13 and TRF.live.tr[9103].crp == nil
		and CO_Logs(n0, "event=fix field=crp trader_id=9101 result=dropped") == 1, "fix: crp 6 and a gone record's crp dropped, 13 kept");
	-- All zero: nil; a sound string kept without a line.
	TRF.crp = strrep("0", 88);
	TRF_Repair();
	local nz = TRF.crp;
	TRF.crp = "00100000000"..strrep("0", 77);
	n0 = S_Mark();
	TRF_Repair();
	HOST_Check(nz == nil and TRF.crp == "00100000000"..strrep("0", 77) and CO_Logs(n0, "event=fix") == 0, "fix: all zero -> nil; a sound string kept");
	-- Saved across a load.
	T_SaveLoad();
	HOST_Check(TRF.crp == "00100000000"..strrep("0", 77), "TRF.crp survives a save and load");
	for i = 1, getn(ids) do TRF.live.tr[ids[i]] = nil; end;
end;

-- h: module absent and cfg corp 0 -------------------------------------------------------------------------

function T_CO_H()
	local h = HOST();
	h.hide = {["trf_corp.script"]=1};
	CO_Begin("golkonda", "5_1");
	HOST_Check(S_Logs(0, "module=core event=loaded map=true module_count=18 extra_count=21") >= 1 and type(TRF_Crp_Label) ~= "function",
		"trf_corp missing: extra_count=21, no module");
	TRF_SetPro(TRF_CurIdx(), 9);
	local n0 = S_Mark();
	local r = CO_Dock();
	HOST_Check(r.nb == 1 and S_Logs(n0, "module=station event=dock ") == 1 and S_Logs(n0, "module=corp") == 0, "req chain as built, no corp line");
	local id = CO_Trader(4);
	local rec = TRF.live.tr[id];
	local nmn = TRF_UI_Name(rec.nm);
	HOST_Check(TRF_UI_Who(rec, id) == "FTU "..CO_Hull(rec, id).." "..nmn and not CO_Has(TRF_Headed(id), "cargo, ") and TRF_ShopOpen(id) == 1, "texts and shop as built");
	id = CO_Trader(4);
	V_PlayerKill(id);
	TRF_RegionTick(TRF.clock.legs);
	HOST_Check(TRF.crp == nil and S_Logs(n0, "module=corp") == 0, "kill and region tick: no TRF.crp");
	-- Charter without trf_corp (spec 10 co-f): 200 legs of board generation, never a type 7.
	CO_Begin("gaoba", "9_1", {charter=1});
	CO_Charter({gaoba=4});
	C = TRF.ch;
	-- A run mark in the saved string: nothing reads it without the module.
	TRF.crp = "0000000000000000000000000000000000000000000005000000000000000000000000000000000000000000";
	local n7, np = 0, 0;
	for k = 1, 200 do
		TRF.clock.legs = TRF.clock.legs + 1;
		C.g = {}; C.cd = {}; C.rs = {}; C.rb = {};
		TRF_ChGenerate(C, TRF_CurIdx());
		for i = 1, 3 do if type(C.g[i]) == "table" then np = np + 1; if C.g[i].t == 7 then n7 = n7 + 1; end; end; end;
	end;
	HOST_Check(type(TRF_Crp_Mark) ~= "function" and n7 == 0 and np > 0, "without trf_corp: no type 7 in 200 board runs ("..np.." postings)");
	h.hide = nil;
	-- cfg corp 0 with labelled records and a state string present.
	CO_Begin("golkonda", "5_1", {corp=0});
	local gs = V_Slot("golkonda");
	TRF.crp = "03000000000"..strrep("0", 77);
	id = CO_Trader(4);
	rec = TRF.live.tr[id];
	nmn = TRF_UI_Name(rec.nm);
	HOST_Check(TRF_Crp_Of(rec) == nil and TRF_UI_Who(rec, id) == "FTU "..CO_Hull(rec, id).." "..nmn and TRF_Crp_Open(rec) == nil and TRF_Crp_Head(rec) == nil
		and TRF_Crp_Shop(rec) == nil and TRF_Crp_Mark(gs) == nil, "corp 0: readers ignore crp");
	n0 = S_Mark();
	V_PlayerKill(id);
	TRF_Crp_RegionTick(TRF.clock.legs + 30);
	CO_Rec(9800, 5);
	TRF_Crp_Label(9800);
	TRF_SetPro(TRF_CurIdx(), 9);
	CO_Dock();
	HOST_Check(TRF.crp == "03000000000"..strrep("0", 77) and TRF.live.tr[9800].crp == nil and CO_Logs(n0, "event=pass reason=off at=dock") == 1
		and CO_Logs(n0, "event=hit") == 0 and CO_Logs(n0, "event=label") == 0, "corp 0: no count, no tick work, no label, the dock pass line only");
	TRF.live.tr[9800] = nil;
	V_ClearTr();
end;

-- Dispatch (H3) ------------------------------------------------------------------------------

local sc = getenv("TRF_CO") or "";
local fn = getglobal("T_CO_"..strupper(sc));
print("HOST ==== corp scenario co-"..sc.." dir="..HOST().dir);
if type(fn) == "function" then
	fn();
	HOST_Check(T_LeftGlobals() == "", "no handle globals left at the end"..T_LeftGlobals());
else
	HOST_Check(nil, "unknown corp scenario "..sc);
end;
HOST_Check((HOST().gpm_tick or 0) == 0, "no GetPlayerMotherShip from a tick (n="..tostring(HOST().gpm_tick or 0)..")");
print("HOST errors="..HOST().errors.." fails="..HOST().fails);
if HOST().errors > 0 or HOST().fails > 0 then exit(1); end;
exit(0);
