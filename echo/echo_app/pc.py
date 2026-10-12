"""Управление компьютером: громкость, музыка, окна, скриншоты, файлы, папки, процессы, настройки Windows."""
import ctypes
import os
import subprocess
import sys
import threading
import time
import webbrowser
from pathlib import Path
from urllib.parse import quote_plus

import psutil

from .config import data_dir

IS_WIN = sys.platform == "win32"
NO_WINDOW = 0x08000000 if IS_WIN else 0

VK = {"vol_up": 0xAF, "vol_down": 0xAE, "mute": 0xAD, "next": 0xB0, "prev": 0xB1, "play_pause": 0xB3,
      "stop": 0xB2, "alt": 0x12, "tab": 0x09, "win": 0x5B, "d": 0x44}


_com = threading.local()


def com_init():
    """COM нужно инициализировать в каждом фоновом потоке (pycaw, SAPI, WMI)."""
    if IS_WIN and not getattr(_com, "ok", False):
        try:
            import comtypes
            comtypes.CoInitialize()
        except Exception:
            pass
        _com.ok = True


def press(*keys):
    if not IS_WIN:
        raise RuntimeError("Доступно только в Windows")
    u = ctypes.windll.user32
    for k in keys:
        u.keybd_event(VK[k], 0, 0, 0)
    for k in reversed(keys):
        u.keybd_event(VK[k], 0, 2, 0)


def run_ps(cmd: str, timeout=60) -> str:
    r = subprocess.run(["powershell", "-NoProfile", "-NonInteractive", "-Command", cmd],
                       capture_output=True, text=True, timeout=timeout, creationflags=NO_WINDOW,
                       encoding="utf-8", errors="ignore")
    return (r.stdout or r.stderr).strip()


# ---------- громкость ----------
def _endpoint():
    from pycaw.pycaw import AudioUtilities
    return AudioUtilities.GetSpeakers().EndpointVolume


