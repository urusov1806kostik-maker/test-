#!/usr/bin/env python3
"""Генерирует свои звуковые эффекты VOID TD (синтез, без чужих сэмплов).

Запуск: python3 tools/make_sounds.py
Результат: assets/sounds/*.wav и *.ogg (ogg — если есть ffmpeg).
Загрузи файлы в Roblox (Creator Hub -> Development Items -> Audio) и вставь ID в Config.Sounds[...].Custom.
"""
import shutil
import subprocess
import wave
from pathlib import Path

import numpy as np

SR = 44100
OUT = Path(__file__).resolve().parent.parent / "assets" / "sounds"
rng = np.random.default_rng(7)


def t_axis(dur):
    return np.linspace(0, dur, int(SR * dur), endpoint=False)


def env(n, attack=0.005, release=0.2, curve=3.0):
    """Огибающая: быстрая атака, экспоненциальный спад."""
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    dur = n / SR
    r = np.clip(1 - (t - attack) / max(dur - attack, 1e-4), 0, 1) ** curve
    return a * r


def noise(n):
    return rng.uniform(-1, 1, n)


def lowpass(x, cutoff):
    # однополюсный фильтр, применённый дважды
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    for _ in range(2):
        prev = 0.0
        out = np.empty_like(x)
        for i, v in enumerate(x):
            prev = (1 - a) * v + a * prev
            out[i] = prev
        x = out
    return x


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def sweep(f0, f1, dur, shape="sin"):
    t = t_axis(dur)
    f = f0 * (f1 / f0) ** (t / dur)
    phase = 2 * np.pi * np.cumsum(f) / SR
    if shape == "saw":
        return 2 * ((phase / (2 * np.pi)) % 1) - 1
    if shape == "square":
        return np.sign(np.sin(phase))
    return np.sin(phase)


def tone(freq, dur, harmonics=(1.0,)):
    t = t_axis(dur)
    out = np.zeros_like(t)
    for i, amp in enumerate(harmonics):
        out += amp * np.sin(2 * np.pi * freq * (i + 1) * t)
    return out


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def delay(x, sec, amount=0.3, repeats=3):
    d = int(sec * SR)
    out = np.concatenate([x, np.zeros(d * repeats)])
    for k in range(1, repeats + 1):
        out[d * k : d * k + len(x)] += x * (amount ** k)
    return out


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) or 1
    return x / m * peak


