"""Build a DXT DDS with a full box-filtered mip chain from an RGB PNG plus an alpha PNG, copying the
128-byte header of a vanilla reference DDS of the same size and format.
Usage: python3 -I png2dds.py <scripts dir> <rgb.png> <alpha.png|-> <reference.dds> <out.dds>
'-' for alpha keeps the reference's top-level alpha."""
import sys; sys.path.insert(0, sys.argv[1]); import dxt, numpy as np
from PIL import Image
rgbp, ap, refp, outp = sys.argv[2:6]
ref = dxt.read_dds(refp); W, H, fcc = ref['W'], ref['H'], ref['fourcc']
rgb = np.asarray(Image.open(rgbp).convert('RGB')); assert rgb.shape[:2] == (H, W), ('size must match reference', rgb.shape, W, H)
if ap == '-': a = dxt.decode(ref['mips'][0], W, H, fcc)[..., 3]
else: a = np.asarray(Image.open(ap).convert('L')); assert a.shape == (H, W)
top = np.dstack([rgb, a]).astype(np.uint8)
levels = []
for i, lv in enumerate(dxt.mip_chain(top, len(ref['mips']))):
    h, w = lv.shape[:2]
    if h < 4 or w < 4: lv = np.pad(lv, ((0, max(0, 4 - h)), (0, max(0, 4 - w)), (0, 0)), mode='edge')
    enc = dxt.encode_level(lv, fcc); assert len(enc) == len(ref['mips'][i]); levels.append(enc)
dxt.write_dds(outp, ref['header'], levels); print('wrote', outp, len(levels), 'levels', fcc.decode())
