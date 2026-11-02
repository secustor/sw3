# Combat state for the traffic mod (`TRF_Combat()`)

Target `sw3cw.exe` (GOG v1.12, same file as movie-state.md). Vanilla scripts from `~/Games/Heroic/sw3-tp-test/Data/Scripts` (cp1251 → utf-8). Exe: Hopper via REA plus `.work/exe.asm`. Tags: **[V]** verified (script line or decompiled code), **[I]** inferred, **[G]** guessed.

## 0. Answer

The engine exposes no "in battle" query to Lua. No native returns a ship's target, attacker, max HP or an under-attack flag [V, lua-natives.tsv]. Combat can be detected with three sources:

1. The mothership's `GetCurHP` dropping between ticks. This is cheap, needs no trigger and catches vanilla enemies too.
2. The `attack` triggers the mod already arms, with `PLAYER_GROUP` as the attacker of a mod ship. Every hit callback passes through `TRF_Cb`, so one hook covers all of them.
3. Raid records in state `demand`/`fight` (mod traders under attack).

`TRF_Combat()` only compares `TRF.live.cbt` (the game time of the last hostile event) with `combat_hold` (25 s). The sampling happens in `TRF_Safety_Tick`, which runs every 250 ms.

## 1. Engine primitives

### 1.1 Trigger kinds (include/NewTriggers.script) [V]

| kind | event | args | use for combat |
|---|---|---|---|
| `attack` | `_EVENT_ATTACKCARCASS` (24) | (group, carcass) :120-123 | **yes**: fires when a ship of *group* has hit *carcass*. The group must be named, and there is no "any attacker" form (1.2). |
| `HP` | `_EVENT_ONHEALTH` (18) | (carcass, hp) :104-107, `SetHealth(hp, TRUE)` | one-shot threshold, not a hit stream. Already used for the trader low-HP flee (trf_raid.script:1799) |
| `died` / `f_died` | `_EVENT_OBJECTDIED` / `_EVENT_FLIGHTDIED` | (carcass) / (flight) | death only. Delete also ends the ship, so a death does not prove a fight [I] |
| `reps` | `_EVENT_GROUPRELATION` (23) | (group, group, rep) :114-116 | relation change, not fighting |
| `group_near_group` | `_EVENT_GROUPINSIDEGROUPVOLUME` | (g, g, r) | proximity only |

Trigger context of `attack`: `GetObject` (the carcass) and `GetGroup` (the configured group) only [V, lua-natives.md:545]. It does not report which ship fired.

### 1.2 How `_EVENT_ATTACKCARCASS` matches [V exe]

- `TriggerAttackCarcass_SetGroup` (Lua binding 0x5cc695) takes a group name string or a Group table (vanilla passes both: `PLAYER_GROUP`, and `Pirate_Group` in Quests/mission_13a/SavingFriend_a_XT24.script:252). It stores the name with 0x4bc8a0 at trigger `+0xbc`.
- Trigger update 0x4bca40: drops a dead carcass, looks the group up by name each update (0x458650), then calls 0x610ac0. 0x610ac0 scans a vector of group pointers on the carcass (`carcass+0x8f0..0x8f4`) for that group. On a match it builds event 0x18 and fires it (0x4bc1b0). The list is cleared when the counter `carcass+0x8e8` reaches `+0x8e4` (0x610b20).
- Consequence: an `attack` trigger only answers "did group G hit this carcass recently". There is no wildcard. A group name that does not exist yet just never matches [I: per-update lookup]. Any ship of `PLAYER_GROUP` counts, including the player's fighters [I: the list holds group pointers, not ships].
- The list is filled by weapon hits [I; the writer was not located. 0x60e680 is the save routine for that vector].

### 1.3 Object queries [V lua-natives.tsv]

