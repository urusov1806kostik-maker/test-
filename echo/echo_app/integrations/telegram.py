"""Telegram через официальный клиентский API (Telethon, MTProto).
Нужны api_id и api_hash с https://my.telegram.org — вход по номеру телефона и коду.
Сессия хранится локально в %APPDATA%/ECHO."""
import asyncio
import logging
import os
import threading
import webbrowser

from ..config import settings, data_dir

log = logging.getLogger("echo.telegram")


class TelegramClient:
    def __init__(self, on_message=None):
        self.on_message = on_message   # (sender, text)
        self.client = None
        self.connected = False
        self.loop = asyncio.new_event_loop()
        threading.Thread(target=self.loop.run_forever, daemon=True).start()

    def _run(self, coro, timeout=60):
        return asyncio.run_coroutine_threadsafe(coro, self.loop).result(timeout)

    def _make(self):
        from telethon import TelegramClient as TC
        api_id = int(settings.get("telegram_api_id") or 0)
        api_hash = settings.get_secret("telegram_api_hash")
        if not api_id or not api_hash:
            raise RuntimeError("Укажите api_id и api_hash Telegram в настройках")

        async def mk():
            return TC(str(data_dir() / "telegram"), api_id, api_hash)
        return self._run(mk())

    def start(self):
        """Подключиться с сохранённой сессией. Возвращает True, если авторизован."""
        if self.client is None:
            self.client = self._make()
        self._run(self.client.connect())
        ok = self._run(self.client.is_user_authorized())
        if ok:
            self._attach()
        return ok

    def send_code(self, phone):
        if self.client is None:
            self.client = self._make()
            self._run(self.client.connect())
        self._phone = phone
        self._run(self.client.send_code_request(phone))

    def sign_in(self, code, password=None):
        from telethon.errors import SessionPasswordNeededError
        try:
            self._run(self.client.sign_in(self._phone, code))
        except SessionPasswordNeededError:
            if not password:
                raise RuntimeError("Нужен пароль двухфакторной аутентификации")
            self._run(self.client.sign_in(password=password))
        self._attach()

    def _attach(self):
        from telethon import events
        self.connected = True

        @self.client.on(events.NewMessage(incoming=True))
        async def handler(ev):
            if self.on_message and ev.is_private:
                s = await ev.get_sender()
                name = getattr(s, "first_name", None) or getattr(s, "title", "Кто-то")
                self.on_message(name, ev.raw_text or "[медиа]")

    def logout(self):
        if self.client:
            self._run(self.client.log_out())
        self.connected = False
        self.client = None

    # ---------- функции ----------
    async def _find(self, name):
        name_l = name.lower()
        async for d in self.client.iter_dialogs(limit=300):
            if name_l in (d.name or "").lower():
                return d
        return None

    def unread_text(self):
        async def go():
            out = []
            async for d in self.client.iter_dialogs(limit=100):
                if d.unread_count and not d.archived:
                    msgs = await self.client.get_messages(d.entity, limit=min(d.unread_count, 5))
                    txt = " | ".join((m.message or "[медиа]")[:200] for m in reversed(msgs))
                    out.append(f"{d.name} ({d.unread_count}): {txt}")
            return "\n".join(out[:20]) or "Непрочитанных нет"
        return self._run(go())

    def read_chat(self, chat, limit=15):
        async def go():
            d = await self._find(chat)
            if not d:
                return f"Чат «{chat}» не найден"
            msgs = await self.client.get_messages(d.entity, limit=int(limit))
            lines = []
            for m in reversed(msgs):
                who = "Я" if m.out else (getattr(m.sender, "first_name", None) or d.name)
                lines.append(f"[{m.date:%d.%m %H:%M}] {who}: {(m.message or '[медиа]')[:500]}")
            return f"Чат {d.name}:\n" + "\n".join(lines)
        return self._run(go())

    def search(self, query):
        async def go():
            q = query.lower()
            res = [d.name async for d in self.client.iter_dialogs(limit=500) if q in (d.name or "").lower()]
            return ", ".join(res[:20]) or "Не найдено"
        return self._run(go())

    def send(self, chat, text):
        async def go():
            d = await self._find(chat)
            if not d:
                return f"Чат «{chat}» не найден"
            await self.client.send_message(d.entity, text)
            return f"Отправлено в {d.name}"
        return self._run(go())

    def open_chat(self, chat):
        async def go():
            d = await self._find(chat)
            if not d:
                return f"Чат «{chat}» не найден"
            u = getattr(d.entity, "username", None)
            url = f"tg://resolve?domain={u}" if u else f"tg://openmessage?user_id={d.entity.id}"
            if os.name == "nt":
                os.startfile(url)  # noqa
            else:
                webbrowser.open(url)
            return f"Открываю чат {d.name}"
        return self._run(go())
