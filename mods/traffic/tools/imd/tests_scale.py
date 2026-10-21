"""Check a uniformly scaled IMD against its vanilla source. Usage: python3 -I tests_scale.py src.IMD scaled.IMD s"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import imdwrite as W
a, b, s = W.read_file(sys.argv[1]), W.read_file(sys.argv[2]), float(sys.argv[3])
f32 = lambda x: __import__('struct').unpack('<f', __import__('struct').pack('<f', x))[0]
def rel(x, y): return abs(x - y) / max(abs(y), 1e-9)
res = {}
res['same V/F per submesh'] = all(len(p['verts']) == len(q['verts']) and p['faces'] == q['faces'] for p, q in zip(a['submeshes'], b['submeshes']))
res['positions = s*vanilla (max rel err)'] = max(rel(q['verts'][i][k], s * p['verts'][i][k]) for p, q in zip(a['submeshes'], b['submeshes']) for i in range(len(p['verts'])) for k in range(3) if abs(p['verts'][i][k]) > 1e-3)
res['uv unchanged'] = all(p['verts'][i][3:] == q['verts'][i][3:] for p, q in zip(a['submeshes'], b['submeshes']) for i in range(len(p['verts'])))
res['vertex normals max abs diff'] = max(abs(x - y) for p, q in zip(a['submeshes'], b['submeshes']) for n, m in zip(p['vnormals'], q['vnormals']) for x, y in zip(n, m))
res['area ratio (expect s^2=%.3f)' % (s * s)] = sum(q['area'] for q in b['submeshes']) / sum(p['area'] for p in a['submeshes'])
res['GBND main r ratio'] = b['gbnd']['main'][3] / a['gbnd']['main'][3]
res['GBND spheres scaled (max rel err)'] = max([rel(y, s * x) for p, q in zip(a['gbnd']['spheres'], b['gbnd']['spheres']) for x, y in zip(p, q) if abs(x) > 1e-3] or [0])
if a['gelp'] and b['gelp']: res['GELP radii ratio'] = [round(y / x, 4) for x, y in zip(a['gelp']['radii'], b['gelp']['radii'])]
ra = {r['name'] + str(i): r for i, r in enumerate(a['gref']['refs'])} if a['gref'] else {}
rb = {r['name'] + str(i): r for i, r in enumerate(b['gref']['refs'])} if b['gref'] else {}
res['refpoints'] = (len(ra), len(rb))
res['ref positions scaled (max rel err)'] = max([rel(y, s * x) for k in ra for x, y in zip(ra[k]['m'][12:15], rb[k]['m'][12:15]) if abs(x) > 1e-3] or [0])
res['ref rotations unchanged (max abs diff)'] = max([abs(x - y) for k in ra for x, y in zip(ra[k]['m'][:11], rb[k]['m'][:11])] or [0])
for k, v in res.items(): print('  %-45s %s' % (k, v if not isinstance(v, float) else '%.3g' % v))
