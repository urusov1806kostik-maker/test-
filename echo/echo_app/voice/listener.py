"""Постоянное прослушивание микрофона:
- VAD (webrtcvad) + определение конца фразы по паузе;
- слово активации «Эхо», окно продолжения диалога без повторения слова;
- режим беседы («Эхо, давай поговорим» / «Эхо, закончи разговор»);
- перебивание: если пользователь заговорил во время ответа — ответ останавливается;
- подавление эха: фразы, совпадающие с тем, что говорит сам E.C.H.O, отбрасываются."""
import collections
import logging
import re
import threading
import time
from difflib import SequenceMatcher

import numpy as np

from ..config import settings
from .stt import STT, SR

log = logging.getLogger("echo.listener")
FRAME_MS = 30
FRAME = SR * FRAME_MS // 1000
WAKE_RE = re.compile(r"^\W*(?:эй\s+|окей\s+|привет\s+)?(эхо|эха|эко|эху|эхой|echo|ехо|эх)\b[\s,.!]*", re.I)
START_CONV = re.compile(r"давай (по)?говорим|режим беседы|поболтаем", re.I)
END_CONV = re.compile(r"(закончи|заверши|останови|хватит|стоп)\w*\s*(разговор|беседу|общение)|пока,? эхо|выключи режим беседы", re.I)
STOP_RE = re.compile(r"^(стоп|хватит|замолчи|тихо|помолчи|стой)\b", re.I)


class Listener:
    def __init__(self, assistant, on_level=None, on_state=None, on_text=None):
        self.a = assistant
        self.stt = STT()
        self.on_level = on_level
        self.on_state = on_state     # "listening" / "idle"
        self.on_text = on_text       # распознанный текст (для отладки в UI)
        self.running = False
        self.muted = False
        self.followup_until = 0.0
        self.error = ""
        self._thread = None
        try:
            import webrtcvad
            self.vad = webrtcvad.Vad(2)
        except Exception:
            self.vad = None

    def start(self):
        if self.running:
            return
        self.running = True
        self._thread = threading.Thread(target=self._loop, daemon=True)
        self._thread.start()

    def stop(self):
        self.running = False

    def activate(self):
        """Ручная активация (кнопка/горячая клавиша) — следующая фраза без слова «Эхо»."""
        self.followup_until = time.time() + settings.get("conversation_timeout")
        if self.on_state:
            self.on_state("listening")

    # ---------- аудио ----------
    def _is_speech(self, frame: np.ndarray, threshold):
        rms = float(np.sqrt(np.mean((frame.astype(np.float32) / 32768) ** 2)))
        if self.on_level:
            self.on_level(min(1.0, rms * 8))
        if rms < threshold:
            return False
        if self.vad:
            try:
                return self.vad.is_speech(frame.tobytes(), SR)
            except Exception:
                pass
        return True

    def _loop(self):
        import sounddevice as sd
        while self.running:
            try:
                dev = settings.get("mic_index")
                with sd.InputStream(samplerate=SR, channels=1, dtype="int16", blocksize=FRAME,
                                    device=None if dev in (-1, None) else dev) as stream:
                    self.error = ""
                    self._capture(stream)
            except Exception as e:
                self.error = f"Микрофон недоступен: {e}"
                log.warning(self.error)
                time.sleep(3)

    def _capture(self, stream):
        pre = collections.deque(maxlen=10)       # 300 мс до начала речи
        voiced, silence, speech_frames = [], 0, 0
        in_speech = False
        noise = 0.004
        while self.running:
            frame, _ = stream.read(FRAME)
            frame = frame[:, 0].copy()
            if self.muted:
                continue
            speaking = self.a.tts is not None and self.a.tts.is_speaking()
            rms = float(np.sqrt(np.mean((frame.astype(np.float32) / 32768) ** 2)))
            if not in_speech:
                noise = 0.97 * noise + 0.03 * min(rms, 0.05)
            # во время собственной речи порог выше — подавление эха динамиков
            thr = max(0.008, noise * 2.5) * (3.5 if speaking else 1.0)
            is_sp = self._is_speech(frame, thr)
            if not in_speech:
                pre.append(frame)
                if is_sp:
                    speech_frames += 1
                    if speech_frames >= 4:          # 120 мс речи — начало фразы
                        in_speech = True
                        voiced = list(pre)
                        silence = 0
                else:
                    speech_frames = 0
                continue
            voiced.append(frame)
            silence = 0 if is_sp else silence + 1
            end_frames = int(settings.get("silence_timeout") * 1000 / FRAME_MS)
            if silence >= end_frames or len(voiced) > 15 * 1000 // FRAME_MS:
                audio = np.concatenate(voiced)
                in_speech, voiced, speech_frames = False, [], 0
                if len(audio) > SR * 0.35:
                    threading.Thread(target=self._process, args=(audio, speaking), daemon=True).start()

    # ---------- логика диалога ----------
    def _is_echo(self, text):
        tts = self.a.tts
        if not tts:
            return False
        recent = tts.is_speaking() or time.time() - tts.last_spoken_end < 0.6
        if not recent:
            return False
        ratio = SequenceMatcher(None, text.lower(), tts.current_text.lower()).ratio()
        words = set(text.lower().split())
        overlap = len(words & set(tts.current_text.lower().split())) / max(1, len(words))
        return ratio > 0.45 or overlap > 0.6

    def _process(self, audio, during_speech):
        text = self.stt.recognize(audio).strip()
        if not text:
            return
        log.info("heard: %s", text)
        if self.on_text:
            self.on_text(text)
        if self._is_echo(text):
            return
        m = WAKE_RE.match(text)
        has_wake = bool(m)
        body = text[m.end():].strip() if m else text
        active = self.a.conversation_mode or time.time() < self.followup_until or self.a.pending_confirm

        if not has_wake and not active:
            return
        # перебивание
        if self.a.tts and (self.a.tts.is_speaking() or during_speech):
            self.a.interrupt()
            if STOP_RE.match(body) or not body:
                return
        if END_CONV.search(body) or (self.a.conversation_mode and END_CONV.search(text)):
            self.a.conversation_mode = False
            self.followup_until = 0
            self.a.mode_changed.emit("conversation", False)
            self.a.speak("Хорошо, заканчиваем. Зови, если что.", force=True)
            return
        if START_CONV.search(body) and (has_wake or not self.a.conversation_mode):
            self.a.conversation_mode = True
            self.a.mode_changed.emit("conversation", True)
            if len(body.split()) <= 3:
                self.a.submit("Давай поговорим!", "voice")
                self._touch()
                return
        if not body:
            self.a.speak("Да?", force=True)
            self._touch()
            return
        self.a.submit(body, "voice")
        self._touch()

    def _touch(self):
        self.followup_until = time.time() + settings.get("conversation_timeout")
        if self.on_state:
            self.on_state("listening")
