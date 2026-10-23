# Read natives a DLL could add (inventory, modules, ships, markets, time, AI, recruits)

Target `sw3cw.exe` GOG v1.12, image base 0x400000, no ASLR. Static work only: `.work/exe.asm` (objdump), file bytes via `.work/scripts/rd.py`, and Hopper pseudo-code through REA (worked in this session). The game was not run. Nothing here is implemented. Tags: **[V]** read from the asm or the file bytes, **[I]** inferred (meaning, runtime behaviour, or a link not read end to end). Helper used for this note: `.work/hooks/natives/f <va> [n]` prints cleaned asm from `exe.asm`.

Related: [../lua-natives.md](../lua-natives.md) (registrations), [../sensor-module-read.md](../sensor-module-read.md) (handle resolution, slot chain, guarded-read C helpers), [../carcass-count.md](../carcass-count.md) (layer lists, class tree), [../key-input-native.md](../key-input-native.md), [../hook-options.md](../hook-options.md) section 4 D, [../ships/shop-save.md](../ships/shop-save.md).

## 0. Result

| # | Target | Feasible | Native | Confidence |
|---|---|---|---|---|
| 1 | Player inventory: modules with counts, stock ships | yes, pure reads + IsKindOf | `TRF_InvList(carcass)` | high |
| 2 | Installed modules of a carcass, hull/module `cost` | yes, pure reads + IsKindOf | `TRF_Modules(c)`, `TRF_CarcassInfo(c)` | high; `cost` = shop base price medium |
| 3 | Player ships (mothership, hangar, in space) and all carcasses with team, template, position, HP | yes, pure reads | `TRF_Carcasses()`, `TRF_Hangar()` | high; position cache and hangar slot meaning medium |
| 4 | Market stock and coefficients per item | yes, one engine call (lookup 0x4eb950) | `TRF_MarketGet(shop, black)` | high layout; "cur = what the trade window shows" medium |
| 5 | Ship cargo | yes, same native as 1 | `TRF_InvList(ship)` | high for carried cargo; death drop not traced |
| 6 | Pause, time mode/scale, game clock, real time | yes, pure reads | `TRF_Time()` | high |
| 7 | AI state / current order | partly: state of every pilot; target only for attack, ComeToPortal, ComeToTradeStation | `TRF_AiState(x)` | high state, medium target |
| 8 | Recruits of a location | partly: offers of the last opened station window only; no per-location store | `TRF_Recruits()` | medium |

Build first: **`TRF_Carcasses()`** (section 3). It closes the largest gap in lua-natives.md ("no query that lists objects"), needs no engine call, and gives the mod team, template, HP and position of every ship in the location: spawn-spot checks without the scenery baseline of `GetCarcassCountInSphere`, finding traders the mod did not create or label, and the player's own ships. Its helpers (registry walk, `tname`, weak refs, class id) are the base for every other native here. Second: `TRF_InvList` (sections 1 and 5), which answers player inventory and NPC cargo with one body.

## C. Common engine facts and helpers

### C.1 Facts every native below relies on [V]

| Item | Read | Evidence |
|---|---|---|
| Root | `R = [0x7ba610]`; `[R]` Game, `[R+0x18]` LayerManager, `[R+0x38]` ModuleManager, `[R+0x44]` TimeManager, `[R+0x4c]` TeamManager, `[R+0x7c]` TradeSystem, `[R+0x88]` RecruitManager | assert strings at 0x61a3eb (`g_ModuleManager`), 0x49dfc0 (`g_TeamManager`), traffic.c `ROOT_SLOT` |
| Lua handle | table with field `id` = object uid `[obj+0x94]`; resolver 0x51f880 walks `[[R+0x18]+0x20]` (node data +0, next +8, `obj = data-8`) | sensor-module-read 2.1-2.2 |
| Kind test | `IsKindOf` = `(obj+4)->vtbl[1](classval)`, thiscall, `ret 4`, no side effects: BigCarcass's body 0x615480 only compares the argument with class globals (`39 05 24 53 7b 00 ...`) | 0x615480 |
| Class values | `[0x7b52f8]`=2 BaseCarcass, `[0x7b5560]`=3 ShipCarcass, `[0x7b5324]`=4 BigCarcass, `[0x7b31d4]`=0x3e Pilot, `[0x7b4a88]`=0x3d GamePlayer (file values; read at call time) | rd.py |
| Name | `[[obj+0x9c]+0x1c]` = template name `char *` for carcasses and modules; `[obj+0x9c]` is an interned name record (refcount +0x2c) and equal names share one record | 0x5e157f, 0x61b2af (`cmp edi,[ecx+0x9c]` against the interned key) |
| Weak pointer | target `+0x20` != 0 = dead, `+0x24` refcount; the engine clears a dead ref on the next use | 0x61bbeb, 0x61b272 |
| Generic list | head +0, tail +4, count +8, cursor node +0xc, cursor index +0x10; node data +0, next +4, prev +8. Walk from head; never call 0x5f3810 (it moves the cursor) | 0x5f3873, sensor-module-read 2.4 |
| Player team | `0x5be230(eax = [R+0x4c])` returns the GamePlayer team and caches it as a weak ref at `[[R+0x4c]+0x18]`; `0x5adc40(team)` (stdcall, 1 arg) returns the mothership, cached at `[team+0x150]` | 0x5be230, 0x5adc40, traffic.c `g_lsig` |

### C.2 C helpers (shared by the sketches)

The guarded-read helpers `rd_ok`, `rd32`, `rd_name` and the registry walk `ms_find(uid, &obj)` are already drafted in [../sensor-module-read.md](../sensor-module-read.md) 4.4; the sketches use them under these names:

```c
static unsigned rdp(unsigned p, unsigned off) { unsigned v; return p && rd32(p + off, &v) ? v : 0; }
static int alive(unsigned p) { return p && !rdp(p, 0x20); }
static unsigned wk(unsigned p, unsigned off) { unsigned q = rdp(p, off); return alive(q) ? q : 0; }   /* weak ref */
typedef int (__thiscall *iskind_t)(unsigned self, unsigned cls);
static int is_kind(unsigned obj, unsigned clsvar)       /* clsvar = 0x7b5324 etc.; value read at call time */
{
    unsigned sub = obj + 4, vt = rdp(sub, 0), fn = rdp(vt, 4);
    return fn >= 0x401000u && fn < 0x6fb02bu && ((iskind_t)fn)(sub, rdp(clsvar, 0));
}
static unsigned obj_by_uid(lua_State *L, int idx)       /* Lua handle -> object or 0 (GetNumericField 0x5c7820) */
{
    unsigned o = 0;
    if (lua_type(L, idx) != T_TABLE) return 0;
    lua_pushstring(L, "id"); lua_gettable(L, idx);
    if (lua_type(L, -1) == T_NUMBER) ms_find((unsigned)lua_tonumber(L, -1), &o);
    lua_settop(L, -2);
    return o;
}
static const char *tname(unsigned o) { const char *s; return rd_name(o, &s) ? s : 0; }
static int fail(lua_State *L, const char *why) { lua_pushnil(L); lua_pushstring(L, why); return 2; }
static void setfs(lua_State *L, const char *k, const char *v) { lua_pushstring(L, k); lua_pushstring(L, v); lua_rawset(L, -3); }
static void setfn(lua_State *L, const char *k, double v) { lua_pushstring(L, k); lua_pushnumber(L, v); lua_rawset(L, -3); }
```