| native | result | cost / note |
|---|---|---|
| `GetCurHP(carcass)` 0x5e2d50 | float `carcass+0xd4` (one field, hull HP) | id lookup plus one load. Logs "Carcass_GetCurHP: no carcass found" on a dead id, so check `IsAlive` first |
| `GetPlayerMotherShip()` 0x5dd780 | Carcass table (field `id`) | one table allocation per call |
| `:IsAlive()` | bool | cheap |
| `GetMaxHP`, `GetHP`, `GetTarget`, `IsAttacked`, `IsUnderAttack`, `GetAttacker` | **do not exist** | `GetTargetObject` exists only on the volume event classes (lua-natives.md:540,551) |
| `GetCarcassCountInSphere(pos, r)` 0x5e68f0 | count of all carcasses, no side filter (decompiled: 2 args, x/y/z + radius) | not a hostility test |
| `GetGroupRelation(g, PLAYER_GROUP)` | relation 0/1/2 | static stance, not activity |
| player fighters | **no enumeration native** (no player-ship list; `GetPilot(name)` needs a known name) | fighters are only visible through `PLAYER_GROUP` triggers |

`AddMusicToBattlePlayList` shows the engine keeps a battle-music state internally. Lua has no read for it [V: no getter in the native list].

### 1.4 How vanilla detects fighting [V]

- No generic detection exists. Quests arm `attack` triggers with a known enemy group: `NewTrigger("attack", TrueCondition, Validol_Nha, Pirate_Group, mothership)` (mission_13a..e SavingFriend_*_XT24.script:252). They also use `HP` thresholds on specific ships (mission_19a NewAcquisition_XT86.script:191, mission_16d NightRaid_Vulcan.script:608) and `SetAllDied` for the end of a battle.
- RandomContacts: `NewTrigger("attack", TrueCondition, Call_SOS_command, PLAYER_GROUP, _ship)` on the trader leader (RandomContacts.script:294, 312).
- **`Call_SOS_command` / `Call_SOS_command2` (RandomContacts.script:457-498) do not read `__sys_SOS`.** The flag gates only `_FTrader_Action` (contact, :379), Fmerc chat (RandomFmerc.script:211), the patrol fine and the extortion (OutOfMission.script:300, 320, 354, 386, 478).
- Quests save the mothership HP, set `SetHP(100000)` for a scripted scene and restore it afterwards (mission_1 ReturnHero.script:138/139/237, 354/355/375, 1411/1412/1431). The restore looks like a large HP drop, so an HP poll must ignore it (2.3).

### 1.5 What the mod already has [V]

| source | where | fires on |
|---|---|---|
| trader transports | trf_events.script:370, 445 `TRF_OnAttack` (+ T_deliberate, heat at :398) | player hits a mod trader |
| raid ships | trf_raid.script:962, 1532 `TRF_OnRaidHit` → `TRF_Rd_HitBody` :1539 (`rd.ph = 1`, `rd.lh[j] = gt`) | player hits raiders |
| raid leader low HP | trf_raid.script:1785 `TRF_RaidArmLowHP` → `HP` trigger at 0.5 x hp0 → `TRF_OnLowHP` :1774 | trader leader damaged by pirates |
| response flights | trf_events.script:805 `TRF_OnRespHit` | player hits the response flights |
| base, convoy, feq, sweep, carrier | trf_base:711 `TRF_OnBaseHit`, trf_convoy:796 `TRF_CvEscHit`, :1341 `TRF_FeqAttack`, trf_faction:900 `TRF_CtJoinPart`, :959 `TRF_SwHit`, trf_clan:875 `TRF_OnCarrierHit` | player hits these |
| parked freighter | trf_freight.script `TRF_Fr_ParkHit` (the parked Wolves Freight ship at its home station) | player hits the parked freighter |
| raid states | `TRF.live.rd[n].st`: armed, wait, launch, come, demand, fight, leave, end (trf_raid.script:1163, 1193, 1302, 1367, 1478) | pirates vs trader |
| heat | trf_state.script:737 `TRF_AddHeat(d, why)` | late: after T_deliberate (5 hits in 20 s) or a kill |

All hit shims call `TRF_Cb(name, body, args)` (traffic.script:87), directly or through `TRF_Rd_Cb2`/`TRF_Cl_Cb2` [V]. Every trigger is armed with `PLAYER_GROUP` as the attacker. Nothing tells the mod when a *mod* hostile hits the *player*, except the HP poll (or source a3 below).

## 2. Design (trf_safety.script)

### 2.1 Sources

