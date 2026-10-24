#!/usr/bin/env python3
"""Lint traffic mod *.script files for Lua 4.0.1 and SW3 engine pitfalls.

Usage: python3 -I lint_lua.py [--host] [--allow NAME[,NAME]] [--bool NAME[,NAME]] FILE...
       python3 -I lint_lua.py --calls [-v] [-q] FILE...
Exit status 1 when any finding is reported. Token-based heuristics, not a parser.
--host: Lua 4 syntax checks only, for host harness files that define engine natives and constants.
--calls: cross-file check of TRF_ definitions and references; exit status 1 only on errors. It also compares the
literal "key = text" pairs of the TRF_<M>_Text() tables: one key (normalised like trf_loc TRF_LocKey) with two
different texts is an error, because trf_loc's merge keeps only the first.
Log keys (mod scripts, not --host; design/log-format.md): TRF_Lf(module, event, k1, v1, ...) needs literal
snake_case module and event ([a-z][a-z0-9_]*), a module wrapper TRF_<Mod>E(event, k1, v1, ...) a literal
snake_case event; every key that is a string literal (Lf: 3rd, 5th, ...; *E: 2nd, 4th, ...) must be snake_case.
The pre-logfmt string helpers (TRF_<Mod>L, TRF_<Mod>Dbg) are findings, as is TRF_L outside traffic.script.
Group names: a "TRF_<Name>_" or "TRF_G<Name>_" literal joined with '..' must use a name of GROUP_PREFIXES.
"""
import argparse
import os
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
SNAKE = re.compile(r"[a-z][a-z0-9_]*$")
LOG_WRAPPER = re.compile(r"TRF_[A-Za-z]*E$")    # module log wrapper TRF_<Mod>E(event, k1, v1, ...)
OLD_LOG = re.compile(r"TRF_(L|[A-Za-z]*(L|Dbg))$")  # pre-logfmt string helpers: only TRF_Lf may call TRF_L
# Group and allocator prefixes (design/worldbuilding/00-economy-and-progression.md section 6, "Group and allocator
# names"; design/wb-plumbing-spec.md 9): a "TRF_<Name>_" literal joined with '..' (a group name built at run time)
# or its group global "TRF_G<Name>_" must use a listed name. All-capital names are labels, not groups.
GROUP_PREFIXES = set("Raid Pir Resp Trade Feq Conv Sweep SwP PBase Car "
                     "Cust Scv Cap Esc Def Pick Push Merc Rival Hunt Fw Drop Sh Nest".split())
GROUP_LIT = re.compile(r'"TRF_(G?)([A-Z][A-Za-z]*)_"$')

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
            elif not host and nxt == "(" and prev not in ("function", ".", ":") and (
                    val == "TRF_Lf" or LOG_WRAPPER.match(val)):
                check_log_call(toks, i, add)
            elif not host and nxt == "(" and prev not in ("function", ".", ":") and OLD_LOG.match(val) and (
                    val != "TRF_L" or os.path.basename(path) != "traffic.script"):
                add(toks[i][2], "%s: string log helper; use TRF_Lf or the module's TRF_<Mod>E wrapper (design/log-format.md)" % val)
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
        elif kind == "str" and not host and nxt == ".." and GROUP_LIT.match(val):
            gm = GROUP_LIT.match(val)
            if not gm.group(2).isupper() and gm.group(2) not in GROUP_PREFIXES:
                add(ln, "group prefix %s is not in GROUP_PREFIXES (00 section 6 allocator list)" % val)
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


def call_args(toks, i):
    """Token ranges [(start, end)) of the arguments of the call whose '(' is token i."""
    args, depth, start, j = [], 0, i + 1, i
    while j < len(toks):
        kind, t = toks[j][0], toks[j][1]
        if kind == "op" and t in ("(", "{", "["):
            depth += 1
        elif kind == "op" and t in (")", "}", "]"):
            depth -= 1
            if depth == 0:
                break
        elif t == "," and depth == 1:
            args.append((start, j))
            start = j + 1
        j += 1
    if j > i + 1:
        args.append((start, j))
    return args


