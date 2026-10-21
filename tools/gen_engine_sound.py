"""Synthesizes the looping pitbike engine sound (single-cylinder two-stroke putter).

Usage: python3 tools/gen_engine_sound.py   (needs numpy and ffmpeg with libvorbis)
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "src", "main", "resources", "assets", "pitbike", "sounds", "engine.ogg")

RATE = 44100
FIRING_HZ = 60  # 1 s loop holds a whole number of firings, so it loops seamlessly
CYCLES = 60


def main():
    rng = np.random.default_rng(7)
    period = RATE // FIRING_HZ
    t = np.arange(period) / RATE
    out = []
    for i in range(CYCLES):
        strength = 0.8 + 0.25 * rng.random()
        # Each firing: a damped low "thump" plus a short burst of exhaust noise.
        thump = np.sin(2 * np.pi * 95 * t) * np.exp(-t * 55)
        bark = np.sin(2 * np.pi * 190 * t + 0.6) * np.exp(-t * 90) * 0.5
        noise = rng.standard_normal(period) * np.exp(-t * 160) * 0.35
        out.append((thump + bark + noise) * strength)
    signal = np.concatenate(out)

    # Light low-pass (moving average, wraps around so the loop stays seamless) and a steady drone.
    kernel = 6
    padded = np.concatenate([signal[-kernel:], signal])
    signal = np.convolve(padded, np.ones(kernel) / kernel, mode="valid")[1:]
    n = np.arange(len(signal)) / RATE
    signal += 0.18 * np.sin(2 * np.pi * FIRING_HZ * n) + 0.08 * np.sin(2 * np.pi * FIRING_HZ * 3 * n)
    signal = np.tanh(signal * 1.6)
    signal = signal / np.max(np.abs(signal)) * 0.85

    pcm = (signal * 32767).astype("<i2")
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "engine.wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", OUT], check=True)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
