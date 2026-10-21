"""OBJ / glTF <-> IMD converter for Star Wolves 3 (pure Python 3, no third-party modules).

Coordinate conventions (measured on vanilla data, see converter.md):
  IMD:  +Y up, +Z forward (guns point +Z, engines sit at -Z), +X = ship's right ("left" refpoints at x<0).
        Left-handed. Face winding: normalised (b-a)x(c-a) points outward.
        UV: u right, v stored negative (v_imd = -v_up), i.e. the 3ds Max value negated.
  glTF: right-handed, +Y up, front faces +Z, so +X is the model's left.  Texcoord t runs downwards.
  OBJ:  right-handed by convention; axes depend on the exporter. Texcoord v runs upwards.
Import maps a right-handed source with forward F and up U to IMD as  x = p.(F x U), y = p.U, z = p.F
and reverses the face winding (the basis change has determinant -1).

Usage:
  python3 -I imdconv.py import <model.obj|.gltf|.glb> <out.IMD> [options]
      --forward +z|-z|+x|-x|+y|-y   source forward axis (default +z)
      --up +y|...                   source up axis (default +y)
      --scale S | --fit-length L    uniform scale, or scale so the Z extent equals L IMD units
      --template X.IMD              copy GMAT coefficients (and texture slot ids) from this vanilla file
      --texture NAME.dds            texture for every material (default: from the model, ext -> .dds)
      --smooth-angle DEG            normals for corners without normals (default 40; 0 = flat)
      --spheres K                   GBND sphere count (default: by size, 8..48)
      --refs refs.json              extra refpoints: [{"name":..,"pos":[x,y,z],"rot":[[..],[..],[..]],"scale":[..]}]
      --refs-from X.IMD [--refs-scale S]   copy every GREF of a vanilla file (positions scaled by S)
      --no-gelp                     omit GELP
  python3 -I imdconv.py export <in.IMD> <out.obj|out.gltf>   (refpoints become glTF nodes / OBJ comments)

Refpoints from the model: a glTF node without a mesh, or an OBJ object/group, whose name starts with a
refpoint type from the exe table (Flare, Module, Fire, Gunpoint, Smallgun, Biggun, Rockets, TractorBeam,
Turret, TurretGuns, System, HangarIn, HangarOut, PortalIn, DockPos, PreDockPos, Hinge1_opened,
Hinge2_opened, GKGun, TurretGK; matched case-insensitively) followed by ':'. A leading 'GREF ' and the
SW3SE 'b:g:r:' colour prefix are accepted, a Blender '.001' suffix is dropped. OBJ refpoint objects
give a position only (centroid of their vertices); glTF nodes give position, rotation and scale.
"""
import sys, os, json, struct, math, base64, re, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import imdwrite as W

REF_TYPES = ('flare', 'module', 'fire', 'gunpoint', 'smallgun', 'biggun', 'rockets', 'tractorbeam', 'turretguns',
             'turretgk', 'turret', 'system', 'hangarin', 'hangarout', 'portalin', 'predockpos', 'dockpos',
             'hinge1_opened', 'hinge2_opened', 'gkgun')
AX = {'+x': (1, 0, 0), '-x': (-1, 0, 0), '+y': (0, 1, 0), '-y': (0, -1, 0), '+z': (0, 0, 1), '-z': (0, 0, -1)}

def ref_name(name):
    """Return the IMD refpoint name if `name` denotes a refpoint, else None."""
    n = name.strip()
    if n.upper().startswith('GREF '): n = n[5:]
    m = re.match(r'^\d{1,3}:\d{1,3}:\d{1,3}:(.*)$', n)          # SW3SE importer colour prefix
    if m: n = m.group(1)
    n = re.sub(r'\.\d{3}$', '', n)                               # Blender duplicate suffix
    head = n.split(':', 1)[0].strip().lower()
    return n if ':' in n and head in REF_TYPES else None

class Basis:
    def __init__(self, fwd='+z', up='+y'):
        F, U = AX[fwd], AX[up]
        if sum(a * b for a, b in zip(F, U)) != 0: raise ValueError('forward and up must differ')
        R = W._cross(F, U)
        self.rows = (R, U, F)
    def p(self, v):
        return tuple(sum(a * b for a, b in zip(r, v)) for r in self.rows)

# ---------------------------------------------------------------- generic mesh -> IMD

