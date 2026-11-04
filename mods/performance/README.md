# sw3-performance: native arm64 Wine setup for Star Wolves 3 on macOS

sw3-performance sets up Heroic to run the GOG Windows build of Star Wolves 3: Civil War on a native arm64 Wine build in borderless fullscreen. It replaces the older Rosetta setup (x86_64 Wine).

## What it does

`install.sh <game dir>` does five things. Each step is skipped when it is already done.

1. **Wine.** It downloads the athei/wine-build release named in `WINE_RELEASE` (`arm64-11.19-2`, asset `wine-arm64-11.19-2-macos-arm64.tar.xz`) and checks its SHA-256 against `wine-release.sha256`. It then unpacks the archive to `~/Library/Application Support/heroic/tools/wine/Wine-mtld3d-arm64-11.19-2`. If that folder already exists, nothing is downloaded. After unpacking, the scripts never write to the Wine folder; only `uninstall.sh --purge` deletes it.
2. **Prefix.** If `~/Games/Heroic/Prefixes/sw3-arm64` does not exist, it creates it with that Wine's `wineboot -u`. It then sets `HKCU\Software\Wine\X11 Driver\EmulateModeset=Y`, which turns on mtld3d's virtual mode-set.
3. **Fullscreen.** In `<game dir>/default.cfg` it sets the fourth `gr_init_resolution` value to `"TRUE"`. Your width and height stay, for example `gr_init_resolution "1680" "1050" "32" "TRUE"`. mtld3d scales the game onto the desktop without a display mode switch.
4. **Heroic.** In `~/Library/Application Support/heroic/GamesConfig/1426253436.json` it points `wineVersion` (bin, lib, lib32, wineserver) at the Wine from step 1 and `winePrefix` at the prefix from step 2. Heroic 2.22 hides custom Wine paths on macOS, so the file is edited directly. Other settings and environment variables stay. `--hud` adds `MTL_HUD_ENABLED=1` (the Metal FPS overlay) and `--no-hud` removes it.
5. **Display.** The game resolution follows the main display, see [Display: resolution follows the screen](#display-resolution-follows-the-screen). `--no-display` skips this step.

Before steps 3 and 4 it copies `default.cfg` and `1426253436.json` to `<game dir>/sw3-performance-backup/`. It writes nothing while Heroic or the game is running.

Heroic's first launch on a new prefix installs DirectX 9.0c, as usual.

## Display: resolution follows the screen

**What.** At each game start the sw3tp proxy (`zlib1.dll`, from the trackpad mod) reads the size of the main display and writes it into the `gr_init_resolution` line of `default.cfg` before the game reads the file. The game then runs at exactly the display size. mtld3d renders internally at a fraction of that size and MetalFX upscales it, so the GPU cost stays about the same.

**Why.** The game stores one fixed resolution. On a display with another shape (for example 1680x1050 on a 16:9 3360x1890 screen) mtld3d shows the frame with black bars, but Wine maps the mouse as if the frame filled the screen, so the cursor cannot reach parts of the image. At the display size there is no mode change and no bars, and the cursor maps 1:1.

**What install.sh changes.**
- If the proxy is not installed, it renames `zlib1.dll` to `zlib1_orig.dll` (after a SHA-1 check of `sw3cw.exe` and `zlib1.dll`), copies the proxy in and writes `sw3tp.ini` with `[sw3tp] enabled=0`, so the trackpad features stay off. The proxy comes from `../trackpad/` (mods pack) or `mods/trackpad/out/` (source tree, built if missing); the standalone sw3-performance zip does not contain it and skips this step. A later trackpad install takes the proxy over.
- It replaces the `[display]` section of `<game dir>/sw3tp.ini`; other sections stay unchanged.
- It writes `render_scale=off` into `[display]` (native rendering; `RENDER_SCALE=auto` renders about 1680x1050 pixels and upscales with MetalFX, which keeps the GPU cost flat but blurs UI text, as a first run on a 3360x1890 screen showed): at each start the proxy sets `MTLD3D_CONFIG=render.scale=<s>` in the game process, with `s` chosen so mtld3d renders about as many pixels as 1680x1050 (0.52 at 3360x1890, 0.95 at 1728x1117). This wins over `mtld3d.conf`; a `render.scale` already in `MTLD3D_CONFIG` (for example from Heroic's environment options) is kept.

**`[display]` keys** (in `sw3tp.ini`):

| Key | Default | Meaning |
|---|---|---|
| `mode` | `off` (shipped ini and install.sh) | `auto`: display size; `fixed`: the `fixed` size; `off`: `default.cfg` is not touched |
| `fixed` | empty | `WxH` for `mode=fixed` |
| `min` | `1024x768` | below this display size `auto` does nothing |
| `max` | `4096x4096` | a larger display is scaled down to fit, keeping the aspect ratio (even numbers) |
| `keep_bpp` | `32` | 3rd value of `gr_init_resolution` (`0` keeps the file's) |
| `fullscreen` | `TRUE` | 4th value |
| `render_scale` | `off` (shipped ini and install.sh) | mtld3d `render.scale`: `auto` (about 1680x1050 pixels of rendering), a number in `0.01`..`1.0`, or `off` (not set) |
| `log` | `1` | writes `display: ...` lines to `sw3tp.log` (`0`: only changes and errors) |

**Env for install.sh:** `DISPLAY_MODE=auto|fixed|off` (default `auto`), `DISPLAY_FIXED=WxH`, `RENDER_SCALE=auto|off|<number>` (default `auto`; written as `render_scale`). With `mode=off` the proxy sets no render scale.

**Disable:** set `mode=off` in `sw3tp.ini`, or run `DISPLAY_MODE=off ./install.sh <game dir>`. The game keeps the last written size in `default.cfg` (it writes its settings back on exit). The proxy keeps the original file as `default.cfg.sw3tp-orig` (made once, at the first change); copy it back to restore the old resolution. `uninstall.sh` does this, removes `[display]` (with it the render scale), and removes the proxy if this installer put it there.

**Check:** `sw3tp.log` shows the `display:` lines; the newest `mtld3d-logs/sw3cw-<pid>.log` shows `config: render.scale = <s>` and `fullscreen entered ... display mode <size> set` with the display size.

## Stability

**What.** The sw3tp proxy patches the start of the game's scene render (`0x4054d0`). While the render manager's quad batch is freed (its pointer is null), the render returns at once and draws nothing. Otherwise it runs unchanged. Both the frame and the load-screen renders go through this function, so the check covers all 21 calls to it.

**Why.** When the game window loses focus (`WM_ACTIVATEAPP(FALSE)`), the game frees its quad vertex batch and sets the device-lost flag. It recreates the batch only at the start of the next frame. If the focus loss is handled in the middle of a frame (for example inside the DirectInput poll), the rest of that frame draws engine trails and projectiles through the freed batch, and the game crashes at `0x432500` or `0x4d6050`. Skipping that one render avoids the crash, and the next frame restores the device and the batch as before. The guard does not test the device-lost flag: only the render's own Present clears it, so a render skipped on that flag never clears it and the screen freezes. Analysis: `mods/traffic/design/mod-research/crash-load-432500.md`.

The proxy checks the bytes at ten addresses of `sw3cw.exe` (GOG v1.12) first. If any of them differ, it logs one line and patches nothing.

**`[stability]` keys** (in `sw3tp.ini`; independent of `[sw3tp] enabled`; a missing section means the defaults):

| Key | Default | Meaning |
|---|---|---|
| `enabled` | `1` | `0`: the module does nothing |
| `render_lost_guard` | `1` | `0`: the render hook is not installed |
| `log` | `1` | writes `stability: ...` lines to `sw3tp.log` (`0`: only a signature mismatch or an install failure) |

`install.sh` writes the section with these defaults.

**Log lines** (`sw3tp.log`):
- `stability: attach ok render_lost_guard patch=0x4054d0 stub=0x... batch=[eax+0x90] sigs=10`: the hook is installed (at game start).
- `stability: sig mismatch at 0x... (<what>), render_lost_guard not installed`: a different exe; nothing was patched.
- `stability: render skipped (batch freed) n=<count>`: the first render skipped in an episode; `n` counts all skipped renders since the start.
- `stability: render resumed skipped=<k> episodes=<e>`: the first render after an episode; `k` renders were skipped in it.

## View: frustum and size cull

**What.** The sw3tp proxy puts a call into the game's per-frame mesh pass (`0x40c9dc` in `0x40c890`), which handles every mesh: stations, portals, asteroids, ships. The call runs for each mesh after the engine has computed its distance `d` and world radius `r`, and before the distance fade. It can skip the mesh for this frame in the same way as the game's own far-distance cull:
- **Frustum cull** (`frustum_cull`, on by default). The pass already tests each mesh's sphere against the view frustum, but then throws the result away, so meshes behind the camera are still drawn. With `frustum_cull=1` a mesh that the engine's own test puts outside the view is skipped.
- **Size cull** (`size_cull`, off by default). A mesh is skipped when its projected diameter `r * m11 * H / d` in pixels is below `min_pixels`. `m11` is the projection scale (1 at FOV 90) and `H` is the back-buffer height; both are read live each frame. A mesh with `r >= keep_radius` is never size-culled. With the default 10, the portal rings (r 11.8 and 15) and the station cores always stay.

The patch never changes a mesh's detection flag or its fade alpha. With a raised far plane (`mods/infinite_view`), the gain is largest in dense systems. A host estimate puts the frustum cull at about 45 % fewer meshes; the size cull adds 2-9 % in 2000x2000 systems and 9-23 % in x244. Analysis: `mods/traffic/design/mod-research/size-cull.md`.

The proxy checks the bytes at 14 addresses of `sw3cw.exe` (GOG v1.12) first. If any of them differ, it logs one line and installs nothing; the other hooks are not affected.

**`[view]` keys** (in `sw3tp.ini`; independent of `[sw3tp] enabled`; a missing section means the defaults):

| Key | Default | Meaning |
|---|---|---|
| `enabled` | `1` | `0`: the module does nothing |
| `frustum_cull` | `1` | skip meshes outside the engine's own frustum test |
| `size_cull` | `0` | skip meshes smaller than `min_pixels` on screen |
| `min_pixels` | `2.0` | projected diameter in pixels below which `size_cull` skips a mesh (0.5..16) |
| `keep_radius` | `10` | world radius from which a mesh is never size-culled (`0`: no mesh is size-culled) |
| `log` | `1` | `1`: attach line and one stats line every 5 s; `2`: also the first 20 culled meshes; `0`: only a mismatch or an install failure |

With `frustum_cull=0` and `size_cull=0` the hook only counts meshes and writes the stats line (the A/B baseline); with `log=0` as well, nothing is installed. `install.sh` writes the section with these defaults; `uninstall.sh` removes it. The traffic test install (`mods/traffic/install-test.sh`) takes `VIEW`, `FRUSTUM_CULL`, `SIZE_CULL`, `MIN_PIXELS` and `KEEP_RADIUS` from the environment.

**Log lines** (`sw3tp.log`):
- `view: attach ok hook=view patch=0x40c9dc stub=0x... frustum_cull=1 size_cull=0 min_pixels=2.000000 keep_radius=10.000000 log=1 sigs=14`: the hook is installed (at game start).
- `view: attach mismatch hook=view at 0x... (<what>), not installed`: a different exe; nothing was patched.
- `view: fps=<f> meshes=<n> frustum=<n> size=<n> px_min=<min_pixels> keep=<keep_radius> H=<h> m11=<m11>`: every 5 s (wall clock). The counts are from the last complete frame: `meshes` reached the check, `frustum` and `size` were skipped. `fps` is the engine's own measured FPS (the value it compares with `minFPSforQ`; `n/a` before the graphics object exists).
- `view: cull n=<k> why=frustum|size mesh=0x... r=<r> d=<d> px=<px>` (`log=2`): the first 20 culled meshes after start.

**A/B check** (game closed between installs; same save, same spot, camera still or the game paused):
1. Baseline: install with `FRUSTUM_CULL=0` (nothing is culled, the stats line still comes), start, load the save in x244, wait 10 s, note `fps=` and `meshes=` from the last `view:` line. Repeat in ND, then Proserpina. `VIEW=0` (no hook at all) is the stricter baseline; it writes no `view:` line, so read the FPS from the Metal HUD (`--hud`) or `gr_showfps`.
2. Install with `VIEW=1` (the defaults: frustum cull) and repeat. Then `SIZE_CULL=1` (and `MIN_PIXELS=4` for the aggressive setting) and repeat. Compare `fps=` and the `frustum=`/`size=` counts.
3. Look for meshes that disappear: stations and portals across the map, asteroid fields at their edge, objects at the screen edges while turning the camera. With `frustum_cull=1` also check what else reads the flag the cull clears (`+0x200` gates the camera ray tests and the lights loop, `size-cull.md` 1.12): mouse-over and click on near asteroids and ships, the sun glare hidden behind a near asteroid, the target HUD, ships beyond 1000 detected by allies.

**In-game result (2026-11-01, Kruger, 1728x1117).** Frustum cull on: `meshes=900`, 600-705 culled per frame (about 75 %), engine FPS reading 200-228, frame rate about three times the baseline by the HUD counter, no script errors; stations, portals and the field edge look normal, nothing pops in at the screen edge and no asteroid lost its body. The size cull has not run in the game.

**Risk.** A mesh may depend on another mesh's flag to be drawn (a parent and its child). The asteroid models are a small wrapper mesh that references the real model. If an asteroid or a station part disappears or pops at the screen edge, set `size_cull=0` or `frustum_cull=0` and report the spot.

## Why

- **Rosetta 2 is ending.** macOS 27 is the last release with full Rosetta 2. Afterwards Apple keeps it only for "older, unmaintained gaming titles", and it is unclear whether that covers Wine. This build is native arm64: Wine, mtld3d's macOS half and the compatdb are arm64, and only `sw3cw.exe` is emulated, as i386 code through FEX in WoW64.
- **mtld3d** (D3D9 to Metal, v0.14.0, bundled) replaces wined3d. The busiest game thread dropped from about 97% CPU on wined3d to about 59%.
- **Fullscreen through `EmulateModeset`** avoids the windowed-mode crash: after a focus loss, the game's lost-device recovery dereferences a null object in windowed mode. In borderless fullscreen it recovers, and Cmd+Tab releases the mouse.
- **FEX x87 reduced precision** stays at the build's default (`fex-x87-reduced-precision`, 64-bit doubles instead of 80-bit x87). `sw3cw.exe` has about 60,800 x87 instructions against about 1,200 SSE references. Full 80-bit precision costs about 60% more CPU and breaks hit detection (ships cannot hit anything).

Measurements from 2026-10-19 (M2 Max, process CPU while flying, game in focus):

| Env | Process CPU | Combat |
|---|---|---|
| defaults (this setup) | ~50-52% | hits register |
| `WINE_FORCE_NX=1` | mean 50.1%, max 55.8% | hits register; no gain, not set |
| full 80-bit x87 (`fex-x87-reduced-precision` off) | mean 81.0%, max 109.1% | ships cannot hit anything |

The Rosetta setup's busiest thread alone sat at about 59%. The ~50% total here looks like the game's frame cap rather than CPU saturation.

## Requirements

- Apple Silicon Mac, macOS 26.4 or later (the floor of the arm64 Wine build).
- Heroic Games Launcher 2.22.x, with Star Wolves 3: Civil War (GOG id `1426253436`) installed through Heroic, and the game's settings opened at least once so that `GamesConfig/1426253436.json` exists.
- `curl` and `tar` (part of macOS). About 110 MB download and 1 GB disk for the Wine folder.

## Install and uninstall

Quit Heroic first. Then:
```sh
./install.sh "$HOME/Games/Heroic/Star Wolves 3 - Civil War"          # add --hud for the FPS overlay
./uninstall.sh "$HOME/Games/Heroic/Star Wolves 3 - Civil War"        # add --purge to delete Wine dir and prefix
```
From the mods pack: `./install.sh --mod performance [--hud]` and `./uninstall.sh --mod performance [--purge]`; the pack scripts find the game dir through Heroic's `installed.json` (`--game-dir <path>` overrides).

`uninstall.sh` restores `1426253436.json` and `default.cfg` from the backups, so any Heroic setting changed after the install reverts too. It also reverts the display step (see above). The Wine folder and the prefix stay unless you pass `--purge`. `--purge` deletes them only if `install.sh` created them.

`WINE_ARCHIVE=/path/to/wine-arm64-11.19-2-macos-arm64.tar.xz ./install.sh …` uses an archive you already downloaded. It is SHA-256 checked the same way.

## Verify

- Heroic's `launch.log` for the game shows `compatdb: sw3cw.exe [i386]` with `fex-x87-reduced-precision` in its rules and `d3d9 = mtld3d`.
- `<game dir>/mtld3d-logs/sw3cw-<pid>.log` contains `mtld3d.dll v0.14.0 … unix call initialized` and `d3d9.dll v0.14.0 … loaded`.

## Known issues

- The arm64 build is new and has open 32-bit/x87 issues upstream (athei/wine-build #10, #13, #25).
- The Wine builds are unsigned single-maintainer binaries, and Wine does not sandbox the game.

## Licence

The scripts are MIT licensed, see [LICENSE](LICENSE). Wine, FEX and mtld3d are downloaded from their release page and are not part of this package. The sw3tp proxy used by the display step belongs to the trackpad mod and is not part of this package either.