| id | source | how | cost |
|---|---|---|---|
| a1 | mothership HP drop | sample `GetCurHP(ms)` every safety tick and mark when it drops by `> combat_hp` (and by `< 50 %` in one sample) | 2 natives + 1 IsAlive per 250 ms |
| a2 | player hit a mod ship | name set in `TRF_Cb`: `TRF_OnAttack, TRF_OnRaidHit, TRF_OnRespHit, TRF_OnBaseHit, TRF_CvEscHit, TRF_FeqAttack, TRF_SwHit, TRF_CtJoinPart, TRF_OnCarrierHit, TRF_OnLowHP, TRF_OnPlayerHit, TRF_Fr_ParkHit` | one table index per callback |
| a3 (optional) | mod hostile hit the mothership while shields absorb the damage | `NewTrigger("attack", nil, "TRF_OnPlayerHit(k,gen)--", gname, ms)` when a mod group goes to WAR with `PLAYER_GROUP` (`TRF_Rd_War1` trf_raid:1514, trf_base:1129, trf_clan:928, trf_convoy:1404/1559, response spawn) | one trigger per hostile group, re-armed up to `arm_max` |
| b | mod trader under attack | sample: an open raid record with `st == "demand"` or `"fight"` within `combat_r` of the mothership | loop over `live.rd` (0-2 records) + 2 positions |
| - | fighters vs vanilla enemies away from the mothership | not detectable (1.3) | - |

Do not reuse `TRF_AddHeat` as a source. Heat rises only after T_deliberate or a kill, so it comes late, and its `why` strings ("attack id", "feq kill", "contract", "base") include non-combat decreases. The a2 hook sees the same hits earlier.

### 2.2 State (plain numbers in `TRF.live`, no handles)

`cbt` gt of the last hostile event, `cbw` its source (log), `cbh` the last mothership HP, `cbi` the mothership `id` of that sample, `cbs` gt of the last sample taken while a scene was visible, `cbg[k]` names of the groups armed for a3. `TRF_LiveReset` rebuilds `TRF.live`, so these clear per visit. `TRF_SafeVisitReset` and `TRF_Safety_OnLoad` also set `cbh, cbi, cbs = nil`, so a load never compares HP across the load. Tune keys: `combat_hold` 25, `combat_hp` 1, `combat_r` 1500 (0 = whole system), `combat_scene` 3, `combat_hit_n` 2, `combat_hit_win` 6 (a2 debounce, section 6). Debounce fields `cbk` (whole seconds of recent a2 hits) and `cbp` (second of the last pending line) are cleared with the others.

### 2.3 Code (Lua 4)

```lua
-- Pure: 1 while the last hostile event is younger than hold.
function TRF_CombatOf(cbt, gt, hold)
	if type(cbt) ~= "number" or type(gt) ~= "number" then return nil; end;
	if gt - cbt < hold then return 1; end;
	return nil;
end;

-- Pure: 1 for a hit-sized HP drop (rejects SetHP restores of quest scenes and ship swaps).
function TRF_HpDropOf(old, new, d)
	if type(old) ~= "number" or type(new) ~= "number" or old <= 0 then return nil; end;
	local dd = old - new;
	if dd > d and dd < 0.5 * old then return 1; end;
	return nil;
end;

-- 1 while the player or a mod trader is in combat (R2c). Reads only TRF.live.
function TRF_Combat()
	local L = TRF_SafeLive();
	if not L then return nil; end;
	return TRF_CombatOf(L.cbt, TRF_SafeGt(), TRF_SafeTune("combat_hold", 25));
end;

-- Record a hostile event now; logs the onset only.
function TRF_CombatMark(why)
	local L = TRF_SafeLive();
	if not L then return; end;
	local gt = TRF_SafeGt();
	if not TRF_CombatOf(L.cbt, gt, TRF_SafeTune("combat_hold", 25)) then
		TRF_SafeL("combat on why="..tostring(why).." gt="..TRF_F(gt));
		TRF_SafeStat("combat_on");
	end;
	L.cbt = gt;
	L.cbw = why;
end;

-- Mothership HP and id, or nil.
function TRF_Safe_MsHp()
	local ms = TRF_N("GetPlayerMotherShip");
	if not ms or type(ms) ~= "table" and type(ms) ~= "userdata" then return nil; end;
	if not TRF_Is(ms:IsAlive()) then return nil; end;
	local hp = TRF_N("GetCurHP", ms);
	if type(hp) ~= "number" then return nil; end;
	return hp, ms.id;
end;

-- Raid n with st demand/fight near the mothership (trf_raid helper, nil when unknown).
function TRF_Safe_RaidHot(rd, r)
	for n, x in rd do
		if type(x) == "table" and (x.st == "fight" or x.st == "demand") then
			if r <= 0 then return n; end;
			local d = TRF_N("TRF_RaidMsDist", n);
			if type(d) ~= "number" or d <= r then return n; end;
		end;
	end;
	return nil;
end;

-- Called from TRF_SafetySample (every safety tick).
function TRF_CombatSample()
	local L = TRF_SafeLive();
	if not L then return; end;
	local gt = TRF_SafeGt();
	local hp, id = TRF_Safe_MsHp();
	if TRF_Safe_Scene() then L.cbs = gt; end;
	local fresh = type(L.cbs) == "number" and gt - L.cbs < TRF_SafeTune("combat_scene", 3);
	if not fresh and id == L.cbi and TRF_HpDropOf(L.cbh, hp, TRF_SafeTune("combat_hp", 1)) then
		TRF_CombatMark("mshp");
	end;
	L.cbh = hp; L.cbi = id;
	if type(L.rd) == "table" then
		local n = TRF_Safe_RaidHot(L.rd, TRF_SafeTune("combat_r", 1500));
		if n then TRF_CombatMark("raid "..n); end;
	end;
end;
```

