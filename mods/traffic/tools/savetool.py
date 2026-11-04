#!/usr/bin/env python3
"""savetool: read and edit Star Wolves 3: Civil War (GOG v1.12) .sav files. stdlib only, run with python3 -I.
Format: mods/traffic/design/mod-research/save-format.md (derived from the exe; not yet checked against a real save)."""
import argparse, json, os, re, struct, sys, tempfile, zlib

MARK = b'\xab\xab\xab\xab'
SECTIONS = ['STREAMID_' + s for s in (
    'Environment CameraParams Map MapSelector GameObjects TeamManager SceneStuff Script Diplomacy QuestManager '
    'GameInterface MusicPlayList LocationManager TradeSystem QuestManager2 PortalManager RecruitManager').split()]
SKIP = set('_CLASS PI _VERSION _INPUT _OUTPUT _STDERR _STDIN _STDOUT _script_error_output sys_IncludeFileList '
           '_script_path _script_error_filename TRUE FALSE PLAYER_TEAM PLAYER_GROUP PLAYER_MOTHERSHIP'.split())
SKIP_DYN = set('EASY NORMAL HARD NOINIT'.split())  # part of the dynamic list 0x7bb6b0, as in lint_lua.py
SKIP_PREFIX = (b'_EVENT_', b'ROLE_', b'RELATION_', b'QUEST_', b'MISSION_')
BADCH = '\\/:*?"<>|.'  # 0x4e6e40 drops the first nine; the file stem ends at a '.' (0x413d10) while the header keeps it
ENC = 'latin-1'  # tool choice: lossless byte<->char mapping; the game's text encoding is not known
P = lambda n: struct.pack('<I', n)
# Points save-format.md marks [I] that this tool relies on; info prints them with what the file showed.
ASSUMPTIONS = [
    ('zlib', 'body is a standard zlib stream (compress2 level 9 -> header 78 da) [I]'),
    ('scan', 'the AB AB AB AB + "STREAMID_" scan finds exactly the 17 section headers, no false hits in data [I]'),
    ('name', 'header field 3 (name) equals the file name; set keeps them equal [I]'),
    ('path', 'saves live in Profiles\\<user>\\Save\\<name>.sav [I]'),
    ('level', 'the loader accepts any zlib level; the tool uses level 9 like the game [I]'),
    ('trig', 'trigger strings str_14/str_38 are the condition and action function names [I]'),
    ('nul', 'strings with an embedded NUL are cut by the game (strlen); set refuses them [I]'),
    ('enc', 'strings are shown as latin-1, \\ddd escapes for bytes >= 0x80 in Lua form (game text encoding unknown) [I]'),
]


class FormatError(Exception):
    pass


class Table:
    __slots__ = ('items', 'tag')

    def __init__(self, items=None, tag=0):
        self.items, self.tag = (items if items is not None else []), tag

    def _find(self, k):
        return next((i for i, (kk, _) in enumerate(self.items) if type(kk) is type(k) and kk == k), None)

    def get(self, k):
        i = self._find(k)
        return None if i is None else self.items[i][1]

    def set(self, k, v):  # v None deletes; a replaced entry keeps its position
        i = self._find(k)
        if i is None:
            if v is not None: self.items.append((k, v))
        elif v is None: del self.items[i]
        else: self.items[i] = (k, v)


class R:
    def __init__(self, b, pos=0):
        self.b, self.p = b, pos

    def take(self, n, what):
        if self.p + n > len(self.b):
            raise FormatError(f'unexpected end of data reading {what} at 0x{self.p:x} (need {n}, have {len(self.b) - self.p})')
        self.p += n
        return self.b[self.p - n:self.p]

    def u32(self, what='u32'): return struct.unpack('<I', self.take(4, what))[0]

    def f64(self): return struct.unpack('<d', self.take(8, 'number'))[0]

    def str(self, what='String'):
        at, n = self.p, self.u32(what + ' length')
        if n >= 0x7fff: raise FormatError(f'{what} at 0x{at:x}: length {n} >= 0x7fff (the game rejects it)')
        return self.take(n, what)


