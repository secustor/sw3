# Corporation carriers: offline data (A22, proposals 6 item 19)

Date 2026-11-04. Offline reads of the read-only test clone (`G` = `~/Games/Heroic/sw3-tp-test/Data`) and the mod's `map.script`. Used by [../corp-carriers-spec.md](../corp-carriers-spec.md); the lore-attribution list (section 3) is also the input B15 needs (proposals 2b.8). Script: `.work/corp/region_owners.py` (python3 -I, reads `map.script` and `G/Scripts/include/FloodTradeStations.script`).

## 1. The corporations

`G/LocData/English/x_news.loc` `M_mail_torg4_LDesc` (the FTU handbook): "almost all of the inhabited space had been controlled by three major corporations - InoCo, USS and Triada". The same text gives the carrier lore the spec turns into weights:
- USS "is always concerned with good security and transporters for its caravans"; its shops "offer the widest range of merchandise".
- Triada "can provide freelancers with contract work, although mostly illegal"; "decent quality at reasonable prices"; a black-market player.
- InoCo "is considered to be the most self-contained company which rarely applies for free traders' services"; "prices in InoCo shops are high, but the equipment for sale is top tier".

No other corporation has a team, a shop list or a gun list: `Location_SideList` (`G/Scripts/include/FloodTradeStations.script` 11-76) knows Vks, Kfni, Triada, Uss, Inoco and Neutral; "Standard Corporation" occurs once in the loc files and nowhere in the scripts. The mod's faction index already carries them: `TRF_FacTeams()` = Vks, Kfni, Triada (3), Uss (4), Inoco (5) (`trf_faction.script` 280).

## 2. Owners per region (static `Location_SideList`, systems with `pc > 0` in `map.script`)

| Slot | Region | Trade systems (`pc > 0`) | Triada | USS | InoCo | Corporation systems |
|---|---|---|---|---|---|---|
| 1 | Dosis | 13 | 8 | 4 | 0 | dosis, fronn, kitaro, kondel, ule, xt39, xt45, xt52 (Triada); dalled, deosis, fiasar, kadenoa (USS) |
| 2 | Elinor | 11 | 0 | 0 | 0 | - |
| 3 | Gefest | 8 | 0 | 0 | 0 | (vulcan is InoCo, `pc = 0`) |
| 4 | Golkonda | 13 | 4 | 4 | 0 | debris3, debris6, golkonda, xt05 (Triada); debris4, xb13, xb15, xt11 (USS) |
| 5 | Kadi | 17 | 0 | 2 | 5 | el_ariash, ergelan (USS); ashelon, gaoba, hafa, lidau, xk10 (InoCo); b_leftera1-3 are Triada with `pc = 0` |
| 6 | Moscowia | 7 | 0 | 0 | 3 | danstag, egleon, heos (InoCo) |
| 7 | Torr | 4 | 0 | 0 | 0 | - |
| 8 | xt27 | 6 | 1 | 0 | 0 | xt93 (Triada) |

Run-time changes: `HafaLife == "Vks"` moves Hafa to Vks (Kadi InoCo 5 -> 4); `Transfer_To_NI` moves only Vks systems to Kfni. The module counts with `GetLocationTeam` at each MapInitialization, so both are followed.

## 3. Lore-attributed modules (`G/LocData/English/m_modules.loc` `#M_LDesc_*`)

| Item | Name | Maker in the text | Cost (`map.script` `it`) | In which trader-shop pool |
|---|---|---|---|---|
| PLC2 | M-805 Shining | InoCo finished the imperial prototype and adopted it | 110,000 | `Gun_List_InoCo[2]` (also Vks, Kfni, Triada, Uft [2]) |
| RBot3 | Gremlin | InoCo engineers, Precursor tech | 23,000 | `Syst_List` (every owner) |
| LRRNB3 | Sigil | InoCo | 22,000 | `Syst_List` |
| ALS2 | Ruby | "only for InoCo's own use ... not present on the open market" | 180,000 | `Syst_List` (lore says not sold; excluded) |
| WBoost3 | Cold Wave | "this USS development" | 10,000 | `Syst_List` |
| AC4, PC3, PLC3, SRM4, AMS3, AMS4, RBot4, LRRNB4, BSL1 | | InoCo | | not in any trader-shop pool (`[3]` rows or no list) |
| HC3 | M-113 Halberd | USS | | not in `Gun_List_Uss` (USS lists no HC) |
| ALS0 | Sapphire | USS, with InoCo parts | | not in `Syst_List` |
| PC1, PLC2, BSL1, AC3, DF, ManAmp2, RNBot4 | | "imperial" / "Empire" | | (empire, not a corporation) |

No text names Triada as a maker. Trader shops draw `Gun_List_<owner>[1]` and `[2]` plus `Syst_List` (`trf_shop.script` `TRF_ShopEquipPool`), where owner is the docked system's team; the five items above that are in those pools can be named for their maker without adding an item the trader shops do not already sell. Pools of the three corporations (`FloodTradeStations.script` 592-612): USS VC1 CG1 AC1 / VC2 CG2 AC2; Triada VC1 PLC1 PC1 AC1 / VC2 PLC2 PC2 AC2; InoCo LC1 PLC1 RG1 / LC2 PLC2 RG2.

Not decoded: the per-shop count tables `NShop_<owner>` of `G/Scripts/InitTradeSystem.script` (132-256, positional rows). B15's "first stage a vanilla shop stocks the item" test needs them; A22 does not, because it stays inside the trader-shop pools.
