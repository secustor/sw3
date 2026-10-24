-- Hail stage B pages and combat hail scenarios (design/hail-spec.md 9) under stock Lua 4.0.1: TRF_HL=a..e, run by
-- run_host.sh as its own entry point. a the stage B pages (hail_box 2: answer page, Back with the used option hidden,
-- Close, Esc frees the lock, escort and provider offer pages with Accept and Decline, a last option without Back, the
-- box fallback, hail_box 1 unchanged); b the busy answer (hostiles near without a raid record, the escort flight in a
-- fight, the box and line forms, TRF_Combat, cfg hail_fight 0, an armed raid); c the help offer without a raid record
-- (outnumbered: Decline, once per visit, Accept then pay with player fire, Accept without fire, the prize gap, the box
-- fallback); d the help offer on a raid record (comply, flee, strength ratio below 1, ratio above 1: busy; Accept then
-- the raid-help pay with one player hit, Accept without fire); e the data model (byte figure of hlp, dump, load and
-- jump settle).
-- Loads host_station.lua up to its first scenario, as host_demand.lua does. TRF_Carcasses = HOST_Carcasses with
-- HOST().carc in b..e (trf_plumb's TRF_Near on the typed path).

local f = openfile((getenv("TRF_TESTS") or "./").."host_station.lua", "r");
if not f then print("HOST FAIL host_hail.lua: cannot open host_station.lua"); exit(1); end;
local src = read(f, "*a");
closefile(f);
local cut = strfind(src, "\n-- a: install (12.1, 6.1)", 1, 1);
if not cut then print("HOST FAIL host_hail.lua: marker '-- a: install (12.1, 6.1)' missing in host_station.lua"); exit(1); end;
dostring(strsub(src, 1, cut), "host_station.lua");

-- Helpers ----------------------------------------------------------------------------------

-- Config of these runs: entry events and modules that spawn ships or claim the box off, escort contracts on, no
-- escort flight (b sets one by hand), log 2.
function HL_Cfg(t)
	local c = {sweeps=0, sweep_ct=0, feq=0, staged=0, seed=0, queue=0, parked=0, voice_events=0, dconv=0, raids=0,
		carriers=0, po=0, bases=0, conv=0, enable_survivors=0, lad_enabled=0, charter=0, enable_scars=0, contracts=1,
		esc_flight=0, demand=0, log=2};
	if t then for k, v in t do c[k] = v; end; end;
	return c;
end;

function HL_Begin(t)
	local h = HOST();
	h.labels.CurrentQuest = "5_1";
	h.st_label = nil;
	S_Begin("gredos", HL_Cfg(t));
	h.credits = 1000000;
	__sys_FTrader_3 = 0;
end;

-- Dialog mode on (tune hail_box 2, hail_xml 1, an idle UI) or off.
function HL_Dlg(on)
	local h = HOST();
	if on then
		h.cfg.tune = {hail_box=2};
		h.cfg.hail_xml = 1;
		TRF_UiState = HOST_UiState;
		h.ui = 0;
	else
		h.cfg.tune = nil;
		h.cfg.hail_xml = nil;
		TRF_UiState = nil;
		h.ui = nil;
	end;
end;

-- A fresh trader 40 from the mothership (other traders removed, heat 0, escort offer rolled yes), path B or A (path
-- given: that one): id, record, handles.
function HL_Trader(path)
	local h = HOST();
	V_ClearTr();
	T_Tick(2, 0.5);
	TRF.std.heat = 0;
	TRF.live.cbt = nil;
	local id = nil;
	if path then id = T_Spawn(path); else id = T_Spawn("B") or T_Spawn("A"); end;
	T_MoveTr(id, h.ms.pos.x + 40, h.ms.pos.y, h.ms.pos.z);
	local r = TRF.live.tr[id];
	r.co = 1;
	r.br = 0.2;
	return id, r, TRF_H().tr[id];
end;

-- Position of the trader lead as {x, y, z}.
function HL_Lp(id)
	local p = TRF_HlLead(id):GetPosition();
	return {x=p.x, y=p.y, z=p.z};
end;

-- Kills the escorts of handle record x (ships that are not transports).
function HL_NoEscorts(x)
	for i = 1, getn(x.sh) do
		local tp = nil;
		for j = 1, getn(x.tp) do if x.tp[j] == x.sh[i] then tp = 1; end; end;
		if not tp then x.sh[i].alive = nil; end;
	end;
end;

-- Object list of the location for TRF_Carcasses: n pirate fighters dx from the lead of id (uids 9001..; odd ones on
-- the +x side, even ones on the -x side, so a ship 50 from 9001 is more than 600 from 9002), plus extra.
function HL_Pirates(id, n, dx, extra)
	local p = HL_Lp(id);
	local l = {};
	for i = 1, n do
		local sx = dx or 300;
		if floor(i / 2) * 2 == i then sx = -sx; end;
		tinsert(l, {id=9000 + i, cls=3, tpl="pir_fighter", team="Pirates", hp=500, hpmax=500, x=p.x + sx, y=p.y, z=p.z + 10 * i, pl=0});
	end;
	if extra then for i = 1, getn(extra) do tinsert(l, extra[i]); end; end;
	HOST().carc = l;
	TRF_Carcasses = HOST_Carcasses;
	return l;
end;

-- Removes the record of uid u from HOST().carc (the ship died).
function HL_Kill(u)
	local q, o = HOST().carc or {}, {};
	for i = 1, getn(q) do if q[i].id ~= u then tinsert(o, q[i]); end; end;
	HOST().carc = o;
end;

-- A player fighter record 50 from the record c.
function HL_PlNear(c)
	return {id=8001, cls=3, tpl="player_fighter", team="Player", hp=400, hpmax=400, x=c.x + 50, y=c.y, z=c.z, pl=1};
end;

-- Hail of trader id with the cooldown passed; returns the result of TRF_HailOpen.
function HL_Hail(id)
	local r = TRF.live.tr[id];
	if type(r.hlt) == "number" then r.hlt = r.hlt - 1000; end;
	return TRF_HailOpen(id, "focus");
end;

-- Lines said after the marks s0 (screen) and m0 (radio) containing text.
function HL_Said(s0, m0, text)
	local h = HOST();
	for i = (s0 or 0) + 1, getn(h.screen) do if strfind(h.screen[i].t, text, 1, 1) then return 1; end; end;
	for i = (m0 or 0) + 1, getn(h.msgs) do if strfind(h.msgs[i].t, text, 1, 1) then return 1; end; end;
	return nil;
end;

-- Ends an open chain: Esc on a dialog, Cancel on a box.
function HL_End()
	local h = HOST();
	for i = 1, 8 do
		if not TRF.live.hl then return; end;
		local b = HOST_Box();
		if h.dlg and h.dlg.open then HOST_DlgEsc();
		elseif b and not b.done then HOST_Press("cancel"); end;
		T_Tick(3, 0.5);
	end;
end;

-- a: stage B pages ------------------------------------------------------------------------------------

function T_HL_A()
	local h = HOST();
	HL_Begin();
	HL_Dlg(1);
	-- The menu dialog, then "Where are you headed": nothing in the callback, the page from the due call.
	local id, r = HL_Trader();
	local n0 = S_Mark();
	local nb, nd = getn(h.boxes), getn(h.tdlgs);
	HOST_Check(TRF_HailOpen(id, "focus") == "menu" and h.dlg and h.dlg.open and h.dlg.name == "TRF_Hail" and TRF_BoxHolder() == "hail",
		"menu dialog open, box lock held by hail ("..tostring(TRF_BoxHolder())..")");
	local o0 = getn(TRF.live.hl.o);
	HOST_Check(strfind(HOST_DlgVis(), "a_head", 1, 1) and strfind(HOST_DlgVis(), "a_trouble", 1, 1), "menu shows head and trouble: "..HOST_DlgVis());
	HOST_DlgPick("a_head");
	HOST_Check(getn(h.tdlgs) == nd + 1 and TRF.live.hl.w == "wait", "pick head: recorded only, no dialog inside the callback");
	T_Tick(1, 0.5);
	local nm = TRF_HlName(r);
	local hd = TRF_Headed(id);
	local t2 = h.tdlgs[nd + 2] or {};
	HOST_Check(t2.d == "TRF_HailPg" and t2.init == "TRF_HlPgInit" and h.dlg.open and getn(h.boxes) == nb and TRF.live.hl.w == "dlg"
		and HOST_DlgText() == "FTU "..nm..": "..hd and HOST_DlgVis() == "a_back a_close"
		and HOST_DlgText("a_back") == "- Back" and HOST_DlgText("a_close") == "- Close",
		"head: answer page with Back and Close, the text set in the init: "..tostring(HOST_DlgText()).." / "..HOST_DlgVis());
	HOST_Check(S_Logs(n0, "module=hail event=page trader_id="..id.." via=dialog kind=answer key=head back=true") == 1
		and S_Logs(n0, "module=hail event=dialog_answers trader_id="..id.." dialog=page answers=back,close kind=answer") == 1
		and r.hd == 1 and TRF_BoxHolder() == "hail", "page log, level 2 answers line, r.hd set, lock still hail");
	-- The menu's pending dialog check leaves the page open.
	T_Tick(3, 0.5);
	HOST_Check(h.dlg.open and TRF.live.hl and TRF.live.hl.w == "dlg" and S_Logs(n0, "event=close trader_id="..id) == 0, "pending menu check: page stays open");
	-- Back: the menu again from the due call, head hidden (D11), the other options shown.
	HOST_DlgPick("a_back");
	HOST_Check(h.dlg.open == nil and TRF.live.hl.w == "wait", "Back: recorded only");
	T_Tick(1, 0.5);
	local t3 = h.tdlgs[nd + 3] or {};
	HOST_Check(t3.d == "TRF_Hail" and h.dlg.open and getn(TRF.live.hl.o) == o0 - 1 and not strfind(HOST_DlgVis(), "a_head", 1, 1)
		and strfind(HOST_DlgVis(), "a_trouble", 1, 1) and HOST_DlgVis() == V_DlgWant(TRF.live.hl.o)
		and S_Logs(n0, "module=hail event=back trader_id="..id.." key=head answer_count="..(o0 - 1).." via=dialog result=menu") == 1,
		"Back: menu dialog reopened, head hidden: "..HOST_DlgVis());
	-- Trouble: a page; Close ends the chain and frees the lock.
	HOST_DlgPick("a_trouble");
	T_Tick(1, 0.5);
	HOST_Check(h.dlg.open and h.dlg.name == "TRF_HailPg" and r.tu == 1 and HOST_DlgVis() == "a_back a_close", "trouble: answer page");
	HOST_DlgPick("a_close");
	HOST_Check(TRF.live.hl == nil and TRF_BoxHolder() == nil and S_Logs(n0, "event=close trader_id="..id.." reason=close") == 1, "Close: chain closed, lock free");
	T_Tick(3, 0.5);
	HOST_Check(S_Logs(n0, "event=close trader_id="..id) == 1, "one close");
	-- Esc on a page: the dialog check closes the chain and frees the lock.
	local id2, r2 = HL_Trader();
	n0 = S_Mark();
	TRF_HailOpen(id2, "focus");
	HOST_DlgPick("a_boom");
	T_Tick(1, 0.5);
	HOST_Check(h.dlg.open and h.dlg.name == "TRF_HailPg" and r2.bm == 1, "boom: answer page");
	HOST_DlgEsc();
	T_Tick(3, 0.5);
	HOST_Check(TRF.live.hl == nil and TRF_BoxHolder() == nil and S_Logs(n0, "event=close trader_id="..id2.." reason=\"dialog closed\"") == 1,
		"Esc on a page: chain closed (dialog closed), lock free");
	-- Escort offer page: Decline goes back to the menu without the escort option; Accept takes the contract.
	local id3, r3 = HL_Trader();
	n0 = S_Mark();
	TRF_HailOpen(id3, "focus");
	HOST_Check(strfind(HOST_DlgVis(), "a_esc", 1, 1), "menu with the escort option: "..HOST_DlgVis());
	HOST_DlgPick("a_esc");
	T_Tick(1, 0.5);
	local txt = TRF_CtOffer(id3);
	HOST_Check(h.dlg.open and h.dlg.name == "TRF_HailPg" and HOST_DlgVis() == "a_acc a_dec" and HOST_DlgText("a_acc") == "- Accept"
		and HOST_DlgText("a_dec") == "- Decline" and HOST_DlgText() == "FTU "..TRF_HlName(r3)..": "..tostring(txt)
		and S_Logs(n0, "event=page trader_id="..id3.." via=dialog kind=offer key=esc back=false") == 1,
		"escort: offer page with Accept and Decline: "..tostring(HOST_DlgText()));
	HOST_DlgPick("a_dec");
	T_Tick(1, 0.5);
	HOST_Check(h.dlg.open and h.dlg.name == "TRF_Hail" and not strfind(HOST_DlgVis(), "a_esc", 1, 1) and TRF.live.ct == nil and r3.ct == nil
		and S_Logs(n0, "module=hail event=contract trader_id="..id3.." result=declined") == 1
		and S_Logs(n0, "module=hail event=back trader_id="..id3.." key=esc ") == 1, "Decline: back to the menu without escort, no contract");
	HOST_DlgPick("a_close");
	local id4, r4 = HL_Trader();
	n0 = S_Mark();
	TRF_HailOpen(id4, "focus");
	HOST_DlgPick("a_esc");
	T_Tick(1, 0.5);
	HOST_DlgPick("a_acc");
	HOST_Check(TRF.live.ct == nil, "Accept: nothing inside the callback");
	T_Tick(1, 0.5);
	HOST_Check(type(TRF.live.ct) == "table" and TRF.live.ct.id == id4 and r4.ct == 1 and TRF.live.hl == nil and TRF_BoxHolder() == nil
		and S_Logs(n0, "event=contract trader_id="..id4.." pay=") == 1, "Accept: contract taken, chain closed");
	TRF_CtVoid("test");
	-- Provider offer item (q): Accept calls ok; Decline returns to the menu.
	local dco = TRF_Dc_HailOpts;
	HL_OkN = 0;
	HL_OkFn = function(id, a) HL_OkN = HL_OkN + 1; return "Offer taken"; end;
	TRF_Dc_HailOpts = function(id) return {{k="xq", t="Test offer", q="FTU Test: Pay us, escort us?", ok=HL_OkFn}}; end;
	local id5 = HL_Trader();
	n0 = S_Mark();
	TRF_HailOpen(id5, "focus");
	HOST_DlgPick("a_p1");
	T_Tick(1, 0.5);
	HOST_Check(h.dlg.open and HOST_DlgVis() == "a_acc a_dec" and S_Logs(n0, "event=page trader_id="..id5.." via=dialog kind=offer key=xq") == 1,
		"provider offer: page with Accept and Decline");
	HOST_DlgPick("a_dec");
	T_Tick(1, 0.5);
	HOST_Check(HL_OkN == 0 and h.dlg.open and h.dlg.name == "TRF_Hail" and not strfind(HOST_DlgVis(), "a_p1", 1, 1)
		and S_Logs(n0, "module=hail event=offer offer_index=1 result=declined") == 1, "provider offer Decline: menu without the item");
	HOST_DlgPick("a_close");
	local id6 = HL_Trader();
	n0 = S_Mark();
	local s0, m0 = getn(h.screen), getn(h.msgs);
	TRF_HailOpen(id6, "focus");
	HOST_DlgPick("a_p1");
	T_Tick(1, 0.5);
	HOST_DlgPick("a_acc");
	T_Tick(1, 0.5);
	HOST_Check(HL_OkN == 1 and TRF.live.hl == nil and HL_Said(s0, m0, "Offer taken") and S_Logs(n0, "event=offer offer_index=1 result=accepted") == 1,
		"provider offer Accept: ok called, reply said, chain closed");
	-- Provider HailDo offer (trf_danger dc, trf_supply sesc): TRF_HlProvPage; Decline back to the menu, Accept runs the
	-- provider's function from the due call and a chain it leaves open is closed.
	local dcd = TRF_Dc_HailDo;
	HL_PvN = 0;
	HL_PvAcc = function() HL_PvN = HL_PvN + 1; end;
	TRF_Dc_HailOpts = function(id) return {"xprov"}; end;
	TRF_Dc_HailDo = function(key, id) if not TRF_HlProvPage("FTU Test: Escort our convoy for 100 cr?", "HL_PvAcc", key) then return nil; end; return 1; end;
	local idp = HL_Trader();
	n0 = S_Mark();
	TRF_HailOpen(idp, "focus");
	HOST_DlgPick("a_p1");
	T_Tick(1, 0.5);
	HOST_Check(h.dlg.open and HOST_DlgVis() == "a_acc a_dec" and HOST_DlgText() == "FTU "..TRF_HlName(TRF.live.tr[idp])..": Escort our convoy for 100 cr?"
		and TRF.live.hl.w == "dlg" and S_Logs(n0, "event=page trader_id="..idp.." via=dialog kind=offer key=xprov") == 1, "provider HailDo: offer page");
	HOST_DlgPick("a_dec");
	T_Tick(1, 0.5);
	HOST_Check(HL_PvN == 0 and h.dlg.open and h.dlg.name == "TRF_Hail" and not strfind(HOST_DlgVis(), "a_p1", 1, 1)
		and S_Logs(n0, "event=offer trader_id="..idp.." key=xprov result=declined") == 1, "provider page Decline: menu without the item");
	HOST_DlgPick("a_close");
	local idq = HL_Trader();
	n0 = S_Mark();
	TRF_HailOpen(idq, "focus");
	HOST_DlgPick("a_p1");
	T_Tick(1, 0.5);
	HOST_DlgPick("a_acc");
	T_Tick(1, 0.5);
	HOST_Check(HL_PvN == 1 and TRF.live.hl == nil and TRF_BoxHolder() == nil
		and S_Logs(n0, "event=offer trader_id="..idq.." key=xprov handler=HL_PvAcc result=accepted") == 1
		and S_Logs(n0, "event=close trader_id="..idq.." reason=accept") == 1, "provider page Accept: the function ran, the chain closed");
	TRF_Dc_HailDo = dcd;
	-- trf_supply sesc on a page: TRF_SupplyCtDo opens the hail page; Accept runs TRF_SpCtPgOk (closes the chain, then the
	-- box OK path; this trader is no sweep convoy, so the contract is not accepted).
	local sco = TRF_SpCtOffer;
	TRF_SpCtOffer = function(id) return "FTU Test: Escort the sweep convoy for 900 cr?", 900; end;
	TRF_Dc_HailOpts = function(id) return {{k="xsesc", t="Sweep escort", f="HL_Sesc"}}; end;
	HL_Sesc = nil;
	local ids = HL_Trader();
	n0 = S_Mark();
	TRF_HailOpen(ids, "focus");
	local hlx = TRF.live.hl;
	-- Called as trf_supply's HailDo is: from the due call after the pick closed the menu dialog.
	HOST_DlgEsc();
	hlx.w = "wait";
	HOST_Check(TRF_SupplyCtDo(ids) == 1 and h.dlg.open and h.dlg.name == "TRF_HailPg" and HOST_DlgVis() == "a_acc a_dec"
		and TRF.live.box == "hail", "sesc: the offer as a hail page (lock stays hail)");
	HOST_DlgPick("a_acc");
	T_Tick(1, 0.5);
	HOST_Check(TRF.live.hl == nil and TRF.live.spc == nil and S_Logs(n0, "event=close trader_id="..ids.." reason=\"sesc accept\"") == 1
		and S_Logs(n0, "module=supply event=contract trader_id="..ids.." result=not_accepted") == 1, "sesc page Accept: TRF_SpCtPgOk, chain closed");
	TRF_SpCtOffer = sco;
	TRF_Dc_HailOpts = dco;
	-- The last option: no Back on its page.
	local id7, r7 = HL_Trader();
	r7.trd = 1; r7.hd = 1; r7.tu = 1; r7.ct = 1;
	n0 = S_Mark();
	HOST_Check(TRF_HailOpen(id7, "focus") == "menu" and HOST_DlgVis() == "a_boom a_close", "menu with boom only: "..HOST_DlgVis());
	HOST_DlgPick("a_boom");
	T_Tick(1, 0.5);
	HOST_Check(HOST_DlgVis() == "a_close" and S_Logs(n0, "event=page trader_id="..id7.." via=dialog kind=answer key=boom back=false") == 1, "last option: Close only");
	HOST_DlgPick("a_close");
	-- Fallback: the page cannot open (UI not idle at the due call): the answer box, then boxes for the chain.
	local id8, r8 = HL_Trader();
	n0 = S_Mark();
	nb = getn(h.boxes);
	TRF_HailOpen(id8, "focus");
	HOST_DlgPick("a_head");
	h.ui = -1;
	T_Tick(1, 0.5);
	h.ui = 0;
	local bx = HOST_Box();
	HOST_Check(getn(h.boxes) == nb + 1 and bx.text == TRF_Headed(id8) and bx.cancel == nil and TRF.live.hl.w == "ans" and TRF.live.hl.bx == 1
		and S_Logs(n0, "event=dialog_fallback reason=ui=-1") <= 1 and S_Logs(n0, "event=page trader_id="..id8.." via=box kind=answer key=head") == 1,
		"page fallback: the answer box (bx 1), page log via=box");
	HOST_Press("ok");
	HOST_Check(TRF.live.hl == nil and TRF_BoxHolder() == nil, "answer box OK closes the chain");
	-- hail_box 1: unchanged box chain (no page dialog, no page line).
	HL_Dlg(nil);
	local id9 = HL_Trader();
	n0 = S_Mark();
	nb, nd = getn(h.boxes), getn(h.tdlgs);
	TRF_HailOpen(id9, "focus");
	local lab = TRF_HlLabel(id9, "head");
	local k = 0;
	while k < 10 and not strfind(HOST_Box().text, lab, 1, 1) do HOST_Press("cancel"); T_Tick(1, 0.5); k = k + 1; end;
	HOST_Press("ok");
	T_Tick(1, 0.5);
	HOST_Check(HOST_Box().text == TRF_Headed(id9) and getn(h.tdlgs) == nd and S_Logs(n0, "event=page ") == 0 and TRF.live.hl.w == "ans",
		"hail_box 1: the answer box as before, no dialog, no page line");
	HOST_Press("ok");
	HOST_Check(TRF.live.hl == nil, "hail_box 1: OK closes");
	V_ClearTr();
end;

-- b: busy ---------------------------------------------------------------------------------------------

function T_HL_B()
	local h = HOST();
	HL_Begin();
	HL_Dlg(1);
	local T = TRF_Tune();
	HOST_Check(T.hail_fight_r == 600 and T.hail_help_ratio == 1 and T.help_k == 0.5 and TRF_HlOpt("hail_fight") == 1,
		"tune hail_fight_r 600, hail_help_ratio 1, help_k 0.5; cfg hail_fight 1");
	-- As many pirates 300 from the lead as the trader has escorts: not losing, the busy page.
	local id, r, x = HL_Trader();
	local ne = TRF_Rd_EscAlive(r, x);
	HOST_Check(ne >= 1, "the spawn has escorts ("..ne..")");
	-- A Trade record (its own ships), a neutral team, a pirate 900 away, a wreck and a dead pirate are no hostiles.
	local p = HL_Lp(id);
	local extra = {{id=7001, cls=3, tpl="trade_ship", team="Trade", hp=300, hpmax=300, x=p.x + 20, y=p.y, z=p.z, pl=0},
		{id=7002, cls=3, tpl="vks_fighter", team="Vks", hp=300, hpmax=300, x=p.x + 20, y=p.y, z=p.z, pl=0},
		{id=7003, cls=3, tpl="far_pirate", team="Pirates", hp=300, hpmax=300, x=p.x + 900, y=p.y, z=p.z, pl=0},
		{id=7004, cls=10, tpl="wreck", team="Pirates", hp=300, hpmax=300, x=p.x + 30, y=p.y, z=p.z, pl=0},
		{id=7005, cls=3, tpl="dead_pirate", team="Pirates", hp=0, hpmax=300, x=p.x + 30, y=p.y, z=p.z, pl=0}};
	HL_Pirates(id, ne, 300, extra);
	local fo = TRF_HlNearShips(id);
	HOST_Check(type(fo) == "table" and getn(fo) == ne, "hostiles: Pirates cls 3 alive within 600 only ("..tostring(fo and getn(fo))..")");
	local n0 = S_Mark();
	local nb, nd = getn(h.boxes), getn(h.tdlgs);
	local res = TRF_HailOpen(id, "focus");
	local nm = TRF_HlName(r);
	HOST_Check(res == "fight" and h.dlg and h.dlg.open and h.dlg.name == "TRF_HailPg" and getn(h.tdlgs) == nd + 1
		and HOST_DlgText() == "FTU "..nm..": Not now, we're busy." and HOST_DlgVis() == "a_close" and getn(h.boxes) == nb,
		"busy: one page, Close only, no menu: "..tostring(HOST_DlgText()).." / "..HOST_DlgVis());
	HOST_Check(S_Logs(n0, "module=hail event=fight trader_id="..id.." via=focus raid_id=nil hostile_count="..ne.." escort_count="..ne
		.." escort_fight=false") == 1 and S_Logs(n0, "losing=false lose_reason=nil answer=busy") == 1
		and S_Logs(n0, "event=page trader_id="..id.." via=dialog kind=busy key=nil back=false") == 1 and r.hn == 1 and r.hlp == nil,
		"fight log: hostiles, escorts, answer busy; hail counted, no offer");
	HOST_DlgPick("a_close");
	HOST_Check(TRF.live.hl == nil and TRF_BoxHolder() == nil, "busy page Close: chain closed, lock free");
	-- The escort flight in a fight (h.eo nil) without a typed list: busy.
	TRF_Carcasses = nil;
	local id2, r2, x2 = HL_Trader();
	x2.ef = x2.fl;
	x2.eo = nil;
	n0 = S_Mark();
	HOST_Check(HL_Hail(id2) == "fight" and HOST_DlgVis() == "a_close"
		and S_Logs(n0, "event=fight trader_id="..id2.." via=focus raid_id=nil hostile_count=nil escort_count=") == 1
		and S_Logs(n0, "escort_fight=true") == 1, "escort flight fighting, no DLL list: busy page");
	HOST_DlgPick("a_close");
	x2.ef = nil;
	-- TRF_Combat (the player's combat) does not stop the combat hail; without a fight it skips as before.
	local id3 = HL_Trader();
	HL_Pirates(id3, 3, 300);
	TRF.live.cbt = TRF_HlGt();
	n0 = S_Mark();
	HOST_Check(HL_Hail(id3) == "fight", "TRF_Combat holds: the combat hail still answers");
	HL_End();
	HOST().carc = {};
	local id4 = HL_Trader();
	TRF.live.cbt = TRF_HlGt();
	n0 = S_Mark();
	local ok, why = HL_Hail(id4);
	HOST_Check(ok == nil and why == "combat" and S_Logs(n0, "event=hail trader_id="..id4.." via=focus result=skipped reason=combat") == 1,
		"TRF_Combat without a trader fight: skipped (combat)");
	TRF.live.cbt = nil;
	-- Box form (hail_box 1): one OK box; line form (hail_box 0): the busy line.
	HL_Dlg(nil);
	local id5, r5 = HL_Trader();
	HL_Pirates(id5, 1, 300);
	r5.np = (r5.nt or 1) + 5;
	nb = getn(h.boxes);
	n0 = S_Mark();
	HOST_Check(HL_Hail(id5) == "fight" and getn(h.boxes) == nb + 1 and HOST_Box().text == "FTU "..TRF_HlName(r5)..": Not now, we're busy."
		and HOST_Box().cancel == nil and TRF.live.hl.w == "ans" and S_Logs(n0, "event=page ") == 0, "hail_box 1: the busy box, no page line");
	HOST_Press("ok");
	HOST_Check(TRF.live.hl == nil, "busy box OK closes");
	h.cfg.tune = {hail_box=0};
	local id6 = HL_Trader();
	HL_Pirates(id6, 1, 300);
	local s0, m0 = getn(h.screen), getn(h.msgs);
	nb = getn(h.boxes);
	HOST_Check(HL_Hail(id6) == "fight" and getn(h.boxes) == nb and TRF.live.hl == nil and HL_Said(s0, m0, "Not now, we're busy."), "hail_box 0: the busy line");
	h.cfg.tune = nil;
	-- cfg hail_fight 0: the menu as before, with the hostiles near.
	h.cfg.hail_fight = 0;
	local id7 = HL_Trader();
	HL_Pirates(id7, 3, 300);
	n0 = S_Mark();
	HOST_Check(HL_Hail(id7) == "menu" and S_Logs(n0, "event=fight ") == 0, "hail_fight 0: the normal menu");
	V_HailEnd();
	h.cfg.hail_fight = nil;
	-- An armed raid (not spawned): no fight, the hail stays skipped (raid).
	HOST().carc = {};
	h.cfg.raids = 1;
	local id8, r8 = HL_Trader("C");
	local n = V_Raid(id8);
	n0 = S_Mark();
	ok, why = HL_Hail(id8);
	HOST_Check(n and V_Rd(n).st == "armed" and ok == nil and why == "raid" and S_Logs(n0, "event=fight ") == 0, "armed raid: skipped (raid), no fight: "..tostring(why));
	TRF_Rd_End(n, "cancel");
	h.cfg.raids = 0;
	TRF_Carcasses = nil;
	h.carc = nil;
	V_ClearTr();
end;

-- c: help offer without a raid record ----------------------------------------------------------------------

function T_HL_C()
	local h = HOST();
	HL_Begin();
	HL_Dlg(1);
	local idx = TRF_CurIdx();
	-- Outnumbered: 2 pirates, no escort. Decline: the decline page; the second hail of the visit is busy.
	local id, r, x = HL_Trader();
	HL_NoEscorts(x);
	HL_Pirates(id, 2, 300);
	local p = floor(min(0.5 * TRF_PayN(idx), TRF_HlT("pay_cap")));
	local n0 = S_Mark();
	local nm = TRF_HlName(r);
	HOST_Check(HL_Hail(id) == "fight" and h.dlg.open and h.dlg.name == "TRF_HailPg" and HOST_DlgVis() == "a_acc a_dec"
		and HOST_DlgText() == "FTU "..nm..": We're outgunned. Clear them off and there's "..p.." cr in it for you." and r.hlp == 1 and p > 0,
		"outnumbered: the help page, Accept and Decline, pay "..p..": "..tostring(HOST_DlgText()));
	HOST_Check(S_Logs(n0, "event=fight trader_id="..id.." via=focus raid_id=nil hostile_count=2 escort_count=0 escort_fight=false") == 1
		and S_Logs(n0, "losing=true lose_reason=outnumbered answer=help") == 1
		and S_Logs(n0, "module=hail event=help trader_id="..id.." raid_id=nil pay="..p.." via=dialog result=offered") == 1
		and S_Logs(n0, "event=page trader_id="..id.." via=dialog kind=help") == 1, "fight and help offer logs");
	HOST_DlgPick("a_dec");
	HOST_Check(h.dlg.open == nil and TRF.live.hl.w == "wait", "Decline: recorded only");
	T_Tick(1, 0.5);
	HOST_Check(h.dlg.open and HOST_DlgText() == "FTU "..nm..": Then stay out of the line of fire." and HOST_DlgVis() == "a_close"
		and S_Logs(n0, "event=help trader_id="..id.." raid_id=nil pay="..p.." result=declined") == 1
		and S_Logs(n0, "event=page trader_id="..id.." via=dialog kind=decline") == 1 and r.hlp == 1, "Decline: the decline page with Close");
	HOST_DlgPick("a_close");
	T_Tick(3, 0.5);
	n0 = S_Mark();
	HOST_Check(HL_Hail(id) == "fight" and HOST_DlgVis() == "a_close" and S_Logs(n0, "answer=busy reason=once") == 1, "once per visit: the second hail is busy");
	HOST_DlgPick("a_close");
	-- Accept, then the player's fighter near one pirate that dies; the other dies with no player ship near; paid.
	local id2, r2, x2 = HL_Trader();
	HL_NoEscorts(x2);
	local l = HL_Pirates(id2, 2, 300);
	TRF.std.heat = 2;
	local hp0, c0, pz0 = TRF.std.help, h.credits, TRF.clock.pz;
	n0 = S_Mark();
	local s0, m0 = getn(h.screen), getn(h.msgs);
	HL_Hail(id2);
	HOST_DlgPick("a_acc");
	HOST_Check(r2.hlp == 1 and TRF.live.hl.w == "wait", "Accept: recorded only");
	T_Tick(1, 0.5);
	local w = TRF_H().hlw and TRF_H().hlw[id2];
	HOST_Check(r2.hlp == 2 and TRF.live.hl == nil and type(w) == "table" and w.p == p and w.k == 0 and w.s[9001] == 1 and w.s[9002] == 1
		and HL_Said(s0, m0, "Deal. Make it quick") and S_Logs(n0, "event=help trader_id="..id2.." raid_id=nil pay="..p.." via=watch result=accepted") == 1,
		"Accept: hlp 2, the watch with both pirates seen, the accept line ("..TRF_Dump(w)..")");
	tinsert(h.carc, HL_PlNear(l[1]));
	T_Tick(5, 0.5);
	HOST_Check(w.s[9001] == 2 and w.s[9002] == 1, "watch: pirate 1 seen with a player ship within 600");
	HL_Kill(9001);
	T_Tick(5, 0.5);
	HOST_Check(w.k == 1 and w.s[9001] == nil and r2.hlp == 2, "pirate 1 gone from the location: one counted kill");
	HL_Kill(8001);
	HL_Kill(9002);
	T_Tick(5, 0.5);
	HOST_Check(r2.hlp == 3 and TRF_H().hlw[id2] == nil and h.credits - c0 == p and TRF.std.help == hp0 + 1 and TRF.std.heat == 1 and r2.res == 1
		and HL_Said(s0, m0, "They're gone. "..p.." cr transferred.") and TRF.clock.pz ~= pz0
		and S_Logs(n0, "event=help trader_id="..id2.." pay="..p.." credits="..p.." kill_count=1 help=1 via=watch result=paid") == 1
		and S_Logs(n0, "module=region event=pay reason=hail_help amount="..p) == 1,
		"fight over: paid "..p.." through TRF_Pay, help +1, heat -1, rescued, prize gap marked ("..(h.credits - c0)..")");
	-- The prize gap is open now: no offer for the next trader (busy, reason gap).
	local id3, r3, x3 = HL_Trader();
	HL_NoEscorts(x3);
	HL_Pirates(id3, 2, 300);
	n0 = S_Mark();
	HOST_Check(HL_Hail(id3) == "fight" and HOST_DlgVis() == "a_close" and r3.hlp == nil and S_Logs(n0, "answer=busy reason=gap") == 1, "prize gap open: busy (gap)");
	HOST_DlgPick("a_close");
	TRF.clock.pz = nil;
	-- Accept without player fire: the pirates die with no player ship near: unpaid.
	local id4, r4, x4 = HL_Trader();
	HL_NoEscorts(x4);
	HL_Pirates(id4, 2, 300);
	c0 = h.credits;
	n0 = S_Mark();
	HL_Hail(id4);
	HOST_DlgPick("a_acc");
	T_Tick(1, 0.5);
	HL_Kill(9001);
	HL_Kill(9002);
	T_Tick(4, 0.5);
	HOST_Check(r4.hlp == 3 and h.credits == c0 and TRF_H().hlw[id4] == nil
		and S_Logs(n0, "event=help trader_id="..id4.." pay="..p.." kill_count=0 via=watch result=unpaid reason=no_fire") == 1, "no player fire: unpaid (no_fire)");
	-- The trader gone during the watch: unpaid (gone); the time-out: unpaid (time).
	local id5, r5, x5 = HL_Trader();
	HL_NoEscorts(x5);
	HL_Pirates(id5, 2, 300);
	n0 = S_Mark();
	HL_Hail(id5);
	HOST_DlgPick("a_acc");
	T_Tick(1, 0.5);
	TRF_Remove(id5, "test");
	T_Tick(4, 0.5);
	HOST_Check(TRF_H().hlw[id5] == nil and S_Logs(n0, "event=help trader_id="..id5.." pay="..p.." kill_count=0 via=watch result=unpaid reason=gone") == 1, "trader gone: unpaid (gone)");
	local id6, r6, x6 = HL_Trader();
	HL_NoEscorts(x6);
	HL_Pirates(id6, 2, 300);
	n0 = S_Mark();
	HL_Hail(id6);
	HOST_DlgPick("a_acc");
	T_Tick(1, 0.5);
	T_Tick(610, 0.5);
	HOST_Check(r6.hlp == 3 and S_Logs(n0, "event=help trader_id="..id6.." pay="..p.." kill_count=0 via=watch result=unpaid reason=time") == 1, "300 s: unpaid (time)");
	-- Box fallback (hail_box 1): the offer as an OK/Cancel box; Cancel -> the decline box; OK -> accepted.
	HL_Dlg(nil);
	local id7, r7, x7 = HL_Trader();
	HL_NoEscorts(x7);
	HL_Pirates(id7, 2, 300);
	local nb = getn(h.boxes);
	n0 = S_Mark();
	HL_Hail(id7);
	local bx = HOST_Box();
	HOST_Check(getn(h.boxes) == nb + 1 and bx.cancel ~= nil and strfind(bx.text, "We're outgunned", 1, 1) and TRF.live.hl.w == "hp"
		and S_Logs(n0, "event=help trader_id="..id7.." raid_id=nil pay="..p.." via=box result=offered") == 1, "hail_box 1: the offer box (OK/Cancel)");
	HOST_Press("cancel");
	HOST_Check(getn(h.boxes) == nb + 1, "Cancel: the next box waits for the due call");
	T_Tick(1, 0.5);
	HOST_Check(getn(h.boxes) == nb + 2 and HOST_Box().text == "FTU "..TRF_HlName(r7)..": Then stay out of the line of fire." and HOST_Box().cancel == nil
		and h.box_nested == 0, "Cancel: the decline box");
	HOST_Press("ok");
	HOST_Check(TRF.live.hl == nil and r7.hlp == 1, "decline box OK closes");
	local id8, r8, x8 = HL_Trader();
	HL_NoEscorts(x8);
	HL_Pirates(id8, 2, 300);
	HL_Hail(id8);
	HOST_Press("ok");
	T_Tick(1, 0.5);
	HOST_Check(r8.hlp == 2 and type(TRF_H().hlw[id8]) == "table" and TRF.live.hl == nil, "hail_box 1: OK accepts, the watch runs");
	TRF_HlHelpDrop("test");
	-- Heat 3: no offer (busy, heat).
	HL_Dlg(1);
	local id9, r9, x9 = HL_Trader();
	HL_NoEscorts(x9);
	HL_Pirates(id9, 2, 300);
	TRF.std.heat = 3;
	n0 = S_Mark();
	HOST_Check(HL_Hail(id9) == "fight" and HOST_DlgVis() == "a_close" and S_Logs(n0, "answer=busy reason=heat") == 1, "heat 3: busy (heat)");
	HOST_DlgPick("a_close");
	TRF.std.heat = 0;
	HL_Dlg(nil);
	TRF_Carcasses = nil;
	h.carc = nil;
	V_ClearTr();
end;

-- d: help offer on a raid record ----------------------------------------------------------------------------

-- Trader without escorts under a spawned raid (st come): id, record, handles, raid id.
function HL_Raided()
	local id, r, x = HL_Trader("C");
	HL_NoEscorts(x);
	local n = V_Raid(id);
	HOST_Fire("f_inside", "TRF_RaidGo("..n..",");
	return id, r, x, n;
end;

function T_HL_D()
	local h = HOST();
	HL_Begin({raids=1});
	HL_Dlg(1);
	local idx = TRF_CurIdx();
	HOST().carc = {};
	TRF_Carcasses = HOST_Carcasses;
	-- Ratio below 1: lone transport (pw x 0.5) against the raid flight.
	local id, r, x, n = HL_Raided();
	HOST_Check(n and V_Rd(n).st == "come", "raid spawned (come)");
	local st, sr = TRF_Rd_HailRatio(n);
	local n0 = S_Mark();
	HOST_Check(type(st) == "number" and sr > 0 and st / sr < 1 and HL_Hail(id) == "fight" and HOST_DlgVis() == "a_acc a_dec"
		and S_Logs(n0, "event=fight trader_id="..id.." via=focus raid_id="..n) == 1 and S_Logs(n0, "losing=true lose_reason=ratio answer=help") == 1,
		"raid, ratio "..TRF_F(st / sr).." below 1: the help page");
	HL_End();
	TRF_Rd_End(n, "cancel");
	-- A strong trader (ratio above 1): busy.
	local id2, r2, x2, n2 = HL_Raided();
	r2.pw = 1000;
	n0 = S_Mark();
	HOST_Check(HL_Hail(id2) == "fight" and HOST_DlgVis() == "a_close" and S_Logs(n0, "losing=false lose_reason=nil answer=busy") == 1, "raid, ratio above 1: busy");
	HL_End();
	TRF_Rd_End(n2, "cancel");
	-- Comply and flee: the help page even when strong.
	local id3, r3, x3, n3 = HL_Raided();
	r3.pw = 1000;
	V_Rd(n3).dc = "comply";
	n0 = S_Mark();
	HOST_Check(HL_Hail(id3) == "fight" and HOST_DlgVis() == "a_acc a_dec" and S_Logs(n0, "lose_reason=comply answer=help") == 1, "raid comply: help page");
	HL_End();
	TRF_Rd_End(n3, "cancel");
	local id4, r4, x4, n4 = HL_Raided();
	r4.pw = 1000;
	r4.st = "flee";
	n0 = S_Mark();
	HOST_Check(HL_Hail(id4) == "fight" and HOST_DlgVis() == "a_acc a_dec" and S_Logs(n0, "lose_reason=flee answer=help") == 1, "trader fleeing: help page");
	HL_End();
	TRF_Rd_End(n4, "cancel");
	-- Accept on a raid, one player hit (ph, not deliberate fire), the raid killed: trf_raid pays help_k x N_eff.
	local id5, r5, x5, n5 = HL_Raided();
	local hr5 = TRF_H().rd[n5];
	TRF.std.heat = 0;
	local c0 = h.credits;
	n0 = S_Mark();
	HL_Hail(id5);
	HOST_DlgPick("a_acc");
	T_Tick(1, 0.5);
	HOST_Check(r5.hlp == 2 and (TRF_H().hlw == nil or TRF_H().hlw[id5] == nil), "Accept on a raid: hlp 2, no watch");
	HOST_Check(S_Logs(n0, "event=help trader_id="..id5.." raid_id="..n5.." pay=") == 2 and S_Logs(n0, "via=raid result=accepted") == 1, "accept log via=raid");
	HOST_Fire("attack", "TRF_OnRaidHit("..n5..",1,");
	HOST_Check(V_Rd(n5).ph == 1 and V_Rd(n5).hit == nil, "one player hit: ph, help not counted by the 5.5 rule");
	local want = floor(0.5 * TRF_PayN(idx));
	for j = 1, getn(hr5.sh) do
		hr5.sh[j].alive = nil;
		HOST_Fire("died", "TRF_OnRaidDied("..n5..","..j..",");
	end;
	HOST_Check(V_Rd(n5).st == "end" and h.credits - c0 == want and want > 0 and r5.hlp == 3
		and S_Logs(n0, "module=raid event=paid raid_id="..n5.." trader_id="..id5.." credits="..want) == 1
		and S_Logs(n0, "event=help trader_id="..id5.." raid_id="..n5.." credits="..want.." via=raid result=paid") == 1,
		"raid killed after an accepted offer and one hit: paid "..want.." by the raid help, hlp 3 ("..(h.credits - c0)..")");
	-- Accept on a raid without player fire: the raid ends, no pay, hlp 3.
	local id6, r6, x6, n6 = HL_Raided();
	local hr6 = TRF_H().rd[n6];
	c0 = h.credits;
	n0 = S_Mark();
	HL_Hail(id6);
	HOST_DlgPick("a_acc");
	T_Tick(1, 0.5);
	for j = 1, getn(hr6.sh) do
		hr6.sh[j].alive = nil;
		HOST_Fire("died", "TRF_OnRaidDied("..n6..","..j..",");
	end;
	HOST_Check(V_Rd(n6).st == "end" and h.credits == c0 and r6.hlp == 3
		and S_Logs(n0, "event=help trader_id="..id6.." raid_id="..n6.." via=raid result=unpaid reason=killed") == 1, "no player fire on the raid: unpaid");
	-- Without an accepted offer one hit (no kill within hit_win, no deliberate fire) pays nothing: the 5.5 rule unchanged.
	local id7, r7, x7, n7 = HL_Raided();
	c0 = h.credits;
	n0 = S_Mark();
	HOST_Fire("attack", "TRF_OnRaidHit("..n7..",1,");
	T_Tick(24, 0.5);
	TRF_Rd_End(n7, "left");
	HOST_Check(V_Rd(n7).st == "end" and h.credits == c0 and V_Rd(n7).paid == nil and r7.hlp == nil and S_Logs(n0, "module=raid event=paid ") == 0,
		"no offer: one hit, the raid left: no pay");
	TRF_Carcasses = nil;
	h.carc = nil;
	HL_Dlg(nil);
	V_ClearTr();
end;

-- e: data model ---------------------------------------------------------------------------------------------

function T_HL_E()
	local h = HOST();
	HL_Begin();
	local id, r = HL_Trader();
	local s0 = HOST_SaveSize(TRF);
	r.hlp = 3;
	local s1 = HOST_SaveSize(TRF);
	HOST_Check(s1 - s0 == 23, "hlp costs "..(s1 - s0).." bytes per trader record (23)");
	r.hlp = nil;
	-- Dump: the watch count.
	local W = TRF_HlHw();
	W[id] = {p=100, t0=0, s={}, k=0};
	local n0 = S_Mark();
	TRF_Hail_Dump();
	HOST_Check(S_Logs(n0, "module=hail event=dump ") == 1 and S_Logs(n0, " help_watch_count=1 ") == 1, "dump: help_watch_count");
	-- Jump: the watches end unpaid (jump).
	r.hlp = 2;
	n0 = S_Mark();
	TRF_Hail_BeforeJump();
	HOST_Check(r.hlp == 3 and TRF_H().hlw[id] == nil and S_Logs(n0, "event=help trader_id="..id.." pay=100 kill_count=0 via=watch result=unpaid reason=jump") == 1,
		"jump: the watch settled unpaid");
	-- Load: an accepted offer without a live raid is settled.
	r.hlp = 2;
	n0 = S_Mark();
	TRF_Hail_OnLoad();
	HOST_Check(r.hlp == 3 and S_Logs(n0, "event=help trader_id="..id.." via=watch result=unpaid reason=load") == 1, "load: hlp 2 without a raid settled");
	HOST_Check(HOST_Reserved(TRF, "TRF") == "", "no reserved key in TRF");
	V_ClearTr();
end;

-- Dispatch ---------------------------------------------------------------------------------

local sc = getenv("TRF_HL") or "";
local fn = getglobal("T_HL_"..strupper(sc));
print("HOST ==== hail scenario hl-"..sc.." dir="..HOST().dir);
if type(fn) == "function" then
	fn();
	HOST_Check(T_LeftGlobals() == "", "no handle globals left at the end"..T_LeftGlobals());
	local q = T_BadCallbacks();
	HOST_Check(q == "", "every mod callback string carries the current gen"..q);
else
	HOST_Check(nil, "unknown hail scenario "..sc);
end;
HOST_Check((HOST().gpm_tick or 0) == 0, "no GetPlayerMotherShip from a tick (n="..tostring(HOST().gpm_tick or 0)..")");
print("HOST errors="..HOST().errors.." fails="..HOST().fails);
if HOST().errors > 0 or HOST().fails > 0 then exit(1); end;
exit(0);
