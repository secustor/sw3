# Extract Lua C function registrations from objdump output of sw3cw.exe
import re,sys,json
EXE="/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/sw3cw.exe"
f=open(EXE,"rb").read()
def cstr(va):
    off=va-0x400000
    if off<0x2fc000 or off>=len(f): return None
    e=f.index(b"\0",off); return f[off:e].decode("latin1")
r=re.compile(r"^\s+([0-9a-f]+):\s+\t(\S+)\s*(.*)$")
ins=[]
for l in open(sys.argv[1]):
    m=r.match(l)
    if m: ins.append((int(m.group(1),16),m.group(2),m.group(3).split(" <")[0].split("  ")[0].strip()))
# function starts: first non-int3 after int3/ret/jmp padding
fstart=[];cur=None;prev="int3"
for i,(a,op,arg) in enumerate(ins):
    if prev in("int3","nop") and op not in("int3","nop"): cur=a
    fstart.append(cur); prev=op
def imm(arg):
    if arg.startswith("$0x"): return int(arg[1:].split()[0],16)
    if arg.startswith("$-"): return -int(arg[2:].split()[0],16) if arg[2:].startswith("0x") else -int(arg[2:])
    return None
PUSHS="0x65e280";PUSHC="0x65e2c0";SETG="0x65e5a0";SETT="0x65e5d0";STM="0x65ed10"
res=[]
for i,(a,op,arg) in enumerate(ins):
    if op=="calll" and arg==PUSHC:
        fn=None
        for j in range(i-1,max(i-6,0),-1):
            if ins[j][1]=="pushl":
                v=imm(ins[j][2])
                if v: fn=v;break
        kind=None;name=None
        for k in range(i+1,min(i+14,len(ins))):
            if ins[k][1]=="calll":
                t=ins[k][2]
                if t==SETG:
                    kind="global"
                    for j in range(k-1,k-5,-1):
                        if ins[j][1]=="pushl" and imm(ins[j][2]): name=cstr(imm(ins[j][2]));break
                elif t==SETT:
                    kind="field"
                    for j in range(i-1,max(i-12,0),-1):
                        if ins[j][1]=="calll" and ins[j][2]==PUSHS:
                            for q in range(j-1,j-5,-1):
                                if ins[q][1]=="pushl" and imm(ins[q][2]): name=cstr(imm(ins[q][2]));break
                            break
                elif t==STM:
                    kind="tagmethod"
                    for j in range(k-1,k-5,-1):
                        if ins[j][1]=="pushl" and imm(ins[j][2]): name=cstr(imm(ins[j][2]));break
                else: kind="call "+t
                break
        res.append(dict(site=a,func=fstart[i],fn=fn,kind=kind,name=name))
json.dump(res,open(sys.argv[2],"w"),indent=0)
