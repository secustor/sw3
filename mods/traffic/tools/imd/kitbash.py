"""Kitbash IMDs from vanilla parts: select geometry, transform it, merge, recompute bounds, carry refpoints.

Usage: python3 -I kitbash.py recipe.json [--objdir <Data/OBJECT>]

Recipe (JSON):
{
  "out": "out/Gunslinger_kb.IMD",
  "parts": [
    { "imd": "Gunslinger_patrol",              # name in --objdir or a path
      "submeshes": "all" | [0, 2],
      "select": {"x_min": 0.2, "z_max": 0.3},  # optional: keep triangles whose centroid is in the box
                                               # keys x_min x_max y_min y_max z_min z_max, abs_x_min abs_x_max
      "ops": [ {"scale": 1.3} | {"scale": [sx, sy, sz]} | {"mirror": "x"} |
               {"rotate": ["y", 90]} | {"translate": [x, y, z]} ],          # applied in order
      "refs": "all" | "none" | "in_select" | ["Biggun:", "Fire:"],          # name prefixes
      "rename": {"Biggun:right": "Biggun:right2"},                         # applied after transform
      "ref_size": ["flare", "fire"],          # ref types whose GREF scale follows the transform scale
      "spheres": "transform" | "auto" | "none" # "transform": vanilla GBND spheres of the part, transformed
                                               #  (only spheres whose centre lies in "select", if given)
    }, ...
  ],
  "materials": "dedupe" | "keep",              # merge identical GMATs
  "gelp": "auto" | "transform" | "none",       # "transform": GELP of parts[0] transformed (axis-aligned ops only)
  "extra_refs": [{"name": "Biggun:center2", "pos": [0, -0.4, 0.6]}]
}
GBND main sphere is recomputed (centre at the origin, radius = farthest vertex), as in 973 of 984 vanilla files.
"""
import sys, os, json, math, copy
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import imdwrite as W

DEFAULT_OBJ = '/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data/OBJECT'

