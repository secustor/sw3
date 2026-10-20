#!/usr/bin/env python3
"""Lint traffic mod *.script files for Lua 4.0.1 and SW3 engine pitfalls.

Usage: python3 -I lint_lua.py [--host] [--allow NAME[,NAME]] [--bool NAME[,NAME]] FILE...
Exit status 1 when any finding is reported. Token-based heuristics, not a parser.
--host: Lua 4 syntax checks only, for host harness files that define engine natives and constants.
"""
import argparse
import re
import sys

# ClearGlobals / save skip list at 0x7acae8 (mod-options 1.8)
RESERVED = set("_CLASS PI _VERSION _INPUT _OUTPUT _STDERR _STDIN _STDOUT _script_error_output "
               "sys_IncludeFileList _script_path _script_error_filename TRUE FALSE PLAYER_TEAM "
               "PLAYER_GROUP PLAYER_MOTHERSHIP EASY NORMAL HARD NOINIT".split())
RESERVED_PREFIX = ("_EVENT_", "ROLE_", "RELATION_", "QUEST_", "MISSION_")
# game Lua helpers that return FALSE (= 0, which is true in Lua 4): a bare test is always true
BOOL_FUNCS = set("NewAllFlight NewFlight NewShip CreateMyFlight FillCargo FillCargoSimple "
                 "FillTraderSimple IsAlienShip IsCanMountPilot PilotIsFearless ShipCanBePoisoned "
                 "Anybody_Home Test_Artifacts Test_Count Test_Nearest _GetRelationsFmerc "
                 "ComputeProbability".split())
# natives that push 1 or nil (IsExist 0x5edcb0, IsAlive, HavePerk): '== FALSE' is never true
NIL_NATIVES = {"IsExist", "IsAlive", "HavePerk"}
KEYWORDS = set("and break do else elseif end for function if in local nil not or repeat "
               "return then until while".split())
PREFIX = "TRF_"

TOKEN = re.compile(r"""
    (?P<nl>\n)
  | (?P<ws>[ \t\r\f\v]+)
  | (?P<comment>--[^\n]*)
  | (?P<long>\[\[.*?\]\])
  | (?P<str>"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*')
  | (?P<num>(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)
  | (?P<name>[A-Za-z_]\w*)
  | (?P<op>==|~=|<=|>=|\.\.\.|\.\.|\S)
""", re.S | re.X)


def tokenize(text):
    toks, line = [], 1
    for m in TOKEN.finditer(text):
        kind, val = m.lastgroup, m.group()
        if kind in ("ws", "comment"):
            pass
        elif kind == "nl":
            line += 1
            continue
        else:
            toks.append((kind, val, line))
        line += val.count("\n") if kind == "long" else 0
    return toks


def reserved(name):
    return name in RESERVED or name.startswith(RESERVED_PREFIX)