def save(name, x):
    x = norm(x)
    data = (x * 32767).astype(np.int16)
    path = OUT / f"{name}.wav"
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    if shutil.which("ffmpeg"):
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(path), "-c:a", "libvorbis", "-q:a", "5", str(path.with_suffix(".ogg"))], check=True)
    print("  ", name)


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    # взмах меча: высокочастотный шум с быстрым свипом
    n = int(SR * 0.28)
    s = highpass(noise(n), 1800) * env(n, 0.01, 0.25, 2.5) * (0.4 + 0.6 * np.sin(np.linspace(0, np.pi, n)))
    save("Slash", mix(s, sweep(900, 300, 0.28) * env(n, 0.005, 0.2, 4) * 0.2))
    # тяжёлый удар: низкий бум + треск
    n = int(SR * 0.55)
    save("HeavyHit", mix(sweep(140, 40, 0.55) * env(n, 0.002, 0.5, 3), lowpass(noise(n), 1200) * env(n, 0.001, 0.2, 6) * 0.8))
    # выстрел: щелчок + короткий шум
    n = int(SR * 0.18)
    save("Shoot", mix(sweep(1600, 200, 0.18, "square") * env(n, 0.001, 0.15, 6) * 0.4, highpass(noise(n), 2500) * env(n, 0.001, 0.1, 8)))
    # лазер: нисходящий пилообразный свип
    n = int(SR * 0.6)
    save("Laser", delay(lowpass(sweep(2200, 300, 0.6, "saw"), 5000) * env(n, 0.005, 0.55, 2), 0.06, 0.35, 2))
    # магия: мерцающий аккорд
    n = int(SR * 0.7)
    chord = mix(tone(660, 0.7, (1, 0.3)), tone(990, 0.7, (1, 0.2)), tone(1320, 0.7)) * env(n, 0.02, 0.65, 2)
    save("Magic", delay(chord * (0.6 + 0.4 * np.sin(2 * np.pi * 14 * t_axis(0.7))), 0.09, 0.4, 3))
    # взрыв
    n = int(SR * 1.1)
    save("Explosion", mix(lowpass(noise(n), 600) * env(n, 0.002, 1.0, 2.5), sweep(90, 30, 1.1) * env(n, 0.002, 0.9, 2) * 0.8))
    # установка юнита: металлический звон + удар о землю
    n = int(SR * 0.5)
    save("Place", mix(tone(880, 0.5, (1, 0.5, 0.3)) * env(n, 0.002, 0.45, 5) * 0.5, lowpass(noise(n), 400) * env(n, 0.001, 0.15, 5)))
    # улучшение: восходящее арпеджио
    notes = [523, 659, 784, 1047]
    up = np.concatenate([tone(f, 0.11, (1, 0.4)) * env(int(SR * 0.11), 0.003, 0.1, 2) for f in notes])
    save("Upgrade", delay(up, 0.08, 0.3, 2))
    # продажа: нисходящие монетки
    down = np.concatenate([tone(f, 0.09, (1, 0.6)) * env(int(SR * 0.09), 0.002, 0.08, 3) for f in (1568, 1319, 1047)])
    save("Sell", down)
    # клик интерфейса
    n = int(SR * 0.06)
    save("Click", tone(1800, 0.06) * env(n, 0.001, 0.05, 6))
    # начало волны: рог
    n = int(SR * 1.0)
    horn = lowpass(sweep(110, 140, 1.0, "saw"), 1500) * env(n, 0.08, 0.9, 1.5)
    save("WaveStart", mix(horn, lowpass(sweep(165, 210, 1.0, "saw"), 1500) * env(n, 0.1, 0.9, 1.5) * 0.6))
    # босс: низкий рык с вибрато
    n = int(SR * 1.6)
    t = t_axis(1.6)
    roar = lowpass(np.sign(np.sin(2 * np.pi * (55 + 6 * np.sin(2 * np.pi * 7 * t)) * t)), 700) * env(n, 0.05, 1.5, 1.5)
    save("Boss", mix(roar, lowpass(noise(n), 300) * env(n, 0.05, 1.5, 2) * 0.6))
    # удар по ядру
    n = int(SR * 0.7)
    save("CoreHit", mix(tone(220, 0.7, (1, 0.5, 0.25)) * env(n, 0.002, 0.65, 3), sweep(400, 80, 0.7) * env(n, 0.001, 0.3, 4) * 0.5))
    # победа: мажорный аккорд с трелью
    fan = np.concatenate([tone(f, 0.16, (1, 0.3)) * env(int(SR * 0.16), 0.005, 0.15, 1.5) for f in (523, 659, 784)])
    fin = mix(tone(523, 1.2), tone(659, 1.2), tone(784, 1.2), tone(1047, 1.2)) * env(int(SR * 1.2), 0.02, 1.15, 1.5)
    save("Victory", np.concatenate([fan, fin]))
    # поражение: минорное нисхождение
    lose = np.concatenate([tone(f, 0.35, (1, 0.4)) * env(int(SR * 0.35), 0.01, 0.33, 1.5) for f in (392, 349, 311, 262)])
    save("Defeat", delay(lowpass(lose, 2500), 0.12, 0.3, 2))
    # тряска кейса: короткий металлический стук
    n = int(SR * 0.12)
    save("CaseShake", mix(tone(320, 0.12, (1, 0.6, 0.4)) * env(n, 0.001, 0.1, 5), highpass(noise(n), 3000) * env(n, 0.001, 0.05, 8) * 0.4))
    # открытие кейса: взрыв + блеск
    n = int(SR * 1.2)
    sparkle = sum(tone(f, 1.2) * env(n, 0.05, 1.1, 3) * 0.15 for f in (1760, 2093, 2637, 3136))
    save("CaseOpen", mix(lowpass(noise(n), 900) * env(n, 0.001, 0.8, 3), sweep(200, 1200, 1.2) * env(n, 0.01, 1.1, 2) * 0.4, sparkle))
    # появление карточки
    n = int(SR * 0.3)
    save("Reveal", delay(tone(1319, 0.3, (1, 0.5)) * env(n, 0.002, 0.28, 3), 0.07, 0.35, 2))
    # SECRET: тёмный удар + искажённый гул
    n = int(SR * 2.0)
    t = t_axis(2.0)
    drone = np.tanh(3 * (np.sin(2 * np.pi * 41 * t) + 0.6 * np.sin(2 * np.pi * 62 * t))) * env(n, 0.01, 1.9, 1.2)
    save("Secret", mix(drone, lowpass(noise(n), 400) * env(n, 0.001, 0.6, 3), sweep(1200, 60, 2.0) * env(n, 0.01, 1.9, 2) * 0.3))
    # покупка: монетки
    coins = np.concatenate([tone(f, 0.08, (1, 0.5)) * env(int(SR * 0.08), 0.001, 0.07, 3) for f in (1319, 1568, 2093, 2637)])
    save("Purchase", delay(coins, 0.05, 0.3, 2))
    # портал: вихрь
    n = int(SR * 1.0)
    t = t_axis(1.0)
    save("Portal", lowpass(noise(n), 800) * (0.5 + 0.5 * np.sin(2 * np.pi * (3 + 9 * t) * t)) * env(n, 0.15, 0.85, 1.5) + sweep(80, 300, 1.0) * env(n, 0.1, 0.9, 2) * 0.4)
    # смерть врага: короткий «пуф»
    n = int(SR * 0.25)
    save("EnemyDeath", mix(lowpass(noise(n), 1500) * env(n, 0.001, 0.22, 3), sweep(500, 120, 0.25) * env(n, 0.001, 0.2, 3) * 0.4))


if __name__ == "__main__":
    print("Генерация звуков в", OUT)
    build()
    print("Готово")
