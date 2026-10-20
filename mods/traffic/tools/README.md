# Traffic host tools

Both tools are stdlib-only Python 3 and are run with `python3 -I`. Neither writes to the game directory.

## check_sites.py

Static check of the DLL hook sites (mod-options.md 5.2) and the Lua C API prologues (section 1). It verifies the exe SHA-1, reads the 5 bytes at each site through the PE section table, checks the `E8` opcode and the decoded rel32 target, and checks for overlap with the sw3tp patch sites. With `--asm` it also cross-checks each site in the disassembly, counts the callers of each target, and reports any jmp/jcc/call/loop whose target lies in site+1..+4. It always scans the whole file for absolute dwords pointing into those ranges (jump tables, function pointers). With `--write-header` it writes `TRF_SITES` and `TRF_APIS` (the first 16 bytes of each of the 30 API functions) for the DLL. The header is written only when every check passes. Exit status 1 on any mismatch.

    python3 -I mods/traffic/tools/check_sites.py --asm .work/exe.asm --write-header mods/traffic/pe/trf_sites.h
    python3 -I mods/traffic/tools/check_sites.py --exe /path/to/sw3cw.exe

## lint_lua.py

Token-based lint for the mod's `*.script` files (Lua 4.0.1 under the SW3 engine). It flags `local function`; `true`/`false`; the `%` operator (`%name` upvalues are allowed) and `#`; `function a:b` and `function a.b` (functions in tables are lost on save); named global functions without the `TRF_` prefix; assignments outside any function body whose target is not `TRF_`-prefixed (pass game globals that a wrapper replaces with `--allow`), and top-level assignments of data (constructor, literal or call result) to `TRF_` names; reserved names (the 0x7acae8 list, `EASY NORMAL HARD NOINIT`, prefixes `_EVENT_ ROLE_ RELATION_ QUEST_ MISSION_`) used as constructor keys, `["..."]` keys or `.field =` targets; bare tests of game helpers that return `FALSE` (0 is true; extend the list with `--bool`); and `== FALSE` against `IsExist`/`IsAlive`/`HavePerk`, which return 1 or nil. Exit status 1 when anything is found.

    python3 -I mods/traffic/tools/lint_lua.py --allow TeleportToLocation,CustomTeleportate mods/traffic/Data/Scripts/Mods/Traffic/*.script
    python3 -I mods/traffic/tools/lint_lua.py --host mods/traffic/tests/host_stubs.lua   # Lua 4 syntax checks only
