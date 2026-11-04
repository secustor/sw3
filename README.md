# Star Wolves 3: Civil War mods for macOS

These mods are for the GOG build of Star Wolves 3: Civil War (v1.12) on an Apple Silicon Mac, running through Heroic.

| Mod | What it does |
|---|---|
| [sw3-performance](#sw3-performance-010) | Runs the game on native arm64 Wine in fullscreen at your display's resolution |
| [sw3-trackpad](#sw3-trackpad-010) | Adds camera keys and trackpad gestures |
| [sw3-infinite-view](#sw3-infinite-view-020) | Draws the whole star system instead of fading it out at 600 to 800 units |
| [sw3-traffic](#sw3-traffic-010-dev) | Adds NPC traders, pirate clans, factions and jobs |

## Install

**You need:**
- macOS 26.4 or later on Apple Silicon
- Heroic 2.22.x, with the game installed through Heroic
- The game's settings opened once in Heroic, so it writes its per-game config

**Steps:**
1. Quit Heroic and the game.
2. Unpack the zip.
3. Open Terminal in that folder and run:

```sh
./install.sh --mod all            # or pick: --mod performance --mod trackpad ...
./uninstall.sh --mod all
```

In the `sw3-infinite-view` and `sw3-traffic` zips, run `./install.sh "<game dir>"` and `./uninstall.sh "<game dir>"` instead; their installers have no `--mod`. With sw3-traffic installed, do its [uninstall steps](#sw3-traffic-010-dev) first, or your saves keep its pirate bases and changed station prices.

**How the installer works:**
- Mods install in this order: performance, trackpad, infinite_view, traffic. They uninstall in reverse.
- traffic needs the `zlib1.dll` proxy, which trackpad or performance installs.
- The game dir is read from Heroic. Use `--game-dir <path>` to override it.
- Mod options pass through the combined installer; values go as `--name=value`. `./install.sh --help` and `./uninstall.sh --help` list every option.
- Each mod folder also has its own `install.sh` / `uninstall.sh`, which takes the game dir as an argument.
- Every installer backs up the files it changes and puts those copies back on uninstall, so later changes to them are lost too: Heroic's game settings and the game's `default.cfg` (performance), `Main.ini` (infinite_view).

**Release zips:**

| Zip | Contains |
|---|---|
| `sw3-mods-pack-<v>.zip` | performance and trackpad, with the combined installer |
| `sw3-performance-<v>.zip` | performance alone, with its own installer |
| `sw3-trackpad-<v>.zip` | trackpad alone, with its own installer |
| `sw3-infinite-view-<v>.zip` | infinite_view, shipped separately |
| `sw3-traffic-<v>.zip` | traffic, shipped separately |

## sw3-performance (0.1.0)

Runs the game on native arm64 Wine, without Rosetta. The game itself is still 32-bit x86 code, emulated by FEX.

- Downloads native arm64 Wine (`arm64-11.19-2`: FEX, mtld3d D3D9→Metal). The download is SHA-256 checked and needs no Rosetta.
- Creates the prefix `sw3-arm64` with `EmulateModeset=Y` and points Heroic's game config at it.
- Runs the game borderless fullscreen. This avoids the windowed-mode crash, and Cmd+Tab releases the mouse.
- Matches the game's resolution to the main display, so the mouse maps 1:1 with no black bars. Render scale is optional.
- Fixes crashes after focus loss (stability guard).
- Skips drawing off-screen meshes (frustum cull). One test in Kruger gave about 3× the frame rate. A size cull exists but is off and untested.

| Option | Effect |
|---|---|
| `--hud` / `--no-hud` | Turn the Metal FPS overlay on or off |
| `--no-display` | Skip the resolution-follows-display step. Without sw3-trackpad this also skips the sw3tp proxy, so the crash fix and the frustum cull are not installed |
| `uninstall --purge` | Also delete the Wine dir and prefix it created |

## sw3-trackpad (0.1.0)

Adds a keymap and trackpad gestures (`zlib1.dll` proxy + `sw3tp.so`). The gestures need the arm64 Wine that sw3-performance installs; under x86_64 Wine (Rosetta) the game runs without them.

**Keys:**
- U: free camera (F9)
- J: follow camera (F10)
- K: view camera, third person (F11)
- O: chase camera (F12)
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

To switch the gestures off without uninstalling, set `enabled=0` under `[sw3tp]` in `sw3tp.ini`.

## sw3-infinite-view (0.2.0)

Shipped separately as `sw3-infinite-view-<v>.zip`, not in the mods pack.

Draws the whole system: stations, portals and asteroids no longer fade out by 600 units, and clouds no longer stop at 800. Ships are still shown only within sensor range.

| Option | Effect |
|---|---|
| `--view=N` | Far plane, 1000–20000. Default 6000; vanilla is 800 |
| `--fade=N\|keep` | Width of the mesh fade band. Default 500 |
| `--fog=clear\|keep` | `keep` rescales fog so haze still ends at 800 units |
| `--dry-run` | Print the changes without writing |

Restart the game after installing. Only `--view=1600` has been tested in game. 6000 may cause depth flicker or a lower frame rate in dense systems; if it does, use a lower `--view`.

## sw3-traffic (0.1.0-dev)

Shipped separately as `sw3-traffic-<v>.zip`, not in the mods pack.

Adds NPC traders, pirate clans, factions and jobs, written as Lua scripts loaded by the sw3tp proxy. Every install also merges eight quest pilots into `Data/Game/Pilots.xml` (and with `--news`, news posts into `News.xml`); both are backed up and restored on uninstall.

**Status:** mostly host-tested. The hooks, save/load and the first jobs card have been seen working in game. A full in-game pass is still open.

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
- Each clan has a raid style: some open fire without a word, some talk first, some pick their targets, some appear out of nowhere. The intro quest "Clan file" puts the style on the patrol board (`temper`; not yet tested in game).
- Opt-in (`haunt=1`, chapter 5+): vanilla pirate patrols follow the region's phase and clan tier, never above vanilla numbers. Destroyed patrols come back slowly: 15 % of the system's patrols every two jumps or 10 game minutes.
- Opt-in (`fits=1`): pirate loadouts vary with clan strength.

**Jobs and quests**
- Hail menu: trade, ask where a ship is headed, for news or for troubled and booming lanes, and take escort contracts. A trader in a fight skips the menu and may pay you to drive off its attackers.
- Sealed parcels from a courier desk, with a deposit and a deadline.
- FTU charter goals per region, with ranks and perks (chapter 5+).
- Wolves Freight: run up to 3 chartered freighters for income (chapter 5+). It is unlocked by the quest "Missing in Capricorn".
- Job offers open as message boxes.
- A mission-window card for offers, the Office jobs board and a job log are built but off by default (`jobs_card`, `jobs_board`, `jobs_log` in `sw3tp.ini`).
- Opt-in (`merc=1`): 12 mercenary clans work the regions, and you can hire their packs for 10 minutes. Add `--merc-names` to give their pilots names.

**Stations and standing**
- Dockmasters greet you by standing, and the harbour has news and tips. Docking fees apply from chapter 5.
- Local events: ore-barge rescue, tanker shuttle, refugee launch.
- Rank ladder for all five factions, with transit permits, settle-the-file offers and prisoners of war.
- The patrol board lists raid reports, booming lanes, wanted captains and sweep offers.
- Warnings for 23 systems that kill, ambush or trap an arriving mothership: a dockmaster line at a trade station one jump away, a note on the first visit, a line at the portal (`warn`; not yet tested in game).
- Your wingmen remark on a system's recent history when you arrive: a lost freighter, a navy sweep, a fallen pirate base, a captain killed by a sweep (`remarks`; not yet tested in game).

**Salvage and intel**
- Collect distress beacons and escape pods (up to 6) and hand them in for credits or standing.
- Wreck fields with loot appear in Bust or raided systems.
- Hidden clan stashes sit in asteroid belts. A clan treasurer comes to take the cargo back.

**Fixes**
- An extortion contact stays neutral until you answer it, so your turrets no longer fire first (`ext_fix`).

**Options**

| Option | Effect |
|---|---|
| `--news` | Merge the mod's news posts into `News.xml` |
| `--merc-names` | Merge 120 named mercenary pilots into `Pilots.xml` |
| `--reset-config` | Replace an edited `config.script` with the defaults |
| `--restore-only` | Clean-up mode before uninstalling: the mod only resets the station prices it changed and removes its pirate bases. Its other data stays in the save and is ignored without the mod. See uninstall below |

Feature toggles (`haunt`, `fits`, `merc`, …) are set in `Data/Scripts/Mods/Traffic/config.script`.

A reinstall keeps an edited `config.script`, so after `--news` or `--merc-names` set `news_mode=2` or `mc_names=2` in it yourself. Pass these options on every reinstall; a run without them removes the news posts or the pilot names.

**Uninstall:**
1. Run `./install.sh --mod traffic --restore-only` (from the sw3-traffic zip: `./install.sh --restore-only "<game dir>"`).
2. Load your save and play on: a mod pirate base is removed when you enter its system, a changed station price when you dock there. `sw3tp.log` lists what is left (`module=shop event=dump restore_list=`); save once it shows `event=restore pending_count=0 result=done` (and `event=bases_removed` if the mod founded bases).
3. Run `./uninstall.sh --mod traffic` (from the zip: `./uninstall.sh "<game dir>"`).

## More

- [macOS setup notes](docs/macos-setup.md): the manual Wine/Heroic setup, problems and fixes, known issues and risks
- Mod details: [performance](mods/performance/README.md), [trackpad](mods/trackpad/README.md), [infinite_view](mods/infinite_view/README.md), [traffic](mods/traffic/README.md)
- Build the release zips with `./release.sh`
- Contributing with an AI agent: [AGENTS.md](AGENTS.md)
- Installing from a clone: build the trackpad proxy first ([Building from source](mods/trackpad/README.md#building-from-source)). `build.sh` compiles against the Wine that sw3-performance downloads, so run `./install.sh --mod performance --no-display` once before it.
