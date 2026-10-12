"""Синтез речи.
Основной движок: Microsoft Edge neural TTS (edge-tts) — естественный мужской голос ru-RU-DmitryNeural.
Запасной (без интернета): Windows SAPI через pyttsx3.
Воспроизведение через sounddevice — можно мгновенно остановить (перебивание)."""
import asyncio
import logging
import queue
import re
import threading
import time

import numpy as np

from ..config import settings

log = logging.getLogger("echo.tts")

VOICES = {
    "ru-RU-DmitryNeural": "Дмитрий (мужской, нейронный)",
    "ru-RU-SvetlanaNeural": "Светлана (женский, нейронный)",
    "ru-RU-DariyaNeural": "Дария (женский, нейронный)",
    "sapi": "Системный голос Windows (офлайн)",
}
LANG_VOICES = {"en": "en-US-GuyNeural", "de": "de-DE-ConradNeural", "fr": "fr-FR-HenriNeural", "es": "es-ES-AlvaroNeural",
               "it": "it-IT-DiegoNeural", "uk": "uk-UA-OstapNeural", "ja": "ja-JP-KeitaNeural", "zh": "zh-CN-YunxiNeural",
               "pl": "pl-PL-MarekNeural", "tr": "tr-TR-AhmetNeural", "ko": "ko-KR-InJoonNeural", "pt": "pt-BR-AntonioNeural"}


class TTS:
    def __init__(self, on_level=None, on_state=None):
        self.q: queue.Queue = queue.Queue()
        self._stop = threading.Event()
        self._playing = threading.Event()
        self._pending = 0
        self._lock = threading.Lock()
        self.on_level = on_level      # уровень громкости для анимации волны
        self.on_state = on_state      # True/False — говорит ли
        self.current_text = ""        # для подавления эха в распознавании
        self.last_spoken_end = 0.0
        self._gen = 0
        self._loop = asyncio.new_event_loop()
        threading.Thread(target=self._worker, daemon=True).start()

    # API
    def say(self, text, lang_hint=None):
        with self._lock:
            self._pending += 1
        self.q.put((text, lang_hint, self._stop_gen()))

    def _stop_gen(self):
        return self._gen

    def stop(self):
        self._gen = self._stop_gen() + 1
        self._stop.set()
        try:
            import sounddevice as sd
            sd.stop()
        except Exception:
            pass
        while not self.q.empty():
            try:
                self.q.get_nowait()
                with self._lock:
                    self._pending -= 1
            except queue.Empty:
                break

    def busy(self):
        return self._pending > 0 or self._playing.is_set()

    def is_speaking(self):
        return self._playing.is_set()

    def wait_idle(self, cancel: threading.Event = None, timeout=120):
        t0 = time.time()
        while self.busy() and time.time() - t0 < timeout:
            if cancel is not None and cancel.is_set():
                return
            time.sleep(0.05)

    # внутреннее
    def _worker(self):
        asyncio.set_event_loop(self._loop)
        while True:
            text, lang, gen = self.q.get()
            try:
                if gen != self._stop_gen():
                    continue
                self._stop.clear()
                pcm, sr = self._synth(text, lang)
                if pcm is not None and gen == self._stop_gen():
                    self._play(pcm, sr, text)
            except Exception:
                log.exception("tts failed")
            finally:
                with self._lock:
                    self._pending = max(0, self._pending - 1)

    def _rate(self):
        r = int(settings.get("voice_rate"))
        return f"{'+' if r >= 0 else ''}{r}%"

    def _synth(self, text, lang):
        voice = settings.get("voice")
        if lang and lang in LANG_VOICES:
            voice = LANG_VOICES[lang]
        if voice != "sapi":
            try:
                return self._edge(text, voice)
            except Exception as e:
                log.warning("edge-tts недоступен (%s), использую SAPI", e)
        return self._sapi(text)

    def _edge(self, text, voice):
        import edge_tts
        import miniaudio

        async def run():
            c = edge_tts.Communicate(text, voice, rate=self._rate())
            data = bytearray()
            async for ch in c.stream():
                if ch["type"] == "audio":
                    data.extend(ch["data"])
            return bytes(data)
        mp3 = self._loop.run_until_complete(asyncio.wait_for(run(), 15))
        dec = miniaudio.decode(mp3, output_format=miniaudio.SampleFormat.FLOAT32, nchannels=1, sample_rate=24000)
        return np.frombuffer(dec.samples, dtype=np.float32), 24000

    def _sapi(self, text):
        import tempfile, os, wave
        import pyttsx3
        from ..pc import com_init
        com_init()
        eng = pyttsx3.init()
        for v in eng.getProperty("voices"):   # ищем русский мужской голос
            n = (v.name or "").lower()
            if ("ru" in str(v.languages).lower() or "russian" in n or "pavel" in n) and "irina" not in n:
                eng.setProperty("voice", v.id)
                break
        eng.setProperty("rate", 180 + int(settings.get("voice_rate")) * 2)
        path = os.path.join(tempfile.gettempdir(), "echo_tts.wav")
        eng.save_to_file(text, path)
        eng.runAndWait()
        with wave.open(path) as w:
            sr, ch, sw = w.getframerate(), w.getnchannels(), w.getsampwidth()
            raw = w.readframes(w.getnframes())
        a = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768
        if ch > 1:
            a = a.reshape(-1, ch).mean(axis=1)
        return a, sr

    def _play(self, pcm, sr, text):
        import sounddevice as sd
        vol = 1.0 + int(settings.get("voice_volume")) / 100
        pcm = np.clip(pcm * vol, -1, 1)
        self.current_text = text
        self._playing.set()
        if self.on_state:
            self.on_state(True)
        try:
            block = int(sr * 0.05)
            with sd.OutputStream(samplerate=sr, channels=1, dtype="float32") as out:
                for i in range(0, len(pcm), block):
                    if self._stop.is_set():
                        break
                    chunk = pcm[i:i + block]
                    out.write(chunk.reshape(-1, 1))
                    if self.on_level:
                        self.on_level(float(np.sqrt(np.mean(chunk ** 2))) * 4)
        finally:
            self._playing.clear()
            self.last_spoken_end = time.time()
            if self.on_level:
                self.on_level(0.0)
            if self.on_state:
                self.on_state(False)


async def list_edge_voices(prefix="ru-"):
    import edge_tts
    return [v["ShortName"] for v in await edge_tts.list_voices() if v["Locale"].lower().startswith(prefix)]
