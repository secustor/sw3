# Lua 4 tooling for the mod scripts (research, 2026-10-21)

The scripts run under the game's Lua 4.0.1. Every mainstream Lua linter, formatter and test framework parses Lua 5.x only. What exists today: `tools/lint_lua.py` (token heuristics), `luac -p` with the stock 4.0.1 build (`tools/get-lua4.sh`), the CRLF check and the host harness (`tests/run_host.sh`, `tests/host_stubs.lua`), all without game files. Prototypes from this research are in `sw3/.work/lua-tooling/` (`calls.py`, `cov.lua`).

## Measured Lua 4 constructs in the 25 scripts

- `%name` upvalues: 43 references (= 43 `PUSHUPVALUE` ops in `luac -l`). 13 of 25 files fail Lua 5.5 `luac -p` on them. With only the `%` characters stripped (token-aware), all 25 parse under 5.5.
- `for k, v in <table> do` in 21 files: valid Lua 5 syntax, but Lua 5 calls the table at runtime.
- Global stdlib names (`strfind`, `tinsert`, `getn`, `mod`, …), `call(f, args, "x", h)`, `getglobal`/`setglobal`/`globals()`, the implicit `arg` table, `getinfo`; tag methods only in `host_stubs.lua`.
- Stock 4.0.1 defines 103 globals; the game's set is that minus `foreachvar nextvar rawgetglobal rawsetglobal getargs` (lua-natives.md).

## Linters

| Tool | Parses Lua 4 | Verdict |
|---|---|---|
| luacheck | No (`%x`); on `%`-stripped copies expected yes (untested) | Try. Custom `stds` (Lua 4 builtins + natives + generated `TRF_*` list, `std = "lua4+sw3+trf"`, `unused_args = false`, ignore 213). Adds undefined/unused/shadowed/unreachable and missing-`local` warnings. Needs Lua 5.x + luarocks. |
| selene | Same as luacheck (untested) | Try instead of luacheck. Single binary; YAML std with per-global argument types, which can be generated from `lua-natives.json` for arity checks on natives. |
| LuaLS `--check` | No; `%x` lines stay syntax errors | Skip for CI; editor only. |

Risks on stripped copies: a Lua 4 upvalue (value copy at closure creation) reads as a live reference; string-dispatched functions (`getglobal("TRF_"..m.."_OnLoad")`, trigger strings) are invisible.

## Cheap exact check: `lint_lua.py --calls` from `luac -l -p`

The 4.0.1 listing resolves locals at compile time, so every `GETGLOBAL`/`SETGLOBAL` is a real global with an exact line. Prototype (`calls.py`, ~40 lines, 3.3 s): referenced globals minus mod `SETGLOBAL` names, Lua 4 builtins, the 139 natives in `lua-natives.json` and the 10,535 globals set by the game's own scripts leaves 18 names, all expected (`EASY NORMAL HARD PLAYER_* RELATION_* ROLE_* QUEST_PROCESS`, the 4 DLL natives, `flight_pir_mon_1`). A planted `TRF_Missing` is found. Without the game directory 59 names are unresolved; commit a generated `tools/sw3_globals.txt` allow-list. Second check from the same data: `SETGLOBAL` of a non-`TRF_` name anywhere (missing `local`, becomes persisted save data); today 13 names, all intended vanilla overrides, to allow-list. Optional info: `TRF_` functions never read or named in a string (44 today, mostly name-concatenated dispatch; real candidates `TRF_DcPayFor`, `TRF_Rd_Legs`, `TRF_TrGt`, `TRF_StagedEnd`, `TRF_Region_WhereTrouble`). Effort about 80 lines, 2–3 h. The listing cannot give unused locals.

## Formatters

StyLua (`line_endings = "Windows"`, `indent_type = "Tabs"`, `syntax = "Lua51"`, `--check`), LuaFormatter (`use_tab`, `line_separator: crlf`), lua-fmt (no options, unmaintained): all fail on `%x`, a strip cannot be reversed after reformatting, and StyLua probably drops the `;` terminators (untested). Skip, including check-only mode.

## Tests

- Keep the Lua 4 harness. Add TAP lines (`ok N - msg`, `1..N`), per-run `clock()` time, and `::error file=…,line=…::` annotations in `run_host.sh`. About 40 lines.
- Lua 5 port with a shim: not feasible. `%name`, `for in t`, tag methods, `tostring(10/2) = "5.0"`, `format("%d", 2.5)` error, `arg` all need source rewrites; the tests would not run the code the game runs. busted/luaunit cannot run on Lua 4.
- Coverage via `setlinehook` works (`cov.lua`): hook state must live in upvalues (the ClearGlobals emulation deletes global tables); v1-a 0.22 s → 1.31 s, 8,276 file:line hits; compare with executable lines from `luac -l` for "functions never entered". Make it opt-in (`COV=1`), full run about 2–3 min.

## Editor

No Lua 4 aware extension found. Minimal: `.editorconfig` (`[*.script] end_of_line = crlf`, `indent_style = tab`), file association `*.script` → lua (VS Code `files.associations`, Zed `file_types`, Neovim `vim.filetype.add`). Optional LuaLS `.luarc.json` with `runtime.version "Lua 5.1"`, all `runtime.builtin` libraries disabled and a generated `---@meta` file of Lua 4 builtins and natives; the 43 `%x` lines stay red.

## CI and pre-commit

GitHub Actions (ubuntu-24.04): cache `.work/lua4/bin` keyed on `get-lua4.sh`, run `get-lua4.sh`, `tests/run_host.sh`, `tools/savetool.py selftest`. The harness embeds vanilla data, so it needs no game files; `gen_map.py --check` and `check_sites.py` read the install and stay local. `get-lua4.sh` on Linux is untested: `-Wno-everything` is clang-only (gcc ignores it unless another diagnostic fires); if gcc 14 rejects implicit declarations, use `CC=clang`.

Pre-commit: `mixed-line-ending --fix=crlf` on `Data/Scripts/**/*.script`, `luac -p` and `lint_lua.py` as local hooks on commit, `run_host.sh` on pre-push.

## Ranked

1. Adopt: `lint_lua.py --calls`/`--sets` from the `luac -l` listing.
2. Adopt: GitHub Actions job (`run_host.sh`, `savetool selftest`).
3. Adopt: pre-commit hooks (CRLF, `luac -p`, lint; host run on push).
4. Adopt: TAP, counts and timing in the harness.
5. Try: `setlinehook` coverage, opt-in.
6. Try: selene (or luacheck) on `%`-stripped copies with a generated std.
7. Try: editor setup (`.editorconfig`, association, optional LuaLS meta).
8. Skip: LuaLS in CI, all formatters, busted/luaunit or a Lua 5 port.

Sources: luacheck config and warnings docs (luacheck.readthedocs.io), selene std format (kampfkarren.github.io/selene/usage/std.html), LuaLS settings (luals.github.io/wiki/settings), StyLua, LuaFormatter, lua-fmt, luaunit repositories, pre-commit-hooks.