New Lua API entries the sketches need beyond traffic.c's `g_used_api`: `lua_newtable` 0x65e560, `lua_gettable` 0x65e3a0, `lua_tonumber` 0x65e0c0 (the last two are also requested by key-input-native.md and sensor-module-read.md). Every offset a native reads gets a byte signature checked at init (traffic.c `sig_verify`); a mismatch disables that native (it returns `nil, "sig"`). Natives run on the game thread (Lua calls them), so plain reads are safe from races; the guarded reads only protect against stale pointers.

## 1. Player inventory: modules with counts, stock ships

### 1.1 Where it lives

The player inventory is the `Inventory` object of the current mothership, `[ms+0xff8]`. Every `Inventory:` native reaches it the same way: `0x5adc40(0x5be230([R+0x4c]))` = mothership, then `+0xff8` (IsExist 0x5edcb0, DeleteModule 0x5edbb0, AddShip 0x5edb30) [V]. `GetInventory()` 0x5ed840 is only `0x5c7a80(0x24, 0)`: a class-0x24 handle with id 0, so the Lua `Inventory` object carries no reference and always means "current mothership's inventory" [V]. The GamePlayer team owns the object at `[team+0xd8]` and moves it to `[ms+0xff8]` when the mothership changes (0x4de60d `mov edi,[eax+0xd8]` ... 0x4de638 `mov [esi+0xff8],edi`; same in SetPlayerMotherShip 0x5d4d32, which also copies `[ms+0x102c]` cargoCapacity to `inv+0x58`) [V]. NPC cargo uses the same type on the NPC's own carcass (section 5).

| Object | Offset | Meaning | Evidence | Tag |
|---|---|---|---|---|
| BigCarcass | +0xff8 | `Inventory *`, created by the BigCarcass ctor (0x64 bytes, ctor 0x619bd0) | `89 87 f8 0f 00 00` at 0x61557a | [V] |
| BigCarcass | +0xffc / +0x102c | `cargoCapacity` float property / value | name 0x73d598 at 0x615598, `lea 0xffc(%edi)` at 0x6154f7 | [V] |
| GamePlayer | +0xd8 | owning ref of the player inventory | 0x4de60d | [V] |
| Inventory | +0 | vtbl 0x73dda8 | `c7 06 a8 dd 73 00` at 0x619bf6 | [V] |
| Inventory | +0x3c | entry list (head +0x3c, tail +0x40, count +0x44, cursor +0x48/+0x4c) | ctor zeroes +0x3c..+0x48, `-1` to +0x4c; count read `8b 46 44` at 0x61b249 | [V] |
| Inventory | +0x54 | cached lookup index, -1 = none | set -1 at 0x61a3b2, 0x5e0eb6 path | [V] |
| Inventory | +0x58, +0x5c, +0x60 | floats: capacity (init 999999.0 from 0x745c48), second limit, used [I] | 0x619c13-0x619c27 | [V] layout, [I] meaning |
| Entry (0x7c, ctor 0x61b600, vtbl 0x73dde4) | +0x3c | weak ref to the item object: a module, or a whole ship carcass | `c7 07 e4 dd 73 00 89 77 3c` at 0x61b62f | [V] |
| Entry | +0x40 / +0x70 | `int` count property / value (ctor default 1) | `add [ecx+0x70],edx` at 0x61bbff (0x61bbe0 = add count) | [V] |
| Entry | +0x78 | owning Inventory | `89 4f 78` at 0x61b665 | [V] |

Semantics [V]: `Inventory::AddModuleWithName` 0x61a370 (thiscall-like: `ecx` = name, stack = inventory, count) looks the name up with 0x61b1c0 (linear walk over the list comparing `[[entry+0x3c]+0x9c]` with the interned name), adds `count` to an existing entry or creates one; for a module that IsKindOf the rockets class (0x1a) the count is first multiplied by `[mod+0x7a4]` (0x61a466), so rocket counts are stored in single rockets [V], `+0x7a4` being the pack size is [I]. Ships (`Inventory:AddShip` -> 0x61a520 -> 0x61a5a0) are entries too: the carcass object itself sits in `+0x3c`, its installed modules are first moved into the inventory as separate entries (loop over `carcass+0xf00`, 0x61a616-0x61a80f), and equal ship templates stack in one entry's count (0x61a961). An entry whose ref goes dead is deleted on the next engine access (0x61af58). The list is kept sorted by 0x61a020 (order not decoded).

Module vs ship: same entry type; test the item with `is_kind(item, 0x7b52f8)` (BaseCarcass). Modules are not carcasses [I: module class ids 0x11..0x2f have no carcass parent in the factory table, carcass-count.md 1.2, sensor-module-read 2.6].

### 1.2 Native `TRF_InvList(carcass)`

```c
/* TRF_InvList(carcass) -> { {name=, n=, ship=0|1}, ... } | nil, why
 * Player inventory: TRF_InvList(GetPlayerMotherShip()), the object GetInventory() works on. */
static int __cdecl n_invlist(lua_State *L)
{
    unsigned o = obj_by_uid(L, 1), inv, node, ent, it, cnt, i, k = 0;
    const char *nm;
    if (!g_inv_ok) return fail(L, "sig");
    if (!o) return fail(L, "handle");
    if (!is_kind(o, 0x7b5324u)) return fail(L, "noinv");          /* BigCarcass only, as 0x5e0fee */
    inv = rdp(o, 0xff8); cnt = rdp(inv, 0x44);
    if (!inv || cnt > 1024) return fail(L, "list");
    lua_newtable(L);
    for (i = 0, node = rdp(inv, 0x3c); i < cnt && node; i++, node = rdp(node, 4)) {
        ent = rdp(node, 0); it = rdp(ent, 0x3c);
        if (!alive(it) || !(nm = tname(it))) continue;              /* dead ref: engine drops the entry later */
        lua_newtable(L);
        setfs(L, "name", nm); setfn(L, "n", (double)(int)rdp(ent, 0x70));
        setfn(L, "ship", is_kind(it, 0x7b52f8u) ? 1.0 : 0.0);
        lua_rawseti(L, -2, ++k);
    }
    return 1;
}
```

Lua receives an array of `{name="Laser_1", n=3, ship=0}` rows (template names as in `Data/Game/*.xml`, the same strings `AddModuleToInventory`/`IsExist` take). Signatures: 0x5e100c `8b 88 f8 0f 00 00`, 0x61b249 `8b 46 44`, 0x61b26b `8b 41 3c`, 0x61b2af `39 b9 9c 00 00 00`, 0x61bbff `01 51 70`, 0x61b62f `c7 07 e4 dd 73 00 89 77 3c`, 0x5f3873 `8b 76 04`, 0x615480 `8b 44 24 04 39 05 24 53 7b 00`.

