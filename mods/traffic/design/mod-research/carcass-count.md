# GetCarcassCountInSphere and Portal:GetEntryPoint

Target `sw3cw.exe` GOG v1.12 (the clone's copy), static reading of `.work/exe.asm` (objdump) and the file bytes, plus the clone's `traffic-runs/*/sw3tp.log`. Tags: **[V]** verified from disassembly or bytes, **[L]** seen in an in-game log, **[I]** inferred.

## 0. Answer

`GetCarcassCountInSphere(pos, r)` counts **every carcass object** in the location whose bounding sphere touches the query sphere: ships, stations, trade stations, portals, space carcasses (wrecks, scenery), rockets. It has no class-id filter and no HP or alive test [V]. A spawn spot at `portal:GetEntryPoint(10)` is 10 units from the portal's origin, so with radius 20 the portal itself is always counted (`10 <= 20 + R` for any portal radius R) [V by the test in 1.3]. That is why every spot was refused in NJ1 (`skip_space=8`, no spawn) [L]. Fix: compare against a per-visit baseline (v01-spec 4.4), not `n > 0`.

## 1. The native

### 1.1 Registration and arguments [V]

- Registered by `RegisterServices` 0x5d2810 (call site 0x5d35af), C function **0x5e68f0** (`lua-natives.tsv`).
- `lua_gettop < 2` → error text 0x739e38 `"ScriptDispatcherServices::GetCarcassCountInSphere: invalid params!"` through 0x455e00, `return 1` with nothing pushed (0x5e691c-0x5e6943).
- Arg 1: a table; `x`, `y`, `z` (strings 0x718f0c, 0x72b8fc, 0x733aa0) read with the field helper 0x5c78b0 at stack index 1 (`edi = 1`, 0x5e6967), which requires `lua_type == 4` (table). A `Vector3` works; a plain `{x=, y=, z=}` table would too [I: the helper reads fields only].
- Arg 2: `lua_tonumber(L, 2)` (0x65e0c0) = radius.
- Builds a sphere `{r, x, y, z}` on the stack (0x5e69a0-0x5e69c3), calls the collector 0x49b330(list, &sphere), pushes the list count as a number (`fildl` of the list size, `lua_pushnumber` 0x65e200), frees the list (0x460940). Returns one number, never nil once called with 2 args.

### 1.2 What is iterated [V]

Collector 0x49b330 walks `g_Root->g_LayerManager` (`[0x7ba610]+0x18`, assert text 0x7175b8) list `LM+0x24`, node `{obj+8, ?, next}`. For each object `o` (= node[0] − 8):

| Test | Address | Meaning |
|---|---|---|
| skip if `o+0x20 != 0` | 0x49b3a6 | same skip as the snapshot writer 0x4a6d8c and the other `LM+0x24` walkers; meaning not traced [I: removed / pending delete] |
| skip if `o+0x804 == 0` | 0x49b3ac | set together with `+0x83c` by BaseCarcass vtable method 0x610800 and the ShipCarcass override 0x625280 (both write the same argument to `+0x83c` and `+0x804`, then call the mesh method 0x418100); 0x502226 / 0x502256 set `+0x804` 1 / 0 on an object from 0x4ff740 [I: "present / enabled in the world"] |
| skip if `o+0x83c == 0` | 0x49b3b5 | see above |
| mesh `o+0x540`, size `o+0x548` | 0x49b3be-0x49b406 | no mesh → log 0x73d3bc `"The object %s has no mesh, but we try to get it's position"` and use position 0x7ba688 |
| sphere test 0x49a800 | 0x49b422 | object radius `0.5 * o+0x548` (double 0.5 at 0x745850), object position from the mesh (0x403810) |
| append to list | 0x49d210 | |

There is **no class-id or kind test** in the loop, unlike the snapshot writer 0x4a6cb0, which walks the other list `LM+0x20` and filters by the type-id set {10, 8, 9, 13} (`research/pirate-bases.md` 4.1).

`LM+0x24` holds carcasses only [I]: every walker of it (0x49aa5e, 0x49abc4, 0x49b042, 0x49b380, 0x49b4b0, 0x49d177, 0x4c536d) reads `+0x540`, `+0x804`, `+0x83c` without a type check, and those fields are laid out by the BaseCarcass constructor 0x60dbd0 (`+0x540`, `+0x544` = 0, `+0x548` = 0.0 at 0x60dca3-0x60dcb7; vtable 0x73d470). 0x60dbd0 is called by the ShipCarcass constructor 0x61f200 (0x61f222) and three more constructors (0x61e3c0, 0x62b1e0, 0x64e610).

Class tree from the factory registrations (call 0x49d300 with `push parent; push id; push name`, 0x6f2d2d-0x6f37ad, 0x6f82bd) [V]:

| id | class | parent |
|---|---|---|
| 2 | BaseCarcass | 1 (GameObject) |
| 3 | ShipCarcass | 2 |
| 4 | BigCarcass | 3 |
| 5 | BigShip | 4 |
| 6 | Interceptor | 3 |
| 7 | Corvette | 3 |
| 8 | Station | 4 |
| 9 | TradeStation | 8 |
| 10 | SpaceCarcass | 2 |
| 11 | NullCarcass | 2 |
| 12 | RocketCarcass | 2 |
| 13 | Portal | 10 |

So a portal (13 → 10 → 2), a station (9 → 8 → 4 → 3 → 2), wrecks and scenery (SpaceCarcass 10) and missiles in flight (RocketCarcass 12) are all BaseCarcass and all qualify [I for list membership, V for the hierarchy].

### 1.3 The sphere test 0x49a800 [V]

`eax` = query sphere `{r, x, y, z}`, `ecx` = object position, stack = object radius R. Computes `d² = |c − p|²` and `(r + R)²`, returns 1 when `d² <= (r + R)²` (`fcompp`, `testb $0x41`). It is sphere against sphere, not point in sphere: a large object counts when its centre is up to `r + R` away.

`+0x548` is twice the mesh bound (0x611105: `fadd st, st` of the value from 0x40a120(1)), so `0.5 * +0x548` is the mesh's bounding radius [I: what 0x40a120 returns].

### 1.4 Dead carcasses [I]

The loop has no HP or alive test. A destroyed object stops counting only once it is removed from `LM+0x24`, flagged `+0x20`, or has `+0x804`/`+0x83c` cleared. When the engine does that for a killed ship (immediately, or after the explosion) was not traced. Wreck objects that remain as SpaceCarcass count.

### 1.5 In-game corroboration [L]

- NJ1 (2026-10-21, 15 game minutes, mode mod, gate ok): `skip_roll=13 skip_space=8`, no `spawn`. Every tick that passed the roll was refused by `TRF_GnFree` with `n > 0`.
- The governor's `GetCarcassCountInSphere(Vector3(0, 0, 0), 3000)` logs `n` = 36 to 202 across runs, e.g. `governor n=181 r=3000` in Taira with `tr=0 ships=0` (no mod ships). Far more than the ships in a system: scenery carcasses count. Side effect: the governor threshold `n > 40` (v01-spec 6) trips on scenery in most systems. Not changed here.

## 2. Portal:GetEntryPoint(d) [V]

C function 0x5eb340 (`lua-natives.tsv`): `d = lua_tonumber(L, 2)`, object by the table's id field (0x5c78b0 with string 0x733a9c, lookup 0x51f880), `IsKindOf(BaseCarcass)` (`[0x7b52f8]`, vtbl+4), then:

- position `p` = 0x610540(o) (mesh world position, cached at mesh+0x7c),
- rotation `q` = 0x4038a0 (cached world quaternion at mesh+0x88..+0x94, x y z w),
- axis = 0x402d70(q) = `(2(xz + wy), 2(yz − wx), …)`, the third column of the rotation matrix, i.e. the mesh's local **+Z** axis in world space, normalised by 0x402580,
- result `p + d * axis` (0x5eb48c-0x5eb4e8), pushed by 0x5dded0 (a Vector3 push helper [I]).

So `GetEntryPoint(10)` is exactly 10 units from the portal's origin along its local +Z (the side ships come out of, as vanilla spawns there) [V for the arithmetic, I for "exit side"]. Any query sphere around it with r ≥ 10 contains the portal's centre.

## 3. Consequences for the mod

- `n > 0` can never be free at a portal spot, and is free at a station approach point only if the nav point is farther than `20 + R_station` from the station. Moving the spawn point out of the portal sphere would need `d > 20 + R_portal`, and R is per model and unknown, so v01-spec 4.4 now compares against a per-visit baseline taken at the same position (`TRF_GnBase`): in OnActivate for every trader portal entry point and station approach point, else on first use.
- Ships parked at a spot when the baseline is taken raise it for the visit (a later spawn may overlap them). Accepted.
- Missiles and short-lived wrecks near a spot raise `n` above the baseline for a while: the spot is refused, which is the intended direction.

## 4. Open

1. Meaning of `o+0x20` and when a killed ship leaves `LM+0x24` (1.4).
2. Which constructor builds Portal (0x61e3c0, 0x62b1e0 or 0x64e610) and its typical `+0x548`.
3. A `debug` run (`cfg log 2`) shows `gen: spot <key> base=<n>` per spot at entry: the static counts per system, to recalibrate the governor (1.5).
