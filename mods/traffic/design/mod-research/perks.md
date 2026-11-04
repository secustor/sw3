# Perks: names, holders and how Lua reads them (proposals 6 item 7)

Question: which perks exist, under which ids and English names, which story pilots carry or can learn the ones a specialist answer needs, and how a script reads a pilot's perk. Offline read of the test clone `~/Games/Heroic/sw3-tp-test/Data` (G below): `Game/Perks.xml`, `Game/Pilots.xml.trf-orig` (the vanilla file; `Pilots.xml` is the mod-merged copy), `LocData/English/m_perks.loc`, `m_pilots.loc`, `Scripts/include/PilotProperties.script`, `Scripts/include/DockStation.script`, the quest scripts, and `mod-research/lua-natives.md`. The game was not run. Script: `.work/spec/perks.py`, `pil.py`, `props.py` (scratch). Tags: [V] seen in files, [I] inferred, [U] unknown.

## 1. Reading a perk from Lua

| # | Fact | Source | Tag |
|---|---|---|---|
| 1.1 | `Pilot:HasProperty(name)` (0x5d8830) answers for perks and for specials (`hack_ship_1`, `summon_*`): `SavePerks` walks one list of both kinds with it | `G/Scripts/include/PilotProperties.script` 60-114 | V |
| 1.2 | `Pilot:HavePerk(name)` (0x5d7af0) exists; vanilla calls it on pilots only for `Tactics`/`Tactics_Exp` | `G/Scripts/AI/Case_Attack.script` 43, 48 | V |
| 1.3 | `Group:HavePerk(name)` (0x5da950): 12 calls, all `Player_Group:HavePerk("F_of_Merchant")`, in 12 quest files (mission 7g, 9c, 12b-e, 16b, 16d, 18a, 19c, 20a). Whether the group test includes the mothership's base pilot is not known | grep | V; base pilot U |
| 1.4 | `Pilot:SetPerk(name)` grants; no remove native exists. Quests grant `F_of_Merchant` and `Repairman` to the Hero and `Repairman` to Yana in `mission_16e/Matrix_Zebos.script` 160-178, 285-303, 413-431, 514-553, 657 | grep | V |
| 1.5 | No native lists the squad; `GetPilot(template)` returns nil for a template never created (0x5e7410, crew-remarks-spec 5.2), so a mod walks a fixed template list and filters with `IsAlive()` and `GetSide() == "Player"` | B06 | V |
| 1.6 | The mothership's own pilot is the attached firmware template (`BasePilot`, `BasePilot_Engine1..3`, `_System1..3`, `_Weapon1..3`, callsign "Mothership"); `AttachNewBaseAI(name)` swaps it (`DockStation.script` 300-322). Lua reaches it as `GetPlayerMotherShip():GetPilot()` [I: `Carcass:GetPilot` 0x5d7810 on the mothership is not traced]; `GetName()` returning the template is proposals 6 item 13 (unverified) | Pilots.xml, DockStation.script | V; reach I |

## 2. Perks a specialist answer could use (Perks.xml id, English name, holders)

| Id | Name (`m_perks.loc`) | Starts with it (Pilots.xml) | Can learn it (PilotProperties tree, cost in points) | Vanilla reads |
|---|---|---|---|---|
| `Repairman` | Repairman | Yana, Josef, Blade, Kalem, Uel, Uel2, Uel3, Uel4; `BasePilot_System1..3` (firmware); InoCo and USS aces | Hero (35 in the pilot, gun and missile trees, 10 in the systems tree), Yana 30, Alex 30, Josef 35, Aia 40, Blade 40, Kalem 20, Uel* 16 | none |
| `Repairman_Exp` | Expert Repairman | Kalem; `BasePilot_System3` | Hero systems tree 75, Yana 50, Josef 100, Kalem 75, Uel 64, Uel4 64 | none |
| `F_of_Merchant` | Intuition | nobody | Hero 50 (every tree) | 12 quests through `Player_Group:HavePerk` |
| `Black_Market` | FTU Warehouse Access | Alex | Hero 75, Alex 5 | none |
| `Systems_2` / `Systems_3` | Advanced / Expert System Engineer | many (Kalem, Cleric, Tramp, Viper, Natali, Blade, Josef, Yana, Uel*) | almost every tree | none |
| `Countermeasures` | Antimissile System Operator | Sedoy, Kalem, Viper, Cleric, Che, Natali, ... | almost every tree | none |
| `hack_ship_1` (special) | - | Cleric, Uel4 | Hero systems tree 15, Cleric 20, Uel4 32 | none |
| `Imperial_Agent`, `Economics`, `Accountancy` | listed, description "... description ..." | nobody | no tree | none (unused, proposals 2b.5) |

Sedoy (Greyhair, from mission 6) starts with `Countermeasures` and `Systems_1` and can learn `Systems_2`, `Systems_3`, `Shields_Op`, `Engine_Op`; neither his start list nor his tree has `Repairman`. Lastochka's tree has no `Repairman` either.

## 3. Who is aboard with `Repairman` (campaign, from `CreatePilot`/`AddPilotToPlayer`)

| Chapters | Holders | Evidence |
|---|---|---|
| 1-20 | the Hero, if the player bought it (any tree) | PilotProperties.script `properties_Hero_*` |
| from the purchase | the mothership with System Firmware Mk 1 (45,000 cr), Mk 2 (95,000 cr), Mk 3 (360,000 cr, also `Repairman_Exp`) at a repair station (DialogR1-R4) | DockStation.script 300-322, DialogR1.xml 116 |
| 9 (branch 9e) on | Yana | `mission_9e/GoShopping_Hafa.script` 253, 520 |
| 10 on | Josef (`JosefFlight` in `Player_Group`) | `mission_10/FrontierSystems_X203.script` 38-41, 143 |
| 13 on | Kalem (`Repairman_Exp`; out while `mission_15e` has removed him) | crew-remarks-spec 5.5 |
| 13e, 14e, 16e, 19c, 20 | Uel (SAM) and copies | `CreatePilot("Uel*")` in those missions |
| 16b on | Blade | `mission_16b_1/Revenge_Dalled.script` 377-378, `16b_2` 352-353 |

So in chapters 4-8 only the Hero (by purchase) and a mothership with System firmware can carry `Repairman`; a story pilot with it joins from chapter 9 or 10. `F_of_Merchant` is the Hero's only, by purchase or by `Matrix_Zebos` (16e).

## 4. Open

- U1 `HasProperty` on a pilot sitting in the hangar (not launched) and on the base pilot (CHECK SPC1, SPC3 of `../specialist-spec.md`).
- U2 Whether `Player_Group:HavePerk` counts the base pilot (not needed by the spec, which tests per pilot).
