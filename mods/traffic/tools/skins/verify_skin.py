"""Verify a generated skin against its vanilla source. Usage: python3 -I verify_skin.py <scripts dir> <vanilla.dds> <new.dds> [<rgba8.dds>]"""
import sys, os, hashlib; sys.path.insert(0, sys.argv[1]); import dxt, numpy as np
from PIL import Image
van, new = sys.argv[2], sys.argv[3]
a, b = open(van, 'rb').read(), open(new, 'rb').read()
print('vanilla size', len(a), 'new size', len(b), 'equal size', len(a) == len(b))
print('header bytes 0..127 identical:', a[:128] == b[:128], '| differing header offsets:', [i for i in range(128) if a[i] != b[i]])
print('data identical (expected False):', a[128:] == b[128:], 'sha256 new', hashlib.sha256(b).hexdigest()[:16])
dv, dn = dxt.read_dds(van), dxt.read_dds(new)
print('mip levels vanilla', len(dv['mips']), 'new', len(dn['mips']), 'trailing bytes new', dn['trailing'])
w, h = dv['W'], dv['H']
for i, (rv, rn) in enumerate(zip(dv['mips'], dn['mips'])):
    iv = dxt.decode(rv, w, h, dv['fourcc']); inn = dxt.decode(rn, w, h, dn['fourcc'])
    # encoder round trip on the unmodified vanilla level, as a loss reference
    pad = iv if min(w, h) >= 4 else np.pad(iv, ((0, max(0, 4 - h)), (0, max(0, 4 - w)), (0, 0)), mode='edge')
    rt = dxt.decode(dxt.encode_level(pad, dv['fourcc']), max(4, w), max(4, h), dv['fourcc'])[:h, :w]
    rmse = np.sqrt(((rt[..., :3].astype(float) - iv[..., :3]) ** 2).mean())
    same_a = (iv[..., 3] == inn[..., 3]).mean() * 100; same_a_rt = (iv[..., 3] == rt[..., 3]).mean() * 100
    if i < 3 or i >= len(dv['mips']) - 2:
        print(' level %2d %4dx%-4d alpha identical to vanilla %.2f%% | Pillow round-trip of vanilla: alpha identical %.2f%%, RGB RMSE %.2f, PSNR %.1f dB' % (
            i, w, h, same_a, same_a_rt, rmse, 20 * np.log10(255 / max(rmse, 1e-9))))
    w, h = max(1, w // 2), max(1, h // 2)
pil = Image.open(new); print('Pillow opens new file:', pil.format, pil.size, pil.mode, getattr(pil, 'pixel_format', '?'))
if len(sys.argv) > 4:
    r8 = sys.argv[4]; p = Image.open(r8); p.load()
    exp = 128 + sum(4 * max(1, dv['W'] >> k) * max(1, dv['H'] >> k) for k in range(len(dv['mips'])))
    print('rgba8:', p.size, p.mode, 'file size', os.path.getsize(r8), 'expected', exp)
    top = np.asarray(p); ref = dxt.decode(dn['mips'][0], dv['W'], dv['H'], dn['fourcc'])
    print('rgba8 top level alpha identical to vanilla alpha:', (top[..., 3] == dxt.decode(dv['mips'][0], dv['W'], dv['H'], dv['fourcc'])[..., 3]).all())
