# SW3 mods: install and features

These mods are for the GOG build of Star Wolves 3: Civil War (v1.12) on an Apple Silicon Mac, running through Heroic.

## Install

**You need:**
- macOS 26.4 or later on Apple Silicon
- Heroic 2.22.x, with the game installed through Heroic
- The game's settings opened once in Heroic, so it writes its per-game config

**Steps:**
1. Quit Heroic and the game.
2. Unpack the zip, or use the repo.
3. Open Terminal in that folder and run:

```sh
./install.sh --mod all            # or pick: --mod performance --mod trackpad ...
./uninstall.sh --mod all
```

**How the installer works:**
- Mods install in this order: performance, trackpad, infinite_view, traffic. They uninstall in reverse.
- traffic needs the `zlib1.dll` proxy, which trackpad or performance installs.
- The game dir is read from Heroic. Use `--game-dir <path>` to override it.
- Mod options pass through the combined installer as `--name=value`, for example `--view=4000`.
- `./install.sh --help` lists every option.
- Each mod folder also has its own `install.sh` / `uninstall.sh`, which takes the game dir as an argument.
- Every installer backs up the files it changes and restores them on uninstall.

**Release zips** (built with `./release.sh` into `dist/`):

| Zip | Contains |
|---|---|
| `sw3-mods-pack-<v>.zip` | performance and trackpad, with the combined installer |
| `sw3-infinite-view-<v>.zip` | infinite_view, shipped separately |
| `sw3-traffic-<v>.zip` | traffic, shipped separately |

## sw3-performance (0.1.0)

Makes the game run natively on arm64.

- Downloads native arm64 Wine (`arm64-11.19-2`: FEX, mtld3d D3D9→Metal). The download is SHA-256 checked and needs no Rosetta.
- Creates the prefix `sw3-arm64` with `EmulateModeset=Y` and points Heroic's game config at it.
- Runs the game borderless fullscreen. This avoids the windowed-mode crash, and Cmd+Tab releases the mouse.
- Matches the game's resolution to the main display, so the mouse maps 1:1 with no black bars. Render scale is optional.
- Fixes crashes after focus loss (stability guard).
- Skips drawing off-screen meshes (frustum cull). One test in Kruger gave about 3× the frame rate. A size cull exists but is off and untested.

| Option | Effect |
|---|---|
| `--hud` / `--no-hud` | Turn the Metal FPS overlay on or off |
| `--no-display` | Skip the resolution-follows-display step |
| `uninstall --purge` | Also delete the Wine dir and prefix it created |

## sw3-trackpad (0.1.0)

Adds a keymap and trackpad gestures (`zlib1.dll` proxy + `sw3tp.so`).

**Keys:**
- U: free camera
- J: target camera
- K: chase camera
- O: azimuth camera
- F2 / F4: edge rotation off / on
- F6: console

**Gestures in space flight:**

| Gesture | Action |
|---|---|
| Pinch | Zoom (Ctrl+pinch: fine zoom) |
| Two-finger scroll | Orbit the camera |
| Two-finger rotate | Yaw |
| Shift+scroll | Change altitude of the selected ships |
| Option+scroll | Pan the free camera or the Tab map |
| Force click | Select and focus. On the focused ship: stop following |
| Two-finger double tap | Switch camera |
| Ctrl+two-finger double tap | Aggressive order at the pointer |

**macOS settings the gestures need:** turn these on: F-keys as standard function keys, Smart zoom, Force Click, and Zoom and Rotate.

| Option | Effect |
|---|---|
| `--no-keymap` | Install gestures only |
| `--no-gestures` | Install the keymap only |
| `uninstall --reset-profile-cvars` | Remove the cvar lines it added to your profile |

To switch the gestures off without uninstalling, set `enabled=0` in `sw3tp.ini`.

## sw3-infinite-view (0.2.0)

Draws the whole system: stations, portals, asteroids and clouds no longer fade out at 800 units. Ships are still shown only within sensor range.

