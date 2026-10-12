"""Реестр действий. Claude вызывает их через tool use — так он сам отличает команду от обсуждения.
Опасные действия требуют подтверждения пользователя."""
import base64
import io
import json
import logging
import time
from dataclasses import dataclass
from typing import Callable

from . import apps, pc, security, steam, sysmon
from .config import settings

log = logging.getLogger("echo.tools")


@dataclass
class Tool:
    name: str
    description: str
    params: dict
    handler: Callable
    dangerous: bool = False
    required: tuple = ()

    def schema(self):
        return {"name": self.name, "description": self.description,
                "input_schema": {"type": "object", "properties": self.params, "required": list(self.required)}}


S = lambda d: {"type": "string", "description": d}          # noqa
I = lambda d: {"type": "integer", "description": d}         # noqa
B = lambda d: {"type": "boolean", "description": d}         # noqa


class Toolbox:
    def __init__(self, assistant):
        self.a = assistant
        self.tools: dict[str, Tool] = {}
        self._games = None
        self._register()

    def add(self, name, desc, params, handler, dangerous=False, required=None):
        self.tools[name] = Tool(name, desc, params, handler, dangerous, tuple(required if required is not None else params))

    def schemas(self):
        return [t.schema() for t in self.tools.values() if self._available(t.name)]

    def _available(self, name):
        if name.startswith("telegram_"):
            return bool(self.a.telegram and self.a.telegram.connected)
        if name.startswith("discord_"):
            return bool(self.a.discord and self.a.discord.connected)
        if name == "click_on_screen":
            return settings.get("allow_ui_control")
        return True

    def games(self, refresh=False):
        if self._games is None or refresh:
            self._games = steam.find_games()
        return self._games

    def run(self, name, args, confirm: Callable[[str], bool]):
        t = self.tools.get(name)
        if not t:
            return f"Нет такого действия: {name}"
        if t.dangerous and settings.get("confirm_dangerous"):
            desc = f"{name}({', '.join(f'{k}={v}' for k, v in args.items())})"
            if not confirm(f"Подтвердите действие: {self._human(name, args) or desc}"):
                return "Пользователь отменил действие."
        try:
            pc.com_init()
            res = t.handler(**args)
            log.info("tool %s %s -> %s", name, args, str(res)[:200])
            return res
        except Exception as e:  # noqa
            log.exception("tool %s failed", name)
            return f"Ошибка: {e}"

    @staticmethod
    def _human(name, a):
        return {"close_program": f"закрыть «{a.get('name')}»", "steam_close_game": f"закрыть игру «{a.get('name')}»",
                "power": f"питание: {a.get('action')}", "telegram_send": f"отправить в Telegram «{a.get('chat')}»:\n{a.get('text')}",
                "discord_send": f"отправить в Discord #{a.get('channel')}:\n{a.get('text')}",
                "click_on_screen": f"кликнуть по экрану ({a.get('x')}, {a.get('y')}) — {a.get('target', '')}",
                "type_text": f"напечатать текст: {a.get('text')}"}.get(name)

    # ------------------------------------------------------------------
    def _register(self):
        A = self.add
        # программы
        A("open_program", "Запустить установленную программу по названию (ищет в меню Пуск, реестре, ярлыках).",
          {"name": S("название программы")}, self.open_program)
        A("close_program", "Закрыть запущенную программу по имени процесса или названию.", {"name": S("имя")},
          pc.close_program, dangerous=True)
        A("list_programs", "Список найденных установленных программ.", {}, lambda: ", ".join(apps.index.list_names()[:300]))
        # веб
        A("open_website", "Открыть сайт в браузере (адрес или известное название: ютуб, вк, гитхаб...).",
          {"site": S("адрес или название")}, pc.open_site)
        A("browser_search", "Открыть поиск Google в браузере пользователя.", {"query": S("запрос")}, pc.web_search)
        # звук и музыка
        A("set_volume", "Установить громкость системы в процентах.", {"percent": I("0-100")}, pc.set_volume)
        A("change_volume", "Изменить громкость на delta процентов (+/-).", {"delta": I("например 10 или -10")}, pc.change_volume)
        A("toggle_mute", "Включить/выключить звук.", {}, pc.mute)
        A("media_control", "Управление музыкой/медиа.", {"action": {"type": "string", "enum": ["play", "pause", "next", "prev", "stop"]}},
          pc.media)
        # окна
        A("focus_window", "Переключиться на окно по части заголовка.", {"title": S("часть заголовка")}, pc.focus_window)
        A("switch_window", "Alt+Tab — переключить на предыдущее окно.", {}, pc.switch_window)
        A("show_desktop", "Свернуть все окна.", {}, pc.show_desktop)
        A("list_windows", "Список открытых окон.", {}, lambda: "\n".join(t for _, t in pc.list_windows()))
        # файлы
        A("open_folder", "Открыть папку (загрузки, документы, рабочий стол, изображения, музыка, видео, скриншоты или путь).",
          {"folder": S("папка")}, pc.open_folder)
        A("search_files", "Найти файлы по части имени в папках пользователя.", {"query": S("часть имени")},
          lambda query: "\n".join(pc.search_files(query)) or "Ничего не найдено")
        A("open_file", "Открыть файл по полному пути.", {"path": S("путь")}, lambda path: (pc.open_path(path), f"Открываю {path}")[1])
        A("file_info", "Прочитать начало текстового файла (до 4000 символов).", {"path": S("путь")}, self.read_file)
        # скриншот и зрение
        A("take_screenshot", "Сделать скриншот и сохранить в Изображения/ECHO.", {}, lambda: f"Сохранено: {pc.screenshot()[1]}")
        A("look_at_screen", "Посмотреть на экран пользователя (получить скриншот для анализа: текст, ошибки, кнопки, "
          "помощь с программами). Используй, когда спрашивают о том, что на экране.", {}, self.look_at_screen)
        A("click_on_screen", "Кликнуть мышью по координатам на последнем скриншоте (координаты в пикселях скриншота).",
          {"x": I("x"), "y": I("y"), "target": S("что нажимаем"), "double": B("двойной клик")}, self.click,
          dangerous=True, required=["x", "y", "target"])
        A("type_text", "Напечатать текст в активное окно.", {"text": S("текст")}, self.type_text, dangerous=True)
        # система
        A("system_status", "Загрузка CPU, RAM, GPU, температуры.", {}, sysmon.summary)
        A("open_windows_settings", "Открыть раздел настроек Windows.",
          {"page": {"type": "string", "enum": list(pc.SETTINGS_PAGES)}}, pc.open_settings)
        A("set_dark_theme", "Включить тёмную (true) или светлую (false) тему Windows.", {"dark": B("тёмная?")}, pc.set_dark_theme)
        A("set_brightness", "Яркость экрана ноутбука, %.", {"percent": I("0-100")}, pc.set_brightness)
        A("lock_pc", "Заблокировать компьютер.", {}, pc.lock_pc)
        A("power", "Выключить/перезагрузить/сон/отменить выключение.",
          {"action": {"type": "string", "enum": ["shutdown", "restart", "sleep", "cancel"]}}, pc.power, dangerous=True)
        # steam
        A("steam_list_games", "Список установленных игр Steam.", {}, lambda: ", ".join(g["name"] for g in self.games(True).values()) or "Игры Steam не найдены")
        A("steam_launch_game", "Запустить игру Steam по названию.", {"name": S("название игры")}, self.launch_game)
        A("steam_open", "Открыть Steam.", {}, lambda: (steam.open_steam(), "Открываю Steam")[1])
        A("steam_running_games", "Какие игры сейчас запущены.", {},
          lambda: ", ".join(g["name"] for g in steam.running_games(self.games()).values()) or "Игры не запущены")
        A("steam_close_game", "Закрыть запущенную игру.", {"name": S("название")}, self.close_game, dangerous=True)
        # security
        A("security_report", "Отчёт о безопасности: Defender, угрозы, подозрительные процессы, автозагрузка.", {}, security.report)
        A("defender_quick_scan", "Запустить быструю проверку Microsoft Defender (несколько минут).", {}, security.quick_scan)
        A("defender_scan_file", "Проверить файл антивирусом.", {"path": S("путь")}, security.scan_file)
        A("startup_programs", "Список автозагрузки.", {}, lambda: "\n".join(f"{i['name']}: {i['command']}" for i in security.startup_items()))
        # память, напоминания, режимы
        A("remember", "Запомнить факт о пользователе/предпочтение надолго.", {"fact": S("факт")},
          lambda fact: (self.a.db.add_memory(fact), "Запомнил")[1])
        A("forget_all_memories", "Удалить все долговременные воспоминания.", {}, lambda: (self.a.db.clear_memories(), "Память очищена")[1],
          dangerous=True)
        A("set_reminder", "Поставить напоминание через N минут.", {"text": S("о чём"), "minutes": {"type": "number", "description": "через сколько минут"}},
          lambda text, minutes: (self.a.db.add_reminder(text, time.time() + float(minutes) * 60),
                                 f"Напомню через {minutes:g} мин: {text}")[1])
        A("list_reminders", "Активные напоминания.", {}, lambda: "\n".join(
            f"{time.strftime('%d.%m %H:%M', time.localtime(r['due']))} — {r['text']}" for r in self.a.db.reminders()) or "Нет напоминаний")
        A("live_translate", "Включить/выключить режим голосового перевода.", {"enabled": B("вкл"), "target_language": S("код языка, напр. en")},
          lambda enabled, target_language="en": self.a.set_translate(enabled, target_language), required=["enabled"])
        A("gaming_mode", "Включить/выключить игровой режим (тише уведомления, высокая производительность).", {"enabled": B("вкл")},
          lambda enabled: self.a.set_gaming(enabled))
        A("end_conversation", "Завершить режим беседы, когда пользователь прощается/просит закончить.", {}, lambda: self.a.end_conversation())
        # telegram
        A("telegram_unread", "Непрочитанные сообщения Telegram (кратко).", {}, lambda: self.a.telegram.unread_text())
        A("telegram_read_chat", "Последние сообщения из чата Telegram.", {"chat": S("имя контакта/чата"), "limit": I("сколько")},
          lambda chat, limit=15: self.a.telegram.read_chat(chat, limit), required=["chat"])
        A("telegram_search_contacts", "Найти контакт/чат Telegram.", {"query": S("имя")}, lambda query: self.a.telegram.search(query))
        A("telegram_open_chat", "Открыть переписку в приложении Telegram.", {"chat": S("имя")}, lambda chat: self.a.telegram.open_chat(chat))
        A("telegram_send", "Отправить сообщение в Telegram (только после явной просьбы пользователя).",
          {"chat": S("кому"), "text": S("текст")}, lambda chat, text: self.a.telegram.send(chat, text), dangerous=True)
        # discord
        A("discord_list_channels", "Список доступных каналов Discord (бот).", {}, lambda: self.a.discord.list_channels())
        A("discord_read_channel", "Последние сообщения канала Discord.", {"channel": S("имя канала"), "limit": I("сколько")},
          lambda channel, limit=15: self.a.discord.read(channel, limit), required=["channel"])
        A("discord_send", "Отправить сообщение в канал Discord от бота.", {"channel": S("канал"), "text": S("текст")},
          lambda channel, text: self.a.discord.send(channel, text), dangerous=True)
        A("discord_search_members", "Найти участника на серверах.", {"query": S("имя")}, lambda query: self.a.discord.search(query))
        # свои команды
        A("create_custom_command", "Создать свою команду: фраза -> список шагов (каждый шаг — текстовая команда для E.C.H.O).",
          {"phrase": S("фраза-триггер"), "steps": {"type": "array", "items": {"type": "string"}}},
          lambda phrase, steps: (self.a.db.set_custom_command(phrase, json.dumps(steps, ensure_ascii=False)),
                                 f"Команда «{phrase}» создана")[1])

    # ---------- обработчики ----------
    def open_program(self, name):
        hit = apps.index.find(name)
        if not hit:
            g = steam.match_game(name, self.games())
            if g:
                return self.launch_game(name)
            return f"Не нашёл программу «{name}»"
        apps.launch(hit[1])
        return f"Запускаю {hit[0]}"

    def launch_game(self, name):
        g = steam.match_game(name, self.games())
        if not g:
            g = steam.match_game(name, self.games(True))
        if not g:
            return f"Игра «{name}» не найдена в Steam"
        steam.launch_game(g[0])
        return f"Запускаю {g[1]['name']}"

    def close_game(self, name):
        g = steam.match_game(name, self.games())
        if not g:
            return "Игра не найдена"
        return f"Закрыл {g[1]['name']}" if steam.close_game(g[0], self.games()) else "Игра не запущена"

    @staticmethod
    def read_file(path):
        with open(path, encoding="utf-8", errors="ignore") as f:
            return f.read(4000)

    def look_at_screen(self):
        img, _ = pc.screenshot(save=False)
        w, h = img.size
        scale = min(1.0, 1568 / max(w, h))
        if scale < 1:
            img = img.resize((int(w * scale), int(h * scale)))
        self.a.last_screen_scale = scale
        buf = io.BytesIO()
        img.convert("RGB").save(buf, "JPEG", quality=80)
        data = base64.b64encode(buf.getvalue()).decode()
        return [{"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": data}},
                {"type": "text", "text": f"Скриншот {img.size[0]}x{img.size[1]}. Координаты для click_on_screen — в этих пикселях."}]

    def click(self, x, y, target="", double=False):
        import ctypes
        s = getattr(self.a, "last_screen_scale", 1.0) or 1.0
        rx, ry = int(x / s), int(y / s)
        u = ctypes.windll.user32
        u.SetCursorPos(rx, ry)
        for _ in range(2 if double else 1):
            u.mouse_event(2, 0, 0, 0, 0)
            u.mouse_event(4, 0, 0, 0, 0)
        return f"Нажал: {target}"

    @staticmethod
    def type_text(text):
        import ctypes
        import pyperclip
        pyperclip.copy(text)
        u = ctypes.windll.user32
        u.keybd_event(0x11, 0, 0, 0); u.keybd_event(0x56, 0, 0, 0)   # noqa: E702  Ctrl+V
        u.keybd_event(0x56, 0, 2, 0); u.keybd_event(0x11, 0, 2, 0)   # noqa: E702
        return "Текст вставлен"
