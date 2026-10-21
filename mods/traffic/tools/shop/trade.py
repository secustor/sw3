# Parse STREAMID_TradeSystem body (empirical grammar). Usage: trade.py <save> [shopname]
import sys, struct, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sections import body_of, sections
class Rd:
    def __init__(s,b,p=0): s.b=b; s.p=p
    def u(s): v=struct.unpack_from('<I',s.b,s.p)[0]; s.p+=4; return v
    def f(s): v=struct.unpack_from('<f',s.b,s.p)[0]; s.p+=4; return v
    def s(s_): n=s_.u(); assert n<0x7fff, n; v=s_.b[s_.p:s_.p+n]; s_.p+=n; return v
def market(r):
    m=dict(id=r.u(), k1=r.f(), k2=r.f(), rows=[])
    for _ in range(r.u()):
        m['rows'].append(dict(name=r.s(), kind=r.u(), n=r.u(), b=r.f(), s=r.f(), kind2=r.u(), cur=r.u(), cb=r.f(), cs=r.f()))
    return m
def parse(sec):
    r=Rd(sec); shops=[]
    for _ in range(r.u()):
        shops.append(dict(name=r.s(), white=market(r), black=market(r)))
    return shops, r.p
def trade_section(path):
    h,body=body_of(path); s=sections(body)
    i=[x[0] for x in s].index('STREAMID_TradeSystem')
    return body, s[i][2], s[i+1][1]
if __name__=='__main__':
    body,a,e=trade_section(sys.argv[1]); shops,p=parse(body[a:e])
    print(f'shops={len(shops)} parsed_end={p} section_len={e-a} tail={body[a+p:e].hex(" ")[:200]}')
    if len(sys.argv)>2:
        for sh in shops:
            if sh['name'].decode()==sys.argv[2]:
                for k in ('white','black'):
                    m=sh[k]; print(k, m['id'], m['k1'], m['k2'], len(m['rows']))
                    for row in m['rows']:
                        if row['kind']==1 or len(sys.argv)>3: print('   ',row)
