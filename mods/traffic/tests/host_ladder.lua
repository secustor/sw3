-- Faction service ladder scenarios (design/ladder-spec.md 9) under stock Lua 4.0.1: TRF_LAD=a..g, run by run_host.sh as
-- its own entry point. a install, registrations and the rank line per faction and rung, Neutral and denied
-- stations, the war rule; b permit offer gates (chapter, rank, rival, valid permit, strict gate, flags, toggles) and
-- one ladder box per docking; c permit purchase, rival cap, rank-6 hold, second purchase, poor, stale answer, void
-- on purchase, expiry; d settlement with its cooldown, corporations; e hand-in credit through CostOfHead with the
-- cooldown, the per-docking flag, hand_cap and prisoners of war; f the portal-fine waiver (permit valid, other region,
-- __sys_SOS, war, Kfni) and the _temp_change reset sync; g dump, save/load, repair and TRF.lad at its bound.
-- Loads host_station.lua up to its first scenario (stubs of host_stubs.lua, the helpers of host_traffic.lua and
-- host_v02.lua, the S_* helpers), as host_survive.lua does. The vanilla parts the module uses are host_stubs.lua
-- stubs: CostOfHead (CostOfPirates.script), _PatrolGIBDD_shtraf / _prava (OutOfMission.script), Timer_Seq,
-- CombineStr, SetInitTeamRelation (called by the _temp_change stub as DockStation.script does).

local f = openfile((getenv("TRF_TESTS") or "./").."host_station.lua", "r");
if not f then print("HOST FAIL host_ladder.lua: cannot open host_station.lua"); exit(1); end;
local src = read(f, "*a");
closefile(f);
local cut = strfind(src, "\n-- a: install (12.1, 6.1)", 1, 1);
if not cut then print("HOST FAIL host_ladder.lua: marker '-- a: install (12.1, 6.1)' missing in host_station.lua"); exit(1); end;
dostring(strsub(src, 1, cut), "host_station.lua");

-- Helpers ----------------------------------------------------------------------------------

-- Config: the repo defaults with the entry events that claim slots or spawn on their own off, log 2 (the reason
-- lines), plus t.
function L_Cfg(t)
	local c = {sweeps=0, sweep_ct=0, feq=0, staged=0, seed=0, queue=0, parked=0, voice_events=0, dconv=0, carriers=0, po=0, log=2};
	if t then for k, v in t do c[k] = v; end; end;
	return c;
end;

function L_Begin(sys, ch, t)
	local h = HOST();
	h.labels.CurrentQuest = ch or "9_1";
	h.quests = {};
	S_Begin(sys, L_Cfg(t));
	h.credits = 1000000;
end;

-- fst string with digit f set to v.
function L_Fst(f, v)
	local s = TRF.std.fst;
	TRF.std.fst = strsub(s, 1, f - 1)..v..strsub(s, f + 1);
end;

-- Patrol docking through the wrapper chain (trf_hail thunk -> trf_plumb dispatcher -> vanilla): screen lines
-- (joined by "|"), boxes opened, vanilla dialogs run, the newest box.
function L_Dock()
	local h = HOST();
	local s0, b0, p0 = getn(h.screen), getn(h.boxes), getn(h.pdlgs);
	_param = GetCurrentLocation();
	__PatrolStationDock_Ok();
	local r = {scr="", nb=getn(h.boxes) - b0, nd=getn(h.pdlgs) - p0, s0=s0};
	for i = s0 + 1, getn(h.screen) do r.scr = r.scr..h.screen[i].t.."|"; end;
	if r.nb > 0 then r.box = h.boxes[getn(h.boxes)]; end;
	return r;
end;

-- Answer the box of docking r (which = "ok" or "cancel"); screen lines since the docking, joined.
function L_Press(r, which)
	local h = HOST();
	if r.nb > 0 then HOST_Press(which, r.box); end;
	local s = "";
	for i = r.s0 + 1, getn(h.screen) do s = s..h.screen[i].t.."|"; end;
	return s;
end;

function L_Has(s, t) return strfind(s or "", t, 1, 1); end;

function L_Rel(team, rel)
	local h = HOST();
	if type(h.rel_team) ~= "table" then h.rel_team = {}; end;
	h.rel_team[team.."|"..PLAYER_TEAM] = rel;
	h.rel_team[PLAYER_TEAM.."|"..team] = rel;
end;

function L_Legs(n) TRF.clock.legs = TRF.clock.legs + n; return TRF.clock.legs; end;

-- Region slot of system name.
function L_Slot(name) return TRF_RgOf(V_Idx(name)); end;

-- Permit of f for slot valid d more legs.
function L_Lic(f, slot, d)
	if type(TRF.lad) ~= "table" then TRF.lad = {}; end;
	if type(TRF.lad.lic) ~= "table" then TRF.lad.lic = {}; end;
	if type(TRF.lad.lic[f]) ~= "table" then TRF.lad.lic[f] = {}; end;
	TRF.lad.lic[f][slot] = TRF.clock.legs + d;
end;

-- Portal patrol of OutOfMission.script 299-336 reduced: group, flight flight_pat_gibdd_1, flags of the fine path.
function L_Patrol(team)
	local t = CreateTeam(team);
	P_Patrol = t:CreateGroup("group_Patrol_gibdd");
	NewFlight("P_Patrol", "pat_gibdd_1", "Tiger_vks1", "VksPilot", Vector3(0, 0, 0));
	_f_PatrolGIBDD = 0;
	__sys_SOS = FALSE;
end;

-- Rank titles of the design table (09 section 2), independent of the module's text table.
function L_Titles()
	return {
		{"Wanted by Imperial Security", "Under watch", "Civilian, no file", "Licensed carrier", "Trusted contractor", "Auxiliary of the Fleet", "Friend of the Throne"},
		{"Violator, to be detained", "Flagged", "Unregistered", "Registered contractor", "Trusted contractor", "Volunteer auxiliary", "Commended by the Empress"},
		{"Marked by the families", "Unwelcome", "Outsider", "Known face", "Trusted associate", "Friend of the family", "Under the Triumvirate's protection"},
		{"Blacklisted shipper", "Under review", "Freelancer", "Listed escort", "Preferred escort", "Convoy partner", "Honorary director"},
		{"Barred from InoCo space", "Under review", "Visitor", "Listed vendor", "Approved vendor", "Partner", "Board guest"}};
