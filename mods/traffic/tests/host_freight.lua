-- Wolves Freight scenarios (design/freight-spec.md 9) under stock Lua 4.0.1: TRF_FR=a..l, run by run_host.sh as its own
-- entry point. a registration, toggles, tune, the loop data of gen_map.py, texts and the pure rules (run pay, price,
-- voucher, rob and loss chances, draw outcome, Park-Miller, seed, hold row, damage band, liability, next stop); b the
-- purchase box (gates: chapter 4 and 19, help, heat, pro, the dockmaster, Trade at war, owe, a non-loop station, the
-- chapter 5-6 regions, the decline cooldown; the box text with the rumour, poor, OK, a second ship refused); c ticks
-- (legs without real seconds, real seconds without legs, pause, one tick per fw_tick_real, the bank clamp, the rt clamp)
-- and the seeded rolls (same state, same draws across a simulated reload); d run pay, the dwell credit with the
-- premium, the payout lines once per visit, pay_cap, at most 3 lines, New Kyoto, lay-up (robbery, full account, heat 5,
-- resume, the damage lay-up at home); e loss off-screen (voucher, owe, pk shortage at the next stop, clan +2, the
-- first-loss clerk line), the liability charge from bal and the wallet, the rest owed blocking the purchase, the
-- voucher price; f on-screen appearance (path A at the first stop tick with the portal facing the previous system,
-- the group, FRIEND, the hold, the marker, the dock with the escort cover and the visit credit once per ship tick, sk
-- re-entry skip, path B as the seed and its exit p + 1, the chapter-6 story systems, fw_onscreen 0, a mission); g the
-- on-screen loss (pirates: voucher, shortage pk, clan +2; counted player fire: no voucher, heat), the comply robbery,
-- the 8.5 resolver (no pay, no help), the hail status line, no 8.4 offer, no 8.6 demand, never tracked, the who line;
-- h charters stop at chapter 19 (the ship keeps paying), enable_freight 0, dump, the load orphan rule, the jump damage
-- band, repair, the save bound and the EW8.6 simulation (2000 ticks per loop region against the cycle model).
-- Step 2 (the base cfg turns its parts off, so a..h run the step 1 rules): i slots 2-3 (help gates, the charter rank,
-- prices, weights, one ship per region, three ships' lines); j hulls (the box by L_fw, carcass, hull_k pay, hull_r
-- robbery, the sell-back, repair); k transit appearances (path C), portal follow (set, consumed, void on load), the parked
-- ship and its cap slot, each cfg off; l news, the captain in the robbery line, pods and the halved liability, the
-- chapter-13 line, size bounds.
-- Loads host_station.lua up to its first scenario, as host_stash.lua does. No new stubs.

local f = openfile((getenv("TRF_TESTS") or "./").."host_station.lua", "r");
if not f then print("HOST FAIL host_freight.lua: cannot open host_station.lua"); exit(1); end;
local src = read(f, "*a");
closefile(f);
local cut = strfind(src, "\n-- a: install (12.1, 6.1)", 1, 1);
if not cut then print("HOST FAIL host_freight.lua: marker '-- a: install (12.1, 6.1)' missing in host_station.lua"); exit(1); end;
dostring(strsub(src, 1, cut), "host_station.lua");

-- Helpers ----------------------------------------------------------------------------------

-- Config of these runs: freight on with the prize gap and the marker off, the entry events and the other features
-- that claim slots or boxes off, log 2, plus t.
function FR_Cfg(t)
	local c = {enable_freight=1, fw_prize_gap=0, cap_enable=0, sweeps=0, sweep_ct=0, feq=0, staged=0, seed=0, queue=0, parked=0,
		voice_events=0, dconv=0, carriers=0, po=0, enable_survivors=0, lad_enabled=0, charter=0, enable_stashes=0, enable_scars=0, log=2, tune={},
		fw_hulls=0, fw_transit=0, fw_follow=0, fw_parked=0, fw_hooks=0};
	if t then for k, v in t do c[k] = v; end; end;
	return c;
end;

function FR_Tune(k, v)
	local h = HOST();
	local o = {};
	for a, b in h.cfg.tune do o[a] = b; end;
	o[k] = v;
	h.cfg.tune = o;
end;

-- Every region Quiet with clan score 10 (T1), dis 0, pro 5 in every trader system with a trade station.
function FR_World()
	local m = TRF_RgMap();
	for s = 1, m.n do
		local r = TRF.rg[s];
		r.ph = 0; r.pt = TRF.clock.legs; r.sl = 0; r.sn = 0; r.sw = 0; r.sr = nil;
		TRF.clan[s].sc = 10;
	end;
	TRF.base = {};
	local mp = TRF_Map();
	for i = 1, getn(mp.sys) do
		TRF_SetDis(i, 0);
		if (m.pc[i] or 0) >= 5 then TRF_SetPro(i, 5); end;
	end;
end;

-- Scenario start in sys at chapter label ch: help 10, heat 0, no freight state.
function FR_Begin(sys, ch, t)
	local h = HOST();
	h.labels.CurrentQuest = ch or "9_1";
	h.quests = {}; h.qlog = {};
	h.qs = FALSE;
	h.rel_team = nil;
	S_Begin(sys, FR_Cfg(t));
	h.credits = 1000000;
	TRF.std.help = 10; TRF.std.heat = 0;
	TRF.co = nil;
	FR_World();
end;

function FR_Idx(name) return V_Idx(name); end;
function FR_Slot(name) return TRF_RgOf(V_Idx(name)); end;
function FR_Has(s, t) return strfind(s or "", t, 1, 1); end;
function FR_Rel(team, rel)
	local h = HOST();
	if type(h.rel_team) ~= "table" then h.rel_team = {}; end;
	h.rel_team[team.."|"..PLAYER_TEAM] = rel;
	h.rel_team[PLAYER_TEAM.."|"..team] = rel;
end;
-- Freight log lines after mark n0 holding pat (plain).
function FR_Logs(n0, pat)
	local n, q = 0, HOST().logs;
	for i = n0 + 1, getn(q) do if strfind(q[i], "module=freight ", 1, 1) and strfind(q[i], pat, 1, 1) then n = n + 1; end; end;
	return n;
end;
function FR_Kv(line, k)
	local a, b, v = strfind(line or "", " "..k.."=([^ ]*)");
	return v;
end;

-- Trade docking through the wrapper chain (trf_shop thunk -> trf_plumb dispatcher -> vanilla): screen lines (joined
-- by "|"), boxes opened, the newest box.
function FR_Dock()
	local h = HOST();
	local s0, b0 = getn(h.screen), getn(h.boxes);
	_param = GetCurrentLocation();
	__TradeStationDock_Ok();
	local r = {scr="", nb=getn(h.boxes) - b0, s0=s0, n=getn(h.screen) - s0};
	for i = s0 + 1, getn(h.screen) do r.scr = r.scr..h.screen[i].t.."|"; end;
	if r.nb > 0 then r.box = h.boxes[getn(h.boxes)]; end;
	return r;
end;

function FR_Press(r, which)
	local h = HOST();
	if r.nb > 0 then HOST_Press(which, r.box); end;
	local s = "";
	for i = r.s0 + 1, getn(h.screen) do s = s..h.screen[i].t.."|"; end;
	return s;
end;

-- A new visit without a jump (the per-visit state of FR and the plumbing slots start again, vn + 1).
function FR_Visit()
	TRF_Fr_OnEnter();
	if type(TRF.live) == "table" then TRF.live.box = nil; TRF.live.bt = nil; end;
end;

-- Buys at the current station (a fresh visit, the box answered OK). Returns the ship record and the dock result.
function FR_Buy()
	FR_Visit();
	local r = FR_Dock();
	local s = FR_Press(r, "ok");
	return TRF_FrShip(1), r, s;
end;

-- Ship fixture in slot 1 on the loop of region of sys, at its stop of sys (or loop index p), fields of t override.
function FR_Ship(sys, t)
	local co = TRF_FrCo(1);
	local idx = V_Idx(sys);
	local slot = TRF_RgOf(idx);
	local lp = TRF_FrLoop(slot);
	local s = {id=1, nm=1, hull=1, rg=slot, home=idx, p=TRF_FrStopOf(lp, idx), w=0, k=10, run=0, st=0, till=0, cov=0, dmg=0, rs=4711,
		price=50000, earned=0, sk=-1, ek=-1};
	if t then for k, v in t do s[k] = v; end; end;
	co.ships[1] = s;
	co.seq = 1;
	co.lk = TRF.clock.legs; co.rt = TRF.clock.rs;
	return s;
end;

-- n freight ticks: legs and unpaused real seconds both advanced, then the 1 s step.
function FR_Ticks(n)
	local tr = TRF_FrT("fw_tick_real");
	for i = 1, n do
		TRF.clock.legs = TRF.clock.legs + 1;
		TRF.clock.rs = TRF.clock.rs + tr;
		TRF_Fr_Step();
	end;
end;

-- Generator state whose next draw is r0 (rs < 127773: the product stays below the modulus, so r = rs x 16807 / M).
function FR_RsFor(r0)
	return floor(r0 * 2147483647 / 16807) + 1;
end;

-- Shortage entry of system idx (the last), or nil.
function FR_Short(idx)
	local e = nil;
	if type(TRF.short) == "table" then for i = 1, getn(TRF.short) do if TRF.short[i].s == idx then e = TRF.short[i]; end; end; end;
	return e;
end;

-- Open trader record with the fw flag, or nil.
function FR_Rec()
	for id, r in TRF.live.tr do if type(r) == "table" and r.fw and r.st ~= "gone" then return id, r; end; end;
	return nil;
end;

-- Jump to sys (through kron first when via = 1, a re-entry); the repair of the entry replaced the ship record, so the
-- current one is returned.
function FR_Jump(sys, via)
	if via == 1 then T_Jump("kron"); end;
	T_Jump(sys);
	return TRF_FrShip(1);
end;

-- Runs the due calls of the next secs game seconds (freight ticks held by a long fw_tick_real).
function FR_Wait(secs)
	T_Tick(floor(secs * 2), 0.5);
end;

-- a: registration, toggles, tune, loops, texts, pure rules ---------------------------------------------