# ---- value grammar (save-format.md section 3) ----
def rd_value(r):
    at, code = r.p, r.u32('type code')
    if code == 1: return r.f64()
    if code == 2: return r.str()
    if code == 3: return rd_table(r)
    raise FormatError(f'bad value type code {code} at 0x{at:x} (expected 1 number, 2 string, 3 table)')


def rd_table(r):
    t = Table()
    while True:
        at, code = r.p, r.u32('key type')
        if code == 4:
            t.tag = r.u32('tag index')
            return t
        if code not in (1, 2): raise FormatError(f'bad key type code {code} at 0x{at:x} (expected 1 number, 2 string, 4 end)')
        k = r.f64() if code == 1 else r.str('key')
        t.items.append((k, rd_value(r)))


def wr_str(out, b):
    if len(b) >= 0x7fff: raise FormatError(f'string of {len(b)} bytes is too long (game limit 0x7ffe)')
    out += P(len(b)) + b


def wr_value(out, v):  # also used for keys (numbers and strings encode the same way)
    if isinstance(v, Table):
        out += P(3)
        for k, x in v.items: wr_value(out, k); wr_value(out, x)
        out += P(4) + P(v.tag)
    elif isinstance(v, float): out += P(1) + struct.pack('<d', v)
    elif isinstance(v, bytes): out += P(2); wr_str(out, v)
    else: raise FormatError(f'cannot encode {type(v).__name__}')


def enc(v):
    out = bytearray()
    wr_value(out, v)
    return bytes(out)


def tree_eq(a, b):  # order-insensitive: entry order comes from the Lua hash and does not matter to the loader
    if isinstance(a, Table) and isinstance(b, Table):
        return a.tag == b.tag and len(a.items) == len(b.items) and all(
            any(type(k) is type(k2) and k == k2 and tree_eq(v, v2) for k2, v2 in b.items) for k, v in a.items)
    return type(a) is type(b) and a == b


def validate(v, path, warn):
    if isinstance(v, bytes) and b'\0' in v: raise FormatError(f'{path}: string contains a NUL byte; the game would cut it there')
    for k, x in v.items if isinstance(v, Table) else ():
        if isinstance(k, bytes):
            validate(k, path + ' key', warn)
            if reserved(k):
                warn(f'{path}.{k.decode(ENC)}: reserved name; it loads (the loader has no skip list) '
                     'but the next in-game save drops it')
        validate(x, path + ('.' if isinstance(k, bytes) else '') + fmt_key(k), warn)


def reserved(k): return k.decode(ENC) in SKIP | SKIP_DYN or k.startswith(SKIP_PREFIX)


