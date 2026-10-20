# Decode DirectInput key-state reads in sw3cw.exe disassembly.
# Usage: python3 -I keyuse.py exe.asm dik.json > keyuse.txt
# Covers:
#  1. direct reads `[eax+off]` within 3 instructions after `call 0x424e80` (g_Input getter)
#  2. helper 0x426a50: key code pushed as the last arg (`push imm; call 0x426a50`), tests state == 1
#  3. helpers 0x426a20 / 0x426a70: key code in esi (`mov esi, imm; call ...`)
# Not covered: indexed loops such as 0x596b28-0x596b84 (`[esi+eax]`, esi 0x2c..0x4c = DIK_1..DIK_9,
# team select / Shift+team), and helper calls whose key code is not an immediate.
import sys,re,json
asm=open(sys.argv[1]).read().splitlines()
ents=json.load(open(sys.argv[2]))
# entry i's code is stored 4 bytes before its DIK string -> ents[i-1].code; NONE code=0
fixed=[]
for i,e in enumerate(ents):
    c=0 if i==0 else ents[i-1][2]
    fixed.append((e[1],c))
cn={}
for n,c in fixed: cn.setdefault(c,[]).append(n)
special={0x854:'LMB',0x858:'RMB',0x85c:'MMB',0x860:'LMB_dbl',0x864:'RMB_dbl',0x868:'MMB_dbl',0x84c:'mouseX',0x850:'mouseY',0x82c:'mouse_dX?',0x830:'mouse_dY?',0x834:'wheel?'}
def keyname(k): return '/'.join(cn.get(k,[hex(k)]))
def addr(l): return l.split(':')[0].strip()
def ins(l): return l.split('\t',1)[1].strip() if '\t' in l else l.strip()
out=[]
for i,l in enumerate(asm):
    if 'call\t0x424e80' in l:
        for j in range(i+1,min(i+4,len(asm))):
            m=re.search(r'\[(e[a-z]{2}) \+ (0x[0-9a-f]+)\]',asm[j])
            if m and m.group(1)=='eax':
                x=int(m.group(2),16)
                if 0x24<=x<0x424 and (x-0x24)%4==0: lab=keyname((x-0x24)//4)
                else: lab=special.get(x,hex(x))
                out.append((addr(asm[j]),lab,ins(asm[j])))
                break
    elif 'call\t0x426a50' in l:
        lab='?'
        for j in range(i-1,max(i-6,0),-1):
            m=re.search(r'\tpush\t(0x[0-9a-f]+|\d+)$',asm[j])
            if m: lab=keyname(int(m.group(1),0)); break
        out.append((addr(l),lab+' [via 0x426a50, ==1]',ins(asm[j]) if lab!='?' else ins(l)))
    elif 'call\t0x426a20' in l or 'call\t0x426a70' in l:
        h='0x426a20' if '0x426a20' in l else '0x426a70'
        lab='?'
        for j in range(i-1,max(i-8,0),-1):
            m=re.search(r'\tmov\tesi, (0x[0-9a-f]+|\d+)$',asm[j])
            if m: lab=keyname(int(m.group(1),0)); break
            if re.search(r'\t(mov|lea|pop|xchg)\tesi,',asm[j]): break
        out.append((addr(l),lab+' [via '+h+']',ins(asm[j]) if lab!='?' else ins(l)))
for a,lab,i_ in out: print(a,lab,'|',i_)
print('# loop 596b28-596b84: [esi+eax], esi 0x2c..0x4c = DIK_1..DIK_9 (team select, Shift+team); not listed per key above')