Confidence: high for the layout (every offset [V] in at least two functions); medium that `n` matches what the trade screen shows for rockets (unit vs pack).

Verify in game: note the trade screen's inventory tab, then log `TRF_InvList(GetPlayerMotherShip())`; buy one module and one ship and compare the new rows and counts.

## 2. Installed modules of a Carcass

Object `o` = result of the uid walk 0x51f880 (sensor-module-read.md 2.2); natives test `(o+4)->vtbl[1]([0x7b5560])` (ShipCarcass, file value 3) before using the slot fields (GetMaxSpeed 0x5e3e6b) [V]. Stations and BigShips derive from ShipCarcass (carcass-count.md 1.2), fighters too.

| Offset | Meaning | Evidence | Tag |
|---|---|---|---|
| +0xee4 / +0xee8 / +0xeec / +0xef0 / +0xef4 / +0xef8 / +0xefc | slot pointers: big_guns 0x11, small_guns 0x12, rockets 0x1a, systems 0x1f, turrets 0x15, gk_guns 0x16, TurretGK 0x19 | ShipCarcass slot setup 0x61fed0-0x61ffff: seven `0x623f80` calls, results stored at these offsets; capacity counts from HolderProperties +0x974/+0x9ac/+0x9e4/+0xa1c/+0xa54/+0xa8c/+0xac4 | [V] |
| +0xf00 | list of all slots (the seven above, no others) | 0x623f80 appends the new 0x90-byte slot to `+0xf00` (0x624017-0x62403e); its only callers are the seven sites above | [V] |
| slot pointer 0 | allowed | 0x623f80 returns 0 when the class check 0x4b5690 fails (0x623fb5) | [V] |
| class tree | no separate engine/armor/reactor slots: engines (MovingForceModule 0x24), shields 0x23, radar 0x20, repairer 0x25, cloak 0x21, jammer 0x27, AMS 0x28, boosters 0x29/0x2c/0x2b, cargo expander 0x2f all derive from SystemModule 0x1f and sit in the systems slot | factory registrations (`push parent; push id`, name string 14 lines earlier) 0x6f389d-0x6f57dd | [V] |
| slot +0x3c list (node data +0, next +4), entry `[node]`, module `[entry+4]`, dead `[m+0x20]` | | sensor-module-read.md 2.4-2.5 | [V] |
| `[[x+0x9c]+0x1c]` | template name (char *) of carcass or module; `+0x9c` is an interned name record, not a template object | Carcass:GetName 0x5e157f; Inventory find 0x61b2af compares `+0x9c` with an interned string | [V] |
| +0x44c (int) | `cost` property (prop at +0x41c, int type 0x60ac70, value at prop+0x30) | name 0x72585c pushed at 0x60747c with `lea 0x41c(%edi)` 0x607476; shop UI reads `fildl 0x44c` × coefficient (0x561716, 0x566d3a) | [V] offset, [I] meaning "base price" |
| +0x3dc (float) | `hit_points` (max HP from XML) | name 0x73bcc8 at 0x607404, `lea 0x3ac` 0x6073fe; init copies it to +0xd4 (0x607685-0x607691) | [V] |
| +0xd4 (float) | current HP | GetCurHP 0x5e2e47, SetHP 0x5e2d2b (no clamp); damage code clamps against +0x3dc (0x6108e7-0x6109ac) | [V] |
| +0x414 (float) | `mass` (prop +0x3e4) | name 0x73bcd4 at 0x60742c | [V] |
| +0xd54 (float) | max speed (ShipCarcass) | GetMaxSpeed 0x5e3e89, SetMaxSpeed 0x5e3d5d | [V] |

The cost/hit_points/mass block sits in the shared base ctor 0x607170, called by BaseCarcass 0x60dbd0 (0x60dbf6) and by 0x607830 (module side, callers 0x60c7bf, 0x63051e, 0x63144b) with `this` at offset 0, so the same offsets hold for modules [V for both calls, I that 0x607830 is the BaseModule ctor]. `Carcasses.xml` has 498 `<cost>` tags, `Modules.xml` 282 [V].

```c
static const char *const g_slot[7] = { "big_guns", "small_guns", "rockets", "systems", "turrets", "gk_guns", "turret_gk" };
static int __cdecl n_modules(lua_State *L)          /* TRF_Modules(carcass) */
{
    unsigned o = obj_by_uid(L, 1), slot, node, m; const char *nm; int i, k = 0, guard = 0;
    if (!o || !is_kind(o, 0x7b5560u)) { lua_pushnil(L); return 1; }
    lua_newtable(L);
    for (i = 0; i < 7; i++) {
        if (!(slot = rdp(o, 0xee4 + 4u * i))) continue;
        for (node = rdp(slot, 0x3c); node && guard++ < 256; node = rdp(node, 4)) {
            m = rdp(rdp(node, 0), 4);
            if (!m || rdp(m, 0x20) || !(nm = (const char *)rdp(rdp(m, 0x9c), 0x1c))) continue;
            lua_newtable(L);
            lua_pushstring(L, "slot"); lua_pushstring(L, g_slot[i]); lua_settable(L, -3);
            lua_pushstring(L, "name"); lua_pushstring(L, nm); lua_settable(L, -3);
            lua_pushstring(L, "cost"); lua_pushnumber(L, *(const int *)(m + 0x44c)); lua_settable(L, -3);
            lua_rawseti(L, -2, ++k);
        }
    }
    return 1;
}
```

A second native `TRF_CarcassInfo(c)` returns `{name, cost=[o+0x44c], hp=[o+0xd4], hp_max=[o+0x3dc], mass=[o+0x414]}` after `is_kind(o, [0x7b52f8])` (BaseCarcass, as GetCurHP 0x5e2e29). New Lua API needed: `lua_newtable` 0x65e560, `lua_settable` 0x65e5d0 (add to `g_used_api`). `is_kind` is a thiscall into the engine: `ecx = o+4`, push class value, `call [[o+4]+4]`.

- Lua receives: `{ {slot="systems", name="Radar_3", cost=12000}, ... }`, `{}` for a hull with no modules, nil for a non-ship handle.
- Confidence: high for slots, names, HP, speed; medium for `cost` meaning (offset certain; whether the shop price is exactly `cost × k` for every item type not traced).
- Verify in game: `TRF_Modules(GetPlayerMotherShip())` and compare the list with the mothership fitting screen; `TRF_CarcassInfo(ms).cost` against `<cost>` of its `Carcasses.xml` entry.
- Init signatures: 0x61ffa7 `89 86 f0 0e 00 00`; 0x624017 `83 bf 00 0f 00 00 00`; 0x607476 `8d 9f 1c 04 00 00 68 5c 58 72 00`; 0x6073fe `8d 9f ac 03 00 00`; 0x5e2e47 `d9 80 d4 00 00 00`; 0x5e3e89 `d9 80 54 0d 00 00`.