function T_FR_A()
	local h = HOST();
	FR_Begin("debris6", "9_1");
	-- design/strength-spec.md 5.6: trf_str counts as an extra module (12 -> 13).
	-- design/fits-spec.md 7: trf_fits counts as an extra module (13 -> 14).
	HOST_Check(S_Logs(0, "module=core event=loaded map=true module_count=18 extra_count=18") >= 1, "trf_freight loads after trf_stash (extra_count=18 with trf_haunt, trf_parcel, trf_merc, trf_wq, trf_warn and trf_remark)");
	local ml = TRF_ModList();
	HOST_Check(ml[getn(ml) - 7] == "Fr" and TRF_Opt("enable_freight") == 1 and TRF_Opt("fw_onscreen") == 1 and TRF_Opt("fw_losses") == 1
		and TRF_Fr_OptDef().fw_max_ships == 3 and TRF_Fr_OptDef().fw_prize_gap == 1 and TRF_Fr_OptDef().fw_marker == 1
		and TRF_Fr_OptDef().fw_hulls == 1 and TRF_Fr_OptDef().fw_transit == 1 and TRF_Fr_OptDef().fw_follow == 1 and TRF_Fr_OptDef().fw_parked == 1
		and TRF_Fr_OptDef().fw_hooks == 1,
		"TRF_ModList has Fr; toggles: freight, on-screen, losses on, three ships, prize gap, marker and the step 2 parts on by default");
	h.cfg.fw_max_ships = 7;
	local m7 = TRF_FrMaxShips();
	h.cfg.fw_max_ships = 0;
	local m0 = TRF_FrMaxShips();
	h.cfg.fw_max_ships = nil;
	HOST_Check(m7 == 3 and m0 == 1 and TRF_FrMaxShips() == 3, "fw_max_ships clamped 1..3 (7 reads 3, 0 reads 1), default 3");
	local T = TRF_FrTune();
	HOST_Check(T.fw_k == 3.33 and T.fw_price_k == 1000 and T.fw_tick_real == 120 and T.fw_bank == 4 and T.fw_premium == 0.05 and T.fw_cover == 0.75
		and T.fw_liab_ticks == 25 and T.fw_rob_base[1] == 0.005 and T.fw_rob_base[4] == 0.04 and T.fw_loss_base == 0.002 and T.fw_layup == 2
		and T.fw_help_slot[1] == 5 and T.fw_help_slot[3] == 30 and T.fw_min_pro == 4 and T.fw_weights[2] == 0.3 and T.fw_offer_cd == 10
		and T.fw_hull_l[1] == 6 and T.fw_hull_l[2] == 11,
		"tune defaults of design 6");
	h.cfg.tune = {fw_tick_real=1, fw_rob_base={0.5, 0.5, 0.5, 0.5, 0.5, 0.5}, fw_bank=7.6};
	T = TRF_FrTune();
	HOST_Check(T.fw_tick_real == 10 and T.fw_rob_base[3] == 0.12 and T.fw_bank == 7, "clamps: tick_real >= 10, rob_base <= 0.12, bank whole");
	h.cfg.tune = {};
	-- Registrations (trf_plumb).
	local P = TRF_PlReg();
	local lo, bo, sd, rh, cg = "", "", "", 0, 0;
	for i = 1, getn(P.dock.trade.line) do lo = lo..P.dock.trade.line[i].o..":"..TRF_PlName(P.dock.trade.line[i].f)..","; end;
	for i = 1, getn(P.dock.trade.box) do bo = bo..P.dock.trade.box[i].o..":"..TRF_PlName(P.dock.trade.box[i].f)..","; end;
	local sl = TRF_SeedList();
	for i = 1, getn(sl) do sd = sd..TRF_PlName(sl[i])..","; end;
	for i = 1, getn(P.rh) do if TRF_PlName(P.rh[i].f) == "TRF_Fr_RaidHelp" then rh = rh + 1; end; end;
	for i = 1, getn(P.cap) do if P.cap[i].g == "freight" and P.cap[i].t == 0 then cg = cg + 1; end; end;
	HOST_Check(FR_Has(lo, "50:") == nil and FR_Has(lo, "60:TRF_Fr_DockLine,70:") and FR_Has(bo, "400:TRF_Pc_DockBox,300:TRF_Fr_DockBox,200:TRF_Ch_DockBox,")
		and FR_Has(sd, "TRF_GnSeedHold,TRF_Fr_Seed,") and rh == 1 and cg == 1,
		"trade line 60 before the charter 70, trade box 300 between the parcel offer 400 and the dues 200, seed provider 400 after the hold 450, the 8.5 resolver, the ship-cap group ("..lo.." "..bo.." "..sd..")");
	-- Loops (gen_map.py): every eligible region but Torr, stops are trade-station systems of the region, consecutive
	-- systems are portal neighbours, no deny system, L = median L_w of the distinct systems.
	local L = TRF_FrLoops();
	local m = TRF_Map();
	local deny = {nk=1, x297=1, earth=1, precursors=1, disonsphere=1, fronn=1, xt23=1, xt24=1};
	local bad, nl, ns = "", 0, 0;
	for slot, lp in L do
		nl = nl + 1;
		local lw = {};
		for j = 1, lp.n do
			local s = m.sys[lp.s[j]];
			local nx = m.sys[lp.s[TRF_FrNextOf(j, lp.n)]];
			local adj = nil;
			for q = 1, getn(s.portals) do if s.portals[q].to == nx.name then adj = 1; end; end;
			if not adj then bad = bad.." gap:"..s.name.."-"..nx.name; end;
			if deny[s.name] then bad = bad.." deny:"..s.name; end;
			if lp.t[j] == 1 then
				ns = ns + 1;
				if s.rg ~= slot or s.trader ~= 1 or not s.st or s.st[1].kind ~= "trade" then bad = bad.." stop:"..s.name; end;
			end;
			lw[lp.s[j]] = TRF_LPay(lp.s[j]);
		end;
		local v = {};
		for k, x in lw do tinsert(v, x); end;
		sort(v);
		local med = v[floor(getn(v) / 2) + 1];
		if mod(getn(v), 2) == 0 then med = floor((v[getn(v) / 2] + v[getn(v) / 2 + 1]) / 2 + 0.5); end;
		if med ~= lp.L then bad = bad.." L:"..slot..":"..lp.L.."/"..med; end;
	end;
	local gk = L[FR_Slot("golkonda")];
	HOST_Check(nl == 7 and bad == "" and not L[FR_Slot("torr")] and gk and gk.n == 18 and gk.L == 6 and gk.s[2] == FR_Idx("debris6") and gk.t[2] == 1,
		"7 loops (Torr excluded), stops are trade stations of the region, consecutive systems are neighbours, no deny system, L = median L_w; Golkonda 18 systems L 6"..bad);
	-- Texts.
	local tx = TRF_Fr_Text();
	local nt = 0;
	for k, v in tx do nt = nt + 1; end;
	local pct = "";
	for k, v in tx do if strfind(v, "%", 1, 1) and k ~= "fwlost" and k ~= "fwlostt" then pct = pct.." "..k; end; end;
	HOST_Check(nt == 43 and pct == "" and TRF_Txt("fwpaid", "3,900") == "Wolves Freight paid 3,900 cr since your last visit."
		and TRF_Txt("fwwhere", "Kestrel", "Callipso", "Golkonda") == "Wolves Freight: Kestrel is in Callipso, bound for Golkonda.", "43 texts (no new one with a percent sign"..pct.."); payout and whereabouts lines of design 2");
	-- Pure rules.
	HOST_Check(TRF_FrEOf(3.33, 7, 4, 1, 1) == floor(3.33 * 49 * 7 / 8 * 1.2 + 0.5) and TRF_FrEOf(3.33, 10, 4, 0.7, 1) == floor(3.33 * 100 * 1.2 * 0.7 + 0.5)
		and TRF_FrEOf(3.33, 4, 0, 1.25, 1) == floor(3.33 * 16 * 0.5 * 1.25 + 0.5), "run pay fw_k L^2 lk (1 + 0.05 R) d_k");
	HOST_Check(TRF_FrListOf(1000, 7, 4, 1, 1) == floor(1000 * 49 * 7 / 8 * 1.2 + 0.5) and TRF_FrListOf(1000, 10, 0, 2.25, 0.7) == 157500,
		"price fw_price_k L^2 lk (1 + 0.05 pro) slot_k d_k");
	local p1, u1 = TRF_FrPaidOf(50000, 0, 0.25);
	local p2, u2 = TRF_FrPaidOf(50000, 30000, 0.25);
	local p3, u3 = TRF_FrPaidOf(50000, 202500, 0.25);
	HOST_Check(p1 == 50000 and u1 == 0 and p2 == 20000 and u2 == 1 and p3 == 12500 and u3 == 1, "voucher: list - vch, floor 25 % of list");
	HOST_Check(TRF_FrTierFOf(1) == 0.5 and TRF_FrTierFOf(4) == 1.5 and abs(TRF_FrRobOf(0.03, 1.25, 2, 1, 0.12) - 0.045) < 1e-9
		and TRF_FrRobOf(0.04, 1.5, 9, 1.3, 0.12) == 0.12 and TRF_FrLossOf(0.002, 1.5, 4, 0, 4) > 0 and TRF_FrLossOf(0.002, 1, 2, 1, 2) == 0
		and abs(TRF_FrLossOf(0.002, 1, 0, 3, 1) - 0.002) < 1e-12, "rob = base tier_f (1 + 0.1 dis) hull_r clamped 12 %; loss only in Raids or at T >= 3");
	HOST_Check(TRF_FrOutOf(0.001, 0.002, 0.03) == "loss" and TRF_FrOutOf(0.01, 0.002, 0.03) == "rob" and TRF_FrOutOf(0.032, 0.002, 0.03) == "none",
		"one draw: loss below p_loss, robbery below p_loss + p_rob");
	HOST_Check(TRF_FrRngOf(1) == 16807 and TRF_FrRngOf(16807) == 282475249 and TRF_FrRngOf(2147483646) == 2147466840,
		"Park-Miller steps exact (1 -> 16807 -> 282475249; M-1 -> M-16807)");
	local sa, sb = TRF_FrSeedOf(1, 0), TRF_FrSeedOf(99, -99999);
	HOST_Check(sa >= 1 and sa <= 2147483646 and sb >= 1 and sb <= 2147483646 and sa ~= TRF_FrSeedOf(2, 0), "seed 1..M-1 from id and leg");
	HOST_Check(TRF_FrTTOf(2) == 1 and TRF_FrTTOf(3) == 2 and TRF_FrTTOf(5) == 3 and TRF_FrDmgOf(800, 800) == 0 and TRF_FrDmgOf(500, 800) == 1
		and TRF_FrDmgOf(300, 800) == 2 and TRF_FrDmgOf(100, 800) == 3, "hold row by R; damage bands");
	local x, y, z = TRF_FrLiabOf(5000, 3000, 1000);
	local x2, y2, z2 = TRF_FrLiabOf(5000, 0, 99999);
	HOST_Check(x == 3000 and y == 1000 and z == 1000 and x2 == 0 and y2 == 5000 and z2 == 0, "liability: bal first, then the wallet, the rest owed");
	HOST_Check(TRF_FrNextStopOf(gk, 1) == 2 and TRF_FrNextStopOf(gk, 3) == 7 and TRF_FrNextStopOf(gk, 14) == 1 and TRF_FrStopOf(gk, FR_Idx("debris1")) == 3,
		"next stop on the loop (cyclic); stop index of a system");
	HOST_Check(TRF_FrNum(58800) == "58,800" and TRF_FrNum(900) == "900" and TRF_FrNum(1234567) == "1,234,567", "credit numbers with separators");
	HOST_Check(TRF.co == nil and HOST_Reserved(TRF, "TRF") == "", "nothing saved before a purchase; no reserved key");
end;

-- b: purchase box and its gates ---------------------------------------------------------------------

function T_FR_B()
	local h = HOST();
	FR_Begin("debris6", "4_1");
	local idx = TRF_CurIdx();
	local n0 = S_Mark();
	local r = FR_Dock();
	HOST_Check(r.nb == 0 and HOST().trade_ok >= 1 and S_Logs(n0, "event=offer system=debris6 result=none reason=chapter") == 1,
		"chapter 4: no offer, the vanilla dock OK runs");
	local gates = {{"19_1", "chapter_end"}, {"9_1", "help", function() TRF.std.help = 4; end}, {"9_1", "heat", function() TRF.std.heat = 3; end},
		{"9_1", "pro", function() TRF_SetPro(TRF_CurIdx(), 3); end}, {"9_1", "war", function() FR_Rel("Trade", RELATION_WAR); end},
		{"9_1", "owe", function() TRF_FrCo(1).owe = 100; end}, {"5_1", "chapter_region", nil, "kadi"}, {"9_1", "no_loop", nil, "xt05"},
		{"9_1", "mission", function() V_QuestOn(); end}};
	local bad = "";
	for i = 1, getn(gates) do
		local g = gates[i];
		h.labels.CurrentQuest = g[1];
		if g[4] then T_Jump(g[4]); FR_World(); end;
		TRF.std.help = 10; TRF.std.heat = 0; h.rel_team = nil; TRF.co = nil;
		if g[3] then g[3](); end;
		local why = TRF_FrBuyGate(TRF_CurIdx());
		if why ~= g[2] then bad = bad.." "..g[2].."->"..tostring(why); end;
		if g[2] == "mission" then V_QuestOff(); end;
		if g[4] then T_Jump("debris6"); FR_World(); end;
	end;
	TRF.co = nil; h.rel_team = nil;
	HOST_Check(bad == "", "purchase gates: chapter 19, help, heat, pro, Trade at war, owe, Kadi in chapter 5, a station off the loop (XT-05), a mission"..bad);
	-- The first ship with the freight unlock quest (cfg enable_wq 1, design/freight-quest-spec.md 4.5): reason quest without
	-- the record and below step 70 (help 10 does not count), steps 70 and 80 pass; enable_wq 0 restores help >= 5.
	h.labels.CurrentQuest = "9_1";
	h.cfg.enable_wq = 1;
	TRF.std.help = 10;
	TRF.wq = nil;
	local q0 = TRF_FrBuyGate(TRF_CurIdx());
	TRF.wq = {v=1, s=50, k=0, n=0, sd=1};
	local q50 = TRF_FrBuyGate(TRF_CurIdx());
	TRF.wq.s = 70;
	local q70 = TRF_FrBuyGate(TRF_CurIdx());
	TRF.wq.s = 80;
	local q80 = TRF_FrBuyGate(TRF_CurIdx());
	TRF.std.help = 4;
	local q4 = TRF_FrBuyGate(TRF_CurIdx());
	h.cfg.enable_wq = 0;
	TRF.wq.s = 50;
	local o4 = TRF_FrBuyGate(TRF_CurIdx());
	TRF.std.help = 5;
	local o5 = TRF_FrBuyGate(TRF_CurIdx());
	TRF.std.help = 10;
	TRF.wq = nil;
	HOST_Check(q0 == "quest" and q50 == "quest" and q70 == nil and q80 == nil and q4 == nil and o4 == "help" and o5 == nil,
		"enable_wq 1: the first ship needs the quest at step 70 (none: "..tostring(q0)..", s 50: "..tostring(q50)..", s 70 and 80 pass, help 4 passes at s 80); enable_wq 0: help 4 "..tostring(o4)..", help 5 passes");
	-- Dockmaster standing below 0 (feature 3).
	h.labels.CurrentQuest = "9_1";
	local e = TRF_StnGet(TRF_Stn_Key(TRF_CurIdx(), 1), 1);
	e.st = -1;
	HOST_Check(TRF_FrBuyGate(TRF_CurIdx()) == "dockmaster", "dockmaster st -1: no offer");
	e.st = 0;
	-- The box: the price of design 5 with the first-offer rumour; Cancel starts the 10-leg cooldown.
	FR_Visit();
	n0 = S_Mark();
	r = FR_Dock();
	local lp = TRF_FrLoop(TRF_RgOf(idx));
	local list = TRF_FrListOf(1000, lp.L, 5, 1, 1);
	HOST_Check(r.nb == 1 and r.box.title == "FTU charter office" and FR_Has(r.box.text, "FTU charter office: transports keep going missing in Capricorn.")
		and FR_Has(r.box.text, "A bulk freighter is up for charter: "..TRF_FrNum(list).." cr. She will run the Golkonda lanes")
		and S_Logs(n0, "event=box system=debris6 region=4 list="..list.." price="..list) == 1, "box: title, rumour, price "..list..", region name");
	local s = FR_Press(r, "cancel");
	HOST_Check(HOST().trade_ok >= 1 and TRF.co and TRF.co.decl and TRF.co.decl.sys == idx and getn(TRF.co.ships) == 0 and S_Logs(n0, "event=buy system=debris6 result=declined") == 1,
		"Cancel: the vanilla dock goes on, the decline is kept");
	FR_Visit();
	HOST_Check(TRF_FrBuyGate(idx) == "declined", "declined: no offer within fw_offer_cd legs");
	TRF.clock.legs = TRF.clock.legs + 10;
	HOST_Check(TRF_FrBuyGate(idx) == nil, "after 10 legs the offer is due again");
	-- Poor, then OK.
	h.credits = 100;
	FR_Visit();
	r = FR_Dock();
	HOST_Check(r.nb == 1 and not FR_Has(r.box.text, "Capricorn"), "second offer without the rumour");
	s = FR_Press(r, "ok");
	HOST_Check(FR_Has(s, "FTU charter office: come back with "..TRF_FrNum(list).." cr.") and TRF_FrCount() == 0 and h.credits == 100, "OK without the credits: the poor line, nothing bought");
	h.credits = 1000000;
	n0 = S_Mark();
	local sh, r2, s2 = FR_Buy();
	HOST_Check(sh and sh.id == 1 and sh.home == idx and sh.rg == TRF_RgOf(idx) and sh.p == TRF_FrStopOf(lp, idx) and sh.price == list
		and h.credits == 1000000 - list and FR_Has(s2, "Wolves Freight: "..TRF_FrShipName(sh.nm).." registered at Debris6. Her first run leaves next leg.")
		and S_Logs(n0, "event=buy ship_id=1") == 1 and S_Logs(n0, "credits_before=1000000 credits_after="..(1000000 - list)) == 1 and TRF.co.decl == nil,
		"OK: the ship at this stop, the price charged (EW8.1 log), the reply line");
	FR_Visit();
	local g10 = TRF_FrBuyGate(idx);
	TRF.std.help = 15;
	local g15 = TRF_FrBuyGate(idx);
	h.cfg.fw_max_ships = 1;
	local g1 = TRF_FrBuyGate(idx);
	h.cfg.fw_max_ships = nil;
	TRF.std.help = 10;
	HOST_Check(g10 == "help" and g15 == "region_ship" and g1 == "ships", "a second ship: help 10 below slot 2's 15, at help 15 the region already has a ship (G2), fw_max_ships 1 refuses it (step 1)");
	-- Voucher price.
	TRF.co.ships[1] = nil;
	TRF.co.vch = 30000;
	local p2 = TRF_FrPaidOf(list, 30000, 0.25);
	FR_Visit();
	r = FR_Dock();
	HOST_Check(r.nb == 1 and FR_Has(r.box.text, TRF_FrNum(p2).." cr with your FTU cover"), "with a voucher: the lower price in the box");
	FR_Press(r, "ok");
	HOST_Check(TRF.co.vch == 0 and TRF_FrShip(1).price == p2, "the voucher spent (the rest forfeited)");
	HOST_Check(HOST_Reserved(TRF, "TRF") == "", "no reserved key");