# ---- file ----
class Save:
    def __init__(self, data, path='<data>'):
        if data[:7] != b'\x03\0\0\0SAV':
            raise FormatError(f'{path}: not a SW3 save: starts {data[:12].hex()} {data[:12]!r}, expected 03000000 "SAV"')
        r = R(data, 7)
        self.version = r.u32('version')
        if self.version != 7: raise FormatError(f'{path}: file version {self.version}, this tool knows version 7 only')
        self.name, self.datetime, self.location = r.str('name'), r.str('date/time'), r.str('location')
        self.state, self.qcount = r.u32('game state'), r.u32('quicksave counter')
        if self.state not in (5, 0x13):
            raise FormatError(f'{path}: game state {self.state}; only 5 and 0x13 have a FullStorage body (6 = intermission, not decoded)')
        tag = r.str('body tag')
        if tag != b'FullStorage': raise FormatError(f'{path}: body tag {tag[:32]!r}, expected b\'FullStorage\'')
        self.clen, self.ulen = r.u32('compressed size'), r.u32('uncompressed size')
        self.zoff, self.header = r.p, data[:r.p]
        self.comp = r.take(self.clen, 'zlib data')
        self.trailing = data[r.p:]
        try: self.body = zlib.decompress(self.comp)
        except zlib.error as e:
            raise FormatError(f'{path}: zlib data at 0x{self.zoff:x} does not inflate: {e} (starts {self.comp[:4].hex()})')
        if len(self.body) != self.ulen: raise FormatError(f'{path}: inflated {len(self.body)} bytes, header says {self.ulen}')
        self.sections = find_sections(self.body)
        self.parse_script()

    def parse_script(self):
        off = {n: o for n, o, _ in self.sections}
        nxt, r = off['STREAMID_Diplomacy'], R(self.body, off['STREAMID_Script'] + 4)
        r.str('section id')
        self.scene, self.system = r.str('scene name'), r.str('system name')
        tc = r.u32('tag count')
        if tc != 0x2c: raise FormatError(f'Script section: tag count {tc:#x}, expected 0x2c')
        kc, gname = r.u32('key type'), r.str('global table name')
        if kc != 2 or gname != b'GLOBAL_TABLE':
            raise FormatError(f'Script section: found key type {kc} {gname[:32]!r}, expected 2 "GLOBAL_TABLE"')
        self.gstart = r.p
        if r.u32('table code') != 3: raise FormatError(f'Script section: GLOBAL_TABLE at 0x{self.gstart:x} is not a table')
        self.g, self.gend = rd_table(r), r.p
        self.triggers = [(r.u32('trigger id'), r.u32(), r.u32(), r.u32(), r.str('trigger str_14'), r.str('trigger str_38'))
                         for _ in range(r.u32('trigger count'))]
        self.tail = r.str('trailing String')
        if r.p != nxt:
            raise FormatError(f'Script section parse ended at body 0x{r.p:x}, expected the STREAMID_Diplomacy marker '
                              f'at 0x{nxt:x} (format differs from save-format.md section 3)')

    def build_header(self, name, clen, ulen):
        out = bytearray()
        wr_str(out, b'SAV'); out += P(self.version)
        for s in (name, self.datetime, self.location): wr_str(out, s)
        out += P(self.state) + P(self.qcount)
        wr_str(out, b'FullStorage')
        return bytes(out + P(clen) + P(ulen))

    def build_body(self): return self.body[:self.gstart] + enc(self.g) + self.body[self.gend:]

    def to_bytes(self, name=None):
        body = self.build_body()
        comp = zlib.compress(body, 9)
        return self.build_header(self.name if name is None else name, len(comp), len(body)) + comp + self.trailing


def find_sections(body):
    found = []
    for m in re.finditer(re.escape(MARK) + rb'(?=(.{4})STREAMID_)', body, re.S):
        n = struct.unpack('<I', m.group(1))[0]
        ident = body[m.start() + 8:m.start() + 8 + n].decode(ENC)
        if 9 <= n <= 40 and ident in SECTIONS: found.append((ident, m.start()))
    if [f[0] for f in found] != SECTIONS:
        raise FormatError(f'section scan found {len(found)} headers {[f[0] for f in found]}, expected the 17 ids in order')
    ends = [f[1] for f in found[1:]] + [len(body)]
    return [(n, o, e - o) for (n, o), e in zip(found, ends)]


def load(path):
    try:
        with open(path, 'rb') as f: return Save(f.read(), path)
    except OSError as e: sys.exit(f'savetool: cannot read {path}: {e.strerror}')


# ---- text forms ----
NAME_RE = re.compile(r'[A-Za-z_]\w*\Z', re.A)
KEYWORDS = set('and break do else elseif end for function if in local nil not or repeat return then until while'.split())


def fmt_num(f): return str(int(f)) if f.is_integer() and abs(f) < 1e15 else repr(f)


def fmt_str(b):
    o = {0x5c: '\\\\', 0x22: '\\"', 0x0a: '\\n', 0x0d: '\\r', 0x09: '\\t'}
    return '"' + ''.join(o.get(c) or (chr(c) if 0x20 <= c < 0x7f else f'\\{c:03d}') for c in b) + '"'


def fmt_key(k):
    if isinstance(k, float): return f'[{fmt_num(k)}]'
    s = k.decode(ENC)
    return s if NAME_RE.match(s) and s not in KEYWORDS else f'[{fmt_str(k)}]'


