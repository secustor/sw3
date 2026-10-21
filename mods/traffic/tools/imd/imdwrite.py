"""IMD (LIBF/IDFM) reader and writer for Star Wolves 3: Civil War.

Data structure (plain dicts and lists, see new_imd()):

  imd = {
    'gnfo': {'ver': 100, 'zeros': [0]*6, 'unit': 1.0},     # GNFO header fields
    'materials': [ {'ver': 100, 'name': 'lit.Gunslinger P',
                    'koeff': [19 floats],                  # shininess .. ior (3ds Max std material)
                    'textures': [ {'id': 1, 'name': 'x.dds', 'amount': 1.0}, ... ] } ],
    'submeshes': [ {'ver': 100, 'material': 0, 'area': float,
                    'verts':    [(x, y, z, u, v), ...],
                    'faces':    [(a, b, c), ...],         # u16 indices
                    'vnormals': [(x, y, z), ...],
                    'fnormals': [(x, y, z), ...] } ],
    'gnin': None | {'ver': 100, 'items': [(a, b, c), ...]},   # s32 triples, ignored by the engine
    'gbnd': None | {'ver': 100, 'main': (x, y, z, r), 'spheres': [(x, y, z, r), ...]},
    'gelp': None | {'ver': 100, 'center': (x, y, z), 'radii': (x, y, z)},
    'gref': None | {'ver': 100, 'refs': [ {'name': 'Biggun:right',
                    'm': [16 floats],    # 3 rotation rows (x,y,z,w) + position row (x,y,z,w)
                    'scale': (sx, sy, sz), 'bgr': (b, g, r), 'pad': 0} ]},
    'extra': [(tag, bytes), ...],        # unknown GNFO sub-chunks, written after GELP
  }

Strings are written as u32 len + bytes + NUL, padded with NUL to a multiple of 4
(the vanilla convention). Chunk sizes include the 8-byte header.

Usage:
  python3 -I imdwrite.py roundtrip <dir|file> [--report out.json]
  python3 -I imdwrite.py info <file>
  python3 -I imdwrite.py fix <in.IMD> <out.IMD>    # recompute normals/area/bounds and rewrite
"""
import struct, sys, os, math, json, collections

VER = 100

# ---------------------------------------------------------------- reading

def _canon_len(s):
    n = len(s.encode('latin1')) + 1
    return n + (-n % 4)

def _str(d, p, keep=None):
    """keep: dict that receives 'name_len' when the stored length is not the canonical pad4(len+1)."""
    n, = struct.unpack_from('<I', d, p)
    raw = d[p + 4:p + 4 + n]
    s = raw.split(b'\0')[0].decode('latin1')
    if keep is not None and n != _canon_len(s):
        keep['name_len'] = n
    return s, p + 4 + n

def _gmat(c):
    ver, = struct.unpack_from('<I', c, 8)
    name, p = _str(c, 12)
    koeff = list(struct.unpack_from('<19f', c, p)); p += 76
    ntex, = struct.unpack_from('<I', c, p); p += 4
    tex = []
    for _ in range(ntex):
        tid, = struct.unpack_from('<i', c, p)
        tname, p = _str(c, p + 4)
        amt, = struct.unpack_from('<f', c, p); p += 4
        tex.append({'id': tid, 'name': tname, 'amount': amt})
    if p != len(c):
        raise ValueError('GMAT size %d != parsed %d' % (len(c), p))
    return {'ver': ver, 'name': name, 'koeff': koeff, 'textures': tex}

def _gvtx(c):
    ver, mat, area, V, F = struct.unpack_from('<IIfII', c, 8)
    p = 28
    verts = list(struct.iter_unpack('<5f', c[p:p + 20 * V])); p += 20 * V
    faces = list(struct.iter_unpack('<3H', c[p:p + 6 * F])); p += 6 * F
    vn = list(struct.iter_unpack('<3f', c[p:p + 12 * V])); p += 12 * V
    fn = list(struct.iter_unpack('<3f', c[p:p + 12 * F])); p += 12 * F
    if p != len(c):
        raise ValueError('GVTX size %d != parsed %d' % (len(c), p))
    return {'ver': ver, 'material': mat, 'area': area, 'verts': verts, 'faces': faces,
            'vnormals': vn, 'fnormals': fn}

