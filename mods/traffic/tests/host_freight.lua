-- Wolves Freight scenarios (design/freight-spec.md 9) under stock Lua 4.0.1: TRF_FR=a..h, run by run_host.sh as its own
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
		voice_events=0, dconv=0, carriers=0, po=0, enable_survivors=0, lad_enabled=0, charter=0, enable_stashes=0, enable_scars=0, log=2, tune={}};
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
	HOST_Check(S_Logs(0, "module=core event=loaded map=true module_count=18 extra_count=14") >= 1, "trf_freight loads after trf_stash (extra_count=14 with trf_nest, trf_parcel and trf_merc)");
	local ml = TRF_ModList();
	HOST_Check(ml[getn(ml) - 3] == "Fr" and TRF_Opt("enable_freight") == 1 and TRF_Opt("fw_onscreen") == 1 and TRF_Opt("fw_losses") == 1
		and TRF_Opt("fw_max_ships") == 1 and TRF_Fr_OptDef().fw_prize_gap == 1 and TRF_Fr_OptDef().fw_marker == 1,
		"TRF_ModList has Fr; toggles: freight, on-screen, losses on, one ship, prize gap and marker on by default");
	h.cfg.fw_max_ships = 3;
	HOST_Check(TRF_FrMaxShips() == 1, "fw_max_ships 3 reads 1 in step 1");
	h.cfg.fw_max_ships = nil;
	local T = TRF_FrTune();
	HOST_Check(T.fw_k == 3.33 and T.fw_price_k == 1000 and T.fw_tick_real == 120 and T.fw_bank == 4 and T.fw_premium == 0.05 and T.fw_cover == 0.75
		and T.fw_liab_ticks == 25 and T.fw_rob_base[1] == 0.005 and T.fw_rob_base[4] == 0.04 and T.fw_loss_base == 0.002 and T.fw_layup == 2
		and T.fw_help_slot[1] == 5 and T.fw_help_slot[3] == 30 and T.fw_min_pro == 4 and T.fw_weights[2] == 0.3 and T.fw_offer_cd == 10,
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
	HOST_Check(nt == 30 and TRF_Txt("fwpaid", "3,900") == "Wolves Freight paid 3,900 cr since your last visit."
		and TRF_Txt("fwwhere", "Kestrel", "Callipso", "Golkonda") == "Wolves Freight: Kestrel is in Callipso, bound for Golkonda.", "30 texts; payout and whereabouts lines of design 2");
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
	HOST_Check(TRF_FrBuyGate(idx) == "ships", "a second ship: refused in step 1 (fw_max_ships 1)");
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
		log={}, ships={}};
	for k = 1, 4 do TRF.co.log[k] = {k=2, s=99, nm=40, sys=113, leg=-99999, f=1}; end;
	for k = 1, 3 do
		TRF.co.ships[k] = {id=97 + k, nm=40, hull=3, rg=k, home=113, p=50, w=1, k=99999999, run=30000, st=2, till=99999999, cov=99999999,
			dmg=3, rs=2147483646, price=99999999, earned=99999999, sk=99999999, ek=99999999};
	end;
	local sz = HOST_SaveSize(TRF.co);
	print("HOST info TRF.co worst case "..sz.." bytes");
	local one = {seq=1, bal=30000, vn=99999999, pg=99999999, rt=-99999, lk=-99999, vch=2000000, owe=30000, lost=99, ships={TRF.co.ships[1]}};
	print("HOST info TRF.co one ship, no log "..HOST_SaveSize(one).." bytes");
	HOST_Check(sz <= 2300, "TRF.co worst case "..sz.." bytes <= 2300 (spec 3.3)");
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