def check_log_call(toks, i, add):
    """TRF_Lf(module, event, k, v, ...) / TRF_<Mod>E(event, k, v, ...): literal snake_case names and keys."""
    name, ln = toks[i][1], toks[i][2]
    args = call_args(toks, i + 1)
    if name != "TRF_Lf" and not args:
        return          # TRF_GenThunkCE(): not a log wrapper
    fixed = ("module", "event") if name == "TRF_Lf" else ("event",)
    lit = lambda a: a[1] - a[0] == 1 and toks[a[0]][0] == "str"
    for k, what in enumerate(fixed):
        if k >= len(args) or not lit(args[k]):
            add(ln, "%s: %s (argument %d) must be a literal snake_case string" % (name, what, k + 1))
        elif not SNAKE.match(toks[args[k][0]][1][1:-1]):
            add(ln, "%s: %s %s is not snake_case" % (name, what, toks[args[k][0]][1]))
    for k in range(len(fixed), len(args), 2):
        a = args[k]
        if lit(a) and not SNAKE.match(toks[a[0]][1][1:-1]):
            add(toks[a[0]][2], "%s: key %s (argument %d) is not snake_case" % (name, toks[a[0]][1], k + 1))


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


# ---- --calls: cross-file check of the mod's own TRF_ functions ----
NATIVES = set("TRF_Version TRF_GameTime TRF_RealTime TRF_Log TRF_InMovie TRF_UiState".split())  # pe/traffic.c
TOLERANT = {"TRF_N", "TRF_P", "getglobal"}    # look the name up and skip a missing function
TRF_NAME = re.compile(r"TRF_\w+$")
TRF_ACTION = re.compile(r"(TRF_\w+)\s*\(")    # string trigger action "TRF_Name(..."
OPEN = {"(": ")", "{": "}", "[": "]"}


def tolerant(callee, k, tol):
    """Call passes argument k to getglobal + type check (TRF_N, TRF_P, *X helpers, auto-detected)."""
    return (k == 0 and (callee in TOLERANT or re.match(r"TRF_\w*X$", callee or ""))) or (callee, k) in tol


def str_kind(callee, k):
    if callee and callee.endswith("Due"):
        return "due"
    if callee and re.search(r"Cb\d*$", callee):
        return "cb"
    return "str"


_TOKENS = {}


def file_tokens(path):
    """Tokens of path, read once per run (scan_calls and text_keys share them)."""
    if path not in _TOKENS:
        with open(path, "r", encoding="latin-1", newline="") as f:
            _TOKENS[path] = tokenize(f.read())
    return _TOKENS[path]


def scan_calls(path):
    """Definitions, global assignments and TRF_ references of one file."""
    toks = file_tokens(path)
    v = [t[1] for t in toks]
    kinds = [t[0] for t in toks]
    n = len(toks)
    defs, assigns, refs, guards, tolp = [], set(), [], set(), []
    stack, brackets = [], []    # block stack ('f'/'b'); open brackets [kind, callee, argidx]
    scope, sname, params = None, None, []    # current top-level function (token index) and its parameters
    for i, (kind, val, ln) in enumerate(toks):
        prev = v[i - 1] if i else ""
        nxt = v[i + 1] if i + 1 < n else ""
        if kind == "name":
            if val == "function":
                if not stack:
                    scope, sname, params = i, None, []
                name, j = None, i            # j: token before the parameter list
                if i + 2 < n and kinds[i + 1] == "name" and v[i + 2] == "(":
                    name, j = v[i + 1], i + 1
                elif prev == "=" and i >= 2 and kinds[i - 2] == "name" and (i < 3 or v[i - 3] not in (".", ":", "local")):
                    name = v[i - 2]          # TRF_X = function(...)
                if not stack:
                    sname = name
                if j + 1 < n and v[j + 1] == "(":
                    k, ps, va = j + 2, [], False
                    while k < n and v[k] != ")":
                        if v[k] == "...":
                            va = True
                        elif kinds[k] == "name":
                            ps.append(v[k])
                        k += 1
                    if not stack:
                        params = ps
                    if name and name.startswith(PREFIX):
                        defs.append((name, len(ps), va, ln, not stack and j == i + 1, path))
                stack.append("f")
            elif val in ("if", "do", "repeat"):
                stack.append("b")
            elif val in ("end", "until"):
                if stack:
                    stack.pop()
                if not stack:
                    scope, sname, params = None, None, []
            elif val == "getglobal" and nxt == "(" and i + 3 < n and v[i + 3] == ")" and v[i + 2] in params:
                if sname:
                    tolp.append((sname, params.index(v[i + 2])))
            elif val.startswith(PREFIX) and prev not in (".", ":", "function"):
                if prev == "(" and i >= 2 and v[i - 2] == "type" and nxt == ")":
                    guards.add((scope, val))
                elif nxt == "=" and prev != "local":
                    assigns.add(val)
                elif nxt in ("(", "{") or kinds[i + 1:i + 2] == ["str"]:
                    refs.append(("call", val, ln, scope) + count_args(toks, i + 1))
                elif prev != "local" and not (nxt == "," and not brackets):    # not a multiple-assignment target
                    refs.append(("val", val, ln, scope, None, False))
        elif kind == "str":
            s = val[1:-1]
            m = TRF_ACTION.match(s)
            top = brackets[-1] if brackets else None
            whole = prev in ("(", ",", "{", "=") and nxt in (",", ")", "}", ";", "")
            if m:
                refs.append(("action", m.group(1), ln, scope, None, False))
            elif TRF_NAME.match(s) and whole and prev != ".." and nxt != "..":
                if top and top[0] == "(" and top[1] and prev in ("(", ","):
                    callee, k = top[1], top[2]
                    if callee == "setglobal" and k == 0:
                        assigns.add(s)
                    else:
                        refs.append(("str@%s:%d" % (callee, k), s, ln, scope, callee, k))
                else:
                    refs.append(("str", s, ln, scope, None, None))
        if val in OPEN and kind == "op":
            callee = prev if val == "(" and i and kinds[i - 1] == "name" and prev not in KEYWORDS else None
            brackets.append([val, callee, 0])
        elif val in (")", "}", "]") and kind == "op":
            if brackets:
                brackets.pop()
        elif val == "," and brackets:
            brackets[-1][2] += 1
    return defs, assigns, refs, guards, tolp