def to_lua(v, depth=0, maxd=99, ind=''):
    if isinstance(v, float): return fmt_num(v)
    if isinstance(v, bytes): return fmt_str(v)
    tag = f' --[[tag {v.tag}]]' if v.tag else ''
    if not v.items: return '{' + tag + ' }'
    if depth >= maxd: return '{' + tag + f' --[[{len(v.items)} entries]] }}'
    i2 = ind + '  '
    return '{' + tag + '\n' + ''.join(f'{i2}{fmt_key(k)} = {to_lua(x, depth + 1, maxd, i2)},\n' for k, x in v.items) + ind + '}'


def to_json(v):  # tables: JSON array if keys are exactly 1..n, else object; number keys as "[n]", tag as "__tag"
    if isinstance(v, float): return int(v) if v.is_integer() and abs(v) < 1e15 else v
    if isinstance(v, bytes): return v.decode(ENC)
    keys = [k for k, _ in v.items]
    if keys and not v.tag and all(isinstance(k, float) for k in keys) and sorted(keys) == [float(i) for i in range(1, len(keys) + 1)]:
        return [to_json(x) for _, x in sorted(v.items, key=lambda kv: kv[0])]
    d = {'__tag': v.tag} if v.tag else {}
    for k, x in v.items: d[k.decode(ENC) if isinstance(k, bytes) else f'[{fmt_num(k)}]'] = to_json(x)
    return d


def from_json(j, path='$'):
    if isinstance(j, bool): raise FormatError(f'{path}: JSON boolean; Lua 4 has no booleans, use 1 or nil')
    if isinstance(j, (int, float)): return float(j)
    if isinstance(j, str): return j.encode(ENC)
    t = Table()
    if isinstance(j, list):
        for i, x in enumerate(j, 1): t.set(float(i), None if x is None else from_json(x, f'{path}[{i}]'))
    elif isinstance(j, dict):
        for k, x in j.items():
            if k == '__tag': t.tag = int(x); continue
            m = re.fullmatch(r'\[(-?[0-9.eE+-]+)\]', k)
            t.set(float(m.group(1)) if m else k.encode(ENC), None if x is None else from_json(x, f'{path}.{k}'))
    else: raise FormatError(f'{path}: unsupported JSON value {j!r}')
    return t


# Lua literal tokens: 1 skip (space, comments), 2 tag comment, 3 name, 4 number, 5 string, 6 punctuation
TOK = re.compile(r'''(\s+|--\[\[(?!tag \d+\]\]).*?\]\]|--(?!\[\[)[^\n]*)|--\[\[tag (\d+)\]\]|([A-Za-z_]\w*)|'''
                 r'''((?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)|("(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*')|([{}\[\]=,;-])''', re.S | re.A)
ESC = {'n': '\n', 't': '\t', 'r': '\r', 'a': '\a', 'b': '\b', 'f': '\f', 'v': '\v'}


def unquote(s):
    def rep(m):
        e = m.group(1)
        return chr(int(e) & 0xff) if e[0].isdigit() else ESC.get(e, e)
    try: return re.sub(r'\\(\d{1,3}|.)', rep, s[1:-1], flags=re.S).encode(ENC)
    except UnicodeEncodeError: raise FormatError(f'Lua literal: string {s[:30]} has characters outside latin-1; use \\ddd escapes')