class Mesh:
    """Triangle soup in IMD coordinates: per material a list of corners (pos, uv_imd, normal|None)."""
    def __init__(self):
        self.mats = collections.OrderedDict()      # name -> {'texture': str|None, 'tris': [((p,uv,n),)*3]}
        self.refs = []
    def add_tri(self, mat, tex, corners):
        e = self.mats.setdefault(mat, {'texture': tex, 'tris': []})
        if e['texture'] is None: e['texture'] = tex
        e['tris'].append(corners)

def _smooth_normals(tris, angle):
    """Corner normals for corners that have none: area-weighted average of the face normals at the same
    position whose angle to this face is below `angle` degrees (0 = flat)."""
    fn = []
    for t in tris:
        c = W._cross(W._sub(t[1][0], t[0][0]), W._sub(t[2][0], t[0][0]))
        fn.append((c, W._norm(c)))
    if angle <= 0:
        return [[t[k][2] or fn[i][1] for k in range(3)] for i, t in enumerate(tris)]
    cosl = math.cos(math.radians(angle))
    at = collections.defaultdict(list)
    for i, t in enumerate(tris):
        for k in range(3): at[tuple(round(x, 6) for x in t[k][0])].append(i)
    out = []
    for i, t in enumerate(tris):
        row = []
        for k in range(3):
            if t[k][2] is not None: row.append(t[k][2]); continue
            s = [0.0, 0.0, 0.0]
            for j in at[tuple(round(x, 6) for x in t[k][0])]:
                if sum(a * b for a, b in zip(fn[i][1], fn[j][1])) >= cosl:
                    for q in range(3): s[q] += fn[j][0][q]
            n = W._norm(s)
            row.append(n if n != (0.0, 0.0, 0.0) else fn[i][1])
        out.append(row)
    return out

def build_imd(mesh, template=None, texture=None, smooth=40.0, spheres=None, gelp=True, extra_refs=()):
    imd = W.new_imd()
    tmpl_mat = None
    if template:
        t = W.read_file(template)
        tmpl_mat = next((m for m in t['materials'] if any(x['id'] == 9 for x in m['textures'])), t['materials'][0])
    for mi, (mname, e) in enumerate(mesh.mats.items()):
        tex = texture or e['texture'] or 'missing.dds'
        tex = os.path.splitext(os.path.basename(tex))[0] + '.dds'
        if tmpl_mat:
            m = {'ver': 100, 'name': mname, 'koeff': list(tmpl_mat['koeff']),
                 'textures': [{'id': x['id'], 'name': tex, 'amount': x['amount']} for x in tmpl_mat['textures']]}
        else:
            m = W.material(mname, tex)
        imd['materials'].append(m)
        normals = _smooth_normals(e['tris'], smooth)
        # dedupe identical corners; split into submeshes of <= 65535 vertices
        verts, faces, vn, index = [], [], [], {}
        def flush():
            if faces: imd['submeshes'].append(W.submesh(mi, verts[:], faces[:], vn[:]))
        for t, ns in zip(e['tris'], normals):
            if len(verts) > 65532:
                flush(); verts.clear(); faces.clear(); vn.clear(); index.clear()
            f = []
            for (p, uv, _), n in zip(t, ns):
                key = (p, uv, n)
                if key not in index:
                    index[key] = len(verts); verts.append((p[0], p[1], p[2], uv[0], uv[1])); vn.append(n)
                f.append(index[key])
            faces.append(tuple(f))
        flush()
    pts = W.all_points(imd)
    if spheres is None:
        r = W.main_sphere(pts)[3]
        spheres = 8 if r < 1.5 else 20 if r < 5 else 32 if r < 12 else 48
    W.recompute(imd, spheres=W.auto_spheres(pts, spheres), gelp=gelp)
    refs = list(mesh.refs) + list(extra_refs)
    if refs: imd['gref'] = {'ver': 100, 'refs': refs}
    return imd

# ---------------------------------------------------------------- OBJ

