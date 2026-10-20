#!/usr/bin/env python3
"""Static check of the traffic hook sites and Lua API prologues in sw3cw.exe.

Read-only on the exe. Run with: python3 -I check_sites.py [--exe P] [--asm P] [--write-header P]
Exit status 1 on any mismatch (SHA-1, site opcode, rel32 target, branch into a site).
"""
import argparse
import hashlib
import os
import re
import struct
import sys

GAME = "/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/sw3cw.exe"
SHA1 = "57420a056f63a869148556dd978e5e2478e7ba2d"

# mod-options.md 5.2
SITES = [
    ("T1", 0x6556d7, 0x5c7e80),
    ("T2a", 0x5d19e4, 0x5c91f0),
    ("T2b", 0x4b0113, 0x5c91f0),
    ("T2c", 0x4b01c6, 0x5c91f0),
    ("T2d", 0x4a4f21, 0x5c91f0),
    ("T3", 0x4dd207, 0x5d1ce0),
    ("T4", 0x4a074e, 0x49d4a0),
]

# mod-options.md section 1, Lua C API list
APIS = [
    ("lua_gettop", 0x65de50), ("lua_settop", 0x65de60),
    ("lua_pushvalue", 0x65df50), ("lua_type", 0x65dfa0),
    ("lua_isnumber", 0x65dfe0), ("lua_isstring", 0x65e020),
    ("lua_tag", 0x65e050), ("lua_tonumber", 0x65e0c0),
    ("lua_tostring", 0x65e100), ("lua_pushnil", 0x65e1d0),
    ("lua_pushnumber", 0x65e200), ("lua_pushlstring", 0x65e240),
    ("lua_pushstring", 0x65e280), ("lua_pushcclosure", 0x65e2c0),
    ("lua_getglobal", 0x65e340), ("lua_gettable", 0x65e3a0),
    ("lua_rawget", 0x65e3f0), ("lua_rawgeti", 0x65e440),
    ("lua_getglobals", 0x65e4b0), ("lua_newtable", 0x65e560),
    ("lua_setglobal", 0x65e5a0), ("lua_settable", 0x65e5d0),
    ("lua_rawset", 0x65e610), ("lua_rawseti", 0x65e670),
    ("lua_rawcall", 0x65e7a0), ("lua_next", 0x65e860),
    ("lua_getn", 0x65e8f0), ("lua_call", 0x65f530),
    ("lua_dobuffer", 0x65f7b0), ("lua_dostring", 0x65f7e0),
]

# sw3tp (trackpad) patch sites, 5 bytes each; traffic sites must not overlap
TP_SITES = [0x4a0632, 0x4a0765, 0x5958b0]

BRANCH = re.compile(r"^\s*([0-9a-f]+):\s+(j[a-z]+|calll|loop[a-z]*)\s+0x([0-9a-f]+)\b")


class PE:
    def __init__(self, data):
        self.data = data
        if data[:2] != b"MZ":
            raise ValueError("not an MZ file")
        pe = struct.unpack_from("<I", data, 0x3C)[0]
        if data[pe:pe + 4] != b"PE\0\0":
            raise ValueError("no PE signature")
        nsec, = struct.unpack_from("<H", data, pe + 6)
        optsz, = struct.unpack_from("<H", data, pe + 20)
        opt = pe + 24
        if struct.unpack_from("<H", data, opt)[0] != 0x10B:
            raise ValueError("not PE32")
        self.base = struct.unpack_from("<I", data, opt + 28)[0]
        self.secs = []
        off = opt + optsz
        for i in range(nsec):
            name = data[off:off + 8].rstrip(b"\0").decode("latin-1")
            vsz, va, rawsz, rawp = struct.unpack_from("<IIII", data, off + 8)
            self.secs.append((name, va, max(vsz, rawsz), rawsz, rawp))
            off += 40

    def off(self, va):
        rva = va - self.base
        for name, sva, size, rawsz, rawp in self.secs:
            if sva <= rva < sva + size:
                if rva - sva >= rawsz:
                    raise ValueError("0x%x is in uninitialised data of %s" % (va, name))
                return rawp + rva - sva
        raise ValueError("0x%x is not in any section" % va)

    def read(self, va, n):
        o = self.off(va)
        return self.data[o:o + n]


def hexb(b):
    return " ".join("%02x" % x for x in b)


def cbytes(b):
    return "{" + ",".join("0x%02x" % x for x in b) + "}"


def scan_asm(path, sites):
    """Return (caller counts per target, branch hits into site+1..+4, site lines)."""
    targets = {t for _, _, t in sites}
    calls = {t: 0 for t in targets}
    jumps = {t: 0 for t in targets}
    ranges = [(s + 1, s + 4, sid) for sid, s, _ in sites]
    lo = min(r[0] for r in ranges)
    hi = max(r[1] for r in ranges)
    hits = []
    lines = {}
    siteaddrs = {s: sid for sid, s, _ in sites}
    with open(path, "r", encoding="latin-1") as f:
        for line in f:
            m = BRANCH.match(line)
            if not m:
                continue
            src, mn, dst = int(m.group(1), 16), m.group(2), int(m.group(3), 16)
            if src in siteaddrs:
                lines[src] = (mn, dst)
            if dst in targets:
                if mn == "calll":
                    calls[dst] += 1
                else:
                    jumps[dst] += 1
            if lo <= dst <= hi:
                for a, b, sid in ranges:
                    if a <= dst <= b:
                        hits.append((sid, src, mn, dst))
    return calls, jumps, hits, lines


