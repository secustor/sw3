"""Software preview of an IMD with a DDS skin (z-buffer, Lambert + texture, no alpha effects).
Usage: python3 -I preview3d.py <scripts dir> <imd> <tex.dds> <out.png> [--size 512]
Renders three orthographic views (top, side, three-quarter). Texture lookup uses (u mod 1, v mod 1), as uvlayout.py."""
import sys, argparse, numpy as np
sys.path.insert(0, sys.argv[1]); import dxt
from uvlayout import read_imd
from PIL import Image
ap = argparse.ArgumentParser(); ap.add_argument('scripts'); ap.add_argument('imd'); ap.add_argument('tex'); ap.add_argument('out'); ap.add_argument('--size', type=int, default=512)
a = ap.parse_args(); N = a.size
d = dxt.read_dds(a.tex); T = dxt.decode(d['mips'][0], d['W'], d['H'], d['fourcc'])[..., :3].astype(np.float32); TH, TW = T.shape[:2]
mats, subs = read_imd(a.imd)
P = np.concatenate([s['xyz'] for s in subs]); UV = np.concatenate([s['uv'] for s in subs]); off = np.cumsum([0] + [len(s['xyz']) for s in subs])
F = np.concatenate([s['faces'].astype(np.int64) + off[i] for i, s in enumerate(subs)])
def rot(ax, deg):
    c, s = np.cos(np.radians(deg)), np.sin(np.radians(deg))
    return {'x': np.array([[1, 0, 0], [0, c, -s], [0, s, c]]), 'y': np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]]), 'z': np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])}[ax]
views = [rot('x', -90), np.eye(3) @ rot('y', 90), rot('x', -35) @ rot('y', 35)]
L = np.array([0.3, 0.5, 0.8]); L /= np.linalg.norm(L)
imgs = []
for R in views:
    Q = P @ R.T; r = np.abs(Q[:, :2]).max() * 1.05
    X = (Q[:, 0] / r * 0.5 + 0.5) * (N - 1); Y = (0.5 - Q[:, 1] / r * 0.5) * (N - 1); Z = Q[:, 2]
    img = np.zeros((N, N, 3), np.float32) + 20; zb = np.full((N, N), -np.inf)
    for f in F:
        x, y, z, uv = X[f], Y[f], Z[f], UV[f]
        e1, e2 = Q[f[1]] - Q[f[0]], Q[f[2]] - Q[f[0]]; n = np.cross(e1, e2); nn = np.linalg.norm(n)
        if nn == 0: continue
        shade = 0.25 + 0.75 * abs(n @ L) / nn
        x0, x1 = int(max(0, np.floor(x.min()))), int(min(N - 1, np.ceil(x.max()))); y0, y1 = int(max(0, np.floor(y.min()))), int(min(N - 1, np.ceil(y.max())))
        if x1 < x0 or y1 < y0: continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        den = (y[1] - y[2]) * (x[0] - x[2]) + (x[2] - x[1]) * (y[0] - y[2])
        if abs(den) < 1e-9: continue
        w0 = ((y[1] - y[2]) * (gx - x[2]) + (x[2] - x[1]) * (gy - y[2])) / den
        w1 = ((y[2] - y[0]) * (gx - x[2]) + (x[0] - x[2]) * (gy - y[2])) / den; w2 = 1 - w0 - w1
        m = (w0 >= 0) & (w1 >= 0) & (w2 >= 0)
        if not m.any(): continue
        zz = w0 * z[0] + w1 * z[1] + w2 * z[2]; sub = zb[y0:y1 + 1, x0:x1 + 1]; m &= zz > sub
        u = (w0 * uv[0, 0] + w1 * uv[1, 0] + w2 * uv[2, 0]) % 1.0; v = (w0 * uv[0, 1] + w1 * uv[1, 1] + w2 * uv[2, 1]) % 1.0
        col = T[(v * TH).astype(int).clip(0, TH - 1), (u * TW).astype(int).clip(0, TW - 1)] * shade
        sub[m] = zz[m]; img[y0:y1 + 1, x0:x1 + 1][m] = col[m]
    imgs.append(img.clip(0, 255).astype(np.uint8))
Image.fromarray(np.concatenate(imgs, 1)).save(a.out); print('wrote', a.out)
