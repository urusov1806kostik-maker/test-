"""Синтез речи.
Основной движок: Piper — нейронный синтез прямо на компьютере, без интернета (мужской голос ru_RU-dmitri).
Дополнительно: Microsoft Edge neural TTS (онлайн, может быть недоступен) и Windows SAPI.
Воспроизведение через sounddevice — можно мгновенно остановить (перебивание)."""
import asyncio
import logging
import queue
import re
import threading
import time

import numpy as np

from ..config import settings, data_dir, resource_path

log = logging.getLogger("echo.tts")

DEFAULT_VOICE = "piper:ru_RU-dmitri-medium"
VOICES = {
    "piper:ru_RU-dmitri-medium": "Дмитрий (мужской, офлайн) — по умолчанию",
    "piper:ru_RU-ruslan-medium": "Руслан (мужской, офлайн, скачается)",
    "piper:ru_RU-denis-medium": "Денис (мужской, офлайн, скачается)",
    "piper:ru_RU-irina-medium": "Ирина (женский, офлайн, скачается)",
    "ru-RU-DmitryNeural": "Microsoft Дмитрий (онлайн)",
    "sapi": "Системный голос Windows",
}
# голоса для переводчика (Piper, скачиваются при первом использовании); запасной — Edge
LANG_VOICES = {"en": "en_US-ryan-medium", "de": "de_DE-thorsten-medium", "fr": "fr_FR-tom-medium", "es": "es_ES-davefx-medium",
               "it": "it_IT-riccardo-x_low", "uk": "uk_UA-ukrainian_tts-medium", "pl": "pl_PL-darkman-medium",
               "tr": "tr_TR-dfki-medium", "zh": "zh_CN-huayan-medium", "pt": "pt_BR-faber-medium"}
EDGE_LANG = {"en": "en-US-GuyNeural", "de": "de-DE-ConradNeural", "fr": "fr-FR-HenriNeural", "es": "es-ES-AlvaroNeural",
             "it": "it-IT-DiegoNeural", "uk": "uk-UA-OstapNeural", "ja": "ja-JP-KeitaNeural", "zh": "zh-CN-YunxiNeural",
             "pl": "pl-PL-MarekNeural", "tr": "tr-TR-AhmetNeural", "ko": "ko-KR-InJoonNeural", "pt": "pt-BR-AntonioNeural"}
HF = "https://huggingface.co/rhasspy/piper-voices/resolve/main"


def piper_model_path(name: str):
    """Путь к модели голоса: встроенная в программу или скачанная в %APPDATA%/ECHO/voices."""
    for base in (resource_path("voices"), data_dir() / "voices"):
        p = base / f"{name}.onnx"
        if p.exists() and (base / f"{name}.onnx.json").exists():
            return p
    return None


def download_piper_voice(name: str, progress=None):
    import urllib.request
    lang = name.split("-")[0]                     # ru_RU
    speaker, quality = name.split("-")[1], name.split("-")[2]
    folder = data_dir() / "voices"
    folder.mkdir(parents=True, exist_ok=True)
    for ext in (".onnx.json", ".onnx"):
        url = f"{HF}/{lang.split('_')[0]}/{lang}/{speaker}/{quality}/{name}{ext}"
        tmp = folder / f"{name}{ext}.part"

        def hook(n, bs, total):
            if progress and total > 0 and ext == ".onnx":
                progress(min(100, int(n * bs * 100 / total)))
        urllib.request.urlretrieve(url, tmp, hook)
        tmp.replace(folder / f"{name}{ext}")
    return folder / f"{name}.onnx"


class TTS:
    def __init__(self, on_level=None, on_state=None, on_error=None):
        self.q: queue.Queue = queue.Queue()
        self._stop = threading.Event()
        self._playing = threading.Event()
        self._pending = 0
        self._lock = threading.Lock()
        self.on_level = on_level      # уровень громкости для анимации волны
        self.on_state = on_state      # True/False — говорит ли
        self.on_error = on_error      # текст ошибки озвучки для интерфейса
        self._error_shown = set()
        self.current_text = ""        # для подавления эха в распознавании
        self.last_spoken_end = 0.0
        self._gen = 0
        self._piper = {}              # загруженные модели Piper
        self._downloading = set()
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
            chain = ["piper:" + LANG_VOICES[lang], EDGE_LANG.get(lang)]
        elif voice == "sapi":
            chain = ["sapi"]
        elif voice.startswith("piper:"):
            chain = [voice, DEFAULT_VOICE, "ru-RU-DmitryNeural", "sapi"]
        else:
            chain = [voice, DEFAULT_VOICE, "sapi"]
        seen = set()
        for v in chain:
            if not v or v in seen:
                continue
            seen.add(v)
            try:
                if v.startswith("piper:"):
                    res = self._piper_synth(text, v[6:])
                    if res is None:
                        continue
                    return res
                if v == "sapi":
                    return self._sapi(text)
                return self._edge(text, v)
            except Exception as e:
                log.warning("голос %s не сработал: %s", v, e)
        self._report("Не удалось озвучить ответ ни одним голосом. Подробности в %APPDATA%\\ECHO\\echo.log")
        return None, None

    def _piper_synth(self, text, name):
        path = piper_model_path(name)
        if path is None:
            if name not in self._downloading:     # качаем в фоне, пока говорим запасным голосом
                self._downloading.add(name)
                threading.Thread(target=self._bg_download, args=(name,), daemon=True).start()
            return None
        from piper import PiperVoice, SynthesisConfig
        if name not in self._piper:
            self._piper[name] = PiperVoice.load(str(path))
        rate = int(settings.get("voice_rate"))
        cfg = SynthesisConfig(length_scale=1.0 / max(0.3, 1 + rate / 100))
        chunks = list(self._piper[name].synthesize(text, cfg))
        if not chunks:
            return None
        return np.concatenate([c.audio_float_array for c in chunks]).astype(np.float32), chunks[0].sample_rate

    def _bg_download(self, name):
        try:
            download_piper_voice(name)
            log.info("голос %s скачан", name)
        except Exception as e:
            log.warning("не удалось скачать голос %s: %s", name, e)
            self._report(f"Не удалось скачать голос {name}: {e}")
        finally:
            self._downloading.discard(name)

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
        voices = eng.getProperty("voices")
        ru = [v for v in voices if "ru" in str(v.languages).lower() or "russian" in (v.name or "").lower()
              or "pavel" in (v.name or "").lower() or "irina" in (v.name or "").lower()]
        male = [v for v in ru if "irina" not in (v.name or "").lower()]
        if ru:
            eng.setProperty("voice", (male or ru)[0].id)
        else:
            self._report("В Windows нет русского голоса для офлайн-озвучки: Параметры → Время и язык → Речь → Добавить голоса → Русский.")
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

    def _report(self, msg):
        if self.on_error and msg not in self._error_shown:   # каждую ошибку показываем один раз
            self._error_shown.add(msg)
            self.on_error(msg)

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
        except Exception as e:
            log.exception("playback failed")
            self._report(f"Нет звука: не удалось открыть динамики ({e})")
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