def _gnin(c):
    ver, n = struct.unpack_from('<II', c, 8)
    items = list(struct.iter_unpack('<3i', c[16:16 + 12 * n]))
    if 16 + 12 * n != len(c):
        raise ValueError('GNIN size')
    return {'ver': ver, 'items': items}

def _gbnd(c):
    ver, x, y, z, r, n = struct.unpack_from('<I4fI', c, 8)
    sph = list(struct.iter_unpack('<4f', c[32:32 + 16 * n]))
    if 32 + 16 * n != len(c):
        raise ValueError('GBND size')
    return {'ver': ver, 'main': (x, y, z, r), 'spheres': sph}

def _gelp(c):
    v = struct.unpack_from('<I6f', c, 8)
    if len(c) != 36:
        raise ValueError('GELP size')
    return {'ver': v[0], 'center': v[1:4], 'radii': v[4:7]}

def _gref(c):
    ver, n = struct.unpack_from('<II', c, 8)
    p = 16; refs = []
    for _ in range(n):
        keep = {}
        name, p = _str(c, p, keep)
        m = list(struct.unpack_from('<16f', c, p)); p += 64
        s = struct.unpack_from('<3f', c, p); p += 12
        b, g, r, pad = c[p:p + 4]; p += 4
        refs.append(dict({'name': name, 'm': m, 'scale': s, 'bgr': (b, g, r), 'pad': pad}, **keep))
    if p != len(c):
        raise ValueError('GREF size')
    return {'ver': ver, 'refs': refs}

def _chunks(d, p, end):
    while p < end:
        tag = d[p:p + 4].decode('latin1'); s, = struct.unpack_from('<I', d, p + 4)
        if s < 8 or p + s > end:
            raise ValueError('bad chunk %r size %d at %d' % (tag, s, p))
        yield tag, d[p:p + s]
        p += s

def read(d):
    if d[:4] != b'LIBF' or d[8:12] != b'IDFM':
        raise ValueError('not an IMD')
    size, = struct.unpack_from('<I', d, 4)
    imd = new_imd(); imd['gnfo'] = None; imd['order'] = []
    for tag, c in _chunks(d, 12, size):
        imd['order'].append(tag)
        if tag == 'GNFO':
            h = struct.unpack_from('<I6IfII', c, 8)
            imd['gnfo'] = {'ver': h[0], 'zeros': list(h[1:7]), 'unit': h[7]}
            imd['_counts'] = (h[8], h[9])          # num_gvtx, num_gmat as stored
            for t, sc in _chunks(c, 48, len(c)):
                imd['order'].append('GNFO/' + t)
                if t == 'GMAT': imd['materials'].append(_gmat(sc))
                elif t == 'GVTX': imd['submeshes'].append(_gvtx(sc))
                elif t == 'GNIN': imd['gnin'] = _gnin(sc)
                elif t == 'GBND': imd['gbnd'] = _gbnd(sc)
                elif t == 'GELP': imd['gelp'] = _gelp(sc)
                else: imd['extra'].append((t, bytes(sc[8:])))
        elif tag == 'GREF':
            imd['gref'] = _gref(c)
        else:
            imd.setdefault('top_extra', []).append((tag, bytes(c[8:])))
    return imd

def read_file(path):
    with open(path, 'rb') as f:
        return read(f.read())

# ---------------------------------------------------------------- writing

def _pstr(s, n=None):
    """n: stored length to reproduce a non-canonical vanilla string (one GREF name in Lindworm_alien)."""
    b = s.encode('latin1') + b'\0'
    b += b'\0' * ((-len(b) % 4) if n is None else (n - len(b)))
    return struct.pack('<I', len(b)) + b

def _chunk(tag, body):
    return tag.encode('latin1') + struct.pack('<I', 8 + len(body)) + body

