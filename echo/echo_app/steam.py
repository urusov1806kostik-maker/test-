"""Steam: поиск библиотек и игр через libraryfolders.vdf / appmanifest_*.acf, запуск через steam://."""
import os
import re
import sys
from pathlib import Path
from difflib import SequenceMatcher

import psutil

IS_WIN = sys.platform == "win32"
GAME_ALIASES = {"кс": "counter-strike 2", "кс2": "counter-strike 2", "кс 2": "counter-strike 2",
                "контра": "counter-strike 2", "каэс": "counter-strike 2", "дота": "dota 2", "дота 2": "dota 2",
                "раст": "rust", "пабг": "pubg", "апекс": "apex legends", "гта": "grand theft auto v",
                "майнкрафт": "minecraft", "тф2": "team fortress 2"}


def steam_path() -> Path | None:
    if IS_WIN:
        import winreg
        for root, key in ((winreg.HKEY_CURRENT_USER, r"Software\Valve\Steam"),
                          (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\WOW6432Node\Valve\Steam")):
            try:
                with winreg.OpenKey(root, key) as k:
                    for v in ("SteamPath", "InstallPath"):
                        try:
                            p = Path(winreg.QueryValueEx(k, v)[0])
                            if p.exists():
                                return p
                        except OSError:
                            pass
            except OSError:
                pass
        p = Path(r"C:\Program Files (x86)\Steam")
        return p if p.exists() else None
    p = Path.home() / ".steam/steam"
    return p if p.exists() else None


def _vdf_values(text, key):
    return re.findall(r'"%s"\s+"([^"]*)"' % key, text)


def find_games() -> dict[str, dict]:
    """{appid: {name, dir}}"""
    sp = steam_path()
    if not sp:
        return {}
    libs = {sp}
    lf = sp / "steamapps" / "libraryfolders.vdf"
    if lf.exists():
        for p in _vdf_values(lf.read_text("utf-8", "ignore"), "path"):
            libs.add(Path(p.replace("\\\\", "\\")))
    games = {}
    for lib in libs:
        apps = lib / "steamapps"
        if not apps.exists():
            continue
        for acf in apps.glob("appmanifest_*.acf"):
            t = acf.read_text("utf-8", "ignore")
            appid = (_vdf_values(t, "appid") or [None])[0]
            name = (_vdf_values(t, "name") or [None])[0]
            inst = (_vdf_values(t, "installdir") or [""])[0]
            if appid and name and "redistributable" not in name.lower() and "steamworks" not in name.lower():
                games[appid] = {"name": name, "dir": str(apps / "common" / inst)}
    return games


def match_game(query: str, games=None):
    games = games if games is not None else find_games()
    q = query.lower().strip()
    q = GAME_ALIASES.get(q, q)
    best, score = None, 0.0
    for appid, g in games.items():
        n = g["name"].lower()
        s = SequenceMatcher(None, q, n).ratio() + (0.5 if q in n else 0)
        if s > score:
            best, score = (appid, g), s
    return best if score >= 0.55 else None


def _open(uri):
    if IS_WIN:
        os.startfile(uri)  # noqa
    else:
        import subprocess
        subprocess.Popen(["xdg-open", uri])


def launch_game(appid):
    _open(f"steam://rungameid/{appid}")


def open_steam():
    _open("steam://open/main")


def running_games(games=None):
    games = games if games is not None else find_games()
    dirs = {os.path.normcase(g["dir"]): (a, g) for a, g in games.items()}
    res = {}
    for p in psutil.process_iter(["pid", "exe"]):
        exe = p.info.get("exe")
        if not exe:
            continue
        ne = os.path.normcase(exe)
        for d, (a, g) in dirs.items():
            if ne.startswith(d + os.sep):
                res.setdefault(a, {"name": g["name"], "pids": []})["pids"].append(p.info["pid"])
    return res


def close_game(appid, games=None):
    r = running_games(games).get(appid)
    if not r:
        return False
    for pid in r["pids"]:
        try:
            psutil.Process(pid).terminate()
        except psutil.Error:
            pass
    return True
