"""Survey all slot ini files in Data/TEXTURE/Interface/Carcass/Slots.
Usage: python3 -I slotini.py <Data dir>
Prints: raw format quirks, every key, value ranges per key, per-type stats,
mapping_name users and classes, refpoint check against the IMD GREF chunk."""
import sys, os, re, collections, xml.etree.ElementTree as ET

G = sys.argv[1]
SL = os.path.join(G, 'TEXTURE/Interface/Carcass/Slots')
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'imd'))


def parse(path):
    raw = open(path, 'rb').read()
    quirks = []
    if raw.startswith(b'\xef\xbb\xbf'):
        quirks.append('utf8-bom')
    if b'\r\n' not in raw:
        quirks.append('LF-only')
    if any(b > 0x7f for b in raw):
        quirks.append('non-ascii')
    if not raw.endswith(b'\n'):
        quirks.append('no-final-newline')
    txt = raw.decode('cp1251')
    secs = collections.OrderedDict()
    cur = None
    for n, line in enumerate(txt.splitlines(), 1):
        s = line.strip()
        if not s:
            continue
        if s.startswith(';') or s.startswith('//'):
            quirks.append('comment@%d' % n)
            continue
        if line != line.lstrip():
            quirks.append('leading-ws@%d' % n)
        m = re.match(r'\[(.+)\]$', s)
        if m:
            cur = m.group(1)
            if cur in secs:
                quirks.append('dup-section %s' % cur)
            secs[cur] = collections.OrderedDict()
            continue
        if '=' not in s:
            quirks.append('junk@%d:%r' % (n, s))
            continue
        k, v = s.split('=', 1)
        if k != k.strip() or v != v.strip():
            quirks.append('ws-around-eq@%d' % n)
        secs.setdefault(cur, collections.OrderedDict())[k.strip()] = v.strip()
    return secs, quirks


files = sorted(f for f in os.listdir(SL) if f.lower().endswith('.ini'))
print('ini files:', len(files))
keys = collections.Counter()
seckeys = collections.Counter()
vals = collections.defaultdict(collections.Counter)
types = collections.Counter()
nslots = {}
coords = collections.defaultdict(list)
info = {}
for f in files:
    secs, q = parse(os.path.join(SL, f))
    info[f] = secs
    names = list(secs)
    slotnames = [s for s in names if s and s.lower().startswith('slot')]
    nslots[f] = len(slotnames)
    # slot numbering contiguity
    nums = [int(re.sub(r'\D', '', s)) for s in slotnames]
    if nums != list(range(1, len(nums) + 1)):
        q.append('slot-numbering %s' % nums)
    other = [s for s in names if s not in slotnames]
    if other != ['image']:
        q.append('sections %s' % other)
    for s, kv in secs.items():
        kind = 'slot' if s in slotnames else s
        for k, v in kv.items():
            keys[(kind, k)] += 1
            if k in ('type', 'text_aligment', 'tuv', 'name', 'index'):
                vals[(kind, k)][v] += 1
            if k in ('image_coord', 'text_coord'):
                xy = v.split()
                if len(xy) != 2:
                    q.append('coord-arity %s %s=%r' % (s, k, v))
                else:
                    coords[(k, kv.get('type'))].append(tuple(int(t) for t in xy))
        if kind == 'slot':
            types[kv.get('type')] += 1
            seckeys[tuple(kv)] += 1
    if q:
        print('QUIRK', f, q)

print('\nkeys by section kind:')
for (kind, k), c in sorted(keys.items()):
    print('  [%s] %s: %d' % (kind, k, c))
print('\nkey order in slot sections:')
for t, c in seckeys.most_common():
    print('  %d x %s' % (c, ' '.join(t)))
print('\nenumerated values:')
for kk, cnt in sorted(vals.items()):
    print('  [%s] %s:' % kk, dict(cnt.most_common()))
print('\nslot type totals:', dict(types.most_common()))
print('\nslot counts per ini:', collections.Counter(nslots.values()))
print('  max', max(nslots.items(), key=lambda x: x[1]))
print('\ncoordinate ranges (min x, max x, min y, max y, n):')
for (k, t), lst in sorted(coords.items(), key=lambda x: (x[0][0], str(x[0][1]))):
    xs = [a for a, b in lst]
    ys = [b for a, b in lst]
    print('  %-11s %-13s x %4d..%4d y %4d..%4d n=%d' % (k, t, min(xs), max(xs), min(ys), max(ys), len(lst)))
allx = [a for (k, t), l in coords.items() if k == 'image_coord' for a, b in l]
ally = [b for (k, t), l in coords.items() if k == 'image_coord' for a, b in l]
print('  all image_coord x %d..%d y %d..%d' % (min(allx), max(allx), min(ally), max(ally)))

# users from Carcasses.xml
root = ET.parse(os.path.join(G, 'Game/Carcasses.xml')).getroot()
users = collections.defaultdict(list)
for el in root:
    mn = el.findtext('mapping_name')
    if mn:
        users[mn.lower()].append((el.tag, el.get('name'), el.findtext('mesh_name'), el))
print('\nini -> classes using it (count) / unused:')
cls_by_ini = {}
for f in files:
    u = users.get(f[:-4].lower(), [])
    cls = collections.Counter(t for t, *_ in u)
    cls_by_ini[f] = cls
    img = info[f].get('image', {})
    print('  %-26s slots=%2d img=%s/%s/%s  %s' % (f, nslots[f], img.get('name'), img.get('tuv'), img.get('index'),
                                                 dict(cls) if u else 'UNUSED'))
missing = [m for m in users if m + '.ini' not in [x.lower() for x in files]]
print('mapping_name values without ini:', missing)

# per-class type maxima in ini
print('\nper class: max slots of each type in one ini')
pc = collections.defaultdict(collections.Counter)
for f in files:
    tc = collections.Counter(kv.get('type') for s, kv in info[f].items() if s != 'image')
    for c in cls_by_ini[f]:
        for t, n in tc.items():
            pc[c][t] = max(pc[c][t], n)
        pc[c]['_total'] = max(pc[c]['_total'], nslots[f])
for c, d in pc.items():
    print('  ', c, dict(d))

# atlas cell usage
cells = collections.defaultdict(list)
for f in files:
    img = info[f].get('image', {})
    cells[(img.get('name', '').lower(), img.get('index'))].append(f)
print('\natlas cells used (sheet,index): %d distinct' % len(cells))
for k in sorted(cells):
    print('  ', k, cells[k])