## 3. Ship and carcass enumeration

Feasible with plain reads. Every link below is a field read, except the class id (one byte-pattern decode, no call).

| Object | Offset | Meaning | Evidence | Tag |
|---|---|---|---|---|
| LM `[[0x7ba610]+0x18]` | +0x24 | carcass list; `node=[list+8]`, `data=[node]`, `next=[node+8]`, `obj=data-8`; skip `[obj+0x20]`, `[obj+0x804]==0`, `[obj+0x83c]==0` | 0x49b380-0x49b3bc (`8b 42 24 8b 58 08 85 db`) | [V] |
| any object | (+4)->vtbl[0] | `mov eax, rec; ret`; `*(int*)rec` = class id (2 Base, 3 Ship, 4 BigCarcass, 5 BigShip, 6 Interceptor, 7 Corvette, 8 Station, 9 TradeStation, 10 SpaceCarcass, 11 Null, 12 Rocket, 13 Portal; table in carcass-count.md 1.2) | ShipCarcass vtbl+4 = 0x73e6dc, [0]=0x61f1b0 `b8 60 55 7b 00 c3`; GameObject 0x607130 -> 0x7b51b0 | [V] |
| BaseCarcass | +0xd4 | current HP, float | GetCurHP 0x5e2e47 `d9 80 d4 00 00 00`; SetHP 0x5e2d2b | [V] |
| BaseCarcass | +0x3dc | `hit_points` (max HP), float; property at +0x3ac (ctor 0x60ad60, value +0x30) | name 0x73bcc8 at 0x607404; clamp `hp+x` to `[0,+0x3dc]` at 0x502120-0x50214a | [V] |
| BaseCarcass | +0x44c | `cost`, int; property at +0x41c (ctor 0x60ac70) | name 0x72585c at 0x60747c, 0x6072cb | [V] (for target 2) |
| BaseCarcass | +0x540 | mesh; world pos float[3] at mesh+0x7c, valid when `[mesh+0x158] & 2`; with no parent (`[mesh+0x170]==0`) the local pos mesh+0x50 equals it | 0x610540, 0x403810-0x403896 | [V] |
| ShipCarcass | +0xf8c | weak pilot | Carcass:GetPilot 0x5d7945 `8b 87 8c 0f 00 00` | [V] |
| Pilot | +0xa8 | weak flight | Pilot:GetFlight 0x5d7a86, pushes class 0x15; 0x524880 | [V] |
| Pilot | +0x5ac | weak ship | 0x5ac53b `8b 88 ac 05 00 00` | [V] |
| Flight | +0x138 / +0x140 | pilot entry list (head / count); entry+0x4 = role (int, ROLE_x), entry+0x10 = weak pilot | 0x5b85eb, 0x5b85fa, GetPilotCount 0x5dcd12, GetFlightRole 0x5d766e `db 40 04`, 0x5ac510 | [V] |
| Flight | +0x14c | weak group | 0x5248b7 `8b 88 4c 01 00 00` | [V] |
| Group | +0xfc | weak team | 0x524932 `8b 88 fc 00 00 00` | [V] |
| Team | +0x9c | name record, `char*` at +0x1c (Pilot:GetSide pushes it) | 0x524957, 0x5d74d2 | [V] |
| player team | `[[R+0x4c]+0x18]` | cached GamePlayer (weak) | 0x5be230 | [V] |
| BigShip | +0x10ac | BigShipHangar (0x88 bytes, ctor 0x617000) | 0x61682d `89 86 ac 10 00 00`; GamePlayer getter 0x5ae0a1 | [V] |
| Hangar | +0x3c / +0x70 / +0x7c / +0x80 | owner BigShip / `hangar_count` (int property at +0x40) / slot array of weak ShipCarcass / array size | 0x617000-0x617092, slot set 0x6177f0-0x61785d (index `< [h+0x70]`, `<= [h+0x80]-1`), element passed to 0x616c10 which reads `+0xf8c` | [V]; element = ship [V], empty slot = 0 [I] |

Team name of a carcass: `[[[[[o+0xf8c]+0xa8]+0x14c]+0xfc]+0x9c]+0x1c` (each link weak, check `+0x20`). Only ShipCarcass-derived ids 3-9 have +0xf8c; portals, wrecks, rockets have no team. Ownership test for the player: compare the team pointer with `[[R+0x4c]+0x18]` (no strings).

Player ships: mothership = `GetPlayerMotherShip()` handle (or cached `[team+0x150]`); hangared fighters = hangar slots of `[ms+0x10ac]`; ships in space = LM walk filtered by player team pointer; stock ships = inventory entries (section 1). Whether a docked fighter stays in LM+0x24 with `+0x804/+0x83c` set is not traced [I]; dedupe by uid.

`GetCarcassCountInSphere(posVec3, r)`: argument order (Vector3, radius) [V], carcass-count.md 1.1. It counts every BaseCarcass, no team or class filter.

```c
/* TRF_Carcasses([cx,cy,cz,r]) -> { {id=,cls=,tpl=,team=,hp=,hpmax=,x=,y=,z=,pl=0|1}, ... } */
static int cls_id(unsigned o) {                      /* (o+4)->vtbl[0] = b8 imm32 c3 */
    const BYTE *f = (const BYTE *)rdp(rdp(o + 4, 0), 0);
    return (f && f[0] == 0xb8 && f[5] == 0xc3) ? *(const int *)*(const unsigned *)(f + 1) : -1; }
static int __cdecl n_carcasses(lua_State *L) {
    unsigned R = *(unsigned *)ROOT_SLOT, lm = rdp(R, 0x18), node = rdp(rdp(lm, 0x24), 8), me = wk(rdp(R, 0x4c), 0x18);
    int n = 0, guard = 0;
    lua_newtable(L);                                 /* 0x65e560, add to TRF_APIS */
    while (node && guard++ < 4096) {
        unsigned d = rdp(node, 0), o = d ? d - 8 : 0, m, tm = 0; int c;
        node = rdp(node, 8);
        if (!o || !alive(o) || !rdp(o, 0x804) || !rdp(o, 0x83c)) continue;
        c = cls_id(o);
        if (c >= 3 && c <= 9) tm = wk(wk(wk(wk(o, 0xf8c), 0xa8), 0x14c), 0xfc);
        m = rdp(o, 0x540);                           /* pos: m+0x7c if [m+0x158]&2, else m+0x50 if [m+0x170]==0, else omit */
        /* optional sphere filter on the pos; push record: id=[o+0x94], cls=c, tpl=tname(o),
           team=tname(tm), hp=*(float*)(o+0xd4), hpmax=*(float*)(o+0x3dc), x,y,z, pl=(tm && tm==me) */
        lua_rawseti(L, -2, ++n);
    }
    return 1; }
/* TRF_Hangar() -> { uid|0, ... }: h=rdp(ms,0x10ac); for i<min([h+0x70],[h+0x80]) s=wk-read of ([h+0x7c])[i]. */
```