trf_raid helper (handles stay in `H.rd`):

```lua
-- Distance raid n's first live ship to the mothership, or nil.
function TRF_RaidMsDist(n)
	local H = TRF_Rd_H();
	if not H or type(H.rd[n]) ~= "table" then return nil; end;
	local sh = H.rd[n].sh;
	if type(sh) ~= "table" then return nil; end;
	for j = 1, getn(sh) do
		if TRF_Rd_Alive(sh[j]) then return TRF_Rd_Dist(sh[j]:GetPosition(), TRF_Rd_MsPos()); end;
	end;
	return nil;
end;
```

a2, traffic.script (chunk local, read with `%`; the name set does not depend on gen, because a stale-gen hit is still a hit in this scene):

```lua
local CBH = {TRF_OnAttack=1, TRF_OnRaidHit=1, TRF_OnRespHit=1, TRF_OnBaseHit=1, TRF_CvEscHit=1,
	TRF_FeqAttack=1, TRF_SwHit=1, TRF_CtJoinPart=1, TRF_OnCarrierHit=1, TRF_OnLowHP=1, TRF_OnPlayerHit=1};

function TRF_Cb(name, f, args)
	if type(f) ~= "function" then return nil; end;
	if %CBH[name] and type(TRF_CombatMark) == "function" then call(TRF_CombatMark, {name}, "x", TRF_Err); end;
	return call(f, args, "x", function(m) TRF_CbErr(%name, m); end);
end;
```

a3 (optional; numeric key, so the action string needs no quoting):

```lua
function TRF_CombatArm(gname)
	local L = TRF_SafeLive();
	if not L or type(gname) ~= "string" or type(NewTrigger) ~= "function" then return nil; end;
	if type(L.cbg) ~= "table" then L.cbg = {}; end;
	local k = getn(L.cbg) + 1;
	L.cbg[k] = gname;
	return TRF_CombatTrig(k);
end;

function TRF_CombatTrig(k)
	local ms = TRF_N("GetPlayerMotherShip");
	if not ms then return nil; end;
	return NewTrigger("attack", nil, "TRF_OnPlayerHit("..k..","..TRF.gen..")--", TRF.live.cbg[k], ms);
end;

function TRF_OnPlayerHit(k, g) TRF_Cb("TRF_OnPlayerHit", TRF_Safe_PHitBody, {k, g}); end;

function TRF_Safe_PHitBody(k, g)
	local L = TRF_SafeLive();
	if g ~= TRF.gen or not L or type(L.cbg) ~= "table" or not L.cbg[k] then return; end;
	L.cba = (L.cba or 0) + 1;
	if L.cba <= 200 then TRF_CombatTrig(k); end;
end;
```

Hook: `TRF_SafetySample` calls `TRF_CombatSample()` at its end. `TRF_Safety_Dump` adds `combat=..` and `cbw`.

