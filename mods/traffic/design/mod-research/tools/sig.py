# Static per-native summary: arg indices read via lua_* API with immediate index, return pushes
import re,sys,json,bisect
r=re.compile(r"^\s+([0-9a-f]+):\s+\t(\S+)\s*(.*)$")
ins=[];idx={}
for l in open(sys.argv[1]):
    m=r.match(l)
    if m:
        a=int(m.group(1),16)
        if 0x5c0000<=a<0x5f0000 or 0x468000<=a<0x469000:
            idx[a]=len(ins); ins.append((a,m.group(2),m.group(3).split(" <")[0].split("#")[0].strip()))
rows=json.load(open(sys.argv[2]))
API={"0x65e0c0":"num","0x65e100":"str","0x65e020":"isnum","0x65e050":"isstr","0x65dfa0":"type","0x65e3a0":"gettable","0x65e1a0":"udata","0x65e180":"cfunc","0x65dfe0":"iscf"}
RET={"0x65e200":"number","0x65e280":"string","0x65e1d0":"nil","0x65e2d0":"usertag","0x65e560":"table"}
def summ(fn):
    i=idx.get(fn)
    if i is None: return None
    args={};rets=set();gettop=False;n=0;calls=set()
    while i<len(ins) and n<3000:
        a,op,arg=ins[i]
        if op=="calll":
            if arg=="0x65de50": gettop=True
            if arg in API:
                # index = second-to-last push (first pushed arg after L)
                pj=[j for j in range(i-1,max(i-6,0),-1) if ins[j][1]=="pushl"]
                if len(pj)>=2 and ins[pj[1]][2].startswith("$"):
                    try:
                        k=int(ins[pj[1]][2][1:],16) if "0x" in ins[pj[1]][2] else int(ins[pj[1]][2][1:])
                    except: k=None
                    if k and 0<k<12: args.setdefault(k,set()).add(API[arg])
            if arg in RET: rets.add(RET[arg])
            if arg.startswith("0x"): calls.add(arg)
        if op=="retl" and i+1<len(ins) and ins[i+1][1] in("int3","nop"): break
        i+=1;n+=1
    return dict(args={k:sorted(v) for k,v in sorted(args.items())},rets=sorted(rets),gettop=gettop,ninstr=n)
for row in rows:
    row['static']=summ(row['fn'])
json.dump(rows,open(sys.argv[3],"w"),indent=0)
