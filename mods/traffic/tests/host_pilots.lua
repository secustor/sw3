-- Named mercenary pilots (design/proposals/merc-pilot-names.md 4.4, 5.1, option B) under stock Lua 4.0.1: TRF_MCP=a..c,
-- run by run_host.sh as its own entry point. a TRF_McName and TRF_Mc_Names of the generated merc_names.script, b
-- TRF_BuildFlight with the ov argument while the templates are merged, c the fallback when CreatePilot gives no pilot
-- and the unchanged path without ov. Loads the stubs of host_stubs.lua (the text before "if H.scen then") and only
-- trf_tier.script and merc_names.script of the mod; no world, no loader.
-- Stub here: CreatePilot of a TRF_McP_ name returns a pilot only while HOST().mcp_merged is set, otherwise its argument
-- (HOST().mcp_ret "arg") or 1 ("one"), the two non-object results the proposal expects from the native (4.4, [I]).

local f = openfile((getenv("TRF_TESTS") or "./").."host_stubs.lua", "r");
if not f then print("HOST FAIL host_pilots.lua: cannot open host_stubs.lua"); exit(1); end;
local src = read(f, "*a");
closefile(f);
local cut = strfind(src, "\nif H.scen then", 1, 1);
if not cut then print("HOST FAIL host_pilots.lua: marker 'if H.scen then' missing in host_stubs.lua"); exit(1); end;
dostring(strsub(src, 1, cut), "host_stubs.lua");

local h = HOST();
h.mcp_calls = {};
h.mcp_merged = nil;
h.mcp_ret = "arg";
h.diff = HARD;   -- TRF_TrTabs: rank r uses pilot list entry r
for _, nm in {"trf_tier.script", "merc_names.script"} do
	if not dofile(h.dir..nm) then print("HOST FAIL host_pilots.lua: cannot load "..nm); exit(1); end;
end;

MC_CreatePilot0 = CreatePilot;
function CreatePilot(tpl)
	tinsert(HOST().mcp_calls, tostring(tpl));
	if type(tpl) == "string" and strsub(tpl, 1, 8) == "TRF_McP_" and not HOST().mcp_merged then
		if HOST().mcp_ret == "one" then return 1; end;
		return tpl;
	end;
	return MC_CreatePilot0(tpl);
end;

-- Clan pilot list in the shape of Trad_merc_Pilots (rank 1..5 through TRF_TrTabs): Pilot, Pilot, Officer, Officer, Ace.
MC_Pil = {"RecruitPilot_blacklegion", "RecruitPilot_blacklegion", "RecruitOfficer_blacklegion", "RecruitOfficer_blacklegion",
	"RecruitAce_blacklegion"};
MC_Row = {{"Tiger_merc1", 5, "A"}, {"Tiger_merc1", 5, "A"}, {"Tiger_merc1", 3, "A"}};
MC_N = 0;

-- Builds MC_Row in a fresh group with ov; returns flight, ships and the pilot templates in row order.
function MC_Build(ov)
	MC_N = MC_N + 1;
	TRF_GMcTest = HOST_Group("TRF_GMcTest", "Merc");
	HOST().mcp_calls = {};
	local fl, sh = TRF_BuildFlight(MC_Pil, MC_Row, "TRF_GMcTest", "trf_mc"..MC_N, Vector3(0, 0, 1000 * MC_N), 10,
		Vector3(0, 0, 1), "shipFormation", 15, 8, ov);
	TRF_GMcTest = nil;
	local tp = {};
	if sh then for i = 1, getn(sh) do tinsert(tp, sh[i].pilot and sh[i].pilot.tpl or "-"); end; end;
	return fl, sh, tp;
end;

function MC_Join(t) local s = ""; for i = 1, getn(t) do s = s..(i > 1 and "," or "")..tostring(t[i]); end; return s; end;

local sc = getenv("TRF_MCP") or "";

