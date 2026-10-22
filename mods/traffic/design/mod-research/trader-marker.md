# "Ready to talk" marker on traders

Question: can the mod mark which traders are ready to talk (hail armed, mothership within `hail_r`, nothing blocks the hail), and clear the mark after the hail? Static analysis only: `.work/exe.asm` (GOG 1.12 `sw3cw.exe`), vanilla scripts in `~/Games/Heroic/sw3-tp-test/DATA` (G below, scripts converted from cp1251), `Manual.pdf`, the mod sources (S = `mods/traffic/Data/Scripts/Mods/Traffic`). The game was not run. Tags: **[V]** verified in disassembly, bytes or a vanilla call; **[I]** inferred; **[G]** guessed.

## 0. Answer

Yes. Create a nav point with the trader's lead ship as the 5th argument of `CreateNavPoint`, make it blink with `FlashOn`, and delete it when the hail opens or the ready state ends. The engine has a separate attached nav point class that copies the object's position and orientation on every update and lets go of the object when the object dies [V]. Vanilla uses it on moving ships [V]. The mod already uses the same call on the trader lead in `trf_raid` (`TRF_Rd_Nav`, S/trf_raid.script:1652-1666). It costs nothing in Lua per frame. Cleanup follows the raid marker pattern: a fixed label per slot, deleted by label on load and entry.

## 1. Mechanisms

### 1.1 Nav point attached to the ship (top option)

