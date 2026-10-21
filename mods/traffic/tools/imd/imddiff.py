"""Semantic diff of two IMD files, chunk by chunk, with float tolerances.
Usage: python3 -I imddiff.py original.IMD exported.IMD [--tol 1e-4]
Materials are matched by name (Blender '.NNN' suffix ignored), submeshes by position, refpoints by name+position order."""
import sys, os, re, math, struct, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import imdlib
TOL=float(sys.argv[sys.argv.index('--tol')+1]) if '--tol' in sys.argv else 1e-4
A=imdlib.parse(sys.argv[1]); B=imdlib.parse(sys.argv[2])
out=collections.defaultdict(list)
def note(k,msg): out[k].append(msg)
def fd(x,y): return max((abs(a-b) for a,b in zip(x,y)),default=0.0)
da=open(sys.argv[1],'rb').read(); db=open(sys.argv[2],'rb').read()
print('bytes', len(da), len(db), 'identical' if da==db else 'differ')
if A['gnfo_raw']!=B['gnfo_raw']: note('GNFO header', f"{A['gnfo_raw'].hex()} != {B['gnfo_raw'].hex()}")
ta=[t for t,_ in A['top']]; tb=[t for t,_ in B['top']]
if ta!=tb: note('top-level order',f'{ta} != {tb}')
ia=re.sub(r'(GVTX)+','GVTX*',re.sub(r'(GMAT)+','GMAT*',''.join(A['inner']))); ib=re.sub(r'(GVTX)+','GVTX*',re.sub(r'(GMAT)+','GMAT*',''.join(B['inner'])))
if ia!=ib: note('GNFO chunk order',f'{ia} != {ib}')
strip=lambda n: re.sub(rb'\.\d{3}$',b'',n)
# materials as used by submeshes
def used(r): return [r['gmat'][g['mat']] if g['mat']<len(r['gmat']) else None for g in r['gvtx']]
if len(A['gmat'])!=len(B['gmat']): note('GMAT count',f"{len(A['gmat'])} -> {len(B['gmat'])}")
for i,(ma,mb) in enumerate(zip(used(A),used(B))):
    if ma is None or mb is None: note('GMAT ref','submesh %d material index out of range'%i); continue
    if ma['name']!=mb['name']: note('GMAT name', f"sub{i}: {ma['name']!r} -> {mb['name']!r}" + (' (Blender suffix)' if strip(mb['name'])==ma['name'] else ''))
    if ma['nl']!=mb['nl'] and ma['name']==mb['name']: note('GMAT name padding', f"sub{i}: len {ma['nl']} -> {mb['nl']}")
    wa=struct.pack('<2f',*ma['f'][:2]); wb=struct.pack('<2f',*mb['f'][:2])
    if wa!=wb: note('GMAT flag words (u32 x2)', f"sub{i}: {struct.unpack('<2I',wa)} -> {struct.unpack('<2I',wb)}")
    names=['diffuse','ambient','specular','emissive']
    for k in range(4):
        x=ma['f'][2+4*k:6+4*k]; y=mb['f'][2+4*k:6+4*k]
        if fd(x,y)>TOL: note('GMAT '+names[k]+' RGBA', f"sub{i}: {[round(v,4) for v in x]} -> {[round(v,4) for v in y]}")
        elif x!=y: note('GMAT float rounding','sub%d %s max %.2e'%(i,names[k],fd(x,y)))
    if abs(ma['f'][18]-mb['f'][18])>TOL: note('GMAT power', f"sub{i}: {ma['f'][18]} -> {mb['f'][18]}")
    elif ma['f'][18]!=mb['f'][18]: note('GMAT float rounding','sub%d power %r -> %r'%(i,ma['f'][18],mb['f'][18]))
    tx=[(t['id'],t['name'].lower(),round(t['amt'],4)) for t in ma['tex']]; ty=[(t['id'],t['name'].lower(),round(t['amt'],4)) for t in mb['tex']]
    if tx!=ty: note('GMAT textures', f"sub{i}: {tx} -> {ty}")
    if [t['len'] for t in ma['tex']]!=[t['len'] for t in mb['tex']] and [t['name'] for t in ma['tex']]==[t['name'] for t in mb['tex']]: note('GMAT texture name padding',f'sub{i}')
