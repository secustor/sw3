# Print up to N distinct call lines per native name from shipped scripts
import re,os,sys,json
ROOT="/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data"
lines=[]
for d,_,fs in os.walk(ROOT+"/Scripts"):
    for x in fs:
        if x.endswith((".script",".xml")):
            p=os.path.join(d,x)
            for l in open(p,"rb").read().decode("cp1251","replace").split("\n"):
                l=re.sub(r"--.*","",l).strip()
                if l: lines.append((os.path.relpath(p,ROOT+"/Scripts"),l))
N=int(sys.argv[1]); 
for spec in sys.argv[2:]:
    meth=spec.startswith(":")
    nm=spec.lstrip(":")
    rx=re.compile((r":\s*" if meth else r"(?<![\w:.])")+re.escape(nm)+r"\s*\(")
    seen=set();out=[]
    for p,l in lines:
        if rx.search(l):
            k=re.sub(r"\d+","#",rx.split(l,1)[1][:40])
            if k in seen: continue
            seen.add(k);out.append(f"   {p}: {l[:170]}")
            if len(out)>=N: break
    print(spec, len(out)); print("\n".join(out))
