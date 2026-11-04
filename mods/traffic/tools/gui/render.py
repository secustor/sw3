"""Software renderer for SW3 IMD meshes (pure Python 3, no numpy/PIL).

Produces:
  icon   : textured, Lambert-shaded orthographic render with alpha, at 128/64/32
           (supersampled), for TEXTURE/Interface/Carcass/{32,64,128}/<flat_image>
  sil    : orthographic top-view silhouette (white on transparent)
  slot   : 512x340 top-view line drawing (visible crease/outline edges) plus the
           slot ini's refpoint markers and leader lines, like the vanilla shipsNN cells

Textures are decoded with ffmpeg (DXT1/3/5 and uncompressed DDS) to raw RGBA.
IMD layout: GVTX = hdr(ver, mat, radius, V, F) + V*(x y z u v) + F*(u16 a b c)
            + V*(nx ny nz) + F*(nx ny nz)  (SW3SE imd_format.ksy.txt:164-228).
Model axes (from GREF): +z nose (engines 'Fire:' at z<0), +y up, -x = ship's left
('Rockets:left' x=-0.246 in Excalibur_Gamer.IMD).

Usage:
  python3 -I render.py icon <imd> <out_prefix> [--yaw -140 --tilt 58 --tex-dir DIR]
  python3 -I render.py sil  <imd> <out.png> [size]
  python3 -I render.py slot <imd> <slot.ini> <out.png> [--scale S --cx X --cy Y --crease DEG]
"""
import math
import os
import struct
import subprocess
import sys
import zlib

TEXDIR_DEFAULT = '/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data/TEXTURE'


# ---------------------------------------------------------------- IMD reading
def cstr(b):
    return b.split(b'\0')[0].decode('latin-1')


def load_imd(path):
    d = open(path, 'rb').read()
    assert d[:4] == b'LIBF' and d[8:12] == b'IDFM'
    mats, meshes, refs = [], [], []
    o = 12
    while o < len(d):
        tag = d[o:o + 4]
        size = struct.unpack_from('<I', d, o + 4)[0]
        if tag == b'GNFO':
            p = o + 48
            while p < o + size:
                t = d[p:p + 4]
                s = struct.unpack_from('<I', d, p + 4)[0]
                if t == b'GMAT':
                    nl = struct.unpack_from('<I', d, p + 12)[0]
                    name = cstr(d[p + 16:p + 16 + nl])
                    q = p + 16 + nl + 8 + 64 + 4
                    ntex = struct.unpack_from('<I', d, q)[0]
                    q += 4
                    tex = {}
                    for _ in range(ntex):
                        slot, l = struct.unpack_from('<II', d, q)
                        q += 8
                        tex[slot] = cstr(d[q:q + l])
                        q += l + 4
                    mats.append((name, tex))
                elif t == b'GVTX':
                    _, mat, _, V, F = struct.unpack_from('<IIfII', d, p + 8)
                    q = p + 28
                    verts = [struct.unpack_from('<5f', d, q + 20 * i) for i in range(V)]
                    q += 20 * V
                    faces = [struct.unpack_from('<3H', d, q + 6 * i) for i in range(F)]
                    meshes.append((mat, verts, faces))
                p += s
        elif tag == b'GREF':
            n = struct.unpack_from('<I', d, o + 12)[0]
            p = o + 16
            for _ in range(n):
                l = struct.unpack_from('<I', d, p)[0]
                p += 4
                name = cstr(d[p:p + l])
                p += l
                m = struct.unpack_from('<16f', d, p)
                p += 64 + 12 + 4
                refs.append((name, m[12:15]))
        o += size
    return mats, meshes, refs


# ---------------------------------------------------------------- textures
_tex_cache = {}


def find_tex(texdir, name):
    base = os.path.splitext(name)[0].lower()
    for f in os.listdir(texdir):
        if os.path.splitext(f)[0].lower() == base and f.lower().endswith('.dds'):
            return os.path.join(texdir, f)
    return None


def load_tex(path):
    if path in _tex_cache:
        return _tex_cache[path]
    probe = subprocess.run(['ffmpeg', '-v', 'error', '-i', path, '-f', 'rawvideo', '-pix_fmt', 'rgba', '-'],
                           capture_output=True)
    raw = probe.stdout
    # size from DDS header
    h, w = struct.unpack_from('<II', open(path, 'rb').read(20), 12)
    if len(raw) < w * h * 4:
        raw = None
    _tex_cache[path] = (w, h, raw)
    return _tex_cache[path]


