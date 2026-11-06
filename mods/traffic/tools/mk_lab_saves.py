#!/usr/bin/env python3
"""Edit one TRF table (savetool get --json output) for a lab save variant; used by mk_lab_saves.sh.

  python3 -I mk_lab_saves.py <variant> <in.json> <out.json> [--loc <system> --map <map.script>]

heat4     std.heat = 4, std.heat_t = clock.legs (decay counts from the load).
recovery  rg[slot] of --loc set to Recovery (ph 5) as TRF_RgEnter does at leg clock.legs: pt = legs, the
          Raids-only fields (sw, sn, sl, sr, ct bits 1 and 2) cleared. Slot from map.script's rg field.
pro9      pro = 9 on every TRF.sys entry (trf_state clamps it to the system's pro cap on load).
base      no edit: the TRF table as saved (the copy gets its own header name, so the original stays untouched).
route     session A of design/test-plan-sessions.md (save in Elio): remark records (a fresh trader scar in Valensia, a
          pirate sweep scar in Gredos, a fresh trader scar in Gefest with the Gefest captain dead 5 legs ago), a lit
          signal source in Escaflon (TRF.sg block of its region, point 1, state 0), a hidden cache in Escaflon's stash
          slot, dockmaster rung 4 at the Endoria 2 and Valensia trade stations (TRF.stn), Elio haunt memory (3 flights,
          last refill 6 legs ago).
raids     session B: the Gefest region (Elio's) in Raids from the save's leg, the debrief pool open ("Report in" done
          bit in TRF.iq) with one pending debrief and a chapter 7 stamp (refill and dbnew at chapter 8), rung 4 at the
          Valensia trade station, and the Gefest remark records of route (for W-B06.4 with rm_own 0).
east      session D: the freight unlock quest at step 70 (TRF.wq, the unlock box at the next Elio dock), help 3 (the
          charter), TRF.crp: two counted USS losses in Golkonda, the Triada pull-out of XT-27 ended (frees a pull-out
          slot), the Moscowia pull-out notice kept until leg + 24.
charter   help 3 only (charter unlock, then the "Report in" offer after the first paid posting).
The record shapes follow the module repairs (TRF_Sc_Fix, TRF_Cap_Fix D5, TRF_Sg_Fix, TRF_Sh_Fix, TRF_Stn_Fix,
TRF_Haunt_Fix, TRF_Rg_Fix, TRF_Pl_Fix/TRF_Db_Fix, TRF_Wq_Fix, TRF_Crp_Fix CD3); `verify` compares the keys a variant
edits with the table the mod repaired on a host load (tools/lab_fixcheck.lua output).

  python3 -I mk_lab_saves.py verify <variant.json> <lab_fixcheck output> <key,key,...> [variant]
  python3 -I mk_lab_saves.py keys <variant>      (the keys a variant edits, comma-separated)

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


def sys_rec(map_path, name):
    """(idx, region slot or None) of system name in map.script."""
    txt = open(map_path, 'rb').read().decode('cp1251')
    m = re.search(r'\{name="%s", idx=(\d+),[^\r\n]*' % re.escape(name.lower()), txt)
    if not m:
        die('system %r not in %s' % (name, map_path))
    g = re.search(r'\brg=(\d+)', m.group(0))
    return int(m.group(1)), (int(g.group(1)) if g else None)


def slot_of(map_path, loc):
    txt = open(map_path, 'rb').read().decode('cp1251')
    m = re.search(r'\{name="%s", idx=(\d+),[^\r\n]*' % re.escape(loc.lower()), txt)
    if not m:
        die('system %r not in %s' % (loc, map_path))
    g = re.search(r'\brg=(\d+)', m.group(0))
    if not g:
        die('system %r has no region (independent); load a save in a region system' % loc)
    return int(g.group(1))


# Staged records (session variants) -------------------------------------------------------------

LAB_SEED = 4242


def keyed(t, name):
    """t[name] as a JSON object with "[n]" keys (savetool's form of a Lua table with number keys); lists convert."""
    v = t.get(name)
    if isinstance(v, list):
        v = {'[%d]' % (i + 1): x for i, x in enumerate(v)}
    if not isinstance(v, dict):
        v = {}
    t[name] = v
    return v


def scar_put(t, idx, leg, kind, fac, nm, legs):
    """One off-screen scar record in system idx (one per system, TRF_Sc_Fix keeps the first 12 in order).
    kind 1 trader wreck, 3 sweep (fac 0 pirate hulls won, >= 1 navy); st 0 waits to be placed at the entry."""
    sc = keyed(t, 'scar')
    recs = [v for k, v in sorted(entries(sc)) if isinstance(v, dict) and v.get('sys') != idx]
    new = {'sys': idx, 'k': 3, 'kind': kind, 'fac': fac, 'x': 0, 'y': 0, 'z': 0, 'on': 0, 'mine': 0, 'lv': 1 if kind == 1 else 1,
           'seed': LAB_SEED % 9999 + idx, 'nd': 3, 'st': 0, 'hid': 0, 'scv': 0, 'rec': 1 if kind == 1 else 0, 'nm': nm % 41,
           'rf': 0, 'leg': leg, 'ttl': 12 if kind == 1 else 16}
    # Room for the new record: drop the oldest far records first (rec_max 12).
    while len(recs) >= 12:
        recs.remove(min(recs, key=lambda r: r.get('leg', 0)))
    recs.append(new)
    t['scar'] = {'[%d]' % (i + 1): r for i, r in enumerate(recs)}
    t['scar']['n'] = len(recs)
    return 'scar sys=%d kind=%d fac=%d leg=%d (age %d)' % (idx, kind, fac, leg, legs - leg)


def cap_dead(t, slot, legs):
    """The region captain dead off-screen 5 legs ago (st 4, dl = death leg, crew-remarks-spec D16/D5)."""
    caps = t.get('cap')
    if not isinstance(caps, list) or len(caps) < slot or not isinstance(caps[slot - 1], dict):
        die('TRF.cap[%d] missing' % slot)
    c = caps[slot - 1]
    c.update(st=4, dl=legs - 5, dj=int(t['clock'].get('j', 0)), due=0)
    return 'cap[%d] st=4 dl=%d' % (slot, legs - 5)


def sg_put(t, idx, slot, legs):
    """A lit source (state 0, point 1, lit now) in the TRF.sg block of its region (static-signals-spec 3.1, 3.2)."""
    n = max(8, len(t.get('rg', [])))
    blocks = (t.get('sg') or '').split('/') if isinstance(t.get('sg'), str) else []
    blocks += [''] * (n - len(blocks))
    blocks[slot - 1] = '%03d%d%03d%d' % (idx, 1, legs % 1000, 0)
    t['sg'] = '/'.join(blocks[:n])
    return 'sg block %d = %s' % (slot, blocks[slot - 1])


def stash_put(t, idx, slot_reg, legs):
    """A hidden cache (st 0) in slot 1 of a stash system (stash-spec 3.1; one record per system and per clan)."""
    st = t.get('stash')
    recs = st if isinstance(st, list) else [v for _, v in sorted(entries(st or {}))]
    recs = [r for r in recs if isinstance(r, dict) and r.get('sys') != idx and r.get('clan') != slot_reg]
    recs.append({'sys': idx, 'slot': 1, 'clan': slot_reg, 'cls': 2, 'v': 200, 'seed': LAB_SEED, 'leg': legs - 2, 'st': 0, 'src': 0,
                 'sf': 0, 'sv': 0, 'rf': 0})
    t['stash'] = recs[-4:]
    return 'stash sys=%d clan=%d st=0' % (idx, slot_reg)


def stn_rung(t, key, legs, st=4):
    """Dockmaster standing st at station key idx + 200 x (j - 1) (trf_station 7, TRF_Stn_Fix)."""
    keyed(t, 'stn')['[%d]' % key] = {'st': st, 'lg': legs}
    return 'stn[%d] st=%d' % (key, st)


def haunt_mem(t, idx, k, legs):
    """Kill memory of a haunt system: k flights not back, last refill 6 legs ago (haunt-spec 3.1)."""
    keyed(t, 'haunt')['[%d]' % idx] = {'k': k, 'l': legs - 6}
    return 'haunt[%d] k=%d l=%d' % (idx, k, legs - 6)


def rg_raids(t, slot, legs):
    """Region slot in Raids from now (TRF_RgEnter for ph 3: pt = legs, sw 0; a planned sweep sl is kept)."""
    rgs = t.get('rg')
    if not isinstance(rgs, list) or len(rgs) < slot or not isinstance(rgs[slot - 1], dict):
        die('TRF.rg[%d] missing' % slot)
    r = rgs[slot - 1]
    old = r.get('ph')
    if old not in (1, 2, 3):
        die('rg[%d] is in phase %r; Raids is staged only from Boom, Build-up or Raids (same phase group)' % (slot, old))
    r.update(ph=3, pt=legs, sw=0)
    return 'rg[%d] ph %s -> 3 pt=%d' % (slot, old, legs)


def debrief_open(t, ch_stamp=7, left=3, pending=1):
    """Pool open through the done bit 2 of TRF.iq ("Report in"), TRF.db = ch x 10^4 + p x 10^2 + pd x 10 + n."""
    iq = t.get('iq') if isinstance(t.get('iq'), dict) else {}
    if iq.get('a', 0):
        die('TRF.iq holds an active intro quest; the debrief variant needs none')
    iq['a'] = 0
    iq['d'] = int(iq.get('d', 0)) | 2
    iq['r'] = int(iq.get('r', 0))
    t['iq'] = iq
    t['db'] = ch_stamp * 10000 + left * 100 + pending * 10
    return 'iq d=%d db=%d (chapter stamp %d, %d left, %d pending)' % (iq['d'], t['db'], ch_stamp, left, pending)


def help_at_least(t, n):
    s = t.setdefault('std', {})
    old = s.get('help', 0)
    s['help'] = max(int(old), n)
    return 'std.help %s -> %d' % (old, s['help'])


def wq_step(t, step, legs):
    """Freight unlock quest record at step (freight-quest-spec 3.1); 70 = the purchase box is offered at a loop stop."""
    if step not in (20, 70):
        die('wq step %r not staged (20 or 70)' % step)
    w = {'v': 1, 's': step, 'k': 0, 'n': 0, 'sd': LAB_SEED, 'r': 1}
    t['wq'] = w
    return 'wq s=%d r=1 sd=%d' % (step, LAB_SEED)


def crp_east(t, legs, n_slots):
    """TRF.crp (corp-carriers-spec 3.1): block 4 (Golkonda) 2 counted USS losses; block 8 (XT-27, Triada at war) pull-out
    ended; block 6 (Moscowia) pull-out end moved to legs + 24 (crp_pull_legs) with its notice still untold."""
    c = t.get('crp') if isinstance(t.get('crp'), str) else ''
    c = c.ljust(11 * n_slots, '0')[:11 * n_slots]
    b = [c[i * 11:(i + 1) * 11] for i in range(n_slots)]
    b[3] = '02000000000'
    b[7] = '00000000000'
    if b[5][3] != '0':
        b[5] = b[5][:6] + '%05d' % (legs + 24)
    t['crp'] = ''.join(b)
    return 'crp blocks 4=%s 6=%s 8=%s' % (b[3], b[5], b[7])


def stage(variant, t, mp):
    legs = int(t['clock']['legs'])
    out = []
    if variant == 'base':
        return out
    V = lambda n: sys_rec(mp, n)
    if variant in ('route', 'raids'):
        g_idx, g_slot = V('gefest')
        out.append(scar_put(t, g_idx, legs - 1, 1, 0, 3, legs))
        out.append(cap_dead(t, g_slot, legs))
    if variant == 'route':
        v_idx, _ = V('valensia')
        gr_idx, _ = V('gredos')
        e_idx, e_slot = V('escaflon')
        en_idx, _ = V('endoria2')
        el_idx, _ = V('elio')
        out.append(scar_put(t, v_idx, legs - 2, 1, 0, 7, legs))
        out.append(scar_put(t, gr_idx, legs - 8, 3, 0, 0, legs))
        out.append(sg_put(t, e_idx, e_slot, legs))
        out.append(stash_put(t, e_idx, e_slot, legs))
        out.append(stn_rung(t, en_idx, legs))
        out.append(stn_rung(t, v_idx, legs))
        out.append(haunt_mem(t, el_idx, 3, legs))
    elif variant == 'raids':
        el_idx, el_slot = V('elio')
        v_idx, _ = V('valensia')
        out.append(rg_raids(t, el_slot, legs))
        out.append(debrief_open(t))
        out.append(stn_rung(t, v_idx, legs))
    elif variant == 'east':
        out.append(wq_step(t, 70, legs))
        out.append(help_at_least(t, 3))
        out.append(crp_east(t, legs, max(8, len(t.get('rg', [])))))
    elif variant == 'charter':
        out.append(help_at_least(t, 3))
    return out


# Fields the load path sets on purpose (not a rejection): the freight quest's reconcile adds its logbook entry (ql).
EXPECTED = {'east': ['wq.ql']}

# Keys each variant edits (checked by `verify` against the host load).
EDITED = {'base': [], 'route': ['scar', 'cap', 'sg', 'stash', 'stn', 'haunt'], 'raids': ['scar', 'cap', 'rg', 'iq', 'db', 'stn'],
          'east': ['wq', 'std', 'crp'], 'charter': ['std']}


def norm(v):
    """JSON value with arrays as "[n]" objects and integral floats as ints, for comparing two encodings of a Lua table."""
    if isinstance(v, list):
        v = {'[%d]' % (i + 1): x for i, x in enumerate(v)}
    if isinstance(v, dict):
        return {k: norm(x) for k, x in v.items()}
    if isinstance(v, float) and v == int(v):
        return int(v)
    return v


def diff(a, b, path):
    if isinstance(a, dict) and isinstance(b, dict):
        out = []
        for k in sorted(set(a) | set(b)):
            out += diff(a.get(k), b.get(k), path + '.' + k)
        return out
    if a != b:
        return ['%s: staged %s, after the load %s' % (path, json.dumps(a), json.dumps(b))]
    return []


def verify(staged, outf, keys, variant=None):
    t = json.load(open(staged, encoding='utf-8'))
    got, done = {}, None
    for ln in open(outf, encoding='utf-8', errors='replace'):
        if ln.startswith('LABKEY '):
            _, k, js = ln.rstrip('\n').split(' ', 2)
            got[k] = json.loads(js)
        elif ln.startswith('LABDONE '):
            done = ln.strip()
    if done is None:
        die('verify: no LABDONE line in %s (the host load failed)' % outf)
    bad = [] if done.endswith('errors=0 fails=0') else [done]
    for k in keys:
        if k not in got:
            bad.append('%s: not printed by the host load' % k)
            continue
        bad += [d for d in diff(norm(t.get(k)), norm(got[k]), k) if d.split(':', 1)[0] not in EXPECTED.get(variant, [])]
    for ln in open(outf, encoding='utf-8', errors='replace'):
        if 'event=fix' in ln or 'event=repair' in ln:
            bad.append('repair line: ' + ln.strip()[:300])
    for b in bad:
        print('verify: ' + b)
    print('verify: %s keys %s: %s' % (staged, ','.join(keys) or '-', 'OK' if not bad else '%d differences' % len(bad)))
    return 0 if not bad else 1


def main():
    if len(sys.argv) > 1 and sys.argv[1] == 'verify':
        if len(sys.argv) not in (5, 6):
            die('usage: verify <variant.json> <lab_fixcheck output> <key,key,...> [variant]')
        sys.exit(verify(sys.argv[2], sys.argv[3], [k for k in sys.argv[4].split(',') if k], (sys.argv[5:] or [None])[0]))
    if len(sys.argv) > 1 and sys.argv[1] == 'keys':
        print(','.join(EDITED.get(sys.argv[2], [])))
        return
    ap = argparse.ArgumentParser()
    ap.add_argument('variant', choices=['heat4', 'recovery', 'pro9'] + sorted(EDITED))
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
    if a.variant in EDITED:
        if a.variant != 'base' and a.variant != 'charter' and (a.loc or '').lower() != 'elio':
            die('variant %s is built for a save in Elio (design/test-plan-sessions.md); this save is in %r' % (a.variant, a.loc))
        if not a.map:
            die('%s needs --map' % a.variant)
        for line in stage(a.variant, t, a.map) or ['no edit']:
            print(line)
        json.dump(t, open(a.dst, 'w', encoding='utf-8'))
        return
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
