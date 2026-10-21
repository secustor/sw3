"""Render the UV layout of an IMD as PNG (wireframe per material, optionally over a texture).
Usage: python3 -I uvlayout.py <imd> <out.png> [--size N] [--tex texture.dds] [--masks prefix]
UV mapping: texel = (u mod 1, v mod 1) with D3D convention (v down), which is what WRAP addressing samples."""
import sys, struct, os, argparse
import numpy as np
from PIL import Image, ImageDraw

def read_imd(path):
    d = open(path, 'rb').read(); assert d[:4] == b'LIBF'
    mats, subs = [], []
    o = 12
    while o < len(d):
        tag = d[o:o+4]; size, = struct.unpack_from('<I', d, o+4)
        if tag == b'GNFO':
            p = o + 48
            while p < o + size:
                t = d[p:p+4]; s, = struct.unpack_from('<I', d, p+4)
                if t == b'GMAT':
                    nl, = struct.unpack_from('<I', d, p+12); name = d[p+16:p+16+nl].split(b'\0')[0].decode('latin1')
                    q = p + 16 + nl + 76; nt, = struct.unpack_from('<I', d, q); q += 4; tex = []
                    for _ in range(nt):
                        sl, l = struct.unpack_from('<II', d, q); q += 8; tex.append((sl, d[q:q+l].split(b'\0')[0].decode('latin1'))); q += l + 4
                    mats.append((name, tex))
                elif t == b'GVTX':
                    ver, mat, area, V, F = struct.unpack_from('<IIfII', d, p+8)
                    q = p + 28
                    vx = np.frombuffer(d, '<f4', V*5, q).reshape(V, 5); q += 20*V
                    fc = np.frombuffer(d, '<u2', F*3, q).reshape(F, 3)
                    subs.append(dict(mat=mat, xyz=vx[:, :3], uv=vx[:, 3:5], faces=fc))
                p += s
        o += size
    return mats, subs

COLS = [(255, 64, 64), (64, 255, 64), (64, 128, 255), (255, 255, 0), (255, 0, 255), (0, 255, 255), (255, 128, 0), (200, 200, 200)]

def main():
    ap = argparse.ArgumentParser(); ap.add_argument('imd'); ap.add_argument('out')
    ap.add_argument('--size', type=int, default=1024); ap.add_argument('--tex'); ap.add_argument('--masks')
    ap.add_argument('--only-tex', help='only submeshes whose material slot-1 texture matches this name (case-insensitive)')
    a = ap.parse_args(); N = a.size
    mats, subs = read_imd(a.imd)
    if a.tex:
        bg = Image.open(a.tex).convert('RGB').resize((N, N)); bg = Image.eval(bg, lambda x: x // 2)
    else:
        bg = Image.new('RGB', (N, N), (0, 0, 0))
    dr = ImageDraw.Draw(bg); masks = {}
    for si, s in enumerate(subs):
        name, tex = mats[s['mat']]
        t1 = [n for sl, n in tex if sl == 1]
        if a.only_tex and not (t1 and t1[0].lower() == a.only_tex.lower()): continue
        uv = s['uv'].astype(np.float64)
        px = np.stack([(uv[:, 0] % 1.0) * N, (uv[:, 1] % 1.0) * N], 1)
        col = COLS[s['mat'] % len(COLS)]
        key = (s['mat'], name, tuple(sl for sl, n in tex))
        m = masks.setdefault(key, Image.new('L', (N, N), 0)); md = ImageDraw.Draw(m)
        for f in s['faces']:
            tri = [tuple(px[i]) for i in f]
            # skip triangles that straddle the wrap seam (their corners land on both sides)
            xs = [p[0] for p in tri]; ys = [p[1] for p in tri]
            if max(xs) - min(xs) > N / 2 or max(ys) - min(ys) > N / 2: continue
            md.polygon(tri, fill=255)
            dr.line(tri + [tri[0]], fill=col, width=1)
        print('sub', si, 'mat', s['mat'], name, tex, 'V', len(uv), 'F', len(s['faces']),
              'u[%.3f,%.3f] v[%.3f,%.3f]' % (uv[:, 0].min(), uv[:, 0].max(), uv[:, 1].min(), uv[:, 1].max()))
    bg.save(a.out)
    if a.masks:
        for (mi, name, slots), m in masks.items():
            fn = '%s_mat%d_slots%s.png' % (a.masks, mi, '-'.join(map(str, slots)))
            m.save(fn); print('mask', fn, 'coverage %.1f%%' % (100 * (np.asarray(m) > 0).mean()))

if __name__ == '__main__': main()