def parse_lua(src):
    toks, pos = [], 0
    while pos < len(src):
        m = TOK.match(src, pos)
        if not m: raise FormatError(f'Lua literal: unexpected text at {pos}: {src[pos:pos + 20]!r}')
        pos = m.end()
        if m.group(1) is None:
            kind = next(i for i in range(2, 7) if m.group(i) is not None)
            toks.append((kind, m.group(kind)))
    toks.append((0, 'end of input'))
    st = [0]

    def peek(o=0): return toks[min(st[0] + o, len(toks) - 1)]

    def nxt():
        st[0] += 1
        return toks[min(st[0] - 1, len(toks) - 1)]

    def expect(ch):
        t = nxt()
        if t != (6, ch): raise FormatError(f'Lua literal: expected {ch!r}, found {t[1]!r}')

    def value():
        k, v = nxt()
        if (k, v) == (6, '{'): return table()
        if (k, v) == (6, '-') and peek()[0] == 4: return -float(nxt()[1])
        if k == 4: return float(v)
        if k == 5: return unquote(v)
        if (k, v) == (3, 'nil'): return None
        raise FormatError(f'Lua literal: unexpected {v!r} (only numbers, strings, nil and tables; Lua 4 has no true/false)')

    def table():
        t, n = Table(), 1
        if peek()[0] == 2: t.tag = int(nxt()[1])
        while peek() != (6, '}'):
            if peek() == (6, '['):
                nxt(); key = value()
                if not isinstance(key, (float, bytes)): raise FormatError('Lua literal: [key] must be a number or a string')
                expect(']'); expect('='); t.set(key, value())
            elif peek()[0] == 3 and peek(1) == (6, '='):
                key = nxt()[1].encode(); nxt(); t.set(key, value())
            else:
                t.set(float(n), value()); n += 1
            if peek() in ((6, ','), (6, ';')): nxt()
            elif peek() != (6, '}'): raise FormatError(f'Lua literal: expected , or }} found {peek()[1]!r}')
        nxt()
        return t

    v = value()
    if peek()[0] != 0: raise FormatError(f'Lua literal: trailing text {peek()[1]!r}')
    return v


# ---- commands ----
def cmd_info(a):
    s, d = load(a.save), lambda b: repr(b.decode(ENC))
    print(f'file         {a.save} ({os.path.getsize(a.save)} bytes)\nversion      {s.version}\nname         {d(s.name)}\n'
          f'date/time    {d(s.datetime)}\nlocation     {d(s.location)}\ngame state   {s.state:#x}\nquicksave    {s.qcount}\n'
          f'compressed   {s.clen} bytes at 0x{s.zoff:x}\ninflated     {s.ulen} bytes\n'
          f'trailing     {len(s.trailing)} bytes after the zlib data (expected 0)\nsections (offset, length in the inflated body):')
    for n, o, ln in s.sections: print(f'  {n:<26} 0x{o:08x} {ln:>10}')
    print(f'script       scene {d(s.scene)}, system {d(s.system)}\nGLOBAL_TABLE {len(s.g.items)} globals, '
          f'{s.gend - s.gstart} bytes at 0x{s.gstart:x}\ntriggers     {len(s.triggers)}\ntail String  {d(s.tail)}\nassumptions:')
    seen = {'zlib': f'file has {s.comp[:2].hex()}' + (' (matches)' if s.comp[:2] == b'\x78\xda' else ' (DIFFERS)'),
            'scan': 'file: 17 ids found in order', 'name': f'file: header name {d(s.name)}'}
    for k, t in ASSUMPTIONS: print(f'  - {t}: {seen.get(k, "not checkable from the file")}')


def hint(name):
    return ('; CurrentQuest is a quest label in STREAMID_QuestManager2 (not decoded), not a Lua global '
            '(save-format.md section 4)' if name == 'CurrentQuest' else '')


def cmd_dump(a):
    s = load(a.save)
    if a.triggers:
        rows = [dict(id=t[0], field_04=t[1], sub_04=t[2], sub_id=t[3], str_14=t[4].decode(ENC), str_38=t[5].decode(ENC))
                for t in s.triggers]
        if a.json: return print(json.dumps(rows, indent=1, ensure_ascii=False))
        for r in rows: print(f"{r['id']:>6} {r['field_04']:>8x} {r['sub_04']:>8x} {r['sub_id']:>6}  {r['str_14']!r}  {r['str_38']!r}")
        return
    if a.globl or a.all:
        v = s.g if a.all else s.g.get(a.globl.encode(ENC))
        if v is None: sys.exit(f'savetool: global {a.globl!r} not in the save' + hint(a.globl))
        return print(json.dumps(to_json(v), indent=1, ensure_ascii=False) if a.json
                     else f'{a.globl or "GLOBAL_TABLE"} = {to_lua(v, 0, a.max_depth)}')
    rows = sorted((fmt_key(k), {float: 'number', bytes: 'string', Table: 'table'}[type(v)], len(enc(v)),
                   len(v.items) if isinstance(v, Table) else '') for k, v in s.g.items)
    if a.json: return print(json.dumps([dict(name=r[0], type=r[1], bytes=r[2], entries=r[3]) for r in rows], indent=1))
    print(f'{"name":<40} {"type":<7} {"bytes":>8} entries')
    for r in rows: print(f'{r[0]:<40} {r[1]:<7} {r[2]:>8} {r[3]}')


