"""Register the gogdl-downloaded Star Wolves 3 in Heroic. Run only while Heroic is quit."""
import json, os, shutil, sys
from pathlib import Path

APP = "1426253436"
HOME = Path.home()
HEROIC = HOME / "Library/Application Support/heroic"
GAME = HOME / "Games/Heroic/Star Wolves 3 - Civil War"
WINE = HEROIC / "tools/wine/Wine-Crossover-latest/Contents/Resources/wine"

if not (GAME / f"goggame-{APP}.info").exists():
    sys.exit("goggame .info missing - download not complete")

size = sum(f.stat().st_size for f in GAME.rglob("*") if f.is_file())

installed_file = HEROIC / "gog_store/installed.json"
store = json.loads(installed_file.read_text())
store["installed"] = [g for g in store.get("installed", []) if g.get("appName") != APP]
store["installed"].append({
    "platform": "windows",
    "executable": "",
    "install_path": str(GAME),
    "install_size": f"{size / 1024**3:.2f} GiB",
    "is_dlc": False,
    "version": "1.12",
    "appName": APP,
    "installedDLCs": [],
    "language": "en-US",
    "versionEtag": "\"4fb38baa3017e983f8b13f12e5f2463e\"",
    "buildId": "49010528147732946",
    "pinnedVersion": False,
})
installed_file.write_text(json.dumps(store, indent=2))

config_file = HEROIC / f"GamesConfig/{APP}.json"
config = json.loads(config_file.read_text()) if config_file.exists() else {"version": "v0", "explicit": True}
config.setdefault(APP, {}).update({
    "wineVersion": {
        "bin": str(WINE / "bin/wine64"),
        "name": "Wine Crossover - 23.7.1-1",
        "type": "wine",
        "lib": str(WINE / "lib"),
        "lib32": str(WINE / "lib"),
        "wineserver": str(WINE / "bin/wineserver"),
    },
    "winePrefix": str(HOME / "Games/Heroic/Prefixes/shared"),
})
config_file.parent.mkdir(parents=True, exist_ok=True)
config_file.write_text(json.dumps(config, indent=2))

# Heroic expects gog-support and the manifest under its own gogdl config dir
gogdl_dir = HEROIC / "gogdlConfig/heroic_gogdl"
support_src, support_dst = GAME / "gog-support", gogdl_dir / "gog-support" / APP
if support_src.exists() and not support_dst.exists():
    support_dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(support_src), str(support_dst))

manifest_dst = gogdl_dir / "manifests" / APP
if not manifest_dst.exists():
    for base in (HOME / ".config/heroic_gogdl", HOME / "Library/Application Support/heroic_gogdl"):
        src = base / "manifests" / APP
        if src.exists():
            manifest_dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, manifest_dst)
            break

print("installed.json entry:", installed_file)
print("game config:", config_file)
print("support dir:", support_dst if support_dst.exists() else "none")
print("manifest:", manifest_dst if manifest_dst.exists() else "missing (Heroic recreates it on startup)")
