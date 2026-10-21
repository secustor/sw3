# IMD tools

Helpers for the SW3 mesh format (`Data/OBJECT/*.IMD`). Format notes: `../../design/mod-research/ships/assets.md`.

- `imdparse.py <file|dir> [-v]`: parse and check chunks (GNFO, GMAT, GVTX, GBND, GELP, GREF). Read-only.
- `imd_retexture.py in.IMD out.IMD old.dds=new.dds [...]`: copy a mesh with renamed textures in its GMAT chunks (the reskin route, tier B in `adding-ships.md`). Not yet loaded in game.

Run with `python3 -I`.

Added with the asset pipeline research (`../../design/mod-research/ship-asset-pipeline.md` section 3):

- `imdwrite.py`: reader and writer for the whole format; round-trips all 990 vanilla IMDs byte-exactly.
- `imdconv.py`: OBJ and glTF to IMD and back, refpoints from object names (axis rule UNVERIFIED in game, see P8).
- `kitbash.py recipe.json`: merge, scale and mirror vanilla parts into a new IMD; recipes in `recipes/`.
- `render.py`: software render of an IMD to PNG.
- `imdlib.py`, `imddiff.py`, `imd_fixup.py`: helpers for the SW3SE Blender exporter route (diff two IMDs, fix known exporter defects).

No IMD written by these tools has been loaded by the game yet.