def _w_gmat(m):
    b = bytearray(struct.pack('<I', m.get('ver', VER)))
    b += _pstr(m['name'])
    k = list(m['koeff']); assert len(k) == 19
    b += struct.pack('<19f', *k)
    b += struct.pack('<I', len(m['textures']))
    for t in m['textures']:
        b += struct.pack('<i', t['id']) + _pstr(t['name']) + struct.pack('<f', t['amount'])
    return _chunk('GMAT', bytes(b))

def _w_gvtx(s):
    V, F = len(s['verts']), len(s['faces'])
    if V > 65535: raise ValueError('submesh has %d vertices; u16 indices allow 65535' % V)
    assert len(s['vnormals']) == V and len(s['fnormals']) == F
    b = bytearray(struct.pack('<IIfII', s.get('ver', VER), s['material'], s['area'], V, F))
    pk5 = struct.Struct('<5f').pack; pk3 = struct.Struct('<3f').pack; pkh = struct.Struct('<3H').pack
    b += b''.join(pk5(*v) for v in s['verts'])
    b += b''.join(pkh(*f) for f in s['faces'])
    b += b''.join(pk3(*n) for n in s['vnormals'])
    b += b''.join(pk3(*n) for n in s['fnormals'])
    return _chunk('GVTX', bytes(b))

def _w_gnin(g):
    return _chunk('GNIN', struct.pack('<II', g.get('ver', VER), len(g['items'])) +
                  b''.join(struct.pack('<3i', *t) for t in g['items']))

def _w_gbnd(g):
    return _chunk('GBND', struct.pack('<I4fI', g.get('ver', VER), *g['main'], len(g['spheres'])) +
                  b''.join(struct.pack('<4f', *s) for s in g['spheres']))

def _w_gelp(g):
    return _chunk('GELP', struct.pack('<I6f', g.get('ver', VER), *g['center'], *g['radii']))

def _w_gref(g):
    b = bytearray(struct.pack('<II', g.get('ver', VER), len(g['refs'])))
    for r in g['refs']:
        b += _pstr(r['name'], r.get('name_len')) + struct.pack('<16f', *r['m']) + struct.pack('<3f', *r['scale'])
        b += bytes(list(r.get('bgr', (0, 0, 0))) + [r.get('pad', 0)])
    return _chunk('GREF', bytes(b))

def write(imd):
    h = imd.get('gnfo') or {'ver': VER, 'zeros': [0] * 6, 'unit': 1.0}
    body = bytearray(struct.pack('<I6IfII', h['ver'], *h['zeros'], h['unit'],
                                 len(imd['submeshes']), len(imd['materials'])))
    for m in imd['materials']: body += _w_gmat(m)
    for s in imd['submeshes']: body += _w_gvtx(s)
    if imd.get('gnin') is not None: body += _w_gnin(imd['gnin'])
    if imd.get('gbnd') is not None: body += _w_gbnd(imd['gbnd'])
    if imd.get('gelp') is not None: body += _w_gelp(imd['gelp'])
    for t, raw in imd.get('extra', []): body += _chunk(t, raw)
    out = bytearray(b'IDFM') + _chunk('GNFO', bytes(body))
    if imd.get('gref') is not None: out += _w_gref(imd['gref'])
    return b'LIBF' + struct.pack('<I', 8 + len(out)) + bytes(out)

def write_file(imd, path):
    d = write(imd)
    with open(path, 'wb') as f:
        f.write(d)
    return len(d)

# ---------------------------------------------------------------- building helpers

def new_imd():
    return {'gnfo': {'ver': VER, 'zeros': [0] * 6, 'unit': 1.0}, 'materials': [], 'submeshes': [],
            'gnin': None, 'gbnd': None, 'gelp': None, 'gref': None, 'extra': []}

DEFAULT_KOEFF = [0.0, 0.0, 0.588, 0.588, 0.588, 0.0, 0.588, 0.588, 0.588, 1.0,
                 0.9, 0.9, 0.9, 0.0, 0.0, 0.0, 0.0, 1.0, 1.5]   # placeholder; copy a vanilla GMAT instead

