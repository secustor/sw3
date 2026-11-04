"""In-place fixes for an IMD written by the SW3SE Blender exporter (all patches keep every size unchanged).
Usage: python3 -I imd_fixup.py in.IMD out.IMD [--transpose-rot] [--second-tex-id N]
  always : GREF position w (m[15]) -> 1.0, GREF 4th colour byte -> 0xFF, GVTX area field -> summed triangle area (only when off by >1%),
           GMAT diffuse alpha -> 1.0 when it is 0 (Emission Strength left at 0 in Blender)
  --transpose-rot     : write the transpose of each GREF 3x3 (use when empties were rotated by eye in Blender)
  --second-tex-id N   : a material with two texture entries of the same file gets id N on the second (vanilla: 9 hull, 5 lit)"""
import sys, struct, math
src,dst=sys.argv[1],sys.argv[2]; tr='--transpose-rot' in sys.argv
sid=int(sys.argv[sys.argv.index('--second-tex-id')+1]) if '--second-tex-id' in sys.argv else None
d=bytearray(open(src,'rb').read()); log=[]
def u(f,o): return struct.unpack_from(f,d,o)
o=12
while o<len(d):
    tag=bytes(d[o:o+4]); s,=u('<I',o+4)
    if tag==b'GNFO':
        p=o+48
        while p<o+s:
            t=bytes(d[p:p+4]); cs,=u('<I',p+4)
            if t==b'GMAT':
                nl,=u('<I',p+12); q=p+16+nl+8            # after the two flag words
                if u('<f',q+12)[0]==0.0: struct.pack_into('<f',d,q+12,1.0); log.append('GMAT diffuse alpha 0 -> 1')
                q+=16*4+4; nt,=u('<I',q); q+=4; ents=[]
                for i in range(nt):
                    tid,l=u('<iI',q); ents.append((q,bytes(d[q+8:q+8+l]).split(b'\0')[0])); q+=12+l
                if sid and len(ents)==2 and ents[0][1].lower()==ents[1][1].lower() and u('<i',ents[1][0])[0]==1:
                    struct.pack_into('<i',d,ents[1][0],sid); log.append(f'GMAT second texture id -> {sid}')
            elif t==b'GVTX':
                V,F=u('<II',p+20); vb=p+28; fb=vb+20*V; A=0.0
                for k in range(F):
                    a,b,c=u('<3H',fb+6*k); P=[u('<3f',vb+20*i) for i in (a,b,c)]
                    e1=[P[1][j]-P[0][j] for j in range(3)]; e2=[P[2][j]-P[0][j] for j in range(3)]
                    cr=(e1[1]*e2[2]-e1[2]*e2[1],e1[2]*e2[0]-e1[0]*e2[2],e1[0]*e2[1]-e1[1]*e2[0]); A+=math.sqrt(sum(x*x for x in cr))/2
                old,=u('<f',p+16)
                if abs(old-A)>0.01*max(A,1e-9): struct.pack_into('<f',d,p+16,A); log.append(f'GVTX area {old:.4f} -> {A:.4f}')
            p+=cs
    elif tag==b'GREF':
        n,=u('<I',o+12); p=o+16
        for i in range(n):
            l,=u('<I',p); p+=4+l; m=list(u('<16f',p))
            if tr:
                R=[[m[4*r+c] for c in range(3)] for r in range(3)]
                for r in range(3):
                    for c in range(3): m[4*r+c]=R[c][r]
            m[3]=m[7]=m[11]=0.0; m[15]=1.0
            struct.pack_into('<16f',d,p,*m); p+=64+12; d[p+3]=0xFF; p+=4
        log.append(f'GREF {n} refs: w=1.0, alpha=0xFF' + (', rotation transposed' if tr else ''))
    o+=s
open(dst,'wb').write(d); print('\n'.join(sorted(set(log))))