end;

-- Test box candidates (registered after an entry; the registry is rebuilt by every MapInitialization).
function L_Box400(kind) HOST().lb400 = (HOST().lb400 or 0) + 1; return {text="L offer 400", ok="L_BoxOk", own="l400"}; end;
function L_Box200(kind) HOST().lb200 = (HOST().lb200 or 0) + 1; return {text="L offer 200", ok="L_BoxOk", own="l200"}; end;
function L_BoxOk(a) return nil; end;

-- a: install, registrations, rank line, war rule ------------------------------------------------------

function T_LAD_A()
	local h = HOST();
	L_Begin("fort_russ");
	HOST_Check(S_Logs(0, "module=core event=loaded map=true module_count=18 extra_count=12") >= 1, "trf_ladder loads after trf_survive (extra_count=12 with trf_charter, trf_scar, trf_captain, trf_stash, trf_freight, trf_nest, trf_parcel and trf_merc)");
	HOST_Check(S_Logs(0, "module=ladder event=install gibdd_installed=true gibdd_wrapped=true temp_change_wrapped=true") >= 1,
		"install: _PatrolGIBDD_shtraf wrapped, _temp_change keeps trf_supply's wrapper");
	local src = function(fn) local i = getinfo(fn, "S"); return tostring(i and i.source); end;
	HOST_Check(TRF_LadIsMine(_PatrolGIBDD_shtraf) and strfind(src(TRF_orig_GibddShtraf), "OutOfMission.script", 1, 1)
		and TRF_InstallLadder().gibdd == 0, "wrapped once over the vanilla function; a second install does not wrap again");
	local o1 = TRF_orig_GibddShtraf;
	T_Enter("fort_russ");
	HOST_Check(TRF_orig_GibddShtraf ~= o1 and strfind(src(TRF_orig_GibddShtraf), "OutOfMission.script", 1, 1) and TRF_LadIsMine(_PatrolGIBDD_shtraf),
		"next MapInitialization: wrapped over the redefined vanilla function");
	local P = TRF_PlReg();
	local lo, bo = "", "";
	for i = 1, getn(P.dock.patrol.line) do lo = lo..P.dock.patrol.line[i].o..":"..tostring(P.dock.patrol.line[i].al)..","; end;
	for i = 1, getn(P.dock.patrol.box) do bo = bo..P.dock.patrol.box[i].o..","; end;
	local ch = 0;
	for i = 1, getn(P.coh) do if P.coh[i].f == "TRF_Lad_CoH" then ch = ch + 1; end; end;
	-- Wanted captains (design/captain-spec.md 4) add patrol line 35 and box 100, clan stashes (design/stash-spec.md 4) line 40.
	HOST_Check(lo == "10:nil,35:nil,40:nil,50:1," and bo == "400,300,100," and ch == 1 and getn(P.none) == 1,
		"patrol line 50 (always), box 300 below the 8.10 box, one CostOfHead handler, no _NoneStation_Action handler ("..lo.." "..bo..")");
	-- Rank line for all five factions at every fst (09 section 2 table), with the empire status.
	local sys = {"fort_russ", "llanovar1", "golkonda", "ergelan", "lasad"};
	local fac = {"MSF", "NESF", "Triada", "USS", "InoCo"};
	local band = {1, 1, 1, 2, 3, 3, 4, 5, 6, 7};
	local W = L_Titles();
	local bad = "";
	for fi = 1, 5 do
		T_Enter(sys[fi]);
		for v = 0, 9 do
			TRF.std.fst = "55555";
			L_Fst(fi, v);
			local r = L_Dock();
			local e = fac[fi].." standing: "..W[fi][band[v + 1]].." ("..v..").";
			if fi <= 2 then e = e.." No permit on file."; end;
			if not L_Has(r.scr, e.."|") or r.nd ~= 0 and r.nb > 0 then bad = bad.." "..fi..":"..v; end;
			L_Press(r, "cancel");
		end;
	end;
	HOST_Check(bad == "", "rank line: 5 factions x fst 0..9, titles of the design table, empire status suffix"..bad);
	local n0 = S_Mark();
	T_Enter("fort_russ");
	TRF.std.fst = "65555";
	local r = L_Dock();
	HOST_Check(S_Logs(n0, "module=ladder event=rank_line system=fort_russ faction=Vks standing=6 band=4 war=false region="..L_Slot("fort_russ").." status=none") == 1,
		"rank_line log line");
	L_Press(r, "cancel");
	-- Neutral and denied stations: no ladder line.
	T_Enter("pandora");
	r = L_Dock();
	HOST_Check(not L_Has(r.scr, "standing:") and r.nb == 0 and r.nd == 1, "Neutral patrol station: S19 only, vanilla dialog");
	T_Enter("fronn");
	n0 = S_Mark();
	r = L_Dock();
	HOST_Check(not L_Has(r.scr, "standing:") and r.nb == 0 and S_Logs(n0, "event=rank_line system=fronn faction=Triada result=none reason=deny") == 1,
		"denied system (fronn): no line, no box");
	-- War rule: band 1 title, no status, no box, fst frozen.
	T_Enter("fort_russ");
	TRF.std.fst = "75555";
	L_Rel("Vks", RELATION_WAR);
	n0 = S_Mark();
	r = L_Dock();
	HOST_Check(L_Has(r.scr, "MSF standing: Wanted by Imperial Security (7).|") and r.nb == 0 and r.nd == 1
		and S_Logs(n0, "standing=7 band=1 war=true") == 1 and S_Logs(n0, "event=permit_offer system=fort_russ faction=Vks result=none reason=war") == 1,
		"war rule: band 1 title, no offer, vanilla dialog ("..r.scr..")");
	TRF_FstAdd(1, -3, "test");
	TRF_FstAdd(1, 2, "test");
	HOST_Check(TRF_Fst(1) == 7, "war rule: fst frozen while the relation is W");
	h.rel_team = nil;
	-- Pure parts.
	HOST_Check(TRF_LadBandOf(0) == 1 and TRF_LadBandOf(2) == 1 and TRF_LadBandOf(3) == 2 and TRF_LadBandOf(5) == 3 and TRF_LadBandOf(6) == 4
		and TRF_LadBandOf(9) == 7, "bands 0-2, 3, 4-5, 6, 7, 8, 9");
	HOST_Check(TRF_LadPriceOf(1200, 15, 5, 1, 6) == 22500 and TRF_LadPriceOf(1200, 10, 5, 1, 5) == 15000 and TRF_LadPriceOf(1200, 16, 6, 1, 8) == 18720
		and TRF_LadPriceOf(1200, 10, 5, 0.7, 5) == 10500, "permit price: 22500 (design 2), 15000 mid, discount 0.75 at rank 8, d_k HARD");
	HOST_Check(TRF_LadSettleOf(4000, 10, 2, 1) == 80000 and TRF_LadSettleOf(4000, 16, 2, 1) == 128000 and TRF_LadSettleOf(4000, 10, 4, 1) == 0,
		"settlement: 80000 mid at fst 2, 128000 late, none above 3");
	HOST_Check(TRF_LadHandKindOf("PirateTough", 3, Pir_Pilots, Vks_Pilots, Kfni_Pilots) == "pirate" and TRF_LadHandKindOf("KfniAce", 1, Pir_Pilots, Vks_Pilots, Kfni_Pilots) == "pow"
		and TRF_LadHandKindOf("VksAce", 2, Pir_Pilots, Vks_Pilots, Kfni_Pilots) == "pow" and TRF_LadHandKindOf("KfniAce", 3, Pir_Pilots, Vks_Pilots, Kfni_Pilots) == nil
		and TRF_LadHandKindOf("VksAce", 1, Pir_Pilots, Vks_Pilots, Kfni_Pilots) == nil, "hand-in kinds: pirate anywhere, prisoners of war only between the empires");
	local nk = 0;
	for k, v in TRF_Lad_Text() do if strfind(k, "^ladrank") then nk = nk + 1; end; end;
	HOST_Check(nk == 35, "35 rank keys");
