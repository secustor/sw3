# Shop stock tools

Market rows of trade stations live in the save's `STREAMID_TradeSystem` section. Evidence and the recommended runtime fix: `../../design/mod-research/ship-asset-pipeline.md` section 5 and `../../design/mod-research/ships/shop-save.md`.

- `sections.py`: save section reader (library).
- `trade.py <save> [shop]`: list the markets and rows of a save.
- `shopedit.py IN.sav OUT.sav SHIP N BUYK SELLK [--black] shop...`: add or set a ship row in a copy of a save. Never run on the only copy. Round-trips three real saves byte-identically; an edited save has not been loaded in game.
- `shipstock.script.example`: Lua 4 sketch of the runtime alternative, an idempotent `ShipGoodsState` call at trade-dock time.

Standard library only.