end;

-- c: ticks and seeded rolls -----------------------------------------------------------------------------

function T_FR_C()
	local h = HOST();
	FR_Begin("debris6", "9_1");
	local s = FR_Ship("debris6", {rs=FR_RsFor(0.5)});
	local co = TRF.co;
	local k0 = s.k;
	TRF.clock.legs = TRF.clock.legs + 3;
	TRF_Fr_Step();
	HOST_Check(s.k == k0, "legs without real seconds: no tick");
	TRF.clock.legs = TRF.clock.legs - 3; co.lk = TRF.clock.legs;
	TRF.clock.rs = TRF.clock.rs + 600;
	TRF_Fr_Step();
	HOST_Check(s.k == k0 and TRF.clock.rs - co.rt == 240, "real seconds without legs: no tick, rt banked at 2 ticks");
	TRF.clock.legs = TRF.clock.legs + 1;
	local n0 = S_Mark();
	TRF_Fr_Step();
	HOST_Check(s.k == k0 + 1 and S_Logs(n0, "event=tick") == 1, "one leg and banked seconds: one tick (one leg consumed)");
	TRF.clock.legs = TRF.clock.legs + 10;
	n0 = S_Mark();
	TRF_Fr_Step();
	HOST_Check(s.k == k0 + 2 and co.lk >= TRF.clock.legs - 4 and S_Logs(n0, "event=bank") == 1, "10 legs at once: clamped to the bank of 4, one tick from the banked 120 s");
	-- Pause: T_Tick with dt_game 0 adds no unpaused seconds.
	local rs0 = TRF.clock.rs;
	h.gt = h.gt; TRF_OnTick(0, 30);
	HOST_Check(TRF.clock.rs == rs0, "pause (dt_game 0): rs unchanged");
	-- Ticks stay at or below real/120 (EW8.3).
	local k1 = s.k;
	TRF.clock.legs = TRF.clock.legs + 4;
	for i = 1, 10 do TRF.clock.rs = TRF.clock.rs + 60; TRF_Fr_Step(); end;
	HOST_Check(s.k - k1 == 4, "600 s and 4 legs: 4 ticks (bank), every tick needs 120 s ("..(s.k - k1)..")");
	-- Seeded rolls: the same state gives the same draws (a reload replays).
	local snap = HOST_SaveCopy(TRF.co, 1);
	local cl = TRF.clock.legs; local cr = TRF.clock.rs;
	n0 = S_Mark();
	FR_Ticks(6);
	local a = "";
	for i = n0 + 1, getn(h.logs) do if strfind(h.logs[i], "event=roll ", 1, 1) then a = a..FR_Kv(h.logs[i], "r")..","; end; end;
	TRF.co = snap; TRF.clock.legs = cl; TRF.clock.rs = cr;
	n0 = S_Mark();
	FR_Ticks(6);
	local b = "";
	for i = n0 + 1, getn(h.logs) do if strfind(h.logs[i], "event=roll ", 1, 1) then b = b..FR_Kv(h.logs[i], "r")..","; end; end;
	HOST_Check(a ~= "" and a == b and strlen(a) > 30, "reload replays the same draws (EW8.4): "..a);
	-- Draws differ per tick (no fixed step): consecutive r values not evenly spaced.
	HOST_Check(not FR_Has(a, "0.5000,0.5000"), "draws move");
	-- enable_freight 0: no ticks.
	h.cfg.enable_freight = 0;
	local k2 = TRF_FrShip(1).k;
	FR_Ticks(3);
	HOST_Check(TRF_FrShip(1).k == k2, "enable_freight 0: no ticks");
	h.cfg.enable_freight = 1;
end;

-- d: run pay, payout lines, lay-up ----------------------------------------------------------------------

function T_FR_D()
	local h = HOST();
	FR_Begin("debris6", "9_1");
	local idx = TRF_CurIdx();
	FR_Tune("fw_rob_base", {0, 0, 0, 0, 0, 0});
	local s = FR_Ship("debris6");
	local co = TRF.co;
	local lp = TRF_FrLoop(s.rg);
	local e = TRF_FrEarn(s, lp);
	HOST_Check(e == TRF_FrEOf(3.33, lp.L, TRF_RgR(s.rg), 1, 1) and e > 0, "run pay of the ship: "..e);
	-- At the stop (w 0): the first tick dwells and credits, the next moves on.
	FR_Ticks(1);
	HOST_Check(s.w == 1 and s.p == 2 and s.run == 0 and co.bal == floor(e * 0.95), "stop: the dwell tick credits run x 0.95 ("..co.bal..")");
	FR_Ticks(1);
	HOST_Check(s.w == 0 and s.p == 3 and s.run == e, "next tick: moved to the next system, run grows");
	FR_Ticks(1);
	HOST_Check(s.p == 3 and s.w == 1 and co.bal == floor(e * 0.95) + floor(2 * e * 0.95), "a stop takes two ticks; credit on the second");
	-- Payout at a dock: once per visit.
	local b0 = co.bal;
	FR_Visit();
	local c0 = h.credits;
	local n0 = S_Mark();
	local r = FR_Dock();
	HOST_Check(h.credits == c0 + b0 and co.bal == 0 and FR_Has(r.scr, "Wolves Freight paid "..TRF_FrNum(b0).." cr since your last visit.")
		and FR_Has(r.scr, "Wolves Freight: "..TRF_FrShipName(s.nm).." is in Debris1, bound for xt11.") and S_Logs(n0, "event=pay visit="..co.vn.." paid_visit="..co.vn) == 1
		and S_Logs(n0, "mode=plain") == 1, "dock: payout and whereabouts lines, credits added (EW8.5, EW8.10 log) "..r.scr);
	FR_Ticks(2);
	r = FR_Dock();
	HOST_Check(not FR_Has(r.scr, "Wolves Freight"), "second dock in the same visit: no freight line");
	-- New Kyoto pays nothing.
	FR_Visit();
	local nk = TRF_Map().by.nk;
	local cur = TRF_CurIdx;
	TRF_CurIdx = function() return %nk; end;
	r = FR_Dock();
	TRF_CurIdx = cur;
	HOST_Check(not FR_Has(r.scr, "Wolves Freight"), "New Kyoto: no payout");
	-- pay_cap: the account lies up at pay_cap (st 2, the full line, the ship home).
	co.bal = 29990;
	FR_Ticks(4);
	HOST_Check(s.st == 2 and co.bal >= 29990 and co.bal <= 30000 and lp.s[s.p] == idx and type(co.log) == "table" and co.log[getn(co.log)].k == 4,
		"account at pay_cap: laid up at home (st 2), log full");
	local k0 = s.k;
	local run0 = s.run;
	FR_Ticks(2);
	HOST_Check(s.run == run0 and s.st == 2, "suspended: no earnings");
	FR_Visit();
	r = FR_Dock();
	HOST_Check(FR_Has(r.scr, "Wolves Freight paid 29,") or FR_Has(r.scr, "Wolves Freight paid 30,000"), "payout of the full account: "..r.scr);
	HOST_Check(FR_Has(r.scr, "Wolves Freight: account full. "..TRF_FrShipName(s.nm).." waits at Debris6 for your orders.") and r.n <= 3, "full line, at most 3 lines");
	FR_Ticks(1);
	HOST_Check(s.st == 0, "balance paid: the ship resumes");
	-- Heat 5: suspended, the FTU line.
	TRF.std.heat = 5;
	FR_Ticks(1);
	FR_Visit();
	r = FR_Dock();
	HOST_Check(s.st == 2 and FR_Has(r.scr, "FTU: the Wolves charter is suspended until traders stop running from you."), "heat 5: suspended with the FTU line");
	TRF.std.heat = 0;
	FR_Ticks(1);
	HOST_Check(s.st == 0, "heat below 5: resumes");
	-- Robbery off-screen (a forced draw).
	FR_Tune("fw_rob_base", {0.12, 0.12, 0.12, 0.12, 0.12, 0.12});
	FR_Ticks(1);
	s.run = 500;
	s.rs = FR_RsFor(0.05);
	local sl = TRF_RgOf(TRF_FrLoop(s.rg).s[TRF_FrNextOf(s.p, lp.n)]) or s.rg;
	local c1 = TRF_ClanScore(TRF_RgOf(lp.s[s.p]) or s.rg);
	n0 = S_Mark();
	local p0 = s.p;
	FR_Ticks(1);
	local rsys = lp.s[s.p];
	HOST_Check(s.st == 1 and s.run == 0 and s.till == s.k + 2 and S_Logs(n0, "event=rob ship_id=1") == 1 and S_Logs(n0, "out=rob") == 1,
		"draw in the robbery band: run lost, laid up 2 ticks");
	FR_Tune("fw_rob_base", {0, 0, 0, 0, 0, 0});
	local k3 = s.k;
	FR_Ticks(1);
	HOST_Check(s.st == 1 and s.k == k3 + 1, "laid up: counts down");
	FR_Ticks(1);
	HOST_Check(s.st == 1 and s.k == k3 + 2, "laid up: the second idle tick");
	FR_Ticks(1);
	HOST_Check(s.st == 0, "lay-up over after fw_layup ticks");
	FR_Visit();
	r = FR_Dock();
	HOST_Check(FR_Has(r.scr, "was robbed near "..TRF_FrSys(rsys)..". Hold lost, two legs in repair."), "robbery line at the next dock: "..r.scr);
	-- Damage lay-up at home: dmg 2 reaching the home stop lies up 2 ticks.
	s.dmg = 2;
	local guard = 0;
	while not (lp.s[s.p] == s.home and lp.t[s.p] == 1 and s.w == 0) and guard < 60 do FR_Ticks(1); guard = guard + 1; end;
	HOST_Check(s.st == 1 and s.dmg == 0 and s.till == s.k + 2, "dmg 2 at home: laid up 2 ticks, repaired");
end;

-- e: losses, liability, voucher ------------------------------------------------------------------------

