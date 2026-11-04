# Skin tools

Produce and check DDS skins. Need `/usr/local/bin/python3` (Pillow, numpy). Routes and evidence: `../../design/mod-research/ship-asset-pipeline.md` section 2 and `../../design/mod-research/ships/skins.md`.

- `ddsscan.py`: header survey of a DDS tree.
- `dxt.py`: DXT1/3/5 decoder and encoder (library, used by the others).
- `dds2png.py` / `png2dds.py`: decode to RGB and alpha PNG, re-encode with a box-filtered mip chain copying a vanilla header.
- `uvlayout.py`: UV wireframe of an IMD over the texture, for painting.
- `recolor.py`: hue-band recolour of a vanilla skin, alpha preserved.
- `decal.py`: composite a decal PNG onto a skin.
- `preview3d.py`: software render of an IMD with a skin.
- `verify_skin.py`: compare a new DDS with its vanilla reference (header, size, mips, alpha).

Nothing produced here has been loaded by the game yet.
