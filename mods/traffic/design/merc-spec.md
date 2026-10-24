# Mercenary clans: implementation spec (merged 12 + 13, build steps 1 and 2)

Status: build step 2 (shared helpers) implemented and host-tested 2026-10-25; build step 1 (pure clan record) follows in the next commit. Not run in the game. Design: `D/worldbuilding/12-mercenary-packs.md` ("12 n.n"), `D/worldbuilding/13-rival-packs.md` ("13"), the proposals `D/proposals/merc-unified-clans.md` ("UC") and `D/proposals/merc-trader-reuse.md` ("TR"); shared rules: `D/worldbuilding/00-economy-and-progression.md` sections 6 and 8 ("00"); plumbing: `D/wb-plumbing-spec.md` ("WB"). Gap numbers ("gap n") refer to the list of open spec gaps drafted with the build brief (2026-10-24, 29 items).
Paths: `D` = `mods/traffic/design`, `S` = `mods/traffic/Data/Scripts/Mods/Traffic`, `T` = `mods/traffic/tests`, `G` = the game's `Data`.

## 1. Scope

| Build step (12 section 9) | Content | State |
|---|---|---|
| 2 | TR G items 1-6 as the merged spec names them: width-parameterised packing (`TRF_TpPackK`/`TRF_TpUnpackK`), `TRF_Charge`, `TRF_CanSpawn` kind `merc`, the adoption registration `TRF_PlAdoptReg`, the group prefix `Hunt`, the death bus (`TRF_DeathReg`, `TRF_Dead`, called from the raid and captain deaths), the group-war toggles | built (section 4) |
| 1 | `trf_merc.script` pure part: record, fortune, stages, rival candidate rule, Black Legion pure part | next commit |
| 3-9 | hire role, rival role, P bundle, corvette, mothership, Legion actions, outpost | not built |

## 2. Decisions

| Gap / question | Decision | Config |
|---|---|---|
| gap 2 (TR vs 12 naming) | spawn kind `merc` (12) instead of TR's `pack`/`hunt`; adoption by a registration call from the module (`TRF_PlAdoptReg`) instead of TR's `TRF_PlKeepReg` or a literal `Merc=1`, so a save loaded with the module off still has its `trf_merc_*` labels scanned | - |
| gap 9, gap 15 (group war against the player defaults on) | four off keys: `merc_war` (betrayal fight-back; 0: a betrayed pack leaves through its portal), `merc_hunt` (M14 hunters at war at spawn), `merc_hostile` (rival HOSTILE meetings, replaces 13's `rv_hostile` 1), `merc_legion` (the Legion's rival entry and HOSTILE variant, 11.4); all 0 until E0.13 | `merc_war`, `merc_hunt`, `merc_hostile`, `merc_legion` |
| gap 13, TR F.12 (`lk` on fees, shares, blood money) | no `lk`: they are charges, not pay. Price level term `TRF_LChargeK(idx)` = `L_w x d_k` (00 A1-A2) | - |
| gap 23 (packing limits) | `TRF_TpPackK(r, ks)` / `TRF_TpUnpackK(s, ks, len)` take the key list and the length; the old `TRF_TpPack`/`TRF_TpUnpack` are wrappers with the 14 pool keys and 80 characters, so every current string is unchanged (v1 host runs) | - |
| gap 24 (missing helpers) | `TRF_Charge`, the death bus, the adoption registration, kind `merc` and the `Hunt` prefix are built; `TRF_GnFindG` already finds `merc_<n>` signs, so the TR sign change is dropped; `rd.pk` does not exist and is not added (the death bus carries the player-fire flag instead) | - |

## 4. Shared helpers (build step 2)

**Packing (`S/trf_track.script`).** `TRF_TpPackK(r, ks)`: one integer per key of `ks`, comma separated, missing or non-number fields 0, `floor`. `TRF_TpUnpackK(s, ks, len)`: nil unless `s` holds exactly `getn(ks)` integers with single commas and at most `len` characters (default 11 per key). Bound: `format("%d")` converts through a C int, which is 32 bits in the game's Lua 4.0.1, so every packed value must lie in -(2^31 - 1) .. 2^31 - 1 (`TRF_TpMax()` = 2,147,483,647). The game (x86) wraps a value above it, the host (arm64) saturates it, so a host run cannot show an overflow; `TRF_TpPackK` therefore clamps to the bound itself and both give the same string. The clan record keeps every field far below the bound (section 3, when built). Host: `v1-h` (28 integers at the bound round-trip, 167 characters; the 80-character and 14-key limits refuse them; `1e12` packs as the bound; malformed strings refused; the 14-key pool string unchanged).

**Charges (`S/trf_region.script`).** `TRF_Charge(n, why, reserve)` beside `TRF_Pay`: `n = min(floor(n), charge_cap)` (tune, default 250,000: above the worst settlement of a late hire, 7 counted kills x 6,400 share plus 7 lost ships x 25,600 blood money = 224,000; a larger charge is cut and the caller keeps the rest as debt); refused with `0, "short"` while the wallet is below `reserve` (default `n`, so a fee is all or nothing; `reserve` 0 takes what the wallet holds, at most `n`, for a settlement); `SubPlayerCredits(min(n, wallet))`, never more than the wallet and never negative; stat `charge_<why>`; `module=region event=charge`. Returns the amount taken (and nil), or 0 and the reason (`none`, `no_native`, `short`, `error`). The fee check of 12 section 5 (`wallet >= 2 x (fee + owe)`) is `TRF_Charge(fee, "merc_fee", 2 * (fee + owe))`. Host: `v1-h`.

