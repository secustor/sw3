# Star Wolves 3: Civil War on macOS

Running the GOG Windows build of Star Wolves 3: Civil War (GOG id `1426253436`, v1.12) on an Apple Silicon Mac through Heroic Games Launcher and Wine.

## Mods

| Mod | Source | Release zip | What it does |
|---|---|---|---|
| sw3-performance | [`mods/performance/`](mods/performance/README.md) | `dist/sw3-performance-<v>.zip` | The setup of sections 7 and 10 as an installer: arm64 Wine `arm64-11.19-2` (SHA-256 checked), prefix `sw3-arm64` with `EmulateModeset=Y`, fullscreen in `default.cfg`, Heroic GamesConfig pointed at both; game resolution follows the main display (`[display]` in `sw3tp.ini`, mtld3d `render.scale` set to match) |
| sw3-trackpad | [`mods/trackpad/`](mods/trackpad/README.md) | `dist/sw3-trackpad-<v>.zip` | Keymap (`controls.cfg` patch) and trackpad gestures (zlib1.dll proxy + `sw3tp.so`) |
| sw3-traffic | [`mods/traffic/`](mods/traffic/README.md) | `dist/sw3-traffic-<v>.zip` | NPC trader traffic (Lua scripts loaded by the sw3tp proxy) with regional boom/bust cycles, convoys, pirate clans and bases, faction sweeps. Needs the proxy from sw3-trackpad or sw3-performance. v1 is host-tested, not yet run in the game; see [`PROGRESS.md`](mods/traffic/design/PROGRESS.md) |
| Pack | top-level `install.sh`, `uninstall.sh` | `dist/sw3-mods-pack-<v>.zip` | sw3-performance and sw3-trackpad with one installer (sw3-traffic is not in the pack yet) |

Quit Heroic, then from the repo (or the unpacked pack):
```sh
./install.sh --mod all                     # or --mod performance, --mod trackpad, --mod traffic (repeatable)
./uninstall.sh --mod all
```
Mods install in the order performance, trackpad, traffic (traffic needs the proxy the other two install) and uninstall in reverse. The game dir comes from Heroic's `gog_store/installed.json` (else `~/Games/Heroic/Star Wolves 3 - Civil War`); `--game-dir <path>` overrides it. `./install.sh --help` lists the mods and options.
Build the zips with `./release.sh`.

## Setup