def material(name, texture, slots=(1, 9), koeff=None):
    """Ship-style material: one texture repeated in each slot (vanilla: slot 1 + 9, or 1 + 5 for lit.grey)."""
    return {'ver': VER, 'name': name, 'koeff': list(koeff or DEFAULT_KOEFF),
            'textures': [{'id': s, 'name': texture, 'amount': 1.0} for s in slots]}

def _sub(a, b): return (a[0] - b[0], a[1] - b[1], a[2] - b[2])
def _cross(a, b): return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])
def _len(a): return math.sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2])
def _norm(a):
    l = _len(a)
    return (a[0] / l, a[1] / l, a[2] / l) if l > 1e-20 else (0.0, 0.0, 0.0)

def face_normals(verts, faces):
    """Normalised (b-a)x(c-a). Degenerate faces get (1,0,0), as in all 491 vanilla degenerate faces."""
    out = []
    for a, b, c in faces:
        n = _norm(_cross(_sub(verts[b], verts[a]), _sub(verts[c], verts[a])))
        out.append(n if n != (0.0, 0.0, 0.0) else (1.0, 0.0, 0.0))
    return out

def surface_area(verts, faces):
    return sum(0.5 * _len(_cross(_sub(verts[b], verts[a]), _sub(verts[c], verts[a]))) for a, b, c in faces)

def submesh(material_index, verts, faces, vnormals=None):
    """verts: (x,y,z,u,v) with v already in IMD convention (negative). Computes area, face normals,
    and (if not given) area-weighted smooth vertex normals."""
    fn = face_normals(verts, faces)
    if vnormals is None:
        acc = [[0.0, 0.0, 0.0] for _ in verts]
        for (a, b, c) in faces:
            n = _cross(_sub(verts[b], verts[a]), _sub(verts[c], verts[a]))
            for i in (a, b, c):
                acc[i][0] += n[0]; acc[i][1] += n[1]; acc[i][2] += n[2]
        vnormals = [_norm(n) for n in acc]
    return {'ver': VER, 'material': material_index, 'area': surface_area(verts, faces),
            'verts': [tuple(v) for v in verts], 'faces': [tuple(f) for f in faces],
            'vnormals': [tuple(n) for n in vnormals], 'fnormals': fn}

def all_points(imd):
    return [v[:3] for s in imd['submeshes'] for v in s['verts']]

def main_sphere(points):
    """Vanilla convention: centre at the origin, radius = largest vertex distance from the origin."""
    r = max((_len(p) for p in points), default=0.0)
    return (0.0, 0.0, 0.0, r)

def auto_spheres(points, k=16, iters=12):
    """Cover the hull with k spheres: k-means on vertex positions, radius = farthest member.
    Deterministic seeding (farthest-point). This is a heuristic, not the vanilla authoring method."""
    pts = list(points)
    if not pts: return []
    k = min(k, len(pts))
    cents = [pts[0]]
    d2 = [sum((a - b) ** 2 for a, b in zip(p, cents[0])) for p in pts]
    while len(cents) < k:
        i = max(range(len(pts)), key=d2.__getitem__)
        cents.append(pts[i])
        d2 = [min(d2[j], sum((a - b) ** 2 for a, b in zip(pts[j], pts[i]))) for j in range(len(pts))]
    for _ in range(iters):
        groups = [[] for _ in cents]
        for p in pts:
            j = min(range(len(cents)), key=lambda c: (p[0] - cents[c][0]) ** 2 + (p[1] - cents[c][1]) ** 2 + (p[2] - cents[c][2]) ** 2)
            groups[j].append(p)
        cents = [tuple(sum(q[i] for q in g) / len(g) for i in range(3)) if g else cents[j] for j, g in enumerate(groups)]
    groups = [[] for _ in cents]
    for p in pts:
        j = min(range(len(cents)), key=lambda c: (p[0] - cents[c][0]) ** 2 + (p[1] - cents[c][1]) ** 2 + (p[2] - cents[c][2]) ** 2)
        groups[j].append(p)
    return [(c[0], c[1], c[2], max(_len(_sub(p, c)) for p in g)) for c, g in zip(cents, groups) if g]