end;

-- b: offer gates, one ladder box per docking ----------------------------------------------------------

function T_LAD_B()
	local h = HOST();
	L_Begin("fort_russ", "4_1");
	local n0 = S_Mark();
	local r = L_Dock();
	HOST_Check(L_Has(r.scr, "MSF standing: Civilian, no file (5).") and r.nb == 0 and S_Logs(n0, "reason=chapter") == 1, "chapter 4: rank line only");
	h.labels.CurrentQuest = "9_1";
	T_Enter("fort_russ");
	local slot = L_Slot("fort_russ");
	-- Rank: fst 3 has an open file (settlement), fst 4 the permit.
	L_Fst(1, 3);
	r = L_Dock();
	HOST_Check(r.nb == 1 and L_Has(r.box.text, "MSF Sector Command, Moscowia:\nYour file shows open violations. Settle for 60000 cr"), "fst 3: settlement box ("..tostring(r.box and r.box.text)..")");
	L_Press(r, "cancel");
	HOST_Check(h.pdlgs[getn(h.pdlgs)] == "" and r.nd == 0, "vanilla dialog after the answer");
	L_Fst(1, 4);
	n0 = S_Mark();
	r = L_Dock();
	HOST_Check(r.nb == 1 and r.box.text == "MSF Sector Command, Moscowia:\nTransit permit for MSF space in this sector, 24 legs: 18900 cr. The New Empire keeps lists of who carries our papers."
		and S_Logs(n0, "event=permit_offer faction=Vks standing=4 region="..slot.." level=15 prosperity=1 difficulty_k=1.000 price=18900 legs=24 result=offered") == 1,
		"fst 4: permit box, c_p x L_rg 15 x (1 + 0.05 R 1) x d_k ("..tostring(r.box and r.box.text)..")");
	L_Press(r, "cancel");
	n0 = S_Mark();
	r = L_Dock();
	HOST_Check(r.nb == 0 and r.nd == 1 and S_Logs(n0, "reason=declined") == 1, "declined offer not shown again this visit");
	-- Strict gate (a mission runs, strict 2): rank line only.
	T_Enter("fort_russ");
	h.cfg.strict = 2; h.qs = TRUE;
	n0 = S_Mark();
	r = L_Dock();
	HOST_Check(L_Has(r.scr, "MSF standing:") and r.nb == 0 and S_Logs(n0, "reason=gate:mission_all") == 1, "strict gate: rank line, no box");
	h.cfg.strict = nil; h.qs = FALSE;
	-- Corporation: no permit.
	T_Enter("golkonda");
	n0 = S_Mark();
	r = L_Dock();
	HOST_Check(r.nb == 0 and S_Logs(n0, "event=permit_offer faction=Triada standing=5 region="..L_Slot("golkonda").." result=none reason=corporation") == 1, "corporations sell no permit");
	-- A valid permit for this region: status, no offer.
	T_Enter("fort_russ");
	TRF.std.fst = "55555";
	L_Lic(1, slot, 5);
	n0 = S_Mark();
	r = L_Dock();
	HOST_Check(L_Has(r.scr, "MSF standing: Civilian, no file (5). Permit valid 5 more legs.|") and r.nb == 0 and S_Logs(n0, "reason=valid") == 1
		and S_Logs(n0, "status=permit permit_legs_left=5") == 1, "valid permit: legs left, no offer");
	-- Rival gate: MSF papers at a NESF station.
	T_Enter("llanovar1");
	n0 = S_Mark();
	r = L_Dock();
	HOST_Check(L_Has(r.scr, "NESF standing: Civilian, no file (5)") == nil and L_Has(r.scr, "NESF standing: Unregistered (5). You fly under MSF papers. The NESF has nothing for you.|")
		and r.nb == 0 and S_Logs(n0, "reason=rival") == 1, "rival papers: line, nothing offered ("..r.scr..")");
	-- Same region, never transferred (Angarsk, Kfni since the start): the rival line, not the void line.
	T_Enter("angarsk");
	r = L_Dock();
	HOST_Check(L_Has(r.scr, "NESF standing: Unregistered (5). You fly under MSF papers. The NESF has nothing for you.|") and r.nb == 0,
		"untransferred NESF system in the permit's region: rival line ("..r.scr..")");
	-- Void: Moscowia moved to the New Empire; the MSF permit of the region does not apply there.
	h.teams.moscowia = "Kfni";
	T_Enter("moscowia");
	r = L_Dock();
	HOST_Check(L_Has(r.scr, "NESF standing: Unregistered (5). MSF papers? This is New Empire space now.|") and r.nb == 0, "transferred system: void line ("..r.scr..")");
	h.teams.moscowia = "Vks";
	TRF.lad = nil;
	-- One ladder box per docking: the 8.10 prio 400 box wins; a lower candidate is not asked after the ladder box.
	T_Enter("fort_russ");
	TRF_DockBox("patrol", 400, "L_Box400");
	n0 = S_Mark();
	r = L_Dock();
	HOST_Check(r.nb == 1 and r.box.text == "L offer 400" and S_Logs(n0, "module=ladder event=permit_offer") == 0, "8.10 box above the ladder box: ladder not asked");
	L_Press(r, "ok");
	T_Enter("fort_russ");
	TRF_DockBox("patrol", 200, "L_Box200");
	h.lb200 = nil;
	r = L_Dock();
	HOST_Check(r.nb == 1 and L_Has(r.box.text, "Transit permit") and h.lb200 == nil, "one box per docking: the ladder box, the prio 200 box not asked");
	local nb0, np0 = getn(h.boxes), getn(h.pdlgs);
	L_Press(r, "cancel");
	HOST_Check(getn(h.pdlgs) == np0 + 1 and h.pdlgs[getn(h.pdlgs)] == "" and getn(h.boxes) == nb0 and h.lb200 == nil,
		"vanilla once after the answer, no further box");
	-- Flags: no line, no box, vanilla at once.
	T_Enter("fort_russ");
	__sys_SOS = TRUE;
	r = L_Dock();
	HOST_Check(not L_Has(r.scr, "standing:") and r.nb == 0 and r.nd == 1, "__sys_SOS: nothing from the ladder");
	__sys_SOS = FALSE;
	__disableAction = TRUE;
	r = L_Dock();
	HOST_Check(not L_Has(r.scr, "standing:") and r.nb == 0 and r.nd == 1, "__disableAction: nothing from the ladder");
	__disableAction = FALSE;
	-- Toggles.
	h.cfg.lad_permit = 0;
	n0 = S_Mark();
	r = L_Dock();
	HOST_Check(L_Has(r.scr, "standing:") and r.nb == 0 and S_Logs(n0, "reason=off") == 1, "lad_permit 0: no permit box");
	h.cfg.lad_permit = nil; h.cfg.lad_rankline = 0;
	r = L_Dock();
	HOST_Check(not L_Has(r.scr, "standing:") and r.nb == 1, "lad_rankline 0: no line, the box stays");
	L_Press(r, "cancel");
	h.cfg.lad_rankline = nil; h.cfg.lad_enabled = 0;
	T_Enter("fort_russ");
	r = L_Dock();
	HOST_Check(not L_Has(r.scr, "standing:") and r.nb == 0 and TRF_Lad_Hold(1) == nil and TRF_Lad_Cap(2) == nil, "lad_enabled 0: nothing");
	h.cfg.lad_enabled = nil;
