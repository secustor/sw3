# Usage: python3 -I npc_natives_extract.py <sw3cw.exe> <exe.asm>  -> "builder_fn kind name handler" per Lua native registration.
# kind G = lua_setglobal (0x65e5a0), M = method-table entry (lua_pushstring 0x65e280 + lua_pushcclosure 0x65e2c0 + lua_settable 0x65e5d0).
import re,sys,struct
exe=open(sys.argv[1],'rb').read()
def s(va):
    if 0x6fc000<=va<0x79b000: o=va-0x6fc000+0x2fc000
    elif 0x79b000<=va<0x7bf000: o=va-0x79b000+0x39b000
    else: return None
    e=exe.find(b'\0',o); b=exe[o:e]
    if not b or len(b)>60 or not re.fullmatch(rb'[A-Za-z_][A-Za-z0-9_]*',b): return None
    return b.decode()
line_re=re.compile(r'^\s*([0-9a-f]+):\s+(\S+)\s*(.*)$')
imms=[]; pend=None; pendname=None; func=None; prev_int3=True
res=[]
for ln in open(sys.argv[2]):
    m=line_re.match(ln)
    if not m: continue
    a,op,args=m.groups()
    if op=='int3': prev_int3=True; continue
    if prev_int3: func=a; prev_int3=False
    mm=re.search(r'\$0x([0-9a-f]+)',args)
    if op in('pushl','movl') and mm: imms.append(int(mm.group(1),16)); imms=imms[-8:]
    if op=='calll':
        t=args.split()[0]
        if t=='0x65e280':
            pendname=s(imms[-1]) if imms else None
        elif t=='0x65e2c0':
            pend=imms[-1] if imms else None
            if pendname: res.append((func,'M',pendname,pend)); pendname=None
        elif t=='0x65e5a0':
            n=s(imms[-1]) if imms else None
            if n and pend: res.append((func,'G',n,pend))
            pend=None
for r in res: print(r[0],r[1],r[2],hex(r[3]) if r[3] else None)