**Spawn kind `merc` (`S/trf_safety.script`).** `TRF_CanSpawn(n, "merc", ev)`: suppression, the strict gate of feature `merc` (deny entries with `merc = 0` apply), no spawn while the governor holds, `ev + n <= mc_ships` (tune, 7; `ev` = live ships of the clan visit, a big ship included), then `cap_ships` with the registered groups and parked ships, without the trader count. Spare = the lower of the two rooms. Over `cap_ships` the registered groups are trimmed first as for every kind. Refusals: `supp`, `gate`, `gov`, `merc_cap`, `ships` (`event=no_spawn kind=merc`, `event_cap` = `mc_ships`). Host: `pl-e`.

**Adoption registration (`S/trf_plumb.script`).** `TRF_PlAdoptReg(name)`: `name` must be one of `TRF_PlGroups`; `TRF_PlAdopt()` returns `{Nest = 1}` plus the registered names. The registrations are in the chunk local, so they start empty at every MapInitialization; a module registers from its `TRF_<M>_Plumb` (run by `TRF_InstallPlumb` before `TRF_Pl_OnLoad`'s scan). Nest is unchanged (fixed entry). Merc registers nothing in steps 1-2 (no ships); the hire role of step 3 registers it together with its own deletion of unhired ships at load. Host: `pl-e` (registered Merc kept by a scan in the same MapInitialization, Cust and Hunt deleted; after a load nothing registered, the merc ship is an orphan).

**Group prefix `Hunt`.** In `TRF_PlGroups` (orphan scan of `trf_hunt_<n>_<j>`, globals `TRF_GHunt_*`) and in `GROUP_PREFIXES` of `tools/lint_lua.py`; 00 section 6 updated. `Merc` was already in both lists.

**Death bus (`S/trf_plumb.script`).** `TRF_DeathReg(m)` (once per module name), `TRF_Dead(kind, rec, ship, pfire)` calls every `TRF_<m>_OnDeath(kind, rec, ship, pfire)` protected, in registration order, and returns the number called (`event=death`, level 2). Sites: trf_raid `TRF_Rd_DiedBody` (`kind` `raid`, `rec = {g = "TRF_Raid_<n>", n = raid id, j = ship index}`, `pfire` 1 when the player group hit that ship within `hit_win`, the same rule as the 8.5 kill-after-hit help) and trf_captain `TRF_CapDeath` (`kind` `cap`, `rec = {g = "TRF_Cap_<slot>", n = slot, j = 1}`, `pfire` = the claim's hit rule; no call for `why = jump`). No module registers yet, so no behaviour changes. The hire role needs exactly this: a death in a group the pack is seeded at war with, and whether the player fired. trf_raid has no per-raid kill record (`rd.pk` of TR G item 7); it keeps `rd.ph` (any player hit on the raid) and `rd.lh[j]` (last hit per ship), which the bus turns into the per-death flag, so no accessor is added. Host: `pl-e` (dispatch, the error of a handler caught and logged, a second registration ignored), `v02-i` (one call per raid ship death, player fire only for the hit ship), `cap-f` (the captain's death with and without player fire).

**Group-war toggles.** `merc_war`, `merc_hunt`, `merc_hostile`, `merc_legion` (all 0) in `config.script` and `TRF_Pl_OptDef` (section 2). Read by nothing yet.

## 12. Deviations

- D1 The brief lists the war toggles "in TuneDef/OptDef where the module reads them"; the module is build step 1, so the defaults live in `TRF_Pl_OptDef` (plumbing), which keeps them defined with trf_merc off or missing and keeps the `v02-a` rule that every `config.script` key equals its module default. The module reads them through `TRF_Opt`.
- D2 `TRF_TpPackK` clamps to the 32-bit bound instead of only documenting it: the game would wrap and the host saturate, so the clamp makes both give the same string; no current value comes near the bound, so no existing string changes.
- D3 `rd.pk` (TR G item 7) is not added: the death bus carries `pfire` per death (section 4), which is the fact the hire role needs; the 8.5 factor of step 3 reads the bus or `rd.hit`.
- D4 `TRF_Charge` has its own cap `charge_cap` 250,000 instead of `pay_cap` 30,000: 12 section 5 leaves the share uncapped, and the cap is a safety bound against a wrong amount; the fee itself is capped at `pay_cap` by its formula.

## 13. Left out

- Build step 1 (next commit) and steps 3-9 (12 section 9).
- Death-bus sites in trf_faction, trf_clan, trf_events, trf_base and trf_stash (TR G items 9, 11), the row pick with table arguments, `opt.pil`/`opt.row`, the fight-open lines (`rd.ph`, `TRF_CapOpen`), the survivors pod entry point (TR G items 7, 8, 10): build step 5.
- The digit helpers with a width argument (TR G item 2): the clan record of step 1 keeps its own digit accessors over `s`.