def read_obj(path, basis):
    mesh = Mesh(); P, T, N = [], [], []
    mtl_tex = {}; cur_mat = 'default'; cur_obj = ''; refpts = collections.OrderedDict()
    base = os.path.dirname(path)
    def load_mtl(fn):
        cur = None
        try: lines = open(os.path.join(base, fn), encoding='latin1').read().splitlines()
        except OSError: return
        for ln in lines:
            s = ln.split()
            if not s: continue
            if s[0] == 'newmtl': cur = ' '.join(s[1:])
            elif s[0] == 'map_Kd' and cur: mtl_tex[cur] = s[-1]
    for ln in open(path, encoding='latin1'):
        s = ln.split()
        if not s or s[0].startswith('#'): continue
        k = s[0]
        if k == 'v': P.append(basis.p(tuple(float(x) for x in s[1:4])))
        elif k == 'vt': T.append((float(s[1]), float(s[2]) if len(s) > 2 else 0.0))
        elif k == 'vn': N.append(W._norm(basis.p(tuple(float(x) for x in s[1:4]))))
        elif k == 'mtllib': load_mtl(' '.join(s[1:]))
        elif k == 'usemtl': cur_mat = ' '.join(s[1:])
        elif k in ('o', 'g'): cur_obj = ' '.join(s[1:])
        elif k == 'f':
            idx = []
            for c in s[1:]:
                parts = c.split('/')
                def ix(v, arr):
                    if v == '': return None
                    i = int(v); return i - 1 if i > 0 else len(arr) + i
                idx.append((ix(parts[0], P), ix(parts[1], T) if len(parts) > 1 else None,
                            ix(parts[2], N) if len(parts) > 2 else None))
            rn = ref_name(cur_obj) if cur_obj else None
            if rn:
                refpts.setdefault(rn, set()).update(i[0] for i in idx); continue
            corners = [(P[a], (T[b][0], -T[b][1]) if b is not None else (0.0, 0.0), N[c] if c is not None else None)
                       for a, b, c in idx]
            for j in range(1, len(corners) - 1):                  # fan; reversed winding for the mirror
                mesh.add_tri(cur_mat, mtl_tex.get(cur_mat), (corners[0], corners[j + 1], corners[j]))
    for rn, ids in refpts.items():
        c = [sum(P[i][q] for i in ids) / len(ids) for q in range(3)]
        mesh.refs.append(W.refpoint(rn, c))
    return mesh

def write_obj(imd, path):
    """IMD -> OBJ with the inverse of the default basis (+Z forward, +Y up => x = -x_imd)."""
    mtl = os.path.splitext(path)[0] + '.mtl'
    with open(mtl, 'w') as f:
        for i, m in enumerate(imd['materials']):
            f.write('newmtl m%d_%s\nmap_Kd %s\n' % (i, m['name'].replace(' ', '_'), m['textures'][0]['name'] if m['textures'] else ''))
    with open(path, 'w') as f:
        f.write('mtllib %s\n' % os.path.basename(mtl))
        o = 1
        for si, s in enumerate(imd['submeshes']):
            m = imd['materials'][s['material']]
            f.write('o sub%d\nusemtl m%d_%s\n' % (si, s['material'], m['name'].replace(' ', '_')))
            for x, y, z, u, v in s['verts']: f.write('v %r %r %r\nvt %r %r\n' % (-x, y, z, u, -v))
            for x, y, z in s['vnormals']: f.write('vn %r %r %r\n' % (-x, y, z))
            for a, b, c in s['faces']:
                f.write('f %d/%d/%d %d/%d/%d %d/%d/%d\n' % tuple(q for i in (a, c, b) for q in (i + o, i + o, i + o)))
            o += len(s['verts'])
        for r in (imd['gref'] or {'refs': []})['refs']:
            f.write('# GREF %s pos %r %r %r\n' % (r['name'], -r['m'][12], r['m'][13], r['m'][14]))

# ---------------------------------------------------------------- glTF

def _mat4_mul(a, b):   # column-major 4x4 as flat lists
    return [sum(a[k * 4 + r] * b[c * 4 + k] for k in range(4)) for c in range(4) for r in range(4)]

def _node_matrix(n):
    if 'matrix' in n: return list(n['matrix'])
    t = n.get('translation', [0, 0, 0]); q = n.get('rotation', [0, 0, 0, 1]); s = n.get('scale', [1, 1, 1])
    x, y, z, w = q
    R = [1 - 2 * (y * y + z * z), 2 * (x * y + z * w), 2 * (x * z - y * w),
         2 * (x * y - z * w), 1 - 2 * (x * x + z * z), 2 * (y * z + x * w),
         2 * (x * z + y * w), 2 * (y * z - x * w), 1 - 2 * (x * x + y * y)]
    return [R[0] * s[0], R[1] * s[0], R[2] * s[0], 0, R[3] * s[1], R[4] * s[1], R[5] * s[1], 0,
            R[6] * s[2], R[7] * s[2], R[8] * s[2], 0, t[0], t[1], t[2], 1]