function T_FR_E()
	local h = HOST();
	FR_Begin("debris6", "9_1");
	local idx = TRF_CurIdx();
	local s = FR_Ship("debris6", {price=40000});
	local co = TRF.co;
	local lp = TRF_FrLoop(s.rg);
	-- Raids in the region at T4, dis 4 everywhere: p_loss > 0.
	local slot = s.rg;
	TRF.rg[slot].ph = 3; TRF.clan[slot].sc = 80;
	FR_Tune("fw_loss_base", 0.05);
	s.w = 1;
	s.rs = FR_RsFor(0.001);
	local nx = lp.s[TRF_FrNextStopOf(lp, TRF_FrNextOf(s.p, lp.n))];
	local e = TRF_FrEarn(s, lp);
	local c0 = TRF_ClanScore(TRF_RgOf(lp.s[TRF_FrNextOf(s.p, lp.n)]));
	local n0 = S_Mark();
	FR_Ticks(1);
	local sh = FR_Short(nx);
	HOST_Check(TRF_FrShip(1) == nil and co.lost == 1 and co.vch == 30000 and co.owe == 25 * e and sh and sh.pk == 1
		and TRF_ClanScore(TRF_RgOf(lp.s[3])) == min(99, c0 + 2) and S_Logs(n0, "event=lost ship_id=1") == 1 and S_Logs(n0, "cause=roll vch=30000") == 1,
		"loss: ship removed, voucher 75 % of the price paid, liability 25 e owed, pk shortage at the next stop, clan +2");
	HOST_Check(TRF_ShortRelief and not FR_Has(TRF_Dump(TRF_ShortRelief()), "s="..nx..","), "the own-freighter shortage is never a relief target");
	-- The next dock: the loss line with the clerk line, the liability from the wallet (no balance).
	co.bal = 1000;
	h.credits = 500;
	FR_Visit();
	local r = FR_Dock();
	local due = 25 * e;
	HOST_Check(FR_Has(r.scr, "lost near "..TRF_FrSys(lp.s[3])..". FTU cover: your next hull at 25 % of list.") and FR_Has(r.scr, "FTU clerk: 'The Carrier makes amends for the Cargo.'")
		and FR_Has(r.scr, "carrier liability charged: 1,500 cr. Still owed: "..TRF_FrNum(due - 1500).." cr.") and co.owe == due - 1500 and h.credits == 0 and co.bal == 0,
		"loss and clerk lines; liability from the balance (1,000) and the wallet (500), the rest owed: "..r.scr);
	HOST_Check(TRF_FrBuyGate(idx) == "owe", "liability owed: no purchase");
	-- Later balance clears the rest before a payout.
	co.bal = due;
	h.credits = 0;
	FR_Visit();
	r = FR_Dock();
	HOST_Check(co.owe == 0 and co.bal == 0 and FR_Has(r.scr, "Wolves Freight paid 1,500 cr") and FR_Has(r.scr, "carrier liability charged: "..TRF_FrNum(due - 1500).." cr."),
		"the rest taken from the next balance first, then the payout: "..r.scr);
	-- A second loss is not the first: no clerk line.
	h.credits = 1000000;
	co.vch = 0;
	FR_Visit();
	local s2 = FR_Buy();
	HOST_Check(s2 and co.vch == 0, "rebought");
	TRF_FrLose(co, 1, s2, idx, "roll", nil, 2);
	FR_Visit();
	r = FR_Dock();
	HOST_Check(FR_Has(r.scr, "lost near") and not FR_Has(r.scr, "FTU clerk"), "second loss: no clerk line");
	HOST_Check(co.vch == floor(0.75 * s2.price), "voucher replaced by the larger value");
	-- A smaller voucher never replaces a larger one.
	co.vch = 999999;
	local s3 = FR_Ship("debris6", {price=1000});
	TRF_FrLose(co, 1, s3, idx, "roll", nil, nil);
	HOST_Check(co.vch == 999999, "a smaller voucher does not replace a larger one, never summed");
end;

-- f: on-screen appearance -----------------------------------------------------------------------------

function T_FR_F()
	local h = HOST();
	FR_Begin("debris6", "9_1");
	FR_Tune("fw_tick_real", 3600);
	FR_Tune("fw_rob_base", {0, 0, 0, 0, 0, 0});
	local cal = FR_Idx("debris1");
	local slot = TRF_RgOf(cal);
	local lp = TRF_FrLoop(slot);
	local s = FR_Ship("debris6", {home=FR_Idx("debris6"), p=TRF_FrStopOf(lp, cal), w=0, k=20});
	h.cfg.fw_marker = 1;
	-- dock_mode 0 (removal at the approach point): the dock arrivals below predate the default 2 of 2026-10-25.
	h.cfg.dock_mode = 0;
	-- Path A: the first tick at the stop; the jump into Callipso.
	local n0 = S_Mark();
	s = FR_Jump("debris1");
	FR_World();
	HOST_Check(S_Logs(n0, "event=plan ship_id=1 tick=20 path=A") == 1 and s.sk == 20, "entry at the ship's stop (first tick): path A planned, sk = k");
	local dl = tonumber(FR_Kv(S_Line(n0, "event=plan ship_id=1"), "delay"));
	HOST_Check(dl >= 60 and dl <= 120, "path A 60-120 s after entry ("..tostring(dl)..")");
	s.rs = s.rs;
	local pw = s.p;
	TRF.clock.legs = TRF.clock.legs + 1; TRF.clock.rs = TRF.clock.rs + 3600;
	TRF_Fr_Step();
	HOST_Check(TRF_FrShip(1).p == pw and TRF_FrShip(1).w == 0 and TRF_FrShip(1).k == 21, "a tick while the appearance is due: the ship holds its stop (k 21)");
	FR_Wait(dl + 1);
	local id, r = FR_Rec();
	local prev = lp.s[TRF_FrPrevOf(s.p, lp.n)];
	HOST_Check(id and r.path == "A" and r.fw == 1 and r.nm == s.nm and r.from == prev and S_Logs(n0, "event=spawn ship_id=1 trader_id="..id.." group=TRF_Fw_1 relation=friend hull=Btransport") == 1,
		"spawned as a trader record with the fw flag, through the portal facing the previous system (EW8.2 log)");
	local rel = "";
	for i = 1, getn(h.rel) do if h.rel[i][1] == "TRF_Fw_1" or h.rel[i][2] == "TRF_Fw_1" then rel = rel..h.rel[i][1]..">"..h.rel[i][2]..":"..h.rel[i][3]..","; end; end;
	local x = TRF_H().tr[id];
	HOST_Check(rel == "TRF_Fw_1>PlayerGroup:2,PlayerGroup>TRF_Fw_1:2," and x.sh[1].tpl == "Btransport" and x.sh[1].pilot.tpl == "Trader" and getn(x.sh) == 1
		and getglobal("TRF_GFw_1") == nil, "group TRF_Fw_1 FRIEND both ways, one Btransport with pilot Trader, no group global left");
	HOST_Check(FR_Has(TRF.mk or "", "TRF_FW_1=fw"), "nav marker on the ship (TRF_MarkerAdd)");
	HOST_Check(FR_Has(TRF_UI_Who(r, id), "Wolves Freight "..TRF_FrShipName(s.nm)), "focus name: Wolves Freight <name>");
	-- Re-entry within the same ship tick: no second appearance.
	-- Docking with the mothership within 400: escort cover and the visit credit once.
	local lead = TRF_GnLead(id);
	h.ms.pos = Vector3(lead.pos.x + 150, lead.pos.y, lead.pos.z);
	lead.hp = 0.6 * (r.hp0 or 1000);
	local pc0 = TRF_Pro(cal);
	TRF.live.pv = 0; TRF.live.pc = 0;
	n0 = S_Mark();
	HOST_Fire("f_inside", "TRF_OnArrive("..id..",0,");
	FR_Wait(25);
	HOST_Check(not TRF_FrRecOpen(id) and s.cov == 27 and s.ek == 21 and s.p == TRF_FrStopOf(lp, cal) and S_Logs(n0, "event=dock ship_id=1 trader_id="..id.." how=dock esc=1") == 1,
		"docked escorted: cover k + 6, ek = k, p unchanged (path A arrival)");
	HOST_Check(s.dmg == 1, "dock at 60 % hull: damage band 1 recorded at the arrival");
	HOST_Check(S_Logs(n0, "event=pro_credit") >= 1 or TRF_Pro(cal) >= pc0, "visit credit counted");
	-- Covered: the next ticks void a robbery.
	FR_Tune("fw_tick_real", 120);
	FR_Tune("fw_rob_base", {0.12, 0.12, 0.12, 0.12, 0.12, 0.12});
	s.rs = FR_RsFor(0.05);
	n0 = S_Mark();
	FR_Ticks(1);
	HOST_Check(s.st == 0 and S_Logs(n0, "out=rob void=cover") == 1, "escort cover: a robbery draw is void");
	FR_Tune("fw_rob_base", {0, 0, 0, 0, 0, 0});
	FR_Tune("fw_tick_real", 3600);
	-- Same tick re-entry: skipped (sk).
	s.w = 0; s.sk = s.k;
	n0 = S_Mark();
	s = FR_Jump("debris1", 1);
	HOST_Check(S_Logs(n0, "event=spawn ship_id=1 tick="..s.k.." sk="..s.k.." result=skipped reason=same_tick") == 1, "re-entry in the same ship tick: no appearance (EW8.9)");
	-- Path B: the dwell tick, undocking as the seed; its exit moves p on.
	s.k = s.k + 1; s.w = 1;
	n0 = S_Mark();
	s = FR_Jump("debris1", 1);
	HOST_Check(S_Logs(n0, "event=plan ship_id=1 tick="..s.k.." path=B") == 1 and TRF.live.ent == "freight", "dwell tick: path B as the seed (entry plan ent=freight)");
	FR_Wait(31);
	id, r = FR_Rec();
	HOST_Check(id and r.path == "B" and r.to == lp.s[TRF_FrNextOf(s.p, lp.n)], "path B toward the portal of the next system");
	h.ms.pos = Vector3(5000, 0, 5000);
	local p0 = s.p;
	n0 = S_Mark();
	HOST_Fire("f_object_inside", "TRF_OnExit("..id..",");
	HOST_Check(s.p == TRF_FrNextOf(p0, lp.n) and s.w == 0 and S_Logs(n0, "how=exit esc=0") == 1 and s.cov == 27, "exit through the portal: p + 1, no escort far away, cover unchanged");
	local rh = TRF_Fr_RaidHelp(9, {id=id}, 100);
	HOST_Check(not TRF_FrRecOpen(id) and type(rh) == "table" and rh.cancel == 1 and rh.nohelp == 1 and TRF.live.tr[id].fw == 1,
		"the gone record keeps fw: a raid that ends after the ship left still pays no 8.5 credits or help");
	-- Chapter 6 story system: no appearance until chapter 7 (Debris4).
	local d1 = FR_Idx("debris4");
	s.p = TRF_FrStopOf(lp, d1); s.w = 0; s.k = s.k + 1;
	h.labels.CurrentQuest = "6_1";
	n0 = S_Mark();
	s = FR_Jump("debris4");
	HOST_Check(FR_Logs(n0, "result=skipped reason=chapter6") == 1, "chapter 6: never on-screen in Debris4");
	h.labels.CurrentQuest = "9_1";
	-- fw_onscreen 0 and a mission.
	h.cfg.fw_onscreen = 0;
	s.k = s.k + 1;
	n0 = S_Mark();
	T_Jump("debris6"); s = FR_Jump("debris4");
	HOST_Check(FR_Logs(n0, "result=skipped reason=off") == 1, "fw_onscreen 0: no appearance");
	h.cfg.fw_onscreen = 1;
	s.k = s.k + 1;
	h.qs = TRUE;
	n0 = S_Mark();
	T_Jump("debris6"); s = FR_Jump("debris4");
	HOST_Check(FR_Logs(n0, "result=skipped reason=quest") == 1, "mission running: no appearance");
	h.qs = FALSE; h.quests = {};
	-- Laid up: no appearance (step 1 has no parked ship).
	s.k = s.k + 1; s.st = 1; s.till = s.k + 5;
	n0 = S_Mark();
	T_Jump("debris6"); s = FR_Jump("debris4");
	HOST_Check(FR_Logs(n0, "reason=state_1") == 1, "laid up: no appearance");
end;

-- g: on-screen loss and robbery, exclusions ------------------------------------------------------------

-- Ship fixture at Callipso's stop (first tick) and its path A appearance; returns ship, trader id, record.
function FR_Live(t)
	local h = HOST();
	local cal = FR_Idx("debris1");
	local lp = TRF_FrLoop(TRF_RgOf(cal));
	local s = FR_Ship("debris6", {p=TRF_FrStopOf(lp, cal), w=0, k=(t and t.k) or 20, price=40000});
	s = FR_Jump("debris1");
	FR_World();
	FR_Wait(121);
	local id, r = FR_Rec();
	return TRF_FrShip(1), id, r;
end;

function T_FR_G()
	local h = HOST();
	FR_Begin("debris6", "9_1");
	FR_Tune("fw_tick_real", 3600);
	FR_Tune("fw_rob_base", {0, 0, 0, 0, 0, 0});
	local s, id, r = FR_Live();
	HOST_Check(id ~= nil, "on-screen ship spawned");
	-- Exclusions: the hail status line only, no 8.4 offer, no 8.6 demand, never tracked.
	local o = TRF_HailOpts(id, r);
	local ok, why = TRF_CtOffer(id);
	local dk, dw = TRF_DemandOk(id);
	HOST_Check(getn(o) == 1 and o[1] == "fwinfo" and ok == nil and why == "freight" and dk == nil and dw == "freight" and TRF_TrackMark(id, "hail") == nil and not TRF_TkTracked(r),
		"hail: the status line only; no 8.4 offer, no 8.6 demand, never tracked");
	HOST_Check(FR_Has(TRF_Fr_HailId(id), ", Wolves Freight. Bound for ") and TRF_HlLabel(id, "fwinfo") == "Status report", "status line: "..tostring(TRF_Fr_HailId(id)));
	-- Raid: comply robs the run; 8.5 pays nothing, no help.
	s.run = 700;
	h.rq = {0};
	local n = TRF_RaidRoll(id, "contract");
	h.rq = {};
	if not n then n = V_Raid(id); end;
	local rd = V_Rd(n);
	HOST_Check(rd ~= nil, "raid armed on the freighter");
	local c0 = TRF_ClanScore(TRF_RgOf(TRF_CurIdx()));
	TRF_Rd_Comply(n, rd, r, TRF_H().tr[id]);
	HOST_Check(s.run == 0 and s.st == 1 and FR_Short(TRF_CurIdx()) == nil, "comply: run lost, laid up, no shortage (only a loss gives one)");
	local help0, cr0, heat0 = TRF.std.help, h.credits, TRF.std.heat;
	rd.hit = 1; rd.paid = nil; rd.tk = nil;
	local n0 = S_Mark();
	TRF_Rd_Pay(n, rd);
	HOST_Check(TRF.std.help == help0 and h.credits == cr0 and TRF.std.heat == heat0 and S_Logs(n0, "event=raid_answered ship_id=1 raid_id="..n.." pay=0 help=0") == 1,
		"answered raid on the own freighter: no 8.5 credits, no help, no heat -1 (question 10)");
	-- On-screen loss to pirates: voucher, pk shortage at the next stop, clan +2, no extra traffic clan point.
	s.st = 0;
	local lp = TRF_FrLoop(s.rg);
	local nx = lp.s[TRF_FrNextStopOf(lp, s.p)];
	local sl = TRF_RgOf(TRF_CurIdx());
	local cs = TRF_ClanScore(sl);
	n0 = S_Mark();
	local x = TRF_H().tr[id];
	x.tp[1].alive = nil;
	HOST_Fire("died", "TRF_OnShipDied("..id..",1,"..TRF.gen..")--");
	local sh = FR_Short(nx);
	HOST_Check(TRF_FrShip(1) == nil and TRF.co.vch == 30000 and sh and sh.pk == 1 and TRF_ClanScore(sl) == min(99, cs + 2) and FR_Short(TRF_CurIdx()) == nil
		and S_Logs(n0, "event=lost ship_id=1") == 1 and S_Logs(n0, "cause=pirates") == 1, "on-screen loss: voucher, pk shortage at the next stop, clan +2");
	-- Counted player fire: no voucher, the normal kill heat.
	TRF.co.vch = 0;
	FR_Begin("debris6", "9_1");
	FR_Tune("fw_tick_real", 3600);
	FR_Tune("fw_rob_base", {0, 0, 0, 0, 0, 0});
	s, id, r = FR_Live();
	local h0, o0 = TRF.std.heat, TRF.co.owe;
	n0 = S_Mark();
	V_PlayerKill(id);
	HOST_Check(TRF_FrShip(1) == nil and TRF.co.vch == 0 and TRF.std.heat == h0 + 1 and S_Logs(n0, "cause=player vch=0 voucher=0 owe_added=0") == 1 and TRF.co.log[1].f == 2
		and TRF.co.owe == o0, "own kill: no voucher, no liability, heat +1 (EW8.8)");
	FR_Visit();
	local dr = FR_Dock();
	HOST_Check(FR_Has(dr.scr, "FTU pays no cover for a hull your own wing shot down."), "own-kill line at the dock: "..dr.scr);