Lua receives an array of records; `id` is the uid, so `{id=uid}` tagged with the Carcass class (0x5c7a80 builder, class 0x17) can be made by the native if handles are wanted. Confidence: high for LM walk, HP, max HP, template, team chain, hangar layout; medium for position (cache flag) and for hangar slot semantics. Signatures for init: the bytes quoted in the table (0x49b380, 0x61f1b0 pattern, 0x5e2e47, 0x50213a `d9 81 dc 03 00 00`, 0x5d7945, 0x524880, 0x5248b7, 0x524932, 0x61682d, 0x617802 `8b 8e 80 00 00 00`, 0x617817 `3b 46 70`, 0x617823 `8b 46 7c`). Verification: in a system with a known trader convoy, log `TRF_Carcasses()` and check that the trader rows show `team=` their CreateTeam name, `hp == GetCurHP(handle)`, and `hpmax` equals `<hit_points>` of the template in Carcasses.xml; dock fighters and compare `TRF_Hangar()` count with the hangar screen.

## 4. Market read

Chain: `TS = [R+0x7c]` (TradeSystem, assert 0x7214a4, read at 0x5de8cf) [V]. `GetWhiteMarket/GetBlackMarket(shop)` call **`Market *__stdcall 0x4eb950(TS, const char *shop, int black)`** (pushes at 0x5de8d2-0x5de8d6 / 0x5de962-0x5de966, `retl $0xc` at 0x4ebac6) and push a class-0x1d handle with `id = [market+0x30]` [V]. 0x4eb950 lowercases the name (0x67b8b0 at 0x4eb990) and returns 0 for an unknown shop [V]. Markets by id: list `[[R+0x18]+0xa4]`, node data +0, next +8, match `[m+0x30]` (0x4ec210-0x4ec272) [V].

| Object | Offset | Meaning | Evidence | Tag |
|---|---|---|---|---|
| TradeSystem | +4 | `std::map<string, shop>`; head `[TS+8]`, size `[TS+0xc]` [I size] | 0x4eba0a `add esi,4`, 0x4eba33 `[esi+4]` | V |
| shop node | +0xc / +0x28 / +0x2c / +0x31 | key std::string / white Market* / black Market* / isnil byte | 0x4eba9c `8b 76 28`, 0x4eba84 `8b 76 2c`, 0x4ee49a `80 7e 31 00` | V |
| Market | +0x14 | rows `std::map<string,row>`; head `[m+0x18]`, begin `[[m+0x18]+0]` | 0x4ecb47 `8b 43 18 83 c3 14`, 0x4ecb4e | V |
| Market | +0x20, +0x24 | `DefaultGoodsPrice(a, b)`: a, b | 0x5dedc3 `89 56 20 89 46 24` | V |
| Market | +0x28, +0x2c | `CommonGoodsPrice(a, b)`: a, b; multiplied into each row's current factors when the market is merged (0x4ecaf3-0x4ecb0f) | 0x5def13 `89 56 28 89 46 2c` | V |
| Market | +0x30 | id (handle `id`) | 0x5de8df, 0x4ec26d | V |
| row node | +0xc | key std::string (lower case): buf/ptr +0x10, size +0x20, cap +0x24 (ptr when cap >= 16) | 0x4ecad9-0x4ecae4 `83 7f 24 10` | V |
| row node | +0x28 +0x2c +0x30 +0x34 | target: kind (1 ship, 0 module), n, Lua arg 5, Lua arg 4 | ShipGoodsState struct `{1, n, arg5, arg4}` built 0x5deab5-0x5deadf, written by 0x4ec3e0 | V |
| row node | +0x38 +0x3c +0x40 +0x44 | current: kind, cur stock, cur factor (arg 5 side), cur factor (arg 4 side) | refresh 0x4ecbca/0x4ecc07/0x4ecc3a; getter 0x4ec892 copies the four dwords | V |
| row node | +0x48 / +0x49 | color / isnil byte | head ctor 0x4ed752 `movb $1,0x49(%eax)` | V |
| module | +0x41c, value +0x44c | `cost` int property (name 0x72585c pushed at 0x60747c, int prop ctor 0x60ac70 stores value at prop+0x30) | 0x6072cb, UI reads `fildl 0x44c` at 0x566d3a | V |

Arg order: vanilla NORMAL white `ShipGoodsState(name, n, 1.35, 0.6)` stores +0x30 = 0.6 and +0x34 = 1.35 (shop-save.md 4 agrees). The shop rows the player trades are the current block (+0x3c..+0x44); `ShipGoodsState` writes only +0x28..+0x34 (shop-save.md 2.3) [V]. Shown price: one UI path computes `trunc(module.cost * [[x+0x5c]+0x54])` (0x566d3a-0x566d44) [V arithmetic]; that the factor there is the row's current factor times the common factor is [I]. A per-station copy of the stock (0x4eca70 merges a market into another map via 0x4ea370, called from 0x4ebf2b) exists; it is not read here [I].

```c
#define TS_GETMKT ((void *(__stdcall *)(void *, const char *, int))0x4eb950)
#define ISNIL(n)  (*(const BYTE *)((n) + 0x49))
static unsigned rb_next(unsigned n)               /* MSVC _Tree in-order successor, rows map */
{ unsigned p = rdp(n, 8);
  if (!ISNIL(p)) { while (!ISNIL(rdp(p, 0))) p = rdp(p, 0); return p; }
  while (!ISNIL(p = rdp(n, 4)) && n == rdp(p, 8)) n = p;
  return p; }
static int __cdecl n_marketget(lua_State *L)      /* TRF_MarketGet(shop, black) */
{ unsigned ts = rdp(*(unsigned *)ROOT_SLOT, 0x7c), m, head, n; int i = 0;
  const char *s = lua_type(L, 1) == T_STRING ? lua_tostring(L, 1) : 0;
  if (!g_mkt_ok || !ts || !s || !(m = (unsigned)TS_GETMKT((void *)ts, s, lua_tonumber(L, 2) != 0))) { lua_pushnil(L); return 1; }
  head = rdp(m, 0x18); lua_newtable(L);
  for (n = rdp(head, 0); n && n != head && i < 4096; n = rb_next(n)) {
    const char *k = rdp(n, 0x24) >= 16 ? (const char *)rdp(n, 0x10) : (const char *)(n + 0x10);
    lua_newtable(L);
    setfs(L, "name", k); setfn(L, "kind", rdp(n, 0x28)); setfn(L, "n", rdp(n, 0x2c));
    setfn(L, "k5", *(float *)(n + 0x30)); setfn(L, "k4", *(float *)(n + 0x34)); setfn(L, "cur", rdp(n, 0x3c));
    setfn(L, "c5", *(float *)(n + 0x40)); setfn(L, "c4", *(float *)(n + 0x44));
    lua_rawseti(L, -2, ++i); }
  return 1; }                                     
```