end;

-- c: purchase, rival cap, hold, expiry -----------------------------------------------------------------

function T_LAD_C()
	local h = HOST();
	L_Begin("fort_russ");
	local slot = L_Slot("fort_russ");
	local L0 = TRF.clock.legs;
	h.credits = 100000;
	local n0 = S_Mark();
	local r = L_Dock();
	local s = L_Press(r, "ok");
	HOST_Check(h.credits == 81100 and TRF.lad.lic[1][slot] == L0 + 24 and TRF_Fst(1) == 6 and TRF_Fst(2) == 4 and TRF.lad.pg[1] == L0,
		"bought: 18900 cr, valid 24 legs, MSF +1 (5 -> 6), NESF -1 (5 -> 4), stamp ("..h.credits.." "..TRF.std.fst..")");
	HOST_Check(L_Has(s, "Permit issued. Moscowia sector, valid 24 legs.|NESF standing capped at 4 while you carry MSF papers.|")
		and h.pdlgs[getn(h.pdlgs)] == "", "issue line, then the cap line, then the vanilla dialog ("..s..")");
	HOST_Check(S_Logs(n0, "event=permit_buy faction=Vks region="..slot.." price=18900 credits=100000 till="..(L0 + 24).." standing_before=5 standing_after=6 gain=gained rival=Kfni rival_before=5 rival_after=4 voided_count=0 result=bought") == 1,
		"permit_buy log line");
	-- Rival cap: NESF gains stop at 4 while the MSF permit is valid.
	n0 = S_Mark();
	TRF_FstAdd(2, 3, "test");
	HOST_Check(TRF_Fst(2) == 4 and S_Logs(n0, "faction=Kfni reason=test standing_before=4 standing_after=4 result=capped") == 1, "rival capped at 4 (result=capped)");
	-- Rank-6 hold: 7 decays to 6 under the permit and stays; the rival's drift stays at the cap.
	TRF.std.fst = "74555";
	TRF_Faction_Tick(1000);
	HOST_Check(TRF.std.fst == "64555", "decay 7 -> 6 under the permit, rival 4 stays ("..TRF.std.fst..")");
	TRF_Faction_Tick(1010);
	TRF_Faction_Tick(1020);
	HOST_Check(TRF.std.fst == "64555", "hold: 6 stays under the permit ("..TRF.std.fst..")");
	-- Second purchase within permit_legs (another region): no gain; at rank 6 no gain either.
	TRF.std.fst = "55555";
	T_Enter("altair");
	local s5 = L_Slot("altair");
	h.credits = 100000;
	r = L_Dock();
	n0 = S_Mark();
	L_Press(r, "ok");
	HOST_Check(h.credits == 100000 - 21120 and TRF.lad.lic[1][s5] ~= nil and TRF_Fst(1) == 5 and S_Logs(n0, "gain=cooldown") == 1,
		"second permit within 24 legs (Kadi, L 16, R 2: 21120): no gain ("..h.credits..")");
	TRF.lad.pg[1] = TRF.clock.legs - 24;
	TRF.lad.lic[1][s5] = nil;
	L_Fst(1, 6);
	T_Enter("altair");
	r = L_Dock();
	n0 = S_Mark();
	L_Press(r, "ok");
	HOST_Check(TRF_Fst(1) == 6 and S_Logs(n0, "gain=cap") == 1, "never above rank_hold 6");
	-- Poor: nothing bought.
	TRF.lad.lic[1][s5] = nil;
	T_Enter("altair");
	h.credits = 100;
	r = L_Dock();
	n0 = S_Mark();
	s = L_Press(r, "ok");
	HOST_Check(L_Has(s, "Not enough credits.") and TRF.lad.lic[1][s5] == nil and h.credits == 100 and S_Logs(n0, "result=poor") == 1, "too poor: nothing bought");
	-- Stale answer: a box carried over a load buys nothing.
	T_Enter("altair");
	h.credits = 100000;
	r = L_Dock();
	T_SaveLoad();
	n0 = S_Mark();
	HOST_Press("ok", r.box);
	HOST_Check(h.credits == 100000 and TRF.lad.lic[1][s5] == nil and S_Logs(n0, "event=permit_buy result=stale") == 1, "answer after a load: stale, nothing bought");
	-- Void on purchase (a permit of the other empire the rival gate does not show): voided, no refund, -1 then the cap.
	TRF.lad.lic[2] = {[L_Slot("llanovar1")] = TRF.clock.legs + 10};
	TRF.std.fst = "59555";
	n0 = S_Mark();
	TRF_LadBuy({f=1, s=slot, p=0, g=TRF.gen});
	HOST_Check(TRF.lad.lic[2] == nil and TRF_Fst(2) == 4 and S_Logs(n0, "rival_before=9 rival_after=4 voided_count=1 result=bought") == 1,
		"other empire's permits void, rival 9 -> 8 -> capped 4 ("..TRF.std.fst..")");
	-- Expiry: stripped at the docking, decay resumes.
	T_Enter("fort_russ");
	TRF.lad.lic[1][s5] = nil;
	TRF.std.fst = "64555";
	TRF.clock.legs = TRF.lad.lic[1][slot];
	n0 = S_Mark();
	r = L_Dock();
	HOST_Check(L_Has(r.scr, "MSF standing: Licensed carrier (6). No permit on file.|") and S_Logs(n0, "event=permit_expire faction=Vks region="..slot) == 1
		and TRF.lad.lic == nil, "expired at its till leg: stripped, no permit on file");
	L_Press(r, "cancel");
	TRF_Faction_Tick(1030);
	HOST_Check(TRF.std.fst == "55555", "after expiry: 6 -> 5, rival 4 -> 5 ("..TRF.std.fst..")");
