# PyInstaller spec — запуск: pyinstaller installer\echo.spec (из папки echo)
from PyInstaller.utils.hooks import collect_data_files, collect_submodules, collect_dynamic_libs
import os
ROOT = os.path.abspath(os.path.join(SPECPATH, ".."))
datas = [(os.path.join(ROOT, "assets"), "assets")]
if os.path.isdir(os.path.join(ROOT, "voices")):          # встроенный голос Piper (скачивается в CI)
    datas.append((os.path.join(ROOT, "voices"), "voices"))
datas += collect_data_files("piper") + collect_data_files("vosk") + collect_data_files("speech_recognition") + collect_data_files("edge_tts")
hidden = (collect_submodules("pyttsx3.drivers") + collect_submodules("comtypes") + collect_submodules("pycaw")
          + collect_submodules("piper") + ["win32timezone", "keyring.backends.Windows", "webrtcvad", "telethon", "discord"])

a = Analysis([os.path.join(ROOT, "main.py")], pathex=[ROOT], datas=datas, binaries=collect_dynamic_libs("piper"), hiddenimports=hidden, hookspath=[os.path.join(SPECPATH, "hooks")],
             excludes=["tkinter", "matplotlib", "PyQt5", "PyQt6"], noarchive=False)
# убираем то, что E.C.H.O не использует (меньше установщик): QML/Quick/PDF, чужие переводы Qt,
# англ. модель pocketsphinx, данные Piper для иврита/арабского, программный OpenGL
DROP = ("Qt6Pdf", "Qt6Qml", "Qt6Quick", "Qt6VirtualKeyboard", "qpdf", "opengl32sw", "pocketsphinx-data",
        os.path.join("piper", "hebrew"), os.path.join("piper", "tashkeel"))
KEEP_TR = ("qt_ru", "qtbase_ru")


def _keep(entry):
    dest = entry[0].replace("/", os.sep)
    if any(d in dest for d in DROP):
        return False
    if os.sep + "translations" + os.sep in dest and dest.endswith(".qm"):
        return any(k in dest for k in KEEP_TR)
    return True


a.binaries = [e for e in a.binaries if _keep(e)]
a.datas = [e for e in a.datas if _keep(e)]
pyz = PYZ(a.pure)
exe = EXE(pyz, a.scripts, [], exclude_binaries=True, name="ECHO", console=False,
          icon=os.path.join(ROOT, "assets", "echo.ico"), version=None, uac_admin=False)
coll = COLLECT(exe, a.binaries, a.datas, name="ECHO", strip=False, upx=False)
