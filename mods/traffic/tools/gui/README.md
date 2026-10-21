# GUI asset tools

Slot screen and icon files for a hull. Formats: `../../design/mod-research/ship-asset-pipeline.md` section 4 and `../../design/mod-research/ships/gui-assets.md`.

- `slotini.py`: parse and check `TEXTURE/Interface/Carcass/Slots/*.ini` against the hull's GREF refpoints (uses `../imd/imdparse.py`).
- `tuv.py`: parse and write `.tuv` atlas descriptions (byte-exact round trip on `ships.tuv`).
- `render.py`: orthographic render of an IMD for icons and the slot picture (needs ffmpeg for DDS decode).
- `ddswrite.py`: write uncompressed or DXT DDS for icons.
- `cellfill.py`: place a picture into an atlas cell.

Standard library only, except where noted. Nothing produced here has been loaded by the game yet.