def cmd_get(a):
    v = load(a.save).g.get(a.globl.encode(ENC))
    if v is None: print('nil'); sys.exit(f'savetool: global {a.globl!r} not in the save' + hint(a.globl))
    print(json.dumps(to_json(v), ensure_ascii=False) if a.json else to_lua(v))


def cmd_set(a):
    if os.path.abspath(a.out) == os.path.abspath(a.save): sys.exit('savetool: --out must differ from the input save')
    stem = os.path.basename(a.out)[:-4] if a.out.endswith('.sav') else ''
    name = a.name or stem
    if not stem or not name or any(c in name for c in BADCH):
        sys.exit(f'savetool: bad --out/--name {a.out!r}/{name!r} (file must end in .sav, name must not contain {BADCH})')
    if name != stem: print(f'warning: header name {name!r} differs from the file name {stem!r}', file=sys.stderr)
    s = load(a.save)
    if a.nil: v = None
    elif a.lua is not None: v = parse_lua(a.lua)
    else:
        with open(a.json) as f: v = from_json(json.load(f))
    key = a.globl.encode(ENC)
    if v is not None and reserved(key):
        print(f'warning: global {a.globl!r} is a reserved name; it loads but the next in-game save drops it', file=sys.stderr)
    if v is not None: validate(v, a.globl, lambda m: print('warning: ' + m, file=sys.stderr))
    old = s.g.get(key)
    s.g.set(key, v)
    data, ulen, size = s.to_bytes(name.encode(ENC)), len(s.build_body()), os.path.getsize(a.save)
    Save(data, a.out)  # re-parse the result before writing it
    with open(a.out, 'wb') as f: f.write(data)
    print(f'{a.out}: {a.globl} {("removed" if old is not None else "was absent, unchanged") if v is None else "replaced" if old is not None else "added"}; '
          f'inflated {s.ulen} -> {ulen} ({ulen - s.ulen:+d}), file {size} -> {len(data)} ({len(data) - size:+d}) bytes')


def first_diff(x, y): return next((i for i, (p, q) in enumerate(zip(x, y)) if p != q), min(len(x), len(y)))


def roundtrip(s):
    errs, g, orig = [], enc(s.g), s.body[s.gstart:s.gend]
    if g != orig: errs.append(f'GLOBAL_TABLE differs at body 0x{s.gstart + first_diff(g, orig):x}')
    b = s.build_body()
    if b != s.body: errs.append(f'body differs at 0x{first_diff(b, s.body):x}')
    h = s.build_header(s.name, s.clen, s.ulen)
    if h != s.header: errs.append(f'header differs at file 0x{first_diff(h, s.header):x}')
    comp = zlib.compress(b, 9)
    if zlib.decompress(comp) != s.body: errs.append('re-deflated data does not inflate to the same body')
    return errs, comp == s.comp


def cmd_roundtrip(a):
    errs, same = roundtrip(load(a.save))
    for e in errs: print('DIFF: ' + e)
    print('compressed bytes ' + ('identical to the original (stock zlib, level 9)' if same else
                                 'differ from the original (other zlib build or level; fine while inflate matches)'))
    print('FAIL' if errs else 'OK')
    sys.exit(1 if errs else 0)


