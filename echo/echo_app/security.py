"""E.C.H.O Security: Microsoft Defender, подозрительные процессы, автозагрузка."""
import json
import os
import sys
from pathlib import Path

import psutil

from .pc import run_ps, IS_WIN

MPCMD = Path(os.environ.get("ProgramFiles", r"C:\Program Files")) / "Windows Defender" / "MpCmdRun.exe"


def defender_status():
    if not IS_WIN:
        return {"error": "Только Windows"}
    out = run_ps("Get-MpComputerStatus | Select-Object AntivirusEnabled,RealTimeProtectionEnabled,"
                 "AntivirusSignatureLastUpdated,QuickScanEndTime,FullScanEndTime,AMServiceEnabled | ConvertTo-Json")
    try:
        return json.loads(out)
    except Exception:
        return {"error": out[:300]}


def quick_scan():
    run_ps("Start-MpScan -ScanType QuickScan", timeout=3600)
    return "Быстрая проверка завершена"


def full_scan_start():
    run_ps("Start-Process powershell -WindowStyle Hidden -ArgumentList '-Command','Start-MpScan -ScanType FullScan'")
    return "Полная проверка запущена в фоне"


def scan_file(path: str):
    if not os.path.exists(path):
        return f"Файл не найден: {path}"
    import subprocess
    r = subprocess.run([str(MPCMD), "-Scan", "-ScanType", "3", "-File", path, "-DisableRemediation"],
                       capture_output=True, text=True, timeout=600, creationflags=0x08000000)
    if r.returncode == 0:
        return "Угроз не найдено"
    if r.returncode == 2:
        return "ВНИМАНИЕ: обнаружена угроза!\n" + r.stdout[-500:]
    return "Ошибка проверки: " + (r.stdout or r.stderr)[-300:]


def threats():
    if not IS_WIN:
        return []
    out = run_ps("Get-MpThreatDetection | Select-Object ThreatID,InitialDetectionTime,ActionSuccess,"
                 "@{n='Resources';e={$_.Resources -join '; '}} | ConvertTo-Json")
    if not out:
        return []
    try:
        data = json.loads(out)
        return data if isinstance(data, list) else [data]
    except Exception:
        return []


SUSPICIOUS_DIRS = ("\\appdata\\local\\temp\\", "\\windows\\temp\\", "\\downloads\\", "\\$recycle.bin\\")
SYSTEM_NAMES = {"svchost.exe", "lsass.exe", "csrss.exe", "winlogon.exe", "services.exe", "explorer.exe", "smss.exe"}


def suspicious_processes():
    res = []
    windir = os.environ.get("WINDIR", r"C:\Windows").lower()
    for p in psutil.process_iter(["pid", "name", "exe"]):
        name, exe = (p.info["name"] or "").lower(), (p.info["exe"] or "").lower()
        if not exe:
            continue
        reason = None
        if any(d in exe for d in SUSPICIOUS_DIRS):
            reason = "запущен из временной папки/загрузок"
        elif name in SYSTEM_NAMES and not exe.startswith(windir):
            reason = "системное имя вне папки Windows"
        if reason:
            res.append({"pid": p.info["pid"], "name": p.info["name"], "exe": p.info["exe"], "reason": reason})
    return res


def startup_items():
    items = []
    if not IS_WIN:
        return items
    import winreg
    for root, rn in ((winreg.HKEY_CURRENT_USER, "HKCU"), (winreg.HKEY_LOCAL_MACHINE, "HKLM")):
        for sub in (r"Software\Microsoft\Windows\CurrentVersion\Run", r"Software\Microsoft\Windows\CurrentVersion\RunOnce"):
            try:
                with winreg.OpenKey(root, sub) as k:
                    for i in range(winreg.QueryInfoKey(k)[1]):
                        n, v, _ = winreg.EnumValue(k, i)
                        items.append({"name": n, "command": v, "location": f"{rn}\\{sub}"})
            except OSError:
                pass
    for folder in (Path(os.environ.get("APPDATA", "")) / r"Microsoft\Windows\Start Menu\Programs\Startup",
                   Path(os.environ.get("PROGRAMDATA", "")) / r"Microsoft\Windows\Start Menu\Programs\StartUp"):
        if folder.exists():
            for f in folder.iterdir():
                items.append({"name": f.stem, "command": str(f), "location": "Папка автозагрузки"})
    return items


def report():
    st = defender_status()
    lines = []
    if "error" in st:
        lines.append("Defender: " + st["error"])
    else:
        lines.append(f"Антивирус: {'включён' if st.get('AntivirusEnabled') else 'ВЫКЛЮЧЕН'}; "
                     f"защита в реальном времени: {'вкл' if st.get('RealTimeProtectionEnabled') else 'ВЫКЛ'}")
    t = threats()
    lines.append(f"Обнаруженных угроз в журнале: {len(t)}")
    s = suspicious_processes()
    lines.append(f"Подозрительных процессов: {len(s)}" + ("".join(f"\n  • {x['name']} — {x['reason']}" for x in s[:5])))
    lines.append(f"Программ в автозагрузке: {len(startup_items())}")
    return "\n".join(lines)