Lua receives an array of `{name, kind, n, k5, k4, cur, c5, c4}` (k4/k5 = Lua arguments 4/5 of `ShipGoodsState`), or nil for an unknown shop. Add `def = {+0x20,+0x24}` and `com = {+0x28,+0x2c}` if needed. Needs `lua_newtable` 0x65e560 and `lua_tonumber` 0x65e0c0 in `g_used_api`. Cost per call: one map lookup, rows up to a few hundred.
Signatures: 0x4eb950 `6a ff 68 98 d2 6b 00`, 0x4ebac6 `c2 0c 00`, 0x4eba9c, 0x4eba84, 0x4ee49a, 0x4ecb47, 0x4ec892 `8b 56 38 8b 46 3c 8b 4e 40 89 55 00 8b 56 44`, 0x4ecad9, 0x5dedc3, 0x5def13. Map node isnil offsets come from template code; if a byte differs, return nil.
Confidence: high for layout and the lookup call; medium for "cur is what the shop shows" (shop-save.md U1). Verify: dock at a station, run `TRF_MarketGet(<shop>, 0)` and compare `cur` of three goods with the trade window counts.

## 5. Ship cargo (what an NPC ship carries)

Cargo is the same `Inventory` at `[carcass+0xff8]` [V]: `Carcass:AddModuleToInventory` 0x5e0f00 resolves the handle, requires `IsKindOf(BigCarcass)` (0x5e0fee-0x5e1003) and calls 0x61a370 on `[obj+0xff8]` (0x5e100c); `Carcass:ClearInventory` 0x5e0dd0 clears the list `inv+0x3c` with 0x56a5a0 and resets `inv+0x54` (0x5e0eb6). So `TRF_InvList(trader)` above is the cargo read; no second native is needed.

- Only BigCarcass and its subclasses (BigShip, Station, TradeStation) have the field; Interceptor (6) and Corvette (7) derive from ShipCarcass (3) and have none (carcass-count.md 1.2), which is why the native checks the kind before reading `+0xff8` [V]. `Carcasses.xml` declares the transports (`Btransport`, `P_transport`) as `<BigShip>` [V], so traders qualify.
- What a destroyed ship actually drops was not traced. `PercentToExcludeInventory` (string 0x725aa8, read by the config loader at 0x4f6170) suggests a share of the inventory is withheld from the drop [I]. Two death-path functions place a single module from `[carcass+0xf8c]` with 0x608400 (the function `PlaceModule` 0x5e4d17 uses) at 0x618216 and 0x61962e [V for the calls, I for "death path"]. Treat `TRF_InvList` as "cargo carried", not "loot that will appear".

Confidence: high (same code path as section 1). Verify in game: `x:AddModuleToInventory("<module>", 5)` on a spawned trader, then `TRF_InvList(x)` returns that row with `n=5`; after `x:ClearInventory()` it returns `{}`.

## 6. Time state

TimeManager `TM = [[0x7ba610]+0x44]`, 0x68 bytes, ctor 0x4c5c90 (alloc at 0x655296, stored 0x6552c6), vtbl 0x723e14; built once with Root. Update 0x4c5e10 (`esi` = TM, no stack args) is called each pass of the frame loop 0x4a04c0 (0x4a050b, second site 0x4a058b). Time mode lives in Game `G = [0x7ba610]+0`.

| Field | Type | Meaning | Writer / reader | Tag |
|---|---|---|---|---|
| TM+0x4 | int | 0 normal, 1 paused, 2 accelerated | 0x4a1929 / 0x4a1938 / 0x49e1de | [V] |
| TM+0x8 | float | time scale: 0 (pause), 1, 2, 4, 8 (consts 0x745980, 0x745884, 0x745c80); modes 2-4 are multiplied by `[0x40bf60()+0xd8]` when `[[R+0x30]+0xd4] != 0` | SetTimeMode 0x4a18a0 via 0x49e1d0 | [V] values, [I] the option meaning |
| TM+0xc | float | QPC seconds at ctor (QPC 0x6fc050, base 0x7b9940, freq 0x7b9948) | ctor 0x4c5ced | [V] |
| TM+0x10 | float | QPC seconds at last update | 0x4c5e8e | [V] |
| TM+0x20 | float | raw frame dt, clamped to 0.1 s (0x7459a8 / 0x745928) | 0x4c5e75-0x4c5e8b | [V] |
| TM+0x14 | float | accumulated real time (sum of clamped dt) | 0x4c5eb5; read 0x56bd83 | [V] |
| TM+0x18 | float | **game clock**: sum of dt × scale, seconds since process start; stops while paused | 0x4c5ebe-0x4c5ec1; read 0x4d5dd2 | [V]; no other writer found [I] |
| TM+0x1c | float | real time accumulated since last tick | 0x4c5ed2, reset 0x4c5f16 | [V] |
| TM+0x38 | int | 1 when this update is a tick (enough time accumulated, frame cap from +0x40 = 0.002 and factor 1, or 2 at scale 8) | 0x4c5ef5; frame loop skips everything when 0 (0x4a05f0) | [V] flag, [I] exact cap formula |
| TM+0x24 | float | real dt of this tick (0 when not a tick); UI/camera/input update uses it | 0x4c5f11 / 0x4c5f00; read 0x4a05fa | [V] |
| TM+0x28 | float | scaled dt of this tick = +0x24 × +0x8; location update 0x4a17a0 uses it | 0x4c5f1f; read 0x4a0742 | [V] |
| TM+0x2c | float | `+0x3c (500.0) × +0x1c × …` sub-tick fraction | 0x4c6054 | [I] |
| TM+0x30 / +0x34 | int | tick count / update count | 0x4c5f0d / 0x4c604b | [V] |
| TM+0x44 | list | timer list (vtbl methods 0x4c6360..0x4c6a40) | ctor 0x4c5ce8 | [I] |
| G+0xc | int | time mode 0 pause, 1 normal, 2 ×2, 3 ×4, 4 ×8 | SetTimeMode `0x4a18a0(ecx=G, eax=mode)` stores at 0x4a18d4; jump table 0x4a19a4 | [V] |
| G+0x8 | int | mode before an explicit pause | 0x4a18cf | [V] |
| G+0x14 / G+0x10 | int | nested pause depth / mode saved by the first push; PushPause 0x4a19c0, PopPause 0x4a1a50 (UI windows) | 0x4a19c8 / 0x4a19d3 | [V] |
| 0x7acb80 | int | difficulty 0/1/2 (writers 0x541309-0x54133e); `GetLevelDifficult` already returns it, -1 without a player team | 0x5e59f3 | [V] |

Writers of the mode: `Pause(f)` 0x5e5900 (f≠0 → mode 0, f=0 → mode 1), `SetNormalTimeMode` 0x5e5950 (mode 1), game-state keys at 0x5969be: action 0x1a steps the mode down (1→0 … 4→3), action 0x1b steps it up (0→1 … 3→4); pause toggles at 0x591c89 / 0x593c7b; TM update forces mode 3 with hint `#UI_HintGameError8X` when ×8 cannot keep the frame rate (0x4c5fa4) [V].

