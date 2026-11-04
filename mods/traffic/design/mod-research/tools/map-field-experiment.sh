#!/bin/sh
# Kept as a reference for map experiments (clone only); the Kitaro values are an example, adapt centres and exceptions per system.
# View distance and map experiment in Kitaro (test clone only). Run with the game closed:
#   sh .work/vd/kitaro-experiment.sh apply     # far plane 800 -> 1600, Kitaro map 2000 -> 3000, two asteroid fields
#   sh .work/vd/kitaro-experiment.sh revert    # restore both files from the backup
# Report: .work/research/view-distance-and-maps.md (ZFarPlane, InitMap, CreateAsterCloudsCube, CreateGroupOfAsteroids).
# Kitaro has no stored snapshot in the current save (Quicksave-83), so location.script runs at the next entry.
set -e
GAME="${GAME:-$HOME/Games/Heroic/sw3-tp-test}"
here=$(cd "$(dirname "$0")" && pwd)
bk="$here/backup"
ini="$GAME/Main.ini"
loc="$GAME/Data/Scripts/Locations/Kitaro/location.script"
if pgrep -f sw3cw.exe >/dev/null 2>&1; then echo "the game is running; close it first" >&2; exit 1; fi
case "${1:-}" in
apply)
    mkdir -p "$bk"
    [ -f "$bk/Main.ini" ] || cp "$ini" "$bk/Main.ini"
    [ -f "$bk/location.script" ] || cp "$loc" "$bk/location.script"
    python3 -I - "$ini" "$loc" <<'EOF'
import sys
ini, loc = sys.argv[1], sys.argv[2]
b = open(ini, 'rb').read()
if b'ZFarPlane = 1600.0f' not in b:
    assert b.count(b'ZFarPlane = 800.0f') == 1, 'ZFarPlane line not found'
    b = b.replace(b'ZFarPlane = 800.0f', b'ZFarPlane = 1600.0f')
    open(ini, 'wb').write(b)
s = open(loc, 'rb').read()
if b'TRF experiment' not in s:
    assert s.count(b'InitMap(2000, 2000, 18, 100);') == 1, 'InitMap line not found'
    s = s.replace(b'InitMap(2000, 2000, 18, 100);', b'InitMap(3000, 3000, 18, 100);')
    marker = b'--SPACE JUNK\r\n----------------------------------------------------------------\r\n'
    assert s.count(marker) == 1, 'SPACE JUNK header not found'
    add = (b'-- TRF experiment (view distance and map size), remove with .work/vd/kitaro-experiment.sh revert\r\n'
           b'xyz_trf_field1 = Vector3(-900, 0, 100);\r\n'
           b'xyz_trf_field2 = Vector3(1000, 0, -1000);\r\n'
           b'trf_exc = {xyz_portal_L, xyz_portal_R, xyz_portal_U, xyz_portal_D, xyz_STO, xyz_trade, xyz_imu, xyz_sci, xyz_lab, xyz_fact1, xyz_fact2};\r\n'
           b'CreateAsterCloudsCube(xyz_trf_field1, 40, 500, 500, 120, trf_exc);\r\n'
           b'CreateGroupOfAsteroids(xyz_trf_field1, 30, 300, 1, trf_exc);\r\n'
           b'CreateAsterCloudsCube(xyz_trf_field2, 70, 800, 800, 160, trf_exc);\r\n'
           b'CreateGroupOfAsteroids(xyz_trf_field2, 60, 450, 1, trf_exc);\r\n'
           b'CreateGroupOfAsteroids(xyz_trf_field2, 6, 300, 2, trf_exc);\r\n')
    s = s.replace(marker, marker + add)
    open(loc, 'wb').write(s)
print('applied')
EOF
    grep -a -n 'ZFarPlane' "$ini" | tr -d '\r'
    grep -a -n 'InitMap\|TRF experiment\|xyz_trf_field\|CreateAsterCloudsCube\|CreateGroupOfAsteroids' "$loc" | tr -d '\r'
    ;;
view)
    # sh .work/vd/kitaro-experiment.sh view 6000 [fog]   -> ZFarPlane = 6000 (6000 covers the 4000x4000 map from any point);
    # with "fog" the 58 Data/Environment/*.env FogEnd values are rescaled so the fog still ends at 800 units (backup kept).
    n="${2:-6000}"; mkdir -p "$bk"
    [ -f "$bk/Main.ini" ] || cp "$ini" "$bk/Main.ini"
    python3 -I - "$ini" "$n" <<'EOP'
import sys,re
ini,n=sys.argv[1],sys.argv[2]
b=open(ini,'rb').read()
b2,k=re.subn(rb'ZFarPlane = [0-9.]+f', b'ZFarPlane = '+n.encode()+b'.0f', b)
assert k==1, 'ZFarPlane line not found'
open(ini,'wb').write(b2); print('ZFarPlane =', n)
EOP
    if [ "${3:-}" = fog ]; then
        mkdir -p "$bk/Environment"
        for e in "$GAME"/Data/Environment/*.env; do
            [ -f "$bk/Environment/$(basename "$e")" ] || cp "$e" "$bk/Environment/"
        done
        python3 -I - "$GAME/Data/Environment" "$n" <<'EOP'
import sys,os,re
d,n=sys.argv[1],float(sys.argv[2]); k=0
for f in sorted(os.listdir(d)):
    if not f.lower().endswith('.env'): continue
    p=os.path.join(d,f); b=open(p,'rb').read()
    m=re.search(rb'(?im)^(FogEnd\s*=\s*)([-0-9.]+)',b)
    if not m or float(m.group(2))<=0: continue
    v=800.0/n*float(m.group(2))
    b=b[:m.start(2)]+(b'%.4f'%v)+b[m.end(2):]
    m2=re.search(rb'(?im)^(FogStart\s*=\s*)([-0-9.]+)',b)
    if m2 and float(m2.group(2))>0:
        v2=800.0/n*float(m2.group(2)); b=b[:m2.start(2)]+(b'%.4f'%v2)+b[m2.end(2):]
    open(p,'wb').write(b); k+=1
print('fog rescaled in',k,'env files (fog ends at 800 units)')
EOP
    fi
    ;;
revert)
    if [ -d "$bk/Environment" ]; then cp "$bk/Environment/"*.env "$GAME/Data/Environment/" && echo "env files restored"; fi
    [ -f "$bk/Main.ini" ] && cp "$bk/Main.ini" "$ini" && echo "Main.ini restored"
    [ -f "$bk/location.script" ] && cp "$bk/location.script" "$loc" && echo "Kitaro/location.script restored"
    ;;
*) echo "usage: $0 apply|revert" >&2; exit 2 ;;
esac
