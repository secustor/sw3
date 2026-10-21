# IMD tools

Helpers for the SW3 mesh format (`Data/OBJECT/*.IMD`). Format notes: `../../design/mod-research/ships/assets.md`.

- `imdparse.py <file|dir> [-v]`: parse and check chunks (GNFO, GMAT, GVTX, GBND, GELP, GREF). Read-only.
- `imd_retexture.py in.IMD out.IMD old.dds=new.dds [...]`: copy a mesh with renamed textures in its GMAT chunks (the reskin route, tier B in `adding-ships.md`). Not yet loaded in game.

Run with `python3 -I`.