EXAMPLE_HEX = ('0200000003000000545246030000000200000001000000730200000001000000780200000001000000740300000001000000'
               '000000000000f03f01000000000000000000f03f0100000000000000000000400100000000000000000000400400000000'
               '000000020000000700000076657273696f6e01000000000000000000f03f02000000010000006e01000000000000000000'
               '00400400000000000000')


def synthetic_save(g, triggers=((1, 0, 0, 2, b'cond', b'act'),)):
    body = bytearray()
    for n in SECTIONS:
        body += MARK; wr_str(body, n.encode())
        if n != 'STREAMID_Script':
            body += bytes(range(len(n)))  # filler
            continue
        wr_str(body, b'scene'); wr_str(body, b'Sol')
        body += P(0x2c) + P(2); wr_str(body, b'GLOBAL_TABLE'); wr_value(body, g); body += P(len(triggers))
        for t in triggers: body += P(t[0]) + P(t[1]) + P(t[2]) + P(t[3]); wr_str(body, t[4]); wr_str(body, t[5])
        wr_str(body, b'')
    comp, h = zlib.compress(bytes(body), 9), bytearray()
    wr_str(h, b'SAV'); h += P(7)
    for x in (b'Synth', b'10/20/26 12:00:00', b'Sol'): wr_str(h, x)
    h += P(0x13) + P(0); wr_str(h, b'FullStorage')
    return bytes(h + P(len(comp)) + P(len(body)) + comp)


def cmd_selftest(a):
    fails = []

    def check(ok, what):
        print(('ok   ' if ok else 'FAIL ') + what)
        if not ok: fails.append(what)
    doc, exp_hex = os.path.join(os.path.dirname(os.path.abspath(__file__)), '../design/mod-research/save-format.md'), EXAMPLE_HEX
    if os.path.exists(doc):
        sec5 = open(doc, encoding='utf-8').read().split('## 5.')[1].split('## 6.')[0]
        exp_hex = ''.join(''.join(m.group(1).split()) for m in re.finditer(r'^[0-9a-f]{4}: ((?:[0-9a-f]{2} )+)', sec5, re.M))
        check(exp_hex == EXAMPLE_HEX, 'save-format.md section 5 hex equals the copy in savetool')
    else: print('note: save-format.md not found, using the built-in copy of the section 5 hex')
    trf = Table([(b's', b'x'), (b't', Table([(1.0, 1.0), (2.0, 2.0)])), (b'version', 1.0), (b'n', 2.0)])  # host lua_next order
    frag = enc(b'TRF') + enc(trf)
    check(frag.hex() == exp_hex and len(frag) == 158, 'TRF={version=1,n=2,s="x",t={1,2}} in s,t,version,n order encodes to the doc hex')
    r = R(bytes.fromhex(exp_hex))
    check(rd_value(r) == b'TRF' and tree_eq(rd_value(r), parse_lua('{version=1, n=2, s="x", t={1,2}}')) and r.p == 158,
          'doc hex decodes to the same tree as the Lua literal')
    nested = parse_lua('{ [1]=1, [-2.5]="neg", ["a b"]={ x={ y={ z="deep" } } }, tagged={ --[[tag 3]] k=1 }, s="q\\"\\n\\200" }')
    nested.set(b'nul', b'a\0b')
    r = R(enc(nested))
    check(tree_eq(rd_value(r), nested) and r.p == len(r.b), 'nested tables, number keys, tag index, escapes, NUL bytes round-trip (grammar level)')
    try: validate(nested, 'T', lambda m: None); check(False, 'set refuses strings with NUL')
    except FormatError: check(True, 'set refuses strings with NUL (the game cuts them)')
    big = Table([(float(i), Table([(b'sys', b's%d' % i), (b't', float(i))])) for i in range(1, 1001)])
    b = enc(big)
    check(tree_eq(rd_value(R(b)), big), f'1000-entry table round-trips ({len(b)} bytes)')
    v1 = parse_lua('{version=1,active=1,gen=0,clock={game=0,real=0},exp={state={n=7,s="x",t={1,2,{3}},PI=5}}}')
    check(tree_eq(parse_lua(to_lua(v1)), v1) and tree_eq(from_json(json.loads(json.dumps(to_json(v1)))), v1)
          and tree_eq(parse_lua(to_lua(nested)), nested), 'Lua and JSON text forms re-parse to the same tree')
    warns = []
    validate(v1, 'TRF', warns.append)
    check(len(warns) == 1 and 'TRF.exp.state.PI' in warns[0], 'nested PI key is reported as reserved')
    with tempfile.TemporaryDirectory() as d:
        src, dst, nil = (os.path.join(d, n + '.sav') for n in ('Synth', 'Synth-trf-v1', 'Synth-trf-nil'))
        g = Table([(b'MAP_NAME', b'Sol'), (b'g_count', 3.0), (b'cfg', Table([(b'a', 1.0)]))])
        with open(src, 'wb') as f: f.write(synthetic_save(g))
        s = load(src)
        errs, same = roundtrip(s)
        check(not errs and same and len(s.triggers) == 1, 'synthetic save parses and round-trips byte-identical')
        ns = lambda **k: argparse.Namespace(**{**dict(globl='TRF', name=None, nil=False, json=None, lua=None), **k})
        cmd_set(ns(save=src, out=dst, lua=to_lua(v1)))
        s2 = load(dst)
        check(tree_eq(s2.g.get(b'TRF'), v1) and s2.name == b'Synth-trf-v1' and not roundtrip(s2)[0] and len(s2.g.items) == 4,
              'set adds TRF, renames the header, result round-trips')
        cmd_set(ns(save=dst, out=nil, nil=True))
        check(load(nil).g.get(b'TRF') is None and tree_eq(load(nil).g, g), 'set --nil removes TRF')
        for bad, msg in ((b'\x03\0\0\0SAX', 'not a SW3 save'), (synthetic_save(g).replace(b'\x07\0\0\0', b'\x08\0\0\0', 1), 'version 8')):
            try: Save(bad, 'bad'); check(False, f'rejects bad {msg}')
            except FormatError as e: check(msg in str(e), f'rejects bad {msg}: {e}')
    print('selftest ' + (f'FAILED: {len(fails)}' if fails else 'passed'))
    sys.exit(1 if fails else 0)


