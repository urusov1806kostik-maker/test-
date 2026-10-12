"""System Monitor: CPU, RAM, GPU (NVIDIA через nvidia-smi), температура (LibreHardwareMonitor/WMI если есть)."""
import shutil
import subprocess
import sys

import psutil

NO_WINDOW = 0x08000000 if sys.platform == "win32" else 0


def gpu_info():
    exe = shutil.which("nvidia-smi")
    if not exe:
        return None
    try:
        out = subprocess.run([exe, "--query-gpu=name,utilization.gpu,temperature.gpu,memory.used,memory.total",
                              "--format=csv,noheader,nounits"], capture_output=True, text=True, timeout=3,
                             creationflags=NO_WINDOW).stdout.strip().splitlines()[0]
        name, util, temp, mu, mt = [x.strip() for x in out.split(",")]
        return {"name": name, "load": float(util), "temp": float(temp), "mem_used": float(mu), "mem_total": float(mt)}
    except Exception:
        return None


def cpu_temp():
    try:
        temps = psutil.sensors_temperatures()  # Linux
        for v in temps.values():
            if v:
                return v[0].current
    except Exception:
        pass
    if sys.platform == "win32":
        try:  # требуется запущенный LibreHardwareMonitor / OpenHardwareMonitor
            import wmi
            from .pc import com_init
            com_init()
            for ns in ("root\\LibreHardwareMonitor", "root\\OpenHardwareMonitor"):
                try:
                    for s in wmi.WMI(namespace=ns).Sensor():
                        if s.SensorType == "Temperature" and "CPU" in s.Name:
                            return float(s.Value)
                except Exception:
                    continue
        except Exception:
            pass
    return None


def snapshot():
    vm = psutil.virtual_memory()
    du = psutil.disk_usage("C:\\" if sys.platform == "win32" else "/")
    return {"cpu": psutil.cpu_percent(interval=None), "ram": vm.percent, "ram_used": vm.used / 2**30,
            "ram_total": vm.total / 2**30, "disk": du.percent, "gpu": gpu_info(), "cpu_temp": cpu_temp()}


def summary():
    s = snapshot()
    parts = [f"Процессор {s['cpu']:.0f}%", f"память {s['ram']:.0f}% ({s['ram_used']:.1f} из {s['ram_total']:.1f} ГБ)",
             f"диск {s['disk']:.0f}%"]
    if s["cpu_temp"]:
        parts.append(f"температура CPU {s['cpu_temp']:.0f}°")
    if s["gpu"]:
        g = s["gpu"]
        parts.append(f"видеокарта {g['load']:.0f}%, {g['temp']:.0f}°")
    return ", ".join(parts)


def top_processes(n=5):
    procs = []
    for p in psutil.process_iter(["name", "cpu_percent", "memory_info"]):
        try:
            procs.append((p.info["name"], p.info["cpu_percent"] or 0, (p.info["memory_info"].rss if p.info["memory_info"] else 0) / 2**20))
        except Exception:
            pass
    return sorted(procs, key=lambda x: x[2], reverse=True)[:n]