end;

-- d: settlement with cooldown ---------------------------------------------------------------------------

function T_LAD_D()
	local h = HOST();
	L_Begin("fort_russ");
	h.credits = 200000;
	L_Fst(1, 2);
	local n0 = S_Mark();
	local r = L_Dock();
	HOST_Check(r.nb == 1 and L_Has(r.box.text, "Settle for 120000 cr and we close it."), "fst 2: c_s 4000 x L_rg 15 x (4 - 2) = 120000");
	local s = L_Press(r, "ok");
	HOST_Check(TRF_Fst(1) == 4 and h.credits == 80000 and TRF.lad.sc[1] == TRF.clock.legs and L_Has(s, "File closed. Do not make us open it again.|")
		and S_Logs(n0, "event=settle faction=Vks region="..L_Slot("fort_russ").." price=120000 credits=200000 standing_before=2 standing_after=4 result=paid") == 1,
		"settled: fst := 4, stamp, line");
	-- Cooldown settle_cd 20 legs.
	L_Fst(1, 3);
	T_Enter("fort_russ");
	n0 = S_Mark();
	r = L_Dock();
	HOST_Check(r.nb == 1 and L_Has(r.box.text, "Transit permit for MSF space") and S_Logs(n0, "event=settle faction=Vks standing=3 region="..L_Slot("fort_russ").." price=60000 result=none reason=cooldown") == 1,
		"cooldown: no settlement, the permit box instead");
	L_Press(r, "cancel");
	L_Legs(20);
	T_Enter("fort_russ");
	L_Fst(1, 3);
	r = L_Dock();
	HOST_Check(r.nb == 1 and L_Has(r.box.text, "Settle for 60000 cr"), "20 legs later: offered again at fst 3");
	h.credits = 10;
	s = L_Press(r, "ok");
	HOST_Check(TRF_Fst(1) == 3 and L_Has(s, "Not enough credits."), "poor: fst unchanged");
	-- Corporation: Triada settles too (L_rg 11 in the Golkonda region).
	T_Enter("golkonda");
	h.credits = 500000;
	L_Fst(3, 1);
	r = L_Dock();
	HOST_Check(r.nb == 1 and L_Has(r.box.text, "Triada Sector Command, Golkonda:\nYour file shows open violations. Settle for 132000 cr"), "Triada settlement (4000 x 11 x 3)");
	L_Press(r, "ok");
	HOST_Check(TRF_Fst(3) == 4 and h.credits == 368000, "Triada settled");
	-- War: nothing.
	L_Legs(20);
	L_Rel("Triada", RELATION_WAR);
	T_Enter("golkonda");
	L_Fst(3, 1);
	r = L_Dock();
	HOST_Check(r.nb == 0 and L_Has(r.scr, "Triada standing: Marked by the families (1).|"), "war: no settlement");
	h.rel_team = nil;
	h.cfg.lad_settle = 0;
	T_Enter("golkonda");
	n0 = S_Mark();
	r = L_Dock();
	HOST_Check(r.nb == 0 and S_Logs(n0, "reason=off") == 1, "lad_settle 0: no settlement");
	h.cfg.lad_settle = nil;