# ---- 3x3 + translation affine
def ident(): return [[1.0, 0, 0], [0, 1.0, 0], [0, 0, 1.0]], [0.0, 0.0, 0.0]
def mat_mul(A, B): return [[sum(A[i][k] * B[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
def mat_vec(A, v): return [sum(A[i][k] * v[k] for k in range(3)) for i in range(3)]
def det3(a):
    return (a[0][0] * (a[1][1] * a[2][2] - a[1][2] * a[2][1]) - a[0][1] * (a[1][0] * a[2][2] - a[1][2] * a[2][0]) +
            a[0][2] * (a[1][0] * a[2][1] - a[1][1] * a[2][0]))
def inv_t(a):
    d = det3(a)
    cof = [[(a[(r + 1) % 3][(c + 1) % 3] * a[(r + 2) % 3][(c + 2) % 3] - a[(r + 1) % 3][(c + 2) % 3] * a[(r + 2) % 3][(c + 1) % 3])
            for c in range(3)] for r in range(3)]
    return [[cof[r][c] / d for c in range(3)] for r in range(3)]      # = (A^-1)^T

def compose(ops):
    L, t = ident()
    for op in ops:
        if 'scale' in op:
            s = op['scale']; s = [s, s, s] if isinstance(s, (int, float)) else s
            M = [[s[0], 0, 0], [0, s[1], 0], [0, 0, s[2]]]
        elif 'mirror' in op:
            i = 'xyz'.index(op['mirror']); M = [[1.0, 0, 0], [0, 1.0, 0], [0, 0, 1.0]]; M[i][i] = -1.0
        elif 'rotate' in op:
            ax, deg = op['rotate']; c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
            M = {'x': [[1, 0, 0], [0, c, -s], [0, s, c]], 'y': [[c, 0, s], [0, 1, 0], [-s, 0, c]],
                 'z': [[c, -s, 0], [s, c, 0], [0, 0, 1]]}[ax]
        elif 'translate' in op:
            t = [a + b for a, b in zip(t, op['translate'])]; continue
        else:
            raise ValueError(op)
        L = mat_mul(M, L); t = mat_vec(M, t)
    return L, t

def in_box(p, sel):
    if not sel: return True
    for k, v in sel.items():
        ax = k.replace('abs_', '')[0]; i = 'xyz'.index(ax); x = abs(p[i]) if k.startswith('abs_') else p[i]
        if k.endswith('_min') and x < v: return False
        if k.endswith('_max') and x > v: return False
    return True

def xform_submesh(s, L, t, sel):
    N = inv_t(L); flip = det3(L) < 0
    V = s['verts']; keep = []
    for f in s['faces']:
        c = [sum(V[i][q] for i in f) / 3 for q in range(3)]
        if in_box(c, sel): keep.append(f)
    if not keep: return None
    used = sorted({i for f in keep for i in f}); remap = {o: n for n, o in enumerate(used)}
    verts = []
    for i in used:
        x, y, z, u, v = V[i]; p = mat_vec(L, (x, y, z))
        verts.append((p[0] + t[0], p[1] + t[1], p[2] + t[2], u, v))
    vn = [W._norm(mat_vec(N, s['vnormals'][i])) for i in used]
    faces = [(remap[a], remap[c], remap[b]) if flip else (remap[a], remap[b], remap[c]) for a, b, c in keep]
    out = W.submesh(s['material'], verts, faces, vn)
    return out

def xform_ref(r, L, t, size_types):
    r = copy.deepcopy(r); r.pop('name_len', None); m = r['m']
    p = mat_vec(L, m[12:15]); m[12:15] = [p[0] + t[0], p[1] + t[1], p[2] + t[2]]
    rows = [mat_vec(L, m[0:3]), mat_vec(L, m[4:7]), mat_vec(L, m[8:11])]
    lens = [W._len(x) for x in rows]; rows = [W._norm(x) for x in rows]
    if det3(L) < 0: rows[0] = tuple(-x for x in rows[0])          # keep a proper rotation (see converter.md)
    m[0:3], m[4:7], m[8:11] = rows
    if r['name'].split(':')[0].lower() in size_types:
        r['scale'] = tuple(a * b for a, b in zip(r['scale'], lens))
    return r

def build(recipe, objdir=DEFAULT_OBJ, base=''):
    out = W.new_imd(); spheres = []; refs = []; gelp_t = None
    matkey = {}
    def resolve(n):
        p = n if os.path.exists(n) else os.path.join(objdir, n if n.lower().endswith('.imd') else n + '.IMD')
        return p
    for pi, part in enumerate(recipe['parts']):
        src = W.read_file(resolve(part['imd']))
        L, t = compose(part.get('ops', []))
        sel = part.get('select')
        subs = range(len(src['submeshes'])) if part.get('submeshes', 'all') == 'all' else part['submeshes']
        n_sub0 = len(out['submeshes'])
        for si in subs:
            s = xform_submesh(src['submeshes'][si], L, t, sel)
            if s is None: continue
            m = src['materials'][s['material']]
            key = json.dumps([m['name'], m['koeff'], m['textures']]) if recipe.get('materials', 'dedupe') == 'dedupe' else '%d/%d' % (pi, s['material'])
            if key not in matkey:
                matkey[key] = len(out['materials']); out['materials'].append(copy.deepcopy(m))
            s['material'] = matkey[key]; out['submeshes'].append(s)
        sp = part.get('spheres', 'auto' if sel else 'transform')
        n_before = len(spheres)
        if sp == 'transform' and src['gbnd']:
            k = max(W._len([L[0][c], L[1][c], L[2][c]]) for c in range(3))     # exact for uniform scale
            for x, y, z, r in src['gbnd']['spheres']:
                if sel and not in_box((x, y, z), sel): continue
                p = mat_vec(L, (x, y, z)); spheres.append((p[0] + t[0], p[1] + t[1], p[2] + t[2], r * k))
        if sp == 'auto' or (sp == 'transform' and len(spheres) == n_before):   # no vanilla sphere centre in select
            pts = [v[:3] for s in out['submeshes'][n_sub0:] for v in s['verts']]
            spheres += W.auto_spheres(pts, part.get('auto_k', 4))
        if pi == 0 and src['gelp']:
            c = mat_vec(L, src['gelp']['center']); r = src['gelp']['radii']
            gelp_t = {'ver': 100, 'center': tuple(a + b for a, b in zip(c, t)),
                      'radii': tuple(abs(r[i]) * W._len([L[0][i], L[1][i], L[2][i]]) for i in range(3))}
        rsel = part.get('refs', 'all')
        size_types = [x.lower() for x in part.get('ref_size', ['flare', 'fire'])]
        for r in (src['gref'] or {'refs': []})['refs']:
            if rsel == 'none': continue
            if rsel == 'in_select' and not in_box(r['m'][12:15], sel): continue
            if isinstance(rsel, list) and not any(r['name'].lower().startswith(p.lower()) for p in rsel): continue
            r2 = xform_ref(r, L, t, size_types)
            r2['name'] = part.get('rename', {}).get(r2['name'], r2['name'])
            refs.append(r2)
    for r in recipe.get('extra_refs', []):
        refs.append(W.refpoint(r['name'], r['pos'], r.get('rot'), tuple(r.get('scale', (1, 1, 1)))))
    pts = W.all_points(out)
    out['gbnd'] = {'ver': 100, 'main': W.main_sphere(pts), 'spheres': spheres}
    g = recipe.get('gelp', 'auto')
    out['gelp'] = W.ellipsoid(pts) if g == 'auto' else gelp_t if g == 'transform' else None
    out['gref'] = {'ver': 100, 'refs': refs} if refs else None
    return out

def check(imd):
    """Sanity report: duplicate names of types the engine de-duplicates, vertices outside GBND spheres, sizes."""
    exempt = {'flare', 'fire', 'module', 'tractorbeam', 'turret', 'gunpoint'}   # exe 0x415fa0-0x415fef
    seen = {}; dups = []
    for r in (imd['gref'] or {'refs': []})['refs']:
        t = r['name'].split(':')[0].lower()
        if t in exempt: continue
        if r['name'] in seen: dups.append(r['name'])
        seen[r['name']] = 1
    pts = W.all_points(imd); sp = imd['gbnd']['spheres']
    step = max(1, len(pts) // 3000); n = inside = 0
    for p in pts[::step]:
        n += 1; inside += any((p[0] - x) ** 2 + (p[1] - y) ** 2 + (p[2] - z) ** 2 <= r * r * 1.0001 for x, y, z, r in sp)
    lo, hi = W.bbox(pts)
    return {'duplicate_refpoint_names': dups, 'vertex_coverage_by_spheres': round(inside / max(n, 1), 3),
            'bbox': [[round(x, 3) for x in lo], [round(x, 3) for x in hi]], 'gbnd_r': round(imd['gbnd']['main'][3], 4),
            'n_spheres': len(sp), 'tris': sum(len(s['faces']) for s in imd['submeshes']),
            'verts': sum(len(s['verts']) for s in imd['submeshes']), 'materials': len(imd['materials'])}

if __name__ == '__main__':
    a = sys.argv[1:]
    if not a: print(__doc__); sys.exit(1)
    objdir = a[a.index('--objdir') + 1] if '--objdir' in a else DEFAULT_OBJ
    recipe = json.load(open(a[0]))
    imd = build(recipe, objdir)
    outp = os.path.join(os.path.dirname(os.path.abspath(a[0])), recipe['out']) if not os.path.isabs(recipe['out']) else recipe['out']
    n = W.write_file(imd, outp)
    print('wrote', outp, n, 'bytes'); print(json.dumps(check(W.read_file(outp))))
