"""Parse SW3 IMD (LIBF/IDFM) files. Usage: python3 -I imdparse.py <file|dir> [-v]"""
import struct, sys, os, collections, math
def rd(fmt,d,o): return struct.unpack_from(fmt,d,o)
def cstr(b): return b.split(b'\0')[0].decode('latin1')
def parse_gmat(d,o,size):
    ver,nl=rd("<II",d,o+8); name=cstr(d[o+16:o+16+nl]); p=o+16+nl; flags=rd("<II",d,p); p+=8
    # 4 RGBA colours (ambient,diffuse,specular,emissive?) + 1 float
    cols=[rd('<4f',d,p+16*i) for i in range(4)]; p+=64
    power,=rd('<f',d,p); p+=4
    ntex,=rd('<I',d,p); p+=4
    tex=[]
    for i in range(ntex):
        slot,l=rd('<II',d,p); p+=8; n=cstr(d[p:p+l]); p+=l; amt,=rd('<f',d,p); p+=4
        tex.append((slot,n,amt))
    assert p==o+size,(hex(o),p-o,size)
    return dict(ver=ver,name=name,flags=flags,cols=cols,power=power,tex=tex)
def parse_gvtx(d,o,size):
    ver,mat,rad,V,F=rd('<IIfII',d,o+8)
    expect=28+V*20+F*6+V*12+F*12
    return dict(ver=ver,mat=mat,rad=rad,V=V,F=F,ok=(expect==size),expect=expect,size=size)
def parse_gref(d,o,size):
    ver,n=rd('<II',d,o+8); p=o+16; out=[]
    for i in range(n):
        l,=rd('<I',d,p); p+=4; name=cstr(d[p:p+l]); p+=l
        m=rd('<16f',d,p); p+=64; s=rd('<3f',d,p); p+=12; c=d[p:p+4]; p+=4
        out.append((name,m[12:15],s,c.hex()))
    return dict(ver=ver,n=n,refs=out,ok=(p==o+size))
def parse(path):
    d=open(path,'rb').read()
    assert d[:4]==b'LIBF' and d[8:12]==b'IDFM', d[:12]
    assert rd('<I',d,4)[0]==len(d)
    res={'chunks':[], 'gmat':[], 'gvtx':[], 'gref':None, 'top':[]}
    o=12
    while o<len(d):
        tag=d[o:o+4].decode('latin1'); size,=rd('<I',d,o+4); res['top'].append((tag,size))
        if tag=='GNFO':
            hdr=rd('<I6ffII',d,o+8); res['gnfo_hdr']=hdr
            p=o+8+40
            while p<o+size:
                t=d[p:p+4].decode('latin1'); s,=rd('<I',d,p+4); res['chunks'].append(t)
                if t=='GMAT': res['gmat'].append(parse_gmat(d,p,s))
                elif t=='GVTX': res['gvtx'].append(parse_gvtx(d,p,s))
                elif t=='GBND': res['gbnd']=rd('<I4fI',d,p+8)
                elif t=='GELP': res['gelp']=rd('<I6f',d,p+8)
                p+=s
            assert p==o+size
        elif tag=='GREF': res['gref']=parse_gref(d,o,size)
        o+=size
    return res
if __name__=='__main__':
    tgt=sys.argv[1]; verbose='-v' in sys.argv
    files=[os.path.join(tgt,f) for f in sorted(os.listdir(tgt)) if f.lower().endswith('.imd')] if os.path.isdir(tgt) else [tgt]
    stats=collections.Counter(); slots=collections.Counter(); top=collections.Counter(); refn=collections.Counter(); fails=[]; matpref=collections.Counter(); hdrs=collections.Counter()
    for f in files:
        try: r=parse(f)
        except Exception as e: fails.append((os.path.basename(f),repr(e))); continue
        top[tuple(t for t,_ in r['top'])]+=1
        stats[tuple(sorted(set(r['chunks'])))]+=1
        hdrs[(r['gnfo_hdr'][0], len(r['gmat'])==r['gnfo_hdr'][-2], len(r['gvtx'])==r['gnfo_hdr'][-1])]+=1
        for g in r['gvtx']:
            if not g['ok']: fails.append((os.path.basename(f),'gvtx size',g))
        for m in r['gmat']:
            matpref[m['name'].split('.')[0] if '.' in m['name'] else '(none)']+=1
            for s,n,a in m['tex']: slots[(s, n.lower().rsplit('.',1)[-1])]+=1
        if r['gref']:
            if not r['gref']['ok']: fails.append((os.path.basename(f),'gref'))
            for n,*_ in r['gref']['refs']: refn[n.split(':')[0]]+=1
        if verbose:
            print(os.path.basename(f), 'top',r['top'],'gnfo',r['gnfo_hdr'])
            for m in r['gmat']: print('  GMAT',m['name'],'power',round(m['power'],1),m['tex'])
            for g in r['gvtx']: print('  GVTX',g)
            print('  GBND',r.get('gbnd')); print('  GELP',r.get('gelp'))
            if r['gref']:
                for x in r['gref']['refs']: print('  GREF',x[0],[round(v,3) for v in x[1]])
    print('files',len(files),'fails',len(fails)); print(fails[:10])
    print('top layouts',top); print('GNFO chunk sets',stats); print('gnfo hdr check',hdrs)
    print('tex slots',slots); print('material name prefixes',matpref.most_common(20)); print('GREF prefixes',refn.most_common(60))
