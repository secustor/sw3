# SW3 mods (Star Wolves 3: Civil War, GOG 1.12, `sw3cw.exe`, Lua 4.0.1)

Read before touching `mods/traffic`:
- `mods/traffic/pe/API.md`: every native the DLL adds (`TRF_*`), its guards, in-game status and the Lua wrapper to
  call. Read it before any code that reads engine objects (counts, positions, teams, HP, inventories), and extend
  it when you add a native. Prefer a typed native or its wrapper (`TRF_Near`) over `GetCarcassCountInSphere`.
- `design/mod-research/exe-hook-survey.md`: what the exe can be hooked or read for; check it before inventing a
  workaround for a missing engine fact.
- `.work/wf/rules.md`: Lua 4 conventions, logging, loc keys, module registration, checks. Specs live in
  `mods/traffic/design/*-spec.md`; the tracker is `mods/traffic/design/PROGRESS.md`.

Rules:
- Never launch the game or wine. `~/Games` (game dir, test clone) is read-only for agents; only the user runs
  `install-test.sh` and `tools/*.sh`, and only while the game is closed.
- Scratch under the repo's `.work/` only (not `/tmp`, not the job dir). Python with `python3 -I`.
- Game scripts are CRLF cp1251: `/usr/bin/grep -a`, `sed -n ... | iconv -f cp1251 -t utf-8`; keep line endings.
- Checks before a commit: `python3 -I mods/traffic/tools/lint_lua.py <scripts>` (0 findings), `--calls -q`
  (5 known warnings), `.work/lua4/bin/luac -p`, `TMPDIR=$PWD/.work/host sh mods/traffic/tests/run_host.sh`
  (all runs 0 fails), `sh -n mods/traffic/install-test.sh`. DLL: `sh mods/trackpad/build.sh` must be clean.
- Conventional commits, no attribution lines, commit only your own hunks. After each implementation task run
  `/code-review xhigh --fix` on its range and commit the fixes as `fix(traffic): ...`.
- `README.md` is the player landing page (install steps, short feature list per mod). Update it when a mod's
  options, defaults or features change; put details in the mod's own README or `docs/`, not there.
  `release.sh` ships it as the pack README minus its `## More` section, so keep repo-only links in that section.