```c
static int __cdecl n_time(lua_State *L)              /* TRF_Time() */
{
    unsigned r = *(const unsigned *)ROOT_SLOT, tm = rdp(r, 0x44), g = rdp(r, 0);
    if (!tm || !g || !g_time_ok) { lua_pushnil(L); return 1; }
    lua_newtable(L);
    lua_pushstring(L, "mode");  lua_pushnumber(L, *(const int *)(g + 0xc));    lua_settable(L, -3);
    lua_pushstring(L, "depth"); lua_pushnumber(L, *(const int *)(g + 0x14));   lua_settable(L, -3);
    lua_pushstring(L, "scale"); lua_pushnumber(L, *(const float *)(tm + 0x8)); lua_settable(L, -3);
    lua_pushstring(L, "game");  lua_pushnumber(L, *(const float *)(tm + 0x18)); lua_settable(L, -3);
    lua_pushstring(L, "real");  lua_pushnumber(L, *(const float *)(tm + 0x14)); lua_settable(L, -3);
    lua_pushstring(L, "dt");    lua_pushnumber(L, *(const float *)(tm + 0x28)); lua_settable(L, -3);
    return 1;
}
```

- Lua receives `{mode=1, depth=0, scale=1, game=1234.5, real=1300.2, dt=0.016}`; paused when `mode == 0` (or `scale == 0`).
- Confidence: high. `game` is a float since process start, not saved with the game: keep using TRF_GameTime's own sum for saves, or store an offset in TRF. Float resolution is 0.06 s after about 11 days of play.
- Verify in game: log `TRF_Time()` each tick while pressing pause and the faster/slower keys; `mode`/`scale` should step 0,1,2,4,8 and `game` should stop while paused and advance 8× at mode 4.
- Init signatures: 0x4c5eb8 `d9 46 20 d8 4e 08 d8 46 18 d9 5e 18`; 0x4c5f1b `24 d8 4e 08 d9 5e 28`; 0x4a18d2 `85 ff 89 7e 0c`; 0x4a191f `e8 0c 36 f6 ff d9 ee d9 58 08 89 58 04`.

## 7. AI state / current order

Feasible: the current behaviour of every pilot is one pointer, readable without calls. The target is per state, found for three states.

Order path [V]: Flight:Stop 0x5dcf14 / Move 0x5dbd7d read `[flight+0xa8]` (command interface), build a Command object and deliver it via 0x5ab290 / 0x5aa9e0 to the leader ship (0x5b8050: first entry of `flight+0x138`, needs `[flight+0x1b8]!=0`) at `ship+0x4c4`->vtbl[4] (0x625350). That forwards to `[[ship+0xf8c]+0xa4]` = **PilotAI** (0x3e64 bytes, ctor 0x4fda70, vtbl 0x726c48, created at 0x523aba/0x524786; string "PilotAI" 0x726ac0). PilotAI::HandleCommand (vtbl[4] 0x4fec00) dispatches on `cmd->vtbl[5]()` bit values (CommandStop 0x40, CommandAttack 0x8, CommandManeuver 0x1, CommandEscort 0x4000000, CommandRoundPatrol 0x80, CommandComeToPortal 0x20000000, CommandComeToTradeStation 0x40000000, CommandComeToHangar 0x100, CommandDefend 0x400000; vtables follow the name strings 0x72230c-0x7228f0).

| PilotAI field | Meaning | Evidence | Tag |
|---|---|---|---|
| +0x50 | weak owner pilot; ship = `[pilot+0x5ac]` | 0x4ff740 `8b 41 50` | [V] |
| +0xf0 | pointer to the active state, always one of the embedded states below; 0 before attach | stores 0x4fef33, 0x4fefcd, 0x4ff011, 0x4ffd45, 0x4fef8c; ctor 0x4fdb63; save/restore switch 0x4fe720 (state ids 0x7e-0x9f) | [V] |
| state->vtbl[9] / [10] | Exit / Enter(arg) | `call [vt+0x24]` then `call [vt+0x28]` around each store | [V] |

`k = [ai+0xf0] - ai` gives the state (names from the string before each state vtable; save id in brackets):

| k | state | save id | set by command | target field (state+off) |
|---|---|---|---|---|
| 0xf4 | Stand | 0x7e | Stop 0x40 | - |
| 0x914 | Destruction (attack) | 0x7f | Attack 0x8 | +0xc weak carcass (0x50b253) [V] |
| 0x1000 | Move | 0x80 | Maneuver 0x1 | [I] |
| 0x1808 | ActLikeMe | 0x81 | | |
| 0x1f08 | Cloaking | 0x83 | | |
| 0x1f84 | MissileDefence | 0x84 | | |
| 0x2000 | Repair | 0x85 | | |
| 0x2090 | Defend | 0x86 | | |
| 0x2790 | Escort | 0x89 | Escort 0x4000000 | +0x754 escorted carcass (0x50c154 store; weak-ptr handling not read) [I] |
| 0x2f3c | Patrol | 0x9b | RoundPatrol 0x80 | |
| 0x381c | ComeToHangar | 0x87 | | |
| 0x396c | DockWingman | 0x88 | | |
| 0x39bc | LongRangeAttack | 0x9a | | |
| 0x3b4c | ComeToPortal | 0x9e | | +0xf0 weak portal (0x509bef) [V] |
| 0x3c98 | ComeToTradeStation | 0x9f | | +0xf0 weak station (0x50a1df) [V] |

Each state's vtable is also known (Stand 0x727528, Destruction 0x727250, Move 0x727420, Escort 0x7272e0, Patrol 0x727460, ComeToPortal 0x727114, ComeToTradeStation 0x727188, ...), so the native can check `[[ai+0xf0]]` against the table as a second test. Role (Task enum, = ROLE_x: 1 Leader, 2 Attack, 3 Defence, 4 ToBase, 5 Stealth, 6 MissileDefence, 7 Repair; names at 0x5be3c0) is the flight entry +0x4 [V].

```c
/* TRF_AiState(pilot|carcass) -> stateName, k, targetUid|nil, role */
static const struct { unsigned k; const char *n; unsigned tgt; } g_ai[] = {
    {0xf4,"stand",0},{0x914,"attack",0xc},{0x1000,"move",0},{0x2790,"escort",0},{0x2f3c,"patrol",0},
    {0x3b4c,"portal",0xf0},{0x3c98,"station",0xf0},{0x381c,"hangar",0} /* ... rest of the table */ };
static int __cdecl n_aistate(lua_State *L) {
    unsigned o = obj_by_uid(L, 1), p, ai, st, k, i, t;
    if (!o) { lua_pushnil(L); return 1; }
    p = is_kind(o, 0x7b31d4u) ? o : (is_kind(o, 0x7b5560u) ? wk(o, 0xf8c) : 0);
    ai = rdp(p, 0xa4); st = rdp(ai, 0xf0);
    if (!ai || !st) { lua_pushnil(L); return 1; }
    k = st - ai;
    for (i = 0; i < sizeof g_ai / sizeof g_ai[0] && g_ai[i].k != k; i++) ;
    lua_pushstring(L, i < sizeof g_ai / sizeof g_ai[0] ? g_ai[i].n : "other");
    lua_pushnumber(L, (double)k);
    t = (i < sizeof g_ai / sizeof g_ai[0] && g_ai[i].tgt) ? wk(st, g_ai[i].tgt) : 0;
    if (t) lua_pushnumber(L, (double)rdp(t, 0x94)); else lua_pushnil(L);
    return 3; }
```

