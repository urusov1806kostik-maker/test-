# PyInstaller spec — запуск: pyinstaller installer\echo.spec (из папки echo)
from PyInstaller.utils.hooks import collect_data_files, collect_submodules
import os
ROOT = os.path.abspath(os.path.join(SPECPATH, ".."))
datas = [(os.path.join(ROOT, "assets"), "assets")]
datas += collect_data_files("vosk") + collect_data_files("speech_recognition") + collect_data_files("edge_tts")
hidden = (collect_submodules("pyttsx3.drivers") + collect_submodules("comtypes") + collect_submodules("pycaw")
          + ["win32timezone", "keyring.backends.Windows", "webrtcvad", "telethon", "discord"])

a = Analysis([os.path.join(ROOT, "main.py")], pathex=[ROOT], datas=datas, hiddenimports=hidden, hookspath=[os.path.join(SPECPATH, "hooks")],
             excludes=["tkinter", "matplotlib", "PyQt5", "PyQt6"], noarchive=False)
pyz = PYZ(a.pure)
exe = EXE(pyz, a.scripts, [], exclude_binaries=True, name="ECHO", console=False,
          icon=os.path.join(ROOT, "assets", "echo.ico"), version=None, uac_admin=False)
coll = COLLECT(exe, a.binaries, a.datas, name="ECHO", strip=False, upx=False)
