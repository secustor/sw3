# Display mode research (mtld3d, Wine EmulateModeset, game cfg)

Inputs: Wine tree `Wine-mtld3d-arm64-11.19-2` (`wine-11.19-17-gd57b522eea5`, athei/wine
`d57b522`), mtld3d v0.14.0 (version string in `mtld3d.so`). Sources fetched to
`.work/untrusted/mtld3d-readme/` (README, `v0.14.0-mtld3d.conf`, `v0.14.0-INSTALL.md`,
`v0.14.0-STATUS.md`) and `.work/untrusted/wine-src-11/` (athei `d57b522` sysparams.c,
winemac.drv display.c and macdrv_main.c, explorer desktop.c, server registry.c; upstream
wine-11.19 sysparams.c). Game addresses refer to `.work/exe.asm`.

## 1. mtld3d configuration

- Implementation: `lib/wine/d3d9/mtld3d/{i386,aarch64}-windows/{d3d9,mtld3d}.dll` +
  `aarch64-unix/mtld3d.so`. The 1.5 KB `lib/wine/i386-windows/d3d9.dll` is a stub. **confirmed**
- Config file: `mtld3d.conf` in the directory of the game exe (`std::env::current_exe()`),
  read at every `Direct3DCreate9`. Missing file = defaults. **confirmed** (README, conf
  header, d3d9.dll strings `mtld3d.conf: loaded from` / `not loaded from`; clone log:
  `mtld3d.conf: not loaded from Z:\Users\secustor\Games\Heroic\sw3-tp-test\mtld3d.conf`).
- So a per-game file next to `sw3cw.exe` works; no other search path. **confirmed**
- Env override: `MTLD3D_CONFIG="key=value;key=value"`, wins over the file key by key.
  Layers: built-in default < built-in app profile < `mtld3d.conf` < `MTLD3D_CONFIG`. **confirmed**
- Format: `key = value`, `#` comments, unknown/invalid values are warned and ignored. **confirmed**
- Render scale: `render.scale`, a number in (0, 1.0], default `1.0`; values above 1.0
  rejected; MetalFX spatial upscale; held at 1.0 on a GPU without MetalFX. It multiplies on
  top of the back buffer size (3360x1890 at `0.5` rasterizes 1680x945). `render.lodBias`
  (default true) keeps texture LOD at the presented size. **confirmed** (conf + strings
  `' is not a number in [`).
- Other keys: `cursor.scale = auto|1..8` (bitmap size only; `auto` doubles in Wine retina
  mode), `cursor.software = false|auto|true`, `present.maxFps = 0` (Hz, 0 = off),
  `present.maxFrameLatency = auto|1..30`. Full key list is in the d3d9.dll strings and the
  sample conf. **confirmed**
- Stretch instead of pillarbox: no such key (full key list has no aspect/stretch option).
  Letterboxing is done by win32u under EmulateModeset, not by mtld3d. **confirmed**
- Cursor mapping option: none. mtld3d only falls back to "window covers the monitor and
  present scales the frame, so mouse coordinates stay in monitor space" when
  `ChangeDisplaySettingsW` fails or the request is no real display mode. **confirmed**
  (strings, STATUS.md). Not usable as a deliberate switch. **inferred**
- Mode list: mtld3d serves at most 15 sizes, first those that fill the display, then
  standard sizes of another shape; the clone log on 3360x1890 lists `(3360, 1890)` first.
  A fullscreen request for a size not in the list "follows the window" (back buffer = window
  size) instead of setting a mode. **confirmed** (INSTALL.md, STATUS.md, clone log). So a
  `max=` downscaled size that is not in the list would not give the requested size. **inferred**

## 2. Wine display query under EmulateModeset

All in `dlls/win32u/sysparams.c` (athei d57b522; differs from upstream 11.19 only in
assert-to-ERR changes and a compatdb DPI hook). **confirmed**

- Storage: per source, key
  `HKLM\System\CurrentControlSet\Hardware Profiles\Current\System\CurrentControlSet\Control\Video\{gpu-guid}\Sources\<name>`,
  created `REG_OPTION_VOLATILE`; values `Current`, `Registry`, `Physical` (DEVMODEW from
  `dmFields`), `Modes`. Volatile keys are never saved (`server/registry.c`: `KEY_VOLATILE`
  skipped), consistent with system.reg holding no Video\Sources data. **confirmed**
- `add_modes()` with `emulate_modeset`: host list reduced to the host current mode;
  `physical` = host current; `virtual` = stored `Current` if present and not detached, else
  `physical`; mode list = standard sizes <= physical plus physical and virtual; `Registry`
  written only if absent; `Current` = virtual. **confirmed**
- `EnumDisplaySettingsW(NULL, ENUM_CURRENT_SETTINGS)` = `source->current` (the `Current`
  value): the emulated mode while one is set, else the physical host mode. **confirmed**