def lint(path, allow, bools, host=False):
    with open(path, "r", encoding="latin-1", newline="") as f:
        toks = tokenize(f.read())
    out = []
    add = lambda ln, msg: out.append("%s:%d: %s" % (path, ln, msg))
    v = [t[1] for t in toks]
    kinds = [t[0] for t in toks]
    n = len(toks)
    stack = []      # block kinds: 'f' function, 'b' other block
    braces = 0
    for i, (kind, val, ln) in enumerate(toks):
        prev = v[i - 1] if i else ""
        nxt = v[i + 1] if i + 1 < n else ""
        in_func = "f" in stack
        if kind == "name":
            if val in ("true", "false"):
                add(ln, "'%s' is not a Lua 4 literal; use TRUE/FALSE or nil" % val)
            elif val == "local" and nxt == "function":
                add(ln, "'local function' is not Lua 4; use 'local f = function() end'")
            elif val == "function":
                if not host and i + 2 < n and kinds[i + 1] == "name" and v[i + 2] in ("(", ".", ":"):
                    root = v[i + 1]
                    if v[i + 2] == ":":
                        add(ln, "method definition '%s:%s' (function in a table is lost on save)"
                            % (root, v[i + 3] if i + 3 < n else "?"))
                    elif v[i + 2] == ".":
                        add(ln, "function stored in table '%s' (lost on save)" % root)
                    elif prev != "local" and not root.startswith(PREFIX) and root not in allow:
                        add(ln, "global function '%s' lacks the %s prefix" % (root, PREFIX))
                stack.append("f")
            elif val in ("if", "do", "repeat"):
                stack.append("b")
            elif val in ("end", "until"):
                if stack:
                    stack.pop()
            elif not host and (val in bools or val in NIL_NATIVES) and nxt == "(":
                k = i
                while k >= 2 and v[k - 1] in (".", ":") and kinds[k - 2] == "name":
                    k -= 2
                before = v[k - 1] if k else ""
                depth, j = 0, i + 1
                while j < n:
                    depth += (v[j] == "(") - (v[j] == ")")
                    if depth == 0:
                        break
                    j += 1
                after = v[j + 1] if j + 1 < n else ""
                if val in NIL_NATIVES:
                    if (after in ("==", "~=") and j + 2 < n and v[j + 2] == "FALSE") or (
                            before in ("==", "~=") and k >= 2 and v[k - 2] == "FALSE"):
                        add(ln, "%s() returns 1 or nil; '== FALSE' never matches, use 'not'" % val)
                elif before not in ("==", "~=") and after not in ("==", "~=") and (
                        after in ("then", "and", "or", "do")
                        or before in ("if", "elseif", "while", "until", "not", "and", "or")):
                    add(ln, "bare boolean test of %s(); compare with == TRUE / == FALSE" % val)
            # reserved names used as keys
            if not host and reserved(val) and nxt == "=" and (prev == "." or (braces and prev in ("{", ",", ";"))):
                add(ln, "reserved name '%s' used as a table key (dropped by save/clear)" % val)
        elif kind == "str" and not host and reserved(val[1:-1]) and prev == "[" and i + 2 < n \
                and v[i + 1] == "]" and v[i + 2] == "=":
            add(ln, "reserved name %s used as a table key (dropped by save/clear)" % val)
        elif kind == "op":
            if val == "{":
                braces += 1
            elif val == "}":
                braces = max(0, braces - 1)
            elif val == "#":
                add(ln, "'#' is not Lua 4; use getn()")
            elif val == "%" and (kinds[i - 1] in ("num", "str") or prev in (")", "]")
                                 or (kinds[i - 1] == "name" and prev not in KEYWORDS)):
                add(ln, "'%' operator is not Lua 4; use mod() (%name is upvalue syntax)")
            elif val == "=" and not in_func and not braces and not host:
                check_assign(toks, i, allow, add)
    return out


def check_assign(toks, i, allow, add):
    """Top-level (outside any function) assignment: LHS roots must carry the prefix."""
    ln = toks[i][2]
    j = i - 1
    while j >= 0 and toks[j][2] == ln and not (toks[j][0] == "name" and toks[j][1] in KEYWORDS):
        j -= 1
    if j >= 0 and toks[j][2] == ln and toks[j][1] in ("local", "for"):
        return
    lhs = toks[j + 1:i]
    starts, expect = [], True
    for t in lhs:
        if expect:
            starts.append(t)
        expect = t[1] == ","
    for t in starts:
        if t[0] == "name" and not t[1].startswith(PREFIX) and t[1] not in allow:
            add(ln, "top-level assignment to '%s' (not %s-prefixed, or data at load time)" % (t[1], PREFIX))
    # A TRF_ name may hold a function (definition or saved original), never data: data globals are
    # cleared on entry and replaced by the save restore. Data = constructor, literal or call result.
    k = i + 1
    if k < len(toks) and toks[k][1] != "function" and (
            toks[k][1] == "{" or toks[k][0] in ("num", "str", "long")
            or (toks[k][0] == "name" and toks[k][1] not in KEYWORDS and k + 1 < len(toks)
                and toks[k + 1][1] in ("(", ".", "[", ":", "..", "+", "-", "*", "/"))):
        for t in starts:
            if t[0] == "name" and t[1].startswith(PREFIX) and t[1] not in allow:
                add(ln, "top-level data assignment to '%s' (only functions may be set at load time)" % t[1])


def names(vals):
    return {x for s in vals for x in s.split(",") if x}


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--allow", action="append", default=[],
                    help="game globals that may be assigned at top level (wrappers)")
    ap.add_argument("--bool", action="append", default=[],
                    help="extra functions returning TRUE/FALSE")
    ap.add_argument("--host", action="store_true",
                    help="host harness file: only the Lua 4 syntax checks")
    ap.add_argument("files", nargs="+")
    a = ap.parse_args()
    allow, bools = names(a.allow), BOOL_FUNCS | names(a.bool)
    found = []
    for p in a.files:
        found += lint(p, allow, bools, a.host)
    for line in found:
        print(line)
    print("%d finding(s) in %d file(s)" % (len(found), len(a.files)), file=sys.stderr)
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main())