| Item | Value |
|---|---|
| Mac | Apple M2 Max, macOS 27.0.1, built-in 3456×2234 Retina display (1728×1117 points) |
| Launcher | Heroic Games Launcher 2.22.4 (Homebrew cask `heroic`) |
| Wine | athei/wine-build `arm64-11.19-2` (wine-11.19), native ARM64, game runs under FEX. See [section 10](#10-native-arm64-wine-with-fex-current-setup). Fallback: `cx-26.3.0-9` x86_64 under Rosetta 2 ([section 6](#6-mtld3d-d3d9--metal-rosetta-setup)) |
| Graphics | mtld3d v0.14.0 (D3D9 → Metal), borderless fullscreen 1680×1050 through `EmulateModeset=Y` |
| Redists | DirectX 9.0c, installed by Heroic on first launch |
| Game files | `~/Games/Heroic/Star Wolves 3 - Civil War` |
| Wine prefix | `~/Games/Heroic/Prefixes/sw3-arm64`. Earlier setups: `sw3-mtld3d` (cx-26.3.0-9), `shared` (Wine-Crossover 23.7) and `sw3-wine11` |
| Per-game Heroic config | `~/Library/Application Support/heroic/GamesConfig/1426253436.json` |
| Logs | Game: `<game dir>/LOGfile.txt` · Wine: `~/Library/Logs/Heroic Games Launcher/games/1426253436_gog/launch.log` |

Launch from Heroic, or with `open "heroic://launch?appName=1426253436&runner=gog"`.

## Problems and fixes

### 1. Homebrew Wine casks are disabled
- **Problem:** `wine-stable`, `wine@staging` and `wine@devel` were disabled on 2026-09-01 because they fail the Gatekeeper check.
- **Fix:** Install Heroic and use its Wine Manager to download Wine-Crossover. Heroic's global default is Game Porting Toolkit, which doesn't handle D3D9, so the per-game config pins Wine-Crossover.

### 2. Game was downloaded outside Heroic's UI
- **Problem:** The game was downloaded with Heroic's bundled `gogdl` from the command line, so Heroic did not list it as installed.
- **Fix:** Quit Heroic, then run [`register_sw3.py`](register_sw3.py). It:
  - adds the entry to `gog_store/installed.json`
  - writes the per-game Wine config
  - moves `gog-support` and the gogdl manifest to where Heroic expects them

  Heroic must be closed while editing, because it overwrites `installed.json` from memory. On the next launch Heroic runs the GOG support script, installs DirectX 9.0c and DXVK, and starts the game.
- Download command used:
  ```sh
  gogdl --auth-config-path "~/Library/Application Support/heroic/gog_store/auth.json" \
    download 1426253436 --platform windows --lang en-US --skip-dlcs --path ~/Games/Heroic
  ```

### 3. White window on start
- **Symptom:** A white window titled "CrossOver FOSS" / `wine-preloader`.
- **Cause:**
  - The game's default config requests fullscreen 1024×768.
  - Wine's Mac driver rejects the mode switch: `NtUserChangeDisplaySettings … returned -2`.
  - Creating the D3D9 device then fails with `0x8876086A` (`D3DERR_NOTAVAILABLE`).
- **Fix:** Run windowed by setting the fourth `gr_init_resolution` value in `<game dir>/default.cfg` to `"FALSE"`. The original file is backed up as `default.cfg.orig`.

### 4. Borderless fullscreen not possible with wined3d (solved later by mtld3d, see section 7)
- **Fullscreen at another resolution:** 1680×1050 fullscreen fails the same way as 1024×768. Wine-Crossover's Mac driver refuses every display mode switch.
- **Fullscreen at the desktop resolution:** 1728×1117 fullscreen needs no mode switch and initialises. The game then crashes while loading the main menu with `EXCEPTION_ACCESS_VIOLATION at 0x00556eb1`. Wine's debugger keeps the window open, so it looks frozen and ignores mouse input.
- **Confirming the cause:** Windowed 1024×768 runs past the same point without crashing, so the crash comes from the non-standard resolution.
- **Current setting:** a large window:
  ```
  gr_init_resolution "1680" "1050" "32" "FALSE"
  ```
- **Untested alternatives:**
  - dgVoodoo2, a D3D9 wrapper that scales to the desktop without a mode switch
  - paid CrossOver

### 5. Lag / low performance (solved by mtld3d + x87sidecar, see section 6)
- **Observation:** One game thread is pinned at about 97% CPU, so the game is CPU-bound in the D3D9 → wined3d (OpenGL) → wow64 → Rosetta path. The Mac was on AC power and not in Low Power Mode. The game does not fall back to software vertex processing.
- **Core placement ruled out:**
  - The game's busy threads run at macOS priorities 31 and 46, which is normal and foreground. Background threads that go to E-cores sit around 4 to 20.
  - `sudo powermetrics --samplers cpu_power` shows P-cores 8–11 at 80–93% active residency, running at the maximum 3696 MHz about 88% of the time. The E-cores show only typical background load.
  - So the game gets full-speed performance cores, and the lag is translation overhead.
- **Tried, and why it didn't help:**

  | Attempt | Result |
  |---|---|
  | Wine-Staging 11.18, in a separate prefix `Prefixes/sw3-wine11` | Runs, still laggy. Config backup: `GamesConfig/1426253436.json.wine11.bak` |
  | `NeedWindowsMouse = 1` in `Main.ini` | Game hangs at the main menu. Reverted; `Main.ini.orig` kept |
  | Wine `HKCU\Software\Wine\DirectInput\MouseWarpOverride=disable` (Wine 11 prefix only) | Still laggy. Left in the Wine 11 prefix |
  | Upstream DXVK 1.10.3 32-bit `d3d9.dll` (Wine 11) | `DxvkAdapter: Failed to create device`, because MoltenVK rejects DXVK's D3D9 device. Reverted |
  | dgVoodoo2 2.87.5 (D3D9 → D3D11 FL10.1 → DXVK-macOS), Wine 11 | DXVK D3D11 fails: `VK_ERROR_FEATURE_NOT_PRESENT` on external-memory `vkCreateBuffer` in wow64. Reverted |
  | dgVoodoo2 2.87.5, Wine-Crossover 23.7 | Crash in dgVoodoo's `D3D9.dll` (`0x100743f8`). Reverted; files in `<game dir>/_disabled-dgvoodoo2/` |

- **Not applicable:** DXMT and D3DMetal/GPTK do not implement D3D9.
- **Current state:** Wine-Crossover 23.7 with built-in wined3d, plus `MTL_HUD_ENABLED=1` (FPS overlay) and `WINEDEBUG=-all` in the per-game env.
- **Remaining options:**
  - CrossOver 26 trial. It is based on Wine 11 and bundles its own D3D stack and 32-bit handling.
  - Lower in-game detail settings.
- **Web research, 2026-10-19:**
  - [athei/mtld3d](https://github.com/athei/mtld3d): native D3D9 → Metal for Wine on macOS, Zlib licence. It covers SM1–3, fixed-function and 32-bit via WoW64. Latest is v0.14.0 (2026-10-18), with near-weekly releases. It needs the author's Wine builds ([athei/wine-build](https://github.com/athei/wine-build)): `cx-26.3.0-9` x86_64 (CrossOver 26 based), or `arm64-11.19-2` native ARM. Older Wine and CrossOver are not expected to work. Untested with SW3.
  - [athei/x87sidecar](https://github.com/athei/x87sidecar): hooks Rosetta to JIT x87 floating-point code.
  - Gcenx DXVK-macOS d3d9 is still unmerged ([PR #20](https://github.com/Gcenx/DXVK-macOS/pull/20)). MoltenVK lacks `geometryShader` and `shaderCullDistance`, which stock DXVK D3D9 requires.
  - DXMT has no D3D9. CrossOver 26 ships D3DMetal and DXMT for DX10–12 only, and probably still uses wined3d for DX9.
  - Fullscreen BADMODE is a known Wine issue (bugs 55629 and 56478). mtld3d documents `EmulateModeset=Y` as a workaround.

### 6. mtld3d (D3D9 → Metal), Rosetta setup (superseded by section 10)
- **Wine:** [athei/wine-build](https://github.com/athei/wine-build) `cx-26.3.0-9`, x86_64, `wine-11.0` (CrossOver 26 based). Installed at `~/Library/Application Support/heroic/tools/wine/Wine-mtld3d-cx-26.3.0-9`.
  - Its `compatdb.so` picks mtld3d as d3d9 for every x86 process by default.
  - The bundled mtld3d in `lib/wine/d3d9/mtld3d/{i386-windows,x86_64-windows,x86_64-unix}` was updated to [mtld3d](https://github.com/athei/mtld3d) v0.14.0 from the release bundle's `wine/` tree.
- **Prefix:** `~/Games/Heroic/Prefixes/sw3-mtld3d`, created fresh by Heroic so wineboot stamped the `mtld3d.dll` markers.
  - The per-game config points `wineVersion.bin` at the Wine above.
  - Previous config: `GamesConfig/1426253436.json.crossover-23.7-dgv-clean.bak`.
- **x87sidecar: active.** The Wine's built-in compatdb rule `x87-sidecar` starts `bin/x87sidecar --cooperative` for every i386 process, even without `ROSETTA_X87_PATH`. It is kept on and is part of the speed-up. To disable it, add `WINE_COMPATDB=name=x87-sidecar;enabled=false` to the per-game env.
- **Verify:** `<game dir>/mtld3d-logs/sw3cw-<pid>.log` must contain both lines:
  - `mtld3d::shim] mtld3d.dll v0.14.0 … unix call initialized`
  - `mtld3d::d3d9] d3d9.dll v0.14.0 … loaded`
- **Result:** The game starts, and no crash after the main menu. The busiest game thread dropped from about 97% (plus 84%) CPU on wined3d to about 59%.
- **Harmless warnings:** `reject GetAdapterModeCount(format=24)` (16-bit modes) and one `QueryInterface … E_NOINTERFACE`.
- **Speed:** confirmed by the user ("massively improved").

### 7. Mouse trapped and crash after focus loss in windowed mode (fixed by fullscreen)
- **Symptoms (windowed mode):**
  - The cursor is confined to the window.
  - After the game lost focus (seen when the display dimmed), it froze. Its main thread was blocked in `NtUserGetMessage`, paused by the game itself.
  - Cmd+Tab back made it crash: `page fault on read access to 0x00000014`, `sw3cw+0x32500: movl 0x14(%esi),%ecx`, `ESI=0`.
- **Cause:**
  - The game polls for `D3DERR_DEVICELOST` and runs its own lost-device recovery. Its log shows `Game::UpdateGame: handle Lost device ok`.
  - In windowed mode that recovery dereferences a null object in game code. mtld3d logs `fault outside d3d9.dll`.
- **Fix:** borderless fullscreen through mtld3d's virtual mode-set.
  ```sh
  WINEPREFIX=~/Games/Heroic/Prefixes/sw3-mtld3d "<mtld3d wine>/bin/wine" reg add 'HKCU\Software\Wine\X11 Driver' /v EmulateModeset /d Y /f
  ```
  - `default.cfg`: `gr_init_resolution "1680" "1050" "32" "TRUE"`.
  - The macOS display keeps 1728×1117, and mtld3d scales the game onto it.
  - On Cmd+Tab, mtld3d logs `app deactivated … left in place` and `app activated, fullscreen re-asserted`.
  - The game's lost-device recovery then succeeds without crashing, and Cmd+Tab releases the mouse. Confirmed by the user.

### 8. Esc does not open the game menu

- Cause: per the manual (p. 45), the first Esc unselects all ships and a second Esc opens the menu (p. 12). The on-screen Menu button also works.
- Not a Wine problem as far as known. If two presses don't help, trace key events with `WINEDEBUG=+key,+keyboard,+dinput` in GamesConfig `enviromentOptions` and check `launch.log` for Escape.
- winemac has no keyboard layout override. Its only key options are `LeftCommandIsCtrl`, `LeftOptionIsAlt`, `RightCommandIsCtrl` and `RightOptionIsAlt`. Wine uses the active macOS input source (Austrian here), not the prefix's `Preload` value.
- Possibly affected on the Austrian layout: `Z` (dock all, sits on the Y key) and `[` / `]` (game speed, Option combinations).

### 9. Porting to a modern DirectX (evaluated, not pursued)

- `sw3cw.exe` is a 4.2 MB 32-bit x86 binary with the engine built in. No source is available.
- Decompiling to compilable source would take one person many months to years. Ghidra or IDA output is not compilable as-is. Rewriting the D3D9 renderer comes on top.
- No benefit on macOS:
  - macOS has no DirectX, so D3D11/12 would still need translating to Metal.
  - mtld3d already translates D3D9 calls to Metal at runtime.
  - The lag was CPU-bound (x87 code under Rosetta), not graphics-bound. Only a native ARM64 build, which needs source, would remove Rosetta.
- Realistic option: binary patches for specific bugs with Ghidra, a few days each. Example: the null-pointer read at `sw3cw+0x32500` after "Lost device" in windowed mode.
- Legal: decompiling for interoperability is allowed in Austria under limited conditions (UrhG §40e, EU Directive 2009/24/EC Art. 6). Sharing decompiled code or a patched .exe is not.

### 10. Native ARM64 Wine with FEX, current setup

- **Why:** Rosetta 2 is being phased out (see [Known issues](#known-issues-and-risks)), and a native ARM64 game build is impossible without source (section 9). The realistic move is a native ARM64 Wine that emulates only the game.
- **Wine:** [athei/wine-build](https://github.com/athei/wine-build) `arm64-11.19-2` (2026-10-18, `wine-11.19-17`), unpacked to `~/Library/Application Support/heroic/tools/wine/Wine-mtld3d-arm64-11.19-2`. Needs macOS 26.4+. No D3D12 yet (irrelevant here).
  - `wine`, `compatdb.so` and mtld3d's unix half are arm64 Mach-O. `sw3cw.exe` runs as i386 through FEX in WoW64 (`libwow64fex.dll`), not Rosetta.
  - mtld3d v0.14.0 is bundled (ARM64X), nothing to copy.
  - x87sidecar does not exist on this build; FEX translates x87 itself. The compatdb rule name `x87-sidecar` is accepted and ignored.
- **Prefix:** `~/Games/Heroic/Prefixes/sw3-arm64`, created with the build's own `wineboot -u`, then `EmulateModeset=Y` set the same way as in section 7. Heroic's first launch installed DirectX 9.0c and the DXVK d3d10/d3d11 overrides into it as usual.
- **Heroic:** Heroic 2.22.4 hides custom Wine paths on macOS, but editing `GamesConfig/1426253436.json` by hand works (Heroic must be quit). `wineVersion.bin/lib/lib32/wineserver` point at the build above, `winePrefix` at `sw3-arm64`. Previous config: `1426253436.json.mtld3d-cx-26.3.0-9.bak`. The cx-26.3.0-9 build and `sw3-mtld3d` prefix are kept for A/B.
- **Result:** game starts, fullscreen 1680×1050 through `EmulateModeset`, lost-device recovery after Cmd+Tab works, no exceptions. "Pretty similar" to the Rosetta setup in feel.
- **Measurements, 2026-10-19,** process CPU (`top -l N -s 1 -pid <pid>`) while flying, game in focus. The game pauses when it loses focus, so samples taken while tabbed out read 3–6% and are discarded.

  | Run | Env | Process CPU | Combat |
  |---|---|---|---|
  | 1 | defaults | ~52% (6 s) | not tested |
  | 2 | `WINE_FORCE_NX=1` | mean 50.1%, max 55.8% (26 samples) | hits register |
  | 3 | `WINE_COMPATDB=v=6\nname=fex-x87-reduced-precision;enabled=false` (full 80-bit x87) | mean 81.0%, max 109.1% (76 samples) | **ship cannot hit anything** |
  | 4 | defaults | — | hits register, precision clearly better than run 3 |

  For comparison, the Rosetta setup's busiest thread alone sat at ~59% (section 6). The ~50% process total here looks like a frame cap rather than CPU saturation.
- **Findings:**
  - `sw3cw.exe` has no `NX_COMPAT` flag, so FEX re-translates writable pages. `WINE_FORCE_NX=1` was expected to help but made no measurable difference. Not set.
  - The built-in `fex-x87-reduced-precision` rule (`FEX_X87REDUCEDPRECISION=1`, 64-bit doubles instead of 80-bit software x87) is on by default for every x86 process and is kept. Full precision costs ~60% more CPU **and breaks hit detection**. `sw3cw.exe` has ~60,800 x87 instructions versus ~1,200 SSE references (static count, `llvm-objdump -d`), so the x87 path dominates. The full-precision failure smells like a FEX x87 bug (compare wine-build issue #13, x87 stack state lost across exceptions) rather than a game dependency on 64-bit rounding; not investigated further.
  - Final config: no extra env beyond `MTL_HUD_ENABLED=1` and `WINEDEBUG=-all`.
- **Verify:** `launch.log` must show `compatdb: sw3cw.exe [i386]` with `rules = … fex-x87-reduced-precision …` and `d3d9 = mtld3d`, and `mtld3d-logs/sw3cw-<pid>.log` the two v0.14.0 lines from section 6.
- **Open upstream issues to watch:** wine-build #25 (another 2008 D3D9 32-bit game black-screens on arm64 but works on cx), #10 (i386 crashes in FEX's WoW64 frontend), #13 (x87 stack state across exceptions).

## Known issues and risks

- **Keyboard layout:** A GOG user review says the game only accepts QWERTY or Russian keyboard layouts. Unverified; Esc works as designed (see section 8). Switch to a US layout if other keys misbehave.
- **Cloud saves:** Cloud saves don't sync. Heroic warns "No clientId in goggame-1426253436.info"; local saves are unaffected.
- **Rosetta 2 end of life (mitigated, section 10):**
  - macOS 27 is the last release with full Rosetta 2. Afterwards Apple keeps it only for "older, unmaintained gaming titles". It is unclear whether that covers Wine.
  - The current setup is native ARM64 Wine with FEX and no longer depends on Rosetta. The cx-26.3.0-9 fallback does.
  - The arm64 build is days old and has open 32-bit/x87 issues; keep the cx build and prefix until a few releases have passed.
- **Security:**
  - The Wine builds are unsigned single-maintainer binaries.
  - Wine does not sandbox the game; it can access the whole home directory.
  - Heroic stores the GOG token unencrypted in `gog_store/auth.json`. Log out of GOG in Heroic to remove it.