## 3. Read sites

Legend: **C** = `TRF_Combat()`, **Q** = `TRF_Quiet()` (scene + `__sys_SOS`; lines and boxes only), **S** = `TRF_Supp() ~= 0`. `__disableAction` stays in every site through S (dis → 2).

| file:line (function) | protects | replace with | reason |
|---|---|---|---|
| trf_hail:149 `TRF_HlSupp` ← `TRF_HailOpen` :421 | hail menu/line on focus | S or Q or C | modal talk; must not pop up mid-fight or in a quest sequence |
| trf_hail:1217 `TRF_BoardDockOk_Body` | board box at patrol dock | Q | the player chose to dock and the vanilla dialog runs anyway; a fight does not matter |
| trf_raid:541 `TRF_Rd_Supp` ← `TRF_Rd_Gate` :563 (lane and staged raids) | new raid | S or C | no new raid into a fight. The open-raid `busy` check already covers the mod's own raids. Return why `"combat"` |
| trf_raid:1187 `TRF_Rd_Meet`, :1213 `TRF_RaidDecide` | running raid | S only | C would make every raid leave because of its own fight (and `rd.ph` already drives refuse) |
| trf_clan:670 `TRF_Cl_Gate` (via `TRF_Rd_Supp`) | new on-screen carrier | S or C | same as new raid |
| trf_clan:1319 carrier wave launch | running carrier | S only | the waves are the fight |
| trf_events:113 `TRF_Ev_Supp` ← `TRF_RespStart` :618, `TRF_RespSpawn` :740 | attack response | S only | vanilla parity: `Call_SOS_command(2)` has no `__sys_SOS` check (RandomContacts:457-498), and C cannot be used because combat is what causes the response |
| trf_events:771 `TRF_RespLine` | second response line | S or Q | it is a line |
| trf_faction:215 `TRF_FcSupp` ← sweep entry :774, `TRF_SweepStart` :792 | new sweep | S or C | no sweep launched into a fight |
| trf_faction:919 `TRF_SweepWave`, :1018 `TRF_FcStepBody` | running sweep | S only | C would wind down the sweep because of its own fight |
| trf_faction:1337 `TRF_FcPoBody` | offer box at dock | Q | dock box; player-initiated |
| trf_supply:214 `TRF_SpSupp` ← `TRF_SupplyRoll` :524 | supply run spawn | S or C | spawn kind; no escorted run into a fight |
| trf_supply:923 `TRF_DemandOk` | demand option in the hail menu | Q | talk option; hail already gated |
| trf_supply:1124 `TRF_SpRelBody` | heat offer box at relation dock | Q | dock box |
| trf_danger:212 `TRF_DcGate` | new danger convoy | C (S is already on :213) | spawn kind |
| trf_danger:626, :1122 | already S only | unchanged | running convoy, contract |

**Parity recommendation**: keep vanilla parity for the attack response (no `__sys_SOS`, no C). The strict and quest gate (`TRF_StrictOk`) already stops mod traders from existing in quest systems, and commit 587e4f4 set the rule that `__sys_SOS` only mutes chatter. Only the response's line goes through Q (`TRF_Say` already does that for the first line).

Tests to update: host_v02.lua:752-755 (raid gate under `__sys_SOS` → expect `"combat"` with a marked combat instead), :960-962 (staged roll under `__sys_SOS` → under combat). :1282-1286 (board under `__sys_SOS`) still holds through Q.

## 4. Host-harness stubs (tests/host_stubs.lua)

| need | current | change |
|---|---|---|
| `attack` shape | `a == PLAYER_GROUP and HOST_IsObj(b)` (:883) | also accept a string or `HOST_IsGroup` group as `a` and `HOST().ms` as `b` (a3) |
| mothership HP | `HOST().ms` has no `hp`; `GetCurHP` returns `o.hp` (:511) | `HOST().ms.hp = 1000; HOST().ms.id = 1` (and `SetHP`). Scenarios: `ms.hp = ms.hp - 50` then tick, `ms.hp = 100000` during `h.mov = 1` then restore |
| fire a3 / a2 | `HOST_Fire("attack", pre)` (:923) | exists |
| `HP` kind | exists (:884) | - |
| `GetTarget`, `GetMaxHP`, `IsAttacked` | - | none (they do not exist in the game; a stub would hide misuse) |
| clock | `HOST().gt` | advance by more than `combat_hold` to test the decay |