- `ENUM_REGISTRY_SETTINGS` = `Registry` value, written once per wineserver session from the
  first `Current`; not refreshed on a later host display change within the same session.
  **confirmed** (code); stale case needs a session that outlives a display switch. **inferred**
- `GetSystemMetrics(SM_CXSCREEN/SM_CYSCREEN)` = primary monitor rect from `source->current`,
  mapped from the source DPI (system DPI) to the thread DPI (96 for an unaware process).
  The prefix has `LogPixels=96`, so it equals ENUM_CURRENT_SETTINGS. **confirmed**
- The physical mode itself is not exposed: `WINE_ENUM_PHYSICAL_SETTINGS` returns FALSE from
  `NtUserEnumDisplaySettings`. Under EmulateModeset the largest enumerated mode equals it,
  unless a stale `Current` larger than the new host mode survives. **confirmed** (code)
- Reset: `apply_display_settings` notifies explorer's `__wine_display_settings_restorer`
  with the caller's pid when `CDS_FULLSCREEN` is set (mtld3d uses it: string
  `CDS_FULLSCREEN) returned`). Explorer waits on the process handle and calls
  `ChangeDisplaySettingsExW(NULL, NULL, ...)`, which writes `Registry` back to `Current`.
  A crash or kill of the game also signals the handle, so it is reset. `wineserver -k`
  ends the session and the volatile keys are dropped; the next session starts from the
  host mode. mtld3d itself also restores the registry mode on app deactivation (clone log).
  **confirmed** (explorer desktop.c, sysparams.c, mtld3d log)
- Units: winemac reports `CGDisplayModeGetWidth/Height` (points). `RetinaMode` is read from
  `HKCU\Software\Wine\Mac Driver`, default `false`; only when true is the native mode
  doubled to pixels. The prefix has no Mac Driver key, so retina is off and the values are
  points (3360x1890 on the external screen, 1728x1117 built-in). **confirmed** (macdrv_main.c,
  display.c, user.reg, mtld3d log `host 3360x1890`, `auto from the Wine retina mode` at 1x)
- DllMain timing: the exe imports d3d9.dll first, and mtld3d's d3d9.dll imports USER32;
  Wine's `process_attach` initializes dependencies first, so user32 is initialized before
  zlib1.dll's DllMain. The proxy links only kernel32/ntdll, so it must resolve user32
  functions with `GetModuleHandleA`/`GetProcAddress` (as sw3tp.c already does for
  `IsWindow`). **confirmed** (import tables, loader.c). Display queries from DllMain under
  the loader lock read the registry cache explorer maintains. **inferred**, not run.
- Conclusion: use `EnumDisplaySettingsW(NULL, ENUM_CURRENT_SETTINGS, &dm)` in DllMain. At
  game start no fullscreen mode is active, so it returns the host mode in points.
  `GetSystemMetrics` gives the same here but scales with DPI. Optional cross-check: log a
  warning if the largest enumerated mode differs. **inferred** (high confidence)

## 3. Game config load and write-back

- `zlib1.dll` is a static import of `sw3cw.exe` (IAT `zlib1.dll!compress2`); static import
  DllMains run before the exe entry point. **confirmed**
- Load: `WinMain` (0x656100, called from CRT code at 0x67ed81) calls 0x49ecb0, which
  registers the `gr_init_resolution` cvar (0x49efe7, handler 0x4a2e40, four values) and then
  executes `default.cfg` via the cfg loader 0x499800 (0x49f4f0..0x49f4f5). `PreMainLoop`
  (0x49fa80) runs after it. So the file is read long after DllMain. **confirmed**
- Write-back: the only `default.cfg` writer is 0x495560 (GetFileAttributesA, then
  SetFileAttributesA(path, FILE_ATTRIBUTE_ARCHIVE), i.e. it clears read-only first). Its
  only caller is 0x49e580 (from 0x49e560, reached indirectly), which then unregisters the
  cvars (`quit`, `gr_init_resolution`, ...): game shutdown. It writes the current cvar
  values, so the line the module set is written back unchanged unless the player changed
  it in the options. No write on crash or kill. **confirmed** (writer, caller);
  shutdown-only **inferred** (high)
- `gr_init_resolution %d %d %d %d` (0x55041c, function 0x54fa80) is a console command the
  video options build and execute (0x4989d0), i.e. how the menu applies a resolution; it
  is not the file writer. **inferred** (high)
- `Profiles/<user>/<user>.cfg`: same header, but carries no `gr_init_resolution` (nor
  texture/fsaa keys); `grep -a gr_init_resolution` matches only `default.cfg`. **confirmed**
  for the current files.
- Mode validation: the D3D9 init code near `Primary surface dimension: %i x %i`
  (0x466370) only logs the primary surface; no strings for a mode-list check or fallback
  exist near it (only an invalid-bpp error in `PrepareNewDisplayParams`). The game ran at
  3360x1890 after `Reset 1680x1050 -> 3360x1890 ... ok`. A size not in mtld3d's list is
  handled by mtld3d (follows the window), not by the game. **inferred** (medium)