end;

-- e: hand-in standing and prisoners of war through CostOfHead ---------------------------------------------

function T_LAD_E()
	local h = HOST();
	L_Begin("fort_russ");
	local r = L_Dock();
	L_Press(r, "cancel");
	local n0 = S_Mark();
	local s0 = getn(h.screen);
	local p = CostOfHead("PirateTough", 2);
	HOST_Check(p == 800 and TRF_Fst(1) == 6 and TRF.lad.hc[1] == TRF.clock.legs and S_Screen(s0, "Imperial Security notes your service. MSF standing: Licensed carrier (6).")
		and S_Logs(n0, "event=handin system=fort_russ faction=Vks pilot=PirateTough count=2 price=800 kind=pirate standing_before=5 standing_after=6 rival=nil rival_before=nil rival_after=nil result=credited") == 1,
		"pirate pods: vanilla price passed through, MSF +1, line");
	n0 = S_Mark();
	p = CostOfHead("PirateRookie", 1);
	HOST_Check(p == 200 and TRF_Fst(1) == 6 and S_Logs(n0, "reason=docking") == 1, "second template in the same docking: no second gain");
	r = L_Dock();
	L_Press(r, "cancel");
	n0 = S_Mark();
	CostOfHead("PirateTough", 1);
	HOST_Check(TRF_Fst(1) == 6 and S_Logs(n0, "result=none reason=cooldown") == 1, "next docking inside lad_hand_cd: cooldown");
	L_Legs(10);
	r = L_Dock();
	L_Press(r, "cancel");
	CostOfHead("PirateCaptain", 1);
	HOST_Check(TRF_Fst(1) == 7, "10 legs later: +1 (7)");
	L_Legs(10);
	r = L_Dock();
	L_Press(r, "cancel");
	n0 = S_Mark();
	CostOfHead("PirateCaptain", 1);
	HOST_Check(TRF_Fst(1) == 7 and S_Logs(n0, "reason=cap") == 1, "hand_cap 7");
	-- Own pilots pay 0: nothing.
	n0 = S_Mark();
	HOST_Check(CostOfHead("VksPilot", 1) == 0 and S_Logs(n0, "module=ladder") == 0, "own pilots: price 0, no ladder line");
	-- Prisoners of war: NESF pilots at an MSF station.
	TRF.std.fst = "55555";
	L_Legs(10);
	r = L_Dock();
	L_Press(r, "cancel");
	n0 = S_Mark();
	p = CostOfHead("KfniOfficer", 1);
	HOST_Check(p == 800 and TRF.std.fst == "64555" and S_Logs(n0, "kind=pow standing_before=5 standing_after=6 rival=Kfni rival_before=5 rival_after=4 result=credited") == 1,
		"prisoners of war: MSF +1, NESF -1 ("..TRF.std.fst..")");
	T_Enter("llanovar1");
	TRF.std.fst = "64555";
	r = L_Dock();
	L_Press(r, "cancel");
	CostOfHead("VksAce", 1);
	HOST_Check(TRF.std.fst == "55555", "MSF pilots at a NESF station: NESF +1, MSF -1 ("..TRF.std.fst..")");
	-- Rival cap: MSF papers hold NESF at 4; a hand-in at a NESF station gains nothing, stamps nothing, costs MSF nothing.
	L_Legs(10);
	L_Lic(1, L_Slot("fort_russ"), 10);
	TRF.std.fst = "64555";
	r = L_Dock();
	L_Press(r, "cancel");
	local hc2 = TRF.lad.hc[2];
	n0 = S_Mark();
	CostOfHead("VksAce", 1);
	HOST_Check(TRF.std.fst == "64555" and TRF.lad.hc[2] == hc2 and S_Logs(n0, "event=handin system=llanovar1 faction=Kfni pilot=VksAce count=1 price=1800 kind=pow standing=4 result=none reason=cap") == 1,
		"rival cap: no credit, no stamp, no prisoner cost ("..TRF.std.fst..")");
	TRF.lad.lic = nil;
	-- Chapter 4: read-only, no credit.
	h.labels.CurrentQuest = "4_1";
	T_Enter("golkonda");
	r = L_Dock();
	L_Press(r, "cancel");
	n0 = S_Mark();
	local v4 = TRF_Fst(3);
	CostOfHead("PirateTough", 1);
	HOST_Check(TRF_Fst(3) == v4 and S_Logs(n0, "event=handin system=golkonda faction=Triada pilot=PirateTough count=1 price=800 standing="..v4.." result=none reason=chapter") == 1,
		"chapter 4: no hand-in credit");
	h.labels.CurrentQuest = "9_1";
	-- Corporation: pirates at a Triada station.
	T_Enter("golkonda");
	r = L_Dock();
	L_Press(r, "cancel");
	CostOfHead("PirateTough", 1);
	HOST_Check(TRF_Fst(3) == 6, "pirates at Triada: Triada +1");
	-- War: no credit; deny: none; toggle.
	L_Legs(10);
	L_Rel("Triada", RELATION_WAR);
	r = L_Dock();
	L_Press(r, "cancel");
	n0 = S_Mark();
	CostOfHead("PirateTough", 1);
	HOST_Check(TRF_Fst(3) == 6 and S_Logs(n0, "reason=war") == 1, "war: no credit");
	h.rel_team = nil;
	T_Enter("fronn");
	r = L_Dock();
	L_Press(r, "cancel");
	n0 = S_Mark();
	local v3 = TRF_Fst(3);
	CostOfHead("PirateTough", 1);
	HOST_Check(TRF_Fst(3) == v3 and S_Logs(n0, "reason=deny") == 1, "denied system: no credit");
	T_Enter("golkonda");
	h.cfg.lad_handin = 0;
	r = L_Dock();
	L_Press(r, "cancel");
	n0 = S_Mark();
	v3 = TRF_Fst(3);
	CostOfHead("PirateTough", 1);
	HOST_Check(TRF_Fst(3) == v3 and S_Logs(n0, "event=handin") == 0, "lad_handin 0: nothing");
	h.cfg.lad_handin = nil;