end;

-- h: chapter 19, config off, dump, load, jump, repair, save bound, simulation ------------------------------

function T_FR_H()
	local h = HOST();
	FR_Begin("debris6", "19_1");
	FR_Tune("fw_rob_base", {0, 0, 0, 0, 0, 0});
	local s = FR_Ship("debris6");
	HOST_Check(TRF_FrBuyGate(TRF_CurIdx()) == "chapter_end", "chapter 19: no new charter");
	FR_Ticks(3);
	FR_Visit();
	local r = FR_Dock();
	HOST_Check(s.k == 13 and FR_Has(r.scr, "Wolves Freight paid"), "chapter 19: the existing ship keeps running and paying");
	-- enable_freight 0: no box, no lines.
	h.labels.CurrentQuest = "9_1";
	h.cfg.enable_freight = 0;
	FR_Ticks(2);
	FR_Visit();
	r = FR_Dock();
	HOST_Check(not FR_Has(r.scr, "Wolves") and r.nb == 0, "enable_freight 0: no freight line, no offer");
	h.cfg.enable_freight = 1;
	-- Dump.
	local n0 = S_Mark();
	TRF_Fr_Dump();
	HOST_Check(S_Logs(n0, "module=freight event=dump balance=") == 1 and S_Logs(n0, "module=freight event=dump_ship slot=1 id=1") == 1, "dump: account and ship lines");
	-- Load with the ship on-screen: the record goes, p stays.
	FR_Tune("fw_tick_real", 3600);
	local cal = FR_Idx("debris1");
	local lp = TRF_FrLoop(TRF_RgOf(cal));
	s.p = TRF_FrStopOf(lp, cal); s.w = 0; s.k = s.k + 1;
	s = FR_Jump("debris1");
	FR_Wait(121);
	local id = FR_Rec();
	HOST_Check(id ~= nil, "ship on-screen before the save");
	local p0 = s.p;
	n0 = S_Mark();
	T_SaveLoad();
	local id2 = FR_Rec();
	HOST_Check(id2 == nil and TRF_FrShip(1).p == p0 and S_Logs(n0, "event=orphan trader_id="..id.." ship_id=1 group=TRF_Fw_1") == 1,
		"load: the on-screen ship removed, p unchanged (EW8.7)");
	-- Jump with a damaged ship: the damage band.
	s = TRF_FrShip(1);
	s.k = s.k + 1; s.w = 0;
	s = FR_Jump("debris1", 1);
	FR_Wait(121);
	id = FR_Rec();
	local lead = TRF_GnLead(id);
	lead.hp = 0.4 * (TRF_Rec(id).hp0 or 1000);
	T_Jump("kron");
	HOST_Check(TRF_FrShip(1).dmg == 2 and FR_Rec() == nil, "jump: damage band 2 from 40 % hull, the flight gone");
	-- Repair: broken fields read their defaults, a ship without a loop region goes.
	TRF.co.bal = -5; TRF.co.vn = "x"; TRF.co.log = {{k=9}, {k=1, s=1, nm=1, sys=5, leg=0}};
	TRF.co.ships[2] = {id=2, rg=7, home=60};
	TRF.co.ships[1].st = 7; TRF.co.ships[1].p = 999;
	TRF_Fr_Fix();
	local c = TRF.co;
	HOST_Check(c.bal == 0 and c.vn == 0 and getn(c.log) == 1 and c.ships[2] == nil and c.ships[1].st == 0 and c.ships[1].p == TRF_FrStopOf(TRF_FrLoop(c.ships[1].rg), c.ships[1].home),
		"repair: bal, vn, log entry, the Torr ship dropped, state and position repaired");
	TRF.co = 5; TRF_Fr_Fix();
	HOST_Check(TRF.co == nil, "repair: a broken TRF.co goes");
	-- Save bound: the worst case of 3.3.
	TRF.co = {seq=99, bal=30000, vn=99999999, pg=99999999, rt=-99999, lk=-99999, vch=2000000, owe=30000, lost=99, decl={sys=113, leg=-99999},
		log={}, ships={}, fo={id=99, to=113}, lq={s=99, nm=40, o=30000}};
	for k = 1, 4 do TRF.co.log[k] = {k=2, s=99, nm=40, sys=113, leg=-99999, f=1, c=99}; end;
	for k = 1, 3 do
		TRF.co.ships[k] = {id=97 + k, nm=40, hull=3, rg=k, home=113, p=50, w=1, k=99999999, run=30000, st=2, till=99999999, cov=99999999,
			dmg=3, rs=2147483646, price=99999999, earned=99999999, sk=99999999, ek=99999999};
	end;
	local sz = HOST_SaveSize(TRF.co);
	print("HOST info TRF.co worst case "..sz.." bytes");
	local one = {seq=1, bal=30000, vn=99999999, pg=99999999, rt=-99999, lk=-99999, vch=2000000, owe=30000, lost=99, ships={TRF.co.ships[1]}};
	print("HOST info TRF.co one ship, no log "..HOST_SaveSize(one).." bytes");
	HOST_Check(sz <= 2500, "TRF.co worst case "..sz.." bytes <= 2500 (spec 3.3: three ships, four log entries with the captain index, decl, fo, lq)");
	TRF.co = nil;
	-- EW8.6: 2000 ticks per loop region against the cycle model (Q4 B16 Bu10 R14 Bs6 Rc6 legs; T1-T2 in Quiet, Boom, Bust,
	-- Recovery, T3-T4 in Build-up, T4 in Raids; dis 2, 4 in Raids), a lost hull replaced at 25 % of list.
	FR_World();
	h.cfg.tune = {};
	local cyc = {{0, 4, 1}, {1, 16, 2}, {2, 10, 3}, {3, 14, 4}, {4, 6, 2}, {5, 6, 1}};
	local ph, len = {}, 0;
	for i = 1, getn(cyc) do for j = 1, cyc[i][2] do len = len + 1; ph[len] = cyc[i]; end; end;
	local tt = {0, 0, 0, 0, 0, 0};
	local L = TRF_FrLoops();
	local slots = {};
	for sl, lp2 in L do tinsert(slots, sl); end;
	sort(slots);
	local over = 0;
	for q = 1, getn(slots) do
		local sl = slots[q];
		local lp2 = L[sl];
		local co = {seq=1, bal=0, vn=0, pg=0, rt=0, lk=0, vch=0, owe=0, lost=0, ships={}};
		TRF.co = co;
		local home = lp2.s[1];
		local list = TRF_FrListOf(1000, lp2.L, 5, 1, 1);
		local mk = function(id) return {id=id, nm=1, hull=1, rg=%sl, home=%home, p=1, w=0, k=0, run=0, st=0, till=0, cov=0, dmg=0,
			rs=TRF_FrSeedOf(id, %sl * 1000), price=%list, earned=0, sk=-1, ek=-1}; end;
		co.ships[1] = mk(1);
		local gross, credited, liab, repl, rob, lost, robbed = 0, 0, 0, 0, 0, 0, 0;
		for t = 1, 2000 do
			local c = ph[mod(t - 1, len) + 1];
			local m = TRF_RgMap();
			for s2 = 1, m.n do TRF.rg[s2].ph = c[1]; TRF.clan[s2].sc = (c[3] - 1) * 25 + 5; end;
			local dis = 2;
			if c[1] == 3 then dis = 4; end;
			for j = 1, lp2.n do TRF_SetDis(lp2.s[j], dis); end;
			local sh2 = co.ships[1];
			gross = gross + TRF_FrEarn(sh2, lp2);
			local b0, lo0, r0 = co.bal, co.lost, sh2.run;
			local st0 = sh2.st;
			TRF_FrShipTick(co, 1, sh2, nil);
			if co.bal > 30000 then over = over + 1; end;
			credited = credited + co.bal - b0;
			co.bal = 0;
			if co.lost > lo0 then
				lost = lost + 1;
				liab = liab + co.owe; co.owe = 0;
				repl = repl + floor(0.25 * list + 0.5);
				co.vch = 0;
				co.ships[1] = mk(lost + 1);
			elseif sh2.st == 1 and st0 == 0 and sh2.run == 0 then
				rob = rob + 1;
				robbed = robbed + r0 + TRF_FrEarn(sh2, lp2) * (1 + TRF_FrT("fw_layup"));
			end;
		end;
		local net = credited - liab - repl;
		TRF_FrE("fwsim", "rg", sl, "ticks", 2000, "gross", gross, "net", net, "rob", rob, "lost", lost, "net_share", TRF_F(net / gross));
		print("HOST info fwsim rg="..sl.." L="..lp2.L.." gross="..gross.." credited="..credited.." net="..net.." rob="..rob.." lost="..lost);
		tt[1] = tt[1] + gross; tt[2] = tt[2] + net; tt[3] = tt[3] + rob; tt[4] = tt[4] + lost; tt[5] = tt[5] + 2000; tt[6] = tt[6] + robbed;
	end;
	TRF.co = nil;
	local share = tt[2] / tt[1];
	local per = tt[5] / max(1, tt[4]);
	print("HOST info fwsim all ticks="..tt[5].." net_share="..share.." robberies="..tt[3].." losses="..tt[4].." ticks_per_loss="..per);
	HOST_Check(share >= 0.60 and share <= 0.75 and over == 0, "EW8.6: net yield 60-75 % of gross over the loop regions ("..format("%.3f", share).."), no balance above pay_cap");
	local rsh = tt[6] / tt[1];
	print("HOST info fwsim robbery share "..rsh);
	HOST_Check(rsh >= 0.08 and rsh <= 0.16, "EW8.6: robbery share 8-16 % of gross ("..format("%.3f", rsh)..")");
	-- Expected ticks per loss of the model (the loss chance summed over one cycle), and the sample within 40 % of it.
	local pl = 0;
	for t = 1, len do
		local c = ph[t];
		local dis = 2;
		if c[1] == 3 then dis = 4; end;
		pl = pl + TRF_FrLossOf(0.002, TRF_FrTierFOf(c[3]), dis, c[1], c[3]);
	end;
	local ex = len / pl;
	print("HOST info fwsim expected ticks per loss "..ex);
	HOST_Check(ex >= 600 and ex <= 1050 and per >= 0.6 * ex and per <= 1.4 * ex,
		"EW8.6: one loss per 600-1050 ticks (20-35 h at 30 ticks/h): model "..format("%.0f", ex)..", sample "..format("%.0f", per));
	HOST_Check(HOST_Reserved(TRF, "TRF") == "", "no reserved key");
end;

