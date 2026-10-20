# Generate lua-natives table sections from rows2.json + annot.py
import json,sys,os,collections
sys.path.insert(0,os.path.dirname(__file__))
from annot import G,M,EVM
rows=json.load(open(sys.argv[1]))
out=[]
def use(x):
    c,f,ex=x['use']
    if c==0: return "0 (never)"
    return f"{c} / {f} files, `{ex.replace('Scripts/','')}`"
def esc(s): return s.replace("|","\\|")
# globals by area
areas=collections.OrderedDict((a,[]) for a in ["util","triggers","quests","ui","news","spawn","player","query","relations","travel","economy","world","save","media"])
for x in rows:
    if x['cls']!="global": continue
    a,args,rel=G.get(x['name'],("misc","?","-"))
    areas.setdefault(a,[]).append((x,args,rel))
TITLE={"util":"Utility, math, script loading","triggers":"Triggers (globals)","quests":"Quests, labels, missions","ui":"UI, dialogs, messages","news":"News / mail","spawn":"Spawning: teams, pilots, ships","player":"Player fleet","query":"Object queries and labels","relations":"Relations / reputation","travel":"Systems, portals, jumps","economy":"Credits, shops, markets","world":"World objects (map builder)","save":"Save","media":"Audio, video, cutscenes"}
for a,lst in areas.items():
    if not lst: continue
    out.append(f"\n### Globals: {TITLE.get(a,a)}\n\n| name | impl addr | args guess | used in scripts (calls / files, example) | relevance |\n|---|---|---|---|---|")
    for x,args,rel in lst:
        out.append(f"| `{x['name']}` | 0x{x['fn']:x} | {esc(args)} | {use(x)} | {rel} |")
# classes
order=["Trigger","Flight","Carcass","Pilot","Team","Group","Portal","Station","Market","Inventory","NavPoint","Line","Vector3"]
bycls=collections.OrderedDict()
for x in rows:
    if x['cls']=="global": continue
    bycls.setdefault(x['cls'],[]).append(x)
def clsrows(c,lst):
    out.append(f"\n### Methods: {c}\n\n| name | impl addr | args guess | used in scripts (`:name(` calls / files, all classes) | relevance |\n|---|---|---|---|---|")
    seen=set()
    for x in lst:
        k=(x['name'],x['fn'])
        if k in seen: continue
        seen.add(k)
        args,rel=M.get((c,x['name']),EVM.get(x['name'],("?","-")) if c.startswith("Event") or c=="Trigger" else ("?","-"))
        if c.startswith("Movie"): args,rel=("see script usage","-")
        out.append(f"| `:{x['name']}` | 0x{x['fn']:x} | {esc(args)} | {use(x)} | {rel} |")
for c in order:
    if c in bycls: clsrows(c,bycls[c])
# event classes compact
out.append("\n### Methods: event classes (returned by `Trigger:AttachEvent(_EVENT_x)`)\n\nAll event classes share `Activate` 0x5cad00, `AttachCondition` 0x5c9530, `AttachAction` 0x5c96e0, `Delete` 0x5c9020, `AssotiateTrigger` 0x5cfbe0, `GetAssotiatedData` 0x5cfd20. Class-specific methods:\n\n| event (value) | setup fn | specific methods (impl) | relevance |\n|---|---|---|---|")
EV={0x5ca6b0:("_EVENT_INSIDEVOLUME",6),0x5cb200:("_EVENT_INSIDEOBJECTVOLUME",7),0x5cae90:("_EVENT_OBJECTDIED",8),0x5cb600:("_EVENT_TIMER",9),0x5cbd90:("_EVENT_GROUPRELATION",23),0x5cc210:("_EVENT_ATTACKCARCASS",24),0x5cca50:("_EVENT_SIDEINSIDEOBJECTVOLUME",10),0x5ccf20:("_EVENT_GROUPINSIDEOBJECTVOLUME",25),0x5cd670:("_EVENT_SIDEINSIDEVOLUME",11),0x5cdba0:("_EVENT_GROUPINSIDEVOLUME",26),0x5ce1d0:("_EVENT_GROUPINSIDEGROUPVOLUME",27),0x5ce9b0:("_EVENT_FLIGHTINSIDEVOLUME",12),0x5ceb10:("_EVENT_FLIGHTINSIDEOBJECTVOLUME",13),0x5d0360:("_EVENT_FLIGHTDIED",14),0x5d05b0:("_EVENT_CAMERAROTATE",15),0x5d0880:("_EVENT_CAMERAREACH",16),0x5d0b60:("_EVENT_ONFOCUS",17),0x5d0df0:("_EVENT_ONHEALTH",18),0x5d13a0:("_EVENT_ONESCORT",20),0x5d1490:("_EVENT_ONPILOTINTOBASE",21),0x5d16f0:("_EVENT_ONUSESPECIAL",22),0x5d11c0:("_EVENT_ONCAMERASWITCH",19)}
REL={"_EVENT_TIMER":"CORE (tick source)","_EVENT_INSIDEVOLUME":"CORE","_EVENT_INSIDEOBJECTVOLUME":"CORE","_EVENT_OBJECTDIED":"CORE","_EVENT_FLIGHTDIED":"CORE","_EVENT_ATTACKCARCASS":"CORE (player attacks trader)","_EVENT_GROUPRELATION":"CORE","_EVENT_FLIGHTINSIDEVOLUME":"CORE","_EVENT_FLIGHTINSIDEOBJECTVOLUME":"CORE (escort/arrival)","_EVENT_SIDEINSIDEVOLUME":"USEFUL","_EVENT_SIDEINSIDEOBJECTVOLUME":"USEFUL (pirates near trader)","_EVENT_GROUPINSIDEVOLUME":"USEFUL","_EVENT_GROUPINSIDEOBJECTVOLUME":"USEFUL","_EVENT_GROUPINSIDEGROUPVOLUME":"USEFUL","_EVENT_ONHEALTH":"USEFUL","_EVENT_ONESCORT":"USEFUL"}
common={"Activate","AttachCondition","AttachAction","Delete","AssotiateTrigger","GetAssotiatedData"}
for s,(nm,v) in EV.items():
    c="Event"+nm[6:].title().replace("_","")
    lst=[x for x in bycls.get(c,[]) if x['name'] not in common]
    sp=", ".join(f"{x['name']} 0x{x['fn']:x}" + (" (stub)" if x['fn']==0x4685e0 else "") for x in lst)
    out.append(f"| `{nm}` ({v}) | 0x{s:x} | {sp} | {REL.get(nm,'-')} |")
mv=[c for c in bycls if c.startswith("Movie")]
out.append("\nMovie/camera classes (" + ", ".join(mv) + ", setup fns 0x5ee320, 0x5ee480, 0x5ee5e0): InitMovie 0x5ee740, Play 0x5ee830, AddOrientKey 0x5ee8a0, AddOrientVectorKey 0x5eea20 (never used), AddPosKey 0x5eec70, AddKeys 0x5eeb70, SetInterpolate 0x5eedc0, SetLength 0x5eeed0, SetTarget 0x5eef70, AttachAction 0x5ef330, AttachEscapeScript 0x5ef4d0, AddScriptKey 0x5ef3c0, SetFollowRocketParam 0x5ef560 (never used). Not relevant for traffic.")
open(sys.argv[2],"w").write("\n".join(out)+"\n")
# unused list
un=[(x['cls'],x['name'],x['fn']) for x in rows if x['use'][0]==0]
print(len(rows),len(un))
seen=set()
for c,n,f in un:
    if (c,n) in seen: continue
    seen.add((c,n)); print(f"{c}.{n} 0x{f:x}")