# ---------------------------------------------------------------- math
def rot(p, yaw, tilt):
    x, y, z = p
    cy, sy = math.cos(yaw), math.sin(yaw)
    x, z = cy * x + sy * z, -sy * x + cy * z
    ct, st = math.cos(tilt), math.sin(tilt)
    y, z = ct * y - st * z, st * y + ct * z
    return x, y, z


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def norm(a):
    l = math.sqrt(a[0] ** 2 + a[1] ** 2 + a[2] ** 2) or 1.0
    return (a[0] / l, a[1] / l, a[2] / l)


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


# ---------------------------------------------------------------- raster
class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.rgba = bytearray(w * h * 4)
        self.z = [1e30] * (w * h)

    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            i = (y * self.w + x) * 4
            self.rgba[i:i + 4] = bytes(c)

    def line(self, x0, y0, x1, y1, c, zfun=None):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for k in range(n + 1):
            t = k / n
            x = int(round(x0 + (x1 - x0) * t))
            y = int(round(y0 + (y1 - y0) * t))
            if zfun is not None:
                if not (0 <= x < self.w and 0 <= y < self.h):
                    continue
                if zfun(t) > self.z[y * self.w + x] + zfun.tol:
                    continue
            self.put(x, y, c)


def project(meshes, yaw, tilt):
    """Rotate every vertex; screen x = x, screen y = z (up), depth = -y (camera above)."""
    out = []
    for mat, verts, faces in meshes:
        pv = []
        for v in verts:
            x, y, z = rot(v[:3], yaw, tilt)
            pv.append((x, z, -y, v[3], v[4]))
        out.append((mat, pv, faces))
    return out


def fit(proj, W, H, margin, scale=None, center=None):
    xs = [v[0] for _, pv, _ in proj for v in pv]
    ys = [v[1] for _, pv, _ in proj for v in pv]
    if scale is None:
        scale = min((W - 2 * margin) / (max(xs) - min(xs)), (H - 2 * margin) / (max(ys) - min(ys)))
    if center is None:
        cx = (max(xs) + min(xs)) / 2
        cy = (max(ys) + min(ys)) / 2
        center = (W / 2 - cx * scale, H / 2 + cy * scale)
    ox, oy = center
    return scale, (lambda x, y: (ox + x * scale, oy - y * scale))


def raster_tris(cv, proj, to_px, shade_fn):
    for mi, (mat, pv, faces) in enumerate(proj):
        for f in faces:
            a, b, c = pv[f[0]], pv[f[1]], pv[f[2]]
            (ax, ay), (bx, by), (cx_, cy_) = to_px(a[0], a[1]), to_px(b[0], b[1]), to_px(c[0], c[1])
            area = (bx - ax) * (cy_ - ay) - (by - ay) * (cx_ - ax)
            if abs(area) < 1e-9:
                continue
            x0 = max(int(math.floor(min(ax, bx, cx_))), 0)
            x1 = min(int(math.ceil(max(ax, bx, cx_))), cv.w - 1)
            y0 = max(int(math.floor(min(ay, by, cy_))), 0)
            y1 = min(int(math.ceil(max(ay, by, cy_))), cv.h - 1)
            n3 = norm(cross(sub(b[:3], a[:3]), sub(c[:3], a[:3])))
            for py in range(y0, y1 + 1):
                fy = py + 0.5
                for px in range(x0, x1 + 1):
                    fx = px + 0.5
                    w0 = ((bx - fx) * (cy_ - fy) - (by - fy) * (cx_ - fx)) / area
                    w1 = ((cx_ - fx) * (ay - fy) - (cy_ - fy) * (ax - fx)) / area
                    w2 = 1.0 - w0 - w1
                    if w0 < 0 or w1 < 0 or w2 < 0:
                        continue
                    z = w0 * a[2] + w1 * b[2] + w2 * c[2]
                    i = py * cv.w + px
                    if z >= cv.z[i]:
                        continue
                    cv.z[i] = z
                    u = w0 * a[3] + w1 * b[3] + w2 * c[3]
                    v = w0 * a[4] + w1 * b[4] + w2 * c[4]
                    cv.rgba[i * 4:i * 4 + 4] = bytes(shade_fn(mat, n3, u, v))


