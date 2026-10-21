"""Erase the existing emblem inside a box (texels whose alpha > 0) and stamp a new decal, modulated by the
base texture's luminance so wear and grime stay visible. Works on the PNG pair written by dds2png.py.
Usage: python3 -I decal.py <rgb.png> <alpha.png> <decal_rgba.png> <x0,y0,x1,y1> [<x0,y0,x1,y1>...] --out <prefix> [--alpha-level N]"""
import sys, numpy as np
from PIL import Image
args = sys.argv[1:]; out = args[args.index('--out') + 1]
lvl = int(args[args.index('--alpha-level') + 1]) if '--alpha-level' in args else None
rgbp, alp, decp = args[:3]; boxes = [tuple(map(int, b.split(','))) for b in args[3:] if b.count(',') == 3]
rgb = np.asarray(Image.open(rgbp).convert('RGB')).astype(np.float32).copy(); a = np.asarray(Image.open(alp).convert('L')).copy()
dec = Image.open(decp).convert('RGBA')
for x0, y0, x1, y1 in boxes:
    R = rgb[y0:y1, x0:x1]; A = a[y0:y1, x0:x1]; em = A > 0
    lev = lvl if lvl is not None else int(np.median(A[em])) if em.any() else 170
    base = np.median(R[~em], 0) if (~em).any() else R.reshape(-1, 3).mean(0)
    # erase: replace emblem texels by the median background colour and clear their alpha
    R[em] = base; A[em] = 0
    d = np.asarray(dec.resize((x1 - x0, y1 - y0), Image.LANCZOS)).astype(np.float32)
    k = d[..., 3:4] / 255
    shade = np.clip(R.mean(-1, keepdims=True) / max(R.mean(), 1), 0.6, 1.3)
    R[:] = R * (1 - k) + d[..., :3] * shade * k
    A[:] = np.maximum(A, (k[..., 0] * lev + 0.5).astype(np.uint8))
    print('box', (x0, y0, x1, y1), 'erased', int(em.sum()), 'texels, decal alpha level', lev)
Image.fromarray(rgb.clip(0, 255).astype(np.uint8)).save(out + '_rgb.png'); Image.fromarray(a).save(out + '_alpha.png'); print('wrote', out + '_rgb.png', out + '_alpha.png')
