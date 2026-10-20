# Build native list (from regs3.json) and count usage in shipped scripts
import json,re,os,sys,collections
r=json.load(open(sys.argv[1]))
ROOT="/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data"
files=[]
for d,_,fs in os.walk(ROOT+"/Scripts"):
    for x in fs:
        if x.endswith((".script",".xml",".lst",".txt")): files.append(os.path.join(d,x))
for d,_,fs in os.walk(ROOT+"/Game"):
    for x in fs:
        if x.endswith((".xml",".script")): files.append(os.path.join(d,x))
texts={}
for p in files:
    t=open(p,"rb").read().decode("cp1251","replace")
    # strip Lua comments
    t=re.sub(r"--[^\n]*","",t)
    texts[os.path.relpath(p,ROOT)]=t
EVT={0x5ca6b0:"_EVENT_INSIDEVOLUME",0x5cb200:"_EVENT_INSIDEOBJECTVOLUME",0x5cae90:"_EVENT_OBJECTDIED",0x5cb600:"_EVENT_TIMER",0x5cbd90:"_EVENT_GROUPRELATION",0x5cc210:"_EVENT_ATTACKCARCASS",0x5cca50:"_EVENT_SIDEINSIDEOBJECTVOLUME",0x5ccf20:"_EVENT_GROUPINSIDEOBJECTVOLUME",0x5cd670:"_EVENT_SIDEINSIDEVOLUME",0x5cdba0:"_EVENT_GROUPINSIDEVOLUME",0x5ce1d0:"_EVENT_GROUPINSIDEGROUPVOLUME",0x5ce9b0:"_EVENT_FLIGHTINSIDEVOLUME",0x5ceb10:"_EVENT_FLIGHTINSIDEOBJECTVOLUME",0x5d0360:"_EVENT_FLIGHTDIED",0x5d05b0:"_EVENT_CAMERAROTATE",0x5d0880:"_EVENT_CAMERAREACH",0x5d0b60:"_EVENT_ONFOCUS",0x5d0df0:"_EVENT_ONHEALTH",0x5d13a0:"_EVENT_ONESCORT",0x5d1490:"_EVENT_ONPILOTINTOBASE",0x5d16f0:"_EVENT_ONUSESPECIAL",0x5d11c0:"_EVENT_ONCAMERASWITCH"}
CLS={0x5ca660:"Trigger",0x5d64b0:"Pilot",0x5d9550:"Team",0x5d9e90:"Group",0x5dac00:"Flight",0x5dde50:"Vector3",0x5de780:"Market",0x5df1b0:"Carcass",0x5e96b0:"NavPoint",0x5e9720:"Line",0x5ea940:"Portal",0x5ec6f0:"Station",0x5ed860:"Inventory",0x5ee320:"Movie(free/orient)",0x5ee480:"Movie(target)",0x5ee5e0:"Movie(keys)"}
CLS.update({k:"Event"+v[6:].title().replace("_","") for k,v in EVT.items()})
rows=[];seen=set()
for x in r:
    if x['kind']=='global':
        if not x['name'] or x['site']>0x650000: continue
        rows.append(dict(cls="global",name=x['name'],fn=x['fn'],site=x['site']))
    elif x['kind']=='field':
        rows.append(dict(cls=CLS.get(x['setup'],hex(x['setup'])),name=x['name'] or "InitMovie",fn=x['fn'],site=x['site']))
# usage
def count(pat):
    c=0;ex=None;files=0
    rx=re.compile(pat)
    for p,t in texts.items():
        n=len(rx.findall(t))
        if n: c+=n;files+=1;ex=ex or p
    return c,files,ex
mcache={}
for row in rows:
    nm=re.escape(row['name'])
    if row['cls']=="global":
        row['use']=count(r"(?<![\w:.])"+nm+r"\s*\(")
        row['ref']=count(r"(?<![\w:.\"])"+nm+r"(?![\w\"(])")[0]
        row['def']=count(r"function\s+"+nm+r"\s*\(")[0]
    else:
        if nm not in mcache: mcache[nm]=count(r":\s*"+nm+r"\s*\(")
        row['use']=mcache[nm]
json.dump(rows,open(sys.argv[2],"w"),indent=0)
print(len(rows),len(texts))
