# Damage type: weapon hit vs collision (`ShipCarcass` damage 0x622540)

Target `sw3cw.exe` GOG v1.12 (base 0x400000, no ASLR). Sources: `.work/exe.asm` (objdump), REA/Hopper pseudocode of 0x622540, byte reads of the exe, the run `traffic-runs/0-20261022-000913/sw3tp.log`. The game was not run. Tags: **[V]** read in the disassembly, data or log, **[I]** inferred, **[U]** unknown.

## 1. Question

The combat source "hit" (`TRF_Cb` → `TRF_CombatMark("hit", ..)`, traffic.script:103) fired when the user rammed a trader (`combat on why=hit src=TRF_OnAttack gt=19351.982`, sw3tp.log:1005 [V]). Can the mod tell a collision from a weapon hit? Which argument of 0x622540 is the type, who passes what, where `_EVENT_ATTACKCARCASS` (24) is raised, and what is the cheapest hook?

## 2. Answer

- The damage entry is the virtual **slot 0x54** of every carcass vtable: `ShipCarcass` 0x622540 in 7 vtables, base `BaseCarcass` 0x610870 (hull only) in 5 [V]. Signature: `thiscall(ecx = victim, float dmg, int type, Vec3 *dir, Obj *src, int unused)`, `ret 0x14` [V].
- **Collision damage is type 2 with `src = NULL`** (0x60f8fa) [V]. Weapon damage always has a non-null `src` whose `+0x54` is the shooter [V]. Splash is also type 2, but with a `src` [V].
- The `attack` event list is filled only from a non-null `src` (0x610e00 returns early on `src == NULL`) [V]. **A collision cannot raise `_EVENT_ATTACKCARCASS`** by the static code. The event at gt 19351.982 therefore came from an attributed hit by `PLAYER_GROUP` (a gun, a turret, a fighter or an explosion owned by the player) or from a path not found here [I]. Section 6 lists the runtime check.
- The event itself carries no type: the trigger update builds event 0x18 with the trigger's carcass and group only [V].
- Cheapest hook: two E8 call-site patches on the calls to 0x610e00 (0x61087d, 0x622feb). Together they see every damage call with victim, type and `src` (section 4).

## 3. Findings

### 3.1 Signature and vtables [V]

| arg | where in 0x622540 | meaning |
|---|---|---|
| ecx | `mov edi, ecx` 0x622564 | victim carcass; HP `+0xd4`, max HP `+0x3dc`, shield `+0xcf4`, id `+0x94` (0x51f8a7 compares the Lua id there) |
| [ebp+8] float | rewritten in place (crit, armour, pilot skills) | damage |
| [ebp+0xc] int | `cmp $4` 0x622994, `cmp $3` 0x622df0 | damage type |
| [ebp+0x10] Vec3* | passed on | hit direction (0x445fa0 builds a random unit vector for unattributed damage) |
| [ebp+0x14] Obj* | `[src+0x54]` = shooter, class check 0x7b6300 (pilot at `+0x944`) or 0x7b5560 (pilot at `+0xf8c`) | source (projectile or contact); NULL = no attacker |
| [ebp+0x18] | never read in 0x622540; callers pass 0 | unused |

Slot 0x54 holds 0x622540 at 0x73d60c, 0x73d74c, 0x73d93c, 0x73db64, 0x73e684, 0x73ea84, 0x73ebbc, and 0x610870 at 0x73d4c4, 0x73e074, 0x73e184, 0x73e974, 0x743db4. No direct `call 0x622540` exists.

### 3.2 Type values [V]

`damage_type` table at 0x7401d0, rows of 0x14 bytes (name, value at +0x10), parsed by 0x6320e3 into weapon params `+0xe4`: **IMPACT = 1, SPLASH = 2, LASER = 4**. Projectile spawn 0x4d41b2 passes params `+0xe4` with damage `+0xe0` [V]. The projectile's `+8` holds that type [I]. Engine-set values: 2 (collision, splash wrapper), 3 (damage over time).

### 3.3 Callers of slot 0x54 [V]

| site | function | type | src | what |
|---|---|---|---|---|
| 0x4d56ba | 0x4d5680, slot 7 of the projectile classes (BigGun, Laser, Plasma, sSFX, Tracer vtables 0x724434..0x72495c) | `[this+8]` (data: 1/2/4) | the projectile (`+0x54` shooter, `+0x68` victim) | **weapon hit** |
| 0x610f5d | 0x610f20 = slot 0x60 "splash", called from explosion 0x49d820 at 0x49da75 | **2** | local contact with `+0x54` = explosion owner `[expl+0x15c]` | **missile / explosion splash** [I: missiles explode through this] |
| 0x60f8fa | `BaseCarcass::Update` 0x60f690 | **2** | **0** | **collision**: applies the accumulator `carcass+0x6b8`, then zeroes it |
| 0x60a641 | 0x60a600, from the carcass update 0x620ba8 (`this = carcass+0xacc`) | **3** | 0 | damage over time (rate `+4` x dt) [I: hazard or burn effect] |

The collision accumulator is slot 0x58 = 0x614b70 (`fadds [ecx+0x6b8]`). Only the CollisionManager 0x49b690 calls it, on both carcasses of a contact (0x49c7e9, 0x49c7fe: +10.0 each, constant 0x745940; 0x49c901 adds more on iteration 4). The collision damage therefore reaches the victim one update later, as type 2 with direction random and `src` 0 [V].

### 3.4 Inside 0x622540 [V]