def main():
    ap = argparse.ArgumentParser(description='Read and edit SW3 .sav files (format: save-format.md).')
    sub = ap.add_subparsers(dest='cmd', required=True)
    p = sub.add_parser('info', help='header, sizes, sections, assumptions'); p.add_argument('save')
    p = sub.add_parser('dump', help='list globals; one (--global), all (--all) or --triggers')
    p.add_argument('save'); p.add_argument('--global', dest='globl'); p.add_argument('--all', action='store_true')
    p.add_argument('--max-depth', type=int, default=99); p.add_argument('--json', action='store_true')
    p.add_argument('--triggers', action='store_true')
    p = sub.add_parser('get', help='print one global')
    p.add_argument('save'); p.add_argument('--global', dest='globl', required=True); p.add_argument('--json', action='store_true')
    p = sub.add_parser('set', help='replace, add or remove one top-level global')
    p.add_argument('save'); p.add_argument('--out', required=True); p.add_argument('--global', dest='globl', required=True)
    p.add_argument('--name', help='header save name (default: the --out file name without .sav)')
    g = p.add_mutually_exclusive_group(required=True)
    g.add_argument('--lua', help='Lua table literal, e.g. \'{version=1, s="x"}\'')
    g.add_argument('--json', help='JSON file (tables: object or array; number keys as "[n]")')
    g.add_argument('--nil', action='store_true', help='remove the global')
    p = sub.add_parser('roundtrip', help='decode and re-encode without changes'); p.add_argument('save')
    sub.add_parser('selftest', help='built-in tests (no save needed)')
    a = ap.parse_args()
    try: globals()['cmd_' + a.cmd](a)
    except FormatError as e: sys.exit(f'savetool: {e}')


if __name__ == '__main__':
    main()