def set_volume(percent: int):
    percent = max(0, min(100, int(percent)))
    try:
        _endpoint().SetMasterVolumeLevelScalar(percent / 100, None)
    except Exception:
        # запасной путь: опустить до 0 и поднять шагами по 2%
        for _ in range(50):
            press("vol_down")
        for _ in range(percent // 2):
            press("vol_up")
    return f"Громкость {percent}%"


def get_volume():
    try:
        return round(_endpoint().GetMasterVolumeLevelScalar() * 100)
    except Exception:
        return None


def change_volume(delta: int):
    cur = get_volume()
    if cur is None:
        for _ in range(abs(delta) // 2):
            press("vol_up" if delta > 0 else "vol_down")
        return "Громкость изменена"
    return set_volume(cur + delta)


def mute():
    press("mute")
    return "Звук переключён"


def media(action: str):
    press({"play": "play_pause", "pause": "play_pause", "next": "next", "prev": "prev", "stop": "stop"}[action])
    return {"play": "Воспроизведение", "pause": "Пауза", "next": "Следующий трек",
            "prev": "Предыдущий трек", "stop": "Стоп"}[action]


# ---------- окна ----------
def list_windows():
    if not IS_WIN:
        return []
    u = ctypes.windll.user32
    res = []

    @ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)
    def cb(hwnd, _):
        if u.IsWindowVisible(hwnd):
            n = u.GetWindowTextLengthW(hwnd)
            if n:
                buf = ctypes.create_unicode_buffer(n + 1)
                u.GetWindowTextW(hwnd, buf, n + 1)
                res.append((hwnd, buf.value))
        return True
    u.EnumWindows(cb, 0)
    return [(h, t) for h, t in res if t not in ("Program Manager",)]


def focus_window(query: str):
    q = query.lower()
    for hwnd, title in list_windows():
        if q in title.lower():
            u = ctypes.windll.user32
            u.ShowWindow(hwnd, 9)  # SW_RESTORE
            press("alt")           # снимает блокировку SetForegroundWindow
            u.SetForegroundWindow(hwnd)
            return f"Переключаюсь на «{title}»"
    return f"Окно «{query}» не найдено"


def switch_window():
    press("alt", "tab")
    return "Переключил окно"


def show_desktop():
    press("win", "d")
    return "Свернул всё"


# ---------- процессы ----------
def find_processes(name: str):
    n = name.lower().removesuffix(".exe")
    out = []
    for p in psutil.process_iter(["pid", "name"]):
        pn = (p.info["name"] or "").lower().removesuffix(".exe")
        if pn and (pn == n or n in pn):
            out.append(p)
    return out


def close_program(name: str):
    procs = find_processes(name)
    if not procs:
        return f"Не нашёл запущенную программу «{name}»"
    for p in procs:
        try:
            p.terminate()
        except psutil.Error:
            pass
    return f"Закрыл {procs[0].info['name']} ({len(procs)} проц.)"


# ---------- скриншоты ----------
def screenshot(save=True):
    from PIL import ImageGrab
    img = ImageGrab.grab(all_screens=True)
    if not save:
        return img, None
    folder = Path.home() / "Pictures" / "ECHO"
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / time.strftime("screenshot_%Y-%m-%d_%H-%M-%S.png")
    img.save(path)
    return img, str(path)


# ---------- файлы и папки ----------
KNOWN_FOLDERS = {"загрузки": "Downloads", "документы": "Documents", "рабочий стол": "Desktop",
                 "изображения": "Pictures", "картинки": "Pictures", "музыка": "Music", "видео": "Videos",
                 "скриншоты": "Pictures/ECHO"}


def open_path(p: str):
    if IS_WIN:
        os.startfile(p)  # noqa
    else:
        subprocess.Popen(["xdg-open", p])


def open_folder(name: str):
    key = name.lower().strip()
    if key in KNOWN_FOLDERS:
        p = Path.home() / KNOWN_FOLDERS[key]
    else:
        p = Path(os.path.expandvars(os.path.expanduser(name)))
    if not p.exists():
        return f"Папка «{name}» не найдена"
    open_path(str(p))
    return f"Открываю {p}"


def search_files(query: str, roots=None, limit=20, timeout=8.0):
    q = query.lower()
    roots = roots or [Path.home() / d for d in ("Desktop", "Documents", "Downloads", "Pictures", "Music", "Videos")]
    res, t0 = [], time.time()
    for root in roots:
        for dp, dns, fns in os.walk(root):
            dns[:] = [d for d in dns if not d.startswith(".") and d not in ("node_modules", "AppData", "__pycache__")]
            for f in fns + dns:
                if q in f.lower():
                    res.append(os.path.join(dp, f))
                    if len(res) >= limit:
                        return res
            if time.time() - t0 > timeout:
                return res
    return res


# ---------- веб ----------
SITES = {"ютуб": "https://youtube.com", "youtube": "https://youtube.com", "гугл": "https://google.com",
         "вк": "https://vk.com", "вконтакте": "https://vk.com", "гитхаб": "https://github.com",
         "твич": "https://twitch.tv", "яндекс": "https://ya.ru", "почта": "https://mail.google.com",
         "чатгпт": "https://chatgpt.com", "клод": "https://claude.ai"}


def open_site(name: str):
    url = SITES.get(name.lower().strip(), name.strip())
    if "." not in url and not url.startswith("http"):
        return web_search(name)
    if not url.startswith("http"):
        url = "https://" + url
    webbrowser.open(url)
    return f"Открываю {url}"


def web_search(query: str):
    webbrowser.open("https://www.google.com/search?q=" + quote_plus(query))
    return f"Ищу в интернете: {query}"


# ---------- настройки Windows (разрешённый список) ----------
SETTINGS_PAGES = {"display": "ms-settings:display", "sound": "ms-settings:sound", "bluetooth": "ms-settings:bluetooth",
                  "wifi": "ms-settings:network-wifi", "network": "ms-settings:network", "update": "ms-settings:windowsupdate",
                  "apps": "ms-settings:appsfeatures", "power": "ms-settings:powersleep", "personalization":
                  "ms-settings:personalization", "privacy": "ms-settings:privacy", "storage": "ms-settings:storagesense",
                  "notifications": "ms-settings:notifications", "defender": "windowsdefender:", "mouse": "ms-settings:mousetouchpad"}


def open_settings(page: str):
    uri = SETTINGS_PAGES.get(page)
    if not uri:
        return "Такой раздел настроек не поддерживается"
    open_path(uri)
    return f"Открываю настройки: {page}"


def set_dark_theme(dark: bool):
    import winreg
    key = r"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, key, 0, winreg.KEY_SET_VALUE) as k:
        for v in ("AppsUseLightTheme", "SystemUsesLightTheme"):
            winreg.SetValueEx(k, v, 0, winreg.REG_DWORD, 0 if dark else 1)
    return "Тёмная тема включена" if dark else "Светлая тема включена"


def set_brightness(percent: int):
    percent = max(0, min(100, int(percent)))
    run_ps(f"(Get-WmiObject -Namespace root/WMI -Class WmiMonitorBrightnessMethods).WmiSetBrightness(1,{percent})")
    return f"Яркость {percent}%"


def lock_pc():
    ctypes.windll.user32.LockWorkStation()
    return "Блокирую компьютер"


def power(action: str):
    cmds = {"shutdown": ["shutdown", "/s", "/t", "30"], "restart": ["shutdown", "/r", "/t", "30"],
            "cancel": ["shutdown", "/a"], "sleep": ["rundll32.exe", "powrprof.dll,SetSuspendState", "0,1,0"]}
    subprocess.Popen(cmds[action], creationflags=NO_WINDOW)
    return {"shutdown": "Выключение через 30 секунд", "restart": "Перезагрузка через 30 секунд",
            "cancel": "Выключение отменено", "sleep": "Перевожу в сон"}[action]


# ---------- автозапуск ----------
RUN_KEY = r"Software\Microsoft\Windows\CurrentVersion\Run"


def set_autostart(enabled: bool):
    if not IS_WIN:
        return
    import winreg
    if getattr(sys, "frozen", False):
        cmd = f'"{sys.executable}" --minimized'
    else:
        pyw = Path(sys.executable).with_name("pythonw.exe")
        cmd = f'"{pyw if pyw.exists() else sys.executable}" "{Path(sys.argv[0]).resolve()}" --minimized'
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, RUN_KEY, 0, winreg.KEY_SET_VALUE) as k:
        if enabled:
            winreg.SetValueEx(k, "ECHO", 0, winreg.REG_SZ, cmd)
        else:
            try:
                winreg.DeleteValue(k, "ECHO")
            except OSError:
                pass


def clipboard_text():
    from PySide6.QtGui import QGuiApplication
    return QGuiApplication.clipboard().text()


def log_path():
    return data_dir() / "echo.log"
