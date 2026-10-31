# sw3-infinite-view: draw the whole system in Star Wolves 3: Civil War

sw3-infinite-view raises the game's render far plane and the mesh fade distance, so stations, portals, asteroids and clouds are drawn across the whole system instead of fading out at 600 to 800 units. Ship visibility does not change: ships beyond your sensor range stay hidden.

## How it works

- **Far plane.** The camera's far clip distance is the key `ZFarPlane = 800.0f` in the `[GRAPH]` section of `<game dir>/Main.ini`. The game reads it once at startup; without the key the exe uses 1000. The largest map is 4000x4000 (its diagonal is about 5660), so a far plane of 6000 covers every system from any point.
- **Fog.** Each system's fog runs from `FogStart` to `FogEnd`, given as fractions of the far plane, in the 58 files `<game dir>/Data/Environment/*.env`. 57 of them use `FogStart = 0.0` and `FogEnd = 1.0`, and one (`SB_U99_asteroid_field1.env`) uses `FogStart = -1.0`, which turns fog off. A larger far plane therefore also pushes the fog out, unless the fractions are rescaled.
- **Mesh fade.** Independently of the far plane, the exe fades every mesh (stations, portals, asteroids, ships) by its distance from the camera, using two more `[GRAPH]` keys in `Main.ini`: `ZTranspar` and `zTransparLenght` (see below).
- **Detection is separate.** Whether a ship is shown is decided every frame by a separate engine test (the team's sensor visibility list, built from hull and radar sensor ranges of 135 to 400 units). That test never reads the far plane, so this mod changes nothing about detection.

## Why the far plane alone is not enough

Every frame the exe measures each mesh's distance `d` from the camera. Up to `ZTranspar` (vanilla `400.0f`) the mesh is opaque. Over the next `zTransparLenght` units (vanilla `200.0f`) its alpha falls linearly to 0, and beyond `ZTranspar + zTransparLenght + 100` it is not drawn at all. The far plane does not enter this formula, so with only `ZFarPlane` raised to 6000 no station, portal or asteroid is visible beyond 600 units. Clouds are particles, not meshes, and are not affected.

install.sh therefore sets `ZTranspar = view - fade - 100` and `zTransparLenght = fade` (default fade 500: `5400.0f` and `500.0f` at view 6000). Meshes start to fade at 5400, reach alpha 0 at 5900, and the draw limit falls exactly on the far plane. The key lookup in the exe ignores case; the vanilla file spells the second key `zTransparLenght` (lines 16 and 17, after `ZFarPlane` on line 15), and that spelling is kept. Ship detection is a separate draw gate and stays as it is.

Frame rate: every mesh within the far plane is now drawn, where vanilla stopped at 700 units. Dense systems (ND has about 500 asteroids, x244 about 280) cost the most; a smaller `--view` reduces it.

## Options

```sh
./install.sh [--view N] [--fade N|keep] [--fog keep|clear] [--dry-run] <game dir>
```

| Option | Default | Meaning |
|---|---|---|
| `--view N` | `6000` | Far plane in world units, an integer from 1000 to 20000. Written as `ZFarPlane = N.0f`. |
| `--fade N` | `500` | Mesh fade band in units, an integer from 100 to 5000 and at most `--view` minus 200. Written as `ZTranspar = (view - N - 100).0f` and `zTransparLenght = N.0f`. `--fade keep` leaves both keys as they are. |
| `--fog clear` | yes | The env files are not touched. The haze stretches out with the far plane and fades out at it, so distant objects look clearer. |
| `--fog keep` | | `FogStart` and `FogEnd` in every env file are multiplied by 800/N (the original `ZFarPlane` over the new one), so the haze still ends at 800 units as in vanilla. Files with `FogStart` below 0 (fog off) or `FogEnd` at or below 0 are left as they are. |
| `--dry-run` | | Prints what would change and writes nothing. |

`--view=N`, `--fade=N` and `--fog=keep` work too.

The fog choice: `clear` shows far objects with little haze but loses the depth cue of the vanilla fog. `keep` keeps the vanilla haze, so objects beyond 800 units are drawn in the fog colour; which one becomes the default is not decided yet (`clear` for now).

## What install.sh changes

- `Main.ini`: only the numbers on the `ZFarPlane`, `ZTranspar` and `zTransparLenght` lines (the last two not with `--fade keep`; a missing fade key is refused unless `--fade keep`). CRLF line endings, the keys' spelling and every other byte stay. It prints the resulting lines.
- With `--fog keep`: only the numbers on the `FogStart` and `FogEnd` lines of each env file (a `FogStart` of 0 stays 0).
- Before the first write, it copies `Main.ini` and every env file to `<game dir>/sw3-infinite-view-backup/`. An existing backup is never overwritten. `sw3-infinite-view-backup/manifest.txt` lists the version, the values and every changed line.
- Every run builds the files from the backed-up originals and writes only the files that differ. A second run with the same values changes nothing and says so. A run with another `--view`, `--fade` or `--fog` updates the key and rescales the env files from the originals, not from an earlier rescale.
- It writes nothing while `sw3cw.exe` is running. Restart the game after an install: `Main.ini` is read only at startup.

## Install and uninstall

Quit the game first. Then:
```sh
./install.sh "$HOME/Games/Heroic/Star Wolves 3 - Civil War"                  # far plane 6000, fog clear
./install.sh --view 4000 --fog keep "$HOME/Games/Heroic/Star Wolves 3 - Civil War"
./uninstall.sh "$HOME/Games/Heroic/Star Wolves 3 - Civil War"
```
From the repo: `./install.sh --mod infinite_view [--view=N] [--fade=N|keep] [--fog=keep|clear] [--dry-run]` and `./uninstall.sh --mod infinite_view`. These scripts find the game dir through Heroic's `installed.json` (`--game-dir <path>` overrides). sw3-infinite-view is not in the mods pack yet; `release.sh` builds it as `dist/sw3-infinite-view-<v>.zip`.

`uninstall.sh <game dir>` restores `Main.ini` and the env files from the backup (only the files that differ are written) and removes `sw3-infinite-view-backup/` with its manifest. Running it again is safe: it says the mod is not installed and exits 0. It writes nothing while the game is running. Changes you make to `Main.ini` after the install revert too.

## Limits

- **Verified in game:** a far plane of 1600 (2026-10-31). Distant fields and stations appeared and ships beyond sensor range stayed hidden. 6000 is the recommended value but not yet tested in game.
- **Depth precision:** the near plane stays at `ZNearPlane = 0.1f`. With far 6000 the far/near ratio is 60000 (8000 in vanilla), so distant overlapping meshes may flicker in a 24-bit depth buffer. A lower `--view` reduces it.
- **Sky box:** whether the sky box still covers the background at a far plane above 1600 is not verified.
- **Frame rate:** more scenery (asteroids, clouds) is drawn; every mesh within the far plane is drawn. Check dense systems such as ND or x244.
- **Fade keys:** the values 5400/500 come from the exe code (`station-visibility.md` in `mods/traffic/design/mod-research/`); not yet tested in game.

## Tests

`sh tests/test_install.sh` runs install and uninstall on copies under `<repo>/.work/infinite_view/` (it reads `Main.ini` and the env files from the test clone `~/Games/Heroic/sw3-tp-test`, or from `SRC=<dir>`).

## Licence

MIT, see [LICENSE](LICENSE).
