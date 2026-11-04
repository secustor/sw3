"""Header scan of every DDS under Data/TEXTURE, classified by role.
Usage: python3 -I ddsscan.py <Data dir> <imdparse dir> <out tsv>"""
import sys, os, struct, re, collections, xml.etree.ElementTree as ET
D, IMDP, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
sys.path.insert(0, IMDP); import imdparse
T = os.path.join(D, 'TEXTURE')

def hdr(p):
    b = open(p, 'rb').read(148); sz = os.path.getsize(p)
    if b[:4] != b'DDS ': return None
    hsz, flags, H, W, pitch, depth, mips = struct.unpack_from('<7I', b, 4)
    pfsz, pff = struct.unpack_from('<2I', b, 76); fcc = b[84:88]
    bits, rm, gm, bm, am = struct.unpack_from('<5I', b, 88)
    caps1, caps2 = struct.unpack_from('<2I', b, 108)
    if pff & 4: fmt = fcc.decode('latin1')
    elif pff & 0x40: fmt = 'RGB%d%s' % (bits, 'A' if pff & 1 else '')
    elif pff & 0x20000: fmt = 'L%d' % bits
    elif pff & 2: fmt = 'A%d' % bits
    else: fmt = 'pf%x' % pff
    if fmt.startswith('RGB'):
        masks = '%x/%x/%x/%x' % (rm, gm, bm, am)
        fmt += {'f800/7e0/1f/0':'(565)','7c00/3e0/1f/8000':'(1555)','f00/f0/f/f000':'(4444)',
                'ff0000/ff00/ff/0':'(888)','ff0000/ff00/ff/ff000000':'(8888)','ff/ff00/ff0000/ff000000':'(ABGR8888)'}.get(masks, '(' + masks + ')')
    return dict(W=W, H=H, mips=mips, flags=flags, fmt=fmt, caps1=caps1, caps2=caps2, size=sz, pitch=pitch)

# --- texture references from IMDs, by mesh role ---
carc = ET.parse(os.path.join(D, 'Game', 'Carcasses.xml')).getroot()
meshrole = {}
def setrole(mesh, role):
    if mesh: meshrole.setdefault(mesh.lower(), role)
for el in carc:
    cls = el.tag
    m = el.findtext('mesh_name'); dm = el.findtext('destroyed_mesh_name')
    role = {'Interceptor':'ship', 'Corvette':'ship', 'BigShip':'ship'}.get(cls, 'station/other')
    if dm: setrole(dm.strip(), 'destroyed')
    if m: setrole(m.strip(), role)
try:
    mods = ET.parse(os.path.join(D, 'Game', 'Modules.xml')).getroot()
    for m in mods.iter('mesh_name'):
        if m.text: setrole(m.text.strip(), 'module')
except Exception as e: print('modules.xml', e)
obj = os.path.join(D, 'OBJECT')
imds = {f[:-4].lower(): os.path.join(obj, f) for f in os.listdir(obj) if f.lower().endswith('.imd')}
parsed = {}
for k, p in imds.items():
    try: parsed[k] = imdparse.parse(p)
    except Exception: pass
# propagate role through Module: refpoints
changed = True
while changed:
    changed = False
    for k, r in parsed.items():
        if k not in meshrole or not r['gref']: continue
        for n, *_ in r['gref']['refs']:
            if n.lower().startswith('module:'):
                sub = n.split(':', 1)[1].split()[0].lower()
                role = meshrole[k]
                if 'destroyed' in sub and role == 'ship': role = 'destroyed'
                if sub in parsed and sub not in meshrole:
                    meshrole[sub] = role; changed = True
texrole = collections.defaultdict(set); slotuse = collections.defaultdict(collections.Counter)
grefdds = set()
for k, r in parsed.items():
    role = meshrole.get(k, 'imd-unreferenced')
    if 'destroyed' in k and role in ('ship', 'imd-unreferenced'): role = 'destroyed'
    for m in r['gmat']:
        for s, n, a in m['tex']:
            base = os.path.splitext(n)[0].lower()
            texrole[base].add(role); slotuse[base][s] += 1
    if r['gref']:
        for n, *_ in r['gref']['refs']:
            for t in re.findall(r'[\w\-]+\.dds', n, re.I): grefdds.add(t[:-4].lower())