def _load_gltf(path):
    data = open(path, 'rb').read(); binchunk = None
    if data[:4] == b'glTF':
        _, _, total = struct.unpack_from('<4sII', data, 0); p = 12; js = None
        while p < total:
            ln, typ = struct.unpack_from('<II', data, p); body = data[p + 8:p + 8 + ln]
            if typ == 0x4E4F534A: js = json.loads(body.decode('utf-8'))
            elif typ == 0x004E4942: binchunk = body
            p += 8 + ln
    else:
        js = json.loads(data.decode('utf-8'))
    bufs = []
    for b in js.get('buffers', []):
        uri = b.get('uri')
        if uri is None: bufs.append(binchunk)
        elif uri.startswith('data:'): bufs.append(base64.b64decode(uri.split(',', 1)[1]))
        else: bufs.append(open(os.path.join(os.path.dirname(path), uri.replace('%20', ' ')), 'rb').read())
    return js, bufs

_CT = {5120: ('b', 1), 5121: ('B', 1), 5122: ('h', 2), 5123: ('H', 2), 5125: ('I', 4), 5126: ('f', 4)}
_NC = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}

def _accessor(js, bufs, i):
    a = js['accessors'][i]
    if 'sparse' in a: raise ValueError('sparse accessors not supported')
    fmt, sz = _CT[a['componentType']]; nc = _NC[a['type']]
    bv = js['bufferViews'][a['bufferView']]; buf = bufs[bv['buffer']]
    base = bv.get('byteOffset', 0) + a.get('byteOffset', 0); stride = bv.get('byteStride') or sz * nc
    st = struct.Struct('<%d%s' % (nc, fmt))
    out = [st.unpack_from(buf, base + k * stride) for k in range(a['count'])]
    if a.get('normalized') and fmt != 'f':
        mx = float((1 << (8 * sz - (1 if fmt.islower() else 0))) - 1)
        out = [tuple(x / mx for x in v) for v in out]
    return out

def read_gltf(path, basis):
    js, bufs = _load_gltf(path); mesh = Mesh()
    def tex_of(mi):
        if mi is None: return None, 'default'
        m = js['materials'][mi]; name = m.get('name', 'mat%d' % mi)
        ti = m.get('pbrMetallicRoughness', {}).get('baseColorTexture', {}).get('index')
        if ti is None: return None, name
        img = js['images'][js['textures'][ti]['source']]
        return img.get('uri') or img.get('name') or ('tex%d' % ti), name
    def to_imd(M, v, w):          # apply column-major M (w=1 point, 0 direction) then basis
        q = [sum(M[c * 4 + r] * (v[c] if c < 3 else w) for c in range(4)) for r in range(3)]
        return basis.p(q)
    scene = js.get('scene', 0)
    roots = js['scenes'][scene]['nodes'] if js.get('scenes') else list(range(len(js.get('nodes', []))))
    def walk(ni, parent):
        n = js['nodes'][ni]; M = _mat4_mul(parent, _node_matrix(n))
        rn = ref_name(n.get('name', ''))
        if 'mesh' in n:
            # normal matrix: inverse transpose of the 3x3 part
            a = [[M[c * 4 + r] for c in range(3)] for r in range(3)]
            det = (a[0][0] * (a[1][1] * a[2][2] - a[1][2] * a[2][1]) - a[0][1] * (a[1][0] * a[2][2] - a[1][2] * a[2][0]) +
                   a[0][2] * (a[1][0] * a[2][1] - a[1][1] * a[2][0]))
            cof = [[(a[(r + 1) % 3][(c + 1) % 3] * a[(r + 2) % 3][(c + 2) % 3] - a[(r + 1) % 3][(c + 2) % 3] * a[(r + 2) % 3][(c + 1) % 3])
                    for c in range(3)] for r in range(3)]
            flip = det < 0
            for pr in js['meshes'][n['mesh']]['primitives']:
                mode = pr.get('mode', 4)
                at = pr['attributes']
                P = [to_imd(M, v, 1) for v in _accessor(js, bufs, at['POSITION'])]
                Nn = [W._norm(basis.p([sum(cof[r][c] * v[c] for c in range(3)) for r in range(3)])) for v in _accessor(js, bufs, at['NORMAL'])] if 'NORMAL' in at else None
                T = _accessor(js, bufs, at['TEXCOORD_0']) if 'TEXCOORD_0' in at else None
                idx = [i[0] for i in _accessor(js, bufs, pr['indices'])] if 'indices' in pr else list(range(len(P)))
                if mode == 4: tris = [idx[i:i + 3] for i in range(0, len(idx) - 2, 3)]
                elif mode == 5: tris = [(idx[i], idx[i + 1], idx[i + 2]) if i % 2 == 0 else (idx[i + 1], idx[i], idx[i + 2]) for i in range(len(idx) - 2)]
                elif mode == 6: tris = [(idx[0], idx[i], idx[i + 1]) for i in range(1, len(idx) - 1)]
                else: continue                                       # points / lines
                tex, mname = tex_of(pr.get('material'))
                for a, b, c in tris:
                    cs = [(P[i], (T[i][0], T[i][1] - 1.0) if T else (0.0, 0.0), Nn[i] if Nn else None) for i in (a, b, c)]
                    # basis change has det -1: reverse; a negative-determinant node matrix reverses again
                    mesh.add_tri(mname, tex, (cs[0], cs[1], cs[2]) if flip else (cs[0], cs[2], cs[1]))
        elif rn:
            pos = to_imd(M, (0, 0, 0), 1)
            cols = [to_imd(M, e, 0) for e in ((1, 0, 0), (0, 1, 0), (0, 0, 1))]
            Rimd, sc = _ref_rows(cols, basis)
            mesh.refs.append(W.refpoint(rn, pos, Rimd, scale=sc))
        for ch in n.get('children', []): walk(ch, M)
    I = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
    for r in roots: walk(r, I)
    return mesh

