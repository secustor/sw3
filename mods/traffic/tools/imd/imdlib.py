"""Full IMD reader returning raw records for statistics. Read-only."""
import struct
def u(fmt,d,o): return struct.unpack_from(fmt,d,o)
def parse(path):
    d=open(path,'rb').read()
    assert d[:4]==b'LIBF' and d[8:12]==b'IDFM'
    r={'path':path,'size':len(d),'libf_size':u('<I',d,4)[0],'top':[],'gmat':[],'gvtx':[],'gnin':None,'gbnd':None,'gelp':None,'gref':None,'inner':[]}
    o=12
    while o<len(d):
        tag=d[o:o+4]; s,=u('<I',d,o+4); r['top'].append((tag.decode('latin1'),s))
        if tag==b'GNFO':
            r['gnfo_raw']=d[o+8:o+48]
            r['gnfo_ver'],=u('<I',d,o+8); r['gnfo_zeros']=u('<6I',d,o+12); r['gnfo_f'],=u('<f',d,o+36)
            r['n_gvtx'],r['n_gmat']=u('<II',d,o+40)
            p=o+48
            while p<o+s:
                t=d[p:p+4]; cs,=u('<I',d,p+4); r['inner'].append(t.decode('latin1'))
                b=d[p:p+cs]
                if t==b'GMAT': r['gmat'].append(gmat(b))
                elif t==b'GVTX': r['gvtx'].append(gvtx(b))
                elif t==b'GNIN':
                    ver,n=u('<II',b,8); r['gnin']=dict(ver=ver,n=n,ok=(16+12*n==cs))
                elif t==b'GBND':
                    ver,=u('<I',b,8); main=u('<4f',b,12); n,=u('<I',b,28)
                    sph=[u('<4f',b,32+16*i) for i in range(n)]
                    r['gbnd']=dict(ver=ver,main=main,sph=sph,ok=(32+16*n==cs))
                elif t==b'GELP':
                    r['gelp']=dict(ver=u('<I',b,8)[0],v=u('<6f',b,12),ok=(cs==36))
                p+=cs
        elif tag==b'GREF': r['gref']=gref(d[o:o+s])
        o+=s
    return r
def gmat(b):
    ver,nl=u('<II',b,8); raw=b[16:16+nl]; p=16+nl
    f=u('<19f',b,p); p+=76; nt,=u('<I',b,p); p+=4; tex=[]
    for i in range(nt):
        tid,l=u('<iI',b,p); p+=8; traw=b[p:p+l]; p+=l; amt,=u('<f',b,p); amt_raw=b[p:p+4]; p+=4
        tex.append(dict(id=tid,len=l,raw=traw,name=traw.split(b'\0')[0],amt=amt,amt_raw=amt_raw))
    return dict(ver=ver,nl=nl,raw=raw,name=raw.split(b'\0')[0],f=f,tex=tex,ok=(p==len(b)))
def gvtx(b):
    ver,mat,area,V,F=u('<IIfII',b,8); p=28
    verts=[u('<5f',b,p+20*i) for i in range(V)]; p+=20*V
    faces=[u('<3H',b,p+6*i) for i in range(F)]; p+=6*F
    vn=[u('<3f',b,p+12*i) for i in range(V)]; p+=12*V
    fn=[u('<3f',b,p+12*i) for i in range(F)]; p+=12*F
    return dict(ver=ver,mat=mat,area=area,V=V,F=F,verts=verts,faces=faces,vn=vn,fn=fn,ok=(p==len(b)))
def gref(b):
    ver,n=u('<II',b,8); p=16; refs=[]
    for i in range(n):
        l,=u('<I',b,p); p+=4; raw=b[p:p+l]; p+=l
        m=u('<16f',b,p); p+=64; sc=u('<3f',b,p); p+=12; c=b[p:p+4]; p+=4
        refs.append(dict(len=l,raw=raw,name=raw.split(b'\0')[0],m=m,sc=sc,c=c))
    return dict(ver=ver,n=n,refs=refs,ok=(p==len(b)))