# PFX / environment / other text refs
pfx = set()
for root, _, fs in os.walk(D):
    if os.path.relpath(root, D).split(os.sep)[0] in ('TEXTURE', 'OBJECT', 'SOUND', 'MUSIC', 'VIDEO'): continue
    for f in fs:
        p = os.path.join(root, f)
        if os.path.getsize(p) > 20_000_000: continue
        try: s = open(p, 'rb').read().decode('latin1')
        except Exception: continue
        top = os.path.relpath(p, D).split(os.sep)[0]
        for t in re.findall(r'[\w\-/\\]+\.dds', s, re.I):
            b = t.replace('\\', '/').split('/')[-1][:-4].lower()
            pfx.add((b, top))
pfxnames = {b for b, top in pfx if top == 'PFX'}
othertxt = collections.defaultdict(set)
for b, top in pfx: othertxt[b].add(top)

rows = []
for root, _, fs in os.walk(T):
    for f in fs:
        if not f.lower().endswith('.dds'): continue
        p = os.path.join(root, f); rel = os.path.relpath(p, T); h = hdr(p)
        parts = rel.split(os.sep); base = f[:-4].lower()
        if len(parts) > 1:
            if parts[0] == 'Interface': cls = 'ui:' + '/'.join(parts[1:-1])
            elif parts[0].startswith('SB'): cls = 'skybox'
            else: cls = parts[0]
        else:
            r = texrole.get(base, set())
            if 'ship' in r: cls = 'ship-skin'
            elif 'destroyed' in r: cls = 'ship-destroyed'
            elif 'module' in r: cls = 'module-mesh'
            elif 'station/other' in r: cls = 'station/other-mesh'
            elif r: cls = 'imd-unreferenced-mesh'
            elif base in pfxnames or base in grefdds: cls = 'pfx/engine'
            elif base in othertxt: cls = 'text-ref:' + ','.join(sorted(othertxt[base]))
            else: cls = 'unreferenced'
        rows.append((cls, rel, h))
with open(OUT, 'w') as o:
    o.write('class\tpath\tW\tH\tmips\tfmt\tflags\tcaps1\tsize\n')
    for cls, rel, h in sorted(rows):
        o.write('%s\t%s\t%d\t%d\t%d\t%s\t%x\t%x\t%d\n' % (cls, rel, h['W'], h['H'], h['mips'], h['fmt'], h['flags'], h['caps1'], h['size']))
print('dds files', len(rows))
bycls = collections.defaultdict(list)
for cls, rel, h in rows: bycls[cls].append(h)
for cls in sorted(bycls, key=lambda c: -len(bycls[c])):
    hs = bycls[cls]
    fm = collections.Counter(h['fmt'] for h in hs)
    sz = collections.Counter('%dx%d' % (h['W'], h['H']) for h in hs)
    mp = collections.Counter(('0' if h['mips'] == 0 else ('full' if h['mips'] == 1 + max(h['W'], h['H']).bit_length() - 1 else str(h['mips']))) for h in hs)
    print('\n## %s  n=%d' % (cls, len(hs)))
    print('  fmt  ', fm.most_common())
    print('  size ', sz.most_common(8))
    print('  mips ', mp.most_common())
# slot-role mapping
print('\n## slot usage across IMD texture refs')
slotname = collections.defaultdict(collections.Counter)
for k, r in parsed.items():
    for m in r['gmat']:
        s1 = [n for s, n, a in m['tex'] if s == 1]
        for s, n, a in m['tex']:
            suf = re.sub(r'.*?(_map|_diffuse|_spec|_glow|_bump|_normal|_lum|_illum|_self|_alpha|_env|_refl|_light)?$', r'\1', os.path.splitext(n)[0].lower()) or '(none)'
            same = 'same-as-slot1' if s1 and n.lower() == s1[0].lower() else ('no-slot1' if not s1 else 'differs')
            slotname[s][(same,)] += 1
            slotname[s][('suffix', suf)] += 1
for s in sorted(slotname):
    print(' slot', s, sorted(slotname[s].items(), key=lambda x: -x[1])[:12])