def downsample(cv, f):
    w, h = cv.w // f, cv.h // f
    out = bytearray(w * h * 4)
    for y in range(h):
        for x in range(w):
            r = g = b = a = 0
            for dy in range(f):
                for dx in range(f):
                    i = ((y * f + dy) * cv.w + x * f + dx) * 4
                    al = cv.rgba[i + 3]
                    r += cv.rgba[i] * al
                    g += cv.rgba[i + 1] * al
                    b += cv.rgba[i + 2] * al
                    a += al
            o = (y * w + x) * 4
            if a:
                out[o:o + 4] = bytes((r // a, g // a, b // a, a // (f * f)))
    return w, h, out


def write_png(path, w, h, rgba):
    raw = b''.join(b'\0' + bytes(rgba[y * w * 4:(y + 1) * w * 4]) for y in range(h))

    def chunk(t, data):
        return struct.pack('>I', len(data)) + t + data + struct.pack('>I', zlib.crc32(t + data) & 0xffffffff)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)) \
        + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
    open(path, 'wb').write(png)


# ---------------------------------------------------------------- modes
def make_shader(mats, texdir, light=(-0.45, 0.55, -0.7), textured=True):
    L = norm(light)
    texs = {}
    for i, (name, tex) in enumerate(mats):
        p = find_tex(texdir, tex.get(1, '')) if textured and tex.get(1) else None
        texs[i] = load_tex(p) if p else None

    def shade(mat, n, u, v):
        # n is the face normal in view space (screen x, screen y, depth toward far)
        lam = max(0.0, -dot(n, L))
        k = 0.45 + 1.0 * lam
        t = texs.get(mat)
        if t and t[2]:
            w, h, raw = t
            tx = int((u % 1.0) * w) % w
            ty = int((v % 1.0) * h) % h
            i = (ty * w + tx) * 4
            r, g, b = raw[i], raw[i + 1], raw[i + 2]
        else:
            r = g = b = 170
        return (min(255, int(r * k)), min(255, int(g * k)), min(255, int(b * k)), 255)
    return shade


def view_normals(proj):
    pass


def mode_icon(imd, prefix, yaw, tilt, texdir):
    mats, meshes, _ = load_imd(imd)
    proj = project(meshes, math.radians(yaw), math.radians(tilt))
    shade = make_shader(mats, texdir)
    SS = 3
    for size in (128, 64, 32):
        cv = Canvas(size * SS, size * SS)
        _, to_px = fit(proj, cv.w, cv.h, margin=cv.w * 0.03)
        raster_tris(cv, proj, to_px, shade)
        w, h, px = downsample(cv, SS)
        write_png('%s_%d.png' % (prefix, size), w, h, px)
        print('wrote %s_%d.png' % (prefix, size))


def mode_sil(imd, out, size):
    _, meshes, _ = load_imd(imd)
    proj = project(meshes, 0.0, 0.0)
    cv = Canvas(size, size)
    _, to_px = fit(proj, size, size, margin=size * 0.04)
    raster_tris(cv, proj, to_px, lambda m, n, u, v: (255, 255, 255, 255))
    write_png(out, size, size, cv.rgba)
    filled = sum(1 for i in range(3, len(cv.rgba), 4) if cv.rgba[i])
    print('wrote', out, 'filled px', filled)


def read_slot_ini(path):
    secs, cur = {}, None
    for line in open(path, encoding='cp1251', errors='replace').read().splitlines():
        s = line.strip()
        if not s or s.startswith(';'):
            continue
        if s.startswith('[') and s.endswith(']'):
            cur = s[1:-1].lower()
            secs[cur] = {}
        elif '=' in s and cur:
            k, v = s.split('=', 1)
            secs[cur][k.strip().lower()] = v.strip()
    slots = []
    i = 1
    while 'slot%d' % i in secs:
        s = secs['slot%d' % i]
        slots.append(dict(type=s.get('type'), ref=s.get('refpoint'),
                          img=tuple(int(t) for t in s.get('image_coord', '0 0').split()),
                          txt=tuple(int(t) for t in s.get('text_coord', '0 0').split()),
                          al=s.get('text_aligment', 'LEFT').upper()))
        i += 1
    return secs.get('image', {}), slots


