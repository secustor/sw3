"""SW3 .tuv (texture UV atlas) reader/writer.

Format as read by the engine's LoadTUV (sw3cw.exe 0x423350):
  line 1 : first token (sscanf "%49s", 0x71840c) is TUVTXT (0x7183dc) or TUVBIN (0x7183d4)
  TUVTXT :
    "TUVCOUNT %i"       (0x718414)  sscanf must return 1
    "TUVBASE %f %f"     (0x718420)  sscanf must return 2  -> W H (pixels)
    count x "%f %f %f %f" (0x718430) sscanf must return 4 -> x0 y0 x1 y1 (pixels)
    Each rect is stored as 4 corners in a 32-byte record (0x422e50):
      (x0/W, y0/H) (x1/W, y0/H) (x0/W, y1/H) (x1/W, y1/H)
  TUVBIN : int32 count, then count 32-byte records of 8 float32 (same corner layout).
           No vanilla file uses TUVBIN; the read position after the first line is UNVERIFIED.

Usage:
  python3 -I tuv.py dump  <file.tuv>
  python3 -I tuv.py survey <Data dir>          # parse all .tuv files, check against companion .dds
  python3 -I tuv.py write <out.tuv> W H x0,y0,x1,y1 [...]
  python3 -I tuv.py grid <out.tuv> W H cw ch n # n cells of cw x ch, row-major, like ships.tuv
"""
import os
import struct
import sys


class TUV:
    def __init__(self, base, rects, kind='TUVTXT'):
        self.base = base          # (W, H)
        self.rects = rects        # [(x0, y0, x1, y1)] in pixels
        self.kind = kind

    def uv(self, i):
        W, H = self.base
        x0, y0, x1, y1 = self.rects[i]
        return [(x0 / W, y0 / H), (x1 / W, y0 / H), (x0 / W, y1 / H), (x1 / W, y1 / H)]


def parse(data):
    """Parse bytes; mimics the engine: strict line order, each line must scan fully."""
    if data[:6] == b'TUVBIN':
        # UNVERIFIED layout: assume count follows the first line.
        nl = data.index(b'\n') + 1
        (n,) = struct.unpack_from('<i', data, nl)
        recs = []
        for i in range(n):
            f = struct.unpack_from('<8f', data, nl + 4 + 32 * i)
            recs.append((f[0], f[1], f[2], f[5]))  # normalized u0 v0 u1 v1
        return TUV((1.0, 1.0), recs, 'TUVBIN')
    lines = data.decode('latin-1').splitlines()
    it = iter(lines)
    head = next(it).split()
    if not head or head[0] != 'TUVTXT':
        raise ValueError('first token %r is not TUVTXT/TUVBIN' % (head[:1],))
    l = next(it).split()
    if len(l) < 2 or l[0] != 'TUVCOUNT':
        raise ValueError('line 2 is not TUVCOUNT: %r' % l)
    n = int(l[1])
    l = next(it).split()
    if len(l) < 3 or l[0] != 'TUVBASE':
        raise ValueError('line 3 is not TUVBASE: %r' % l)
    W, H = float(l[1]), float(l[2])
    rects = []
    for i in range(n):
        l = next(it, None)
        if l is None:
            raise ValueError('only %d of %d rect lines' % (i, n))
        t = l.split()
        if len(t) < 4:
            raise ValueError('rect line %d has %d numbers: %r' % (i, len(t), l))
        rects.append(tuple(float(x) for x in t[:4]))
    return TUV((W, H), rects)


def dump_text(t):
    out = ['TUVTXT', 'TUVCOUNT %d' % len(t.rects), 'TUVBASE %g %g' % t.base]
    for r in t.rects:
        out.append('%.2f %.2f %.2f %.2f' % r)
    return ('\r\n'.join(out) + '\r\n').encode('ascii')


def dds_info(path):
    d = open(path, 'rb').read(128)
    if d[:4] != b'DDS ':
        return None
    h, w = struct.unpack_from('<II', d, 12)
    mips = struct.unpack_from('<I', d, 28)[0]
    pf_flags = struct.unpack_from('<I', d, 80)[0]
    fourcc = d[84:88]
    bits = struct.unpack_from('<I', d, 88)[0]
    fmt = fourcc.decode('latin-1') if pf_flags & 4 else 'RGB%d%s' % (bits, 'A' if pf_flags & 1 else '')
    return w, h, mips, fmt


def survey(G):
    tuvs = []
    for root, _, files in os.walk(G):
        for f in files:
            if f.lower().endswith('.tuv'):
                tuvs.append(os.path.join(root, f))
    tuvs.sort()
    print('tuv files:', len(tuvs))
    bad = 0
    for p in tuvs:
        raw = open(p, 'rb').read()
        rel = os.path.relpath(p, G)
        try:
            t = parse(raw)
        except Exception as e:
            print('PARSE-FAIL', rel, e)
            bad += 1
            continue
        W, H = t.base
        extra = len(raw.decode('latin-1').strip().splitlines()) - 3 - len(t.rects)
        oob = [i for i, (x0, y0, x1, y1) in enumerate(t.rects) if x0 < 0 or y0 < 0 or x1 > W or y1 > H or x1 < x0 or y1 < y0]
        crlf = b'\r\n' in raw
        ints = all(float(v).is_integer() for r in t.rects for v in r)
        dds = os.path.splitext(p)[0] + '.dds'
        di = dds_info(dds) if os.path.exists(dds) else None
        dm = ''
        if di:
            dm = 'dds %dx%d %s mips=%d %s' % (di[0], di[1], di[3], di[2], 'base==dds' if (di[0], di[1]) == (W, H) else 'BASE!=DDS')
        else:
            dm = 'no same-name .dds'
        print('%-52s n=%3d base=%gx%g %s%s%s%s | %s' % (
            rel, len(t.rects), W, H, 'CRLF' if crlf else 'LF', '' if ints else ' fractional',
            ' extra-lines=%d' % extra if extra else '', ' OOB=%s' % oob if oob else '', dm))
    print('parse failures:', bad)


def main():
    cmd = sys.argv[1]
    if cmd == 'dump':
        t = parse(open(sys.argv[2], 'rb').read())
        print(t.kind, 'base', t.base, 'count', len(t.rects))
        for i, r in enumerate(t.rects):
            print(i, r, 'size %gx%g' % (r[2] - r[0], r[3] - r[1]), 'uv', [tuple(round(c, 4) for c in p) for p in t.uv(i)])
    elif cmd == 'survey':
        survey(sys.argv[2])
    elif cmd == 'write':
        W, H = float(sys.argv[3]), float(sys.argv[4])
        rects = [tuple(float(v) for v in a.split(',')) for a in sys.argv[5:]]
        open(sys.argv[2], 'wb').write(dump_text(TUV((W, H), rects)))
    elif cmd == 'grid':
        W, H, cw, ch, n = (int(x) for x in sys.argv[3:8])
        cols = W // cw
        rects = [((i % cols) * cw, (i // cols) * ch, (i % cols + 1) * cw, (i // cols + 1) * ch) for i in range(n)]
        open(sys.argv[2], 'wb').write(dump_text(TUV((W, H), rects)))
    else:
        raise SystemExit(__doc__)


if __name__ == '__main__':
    main()