def count_args(toks, i):
    """(nargs, multi) of the call whose argument list starts at token i; multi: the last arg may expand."""
    if toks[i][1] != "(":
        return 1, False      # f{...} / f"..."
    depth, commas, j = 0, 0, i
    while j < len(toks):
        kind, t = toks[j][0], toks[j][1]
        if kind == "op" and t in OPEN:
            depth += 1
        elif kind == "op" and t in (")", "}", "]"):
            depth -= 1
            if depth == 0:
                break
        elif t == "," and depth == 1:
            commas += 1
        j += 1
    if j == i + 1:
        return 0, False
    return commas + 1, toks[j - 1][1] in (")", "...")


# Load sets (traffic.script TRF_Main): cfg exp 1..3 loads one exp kit and no trf_* module, exp 0 loads the
# trf_* modules; traffic.script holds fallbacks that a later module redefines (TRF_Init).
KITS = ("exp_hooks.script", "exp_state.script", "exp_trader.script")
LOADER = "traffic.script"


TEXT_FN = re.compile(r"TRF_\w+_Text$")


def text_keys(path):
    """Literal (key, text, line, table) pairs of the TRF_<M>_Text() functions of one file ("return {k = "s", ...}")."""
    toks = file_tokens(path)
    v = [t[1] for t in toks]
    out = []
    for i in range(len(toks) - 5):
        if not (v[i] == "function" and TEXT_FN.match(v[i + 1]) and v[i + 2:i + 6] == ["(", ")", "return", "{"]):
            continue
        depth, j = 1, i + 6
        while j < len(toks) and depth > 0:
            if v[j] in "{(":
                depth += 1
            elif v[j] in "})":
                depth -= 1
            elif (depth == 1 and j + 3 < len(toks) and toks[j][0] == "name" and v[j + 1] == "="
                  and toks[j + 2][0] == "str" and v[j + 3] in (",", ";", "}")):
                out.append((re.sub(r"[^a-z0-9]", "", v[j].lower()), v[j + 2][1:-1], toks[j][2], v[i + 1]))
            j += 1
    return out


def base(p):
    return p.replace("\\", "/").rsplit("/", 1)[-1]


def exclusive(p, q):
    """Files never loaded together."""
    a, b = base(p), base(q)
    return a != b and (a in KITS or b in KITS) and (a in KITS or a.startswith("trf_")) \
        and (b in KITS or b.startswith("trf_"))


