"""xbox360-games: the Games Library's data — every installed game as JSON.

Steam: every library in libraryfolders.vdf, each appmanifest_*.acf (name,
LastPlayed), minus Proton/runtimes/redistributables; artwork from Steam's own
librarycache (the capsule, the header, the small icon).
Heroic: Epic (legendary) and GOG installs, minus DLC; icons from Heroic's
icon cache, covers from its store cache.

Output, newest-played first: [{ id, name, source, lastPlayed, icon, art, cmd }].
Argument: a JSON config { steam: <launch command or "">, heroic: <...> }.
"""

import glob
import json
import os
import re
import sys

CFG = json.loads(sys.argv[1]) if len(sys.argv) > 1 else {}
HOME = os.path.expanduser("~")
STEAM = os.path.join(HOME, ".local/share/Steam")
HEROIC = os.path.join(HOME, ".config/heroic")

# Installed "apps" that are not games.
NOT_GAMES = re.compile(r"Proton|Steam Linux Runtime|Steamworks Common|Steam Audio|"
                       r"SteamVR|Redistributable|Dedicated Server|Soundtrack", re.I)


def vdf_values(text, key):
    return re.findall(r'"%s"\s+"([^"]*)"' % re.escape(key), text)


def first(paths):
    for p in paths:
        if p and os.path.isfile(p):
            return "file://" + p
    return ""


def steam_games():
    if not CFG.get("steam"):
        return []
    try:
        libs = vdf_values(open(os.path.join(STEAM, "steamapps/libraryfolders.vdf")).read(), "path")
    except OSError:
        libs = [STEAM]
    out, seen = [], set()
    for lib in libs:
        for acf in glob.glob(os.path.join(lib, "steamapps/appmanifest_*.acf")):
            try:
                text = open(acf, errors="replace").read()
            except OSError:
                continue
            appid = (vdf_values(text, "appid") or [""])[0]
            name = (vdf_values(text, "name") or [""])[0]
            if not appid or appid in seen or not name or NOT_GAMES.search(name):
                continue
            seen.add(appid)
            last = int((vdf_values(text, "LastPlayed") or ["0"])[0] or 0)
            cache = os.path.join(STEAM, "appcache/librarycache", appid)
            # Newer Steam keeps art in hashed subdirectories; older, flat.
            capsule = glob.glob(os.path.join(cache, "**/library_capsule.jpg"), recursive=True) \
                + glob.glob(os.path.join(cache, "library_600x900.jpg"))
            header = glob.glob(os.path.join(cache, "**/library_header.jpg"), recursive=True) \
                + glob.glob(os.path.join(cache, "header.jpg"))
            icons = [p for p in glob.glob(os.path.join(cache, "*.jpg"))
                     if os.path.basename(p) not in ("header.jpg", "library_600x900.jpg")]
            out.append({
                "id": "steam:" + appid, "name": name, "source": "Steam", "lastPlayed": last,
                "icon": first(icons) or first(header), "art": first(capsule) or first(header),
                "cmd": CFG["steam"] + " steam://rungameid/" + appid,
            })
    return out


def heroic_games():
    if not CFG.get("heroic"):
        return []
    out = []
    covers = {}
    for lib in ("legendary_library.json", "gog_library.json"):
        try:
            data = json.load(open(os.path.join(HEROIC, "store_cache", lib)))
            for g in data.get("library", data.get("games", [])) or []:
                covers[g.get("app_name")] = g.get("art_square") or g.get("art_cover") or ""
        except (OSError, ValueError, AttributeError):
            pass
    sources = [
        ("legendary", "Epic", os.path.join(HEROIC, "legendaryConfig/legendary/installed.json")),
        ("gog", "GOG", os.path.join(HEROIC, "gog_store/installed.json")),
    ]
    for runner, label, path in sources:
        try:
            data = json.load(open(path))
        except (OSError, ValueError):
            continue
        games = data.get("installed", list(data.values())) if isinstance(data, dict) else data
        for g in games:
            if not isinstance(g, dict) or g.get("is_dlc"):
                continue
            app = g.get("app_name") or g.get("appName")
            if not app:
                continue
            out.append({
                "id": runner + ":" + app, "name": g.get("title") or app, "source": label,
                "lastPlayed": 0,
                "icon": first([os.path.join(HEROIC, "icons", app + ".jpg"),
                               os.path.join(HEROIC, "icons", app + ".png")]),
                "art": covers.get(app, ""),
                "cmd": CFG["heroic"] + " --no-gui 'heroic://launch?appName=%s&runner=%s'" % (app, runner),
            })
    return out


games = steam_games() + heroic_games()
games.sort(key=lambda g: (-g["lastPlayed"], g["name"].lower()))
print(json.dumps(games))
