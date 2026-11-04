# Inflate a .sav and print section offsets/sizes; write each section to out dir. Read-only on input.
import sys, zlib, struct, re, os
def rs(b, p):
    n = struct.unpack_from('<I', b, p)[0]; return b[p+4:p+4+n], p+4+n
def body_of(path):
    b = open(path,'rb').read(); p = 0
    sig, p = rs(b,p); ver = struct.unpack_from('<I',b,p)[0]; p+=4
    name,p=rs(b,p); dt,p=rs(b,p); loc,p=rs(b,p)
    st, qs = struct.unpack_from('<II',b,p); p+=8
    tag,p=rs(b,p); cl,ul=struct.unpack_from('<II',b,p); p+=8
    body=zlib.decompress(b[p:p+cl]); assert len(body)==ul
    return dict(sig=sig,ver=ver,name=name,dt=dt,loc=loc,state=st,qs=qs,tag=tag,clen=cl,ulen=ul,hdr_end=p), body
def sections(body):
    out=[]
    for m in re.finditer(rb'\xab\xab\xab\xab(.{4})STREAMID_', body, re.S):
        n=struct.unpack('<I',m.group(1))[0]; nm=body[m.start()+8:m.start()+8+n]
        out.append((nm.decode(), m.start(), m.start()+8+n))
    return out
if __name__=='__main__':
    h,body=body_of(sys.argv[1]); print({k:v for k,v in h.items()})
    s=sections(body)
    for i,(nm,st,ds) in enumerate(s):
        end = s[i+1][1] if i+1<len(s) else len(body)
        print(f'{nm:28s} hdr@0x{st:06x} data@0x{ds:06x} len={end-ds}')
        if len(sys.argv)>2:
            os.makedirs(sys.argv[2],exist_ok=True); open(os.path.join(sys.argv[2],nm+'.bin'),'wb').write(body[ds:end])