def _ref_rows(cols, basis):
    """cols: images (already in IMD coordinates) of the node's local source axes +X,+Y,+Z.
    The node's local frame is converted with the same rule as the mesh: local right = image of the
    source axis that maps to IMD +X, etc. Rows returned: local IMD X, Y, Z axes (unit)."""
    # basis.rows = (R, U, F) in source coordinates; a local source vector e maps to sum_k e.rows[k] * axis_k
    R, U, F = basis.rows
    def comb(v):   # local source vector v -> combination of the node's local column images
        return tuple(sum(v[c] * cols[c][q] for c in range(3)) for q in range(3))
    ax = [comb(R), comb(U), comb(F)]
    return tuple(W._norm(x) for x in ax), tuple(W._len(x) for x in ax)

def write_gltf(imd, path):
    """IMD -> glTF 2.0 (.gltf with embedded buffer). Inverse of the default import basis."""
    blob = bytearray(); views = []; accs = []; meshes = []; nodes = []; mats = []; imgs = []; texs = []
    def add(data_bytes, target=None):
        while len(blob) % 4: blob.append(0)
        views.append(dict({'buffer': 0, 'byteOffset': len(blob), 'byteLength': len(data_bytes)}, **({'target': target} if target else {})))
        blob.extend(data_bytes); return len(views) - 1
    for m in imd['materials']:
        t = m['textures'][0]['name'] if m['textures'] else None
        md = {'name': m['name'], 'pbrMetallicRoughness': {'metallicFactor': 0.0}}
        if t:
            imgs.append({'uri': t}); texs.append({'source': len(imgs) - 1})
            md['pbrMetallicRoughness']['baseColorTexture'] = {'index': len(texs) - 1}
        mats.append(md)
    for si, s in enumerate(imd['submeshes']):
        P = [(-x, y, z) for x, y, z, u, v in s['verts']]
        lo = [min(p[i] for p in P) for i in range(3)]; hi = [max(p[i] for p in P) for i in range(3)]
        pv = add(b''.join(struct.pack('<3f', *p) for p in P), 34962)
        accs.append({'bufferView': pv, 'componentType': 5126, 'count': len(P), 'type': 'VEC3', 'min': lo, 'max': hi})
        nv = add(b''.join(struct.pack('<3f', -x, y, z) for x, y, z in s['vnormals']), 34962)
        accs.append({'bufferView': nv, 'componentType': 5126, 'count': len(P), 'type': 'VEC3'})
        tv = add(b''.join(struct.pack('<2f', u, v + 1.0) for x, y, z, u, v in s['verts']), 34962)
        accs.append({'bufferView': tv, 'componentType': 5126, 'count': len(P), 'type': 'VEC2'})
        iv = add(b''.join(struct.pack('<3I', a, c, b) for a, b, c in s['faces']), 34963)
        accs.append({'bufferView': iv, 'componentType': 5125, 'count': 3 * len(s['faces']), 'type': 'SCALAR'})
        k = len(accs) - 4
        meshes.append({'name': 'sub%d' % si, 'primitives': [{'attributes': {'POSITION': k, 'NORMAL': k + 1, 'TEXCOORD_0': k + 2},
                                                             'indices': k + 3, 'material': s['material']}]})
        nodes.append({'name': 'sub%d' % si, 'mesh': si})
    for r in (imd['gref'] or {'refs': []})['refs']:
        m = r['m']; s = r['scale']
        # IMD rows (local X,Y,Z in IMD coords) -> source columns: mirror x of each axis, local X negated
        cx = (m[0], -m[1], -m[2]); cy = (-m[4], m[5], m[6]); cz = (-m[8], m[9], m[10])
        mat = [cx[0] * s[0], cx[1] * s[0], cx[2] * s[0], 0, cy[0] * s[1], cy[1] * s[1], cy[2] * s[1], 0,
               cz[0] * s[2], cz[1] * s[2], cz[2] * s[2], 0, -m[12], m[13], m[14], 1]
        nodes.append({'name': r['name'], 'matrix': [float(x) for x in mat]})
    js = {'asset': {'version': '2.0', 'generator': 'sw3 imdconv.py'}, 'scene': 0,
          'scenes': [{'nodes': list(range(len(nodes)))}], 'nodes': nodes, 'meshes': meshes, 'materials': mats,
          'accessors': accs, 'bufferViews': views,
          'buffers': [{'byteLength': len(blob), 'uri': 'data:application/octet-stream;base64,' + base64.b64encode(bytes(blob)).decode()}]}
    if imgs: js['images'] = imgs; js['textures'] = texs
    with open(path, 'w') as f: json.dump(js, f)

