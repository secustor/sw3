"""Orthographic flat-shaded preview of an IMD as PNG (pure Python, z-buffer). Draws GBND spheres as circles
and refpoints as dots. Usage: python3 -I render.py in.IMD out.png [--size 320]
Views left to right: top (looking down -Y, nose up), side (looking from +X, nose right), front (looking -Z)."""
import sys, os, struct, zlib, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import imdwrite as W

def png(path, w, h, rgb):
    raw = b''.join(b'\0' + bytes(rgb[y * w * 3:(y + 1) * w * 3]) for y in range(h))
    def ch(t, d): return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    open(path, 'wb').write(b'\x89PNG\r\n\x1a\n' + ch(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)) +
                           ch(b'IDAT', zlib.compress(raw, 6)) + ch(b'IEND', b''))

VIEWS = {  # (screen x axis, screen y axis (up), depth axis toward viewer) as (index, sign)
    'top':   ((0, 1), (2, 1), (1, 1)),
    'side':  ((2, 1), (1, 1), (0, 1)),
    'front': ((0, -1), (1, 1), (2, 1)),
}

def render(imd, size=320, spheres=True):
    pts = W.all_points(imd)
    R = max((W._len(p) for p in pts), default=1.0) * 1.05
    if imd.get('gbnd'): R = max(R, max([abs(c) + s[3] for s in imd['gbnd']['spheres'] for c in s[:3]] or [0]) * 1.02)
    W_ = size * 3; H = size
    img = bytearray([24, 24, 32] * (W_ * H))
    light = W._norm((0.4, 0.8, 0.45))
    for vi, (name, (ax, ay, az)) in enumerate(VIEWS.items()):
        ox = vi * size; zb = [-1e30] * (size * size)
        def proj(p):
            return ((p[ax[0]] * ax[1] / R + 1) * 0.5 * (size - 1), (1 - (p[ay[0]] * ay[1] / R + 1) * 0.5) * (size - 1), p[az[0]] * az[1])
        for s in imd['submeshes']:
            V = s['verts']
            for (a, b, c), n in zip(s['faces'], s['fnormals']):
                shade = 0.25 + 0.75 * abs(sum(x * y for x, y in zip(n, light)))
                col = (int(200 * shade), int(190 * shade), int(170 * shade))
                P = [proj(V[i]) for i in (a, b, c)]
                x0 = max(int(min(p[0] for p in P)), 0); x1 = min(int(max(p[0] for p in P)) + 1, size - 1)
                y0 = max(int(min(p[1] for p in P)), 0); y1 = min(int(max(p[1] for p in P)) + 1, size - 1)
                (xa, ya, za), (xb, yb, zb_), (xc, yc, zc) = P
                den = (yb - yc) * (xa - xc) + (xc - xb) * (ya - yc)
                if abs(den) < 1e-12: continue
                for y in range(y0, y1 + 1):
                    for x in range(x0, x1 + 1):
                        l1 = ((yb - yc) * (x - xc) + (xc - xb) * (y - yc)) / den
                        l2 = ((yc - ya) * (x - xc) + (xa - xc) * (y - yc)) / den
                        l3 = 1 - l1 - l2
                        if l1 < -1e-6 or l2 < -1e-6 or l3 < -1e-6: continue
                        z = l1 * za + l2 * zb_ + l3 * zc
                        k = y * size + x
                        if z > zb[k]:
                            zb[k] = z; o = (y * W_ + ox + x) * 3; img[o:o + 3] = bytes(col)
        def dot(px, py, col, r=1):
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    x, y = int(px) + dx, int(py) + dy
                    if 0 <= x < size and 0 <= y < size:
                        o = (y * W_ + ox + x) * 3; img[o:o + 3] = bytes(col)
        if spheres and imd.get('gbnd'):
            for s in imd['gbnd']['spheres']:
                cx, cy, _ = proj(s[:3]); rr = s[3] / R * 0.5 * (size - 1)
                for t in range(0, 360, 4):
                    dot(cx + rr * math.cos(math.radians(t)), cy + rr * math.sin(math.radians(t)), (60, 140, 255), 0)
            cx, cy, _ = proj((0, 0, 0)); rr = imd['gbnd']['main'][3] / R * 0.5 * (size - 1)
            for t in range(0, 360, 2):
                dot(cx + rr * math.cos(math.radians(t)), cy + rr * math.sin(math.radians(t)), (90, 90, 120), 0)
        if imd.get('gref'):
            for r in imd['gref']['refs']:
                n = r['name'].lower()
                col = (255, 60, 60) if n.startswith(('biggun', 'smallgun', 'rockets', 'gunpoint', 'turret', 'gkgun')) else \
                      (255, 170, 0) if n.startswith('fire') else (80, 220, 80) if n.startswith('hangar') else None
                if col: px, py, _ = proj(r['m'][12:15]); dot(px, py, col, 2)
        for y in range(H):
            o = (y * W_ + ox) * 3; img[o:o + 3] = bytes((90, 90, 90))
    return W_, H, img

if __name__ == '__main__':
    a = sys.argv[1:]
    size = int(a[a.index('--size') + 1]) if '--size' in a else 320
    w, h, img = render(W.read_file(a[0]), size)
    png(a[1], w, h, img); print('wrote', a[1], w, 'x', h)