def lint_calls(paths, verbose=False, quiet=False):
    defs, assigns, refs, guards, tol = {}, set(), [], set(), set()
    out, nexcl = [], 0
    add = lambda p, ln, kind, msg: out.append((kind, "%s:%d: %s: %s" % (p, ln, kind, msg)))
    for p in paths:
        d, a, r, g, t = scan_calls(p)
        for name, np, va, ln, top, _ in d:
            lst = defs.setdefault(name, [])
            for o in lst:
                if not (top and o[4]):
                    continue
                if exclusive(o[5], p):
                    nexcl += 1
                elif base(o[5]) == LOADER and base(p) != LOADER:
                    add(p, ln, "info", "%s redefines the loader fallback (%s:%d)" % (name, o[5], o[3]))
                else:
                    add(p, ln, "error", "duplicate definition of %s (first at %s:%d)" % (name, o[5], o[3]))
                break
            lst.append((name, np, va, ln, top, p))
        assigns |= a
        refs += [(p,) + x for x in r]
        guards |= {(p, s, nm) for s, nm in g}
        tol |= set(t)
    texts = {}
    for p in paths:
        if base(p) in KITS:
            continue        # exp kits never load with trf_loc, so their tables are never merged
        for k, txt, ln, fn in text_keys(p):
            o = texts.setdefault(k, (txt, p, ln, fn))
            if o[0] != txt:
                add(p, ln, "error", "text key %s of %s differs from %s (%s:%d); trf_loc keeps only the one TRF_Loc_TextFns lists first"
                    % (k, fn, o[3], o[1], o[2]))

    def target(name, p):
        """Definition a call from file p reaches: same file, else a later-loaded module, else the loader."""
        c = [d for d in defs.get(name, []) if not exclusive(d[5], p)]
        c.sort(key=lambda d: (d[5] != p, base(d[5]) == LOADER, not d[4]))
        return c[0] if c else None

    optional = []
    for p, kind, name, ln, scope, x, y in refs:
        if kind.startswith("str@") and not (x.startswith(PREFIX) or x == "getglobal"):
            continue        # engine call (CreateGroup, SetGroupRelation, ...): a label, not a function
        dfn = target(name, p)
        known = dfn or name in assigns or name in NATIVES
        guarded = (p, scope, name) in guards
        excl = "" if known or name not in defs else " (only in %s)" % ", ".join(
            sorted({base(d[5]) for d in defs[name]}))
        if kind == "call":
            if not known:
                if guarded:
                    optional.append((p, ln, name))
                else:
                    add(p, ln, "error", "call to undefined %s%s" % (name, excl))
                continue
            if dfn and not dfn[2]:
                nargs, multi = x, y
                if nargs > dfn[1]:
                    add(p, ln, "warn", "%s called with %d args, defined with %d (%s:%d)"
                        % (name, nargs, dfn[1], dfn[5], dfn[3]))
                elif nargs < dfn[1] and not multi:
                    add(p, ln, "info", "%s called with %d args, defined with %d (%s:%d)"
                        % (name, nargs, dfn[1], dfn[5], dfn[3]))
        elif known:
            continue
        elif guarded or (kind.startswith("str@") and tolerant(x, y, tol)):
            optional.append((p, ln, name))
        elif kind == "val":
            add(p, ln, "warn", "reference to undefined %s%s" % (name, excl))
        elif kind == "action":
            add(p, ln, "warn", "trigger action calls undefined %s%s" % (name, excl))
        else:
            what = str_kind(x, y) if kind.startswith("str@") else "str"
            where = " (arg %d of %s)" % (y + 1, x) if kind.startswith("str@") else ""
            label = {"due": "scheduled call", "cb": "callback name", "str": "string reference"}[what]
            add(p, ln, "warn", "%s to undefined %s%s%s" % (label, name, where, excl))
    out.sort(key=lambda o: (o[1].split(":")[0], int(o[1].split(":")[1])))
    for kind, line in out:
        if not (quiet and kind == "info"):
            print(line)
    if verbose:
        for p, ln, name in optional:
            print("%s:%d: optional: %s not defined (guarded or looked up)" % (p, ln, name))
    cnt = {k: sum(1 for kk, _ in out if kk == k) for k in ("error", "warn", "info")}
    print("%d error(s), %d warn(s), %d info, %d optional unresolved (%d distinct), %d redefinition(s) in "
          "exclusive load sets; %d TRF_ functions, %d references in %d file(s)"
          % (cnt["error"], cnt["warn"], cnt["info"], len(optional), len({o[2] for o in optional}), nexcl,
             len(defs), len(refs), len(paths)), file=sys.stderr)
    return 1 if cnt["error"] else 0


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
    ap.add_argument("--calls", action="store_true",
                    help="cross-file check of TRF_ definitions, references and argument counts")
    ap.add_argument("-v", "--verbose", action="store_true", help="--calls: also list the optional references")
    ap.add_argument("-q", "--quiet", action="store_true", help="--calls: count the info findings, do not list them")
    ap.add_argument("files", nargs="+")
    a = ap.parse_args()
    if a.calls:
        return lint_calls(a.files, a.verbose, a.quiet)
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