Lua receives `name, k, targetUid|nil` (role can be added from the flight entry of `[pilot+0xa8]` whose +0x10 is the pilot). The leader's state is the flight's order; wingmen run their own states (ActLikeMe, Defend, ...). Confidence: high for the AI pointer chain, the `+0xf0` slot and the offset-to-state map (constructor order 0x4fdb69-0x4fdc5e and the restore switch agree); medium for the target fields (three read, rest open). Init signatures: 0x6253b9 `8b 88 a4 00 00 00`, 0x4fefc2 `8d b7 f4 00 00 00` + 0x4fefcd `89 b7 f0 00 00 00`, 0x4fdb69 `8d 9f f4 00 00 00`, 0x4ff740 `8b 41 50`, 0x50b253 `89 47 0c`, 0x509bef `89 b7 f0 00 00 00`. Verification: give a spawned trader flight `Flight:Stop()`, then `Carcass:ComeToPortal(p)`, and check that `TRF_AiState(flight:GetLeader())` returns `stand` then `portal` with `targetUid` equal to the portal handle's `id`.

Open: (1) target fields of Move (destination Vector3), Patrol, Escort, Defend; (2) whether hangared fighters stay in LM+0x24; (3) meaning of `[flight+0x1b8]`.

## 8. Recruits of a location

`RecruitManager = [R+0x88]` (assert 0x7214d8, getter 0x4a4450) [V]. Offers are generated by **0x58b680(window, nGroups)**, called from the station work window (0x588801; group count `min + rand % (max - min)` from 0x7acd14/0x7acd18 at 0x5887ec) and 0x540e95 [V]. It first clears the offer list (0x58c500), reloads `DATA\GAME\Recruits.xml` (0x58b950, which rewrites 0x7acd0c/10/14/18 at 0x58bc94-0x58bdcf) [V]. So `RecruitsSetMinCount/MaxCount` (write 0x7acd0c/0x7acd10 at 0x5e6de9/0x5e6e55) are overwritten at the next generation: in effect loader-only, as noted before [V for the order, I for "no other reader"]. Per group: pilots `= [0x7acd0c] + rand % ([0x7acd10] - [0x7acd0c])` (0x58b7c0-0x58b7e4), group object 0x48 bytes (ctor 0x4f1470, vtbl 0x725974), filled by 0x4f1b80 from the XML table, total cost > 0 → `0x58a320(window, group, cost)` adds a GUI row and an offer element [V].

| Object | Offset | Meaning | Evidence | Tag |
|---|---|---|---|---|
| offer list (global) | 0x7b3f78 / +4 / +8 | generic list head / tail / count; node data +0, next +4, prev +8 | 0x58c500 frees from 0x7b3f7c via node+8; 0x58a43d `39 0d 78 3f 7b 00` | V |
| offer element (0x18) | +0 | GUI panel element (freed with it, vtbl[0](1)) | 0x58a427 `89 30`, 0x58c53c | V |
| | +4 | `[0x7ba5c8]` (counter, incremented 0x58a108) | 0x58a413 | V |
| | +0xc | total cost of the group | 0x58a42f, arg 3 | V |
| | +0x10 | value drawn and removed from pool list 0x7bb664 (0x58a1d0) | 0x58a42c | V; meaning (portrait or text id) I |
| | +0x14 | RecruitGroup* | 0x58a41d, arg 2 (`edi` at 0x58b8b9) | V |
| RecruitGroup | +0x34 | `std::list<record>`; head node `[g+0x38]`, size `[g+0x3c]`; node next +0, value +8 | 0x4f1b1c `8b 46 38 83 c6 34`, 0x4f1b25 | V |
| record (node+8) | +0 / +0x24 | engine String `pilot_name` / `ship_name` (char* at String+0x1c) | copies 0x4f09c5/0x4f09d2; order per Recruits.xml | V copy, I which is which |
| record | +0x48 / +0x4c | rank (byte) / cost (int) | 0x4f09d7 `8a 4e 48 88 4f 48 8b 56 4c 89 57 4c`; sum `[node+0x54]` at 0x4f1b59 | V |
| RecruitManager | +4 | group selected for payment; `RecruitsPayRequest(1)` subtracts `0x4f1b10(group)` from GamePlayer+0x110 (credits) and does not clear it | 0x4f141a, 0x4f1438 `29 b0 10 01 00 00` | V |

```c
static int __cdecl n_recruits(lua_State *L)       /* TRF_Recruits() */
{ unsigned node = *(unsigned *)0x7b3f78, e, g, h, r; int i = 0, j;
  if (!g_rec_ok) { lua_pushnil(L); return 1; }
  lua_newtable(L);
  for (; node && i < 32; node = rdp(node, 4)) {
    if (!(e = rdp(node, 0)) || !(g = rdp(e, 0x14)) || !(h = rdp(g, 0x38))) continue;
    lua_newtable(L); setfn(L, "cost", rdp(e, 0xc));
    for (j = 0, r = rdp(h, 0); r && r != h && j < 16; r = rdp(r, 0)) {
      lua_newtable(L);
      setfs(L, "pilot", (const char *)rdp(r, 8 + 0x1c)); setfs(L, "ship", (const char *)rdp(r, 8 + 0x24 + 0x1c));
      setfn(L, "rank", *(const BYTE *)(r + 8 + 0x48)); setfn(L, "cost", rdp(r, 8 + 0x4c));
      lua_rawseti(L, -2, ++j); }
    lua_rawseti(L, -2, ++i); }
  return 1; }
```

Lua receives `{ {cost=, [1]={pilot=, ship=, rank=, cost=}, ...}, ... }`: one entry per offer row of the last generated station work window; an empty table before the first generation. Names are Recruits.xml template names (`RecruitPilot`, `Yari_merc2`), not the generated pilot names; the generated pilots are created only when the offer is paid (not traced) [I]. The list is a global that survives leaving the station until the next generation; group objects are not freed by 0x58c500 (only the element and its panel), so `+0x14` stays readable [I].
Signatures: 0x58a40d-0x58a42f (element stores), 0x58a43d, 0x58c519 `a1 7c 3f 7b 00`, 0x4f1b1c, 0x4f1b59 `8b 57 54`, 0x4f09d7.
Confidence: medium. List and record offsets are read from the asm; when the list is valid relative to the window lifetime is not traced. Verify: open a station's recruit tab, then call `TRF_Recruits()` and compare offer count, costs and ship names with the window.
Not feasible from this data: recruits of a location the player has not opened (offers are generated on window open, not stored per location).