- Type 4 (LASER) 0x62299e: scales the damage by `1 - k*[module+0x504]` for modules of slot type 0x2e (laser armour) [I: names].
- Type 3 at 0x622df0: hull directly through 0x610870 (`push 3`, 0x622e7a); it ignores the shields.
- Other types: shield `+0xcf4` absorbs the damage (0x622fe6: `call 0x610e00`, shield -= dmg), or the remainder goes to the hull via 0x610870 (0x622f1c). Each call passes exactly one of the two 0x610e00 sites.
- Slot 0xa8 (0x6232b0, hit effect) tests `type == 2` and then uses `dir`; for other types it uses `src+0x58..0x60`. Retagging the collision type would change hit effects, so the hook does not retag.

### 3.5 Where event 24 comes from [V]

- 0x610e00 (`ebx` = victim, `eax` = src): returns if `victim+0x8e4 <= 0` (no `attack` trigger armed on it) or `src == 0`. Otherwise it resolves the shooter's pilot and calls 0x610c60(victim, pilot). That adds the pilot's group key (`0x524880(pilot)+0x9c`) to the vector `victim+0x8ec` (begin `+0x8f0`, end `+0x8f4`) once, through 0x610ac0 and 0x614bd0, after a relation test 0x5bf9d0.
- The only runtime writer is 0x610c60 (the other caller of 0x614bd0, 0x60f13d, is the save loader) [V].
- Trigger update 0x4bca40: looks the group up, and 0x610ac0 matches it. On a match it builds the event with `push 0x18` (0x4bcbc9) and fires it (0x4bc1b0). Each armed trigger increments `+0x8e8`. Once that reaches `+0x8e4`, 0x610b20 clears the list, so an entry lives about one trigger round.
- **The event is raised in the trigger update, not in 0x622540**, and carries neither type nor shooter.

## 4. Proposed hook (sw3tp, traffic.c style)

Two E8 call-site patches on the `call 0x610e00` sites. Both run on the game thread, the same thread as Lua, so no locking is needed.

| site | bytes to check (site = the E8) | state at the stub (after the E8 return push) |
|---|---|---|
| **0x61087d** (inside 0x610870, hull path) | `8b 74 24 28 8b d9 8b c6` at 0x610875, then `e8 7e 05 00 00` (→ 0x610e00), then `d9 44 24 1c` | ebx = victim, eax = esi = src; dmg `[esp+0x20]`, type `[esp+0x24]`, dir `[esp+0x28]`, src `[esp+0x2c]` |
| **0x622feb** (inside 0x622540, shield absorbed) | `8b 45 14 8b df` at 0x622fe6, then `e8 10 de fe ff` (→ 0x610e00), then `8b f7 e8 39 6e df ff` | ebx = edi = victim, eax = src = `[ebp+0x14]`; dmg `[ebp+8]`, type `[ebp+0xc]` |

Also check the vtable dwords in 3.1 and the prologues `55 8b ec 83 e4 c0 6a ff 68 fe 18 6e 00` (0x622540) and `83 ec 10 53 56 8b 74 24 28 8b d9` (0x610870).

Stub per site: `pushad`, push (victim, type, src), `call trf_dmg_rec` (stdcall), `popad`, `jmp 0x610e00`. 0x610e00 takes eax and ebx as inputs and ends with a plain `ret`, so the stub must leave both and the stack unchanged.

`trf_dmg_rec(v, type, src)`: id = `[v+0x94]`; slot = a 64-entry table keyed by id (overwrite the oldest). If `src` is set, store `t_hit = GetTickCount()`, `type`, shooter id `[[src+0x54]+0x94]` [I: same base layout]. If `src == 0 && type == 2`, store `t_col` instead.

Native (registered in `trf_register`): `TRF_DmgInfo(id)` → `age_hit_ms, type, shooter_id, age_col_ms` (nil when unknown, -1 when the signature check failed).

Lua use:
- in `TRF_Cb` for the CBH names, mark "hit" only when `age_hit_ms < 1000`;
- in `TRF_CombatSample`, skip a mothership HP drop when `age_col_ms < 750` and `age_hit_ms` is older. A ram also lowers the mothership hull, so source a1 (`why=hp`) can misfire on rams as well [I].

Cost: one table write per damage call (hundreds per second in a large battle) [I].

## 5. Lua-only alternative

Count a "hit" only when the attack events of one ship fall in **2 distinct whole seconds within 6 s**: the `TRF_Ev_Deliberate` stamp logic (trf_events.script:381) with `need = 2`, `win = 6`, applied in `TRF_Cb` before `TRF_CombatMark`.

- False negative: a single shot, or a single burst inside one second, does not mark combat. The mark comes late by up to the time to the next hit (under 1 s for guns, longer for a single missile).
- False positive: a sustained scrape or repeated rams over 2+ seconds still counts. By the static result, a pure ram produces no attack events at all, so the rule mainly filters stray single hits, such as a turret shot while passing.
- No exe dependency, so it stays when the hook signature fails. It does not help source a1 (HP drop from rams); a1 would need its own rule, such as 2 drops in 2 distinct samples.

## 6. Open checks

1. **What hit the trader at gt 19351.982 [U].** Run once with a logging build of the hook (victim id, type, src, shooter id, dmg). Ram a trader with all weapons and turrets disabled and no fighters out. If no `src != 0` line appears, the ram did not cause the event, so look at turret auto-fire, a right-click attack order or a fighter.
2. The log also shows `ev attack id=7 stale gen=39 now=41`: the trigger dated from an older generation, and trader 7 was "gone why=obj" at load. `TRF_Cb` marks combat before the gen test (traffic.script:103), so a stale trigger on a ship the mod no longer tracks still marks combat [V log, code].
3. Missile hits through the projectile path vs only through the explosion 0x49d820 [I].
4. Type 3 source (0x60a600, `carcass+0xacc`) not identified [U].
5. Shooter id via `[src+0x54]+0x94` for pilot-class shooters (class 0x7b6300) [I].
