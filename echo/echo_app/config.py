"""Настройки (JSON) и безопасное хранение секретов (Windows Credential Manager через keyring)."""
import json
import os
import sys
import threading
from pathlib import Path

try:
    import keyring
except ImportError:  # pragma: no cover
    keyring = None

SERVICE = "ECHO-Assistant"


def data_dir() -> Path:
    base = os.environ.get("APPDATA") or str(Path.home() / ".config")
    p = Path(base) / "ECHO"
    p.mkdir(parents=True, exist_ok=True)
    return p


DEFAULTS = {
    "model": "claude-opus-5-5",
    "fast_model": "claude-haiku-5-5",
    "personality": "friendly",
    "custom_personality": "",
    "user_name": "",
    "voice": "ru-RU-DmitryNeural",
    "voice_rate": 0,          # проценты, -50..+50
    "voice_volume": 0,
    "tts_enabled": True,
    "speak_text_replies": False,  # озвучивать ответы на сообщения из чата
    "wake_word": "эхо",
    "stt_engine": "auto",     # auto | vosk | google
    "vosk_model_path": "",
    "mic_index": -1,
    "silence_timeout": 0.9,   # сек тишины = конец фразы
    "conversation_timeout": 25,
    "autostart": False,
    "start_minimized": False,
    "show_widget": True,
    "confirm_dangerous": True,
    "allow_ui_control": False,
    "telegram_api_id": "",
    "telegram_enabled": False,
    "discord_enabled": False,
    "read_notifications": True,
    "gaming_mode": False,
    "translate_target": "en",
    "memory_enabled": True,
    "history_context": 30,
}

PERSONALITIES = {
    "friendly": "Ты дружелюбный, тёплый и немного ироничный собеседник. Любишь пошутить к месту.",
    "professional": "Ты сдержанный, точный и деловой помощник. Отвечаешь чётко и по делу.",
    "funny": "Ты весёлый, остроумный и любишь шутки, но всё равно полезен.",
    "jarvis": "Ты вежливый британский дворецкий-ИИ в стиле JARVIS: изысканно, спокойно, с лёгким сарказмом. Обращаешься «сэр».",
    "gamer": "Ты геймер-напарник: говоришь неформально, разбираешься в играх, сленг в меру.",
}


class Settings:
    def __init__(self):
        self.path = data_dir() / "settings.json"
        self._lock = threading.Lock()
        self.data = dict(DEFAULTS)
        if self.path.exists():
            try:
                self.data.update(json.loads(self.path.read_text("utf-8")))
            except Exception:
                pass

    def get(self, key, default=None):
        return self.data.get(key, DEFAULTS.get(key, default))

    def set(self, key, value):
        with self._lock:
            self.data[key] = value
            self.save()

    def save(self):
        tmp = self.path.with_suffix(".tmp")
        tmp.write_text(json.dumps(self.data, ensure_ascii=False, indent=2), "utf-8")
        tmp.replace(self.path)

    # ---- секреты ----
    @staticmethod
    def get_secret(name: str) -> str:
        if name == "anthropic_api_key" and os.environ.get("ANTHROPIC_API_KEY"):
            return os.environ["ANTHROPIC_API_KEY"]
        if keyring:
            try:
                return keyring.get_password(SERVICE, name) or ""
            except Exception:
                pass
        return ""

    @staticmethod
    def set_secret(name: str, value: str):
        if not keyring:
            raise RuntimeError("keyring недоступен")
        if value:
            keyring.set_password(SERVICE, name, value)
        else:
            try:
                keyring.delete_password(SERVICE, name)
            except Exception:
                pass


settings = Settings()


def resource_path(rel: str) -> Path:
    base = Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent.parent))
    return base / rel
