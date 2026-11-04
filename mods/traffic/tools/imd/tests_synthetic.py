"""Synthetic OBJ / glTF inputs that exercise quads, missing normals, TRS nodes, negative scale and refpoints.
Usage: python3 -I tests_synthetic.py <tmp dir>"""
import sys, os, json, struct, base64, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import imdwrite as W, imdconv as C
T = sys.argv[1]; os.makedirs(T, exist_ok=True); ok = True
def check(cond, msg):
    global ok; ok &= bool(cond); print('PASS' if cond else 'FAIL', msg)
def outward(imd):
    pts = W.all_points(imd); c = [sum(p[i] for p in pts) / len(pts) for i in range(3)]
    good = tot = 0
    for s in imd['submeshes']:
        for (a, b, cc), n in zip(s['faces'], s['fnormals']):
            fc = [(s['verts'][a][i] + s['verts'][b][i] + s['verts'][cc][i]) / 3 - c[i] for i in range(3)]
            tot += 1; good += sum(x * y for x, y in zip(fc, n)) > 0
    return good, tot
# 1. OBJ: box 1 wide (x), 0.5 high (y), 2 long; nose at -z (Blender default export: forward -Z), quads, no normals,
#    UV v up; a refpoint object 'Biggun:right' at the model's right side (+x in OBJ means model right? no: in a
#    right-handed file with forward -Z and up +Y, right = F x U = (-z) x y = +x).
obj = """mtllib box.mtl
o hull
v -0.5 -0.25 -1
v 0.5 -0.25 -1
v 0.5 0.25 -1
v -0.5 0.25 -1
v -0.5 -0.25 1
v 0.5 -0.25 1
v 0.5 0.25 1
v -0.5 0.25 1
vt 0 0
vt 1 0
vt 1 1
vt 0 1
usemtl hullmat
f 1/1 4/4 3/3 2/2
f 5/1 6/2 7/3 8/4
f 1/1 2/2 6/3 5/4
f 4/1 8/4 7/3 3/2
f 1/1 5/2 8/3 4/4
f 2/1 3/4 7/3 6/2
o Biggun:right
v 0.6 0 0
v 0.6 0.02 0
v 0.62 0 0
f 9 10 11
"""
open(os.path.join(T, 'box.obj'), 'w').write(obj)
open(os.path.join(T, 'box.mtl'), 'w').write('newmtl hullmat\nmap_Kd box_skin.png\n')
m = C.read_obj(os.path.join(T, 'box.obj'), C.Basis('-z', '+y'))
imd = C.build_imd(m, smooth=0); W.write_file(imd, os.path.join(T, 'box_obj.IMD')); imd = W.read_file(os.path.join(T, 'box_obj.IMD'))
lo, hi = W.bbox(W.all_points(imd))
check(abs(lo[2] + 1) < 1e-6 and abs(hi[2] - 1) < 1e-6, 'OBJ box z extent -1..1')
g, t = outward(imd); check(g == t == 12, 'OBJ quads -> 12 triangles, all face normals outward (%d/%d)' % (g, t))
r = imd['gref']['refs'][0]; check(r['name'] == 'Biggun:right' and r['m'][12] > 0.5, 'OBJ refpoint Biggun:right at IMD x>0 (%.3f)' % r['m'][12])
check(imd['materials'][0]['textures'][0]['name'] == 'box_skin.dds', 'map_Kd box_skin.png -> GMAT texture box_skin.dds')
uv = sorted(set(v[4] for s in imd['submeshes'] for v in s['verts'])); check(min(uv) <= -1 + 1e-9 and max(uv) <= 0, 'OBJ v -> -v (range %s)' % uv)
# 2. glTF: same box built from a unit cube scaled (1, 0.5, 2) by a parent node, child node rotated 90 deg about Y;
#    the hull node also has a mirrored (negative x scale) instance; a refpoint node with rotation.
P = [(-.5, -.5, -.5), (.5, -.5, -.5), (.5, .5, -.5), (-.5, .5, -.5), (-.5, -.5, .5), (.5, -.5, .5), (.5, .5, .5), (-.5, .5, .5)]
Q = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (3, 7, 6, 2), (0, 4, 7, 3), (1, 2, 6, 5)]   # CCW from outside (right-handed)
idx = [i for q in Q for i in (q[0], q[1], q[2], q[0], q[2], q[3])]
pos = b''.join(struct.pack('<3f', *p) for p in P); ind = b''.join(struct.pack('<H', i) for i in idx)
uvs = b''.join(struct.pack('<2f', (i & 1), (i >> 1) & 1) for i in range(8))
blob = pos + uvs + ind
s2 = math.sqrt(0.5)
js = {'asset': {'version': '2.0'}, 'scene': 0, 'scenes': [{'nodes': [0]}],
      'nodes': [{'name': 'root', 'scale': [1, 0.5, 2], 'children': [1, 2, 3]},
                {'name': 'hull', 'mesh': 0},
                {'name': 'mirror', 'mesh': 0, 'translation': [3, 0, 0], 'scale': [-1, 1, 1]},
                {'name': 'Fire:white_fire.dds Fighter.efx.001', 'translation': [0.2, 0, -0.5], 'rotation': [0, 1, 0, 0], 'scale': [0.2, 0.2, 1.5]}],
      'meshes': [{'primitives': [{'attributes': {'POSITION': 0, 'TEXCOORD_0': 1}, 'indices': 2, 'material': 0}]}],
      'materials': [{'name': 'lit.hull', 'pbrMetallicRoughness': {'baseColorTexture': {'index': 0}}}],
      'textures': [{'source': 0}], 'images': [{'uri': 'hull_diffuse.png'}],
      'accessors': [{'bufferView': 0, 'componentType': 5126, 'count': 8, 'type': 'VEC3'},
                    {'bufferView': 1, 'componentType': 5126, 'count': 8, 'type': 'VEC2'},
                    {'bufferView': 2, 'componentType': 5123, 'count': len(idx), 'type': 'SCALAR'}],
      'bufferViews': [{'buffer': 0, 'byteOffset': 0, 'byteLength': len(pos)}, {'buffer': 0, 'byteOffset': len(pos), 'byteLength': len(uvs)},
                      {'buffer': 0, 'byteOffset': len(pos) + len(uvs), 'byteLength': len(ind)}],
      'buffers': [{'byteLength': len(blob)}]}