| Fact | Evidence | Tag |
|---|---|---|
| `CreateNavPoint(text, pos, icon, col, obj)`. Each argument is optional by count: with n >= 3 it reads the icon (default `waypoint.dds`), with n > 3 the colour from fields x, y, z of the `RGB()` Vector3 (default 0xFFFFFF), and with n >= 5 `obj.id` | 0x5e9866 (`waypoint.dds` 0x73a598), 0x5e981b, 0x5e9881, 0x5e98a0-0x5e9969, 0x5e996f-0x5e9a1d | V |
| The object goes through the id lookup 0x51f880 and the type check `vtbl+4(0x7b52f8)`. If either fails, the nav point is created static at `pos` and no error is raised | 0x5e99ec-0x5e9a22 | V |
| With an object, `0x5a0e80` allocates 0x104 bytes (ctor 0x5a3840, vtable 0x731738) and calls attach 0x5a3970: object refcount `+0x24` is incremented, the object is stored at `nav+0x100`, and sync runs once. Without an object it allocates 0x100 bytes (ctor 0x5a4530, vtable 0x7318a0) | 0x5a0e9d-0x5a0f1b, 0x5a3970-0x5a39be | V |
| Update (vtable slot 10, 0x5a4730, `retn 4` = dt) runs sync (slot 16) when slot 14 says the object is attached and alive. Sync 0x5a39c0 reads the object's node `obj+0x540`, then copies position (0x403810) and orientation (0x4038a0) into the nav point. The static class has slot 16 = 0x4841f0 (`xor eax; ret`) | 0x5a4730-0x5a4751, 0x5a39c0-0x5a3a5b, 0x5a3df0 | V (calls); I (slot 10 runs every frame) |
| When the object dies or is deleted (`obj+0x20 != 0`), the nav point releases it and stays where it last was. It is not deleted | 0x5a39cd-0x5a39d7, 0x5a3dfa-0x5a3e04 | V |
| Vanilla uses on moving ships: `nav_emperor` on `ship_emp1_1`, red, before `ComeToPortal` | G/Scripts/Quests/mission_19d/Surgery_Vuadil.script:390, 604-612 | V |
| Vanilla: `nav_Treasurer` on `ship_tre1_1` (`nav_pir1.dds`) | G/Scripts/Quests/mission_5_2/Secret_place_Pegas.script:723, 735 | V |
| Vanilla: `nav_current` on `mothership` with `nav_void.dds` (invisible) as the moving end of guidance lines, 59 calls | G/Scripts/Quests/mission_19a/NewAcquisition_XT86.script:97-98 | V |
| Vanilla: mission 3 `nav_Heretic` / `nav_Lastochka` have no 5th argument: they are static at a position | G/Scripts/Quests/mission_3/UnexpectedEncounter.script:123, 178 | V |
| `:FlashOn([period[, rgbA[, rgbB]]])`: looks up the nav point by id (0x5a1170), takes its icon object `nav+0xf8`, and calls 0x5a91a0(period, colA, colB). Defaults: period 0.5 (0x715100), A = (255,0,0), B = (255,255,255) | 0x5e9b70-0x5e9e3c | V (argument parsing); I (A/B are the blink colours) |
| Vanilla calls `FlashOn()` and `FlashOff()` without arguments, also on an attached satellite nav point | mission_8b/TriadaQuest_xt54.script:720-721; mission_16a_1/EmpireUnderFire_Altrabon.script:17, 77 | V |
| `SetNavPointLabel(nav, lbl)` / `GetNavPointByLabel(lbl)` set and find the script label. The label is not drawn | mission_15c/Reconnaissance_XT86.script:112; Locations/Eridan/functions.script:16-21 | V |
| `:Delete()` 0x5e9a90 | vanilla `nav_current:Delete()` NewAcquisition_XT86.script:113 | V |
| Icons: 99 `nav_*.dds` in **G/TEXTURE/** (not `TEXTURE/Interface`). Trader icons: `nav_arba.dds`, `nav_arba_{astra,ber,ino,pir,tri,uss,destroy}.dds`. Also `nav_target`, `nav_default`, `nav_void`, `nav_buoy_station`, `nav_radiopod`, `nav_pir1-4`, `nav_tri1-4`, `nav_battleship`, station and portal icons | `find G -iname 'nav_*.dds'` | V |
| Colour tints the icon (vanilla red emperor `RGB(255,0,0)`, mod raid `RGB(255,80,80)`) | Surgery_Vuadil.script:390 | I |
| Text: the first argument is stored as a String (`nav+0xb0`). Vanilla passes `#L_` keys or `""`. A global key exists: `#UI_FTrader_confirm` = "Free trader" (G/LocData/English/ui_windows.loc) | 0x5a0f1b-0x5a0f27 | V (stored); G (whether a raw non-key string displays) |
| What the player sees: a blinking icon on the ship in the 3D view and on the system map, also listed among the nav points | vanilla quest guidance | I |
| Persistence: location.script nav points survive in the location snapshot (script-runtime.md:54). A runtime nav point is the same class, so it probably goes into the save, but whether the attach link is restored is unknown. The H table is empty after a load either way | - | I / G |

Cost: one nav object (0x104 bytes) and one HUD icon. The engine runs one virtual sync per update. Lua runs no per-frame code, only create and delete, plus the 1 s readiness check of 3.

Cleanup rule: delete on hail open, on any change out of ready, when the lead changes or dies (the nav point stays behind as a detached marker), before a jump (`TRF_Hail_BeforeJump`), and by label `trf_talk_<k>` on load and entry.

### 1.2 Object label and name

| Native | What it does | Evidence | Shown to player | Tag |
|---|---|---|---|---|
| `SetObjectLabel(obj, lbl)` 0x5dd880 | writes to the label registry (0x5d2700) | asm | no, lookup only | V |
| `GetObjectLabel` 0x5dd9c0 (never called) | returns string `obj+0xa0 -> +0x1c` | 0x5ddaa5 | - | V |
| `Carcass:GetName` 0x5e1490 | returns `obj+0x9c -> +0x1c`, the template (hull) name | 0x5e157f | - | V |
| `Carcass:SetName(str)` 0x5dfe40 (never called) | calls virtual `obj vtbl+0x20(str)` | 0x5dff13-0x5dff19 | unknown. If it renames the shared template, every hull of that type changes, and the save or reload could break | G |
| Pilot name on the target panel | comes from the pilot template (`#M_pilot_Name_Trader` "Trader", `#M_pilot_Name_UFTTrader` "FTU pilot"). There is no `Pilot:SetName`. `AssignPilot` of another pilot would change AI and skills | m_pilots.loc | yes, but cannot be changed safely | I |

Verdict: not usable as a marker.

### 1.3 Effects on the ship

| Native | Use | Attach to moving ship | Cleanup | Tag |
|---|---|---|---|---|
| `Carcass:PlayFX("x.shfx")` 0x5e2890 (shader FX on the hull) | `marker.shfx` = alpha pulse 0.1-0.7, 3 s, endless (vanilla satellite marker, TriadaQuest_xt54.script:719). `RepairerReflection.shfx` = endless additive gloss. `Repair.shfx` = 6 s gloss. Files in G/PFX/ShaderFX | yes, on the hull | `:ResetFX()` 0x5e2ac0 (mission_15c/Reconnaissance_XT86.script:323). It clears every shader FX on the ship, cloak included | V (files, calls); I (look on a trader) |
| `Carcass:AddMeshFX("PARTICLESYSTEM", "flare_unl.pst", offset)` 0x5e6530 | endless flare light (emitter life -1, 10/s, size 1), on a station in Locations/Areko/functions.script:132. On moving ships: `mothership:AddMeshFX` mission_7f_01/InoCoHelp_Danstag.script:15, `ship_greyS3_1` mission_11_1/...X297.script:161 | yes (mesh-attached) | `:RemoveMeshFX("flare_unl.pst")` 0x5e6760 | V (calls); I (follows mesh, size on a freighter) |
| `CreatePortalGlow(pos, dir, secs)` 0x5e5fe0 | one-shot portal-arrival flash at a fixed point (RandomContacts.script:477-480, `secs` 3-7) | no | expires | V |
| Other FX types | the exe names only `EXPLOSION` and `PARTICLESYSTEM` next to the AddMeshFX code (0x33cfc0). `AURAFX` / `SHADERFX` / `FLASHFX` are ini section names of their loaders. Lua has no `SetColor`/`SetGlow`/`Highlight`/`AttachEffect`. `DrawBoundSphere` 0x5e3190 is never used and is probably debug | strings, natives list | - | V (names); G (aura not reachable) |

Persistence of FX across a save: unknown [G]. On load, clean up through the ship handles the load pass finds again.

### 1.4 Radar and HUD relation colour

| Fact | Evidence | Tag |
|---|---|---|
| Camera-panel team tabs: enemy red, neutral yellow, friend green | Manual.pdf p.13 "Camera panel" | V (manual) |
| Ship brackets and map icons use the same colours | - | I |
| Colours are not in any data file (no relation colour key under G) | grep | V |
| `SetGroupRelation(g, PLAYER_GROUP, RELATION_FRIEND)` turns trader group `TRF_Trade_<k>` (one per record slot, S/trf_gen.script:795-811) green | - | I |

Side effects: player fighters may cover or escort friends, and the attack order and fire-on-friend behaviour change [G]. `TRF_GnGroup` re-seeds the relation on every call (S/trf_gen.script:805-808), as do the convoy and heat-war setters (trf_convoy.script:1240, 1415-1443), so the colour would flicker or stick. Green already means "friend or escort" to the player. If a save lands while FRIEND is set, the group relation is saved with it [I]. Not recommended.

### 1.5 Text cues

| Mechanism | Evidence | Marks a ship? | Note |
|---|---|---|---|
| `Pilot:Message` / `OutputToScreenLog` (`TRF_Say`) | already used (announce "FTU <name>, open for trade", S/trf_ui.script:546-574) | no | cheapest addition: append "(select to hail)" to the announce |
| `ShowMsgBox` | the hail itself | no | modal |
| `AddPost` "Fresh news" notice, mail icon blinks (Manual p.11) | news-records.md 1.10 | no | persistent mail entry, needs loc keys (`--news`); wrong channel |
| Station board | patrol dock box | no | only while docked |

### 1.6 Guidance line

| Fact | Evidence | Tag |
|---|---|---|
| `CreateLine(navA, navB, RGB, width, flag, a, b)` 0x5ea2e0 looks up both nav points by id (0x5a1170 at 0x5ea4b4 and 0x5ea53b) and builds the line through 0x5a0c30 | asm | V |
| Vanilla form `CreateLine(nav_current, np, RGB(20,80,220), .3, TRUE, .2, 1)`, where `nav_current` is attached to the mothership | NewAcquisition_XT86.script:97-98; mission_3 UnexpectedEncounter.script:180 (static ends) | V |
| The line follows moving ends | vanilla relies on it | I |
| `:Delete()` 0x5ea640 | NewAcquisition_XT86.script:116-118 | V |
| `DrawLine` 0x5ea010 is never used and its arguments are unclear | - | G |

A line needs its own mothership nav point (never reuse the quest global `nav_current`), so it costs 2 nav points and 1 line per trader. "Ready" means within 150 units, so the line would be very short and would add clutter. Useful only as an add-on at longer range.

## 2. Ranking

| # | Option | Feasibility | Player sees | Per frame | Cleanup | Risk |
|---|---|---|---|---|---|---|
| 1 | Attached nav point + `FlashOn` | V (class, sync, vanilla on ships, mod raid precedent) | blinking green freighter icon on the trader, in 3D and on the map | engine sync only | Delete; label probe on load/entry/jump | the icon may take the click meant for the hull (check M9) |
| 2 | Mesh flare `flare_unl.pst` | I | small flare on the hull, 3D only | 1 emitter | RemoveMeshFX | size and visibility at 150 u unknown |
| 3 | Announce text hint | V | one radio or log line | none | none | does not say which ship |
| 4 | Shader FX `marker.shfx` | I | hull pulses translucent | shader | ResetFX (clears cloak too) | looks like a cloak |
| 5 | Line from a mothership nav point | I | blue lane to the trader | 2 nav + 1 line | Delete all three | clutter at short range |
| 6 | Relation FRIEND | I | green tab and bracket | none | restore relation | AI, re-seed conflicts, saves |
| 7 | SetName / labels / PortalGlow | G / no | nothing, or misleading | - | - | - |

## 3. Sketch (top option, Lua 4)

These go in trf_hail. Handles are kept in the never-saved handle table `TRF_H().mk`, beside `H.tr` and the raid `H.nav`; they never go into `TRF` or `TRF.live`, which are saved. The marker needs no trigger: the announce (a trigger callback that already runs through `TRF_Cb`) and `TRF_HailOpen` call it directly, and the 1 s step does the rest. If a died trigger is added later, it uses the string shim `"TRF_OnMkDied("..id..","..TRF.gen..")--"` -> `TRF_Cb("TRF_OnMkDied", TRF_MkOff_Body, {id, g})`.

```lua
function TRF_MkK() return {icon="nav_arba.dds", c={80,255,120}, c2={255,255,255}, per=0.5, max=6, lb="trf_talk_"}; end;

function TRF_MkH()
	local H = TRF_N("TRF_H");
	if type(H) ~= "table" then return nil; end;
	if type(H.mk) ~= "table" then H.mk = {}; end;
	return H.mk;
end;

function TRF_MkSame(a, b)
	return TRF_HlP(function(x, y) if x.id ~= nil and x.id == y.id then return 1; end; return nil; end, {a, b});
end;

-- 1 when a focus on trader id would open the hail now (same gates as TRF_HailOpen, plus arm window and range).
function TRF_MkReady(id)
	local L, r = TRF_HlLive(), TRF_HlRec(id);
	if not L or not r or type(r.ha) ~= "number" then return nil; end;
	if TRF_HlOpt("hail_start", 2) == 2 and not r.hr then return nil; end; -- no focus trigger armed
	local gt = TRF_HlGt();
	if gt > r.ha or (r.hn or 0) >= TRF_HlT("hail_max") or gt - (r.hlt or -1000) < TRF_HlT("hail_cd") then return nil; end;
	if type(L.hl) == "table" or TRF_HlSupp() or TRF_HlRaided(r) or r.st == "wind" or r.st == "gone" then return nil; end;
	local d = TRF_HlDistMs(id);
	if not d or d > TRF_HlT("hail_r") then return nil; end;
	return 1;
end;

function TRF_MkSlot(M)
	local used = {};
	for id, m in M do used[m.k] = 1; end;
	for k = 1, TRF_MkK().max do if not used[k] then return k; end; end;
	return nil;
end;

function TRF_MkOn(id)
	local M, s = TRF_MkH(), TRF_HlLead(id);
	if not M or not s or type(CreateNavPoint) ~= "function" then return nil; end;
	if M[id] and TRF_MkSame(M[id].s, s) then return M[id].o; end;
	TRF_MkOff(id, "lead");
	local k, K = TRF_MkSlot(M), TRF_MkK();
	if not k then TRF_HlStat("mk_full"); return nil; end;
	local col, c2 = TRF_N("RGB", K.c[1], K.c[2], K.c[3]), TRF_N("RGB", K.c2[1], K.c2[2], K.c2[3]);
	local nav = TRF_HlP(CreateNavPoint, {"", s:GetPosition(), K.icon, col, s});
	if type(nav) ~= "table" then TRF_HlStat("mk_fail"); return nil; end;
	TRF_N("SetNavPointLabel", nav, K.lb..k);
	TRF_HlP(function(n, p, a, b) n:FlashOn(p, a, b); end, {nav, K.per, col, c2});
	M[id] = {o=nav, s=s, k=k};
	TRF_HlStat("mk_on");
	return nav;
end;

function TRF_MkOff(id, why)
	local M = TRF_MkH();
	if not M or not M[id] then return; end;
	TRF_HlP(function(o) o:Delete(); end, {M[id].o});
	M[id] = nil;
	TRF_HlDE("marker_off", "trader_id", id, "reason", tostring(why));
end;

-- 1 s step (traffic.script s1 block: TRF_P("TRF_Mk_Step")). No mothership -> do nothing (teardown window).
function TRF_Mk_Step()
	local M, L = TRF_MkH(), TRF_HlLive();
	if not M or not L or type(L.tr) ~= "table" or not TRF_HlMs() then return; end;
	local ids = {};
	for id, m in M do tinsert(ids, id); end;
	for i = 1, getn(ids) do if not TRF_MkReady(ids[i]) then TRF_MkOff(ids[i], "gate"); end; end;
	for id, r in L.tr do if TRF_MkReady(id) then TRF_MkOn(id); end; end;
end;

-- Jump: every handle; load and entry: by label (H is new, the engine may still hold the old nav points).
function TRF_MkAll(why)
	local M = TRF_MkH();
	if M then local ids = {}; for id, m in M do tinsert(ids, id); end; for i = 1, getn(ids) do TRF_MkOff(ids[i], why); end; end;
	local K = TRF_MkK();
	for k = 1, K.max do
		local o = TRF_N("GetNavPointByLabel", K.lb..k);
		if type(o) == "table" then TRF_HlP(function(x) x:Delete(); end, {o}); TRF_HlStat("mk_orphan"); end;
	end;
end;
```

Hooks: at the end of `TRF_UI_Announce`, `call(TRF_MkOn, {id}, "x", TRF_PErr)` when `TRF_MkReady(id)`. In `TRF_HailOpen`, `TRF_MkOff(id, "hail")` right after `r.hlt = gt`. `TRF_MkAll("jump")` in `TRF_Hail_BeforeJump`. `TRF_MkAll("load")` in `TRF_Hail_OnLoad` and on entry (OnActivate). Re-arming after `TRF_HlClose` is picked up by the step. Under the default `hail_start = 2` the menu opens on meet, so the marker only appears for a re-hail, and only when a focus trigger is armed (`r.hr`).

## 4. In-game checks (one experiment kit, log prefix `mk:`)

| # | Step | Pass |
|---|---|---|
| M1 | `CreateNavPoint("", p, "nav_arba.dds", RGB(80,255,120), lead)` on a moving trader | icon stays on the ship for 60 s in the 3D view and on the map; log the nav and ship `GetPosition` every 5 s, they match |
| M2 | `FlashOn()` vs `FlashOn(0.5, RGB(80,255,120), RGB(255,255,255))` | default blinks red/white (if not, record what it does); the argument form blinks green/white |
| M3 | text `""` vs `"#UI_FTrader_confirm"` vs a raw string | which texts show next to the icon |
| M4 | kill the lead | the nav point stays at the death spot (detached); the step deletes it or moves it to the new lead within 1 s |
| M5 | hail opens / closes with hails left / cooldown passes | marker gone at open; back after `hail_cd` while in range |
| M6 | start combat, a scene, `__disableAction` | marker off; back after |
| M7 | save with a marker, then load | `mk_orphan` count (found by label: yes or no), no marker left, `ScriptErrors.log` empty |
| M8 | jump with a marker, return | none left in either system |
| M9 | click the icon, click the hull | the focus trigger still fires (`hl_focus` stat); note whether the icon click selects the nav point or starts autopilot |
| M10 (opt.) | `lead:AddMeshFX("PARTICLESYSTEM", "flare_unl.pst", Vector3(0,0,0))`, then `RemoveMeshFX` | visible at 150 u; follows the ship; removed cleanly |