Cases: HP drop → C 1, after 26 s → nil; scene restore drop → nil; ship swap (`ms.id` changes) → nil; raid `st = "fight"` near → 1, far (`combat_r`) → nil; a2 callback name → 1; `TRF_Rd_Gate` → `"combat"` while `TRF_RaidDecide` still runs; response spawns under `__sys_SOS = TRUE`.

## 5. Open risks

| risk | effect | mitigation |
|---|---|---|
| HP drop from collisions, mines, asteroids, damaging clouds [G] | false combat for 25 s; constant in a damaging area | `combat_hp` threshold; option: require 2 drops in 5 s; log `cbw=mshp` to measure in game |
| shields absorb hits, so hull HP does not move [I] | the start of a fight is missed | a3 for mod hostiles. Vanilla hostiles are counted once the hull is hit |
| fighters fighting vanilla ships away from the mothership | not detected | no native; accepted |
| distant raid (`combat_r`) | false combat system-wide (hail, supply, danger blocked) | distance test in the sample |
| friendly fire on a neutral trader | a2 marks combat | correct: player fire is combat for these gates |
| quest `SetHP(100000)` restore and `SetPlayerMotherShip` swaps | large drop | the `< 50 %` per-sample cap, `combat_scene` hold-off after a scene, `ms.id` compare |
| a3 trigger cost | per-update group-name lookup per trigger (0x4bca40) [V], so cost grows with the number of armed groups | arm only on WAR, cap 200 re-arms per visit, gen check |
| `ATTACKCARCASS` firing rate under sustained fire | unknown (existing CHECK trf_events.script:432) | a2 needs hits in only `combat_hit_n` (2) distinct seconds, and the re-arm caps already exist |
| a single attributed hit or a stale trigger raises a2 (in game 2026-10-22: one `TRF_OnAttack` with `ev attack id=7 stale gen=39`, a record dropped at load; shorthand form of that run's log) | false combat for 25 s | in place (2026-10-22): `TRF_Cb` marks only when the callback's gen argument is the current `TRF.gen`, and a2 starts combat only after hits in `combat_hit_n` (2) distinct seconds within `combat_hit_win` (6 s), debug `module=safety event=combat_hit_pending hit_count=1 hits_needed=2`. Rams do not fire a2 at all: collision damage has no source object, so `_EVENT_ATTACKCARCASS` is never raised (mod-research/damage-type.md) |
| combat holding back the mod's own content | C used in running sites would cancel raids or sweeps | C only at spawn and open gates (table 3) |

## 6. Implementation (2026-10-21)

Built as in 2-4 with these differences: `combat_hp` defaults to 0.5 (HP units); `TRF_OnLowHP` is not in the a2 name set (pirates hitting a trader can be far from the mothership, so source b with its distance test covers it); a3 is not built; the live field `cbl` (1 while "combat on" is logged) gives one log line per transition; `TRF_SafeVisitReset` clears all `cb*` fields. The hail on focus skips with reason `flag` (`__disableAction`, `TRF_Supp`), `quiet` (`TRF_Quiet`) or `combat`. trf_station and trf_ui no longer fall back to `__sys_SOS` without trf_safety.

2026-10-22, a2 debounce (`TRF_CombatHitOk`, traffic.script `TRF_HitSecsOf`): outside combat a hit through `TRF_Cb` starts combat only when hits were seen in at least tune `combat_hit_n` (2) distinct whole seconds within `combat_hit_win` (6 s), the shape of `TRF_Ev_Deliberate`. Until then the hit seconds stay in `live.cbk` and one debug line `module=safety event=combat_hit_pending hit_count=1 hits_needed=2 source=...` is logged per window; the line `module=safety event=combat_on reason=hit` stays at the trip. A hit while in combat refreshes the hold as before. `TRF_Cb` marks only when the gen argument of the shim (position per name in `CBH`) is the current `TRF.gen`, so a stale trigger never counts. Sources hp and raid are unchanged. Host: `T_Combat` in traffic-g.