| Option | Effect |
|---|---|
| `--view N` | Far plane, 1000–20000. Default 6000; vanilla is 800 |
| `--fade N\|keep` | Width of the mesh fade band. Default 500 |
| `--fog clear\|keep` | `keep` rescales fog so haze still ends at 800 units |
| `--dry-run` | Print the changes without writing |

Restart the game after installing. Only `--view 1600` has been tested in game. 6000 may cause depth flicker or a lower frame rate in dense systems; if it does, use a lower `--view`.

## sw3-traffic (0.1.0-dev)

Adds a living economy: NPC traders, pirate clans, factions and jobs, written as Lua scripts loaded by the sw3tp proxy. No game files are edited.

**Status:** host-tested only. The hooks, save/load and the first jobs card have been seen working in game. A full in-game pass is still open.

**Traffic and economy**
- Named FTU traders fly between portals and stations, and dock in a queue where you get priority.
- Each region cycles through Quiet, Boom, Build-up, Raids, Bust and Recovery. Prosperity sets how many traders fly and how big they are.
- Lost traders cause shortages, and stations pay +50 % for the missing cargo.
- Supply, TT4, equipment and danger convoys run. Killing a big convoy forces a Bust.
- Attacking traders raises your heat. Traders then flee or refuse to deal, and an FTU station can clear heat for a fee.

**Pirates and factions**
- Pirate clans raid the lanes. Traders comply or call for help, and helping them pays.
- Clans grow from tier 1 to 4. At tier 4 they bring carrier raids.
- Clans can found pirate bases, which carry a bounty.
- Factions sweep against the clans, and you can join for pay.
- Each clan region has a wanted captain with a bounty, and you can buy informant tips about them.
- You can demand cargo from a trader.
- Opt-in (`haunt=1`): vanilla pirate patrols scale with the region's state and stay dead once destroyed.
- Opt-in (`fits=1`): pirate loadouts vary with clan strength.

**Jobs and quests**
- Hail menu: trade, ask where a ship is headed or for news, take escort contracts, call for combat help.
- Sealed parcels from a courier desk, with a deposit and a deadline.
- FTU charter goals per region, with ranks and perks (chapter 5+).
- Wolves Freight: run up to 3 chartered freighters for income (chapter 5+). It is unlocked by the quest "Missing in Capricorn".
- Jobs are shown as cards in the mission window.
- The Office jobs board and the job log are built but off by default.
- Opt-in (`merc=1`): 12 mercenary clans work the regions, and you can hire their packs for 10 minutes. Add `--merc-names` to give their pilots names.

**Stations and standing**
- Dockmasters greet you by standing, and the harbour has news and tips. Docking fees apply from chapter 5.
- Local events: ore-barge rescue, tanker shuttle, refugee launch.
- Rank ladder for all five factions, with transit permits, settle-the-file offers and prisoners of war.
- The patrol board lists raid reports, booming lanes, wanted captains and sweep offers.

**Salvage and intel**
- Collect distress beacons and escape pods (up to 6) and hand them in for credits or standing.
- Wreck fields with loot appear in Bust or raided systems.
- Hidden clan stashes sit in asteroid belts. A clan treasurer comes to take the cargo back.

**Fixes**
- An extortion contact stays neutral until you answer it, so your turrets no longer fire first (`ext_fix`).

**Options**

| Option | Effect |
|---|---|
| `--news` | Merge 224 news posts into `News.xml` |
| `--merc-names` | Merge 120 named mercenary pilots into `Pilots.xml` |
| `--reset-config` | Replace an edited `config.script` with the defaults |
| `--restore-only` | Remove the mod's changes from your save. See uninstall below |

Feature toggles (`haunt`, `fits`, `merc`, …) are set in `Data/Scripts/Mods/Traffic/config.script`.

**Uninstall:**
1. Run `install.sh --restore-only`.
2. Load your save in the game. This removes the mod's pirate bases. Changed station prices are reset when you dock at those stations. Save the game.
3. Run `uninstall.sh`.
