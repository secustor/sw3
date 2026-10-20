# Enumerate every lua_setglobal (0x65e5a0) call site and classify the pushed value
import re,sys,struct,json
EXE="/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/sw3cw.exe"
f=open(EXE,"rb").read()
def cstr(va):
    off=va-0x400000
    if off<0x2fc000 or off>=len(f): return None
    e=f.index(b"\0",off); return f[off:e].decode("latin1")
def dbl(va): return struct.unpack_from("<d",f,va-0x400000)[0]
r=re.compile(r"^\s+([0-9a-f]+):\s+\t(\S+)\s*(.*)$")
ins=[]
for l in open(sys.argv[1]):
    m=r.match(l)
    if m: ins.append((int(m.group(1),16),m.group(2),m.group(3).split(" <")[0].split("  ")[0].strip().split("#")[0].strip()))
N={"0x65e280":"pushstring","0x65e2c0":"pushcclosure","0x65e200":"pushnumber","0x65e560":"newtable","0x65e5a0":"setglobal"}
out=[]
for i,(a,op,arg) in enumerate(ins):
    if not(op=="calll" and arg=="0x65e5a0"): continue
    # name: last push before call (arg2) -> immediate or register loaded by movl $imm
    pushes=[j for j in range(i-1,max(i-8,0),-1) if ins[j][1]=="pushl"]
    name=None
    if len(pushes)>1:
        p=ins[pushes[1]][2]
        if p.startswith("$0x"): name=cstr(int(p[1:],16))
        elif p.startswith("%"):
            for j in range(pushes[1]-1,max(pushes[1]-40,0),-1):
                if ins[j][1]=="movl" and ins[j][2].endswith(", "+p) and ins[j][2].startswith("$0x"):
                    name=cstr(int(ins[j][2].split(",")[0][1:],16));break
    # value: previous lua push call
    val=None;kind=None
    for j in range(i-1,max(i-25,0),-1):
        if ins[j][1]=="calll" and ins[j][2] in N and ins[j][2]!="0x65e5a0":
            kind=N[ins[j][2]]
            if kind=="pushnumber":
                for q in range(j-1,max(j-10,0),-1):
                    if ins[q][1] in("fldl","flds") and ins[q][2].startswith("0x"):
                        val=dbl(int(ins[q][2],16)) if ins[q][1]=="fldl" else struct.unpack_from("<f",f,int(ins[q][2],16)-0x400000)[0];break
                    if ins[q][1] in("fld1",): val=1.0;break
                    if ins[q][1] in("fldz",): val=0.0;break
            if kind=="pushcclosure":
                for q in range(j-1,max(j-6,0),-1):
                    if ins[q][1]=="pushl" and ins[q][2].startswith("$0x") and ins[q][2]!="$0x0":
                        val=hex(int(ins[q][2][1:],16));break
            if kind=="pushstring":
                for q in range(j-1,max(j-6,0),-1):
                    if ins[q][1]=="pushl" and ins[q][2].startswith("$0x"):
                        val=cstr(int(ins[q][2][1:],16));break
            break
    out.append(dict(site=hex(a),name=name,kind=kind,val=val))
json.dump(out,open(sys.argv[2],"w"),indent=0)
import collections
print(collections.Counter(o["kind"] for o in out))