end;

-- f: portal-fine waiver and the relation-reset sync --------------------------------------------------------

function T_LAD_F()
	local h = HOST();
	L_Begin("altair");
	local s5 = L_Slot("altair");
	L_Patrol("Vks");
	h.credits = 100000;
	local b0 = getn(h.boxes);
	local n0 = S_Mark();
	_PatrolGIBDD_shtraf();
	HOST_Check(h.credits == 90000 and getn(h.boxes) == b0 + 1 and HOST_Box().title == "#UI_PatrolGIBDD_confirm"
		and S_Logs(n0, "event=gibdd_waive system=altair faction=Vks region="..s5.." credits=100000 result=fined reason=none") == 1, "no permit: the vanilla fine (10 %)");
	HOST_Press("ok");
	-- A permit of another region: the region line, then the fine.
	L_Lic(1, L_Slot("fort_russ"), 10);
	h.credits = 100000;
	local s0 = getn(h.screen);
	n0 = S_Mark();
	_PatrolGIBDD_shtraf();
	HOST_Check(h.credits == 90000 and S_Screen(s0, "Permit for the Moscowia sector only. Pay up.") and S_Logs(n0, "result=fined reason=region") == 1, "permit for Moscowia only: fined");
	HOST_Press("ok");
	-- Valid permit for this region: waived through the vanilla exit.
	L_Lic(1, s5, 10);
	h.credits = 100000;
	h.prava = 0;
	b0 = getn(h.boxes);
	local m0 = getn(h.msgs);
	local t0 = getn(h.tseq or {});
	n0 = S_Mark();
	_PatrolGIBDD_shtraf();
	HOST_Check(h.credits == 100000 and getn(h.boxes) == b0 and h.prava == 1 and getn(h.msgs) == m0 + 1 and h.msgs[getn(h.msgs)].t == "Permit on file. Move along, and keep the portal clear."
		and getn(h.tseq) == t0 + 1 and S_Logs(n0, "event=gibdd_waive system=altair faction=Vks region="..s5.." credits=100000 credits_after=100000 till=") == 1,
		"permit valid: no fine, the leader's line, _PatrolGIBDD_prava (its own Timer_Seq)");
	-- __sys_SOS and the player having left: the original's prava path, no ladder decision.
	__sys_SOS = TRUE;
	t0 = getn(h.tseq);
	n0 = S_Mark();
	_PatrolGIBDD_shtraf();
	HOST_Check(h.credits == 100000 and getn(h.tseq) == t0 + 1 and h.tseq[getn(h.tseq)].t == 10 and h.prava == 1 and S_Logs(n0, "event=gibdd_waive") == 0,
		"__sys_SOS: the original (Timer_Seq 10 to prava)");
	__sys_SOS = FALSE;
	_f_PatrolGIBDD = 1;
	_PatrolGIBDD_shtraf();
	HOST_Check(h.tseq[getn(h.tseq)].t == 6 and h.prava == 1, "player moved away: the original (Timer_Seq 6)");
	_f_PatrolGIBDD = 0;
	-- War: fined.
	L_Rel("Vks", RELATION_WAR);
	n0 = S_Mark();
	_PatrolGIBDD_shtraf();
	HOST_Check(h.credits == 90000 and S_Logs(n0, "reason=war") == 1, "war: fined");
	HOST_Press("ok");
	h.rel_team = nil;
	h.cfg.lad_gibdd = 0;
	h.credits = 100000;
	_PatrolGIBDD_shtraf();
	HOST_Check(h.credits == 90000, "lad_gibdd 0: fined");
	HOST_Press("ok");
	h.cfg.lad_gibdd = nil;
	-- Kfni system with a Kfni permit.
	T_Enter("llanovar1");
	L_Patrol("Kfni");
	TRF.lad = nil;
	L_Lic(2, L_Slot("llanovar1"), 5);
	h.credits = 100000;
	h.prava = 0;
	_PatrolGIBDD_shtraf();
	HOST_Check(h.credits == 100000 and h.prava == 1, "NESF permit in a NESF system: waived");
	TRF.lad = nil;
	-- Reset sync: a paid reset (650000) with the relation W: fst max(fst, 4).
	TRF.std.fst = "11555";
	L_Rel("Vks", RELATION_WAR);
	h.credits = 1000000;
	_param = "3";
	n0 = S_Mark();
	_temp_change("Vks");
	HOST_Check(h.credits == 350000 and TRF_Fst(1) == 4 and S_Logs(n0, "event=reset_sync faction=Vks name=Vks paid=650000 standing_before=1 standing_after=4 result=synced") == 1,
		"paid reset: relation no longer W, fst 1 -> 4");
	-- Free reset (tip 1): nothing.
	L_Rel("Kfni", RELATION_WAR);
	_param = "1";
	n0 = S_Mark();
	_temp_change("Kfni");
	HOST_Check(TRF_Fst(2) == 1 and S_Logs(n0, "paid=0 standing_before=1 standing_after=1 result=free") == 1, "free reset: fst unchanged");
	-- Below reset_min_paid, still at war, at 4 or above, toggle off (direct calls).
	n0 = S_Mark();
	TRF_Lad_ResetSync(2, "Kfni", 200000, 100001);
	HOST_Check(TRF_Fst(2) == 1 and S_Logs(n0, "paid=99999 standing_before=1 standing_after=1 result=free") == 1, "99999 paid: below reset_min_paid");
	L_Rel("Kfni", RELATION_WAR);
	TRF_Lad_ResetSync(2, "Kfni", 900000, 0);
	HOST_Check(TRF_Fst(2) == 1 and S_Logs(n0, "result=war") == 1, "relation still W: no sync");
	h.rel_team = nil;
	L_Fst(3, 6);
	TRF_Lad_ResetSync(3, "Triada", 900000, 0);
	HOST_Check(TRF_Fst(3) == 6 and S_Logs(n0, "result=kept") == 1, "fst 6: kept");
	h.cfg.lad_reset_sync = 0;
	TRF_Lad_ResetSync(2, "Kfni", 900000, 0);
	HOST_Check(TRF_Fst(2) == 1 and S_Logs(n0, "result=off") == 1, "lad_reset_sync 0: no sync, the v1 rule does not run");
	h.cfg.lad_reset_sync = nil;
	_param = nil;