-- a: the generated name table and TRF_McName ---------------------------------------------
if sc == "a" then
	local t = TRF_Mc_Names();
	local nc, nn, seen, dup, long = 0, 0, {}, 0, 0;
	for k, v in t do
		nc = nc + 1;
		HOST_Check(type(v) == "table" and getn(v) == 10, "clan "..k..": 10 names");
		for i = 1, getn(v) do
			nn = nn + 1;
			local l = strlower(v[i]);
			if seen[l] then dup = dup + 1; end;
			seen[l] = 1;
			if strlen(v[i]) > 14 or strlen(v[i]) == 0 then long = long + 1; end;
		end;
	end;
	HOST_Check(nc == 12 and nn == 120 and dup == 0 and long == 0, "TRF_Mc_Names: 12 clans, 120 names, unique, 1-14 characters ("..nc..", "..nn..", "..dup..", "..long..")");
	HOST_Check(TRF_Mc_Names() ~= t and getglobal("TRF_McNames") == nil, "TRF_Mc_Names builds a new table per call, no table global");
	local tpl, nm = TRF_McName("blacklegion", 0, 1);
	HOST_Check(tpl == "TRF_McP_blacklegion_0_1" and nm == t.blacklegion[2], "TRF_McName blacklegion 0 1 = "..tostring(tpl)..", "..tostring(nm));
	tpl, nm = TRF_McName("stardust", 4, 0);
	HOST_Check(tpl == "TRF_McP_stardust_4_0" and nm == t.stardust[9], "TRF_McName stardust 4 0 = "..tostring(tpl)..", "..tostring(nm));
	local bad = {{"blacklegion", 5, 0}, {"blacklegion", -1, 0}, {"blacklegion", 1.5, 0}, {"blacklegion", 0, 2},
		{"blacklegion", 0, -1}, {"nosuchclan", 0, 0}, {nil, 0, 0}, {"blacklegion", "0", 0}};
	local nb = 0;
	for i = 1, getn(bad) do if TRF_McName(bad[i][1], bad[i][2], bad[i][3]) == nil then nb = nb + 1; end; end;
	HOST_Check(nb == getn(bad), "TRF_McName: nil for slot outside 0..4, gen outside 0..1, unknown clan, wrong types ("..nb.."/"..getn(bad)..")");
end;

-- b: ov with the merge present ----------------------------------------------------------
if sc == "b" then
	h.mcp_merged = 1;
	local lead = TRF_McName("blacklegion", 0, 0);
	local ace = TRF_McName("blacklegion", 1, 1);
	local fl, sh, tp = MC_Build({lead, ace});
	HOST_Check(fl and getn(sh) == 3 and tp[1] == lead and tp[2] == ace and tp[3] == "RecruitOfficer_blacklegion",
		"ov {1 leader, 2 ace}: ships fly the named templates, row 3 its rank template ("..MC_Join(tp)..")");
	fl, sh, tp = MC_Build({[3]=lead});
	HOST_Check(fl and tp[1] == "RecruitAce_blacklegion" and tp[2] == "RecruitAce_blacklegion" and tp[3] == lead,
		"ov {[3] leader}: only row 3 named, the big ship of the proposal 5.2 rule 1 ("..MC_Join(tp)..")");
	fl, sh, tp = MC_Build({ace, 7, {}});
	HOST_Check(fl and tp[1] == ace and tp[2] == "RecruitAce_blacklegion" and tp[3] == "RecruitOfficer_blacklegion",
		"ov entries that are not strings are ignored ("..MC_Join(tp)..")");
	HOST_Check(getglobal("flight_trf_mc1") == nil and getglobal("ship_trf_mc1_1") == nil and getglobal("pilot_trf_mc1_1") == nil,
		"no flight_/ship_/pilot_ globals left");
end;

-- c: fallback without the merge; nil ov unchanged ----------------------------------------
if sc == "c" then
	h.mcp_merged = nil;
	local lead = TRF_McName("blacklegion", 0, 0);
	local ace = TRF_McName("blacklegion", 2, 0);
	h.mcp_ret = "arg";
	local fl, sh, tp = MC_Build({lead, ace});
	local calls = MC_Join(h.mcp_calls);
	HOST_Check(fl and getn(sh) == 3 and tp[1] == "RecruitAce_blacklegion" and tp[2] == "RecruitAce_blacklegion"
		and tp[3] == "RecruitOfficer_blacklegion" and h.fails == 0,
		"CreatePilot returns its argument: each ship falls back to its rank template, AssignPilot gets a pilot ("..MC_Join(tp)..")");
	HOST_Check(calls == lead..",RecruitAce_blacklegion,"..ace..",RecruitAce_blacklegion,RecruitOfficer_blacklegion",
		"CreatePilot order: named template, then the fallback ("..calls..")");
	h.mcp_ret = "one";
	fl, sh, tp = MC_Build({lead});
	HOST_Check(fl and tp[1] == "RecruitAce_blacklegion" and h.fails == 0, "CreatePilot returns 1: fallback to RecruitAce_blacklegion ("..MC_Join(tp)..")");
	fl, sh, tp = MC_Build(nil);
	calls = MC_Join(h.mcp_calls);
	HOST_Check(fl and tp[1] == "RecruitAce_blacklegion" and tp[2] == "RecruitAce_blacklegion" and tp[3] == "RecruitOfficer_blacklegion"
		and calls == "RecruitAce_blacklegion,RecruitAce_blacklegion,RecruitOfficer_blacklegion",
		"ov nil: one CreatePilot per ship with the rank template, as before ("..calls..")");
	fl, sh, tp = MC_Build({});
	HOST_Check(fl and MC_Join(h.mcp_calls) == calls, "ov {}: the same calls as without ov");
end;

if sc ~= "a" and sc ~= "b" and sc ~= "c" then print("HOST FAIL host_pilots.lua: TRF_MCP must be a, b or c"); exit(1); end;
print("traffic: host_pilots "..sc.." done");
if h.errors > 0 or h.fails > 0 then exit(1); end;
exit(0);
