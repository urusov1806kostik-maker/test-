"""Discord через официальный Bot API (discord.py).
Ограничение Discord: автоматизация личного аккаунта (self-bot) запрещена правилами, поэтому E.C.H.O
работает через вашего бота — он видит только серверы/каналы, куда его добавили.
Нужно включить Message Content Intent и Server Members Intent в Developer Portal."""
import asyncio
import logging
import threading

from ..config import settings

log = logging.getLogger("echo.discord")


class DiscordClient:
    def __init__(self, on_message=None):
        self.on_message = on_message
        self.connected = False
        self.error = ""
        self.bot = None
        self.loop = None

    def start(self):
        token = settings.get_secret("discord_token")
        if not token:
            raise RuntimeError("Токен Discord-бота не задан")
        import discord
        intents = discord.Intents.default()
        intents.message_content = True
        intents.members = True
        self.loop = asyncio.new_event_loop()

        def runner():
            asyncio.set_event_loop(self.loop)
            self.bot = discord.Client(intents=intents)

            @self.bot.event
            async def on_ready():
                self.connected = True
                log.info("Discord: %s", self.bot.user)

            @self.bot.event
            async def on_message(msg):
                if msg.author == self.bot.user:
                    return
                if self.on_message and (self.bot.user in msg.mentions or msg.guild is None):
                    self.on_message(f"{msg.author.display_name} ({'ЛС' if msg.guild is None else '#' + msg.channel.name})",
                                    msg.content)
            try:
                self.loop.run_until_complete(self.bot.start(token))
            except Exception as e:
                self.error = str(e)
                self.connected = False
                log.warning("discord: %s", e)
        threading.Thread(target=runner, daemon=True).start()

    def stop(self):
        if self.bot and self.loop:
            asyncio.run_coroutine_threadsafe(self.bot.close(), self.loop)
        self.connected = False

    def _run(self, coro, timeout=30):
        return asyncio.run_coroutine_threadsafe(coro, self.loop).result(timeout)

    def _channel(self, name):
        n = name.lower().lstrip("#")
        for g in self.bot.guilds:
            for c in g.text_channels:
                if c.name.lower() == n or n in c.name.lower():
                    return c
        return None

    def list_channels(self):
        return "\n".join(f"{g.name}: " + ", ".join("#" + c.name for c in g.text_channels) for g in self.bot.guilds) or "Бот не добавлен ни на один сервер"

    def read(self, channel, limit=15):
        c = self._channel(channel)
        if not c:
            return "Канал не найден"

        async def go():
            msgs = [m async for m in c.history(limit=int(limit))]
            return "\n".join(f"[{m.created_at:%d.%m %H:%M}] {m.author.display_name}: {m.content[:500]}" for m in reversed(msgs))
        return self._run(go())

    def send(self, channel, text):
        c = self._channel(channel)
        if not c:
            return "Канал не найден"
        self._run(c.send(text))
        return f"Отправлено в #{c.name}"

    def search(self, query):
        q = query.lower()
        res = {f"{m.display_name} (@{m.name})" for g in self.bot.guilds for m in g.members
               if q in m.display_name.lower() or q in m.name.lower()}
        return ", ".join(sorted(res)[:20]) or "Не найдено"