end;

-- g: dump, save/load, repair, TRF.lad at its bound -------------------------------------------------------

function T_LAD_G()
	local h = HOST();
	L_Begin("fort_russ");
	local slot = L_Slot("fort_russ");
	local L = TRF.clock.legs;
	TRF.std.fst = "73555";
	TRF.lad = {lic={[1]={[slot]=L + 5}}, pg={L}, hc={L, nil, L}, sc={nil, L}};
	local r = L_Dock();
	L_Press(r, "cancel");
	local n0 = S_Mark();
	TRF_DumpState("test");
	HOST_Check(S_Logs(n0, "module=ladder event=dump faction=Vks standing=7 band=5 war=false permits="..slot..":"..(L + 5).." permit_gain_leg="..L.." handin_leg="..L.." settle_leg=nil") == 1
		and S_Logs(n0, "module=ladder event=dump faction=Kfni standing=3 band=2 war=false permits=nil permit_gain_leg=nil handin_leg=nil settle_leg="..L) == 1
		and S_Logs(n0, "module=ladder event=dump_state escort_ban_leg=nil warrant=nil warrant_next_leg=nil warrant_real_seconds=nil patron=nil docking_count=1 credited=nil declined=") == 1,
		"dump lines (one per faction, the step 2 fields, the visit flags)");
	-- Save/load: the permit stays, the visit state starts again.
	T_SaveLoad();
	HOST_Check(TRF.lad.lic[1][slot] == L + 5 and TRF_LadLV().dk == 0, "load: permits kept, visit state reset");
	r = L_Dock();
	HOST_Check(L_Has(r.scr, "Permit valid 5 more legs."), "after the load: the permit counts");
	-- Repair.
	TRF.lad = {lic={[1]={[slot]=L + 999, [99]=L, x=1}, [2]="x", [3]={[1]=L}}, pg={"a", L + 9}, hc={L, L, L, L, L, L}, sc=7, eb="x",
		w={f=9, sys=1, till=1, n=1}, wc=L, wr=-1, pat=3, junk=1};
	TRF_Repair();
	local R = TRF.lad;
	HOST_Check(R.lic[1][slot] == L + 24 and R.lic[1][99] == nil and R.lic[2] == nil and R.lic[3] == nil and R.pg[1] == nil and R.pg[2] == L
		and R.hc[5] == L and R.hc[6] == nil and R.sc == nil and R.eb == nil and R.w == nil and R.wc == L and R.wr == nil and R.pat == 3 and R.junk == nil,
		"repair: bounds, stamps clamped to the current leg, step 2 fields kept when valid");
	TRF.lad = 7;
	TRF_Repair();
	HOST_Check(TRF.lad == nil, "repair: a non-table TRF.lad becomes absent");
	TRF_Repair();
	HOST_Check(TRF.lad == nil, "repair leaves an absent TRF.lad absent");
	-- Worst case (spec 3.3): 2 x 11 permits, every stamp, the step 2 fields.
	local big = 99999;
	TRF.lad = {lic={{}, {}}, pg={big, big}, hc={big, big, big, big, big}, sc={big, big, big, big, big}, eb=big,
		w={f=5, sys=113, till=big, n=4}, wc=big, wr=999999.5, pat=5};
	for k = 1, 11 do TRF.lad.lic[1][k] = big; TRF.lad.lic[2][k] = big; end;
	local sz = HOST_SaveSize(TRF.lad) + 8 + strlen("lad");
	print("HOST info TRF.lad worst case "..sz.." bytes");
	HOST_Check(sz <= 1200, "TRF.lad at its bound: "..sz.." bytes <= 1200 (spec 3.3)");
	HOST_Check(HOST_Reserved(TRF, "TRF") == "", "no reserved key in TRF");
	TRF.lad = nil;
end;

-- Dispatch ---------------------------------------------------------------------------------

local sc = getenv("TRF_LAD") or "";
local fn = getglobal("T_LAD_"..strupper(sc));
print("HOST ==== faction ladder scenario lad-"..sc.." dir="..HOST().dir);
if type(fn) == "function" then
	fn();
	HOST_Check(T_LeftGlobals() == "", "no handle globals left at the end"..T_LeftGlobals());
else
	HOST_Check(nil, "unknown faction ladder scenario "..sc);
end;
HOST_Check((HOST().gpm_tick or 0) == 0, "no GetPlayerMotherShip from a tick (n="..tostring(HOST().gpm_tick or 0)..")");
print("HOST errors="..HOST().errors.." fails="..HOST().fails);
if HOST().errors > 0 or HOST().fails > 0 then exit(1); end;
exit(0);
