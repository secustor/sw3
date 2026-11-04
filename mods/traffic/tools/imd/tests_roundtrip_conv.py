"""Export vanilla IMDs to OBJ and glTF, import them back, compare geometry and refpoints.
Usage: python3 -I tests_roundtrip_conv.py <OBJECT dir> <tmp dir> [names...]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import imdwrite as W, imdconv as C
D, T = sys.argv[1], sys.argv[2]; os.makedirs(T, exist_ok=True)
names = sys.argv[3:] or ['Gunslinger_patrol', 'arba_Inoco', 'Lion_Cruiser_MK3', 'Btransport', 'excalibur_gamer']
def soup(imd):
    out = []
    for s in imd['submeshes']:
        for f in s['faces']:
            out.append(tuple((tuple(round(x, 4) for x in s['verts'][i][:3]), tuple(round(x, 4) for x in s['verts'][i][3:]),
                              tuple(round(x, 3) for x in s['vnormals'][i])) for i in f))
    # canonical rotation of each triangle (keeps winding)
    canon = []
    for t in out:
        k = min(range(3), key=lambda j: t[j]); canon.append(t[k:] + t[:k])
    return sorted(canon)
def refs(imd):
    return sorted((r['name'], tuple(round(x, 3) + 0.0 for x in r['m'][:15]), tuple(round(x, 3) for x in r['scale'])) for r in (imd['gref'] or {'refs': []})['refs'])
for n in names:
    src = os.path.join(D, n + '.IMD')
    if not os.path.exists(src): print('missing', n); continue
    a = W.read_file(src)
    for ext in ('obj', 'gltf'):
        p = os.path.join(T, n + '.' + ext); q = os.path.join(T, n + '_from_' + ext + '.IMD')
        (C.write_gltf if ext == 'gltf' else C.write_obj)(a, p)
        mesh = (C.read_gltf if ext == 'gltf' else C.read_obj)(p, C.Basis())
        b = C.build_imd(mesh, template=src, smooth=0)
        W.write_file(b, q); b = W.read_file(q)
        sa, sb = soup(a), soup(b)
        same = sum(1 for x, y in zip(sa, sb) if x == y)
        ra, rb = refs(a), refs(b)
        rs = sum(1 for x, y in zip(ra, rb) if x == y) if ext == 'gltf' else None
        V = sum(len(s['verts']) for s in a['submeshes']); Vb = sum(len(s['verts']) for s in b['submeshes'])
        print('%-20s %-4s tris %d/%d identical (pos 1e-4, uv 1e-4, normal 1e-3, winding kept)  verts %d -> %d after dedupe  refs %s/%d  GBND r %.4f -> %.4f' % (
            n, ext, same, len(sa), V, Vb, rs, len(ra), a['gbnd']['main'][3], b['gbnd']['main'][3]))
        if ext == 'gltf' and rs != len(ra):
            for x, y in zip(ra, rb):
                if x != y: print('   ref diff', x, '\n            ', y); break