jb = json.dumps(js).encode(); jb += b' ' * (-len(jb) % 4); bb = blob + b'\0' * (-len(blob) % 4)
glb = struct.pack('<4sII', b'glTF', 2, 12 + 8 + len(jb) + 8 + len(bb)) + struct.pack('<II', len(jb), 0x4E4F534A) + jb + struct.pack('<II', len(bb), 0x004E4942) + bb
open(os.path.join(T, 'box.glb'), 'wb').write(glb)
m = C.read_gltf(os.path.join(T, 'box.glb'), C.Basis())
imd = C.build_imd(m, smooth=30); W.write_file(imd, os.path.join(T, 'box_glb.IMD')); imd = W.read_file(os.path.join(T, 'box_glb.IMD'))
pts = W.all_points(imd); lo, hi = W.bbox(pts)
check(abs(lo[0] + 3.5) < 1e-6 and abs(hi[0] - 0.5) < 1e-6, 'glTF +X (model left) -> IMD -X; mirror instance at x=-3 (x range %.2f..%.2f)' % (lo[0], hi[0]))
check(abs(hi[2] - 1) < 1e-6 and abs(hi[1] - .25) < 1e-6, 'parent scale (1,0.5,2) applied')
# outward test per instance
for name, sel in (('hull', lambda x: x > -1.5), ('mirror', lambda x: x < -1.5)):
    good = tot = 0
    for s in imd['submeshes']:
        for (a, b, c), n in zip(s['faces'], s['fnormals']):
            cen = [(s['verts'][a][i] + s['verts'][b][i] + s['verts'][c][i]) / 3 for i in range(3)]
            if not sel(cen[0]): continue
            oc = (-3.0 if name == 'mirror' else 0.0, 0, 0)
            tot += 1; good += sum((cen[i] - oc[i]) * n[i] for i in range(3)) > 0
    check(good == tot == 12, 'glTF %s instance: %d/%d faces outward (negative-determinant node handled)' % (name, good, tot))
vn = [n for s in imd['submeshes'] for n in s['vnormals']]
check(all(abs(abs(x) - 1) < 1e-6 or abs(x) < 1e-6 for n in vn for x in n), 'smooth-angle 30 keeps box corners flat (normals axis-aligned)')
r = imd['gref']['refs'][0]
check(r['name'] == 'Fire:white_fire.dds Fighter.efx', 'Blender .001 suffix stripped from refpoint name')
check(abs(r['m'][12] + 0.2) < 1e-6 and abs(r['m'][14] + 1.0) < 1e-6, 'refpoint position glTF (0.2,0,-0.5)*scale -> IMD (%.2f, %.2f, %.2f)' % tuple(r['m'][12:15]))
check(r['m'][10] < -0.99, 'refpoint rotated 180 deg about Y: local forward row = -Z (engine points back), row2=%s' % [round(x, 3) for x in r['m'][8:11]])
check(abs(r['scale'][2] - 3.0) < 1e-6 and abs(r['scale'][0] - 0.2) < 1e-6, 'refpoint scale includes parent scale: %s' % [round(x, 3) for x in r['scale']])
R = [r['m'][0:3], r['m'][4:7], r['m'][8:11]]
det = (R[0][0] * (R[1][1] * R[2][2] - R[1][2] * R[2][1]) - R[0][1] * (R[1][0] * R[2][2] - R[1][2] * R[2][0]) + R[0][2] * (R[1][0] * R[2][1] - R[1][1] * R[2][0]))
check(abs(det - 1) < 1e-6, 'refpoint rotation is proper (det %.3f)' % det)
print('ALL PASS' if ok else 'SOME FAILED')
