# Prototype: add (or set) a ship row in station markets of a .sav copy. Never run on the only copy of a save.
# Usage: shopedit.py IN.sav OUT.sav SHIP N BUYK SELLK [--black] [--cur K] shop1 shop2 ... | --all-with-ships
import sys, struct, zlib, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sections import body_of, sections
from trade import parse
def w_str(b): return struct.pack('<I', len(b)) + b
def w_market(m):
    out = [struct.pack('<Iff I', m['id'], m['k1'], m['k2'], len(m['rows']))]
    for r in sorted(m['rows'], key=lambda r: r['name']):           # std::map order (byte order of lower-case names)
        out.append(w_str(r['name']) + struct.pack('<IIffIIff', r['kind'], r['n'], r['b'], r['s'], r['kind2'], r['cur'], r['cb'], r['cs']))
    return b''.join(out)
def w_trade(shops):
    return struct.pack('<I', len(shops)) + b''.join(w_str(s['name']) + w_market(s['white']) + w_market(s['black']) for s in shops)
def rebuild(path, new_trade):
    raw = open(path, 'rb').read(); h, body = body_of(path); s = sections(body)
    i = [x[0] for x in s].index('STREAMID_TradeSystem'); a, e = s[i][2], s[i+1][1]
    nb = body[:a] + new_trade + body[e:]
    z = zlib.compress(nb, 9)
    return raw[:h['hdr_end'] - 8] + struct.pack('<II', len(z), len(nb)) + z
def main(a):
    src, dst, ship, n, bk, sk = a[0], a[1], a[2].lower().encode(), int(a[3]), float(a[4]), float(a[5])
    rest = a[6:]; mk = 'white'; cur = n; shopsel = []
    while rest:
        x = rest.pop(0)
        if x == '--black': mk = 'black'
        elif x == '--cur': cur = int(rest.pop(0))
        else: shopsel.append(x.lower().encode())
    h, body = body_of(src); s = sections(body)
    i = [x[0] for x in s].index('STREAMID_TradeSystem'); shops, _ = parse(body[s[i][2]:s[i+1][1]])
    done = []
    for sh in shops:
        m = sh[mk]
        if shopsel == [b'--all-with-ships'] and not any(r['kind'] == 1 for r in m['rows']): continue
        if shopsel != [b'--all-with-ships'] and sh['name'] not in shopsel: continue
        m['rows'] = [r for r in m['rows'] if r['name'] != ship]
        m['rows'].append(dict(name=ship, kind=1, n=n, b=bk, s=sk, kind2=1, cur=cur, cb=bk, cs=sk))
        done.append(sh['name'].decode())
    out = rebuild(src, w_trade(shops))
    if os.path.abspath(dst) == os.path.abspath(src): sys.exit('refusing to overwrite the input')
    open(dst, 'wb').write(out)
    print(f'{mk} rows set for {ship.decode()} n={n} cur={cur} in {len(done)} shops: {" ".join(done)}')
if __name__ == '__main__': main(sys.argv[1:])
