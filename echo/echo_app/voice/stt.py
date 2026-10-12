"""Распознавание речи: Vosk (локально, офлайн) и Google Web Speech (онлайн, точнее)."""
import io
import json
import logging
import os
import wave
from pathlib import Path

import numpy as np

from ..config import settings, data_dir

log = logging.getLogger("echo.stt")
SR = 16000
VOSK_URL = "https://alphacephei.com/vosk/models/vosk-model-small-ru-0.22.zip"


def default_vosk_dir() -> Path:
    return data_dir() / "vosk-model-small-ru-0.22"


class STT:
    def __init__(self):
        self._vosk_model = None

    def vosk_available(self):
        p = settings.get("vosk_model_path") or str(default_vosk_dir())
        return os.path.isdir(p)

    def _vosk(self):
        if self._vosk_model is None:
            from vosk import Model, SetLogLevel
            SetLogLevel(-1)
            self._vosk_model = Model(settings.get("vosk_model_path") or str(default_vosk_dir()))
        return self._vosk_model

    def recognize(self, pcm16: np.ndarray) -> str:
        engine = settings.get("stt_engine")
        order = {"vosk": ["vosk"], "google": ["google", "vosk"], "auto": ["google", "vosk"]}.get(engine, ["google", "vosk"])
        for e in order:
            try:
                if e == "vosk" and self.vosk_available():
                    return self._rec_vosk(pcm16)
                if e == "google":
                    return self._rec_google(pcm16)
            except Exception as ex:
                log.debug("stt %s failed: %s", e, ex)
        return ""

    def _rec_vosk(self, pcm16):
        from vosk import KaldiRecognizer
        r = KaldiRecognizer(self._vosk(), SR)
        r.AcceptWaveform(pcm16.tobytes())
        return json.loads(r.FinalResult()).get("text", "")

    def _rec_google(self, pcm16):
        import speech_recognition as sr
        audio = sr.AudioData(pcm16.tobytes(), SR, 2)
        try:
            return sr.Recognizer().recognize_google(audio, language="ru-RU")
        except sr.UnknownValueError:
            return ""


def download_vosk(progress=None):
    """Скачать маленькую русскую модель Vosk (~45 МБ) для офлайн-распознавания."""
    import urllib.request
    import zipfile
    dest = data_dir()
    zpath = dest / "vosk.zip"

    def hook(n, bs, total):
        if progress and total > 0:
            progress(min(100, int(n * bs * 100 / total)))
    urllib.request.urlretrieve(VOSK_URL, zpath, hook)
    with zipfile.ZipFile(zpath) as z:
        z.extractall(dest)
    zpath.unlink()
    settings.set("vosk_model_path", str(default_vosk_dir()))
    return str(default_vosk_dir())
