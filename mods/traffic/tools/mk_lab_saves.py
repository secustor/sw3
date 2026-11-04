#!/usr/bin/env python3
"""Edit one TRF table (savetool get --json output) for a lab save variant; used by mk_lab_saves.sh.

  python3 -I mk_lab_saves.py heat4|recovery|pro9 <in.json> <out.json> [--loc <system> --map <map.script>]

heat4     std.heat = 4, std.heat_t = clock.legs (decay counts from the load).
recovery  rg[slot] of --loc set to Recovery (ph 5) as TRF_RgEnter does at leg clock.legs: pt = legs, the
          Raids-only fields (sw, sn, sl, sr, ct bits 1 and 2) cleared. Slot from map.script's rg field.
pro9      pro = 9 on every TRF.sys entry (trf_state clamps it to the system's pro cap on load).
Prints the edited fields. Exits 1 when the table is not a TRF v4 table or the system has no region.
"""
import argparse
import json
import re
import sys


def die(msg):
    sys.exit('mk_lab_saves: ' + msg)


def entries(t):
    """(key, value) pairs of a JSON table: arrays are slots 1..n, objects use "[n]" keys."""
    if isinstance(t, list):
        return [(i + 1, v) for i, v in enumerate(t)]
    out = []
    for k, v in t.items():
        m = re.fullmatch(r'\[(\d+)\]', k)
        if m:
            out.append((int(m.group(1)), v))
    return out


def slot_of(map_path, loc):
    txt = open(map_path, 'rb').read().decode('cp1251')
    m = re.search(r'\{name="%s", idx=(\d+),[^\r\n]*' % re.escape(loc.lower()), txt)
    if not m:
        die('system %r not in %s' % (loc, map_path))
    g = re.search(r'\brg=(\d+)', m.group(0))
    if not g:
        die('system %r has no region (independent); load a save in a region system' % loc)
    return int(g.group(1))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('variant', choices=['heat4', 'recovery', 'pro9'])
    ap.add_argument('src')
    ap.add_argument('dst')
    ap.add_argument('--loc')
    ap.add_argument('--map')
    a = ap.parse_args()
    t = json.load(open(a.src, encoding='utf-8'))
    if not isinstance(t, dict) or t.get('version') != 4:
        die('TRF is not a v4 table (version %r); use a save made with the current mod' % (t.get('version') if isinstance(t, dict) else None))
    legs = t.get('clock', {}).get('legs')
    if not isinstance(legs, (int, float)):
        die('TRF.clock.legs missing')
    if a.variant == 'heat4':
        s = t.setdefault('std', {})
        s['heat'] = 4
        s['heat_t'] = legs
        print('std.heat=4 std.heat_t=%s' % legs)
    elif a.variant == 'recovery':
        if not a.loc or not a.map:
            die('recovery needs --loc and --map')
        slot = slot_of(a.map, a.loc)
        rgs = dict(entries(t.get('rg', [])))
        r = rgs.get(slot)
        if not isinstance(r, dict) or not all(isinstance(r.get(k), (int, float)) for k in ('ph', 'pt', 'sn', 'sl', 'gx', 'sw')):
            die('TRF.rg[%d] missing or not a valid region record' % slot)
        old = r['ph']
        r.update(ph=5, pt=legs, sw=0, sn=0, sl=0)
        r.pop('sr', None)
        ct = r.get('ct')
        if isinstance(ct, (int, float)):
            r['ct'] = int(ct) - (int(ct) & 3)
        print('rg[%d] (%s) ph %s -> 5 pt=%s gx=%s' % (slot, a.loc, old, legs, r['gx']))
    else:
        n = 0
        for _, v in entries(t.get('sys', {})):
            if isinstance(v, dict):
                v['pro'] = 9
                n += 1
        if n == 0:
            die('TRF.sys has no entries')
        print('sys: pro=9 on %d entries' % n)
    json.dump(t, open(a.dst, 'w', encoding='utf-8'))


if __name__ == '__main__':
    main()