if len(A['gvtx'])!=len(B['gvtx']): note('GVTX count',f"{len(A['gvtx'])} -> {len(B['gvtx'])}")
for i,(ga,gb) in enumerate(zip(A['gvtx'],B['gvtx'])):
    if (ga['V'],ga['F'])!=(gb['V'],gb['F']): note('GVTX V/F', f"sub{i}: {ga['V']},{ga['F']} -> {gb['V']},{gb['F']}"); continue
    if abs(ga['area']-gb['area'])>1e-3*max(1,ga['area']): note('GVTX area field', f"sub{i}: {ga['area']:.4f} -> {gb['area']:.4f}")
    if ga['faces']!=gb['faces']: note('GVTX faces', f"sub{i}: index lists differ")
    p=max(fd(a[:3],b[:3]) for a,b in zip(ga['verts'],gb['verts'])) if ga['V'] else 0
    if p>TOL: note('GVTX positions',f'sub{i}: max {p:.2e}')
    uv=max(fd(a[3:],b[3:]) for a,b in zip(ga['verts'],gb['verts'])) if ga['V'] else 0
    if uv>TOL: note('GVTX uv',f'sub{i}: max {uv:.2e}')
    elif uv>0: note('GVTX uv rounding',f'sub{i}: max {uv:.2e}')
    vn=max(fd(a,b) for a,b in zip(ga['vn'],gb['vn'])) if ga['V'] else 0
    if vn>1e-3: note('GVTX vertex normals',f'sub{i}: max {vn:.2e}')
    fn=max(fd(a,b) for a,b in zip(ga['fn'],gb['fn'])) if ga['F'] else 0
    if fn>1e-3: note('GVTX face normals',f'sub{i}: max {fn:.2e}')
ba,bb=A['gbnd'],B['gbnd']
if (ba is None)!=(bb is None): note('GBND presence',f'{ba is not None} -> {bb is not None}')
elif ba:
    if fd(ba['main'],bb['main'])>TOL: note('GBND main sphere',f"{[round(v,4) for v in ba['main']]} -> {[round(v,4) for v in bb['main']]}")
    if len(ba['sph'])!=len(bb['sph']): note('GBND sphere count',f"{len(ba['sph'])} -> {len(bb['sph'])}")
    elif sorted(ba['sph'])!=sorted(bb['sph']) and max(fd(x,y) for x,y in zip(sorted(ba['sph']),sorted(bb['sph'])))>TOL: note('GBND spheres','set differs')
    elif ba['sph']!=bb['sph']: note('GBND sphere order','same set, other order')
ea,eb=A['gelp'],B['gelp']
if (ea is None)!=(eb is None): note('GELP presence',f'{ea is not None} -> {eb is not None}')
elif ea and fd(ea['v'],eb['v'])>TOL: note('GELP',f"{ea['v']} -> {eb['v']}")
gin=(A['gnin'] is not None, B['gnin'] is not None)
if gin[0]!=gin[1]: note('GNIN presence',f'{gin[0]} -> {gin[1]}')
ra=A['gref']['refs'] if A['gref'] else []; rb=B['gref']['refs'] if B['gref'] else []
if len(ra)!=len(rb): note('GREF count',f'{len(ra)} -> {len(rb)}')
for i,(x,y) in enumerate(zip(ra,rb)):
    if x['name']!=y['name']: note('GREF name',f"#{i}: {x['name']!r} -> {y['name']!r}")
    elif x['len']!=y['len']: note('GREF name padding',f'#{i}')
    if fd(x['m'][:12],y['m'][:12])>TOL: note('GREF rotation',f"#{i} {x['name'][:30]!r}: max {fd(x['m'][:12],y['m'][:12]):.2e}")
    elif x['m'][:12]!=y['m'][:12]: note('GREF rotation rounding',f"#{i} max {fd(x['m'][:12],y['m'][:12]):.2e}")
    if fd(x['m'][12:15],y['m'][12:15])>TOL: note('GREF position',f'#{i}')
    if x['m'][15]!=y['m'][15]: note('GREF position w (m[15])',f"#{i}: {x['m'][15]} -> {y['m'][15]}")
    if fd(x['sc'],y['sc'])>TOL: note('GREF scale',f'#{i}')
    if x['c'][:3]!=y['c'][:3]: note('GREF colour BGR',f"#{i}: {x['c'][:3].hex()} -> {y['c'][:3].hex()}")
    if x['c'][3]!=y['c'][3]: note('GREF 4th colour byte (alpha)',f"#{i}: {x['c'][3]} -> {y['c'][3]}")
for k in sorted(out):
    v=out[k]; print(f'{k}: {len(v)}'); [print('   ',m) for m in v[:4]]
if not out: print('no semantic differences')
