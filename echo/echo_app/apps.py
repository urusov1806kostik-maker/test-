"""Поиск установленных программ: ярлыки меню «Пуск», рабочий стол, реестр (App Paths, Uninstall)."""
import os
import re
import subprocess
import sys
import threading
from difflib import SequenceMatcher
from pathlib import Path

IS_WIN = sys.platform == "win32"
if IS_WIN:
    import winreg

ALIASES = {
    "хром": "chrome", "гугл хром": "chrome", "браузер": "chrome", "файрфокс": "firefox", "эдж": "edge",
    "блокнот": "notepad", "калькулятор": "calc", "проводник": "explorer", "дискорд": "discord",
    "телеграм": "telegram", "телеграмм": "telegram", "стим": "steam", "спотифай": "spotify",
    "ворд": "word", "эксель": "excel", "вс код": "visual studio code", "вскод": "visual studio code",
    "обс": "obs", "диспетчер задач": "taskmgr", "панель управления": "control", "пэйнт": "mspaint",
    "паинт": "mspaint", "командная строка": "cmd", "терминал": "wt", "настройки": "ms-settings:",
}
BUILTIN = {"notepad": "notepad.exe", "calc": "calc.exe", "explorer": "explorer.exe", "taskmgr": "taskmgr.exe",
           "control": "control.exe", "mspaint": "mspaint.exe", "cmd": "cmd.exe", "wt": "wt.exe",
           "ms-settings:": "ms-settings:"}


def _norm(s: str) -> str:
    return re.sub(r"[^\w ]+", " ", s.lower()).strip()


class AppIndex:
    def __init__(self):
        self.apps: dict[str, str] = {}   # нормализованное имя -> путь
        self._lock = threading.Lock()
        self.ready = False

    def scan(self):
        found = {}
        if IS_WIN:
            dirs = [Path(os.environ.get("APPDATA", "")) / r"Microsoft\Windows\Start Menu\Programs",
                    Path(os.environ.get("PROGRAMDATA", "")) / r"Microsoft\Windows\Start Menu\Programs",
                    Path.home() / "Desktop", Path(os.environ.get("PUBLIC", "")) / "Desktop"]
            for d in dirs:
                if d.exists():
                    for p in d.rglob("*"):
                        if p.suffix.lower() in (".lnk", ".url", ".exe") and "uninstall" not in p.name.lower() \
                                and "удал" not in p.name.lower():
                            found.setdefault(_norm(p.stem), str(p))
            for root in (winreg.HKEY_LOCAL_MACHINE, winreg.HKEY_CURRENT_USER):
                try:
                    with winreg.OpenKey(root, r"SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths") as k:
                        for i in range(winreg.QueryInfoKey(k)[0]):
                            name = winreg.EnumKey(k, i)
                            try:
                                with winreg.OpenKey(k, name) as sk:
                                    path = winreg.QueryValue(sk, None)
                                    if path:
                                        found.setdefault(_norm(Path(name).stem), path.strip('"'))
                            except OSError:
                                pass
                except OSError:
                    pass
                for sub in (r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
                            r"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"):
                    try:
                        with winreg.OpenKey(root, sub) as k:
                            for i in range(winreg.QueryInfoKey(k)[0]):
                                try:
                                    with winreg.OpenKey(k, winreg.EnumKey(k, i)) as sk:
                                        name = winreg.QueryValueEx(sk, "DisplayName")[0]
                                        icon = winreg.QueryValueEx(sk, "DisplayIcon")[0].split(",")[0].strip('"')
                                        if icon.lower().endswith(".exe") and os.path.exists(icon):
                                            found.setdefault(_norm(name), icon)
                                except OSError:
                                    pass
                    except OSError:
                        pass
        for k, v in BUILTIN.items():
            found.setdefault(k, v)
        with self._lock:
            self.apps = found
            self.ready = True
        return len(found)

    def find(self, query: str):
        q = _norm(query)
        q = ALIASES.get(q, q)
        with self._lock:
            if q in self.apps:
                return q, self.apps[q]
            best, score = None, 0.0
            for name, path in self.apps.items():
                s = SequenceMatcher(None, q, name).ratio()
                if q in name.split() or name.startswith(q):
                    s += 0.5
                elif q in name:
                    s += 0.3
                if s > score:
                    best, score = (name, path), s
        return best if score >= 0.6 else None

    def list_names(self):
        return sorted(self.apps)


def launch(path: str):
    if IS_WIN:
        os.startfile(path)  # noqa
    else:
        subprocess.Popen(["xdg-open", path])


index = AppIndex()
