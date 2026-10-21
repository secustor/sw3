"""Copy an IMD and replace texture file names in its GMAT chunks; chunk sizes are recomputed.
Usage: python3 -I imd_retexture.py in.IMD out.IMD old.dds=new.dds [...]"""
import struct, sys
def pad4(b): return b + b'\0'*((-len(b)) % 4) if len(b)%4 else b
def rebuild_gmat(c, repl):
    nl,=struct.unpack_from('<I',c,12); p=16+nl+8+64+4
    ntex,=struct.unpack_from('<I',c,p); p+=4
    out=bytearray(c[:p])
    for _ in range(ntex):
        slot,l=struct.unpack_from('<II',c,p); name=c[p+8:p+8+l]; amt=c[p+8+l:p+12+l]; p+=12+l
        s=name.split(b'\0')[0].decode('latin1'); s=repl.get(s.lower(), s)
        nb=s.encode('latin1')+b'\0'; nb=nb+b'\0'*((-len(nb))%4) if s.encode('latin1')+b'\0'!=name else name
        out+=struct.pack('<II',slot,len(nb))+nb+amt
    assert p==len(c)
    struct.pack_into('<I',out,4,len(out)); return bytes(out)
def main():
    src,dst=sys.argv[1],sys.argv[2]
    repl={a.split('=')[0].lower():a.split('=')[1] for a in sys.argv[3:]}
    d=open(src,'rb').read(); o=12; top=[]
    while o<len(d):
        tag=d[o:o+4]; s,=struct.unpack_from('<I',d,o+4); top.append((tag,d[o:o+s])); o+=s
    out=bytearray(d[:12])
    for tag,c in top:
        if tag==b'GNFO':
            body=bytearray(c[:48]); p=48
            while p<len(c):
                t=c[p:p+4]; s,=struct.unpack_from('<I',c,p+4); ch=c[p:p+s]
                body+=rebuild_gmat(ch,repl) if t==b'GMAT' else ch; p+=s
            struct.pack_into('<I',body,4,len(body)); out+=body
        else: out+=c
    struct.pack_into('<I',out,4,len(out)); open(dst,'wb').write(out)
main()