def scan_dwords(data, sites):
    """Absolute dwords anywhere in the file that point into site+1..+4 (jump tables, pointers)."""
    out = []
    for sid, s, _ in sites:
        for v in range(s + 1, s + 5):
            pat = struct.pack("<I", v)
            i = data.find(pat)
            while i >= 0:
                out.append((sid, v, i))
                i = data.find(pat, i + 1)
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--exe", default=GAME)
    ap.add_argument("--asm", default=None, help="path to .work/exe.asm (optional)")
    ap.add_argument("--write-header", default=None, metavar="PATH")
    a = ap.parse_args()

    bad = 0
    with open(a.exe, "rb") as f:
        data = f.read()
    sha = hashlib.sha1(data).hexdigest()
    ok = sha == SHA1
    print("sha1 %s %s" % (sha, "ok" if ok else "MISMATCH (expected %s)" % SHA1))
    bad += not ok

    pe = PE(data)
    print("image base 0x%x" % pe.base)
    for name, va, size, rawsz, rawp in pe.secs:
        print("  section %-8s va 0x%06x size 0x%06x raw 0x%06x at 0x%06x"
              % (name, pe.base + va, size, rawsz, rawp))

    site_bytes = {}
    for sid, s, t in SITES:
        b = pe.read(s, 5)
        site_bytes[sid] = b
        dec = (s + 5 + struct.unpack("<i", b[1:5])[0]) & 0xFFFFFFFF if len(b) == 5 else None
        good = len(b) == 5 and b[0] == 0xE8 and dec == t
        print("site %-3s 0x%06x file 0x%06x bytes %s -> %s %s"
              % (sid, s, pe.off(s), hexb(b), "0x%x" % dec if dec is not None else "?",
                 "ok" if good else "MISMATCH (expected E8 -> 0x%x)" % t))
        bad += not good

    for sid, s, _ in SITES:
        for tp in TP_SITES:
            if s < tp + 5 and tp < s + 5:
                print("OVERLAP %s 0x%06x with sw3tp site 0x%06x" % (sid, s, tp))
                bad += 1

    api_bytes = {}
    for name, va in APIS:
        api_bytes[name] = pe.read(va, 16)
        print("api  %-16s 0x%06x %s" % (name, va, hexb(api_bytes[name])))

    if a.asm and os.path.isfile(a.asm):
        calls, jumps, hits, lines = scan_asm(a.asm, SITES)
        for sid, s, t in SITES:
            ln = lines.get(s)
            good = ln == ("calll", t)
            print("asm  %-3s 0x%06x %s" % (sid, s, "calll 0x%x ok" % t if good
                                          else "MISMATCH %r" % (ln,)))
            bad += not good
        for t in sorted(calls):
            ids = ",".join(sid for sid, _, tt in SITES if tt == t)
            print("callers 0x%06x (%s): %d call, %d jmp/jcc" % (t, ids, calls[t], jumps[t]))
        for sid, src, mn, dst in hits:
            print("BRANCH INTO SITE %s: 0x%06x %s 0x%06x" % (sid, src, mn, dst))
        print("branch scan: %d branches into site+1..+4" % len(hits))
        bad += len(hits)
    else:
        print("notice: no --asm file, caller count and branch scan skipped")

    dw = scan_dwords(data, SITES)
    for sid, v, o in dw:
        print("dword 0x%06x (inside %s) at file offset 0x%x" % (v, sid, o))
    print("dword scan: %d absolute pointers into site+1..+4 (informational)" % len(dw))

    if a.write_header:
        out = ["/* generated by mods/traffic/tools/check_sites.py; do not edit */",
               '#define TRF_EXE_SHA1 "%s"' % SHA1,
               "#define TRF_SITE_COUNT %d" % len(SITES),
               "#define TRF_SITES { " + ", ".join(
                   '{"%s",0x%x,0x%x,%s}' % (sid, s, t, cbytes(site_bytes[sid]))
                   for sid, s, t in SITES) + " }",
               "#define TRF_API_COUNT %d" % len(APIS),
               "#define TRF_APIS { " + ", \\\n  ".join(
                   '{"%s",0x%x,%s}' % (n, va, cbytes(api_bytes[n])) for n, va in APIS) + " }",
               ""]
        if bad:
            print("header not written: %d mismatch(es)" % bad)
        else:
            with open(a.write_header, "w", newline="\n") as f:
                f.write("\n".join(out))
            print("wrote %s" % a.write_header)

    print("result: %s" % ("ok" if not bad else "%d mismatch(es)" % bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