def bbox(points):
    xs, ys, zs = zip(*points)
    return (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))

def ellipsoid(points):
    """Axis-aligned ellipsoid at the bbox centre, radii proportional to the half extents and scaled so the
    farthest vertex lies on the surface. Vanilla GELP is close to this (median farthest-vertex normalised
    distance 0.984 over 309 files) but its centre is not the bbox centre, so it is not reproducible exactly."""
    lo, hi = bbox(points)
    c = tuple((a + b) / 2 for a, b in zip(lo, hi))
    h = tuple(max((b - a) / 2, 1e-4) for a, b in zip(lo, hi))
    s = max(math.sqrt(sum(((p[i] - c[i]) / h[i]) ** 2 for i in range(3))) for p in points)
    return {'ver': VER, 'center': c, 'radii': tuple(x * s for x in h)}

def refpoint(name, pos, rot=None, scale=(1.0, 1.0, 1.0), bgr=(87, 198, 224)):
    """rot: 3x3 rows; default identity. Matrix layout matches vanilla: rows with w=0, position row w=1."""
    r = rot or ((1, 0, 0), (0, 1, 0), (0, 0, 1))
    m = [r[0][0], r[0][1], r[0][2], 0.0, r[1][0], r[1][1], r[1][2], 0.0,
         r[2][0], r[2][1], r[2][2], 0.0, pos[0], pos[1], pos[2], 1.0]
    # 4th colour byte is 0xFF in all 30010 vanilla refpoints (BGRA, alpha 255); bgr default copied from AG.IMD
    return {'name': name, 'm': [float(x) for x in m], 'scale': tuple(scale), 'bgr': tuple(bgr), 'pad': 255}

def recompute(imd, spheres=None, gelp=True):
    """Recompute area, face normals, GBND main sphere (and spheres if given) and GELP."""
    for s in imd['submeshes']:
        s['area'] = surface_area(s['verts'], s['faces'])
        s['fnormals'] = face_normals(s['verts'], s['faces'])
    pts = all_points(imd)
    g = imd.get('gbnd') or {'ver': VER, 'main': (0, 0, 0, 0), 'spheres': []}
    g['main'] = main_sphere(pts)
    if spheres is not None: g['spheres'] = spheres
    imd['gbnd'] = g
    if gelp: imd['gelp'] = ellipsoid(pts)
    return imd

# ---------------------------------------------------------------- round trip + diff classification

def _classify(orig, new):
    """Return a list of difference classes between two IMD byte strings (assumes write(read(orig)) == new)."""
    if orig == new: return []
    cls = []
    if len(orig) != len(new): cls.append('size %d->%d' % (len(orig), len(new)))
    # walk the original chunk tree, find the first differing chunk
    def flat(d):
        out = []
        size, = struct.unpack_from('<I', d, 4)
        for tag, c in _chunks(d, 12, size):
            if tag == 'GNFO':
                out.append(('GNFO-hdr', c[:48]))
                out += [('GNFO/' + t, sc) for t, sc in _chunks(c, 48, len(c))]
            else:
                out.append((tag, c))
        return out
    a, b = flat(orig), flat(new)
    if [t for t, _ in a] != [t for t, _ in b]: cls.append('chunk order')
    for (ta, ca), (tb, cb) in zip(a, b):
        if ca != cb: cls.append('diff in ' + ta)
    return cls

def _string_anomalies(d):
    """Scan all length-prefixed strings for non-canonical length/padding."""
    out = collections.Counter()
    def chk(c, p, where):
        n, = struct.unpack_from('<I', c, p)
        raw = c[p + 4:p + 4 + n]
        s = raw.split(b'\0')[0]
        canon = s + b'\0' + b'\0' * (-(len(s) + 1) % 4)
        if raw != canon:
            if len(raw) != len(canon): out[where + ': length not pad4(len+1)'] += 1
            else: out[where + ': non-zero bytes after NUL'] += 1
        return p + 4 + n
    size, = struct.unpack_from('<I', d, 4)
    for tag, c in _chunks(d, 12, size):
        if tag == 'GNFO':
            for t, sc in _chunks(c, 48, len(c)):
                if t == 'GMAT':
                    p = chk(sc, 12, 'GMAT name') + 76
                    nt, = struct.unpack_from('<I', sc, p); p += 4
                    for _ in range(nt): p = chk(sc, p + 4, 'GMAT texture') + 4
        elif tag == 'GREF':
            n, = struct.unpack_from('<I', c, 12); p = 16
            for _ in range(n): p = chk(c, p, 'GREF name') + 80
    return out

