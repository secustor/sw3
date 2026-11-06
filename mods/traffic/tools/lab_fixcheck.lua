-- Load check of a staged TRF table under stock Lua 4.0.1 (no game): used by mk_lab_saves.sh through
-- mk_lab_saves.py --check. Loads the mod scripts with the host harness of tests/host_station.lua, enters
-- LAB_SYS at chapter LAB_CH, replaces TRF with the table in file LAB_TRF (savetool.py get output prefixed
-- "LAB_STG = "), runs the load path (TRF_OnLoad: TRF_Init, TRF_Repair and every module Fix), then prints each
-- key of LAB_KEYS (comma list) of the repaired TRF as one line "LABKEY <key> <json>".
-- Env: TRF_DIR, TRF_TESTS (as run_host.sh), LAB_TRF, LAB_KEYS, LAB_SYS (default elio), LAB_CH (default 8).

local f = openfile((getenv("TRF_TESTS") or "./").."host_station.lua", "r");
if not f then print("LABFAIL cannot open host_station.lua"); exit(1); end;
local src = read(f, "*a");
closefile(f);
local cut = strfind(src, "\n-- a: install (12.1, 6.1)", 1, 1);
if not cut then print("LABFAIL marker '-- a: install (12.1, 6.1)' missing in host_station.lua"); exit(1); end;
dostring(strsub(src, 1, cut), "host_station.lua");

function LAB_Esc(s)
	s = gsub(s, "\\", "\\\\");
	s = gsub(s, "\"", "\\\"");
	return s;
end;

-- JSON of v: sequences 1..n as arrays, other tables as objects with "[n]" keys for numbers.
function LAB_Json(v)
	local t = type(v);
	if t == "number" then return format("%.17g", v); end;
	if t == "string" then return "\""..LAB_Esc(v).."\""; end;
	if t ~= "table" then return "null"; end;
	local n, cnt = 0, 0;
	for k, x in v do cnt = cnt + 1; end;
	while v[n + 1] ~= nil do n = n + 1; end;
	local o = "";
	if n == cnt and n > 0 then
		for i = 1, n do
			if i > 1 then o = o..","; end;
			o = o..LAB_Json(v[i]);
		end;
		return "["..o.."]";
	end;
	local ks = {};
	for k, x in v do
		if type(k) == "number" then tinsert(ks, "["..format("%.17g", k).."]"); else tinsert(ks, k); end;
	end;
	sort(ks);
	for i = 1, getn(ks) do
		local k = ks[i];
		local x = v[k];
		if strsub(k, 1, 1) == "[" then x = v[tonumber(strsub(k, 2, -2))]; end;
		if i > 1 then o = o..","; end;
		o = o.."\""..LAB_Esc(k).."\":"..LAB_Json(x);
	end;
	return "{"..o.."}";
end;

local h = HOST();
h.labels.CurrentQuest = getenv("LAB_CH") or "8";
S_Begin(getenv("LAB_SYS") or "elio", {cap_enable=1, enable_parcels=1, enable_wq=1, temper=1, log=2});
dofile(getenv("LAB_TRF"));
if type(LAB_STG) ~= "table" then print("LABFAIL LAB_TRF did not set LAB_STG"); exit(1); end;
print("LAB ---- load of the staged table");
T_SaveLoad(function() TRF = LAB_STG; end);
local keys = getenv("LAB_KEYS") or "";
local i = 1;
while i <= strlen(keys) do
	local e = strfind(keys, ",", i, 1) or (strlen(keys) + 1);
	local k = strsub(keys, i, e - 1);
	if k ~= "" then print("LABKEY "..k.." "..LAB_Json(TRF[k])); end;
	i = e + 1;
end;
print("LABDONE errors="..h.errors.." fails="..h.fails);