-- i: slots 2 and 3 (help gates, charter rank, prices, weights, one ship per region, three ships' lines) --------------

-- Ship fixture in slot i (FR_Ship writes slot 1): the loop of sys's region, at its stop of sys, fields of t override.
function FR_ShipAt(i, sys, t)
	local co = TRF_FrCo(1);
	local idx = V_Idx(sys);
	local slot = TRF_RgOf(idx);
	local lp = TRF_FrLoop(slot);
	local s = {id=i, nm=i, hull=1, rg=slot, home=idx, p=TRF_FrStopOf(lp, idx), w=0, k=10, run=0, st=0, till=0, cov=0, dmg=0, rs=4711 + i,
		price=50000, earned=0, sk=-1, ek=-1};
	if t then for k, v in t do s[k] = v; end; end;
	co.ships[i] = s;
	co.seq = max(co.seq, i);
	co.lk = TRF.clock.legs; co.rt = TRF.clock.rs;
	return s;
end;

function T_FR_I()
	local h = HOST();
	FR_Begin("debris6", "9_1");
	FR_Tune("fw_rob_base", {0, 0, 0, 0, 0, 0});
	FR_Ship("debris6");
	T_Jump("elio");
	FR_World();
	local elio = TRF_CurIdx();
	TRF.std.help = 10;
	local g10 = TRF_FrBuyGate(elio);
	TRF.std.help = 15;
	local g15 = TRF_FrBuyGate(elio);
	TRF.std.help = 10;
	-- Charter rank 3 with dues paid stands in for help 15 on slot 2 (14-charter-goals.md 4); unpaid dues do not.
	h.cfg.charter = 1;
	TRF.ch = {on=1, rk=3, rp=12, du=TRF.clock.legs + 10};
	local gr3 = TRF_FrBuyGate(elio);
	TRF.ch.du = TRF.clock.legs - 1;
	local gru = TRF_FrBuyGate(elio);
	TRF.ch.du = TRF.clock.legs + 10; TRF.ch.rk = 2;
	local gr2 = TRF_FrBuyGate(elio);
	h.cfg.charter = 0; TRF.ch = nil;
	HOST_Check(g10 == "help" and g15 == nil and gr3 == nil and gru == "help" and gr2 == "help",
		"slot 2: help 10 refused, help 15 opens it, charter rank 3 with dues paid opens it at help 10, unpaid dues or rank 2 do not ("
		..tostring(g10)..","..tostring(g15)..","..tostring(gr3)..","..tostring(gru)..","..tostring(gr2)..")");
	-- The slot 2 box: price x1.5 and the convoy fee sentence.
	TRF.std.help = 15;
	h.credits = 1000000;
	FR_Visit();
	local r = FR_Dock();
	local lp2 = TRF_FrLoop(TRF_RgOf(elio));
	local l2 = TRF_FrListOf(1000, lp2.L, 5, 1.5, 1);
	HOST_Check(r.nb == 1 and FR_Has(r.box.text, "A bulk freighter is up for charter: "..TRF_FrNum(l2).." cr.")
		and FR_Has(r.box.text, "FTU takes most of a second charter's run as convoy fee."), "slot 2 box: list x1.5 ("..l2..") and the convoy fee sentence: "..tostring(r.box and r.box.text));
	local n0 = S_Mark();
	FR_Press(r, "ok");
	local s2 = TRF_FrShip(2);
	HOST_Check(s2 and s2.rg == TRF_RgOf(elio) and s2.price == l2 and s2.nm ~= TRF_FrShip(1).nm and S_Logs(n0, "event=buy ship_id=2") == 1
		and S_Logs(n0, "slot=2 hull=Btransport result=ok") == 1, "OK: ship 2 in slot 2 on the Gefest loop, its own name");
	-- One ship per region (G2): another Gefest stop refuses at any help.
	TRF.std.help = 30;
	T_Jump("argon"); FR_World();
	HOST_Check(TRF_FrBuyGate(TRF_CurIdx()) == "region_ship", "a second ship in the Gefest region: refused (one ship per region)");
	-- Slot 3: help 30 (rank 3 does not stand in; rank 5 is charter step 2), price x2.25.
	T_Jump("kadenoa"); FR_World();
	local kd = TRF_CurIdx();
	TRF.std.help = 29;
	h.cfg.charter = 1;
	TRF.ch = {on=1, rk=3, rp=12, du=TRF.clock.legs + 10};
	local g29 = TRF_FrBuyGate(kd);
	h.cfg.charter = 0; TRF.ch = nil;
	TRF.std.help = 30;
	local g30 = TRF_FrBuyGate(kd);
	FR_Visit();
	r = FR_Dock();
	local lp3 = TRF_FrLoop(TRF_RgOf(kd));
	local l3 = TRF_FrListOf(1000, lp3.L, 5, 2.25, 1);
	HOST_Check(g29 == "help" and g30 == nil and r.nb == 1 and FR_Has(r.box.text, TRF_FrNum(l3).." cr.") and FR_Has(r.box.text, "convoy fee"),
		"slot 3: help 29 with rank 3 refused, help 30 opens it, list x2.25 ("..l3..")");
	FR_Press(r, "ok");
	HOST_Check(TRF_FrCount() == 3 and TRF_FrShip(3) and TRF_FrShip(3).price == l3, "three ships owned");
	FR_Visit();
	HOST_Check(TRF_FrBuyGate(kd) == "ships", "a fourth ship: refused (fw_max_ships 3)");
	-- Fleet weights by rank of run pay: 1 / 0.3 / 0.1, equal pay ranked by slot.
	local co = TRF.co;
	local e = {};
	for i = 1, 3 do local s = TRF_FrShip(i); e[i] = TRF_FrEarn(s, TRF_FrLoop(s.rg)); end;
	local rk = {TRF_FrRank(TRF_FrShip(1)), TRF_FrRank(TRF_FrShip(2)), TRF_FrRank(TRF_FrShip(3))};
	local okr = 1;
	for i = 1, 3 do for j = 1, 3 do
		if i ~= j and rk[i] == rk[j] then okr = nil; end;
		if i ~= j and e[i] > e[j] and rk[i] > rk[j] then okr = nil; end;
	end; end;
	local w = TRF_FrT("fw_weights");
	local cr = {};
	for i = 1, 3 do
		local s = TRF_FrShip(i);
		co.bal = 0; s.run = 1000;
		TRF_FrCredit(co, s);
		cr[i] = co.bal;
	end;
	HOST_Check(okr and cr[1] == floor(1000 * 0.95 * w[rk[1]]) and cr[2] == floor(1000 * 0.95 * w[rk[2]]) and cr[3] == floor(1000 * 0.95 * w[rk[3]]),
		"weights by rank: run pay "..e[1]..","..e[2]..","..e[3].." ranks "..rk[1]..","..rk[2]..","..rk[3].." credits "..cr[1]..","..cr[2]..","..cr[3]);
	-- Equal run pay: the lower slot ranks first.
	local s3 = TRF_FrShip(3);
	local rg3 = s3.rg;
	s3.rg = TRF_FrShip(2).rg;
	local t2, t3 = TRF_FrRank(TRF_FrShip(2)), TRF_FrRank(s3);
	s3.rg = rg3;
	HOST_Check(t3 == t2 + 1, "equal run pay: slot 2 ranks before slot 3 ("..t2..","..t3..")");
	-- Lines for three ships: payout, at most 2 log lines, whereabouts in the room left; the first slot shown turns.
	co.bal = 3000;
	co.log = nil;
	for i = 1, 3 do local s = TRF_FrShip(i); TRF_FrNote(co, 1, s, TRF_FrLoop(s.rg).s[s.p]); end;
	FR_Visit();
	r = FR_Dock();
	local nl = 0;
	for i = 1, 3 do if FR_Has(r.scr, TRF_FrShipName(TRF_FrShip(i).nm).." was robbed") then nl = nl + 1; end; end;
	HOST_Check(r.n == 3 and FR_Has(r.scr, "Wolves Freight paid 3,000 cr") and nl == 2 and getn(co.log) == 1, "three robberies: payout and two log lines, one waits: "..r.scr);
	FR_Visit();
	r = FR_Dock();
	nl = 0;
	for i = 1, 3 do if FR_Has(r.scr, TRF_FrShipName(TRF_FrShip(i).nm).." was robbed") then nl = nl + 1; end; end;
	local seen = {};
	local wh = 0;
	for v = 1, 3 do
		if v > 1 then FR_Visit(); r = FR_Dock(); end;
		for i = 1, 3 do if FR_Has(r.scr, "Wolves Freight: "..TRF_FrShipName(TRF_FrShip(i).nm).." is in ") then seen[i] = 1; wh = wh + 1; end; end;
		HOST_Check(r.n <= 3, "at most 3 lines per dock ("..r.n..")");
	end;
	HOST_Check(nl == 1 and co.log == nil and seen[1] and seen[2] and seen[3], "the waiting log line next visit; over three visits every ship has its whereabouts line ("..wh..")");
	HOST_Check(HOST_Reserved(TRF, "TRF") == "", "no reserved key");
end;

-- j: hulls (box by L_fw, carcass per hull, hull_k pay, hull_r robbery, the sell-back, repair) -----------------------

function T_FR_J()
	local h = HOST();
	FR_Begin("debris6", "9_1", {fw_hulls=1});
	FR_Tune("fw_tick_real", 3600);
	FR_Tune("fw_rob_base", {0, 0, 0, 0, 0, 0});
	local idx = TRF_CurIdx();
	HOST_Check(TRF_FrHullOf(4, {6, 13}) == 2 and TRF_FrHullOf(6, {6, 13}) == 2 and TRF_FrHullOf(7, {6, 13}) == 1 and TRF_FrHullOf(12, {6, 13}) == 1
		and TRF_FrHullOf(13, {6, 13}) == 3 and TRF_FrHullOf(16, {6, 17}) == 1, "hull by L: Walrus at L <= 6, Btransport 7-12, Btransport2 at L >= 13");
	-- Golkonda (L 6): the Walrus box, price x0.7.
	FR_Visit();
	local r = FR_Dock();
	local lp = TRF_FrLoop(TRF_RgOf(idx));
	local lw = TRF_FrListOf(1000, lp.L, 5, 0.7, 1);
	HOST_Check(r.nb == 1 and FR_Has(r.box.text, "A Walrus hauler is up for charter: "..TRF_FrNum(lw).." cr. Two turrets, no hold"), "Golkonda box: the Walrus at x0.7: "..tostring(r.box and r.box.text));
	local n0 = S_Mark();
	FR_Press(r, "ok");
	local s = TRF_FrShip(1);
	HOST_Check(s and s.hull == 2 and s.price == lw and S_Logs(n0, "hull=Walrus_tr1 result=ok") == 1, "bought: hull 2 (Walrus_tr1)");
	-- hull_k: run pay x0.75.
	HOST_Check(TRF_FrEarn(s, lp) == TRF_FrEOf(3.33, lp.L, TRF_RgR(s.rg), 1, 0.75), "Walrus run pay x0.75 ("..TRF_FrEarn(s, lp)..")");
	-- hull_r: p_rob x0.8 in the roll.
	FR_Tune("fw_tick_real", 120);
	FR_Tune("fw_rob_base", {0.03, 0.03, 0.03, 0.03, 0.03, 0.03});
	s.rs = FR_RsFor(0.9);
	n0 = S_Mark();
	FR_Ticks(1);
	HOST_Check(S_Logs(n0, "event=roll ship_id=1 ") == 1 and FR_Kv(S_Line(n0, "event=roll ship_id=1 "), "p_rob") == format("%.4f", 0.03 * 0.5 * 0.8),
		"Walrus robbery chance x0.8: "..S_Line(n0, "event=roll"));
	FR_Tune("fw_rob_base", {0, 0, 0, 0, 0, 0});
	FR_Tune("fw_tick_real", 3600);
	-- On-screen: the Walrus carcass, no hold.
	h.cfg.fw_marker = 0;
	local cal = FR_Idx("debris1");
	s.p = TRF_FrStopOf(lp, cal); s.w = 0; s.k = s.k + 1;
	n0 = S_Mark();
	s = FR_Jump("debris1");
	FR_World();
	FR_Wait(121);
	local id, rec = FR_Rec();
	local x = id and TRF_H().tr[id];
	HOST_Check(id and x.sh[1].tpl == "Walrus_tr1" and getn(rec.hold) == 0 and S_Logs(n0, "hull=Walrus_tr1 hold=0") == 1, "on-screen Walrus: carcass Walrus_tr1, no hold");
	TRF_Remove(id, "test");
	-- Btransport2 (default fw_hull_l {6, 11}: Kadi, L 11): price x1.8, run pay x1.5, p_rob x1.3, the carcass.
	TRF.co = nil;
	T_Jump("kadi"); FR_World();
	local kd = TRF_CurIdx();
	TRF_SetPro(kd, 5);
	local lk = TRF_FrLoop(TRF_RgOf(kd));
	local nh = {0, 0, 0};
	for k, e in TRF_FrLoops() do local hh = TRF_FrHullOf(e.L, TRF_FrT("fw_hull_l")); nh[hh] = nh[hh] + 1; end;
	HOST_Check(lk.L == 11 and TRF_FrHullOf(lk.L, TRF_FrT("fw_hull_l")) == 3 and nh[1] == 4 and nh[2] == 2 and nh[3] == 1,
		"default fw_hull_l {6, 11}: Btransport2 on the Kadi loop (L 11) only, the Walrus on two loops, Btransport on four");
	FR_Visit();
	r = FR_Dock();
	local lb = TRF_FrListOf(1000, lk.L, 5, 1.8, 1);
	HOST_Check(r.nb == 1 and FR_Has(r.box.text, "A heavy freighter is up for charter: "..TRF_FrNum(lb).." cr."), "Kadi box with the default fw_hull_l: Btransport2 at x1.8: "..tostring(r.box and r.box.text));
	FR_Press(r, "ok");
	s = TRF_FrShip(1);
	HOST_Check(s and s.hull == 3 and TRF_FrEarn(s, lk) == TRF_FrEOf(3.33, lk.L, TRF_RgR(s.rg), 1, 1.5), "Btransport2: hull 3, run pay x1.5");
	local p3 = TRF_FrRobOf(0.04, 1.5, 9, TRF_FrK().hull_r[3], 0.12);
	HOST_Check(p3 == 0.12 and abs(TRF_FrRobOf(0.01, 1, 0, TRF_FrK().hull_r[3], 0.12) - 0.013) < 1e-9, "Btransport2 robbery chance x1.3, clamped 12 %");
	-- fw_hulls 0: the bulk freighter everywhere.
	h.cfg.fw_hulls = 0;
	TRF.co.ships[1] = nil;
	FR_Visit();
	r = FR_Dock();
	HOST_Check(r.nb == 1 and FR_Has(r.box.text, "A bulk freighter is up for charter: "..TRF_FrNum(TRF_FrListOf(1000, lk.L, 5, 1, 1)).." cr."), "fw_hulls 0: the bulk freighter at list");
	FR_Press(r, "cancel");
	h.cfg.fw_hulls = 1;
	TRF.co.decl = nil;
	-- Sell-back (trade-in at 50 %): a laid-up ship at its home station.
	s = FR_ShipAt(1, "kadi", {hull=3, price=80000, st=1, till=99});
	FR_Visit();
	local c0 = h.credits;
	n0 = S_Mark();
	r = FR_Dock();
	HOST_Check(r.nb == 1 and r.box.title == "FTU charter office" and FR_Has(r.box.text, "lies at "..TRF_FrSys(kd)..". The office buys her back for 40,000 cr, half her price. Sell?")
		and S_Logs(n0, "kind=sell result=shown") == 1, "home station, laid up: the sell-back box: "..tostring(r.box and r.box.text));
	local sx = FR_Press(r, "ok");
	HOST_Check(TRF_FrShip(1) == nil and h.credits == c0 + 40000 and FR_Has(sx, "sold back to the FTU for 40,000 cr.") and S_Logs(n0, "event=sell ship_id=1") == 1,
		"OK: the ship goes, 40,000 cr to the wallet");
	FR_Visit();
	r = FR_Dock();
	HOST_Check(r.nb == 1 and FR_Has(r.box.text, "up for charter"), "the region is free: the purchase box again");
	FR_Press(r, "cancel");
	TRF.co.decl = nil;
	-- Running (st 0) or away from home: no sell-back; Cancel starts the cooldown.
	s = FR_ShipAt(1, "kadi", {st=0});
	FR_Visit();
	r = FR_Dock();
	HOST_Check(r.nb == 0, "a running ship: no sell-back box");
	s.st = 2;
	FR_Visit();
	r = FR_Dock();
	HOST_Check(r.nb == 0, "suspended by a full account (paid out at this dock): no sell-back box");
	s.st = 2;
	TRF.std.heat = 5;
	FR_Visit();
	r = FR_Dock();
	HOST_Check(r.nb == 1 and FR_Has(r.box.text, "buys her back"), "suspended at heat 5 at home: the sell-back box");
	FR_Press(r, "cancel");
	TRF.std.heat = 0;
	FR_Visit();
	r = FR_Dock();
	HOST_Check(r.nb == 0 and TRF_FrShip(1) ~= nil, "Cancel: no box for fw_offer_cd legs, the ship kept");
	-- Repair: hull 1..3.
	TRF.co.ships[1].hull = 7;
	TRF.co.ships[2] = nil;
	TRF_Fr_Fix();
	local h1 = TRF_FrShip(1).hull;
	TRF.co.ships[1].hull = 3;
	TRF_Fr_Fix();
	HOST_Check(h1 == 1 and TRF_FrShip(1).hull == 3, "repair: hull 7 reads 1, hull 3 kept");
	HOST_Check(HOST_Reserved(TRF, "TRF") == "", "no reserved key");
end;

-- k: transit appearances, portal follow, the parked ship ---------------------------------------------------------

function T_FR_K()
	local h = HOST();
	FR_Begin("debris6", "9_1", {fw_transit=1, fw_follow=1});
	FR_Tune("fw_tick_real", 3600);
	FR_Tune("fw_rob_base", {0, 0, 0, 0, 0, 0});
	h.cfg.fw_marker = 0;
	local d6 = FR_Idx("debris6");
	local lp = TRF_FrLoop(TRF_RgOf(d6));
	-- Golkonda loop index 4: Debris6 as a transit system between Debris1 (3) and Golkonda (5).
	local s = FR_Ship("debris6", {p=4, w=0, k=20});
	HOST_Check(lp.s[4] == d6 and lp.t[4] == 0 and lp.s[3] == FR_Idx("debris1") and lp.s[5] == FR_Idx("golkonda"), "fixture: Debris6 transit at loop index 4");
	local n0 = S_Mark();
	s = FR_Jump("debris6", 1);
	HOST_Check(S_Logs(n0, "event=plan ship_id=1 tick=20 path=C") == 1 and s.sk == 20, "transit system: path C planned, sk = k");
	local dl = tonumber(FR_Kv(S_Line(n0, "event=plan ship_id=1"), "delay"));
	FR_Wait(dl + 1);
	local id, r = FR_Rec();
	HOST_Check(id and r.path == "C" and r.from == FR_Idx("debris1") and r.to == FR_Idx("golkonda") and S_Logs(n0, "path=C tick=20") == 1,
		"path C: in from the Debris1 portal, out to the Golkonda portal ("..tostring(r and r.from).."->"..tostring(r and r.to)..")");
	local sc = "";
	for i = 1, getn(h.screen) do sc = sc..h.screen[i].t.."|"; end;
	HOST_Check(FR_Has(sc, TRF_FrShipName(s.nm).." passing through, boss. Bound for "), "path C radio line: "..sc);
	-- Exit through the Golkonda portal: p + 1; then the player follows within T_chase (60 s).
	T_Tick(20, 0.5);
	n0 = S_Mark();
	HOST_Fire("f_inside", "TRF_ArmExit("..id..",");
	HOST_Fire("f_object_inside", "TRF_OnExit("..id..",");
	HOST_Check(s.p == 5 and S_Logs(n0, "how=exit") == 1, "path C exit: p 5 (Golkonda)");
	n0 = S_Mark();
	T_Jump("golkonda");
	s = TRF_FrShip(1);
	HOST_Check(S_Logs(n0, "event=follow ship_id=1 destination=golkonda") == 1 and S_Logs(n0, "result=written") == 1, "jump through the same portal within T_chase: follow written");
	HOST_Check(S_Logs(n0, "event=plan ship_id=1 tick=20 path=C") == 1 and S_Logs(n0, "follow=true") >= 1 and TRF.co.fo == nil, "follow consumed: path C in Golkonda in the same ship tick");
	dl = tonumber(FR_Kv(S_Line(n0, "event=plan ship_id=1"), "delay"));
	HOST_Check(dl >= 5 and dl <= 15, "follow delay 5-15 s ("..tostring(dl)..")");
	FR_Wait(dl + 1);
	id, r = FR_Rec();
	HOST_Check(id and r.from == FR_Idx("debris6") and S_Logs(n0, "event=spawn ship_id=1 trader_id="..id) == 1, "the followed ship arrives from the Debris6 portal");
	-- Too late: an exit, then 61 s, then the jump: no follow.
	T_Tick(10, 0.5);
	HOST_Fire("f_inside", "TRF_ArmExit("..id..",");
	HOST_Fire("f_object_inside", "TRF_OnExit("..id..",");
	HOST_Check(s.p == 6, "exit: p 6 (XT-05)");
	T_Tick(122, 0.5);
	n0 = S_Mark();
	T_Jump("xt05");
	HOST_Check(S_Logs(n0, "result=written") == 0 and TRF.co.fo == nil, "jump 61 s after the exit: no follow record");
	HOST_Check(S_Logs(n0, "event=spawn ship_id=1 tick=20 sk=20 result=skipped reason=same_tick") == 1, "no follow: the same ship tick is skipped in XT-05");
	-- Void on load; an unconsumed record goes at OnActivate.
	TRF.co.fo = {id=1, to=FR_Idx("xt05")};
	n0 = S_Mark();
	T_SaveLoad();
	HOST_Check(TRF.co.fo == nil and S_Logs(n0, "event=follow result=dropped reason=load") == 1, "follow record void on load");
	TRF.co.fo = {id=1, to=FR_Idx("kron")};
	n0 = S_Mark();
	T_Jump("debris1");
	HOST_Check(TRF.co.fo == nil and S_Logs(n0, "event=follow ship_id=1 system=debris1 result=dropped reason=other_system") == 1, "follow record for another system: dropped at entry");
	-- fw_follow 0: the exit keeps nothing.
	h.cfg.fw_follow = 0;
	s = TRF_FrShip(1);
	s.p = 4; s.k = s.k + 1; s.w = 0;
	T_Jump("kron"); s = FR_Jump("debris6");
	FR_Wait(121);
	id, r = FR_Rec();
	T_Tick(4, 0.5);
	HOST_Fire("f_inside", "TRF_ArmExit("..id..",");
	HOST_Fire("f_object_inside", "TRF_OnExit("..id..",");
	n0 = S_Mark();
	T_Jump("golkonda");
	HOST_Check(S_Logs(n0, "event=follow") == 0 and TRF.co.fo == nil, "fw_follow 0: no follow");
	h.cfg.fw_follow = 1;
	-- fw_transit 0: no path C.
	h.cfg.fw_transit = 0;
	s = TRF_FrShip(1);
	s.p = 4; s.k = s.k + 1; s.w = 0;
	n0 = S_Mark();
	T_Jump("kron"); s = FR_Jump("debris6");
	HOST_Check(S_Logs(n0, "event=plan ship_id=1") == 0, "fw_transit 0: no transit appearance");
	h.cfg.fw_transit = 1;
	-- Parked ship at home (S25): laid up at its home stop, one ship of cap_ships, no hold, FRIEND, still, gone at the jump.
	h.cfg.fw_parked = 1;
	-- Home Debris1 (the host scene's station label is the map label there).
	local d1 = FR_Idx("debris1");
	s = FR_Ship("debris1", {st=1, till=99, k=30});
	n0 = S_Mark();
	T_Jump("kron"); s = FR_Jump("debris1");
	local cs0 = TRF_CapShips();
	FR_Wait(5);
	local pk = TRF_FrSH().v.pk;
	local o = pk and pk.sh;
	local rel = "";
	for i = 1, getn(h.rel) do if h.rel[i][1] == "TRF_Fw_1" or h.rel[i][2] == "TRF_Fw_1" then rel = rel..h.rel[i][1]..">"..h.rel[i][2]..":"..h.rel[i][3]..","; end; end;
	HOST_Check(o and o.alive and o.tpl == "Btransport" and o.cleared == 1 and pk.fl.stopped == 1 and o.label == "trf_fw_1_1" and S_Logs(n0, "event=parked ship_id=1 slot=1 system=debris1") == 1
		and FR_Has(rel, "TRF_Fw_1>PlayerGroup:2,PlayerGroup>TRF_Fw_1:2,") and getglobal("TRF_GFw_1") == nil, "parked ship: Btransport, inventory cleared, stopped, label trf_fw_1_1, FRIEND, no group global");
	HOST_Check(TRF_Fr_Ships("freight") == 1 and TRF_CapShips() == cs0 + 1, "the parked ship counts one ship of cap_ships (TRF_CapReg freight)");
	local p0 = o:GetPosition();
	FR_Wait(30);
	HOST_Check(HOST_Dist(o:GetPosition(), p0) < 1, "it never moves");
	T_Jump("kron");
	HOST_Check(not o.alive and TRF_Fr_Ships("freight") == 0 and TRF_FrSH().v.pk == nil, "deleted at the jump");
	-- Suspended fleet (st 2) at home: parked too; load: the plumbing orphan scan deletes it.
	s = TRF_FrShip(1);
	s.st = 2;
	s = FR_Jump("debris1");
	FR_Wait(5);
	o = TRF_FrSH().v.pk and TRF_FrSH().v.pk.sh;
	HOST_Check(o and o.alive, "suspended at home: parked");
	T_SaveLoad();
	HOST_Check(not o.alive and TRF_FrSH().v.pk == nil, "load: the parked ship removed (label scan trf_fw_1_1)");
	-- Gone without a died event: no loss, the record stays.
	s = TRF_FrShip(1);
	n0 = S_Mark();
	T_Jump("kron"); s = FR_Jump("debris1");
	FR_Wait(5);
	o = TRF_FrSH().v.pk and TRF_FrSH().v.pk.sh;
	local pre = "TRF_Fr_ParkDied(1,"..TRF.gen..")--";
	HOST_Check(o ~= nil and HOST_Live("died", pre) == 1 and HOST_Live("attack", "TRF_Fr_ParkHit(1,"..TRF.gen..")--") == 1
		and S_Logs(n0, "attack_trigger=true died_trigger=true result=spawned") == 1, "parked again after the load, attack and died triggers armed");
	o.alive = nil;
	n0 = S_Mark();
	FR_Wait(3);
	HOST_Check(TRF_FrShip(1) ~= nil and TRF_FrSH().v.pk == nil and S_Logs(n0, "event=parked ship_id=1 died_trigger=true result=gone") == 1
		and S_Logs(n0, "event=lost") == 0, "parked ship gone without a died event: no loss, the record kept");
	-- Killed by others (the died event, no player fire): the loss of its ship (cause parked) with the voucher.
	TRF.co.vch = 0;
	T_Jump("kron"); s = FR_Jump("debris1");
	FR_Wait(5);
	o = TRF_FrSH().v.pk and TRF_FrSH().v.pk.sh;
	o.alive = nil;
	n0 = S_Mark();
	HOST_Fire("died", "TRF_Fr_ParkDied(1,"..TRF.gen..")--");
	HOST_Check(TRF_FrShip(1) == nil and TRF.co.vch == 37500 and TRF.co.log[getn(TRF.co.log)].f == 1 and S_Logs(n0, "event=parked ship_id=1 by=other counted=false result=destroyed") == 1
		and S_Logs(n0, "cause=parked vch=37500") == 1, "parked ship killed by others: the ship is lost, 75 % voucher, the first-loss log entry");
	-- Own kill: player fire counted (T_del distinct seconds), the died event after pk_win: no voucher, heat +1, pro -3 (EW8.8).
	s = FR_Ship("debris1", {st=1, till=99, k=30});
	TRF.co.vch = 0;
	T_Jump("kron"); s = FR_Jump("debris1");
	FR_Wait(5);
	o = TRF_FrSH().v.pk and TRF_FrSH().v.pk.sh;
	local hp = "TRF_Fr_ParkHit(1,"..TRF.gen..")--";
	n0 = S_Mark();
	for j = 1, 5 do HOST_Fire("attack", hp); FR_Wait(1); end;
	HOST_Check(TRF_FrSH().v.pk.cnt == 1 and S_Logs(n0, "result=hit") == 5 and S_Logs(n0, "arm_count=4 result=hit") == 1 and S_Logs(n0, "result=counted") == 1
		and HOST_Live("attack", hp) == 5, "five hits in five seconds count the fire (T_del), the trigger re-armed until then");
	FR_Wait(12);
	local h0, p0, o0 = TRF.std.heat, TRF_Pro(d1), TRF.co.owe;
	o.alive = nil;
	n0 = S_Mark();
	HOST_Fire("died", "TRF_Fr_ParkDied(1,"..TRF.gen..")--");
	HOST_Check(TRF_FrShip(1) == nil and TRF.co.vch == 0 and TRF.co.owe == o0 and TRF.std.heat == h0 + 1 and p0 >= 3 and TRF_Pro(d1) == p0 - 3 and TRF.co.log[getn(TRF.co.log)].f == 2
		and S_Logs(n0, "event=parked ship_id=1 by=player counted=true result=destroyed") == 1 and S_Logs(n0, "cause=player vch=0 voucher=0 owe_added=0") == 1,
		"own kill of the parked ship: no voucher, no liability, heat +1, pro -3, the own-fire log entry (EW8.8)");
	-- Kill proxy without a count: one hit, then the died event within pk_win: by=player counted=false (no voucher); the
	-- re-arm cap logs once; a died callback of a stale gen or another ship id does nothing.
	s = FR_Ship("debris1", {st=1, till=99, k=30});
	TRF.co.vch = 0;
	T_Jump("kron"); s = FR_Jump("debris1");
	FR_Wait(5);
	o = TRF_FrSH().v.pk and TRF_FrSH().v.pk.sh;
	hp = "TRF_Fr_ParkHit(1,"..TRF.gen..")--";
	n0 = S_Mark();
	HOST_Fire("attack", hp);
	HOST_Check(o ~= nil and TRF_FrSH().v.pk.cnt == nil and TRF_FrSH().v.pk.arm == 1 and HOST_Live("attack", hp) == 2 and S_Logs(n0, "arm_count=0 result=hit") == 1,
		"one hit: not counted, the hit line, the trigger re-armed once");
	TRF_FrSH().v.pk.arm = TRF_FrK().pk_arm;
	HOST_Fire("attack", hp);
	HOST_Check(TRF_FrSH().v.pk.arm == TRF_FrK().pk_arm + 1 and HOST_Live("attack", hp) == 2 and S_Logs(n0, "rearm_max=200 result=rearm_cap") == 1
		and HOST_Fire("attack", hp) == nil, "re-arm cap: one rearm_cap line, no new trigger");
	TRF_Fr_ParkDied(1, TRF.gen - 1); TRF_Fr_ParkDied(2, TRF.gen);
	HOST_Check(TRF_FrShip(1) ~= nil and TRF_FrSH().v.pk ~= nil, "a died callback of a stale gen or another ship id: nothing");
	FR_Wait(3);
	h0 = TRF.std.heat;
	o.alive = nil;
	n0 = S_Mark();
	HOST_Fire("died", "TRF_Fr_ParkDied(1,"..TRF.gen..")--");
	HOST_Check(TRF_FrShip(1) == nil and TRF.co.vch == 0 and TRF.std.heat == min(h0 + 1, 9) and S_Logs(n0, "event=parked ship_id=1 by=player counted=false result=destroyed") == 1
		and S_Logs(n0, "cause=player vch=0") == 1, "a hit within pk_win before the died event: the own kill without a count");
	-- fw_parked 0: none; away from home: none.
	s = FR_Ship("debris1", {st=1, till=999});
	h.cfg.fw_parked = 0;
	T_Jump("kron"); FR_Jump("debris1");
	FR_Wait(5);
	HOST_Check(TRF_FrSH().v.pk == nil, "fw_parked 0: no parked ship");
	h.cfg.fw_parked = 1;
	T_Jump("golkonda");
	FR_Wait(5);
	HOST_Check(TRF_FrSH().v.pk == nil, "not its home station: no parked ship");
	T_Jump("kron");
	HOST_Check(HOST_Reserved(TRF, "TRF") == "", "no reserved key");
end;

-- l: news, the captain in the robbery line, pods and the halved liability, the chapter-13 line, size ----------------

function T_FR_L()
	local h = HOST();
	FR_Begin("debris6", "9_1", {fw_hooks=1});
	FR_Tune("fw_rob_base", {0, 0, 0, 0, 0, 0});
	local idx = TRF_CurIdx();
	local slot = TRF_RgOf(idx);
	-- News: fw/reg (global) at the first charter only; fw/lost (regional) on a loss.
	TRF.news = nil; TRF.newsx = nil;
	local n0 = S_Mark();
	local s = FR_Buy();
	HOST_Check(s and type(TRF.news) == "table" and TRF.news.fw and TRF.news.fw.v == "reg" and TRF.news.fw.n == 1
		and S_Logs(n0, "event=news topic=fw variant=reg") == 1 and TRF_UI_NewsText("fw", "reg", nil) == "FTU registers Wolves Freight",
		"first charter: the global bulletin 'FTU registers Wolves Freight'");
	TRF.news.fw.n = 0;
	local lp = TRF_FrLoop(s.rg);
	TRF_FrLose(TRF.co, 1, s, lp.s[s.p], "roll", nil, nil);
	local e = TRF.newsx and TRF.newsx[slot] and TRF.newsx[slot].fw;
	HOST_Check(e and e.v == "lost" and TRF_UI_NewsText("fw", "lost", slot) == "Wolves Freight hull lost near Golkonda", "a loss: the regional bulletin 'Wolves Freight hull lost near Golkonda'");
	TRF.co.owe = 0; TRF.co.vch = 0;
	n0 = S_Mark();
	FR_Buy();
	HOST_Check(S_Logs(n0, "topic=fw variant=reg") == 0 and TRF.news.fw.n == 0, "a later charter: no second registration post (one post per topic)");
	-- news_mode 0: nothing posted.
	h.cfg.news_mode = 0;
	TRF.newsx = nil;
	TRF_FrLose(TRF.co, 1, TRF_FrShip(1), idx, "roll", nil, nil);
	HOST_Check(TRF.newsx == nil or TRF.newsx[slot] == nil or TRF.newsx[slot].fw == nil, "news_mode 0: no post");
	h.cfg.news_mode = nil;
	TRF.co.owe = 0; TRF.co.log = nil;
	-- Feature 4: the robbing clan's living captain named in the robbery line.
	s = FR_Ship("debris6");
	h.cfg.cap_enable = 1;
	if type(TRF.cap) ~= "table" then TRF.cap = {}; end;
	TRF.cap[slot] = {nm=3, st=2, gen=1};
	TRF_FrRob(TRF.co, s, idx, "roll");
	local c3 = TRF.co.log[1].c;
	TRF.cap[slot].st = 4;
	TRF_FrRob(TRF.co, s, idx, "roll");
	local c4 = TRF.co.log[2].c;
	TRF.cap[slot].st = 2;
	h.cfg.fw_hooks = 0;
	TRF_FrRob(TRF.co, s, idx, "roll");
	local c0 = TRF.co.log[3].c;
	h.cfg.fw_hooks = 1;
	local cn = TRF_Cap_NmText(3);
	h.cfg.cap_enable = 0;
	FR_Visit();
	local r = FR_Dock();
	HOST_Check(c3 == 3 and c4 == nil and c0 == nil and type(cn) == "string" and FR_Has(r.scr, "was robbed near "..TRF_FrSys(idx).." by the crew of "..cn..". Hold lost"),
		"robbery with a living captain: his name in the line (dead captain or fw_hooks 0: none): "..r.scr);
	TRF.cap = nil; TRF.co.log = nil;
	-- Feature 6: an on-screen loss to pirates leaves pods with the ship id; the hand-in halves that loss's liability.
	h.cfg.enable_survivors = 1;
	FR_Tune("fw_tick_real", 3600);
	local id = nil;
	s, id, r = FR_Live();
	local x = TRF_H().tr[id];
	x.tp[1].alive = nil;
	-- The loss point away from the portals and the station (the survivors' site rule).
	TRF_SvSV().pc[id] = {x=-300, y=0, z=400};
	x.tp[1].pos = Vector3(-300, 0, 400);
	n0 = S_Mark();
	HOST_Fire("died", "TRF_OnShipDied("..id..",1,"..TRF.gen..")--");
	local lq = TRF.co.lq;
	local b = TRF.sv and TRF.sv.b and TRF.sv.b[getn(TRF.sv.b)];
	HOST_Check(TRF_FrShip(1) == nil and lq and lq.s == 1 and lq.o == TRF.co.owe and lq.o > 0 and b and b.fw == 1 and S_Logs(n0, "module=survive event=loss") >= 1
		and S_Logs(n0, "result=beacon") == 1, "on-screen loss: pods with the ship id (fw 1), lq keeps the loss's liability ("..tostring(lq and lq.o)..")");
	-- The pickup carries fw; the hand-in at a trade dock (line 30) halves the liability before the freight line 60.
	FR_Wait(6);
	local j = getn(TRF.sv.b);
	TRF_SvPick(j, TRF.sv.b[j], 1, 10, TRF_SvTune());
	HOST_Check(TRF.sv.c and TRF.sv.c.fw == 1, "the picked pod carries fw into the carry record");
	local o0 = TRF.co.owe;
	local w = floor(lq.o / 2);
	TRF.co.bal = 0;
	h.credits = 0;
	FR_Visit();
	n0 = S_Mark();
	r = FR_Dock();
	HOST_Check(FR_Has(r.scr, "FTU: the crew of "..TRF_FrShipName(lq.nm).." is home. Half the carrier liability is waived: "..TRF_FrNum(w).." cr.") and TRF.co.owe == o0 - w
		and TRF.co.lq == nil and TRF.sv.c == nil and S_Logs(n0, "event=crew ship_id=1 liability="..lq.o.." waived="..w) == 1, "hand-in: half the liability waived: "..r.scr);
	-- Counted player fire: no pods; fw_hooks 0: no pods (step 1 rule).
	TRF.co = nil; TRF.sv = nil;
	s, id, r = FR_Live();
	n0 = S_Mark();
	V_PlayerKill(id);
	HOST_Check(S_Logs(n0, "module=survive event=loss") == 0 or S_Logs(n0, "reason=fire") == 1, "own kill: no pods");
	HOST_Check(TRF.co.lq == nil, "own kill: no liability, no lq");
	h.cfg.fw_hooks = 0;
	TRF.co = nil; TRF.sv = nil;
	s, id, r = FR_Live();
	x = TRF_H().tr[id];
	x.tp[1].alive = nil;
	n0 = S_Mark();
	HOST_Fire("died", "TRF_OnShipDied("..id..",1,"..TRF.gen..")--");
	HOST_Check(S_Logs(n0, "reason=freight") == 1 and (TRF.sv == nil or getn(TRF.sv.b or {}) == 0), "fw_hooks 0: no pods (reason=freight)");
	h.cfg.fw_hooks = 1;
	h.cfg.enable_survivors = 0;
	FR_Tune("fw_tick_real", 120);
	-- A crew without a pending record: nothing.
	HOST_Check(TRF_Fr_CrewHome(7) == nil, "another ship's crew: no waiver");
	-- The chapter-13 FTU alarm line, once per visit, for an owner.
	FR_Begin("debris6", "13_1", {fw_hooks=1});
	FR_Tune("fw_rob_base", {0, 0, 0, 0, 0, 0});
	FR_Ship("debris6");
	FR_Visit();
	r = FR_Dock();
	local r2 = FR_Dock();
	FR_Visit();
	local r3 = FR_Dock();
	HOST_Check(FR_Has(r.scr, "FTU: HQ on alert. Charters run as usual.") and not FR_Has(r2.scr, "HQ on alert") and FR_Has(r3.scr, "HQ on alert") and r.n <= 3,
		"chapter 13: the alarm line once per visit: "..r.scr);
	h.labels.CurrentQuest = "12_1";
	FR_Visit();
	r = FR_Dock();
	h.labels.CurrentQuest = "13_1";
	h.cfg.fw_hooks = 0;
	FR_Visit();
	r2 = FR_Dock();
	h.cfg.fw_hooks = 1;
	TRF.co.ships[1] = nil;
	FR_Visit();
	r3 = FR_Dock();
	HOST_Check(not FR_Has(r.scr, "HQ on alert") and not FR_Has(r2.scr, "HQ on alert") and not FR_Has(r3.scr, "HQ on alert"), "no alarm line in chapter 12, with fw_hooks 0 or without a ship");
	-- Size: the news entries of the topic and the crew record.
	TRF_NewsPost("fw", "reg"); TRF_NewsPost("fw", "lost", 4);
	local ns = HOST_SaveSize(TRF.news.fw) + HOST_SaveSize(TRF.newsx[4].fw) + 16;
	local sz = HOST_SaveSize({s=99, nm=40, o=30000}) + HOST_SaveSize({id=99, to=113}) + 4;
	print("HOST info fw news "..ns.." bytes, lq + fo "..sz.." bytes");
	HOST_Check(ns <= 200 and sz <= 200, "news entries "..ns.." bytes, lq and fo "..sz.." bytes (spec 3.3)");
	HOST_Check(HOST_Reserved(TRF, "TRF") == "", "no reserved key");
end;

-- Dispatch ---------------------------------------------------------------------------------

local sc = getenv("TRF_FR") or "";
local fn = getglobal("T_FR_"..strupper(sc));
print("HOST ==== Wolves Freight scenario fr-"..sc.." dir="..HOST().dir);
if type(fn) == "function" then
	fn();
	HOST_Check(T_LeftGlobals() == "", "no handle globals left at the end"..T_LeftGlobals());
	local q = T_BadCallbacks();
	HOST_Check(q == "", "every mod callback string carries the current gen"..q);
else
	HOST_Check(nil, "unknown Wolves Freight scenario "..sc);
end;
HOST_Check((HOST().gpm_tick or 0) == 0, "no GetPlayerMotherShip from a tick (n="..tostring(HOST().gpm_tick or 0)..")");
print("HOST errors="..HOST().errors.." fails="..HOST().fails);
if HOST().errors > 0 or HOST().fails > 0 then exit(1); end;
exit(0);