def roundtrip(paths, report=None):
    exact = 0; classes = collections.Counter(); strs = collections.Counter(); fails = []; per = {}
    nan = 0; counts_bad = 0; order = collections.Counter()
    for f in paths:
        d = open(f, 'rb').read()
        try:
            imd = read(d); new = write(imd)
        except Exception as e:
            fails.append((os.path.basename(f), repr(e))); continue
        order[tuple(t for t in imd['order'] if t not in ('GNFO/GMAT', 'GNFO/GVTX'))] += 1
        if imd['_counts'] != (len(imd['submeshes']), len(imd['materials'])): counts_bad += 1
        if new == d:
            exact += 1; continue
        c = _classify(d, new); sa = _string_anomalies(d)
        per[os.path.basename(f)] = {'classes': c, 'strings': dict(sa)}
        for x in c: classes[x if not x.startswith('size') else 'size changed'] += 1
        for k, v in sa.items(): strs[k] += v
    res = {'files': len(paths), 'exact': exact, 'parse_fail': fails, 'diff_classes': dict(classes),
           'string_anomalies_in_nonexact': dict(strs), 'header_count_mismatch': counts_bad,
           'gnfo_layouts': {' '.join(k): v for k, v in order.items()}, 'nonexact': per}
    if report:
        with open(report, 'w') as fh: json.dump(res, fh, indent=1)
    return res

def info(path):
    imd = read_file(path)
    print(os.path.basename(path), 'order', [t for t in imd['order']])
    for i, m in enumerate(imd['materials']):
        print('  GMAT %d %r tex=%s' % (i, m['name'], [(t['id'], t['name']) for t in m['textures']]))
    for i, s in enumerate(imd['submeshes']):
        print('  GVTX %d mat=%d V=%d F=%d area=%.4f' % (i, s['material'], len(s['verts']), len(s['faces']), s['area']))
    if imd['gbnd']: print('  GBND main', [round(x, 4) for x in imd['gbnd']['main']], 'spheres', len(imd['gbnd']['spheres']))
    if imd['gelp']: print('  GELP', [round(x, 4) for x in imd['gelp']['center']], [round(x, 4) for x in imd['gelp']['radii']])
    if imd['gnin']: print('  GNIN', len(imd['gnin']['items']))
    if imd['gref']:
        for r in imd['gref']['refs']: print('  GREF %-40s pos=%s' % (r['name'], [round(x, 3) for x in r['m'][12:15]]))
    pts = all_points(imd)
    if pts:
        lo, hi = bbox(pts); print('  bbox', [round(x, 3) for x in lo], [round(x, 3) for x in hi])

if __name__ == '__main__':
    a = sys.argv[1:]
    if not a: print(__doc__); sys.exit(1)
    if a[0] == 'roundtrip':
        t = a[1]
        paths = [os.path.join(t, f) for f in sorted(os.listdir(t)) if f.lower().endswith('.imd')] if os.path.isdir(t) else [t]
        rep = a[a.index('--report') + 1] if '--report' in a else None
        r = roundtrip(paths, rep)
        r2 = dict(r); r2.pop('nonexact')
        print(json.dumps(r2, indent=1))
        for k, v in list(r['nonexact'].items())[:40]: print(k, v)
    elif a[0] == 'info':
        info(a[1])
    elif a[0] == 'fix':
        imd = read_file(a[1]); recompute(imd, gelp=imd['gelp'] is not None); print(write_file(imd, a[2]), 'bytes')
    else:
        print(__doc__); sys.exit(1)