# ---------------------------------------------------------------- CLI

def scale_mesh(mesh, s):
    for e in mesh.mats.values():
        e['tris'] = [tuple(((p[0] * s, p[1] * s, p[2] * s), uv, n) for p, uv, n in t) for t in e['tris']]
    for r in mesh.refs:
        for i in (12, 13, 14): r['m'][i] *= s

def main(a):
    if not a or a[0] not in ('import', 'export'): print(__doc__); return 1
    opt = lambda k, d=None: a[a.index(k) + 1] if k in a else d
    if a[0] == 'export':
        imd = W.read_file(a[1])
        (write_gltf if a[2].lower().endswith('.gltf') else write_obj)(imd, a[2]); print('wrote', a[2]); return 0
    src, dst = a[1], a[2]
    basis = Basis(opt('--forward', '+z'), opt('--up', '+y'))
    mesh = read_gltf(src, basis) if src.lower().endswith(('.gltf', '.glb')) else read_obj(src, basis)
    if '--fit-length' in a:
        zs = [p[2] for e in mesh.mats.values() for t in e['tris'] for p, _, _ in t]
        scale_mesh(mesh, float(opt('--fit-length')) / (max(zs) - min(zs)))
    elif '--scale' in a:
        scale_mesh(mesh, float(opt('--scale')))
    extra = []
    if '--refs' in a:
        for r in json.load(open(opt('--refs'))):
            extra.append(W.refpoint(r['name'], r['pos'], r.get('rot'), tuple(r.get('scale', (1, 1, 1)))))
    if '--refs-from' in a:
        rs = float(opt('--refs-scale', '1'))
        for r in W.read_file(opt('--refs-from'))['gref']['refs']:
            r = dict(r, m=list(r['m'])); r.pop('name_len', None)
            for i in (12, 13, 14): r['m'][i] *= rs
            extra.append(r)
    imd = build_imd(mesh, template=opt('--template'), texture=opt('--texture'), smooth=float(opt('--smooth-angle', '40')),
                    spheres=int(opt('--spheres')) if '--spheres' in a else None, gelp='--no-gelp' not in a, extra_refs=extra)
    n = W.write_file(imd, dst)
    W.read_file(dst)
    print('wrote %s: %d bytes, %d materials, %d submeshes, %d tris, %d refpoints, GBND r=%.3f with %d spheres' % (
        dst, n, len(imd['materials']), len(imd['submeshes']), sum(len(s['faces']) for s in imd['submeshes']),
        len(imd['gref']['refs']) if imd['gref'] else 0, imd['gbnd']['main'][3], len(imd['gbnd']['spheres'])))
    return 0

if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
