"""Procedural recolour of a vanilla DXT skin, preserving alpha and mip count.
Usage: python3 -I recolor.py <scripts dir> <in.dds> <out.dds> --hue-lo 20 --hue-hi 75 --sat-min 0.25 --target-hue 280
       [--sat-scale 1.0] [--val-scale 1.0] [--format DXT3] [--preview out.png] [--rgba8 out_rgba8.dds]
Each vanilla mip level is decoded, recoloured with the same per-texel function, and re-encoded with
Pillow's BCn encoder; the 128-byte vanilla header is copied unchanged, so header, size and mip count match."""
import sys, argparse
sys.path.insert(0, sys.argv[1]); import dxt
import numpy as np
from PIL import Image

def rgb2hsv(rgb):
    f = rgb.astype(np.float32) / 255; r, g, b = f[..., 0], f[..., 1], f[..., 2]
    mx = f.max(-1); mn = f.min(-1); c = mx - mn; cs = np.where(c > 0, c, 1)
    h = np.where(mx == r, ((g - b) / cs) % 6, np.where(mx == g, (b - r) / cs + 2, (r - g) / cs + 4)) * 60
    h = np.where(c > 0, h, 0); s = np.where(mx > 0, c / np.where(mx > 0, mx, 1), 0)
    return h, s, mx

def hsv2rgb(h, s, v):
    h = (h % 360) / 60; i = np.floor(h).astype(int) % 6; f = h - np.floor(h)
    p = v * (1 - s); q = v * (1 - s * f); t = v * (1 - s * (1 - f))
    r = np.choose(i, [v, q, p, p, t, v]); g = np.choose(i, [t, v, v, q, p, p]); b = np.choose(i, [p, p, t, v, v, q])
    return (np.stack([r, g, b], -1) * 255 + 0.5).clip(0, 255).astype(np.uint8)

def smooth(x, a, b):
    t = np.clip((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t)

def recolor(rgba, a):
    h, s, v = rgb2hsv(rgba[..., :3])
    mid = (a.hue_lo + a.hue_hi) / 2; half = (a.hue_hi - a.hue_lo) / 2
    dist = np.abs((h - mid + 180) % 360 - 180)
    w = smooth(s, a.sat_min * 0.6, a.sat_min) * (1 - smooth(dist, half * 0.8, half * 1.2))  # soft mask 0..1
    nh = a.target_hue + (h - mid)            # keep the hue spread of the source region
    ns = np.clip(s * a.sat_scale, 0, 1); nv = np.clip(v * a.val_scale, 0, 1)
    new = hsv2rgb(nh, ns, nv).astype(np.float32)
    out = rgba.copy()
    out[..., :3] = (rgba[..., :3] * (1 - w[..., None]) + new * w[..., None] + 0.5).clip(0, 255).astype(np.uint8)
    return out, w

def encode(rgba, fourcc):
    h, w = rgba.shape[:2]
    if h < 4 or w < 4:  # pad to one 4x4 block by edge replication; DDS stores one block for 2x2 and 1x1
        rgba = np.pad(rgba, ((0, max(0, 4 - h)), (0, max(0, 4 - w)), (0, 0)), mode='edge')
    return dxt.encode_level(rgba, fourcc)

def main():
    ap = argparse.ArgumentParser(); ap.add_argument('scripts'); ap.add_argument('src'); ap.add_argument('dst')
    ap.add_argument('--hue-lo', type=float, required=True); ap.add_argument('--hue-hi', type=float, required=True)
    ap.add_argument('--sat-min', type=float, default=0.25); ap.add_argument('--target-hue', type=float, required=True)
    ap.add_argument('--sat-scale', type=float, default=1.0); ap.add_argument('--val-scale', type=float, default=1.0)
    ap.add_argument('--format', default=None); ap.add_argument('--preview'); ap.add_argument('--rgba8')
    a = ap.parse_args()
    d = dxt.read_dds(a.src); fcc = (a.format or d['fourcc'].decode()).encode()
    assert fcc == d['fourcc'], 'header copy requires the same format as the source'
    w, h = d['W'], d['H']; levels = []; tops = None; rgba8 = []
    for i, raw in enumerate(d['mips']):
        src = dxt.decode(raw, w, h, d['fourcc'])
        out, m = recolor(src, a)
        enc = encode(out, fcc); assert len(enc) == len(raw), (i, len(enc), len(raw))
        levels.append(enc); rgba8.append(out)
        if i == 0: tops = (src, out, m)
        w, h = max(1, w // 2), max(1, h // 2)
    dxt.write_dds(a.dst, d['header'], levels)
    print('wrote', a.dst, 'levels', len(levels), 'mask coverage top %.1f%%' % (100 * (tops[2] > 0.5).mean()))
    if a.preview:
        src, out, m = tops; S = 512
        row = [Image.fromarray(src[..., :3]), Image.fromarray(out[..., :3]), Image.fromarray((m * 255).astype(np.uint8)).convert('RGB')]
        sheet = Image.new('RGB', (S * 3, S)); [sheet.paste(r.resize((S, S)), (S * i, 0)) for i, r in enumerate(row)]
        sheet.save(a.preview); print('preview', a.preview)
    if a.rgba8:
        hdr = bytearray(d['header'])
        import struct
        # A8R8G8B8 with the same mip count: flags CAPS|HEIGHT|WIDTH|PITCH|PIXELFORMAT|MIPMAPCOUNT, pitch = 4*W,
        # pixel format RGB|ALPHAPIXELS 32 bit masks ff0000/ff00/ff/ff000000 (as vanilla RGB32A files), caps COMPLEX|TEXTURE|MIPMAP|ALPHA
        struct.pack_into('<I', hdr, 8, 0x2100F); struct.pack_into('<I', hdr, 20, 4 * d['W'])
        struct.pack_into('<8I', hdr, 76, 32, 0x41, 0, 32, 0xFF0000, 0xFF00, 0xFF, 0xFF000000)
        struct.pack_into('<I', hdr, 108, 0x401002 | 0x1008)
        with open(a.rgba8, 'wb') as f:
            f.write(hdr)
            for lv in rgba8: f.write(lv[..., [2, 1, 0, 3]].tobytes())  # BGRA in memory = A8R8G8B8
        print('wrote', a.rgba8)

if __name__ == '__main__': main()
