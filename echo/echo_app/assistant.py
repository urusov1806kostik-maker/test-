"""Ядро E.C.H.O: диалог с Claude (стриминг + tool use), локальный режим, подтверждения, режимы."""
import json
import logging
import re
import threading
import time

from PySide6.QtCore import QObject, Signal

from . import localcmd
from .config import settings, PERSONALITIES
from .db import DB
from .tools import Toolbox

log = logging.getLogger("echo.assistant")

YES = re.compile(r"^(да|ага|угу|конечно|подтверждаю|давай|выполняй|ок|окей|yes|разрешаю)\b", re.I)
NO = re.compile(r"^(нет|не надо|отмена|отмени|стоп|не)\b", re.I)


class Assistant(QObject):
    user_message = Signal(str, str)        # текст, источник (voice/text)
    reply_started = Signal()
    reply_delta = Signal(str)
    reply_finished = Signal(str)
    state_changed = Signal(str)            # idle / listening / thinking / speaking
    status = Signal(str)
    action_done = Signal(str)
    confirm_request = Signal(str)
    notify = Signal(str, str)              # заголовок, текст
    mode_changed = Signal(str, bool)       # имя режима, вкл

    def __init__(self):
        super().__init__()
        self.db = DB()
        self.tts = None
        self.telegram = None
        self.discord = None
        self.tools = Toolbox(self)
        self._client = None
        self._client_key = None
        self._busy = threading.Lock()
        self._cancel = threading.Event()
        self._confirm_event = threading.Event()
        self._confirm_result = False
        self.pending_confirm = False
        self.conversation_mode = False
        self.translate_mode = False
        self.translate_target = settings.get("translate_target")
        self.last_screen_scale = 1.0
        self._gen = 0

    # ---------- клиент ----------
    def client(self):
        key = settings.get_secret("anthropic_api_key")
        if not key:
            return None
        if self._client is None or key != self._client_key:
            import anthropic
            self._client = anthropic.Anthropic(api_key=key, max_retries=1, timeout=60)
            self._client_key = key
        return self._client

    # ---------- вход ----------
    def submit(self, text: str, source="text", translate=False):
        text = text.strip()
        if not text:
            return
        if self.pending_confirm:
            if YES.match(text):
                return self.answer_confirm(True)
            if NO.match(text):
                return self.answer_confirm(False)
        self.interrupt()
        self._gen += 1
        gen = self._gen
        threading.Thread(target=self._handle, args=(text, source, gen, translate), daemon=True).start()

    def interrupt(self):
        """Перебить текущий ответ (речь + генерацию)."""
        self._cancel.set()
        if self.tts:
            self.tts.stop()
        if self.pending_confirm:
            self.answer_confirm(False)

    def answer_confirm(self, ok: bool):
        self._confirm_result = ok
        self.pending_confirm = False
        self._confirm_event.set()

    def _confirm(self, question: str) -> bool:
        self._confirm_event.clear()
        self.pending_confirm = True
        self.confirm_request.emit(question)
        self.speak(question.split("\n")[0] + ". Да или нет?")
        ok = self._confirm_event.wait(60)
        self.pending_confirm = False
        return ok and self._confirm_result

    # ---------- обработка ----------
    def _handle(self, text, source, gen, translate=False):
        with self._busy:
            if gen != self._gen:
                return
            self._cancel.clear()
            self.user_message.emit(text, source)
            self.db.add_message("user", text, source)
            self.state_changed.emit("thinking")
            try:
                reply = self._translate(text) if translate else self._dispatch(text, source)
            except Exception as e:  # noqa
                log.exception("handle failed")
                reply = f"Произошла ошибка: {e}"
                self.reply_started.emit()
                self.reply_delta.emit(reply)
            if reply:
                self.db.add_message("assistant", reply, source)
            self.reply_finished.emit(reply or "")
            if self.tts and self.tts.busy():
                self.tts.wait_idle(self._cancel)
            self.state_changed.emit("idle")

    def _dispatch(self, text, source):
        low = localcmd.normalize(text)
        for cmd in self.db.custom_commands():
            if low == cmd["phrase"]:
                return self._run_custom(cmd)
        if self.translate_mode and not re.search(r"(выключи|останови|закончи).{0,10}перев", low):
            return self._translate(text)
        client = self.client()
        if client is None:
            return self._local(text, reason="Ключ Claude API не задан (Настройки → ИИ).")
        try:
            return self._claude(client, text, source)
        except Exception as e:
            import anthropic
            if isinstance(e, (anthropic.APIConnectionError, anthropic.APITimeoutError)):
                return self._local(text, reason="Нет связи с Claude — работаю локально.")
            if isinstance(e, anthropic.AuthenticationError):
                return self._local(text, reason="Неверный API-ключ Claude.")
            raise

    def _emit_reply(self, text):
        self.reply_started.emit()
        self.reply_delta.emit(text)
        self.speak(text)
        return text

    def _local(self, text, reason=""):
        self.status.emit(reason)
        parsed = localcmd.parse(text)
        if parsed:
            name, args = parsed
            res = self.tools.run(name, args, self._confirm)
            self.action_done.emit(str(res))
            return self._emit_reply(str(res))
        return self._emit_reply(localcmd.offline_reply(text))

    def _run_custom(self, cmd):
        steps = json.loads(cmd["actions"])
        out = []
        for st in steps:
            if self._cancel.is_set():
                break
            parsed = localcmd.parse(st)
            if parsed:
                out.append(str(self.tools.run(*parsed, self._confirm)))
            elif self.client():
                out.append(self._claude(self.client(), st, "text", silent=True))
        return self._emit_reply("Готово. " + "; ".join(o for o in out if o)[:400])

    # ---------- Claude ----------
    def system_prompt(self, source):
        p = settings.get("personality")
        style = settings.get("custom_personality") if p == "custom" else PERSONALITIES.get(p, PERSONALITIES["friendly"])
        mem = "\n".join(f"- {m['text']}" for m in self.db.memories()) if settings.get("memory_enabled") else ""
        name = settings.get("user_name")
        return f"""Ты — E.C.H.O, персональный ИИ-помощник на компьютере пользователя с Windows. Мужской род. Говоришь по-русском.
{style}
Сейчас {time.strftime('%A, %d.%m.%Y %H:%M')}.{f' Пользователя зовут {name}.' if name else ''}
{('Что ты помнишь о пользователе:' + chr(10) + mem) if mem else ''}

Правила:
- Ты можешь свободно болтать, шутить, обсуждать игры, программирование и что угодно, объяснять сложное.
- У тебя есть инструменты для управления ПК. Вызывай их ТОЛЬКО когда пользователь явно просит выполнить действие сейчас
  («запусти», «открой», «давай КС», «сделай»). Если он просто обсуждает («я вчера запускал КС», «может потом поиграем»,
  «что лучше, CS или Valorant?») — НЕ выполняй действий, просто поговори или уточни.
- Если запрос неоднозначный — коротко переспроси, вместо того чтобы действовать.
- После действия коротко подтверди («Запускаю Counter-Strike 2»).
- Когда пользователь сообщает о себе важное или предпочтение — сохрани через remember.
- Сообщения в Telegram/Discord отправляй только по явной просьбе; текст покажи в подтверждении.
- Вопросы о том, что на экране, ошибки, кнопки — используй look_at_screen.
- Если пользователь прощается или просит закончить разговор — вызови end_conversation.
{'- Ответ будет озвучен голосом: говори естественно и кратко (1-3 предложения, если не просят подробнее), без markdown, списков, эмодзи и ссылок.' if source == 'voice' else '- Ответ в текстовом чате: можно использовать markdown и код, но без воды.'}
- Если прошлые сообщения содержат начатую тему, ты можешь продолжить её."""

    def _history(self):
        msgs = []
        for m in self.db.recent_messages(settings.get("history_context")):
            if msgs and msgs[-1]["role"] == m["role"]:
                msgs[-1]["content"] += "\n" + m["content"]
            else:
                msgs.append({"role": m["role"], "content": m["content"]})
        while msgs and msgs[0]["role"] != "user":
            msgs.pop(0)
        return msgs

    def _claude(self, client, text, source, silent=False):
        messages = self._history() if not silent else [{"role": "user", "content": text}]
        if not messages or messages[-1]["role"] != "user":
            messages.append({"role": "user", "content": text})
        tools = self.tools.schemas() + [{"type": "web_search_20250305", "name": "web_search", "max_uses": 3}]
        system = [{"type": "text", "text": self.system_prompt(source), "cache_control": {"type": "ephemeral"}}]
        full = []
        started = False
        sentence_buf = ""
        for _ in range(8):  # максимум шагов агента
            with client.messages.stream(model=settings.get("model"), max_tokens=2048, system=system,
                                        tools=tools, messages=messages) as stream:
                for event in stream:
                    if self._cancel.is_set():
                        break
                    if event.type == "content_block_delta" and event.delta.type == "text_delta":
                        chunk = event.delta.text
                        if not silent:
                            if not started:
                                self.reply_started.emit()
                                started = True
                            self.reply_delta.emit(chunk)
                            sentence_buf += chunk
                            sentence_buf = self._speak_sentences(sentence_buf)
                        full.append(chunk)
                if self._cancel.is_set():
                    break
                msg = stream.get_final_message()
            messages.append({"role": "assistant", "content": [b.model_dump(exclude_none=True) for b in msg.content]})
            if msg.stop_reason == "pause_turn":
                continue
            if msg.stop_reason != "tool_use":
                break
            results = []
            for b in msg.content:
                if b.type == "tool_use":
                    self.status.emit(f"Действие: {b.name}")
                    res = self.tools.run(b.name, dict(b.input or {}), self._confirm)
                    if isinstance(res, str):
                        self.action_done.emit(f"{b.name}: {res[:120]}")
                    results.append({"type": "tool_result", "tool_use_id": b.id,
                                    "content": res if isinstance(res, list) else str(res)[:8000]})
            messages.append({"role": "user", "content": results})
            if full and not full[-1].endswith((" ", "\n")):
                full.append(" ")
                if not silent:
                    self.reply_delta.emit(" ")
        if not silent and sentence_buf.strip() and not self._cancel.is_set():
            self.speak(sentence_buf)
        return "".join(full).strip()

    _SENT = re.compile(r"(.+?[.!?…](?:\s|$)|.+?\n)", re.S)

    def _speak_sentences(self, buf):
        """Озвучиваем ответ по предложениям по мере генерации — минимальная задержка."""
        while True:
            m = self._SENT.match(buf)
            if not m or len(m.group(1)) < 2:
                return buf
            self.speak(m.group(1))
            buf = buf[m.end():]

    def speak(self, text):
        if self.tts and settings.get("tts_enabled") and not self._cancel.is_set():
            clean = re.sub(r"```.*?```", " код показан в чате. ", text, flags=re.S)
            clean = re.sub(r"[*_#`>|]+", "", clean)
            clean = re.sub(r"https?://\S+", "ссылка", clean).strip()
            if clean:
                self.state_changed.emit("speaking")
                self.tts.say(clean)

    # ---------- режимы ----------
    def set_translate(self, enabled, target="en"):
        self.translate_mode = bool(enabled)
        self.translate_target = target or "en"
        self.mode_changed.emit("translate", self.translate_mode)
        return f"Переводчик {'включён: ' + self.translate_target if enabled else 'выключен'}"

    def _translate(self, text):
        client = self.client()
        if not client:
            return self._emit_reply("Для перевода нужен Claude API.")
        r = client.messages.create(model=settings.get("fast_model"), max_tokens=500, messages=[{"role": "user", "content":
            f"Переведи. Если текст на русском — на язык '{self.translate_target}', иначе — на русский. "
            f"Выведи только перевод.\n\n{text}"}])
        out = "".join(b.text for b in r.content if b.type == "text")
        if self.tts:
            self.tts.say(out, lang_hint=None if re.search("[а-яё]", out, re.I) else self.translate_target)
        self.reply_started.emit()
        self.reply_delta.emit(out)
        return out

    def set_gaming(self, enabled):
        settings.set("gaming_mode", bool(enabled))
        try:
            from .pc import NO_WINDOW
            import subprocess
            plan = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" if enabled else "381b4222-f694-41f0-9685-ff5bb260df2e"
            subprocess.run(["powercfg", "/setactive", plan], creationflags=NO_WINDOW, timeout=5)
        except Exception:
            pass
        self.mode_changed.emit("gaming", bool(enabled))
        return "Игровой режим включён: высокая производительность, уведомления только важные." if enabled \
            else "Игровой режим выключен."

    def end_conversation(self):
        self.conversation_mode = False
        self.mode_changed.emit("conversation", False)
        return "Режим беседы завершён"

    def clear_history(self):
        self.db.clear_history()
        self.db.session = self.db.new_session()