def edges_of(meshes):
    """Unique edges by welded position, with the normals of adjacent faces."""
    key = lambda p: (round(p[0], 4), round(p[1], 4), round(p[2], 4))
    E = {}
    for mat, verts, faces in meshes:
        for f in faces:
            P = [verts[k][:3] for k in f]
            n = norm(cross(sub(P[1], P[0]), sub(P[2], P[0])))
            for a, b in ((0, 1), (1, 2), (2, 0)):
                ka, kb = key(P[a]), key(P[b])
                if ka == kb:
                    continue
                e = (ka, kb) if ka < kb else (kb, ka)
                E.setdefault(e, []).append(n)
    return E


def mode_slot(imd, ini, out, scale=None, cx=None, cy=None, crease=35.0):
    W, H = 512, 340
    mats, meshes, refs = load_imd(imd)
    image, slots = read_slot_ini(ini)
    proj = project(meshes, 0.0, 0.0)
    cv = Canvas(W, H)
    center = (cx, cy) if cx is not None else None
    s, to_px = fit(proj, W, H, margin=20, scale=scale, center=center)
    # depth only pass
    raster_tris(cv, proj, to_px, lambda m, n, u, v: (0, 0, 0, 0))
    zbuf = cv.z
    cv.rgba = bytearray(W * H * 4)
    white = (235, 240, 245, 255)
    cosc = math.cos(math.radians(crease))
    nvis = 0
    for (ka, kb), ns in edges_of(meshes).items():
        sharp = len(ns) == 1 or any(dot(ns[0], m) < cosc for m in ns[1:])
        if not sharp:
            continue
        a = rot(ka, 0, 0)
        b = rot(kb, 0, 0)
        (x0, y0), (x1, y1) = to_px(a[0], a[2]), to_px(b[0], b[2])
        za, zb = -a[1], -b[1]

        def zf(t, za=za, zb=zb):
            return za + (zb - za) * t
        zf.tol = 0.02
        cv.z = zbuf
        cv.line(x0, y0, x1, y1, white, zf)
        nvis += 1
    cyan = (90, 190, 200, 255)
    refpos = {}
    for name, pos in refs:
        if ':' in name:
            typ, arg = name.split(':', 1)
            if typ.lower() in ('biggun', 'smallgun', 'rockets', 'turret', 'gkgun', 'turretgk'):
                refpos[arg] = pos
    report = []
    for sl in slots:
        tx, ty = sl['txt']
        if sl['ref'] in refpos:
            p = refpos[sl['ref']]
            rx, ry = to_px(p[0], p[2])
        else:   # system slots have no mesh refpoint: use the hull centre line, as vanilla art does
            rx, ry = to_px(0.0, 0.0)
        rx, ry = int(round(rx)), int(round(ry))
        # leader: horizontal from text anchor, then diagonal to the refpoint marker
        elbow_x = tx + (60 if sl['al'] == 'LEFT' else -60)
        elbow_x = max(min(elbow_x, rx), tx) if sl['al'] == 'LEFT' else min(max(elbow_x, rx), tx)
        cv.line(tx, ty, elbow_x, ty, cyan)
        cv.line(elbow_x, ty, rx, ry, cyan)
        for d in range(-2, 3):
            cv.put(rx + d, ry - 2, cyan)
            cv.put(rx + d, ry + 2, cyan)
            cv.put(rx - 2, ry + d, cyan)
            cv.put(rx + 2, ry + d, cyan)
        report.append((sl['type'], sl['ref'], (rx, ry), sl['txt']))
    write_png(out, W, H, cv.rgba)
    print('wrote', out, 'scale px/unit %.1f' % s, 'edges drawn', nvis)
    for r in report:
        print('  slot', r)


def main():
    a = sys.argv[1:]
    opts = {}
    pos = []
    i = 0
    while i < len(a):
        if a[i].startswith('--'):
            opts[a[i][2:]] = a[i + 1]
            i += 2
        else:
            pos.append(a[i])
            i += 1
    mode = pos[0]
    if mode == 'icon':
        mode_icon(pos[1], pos[2], float(opts.get('yaw', -140)), float(opts.get('tilt', 58)),
                  opts.get('tex-dir', TEXDIR_DEFAULT))
    elif mode == 'sil':
        mode_sil(pos[1], pos[2], int(pos[3]) if len(pos) > 3 else 256)
    elif mode == 'slot':
        mode_slot(pos[1], pos[2], pos[3],
                  float(opts['scale']) if 'scale' in opts else None,
                  float(opts['cx']) if 'cx' in opts else None,
                  float(opts['cy']) if 'cy' in opts else None,
                  float(opts.get('crease', 35)))
    else:
        raise SystemExit(__doc__)


if __name__ == '__main__':
    main()
