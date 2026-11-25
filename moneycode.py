"""Moneycode — личный ИИ-агент, который работает с твоим компом.

Запуск:  python moneycode.py   (или Moneycode.exe)
Набери «/» — появится меню команд.
"""
import itertools
import json
import os
import platform
import sys

# Чтобы русский текст и эмодзи не ломали консоль Windows
for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

import anthropic

import tools
import ui
from tools import BASE, HANDLERS, TOOLS, load_knowledge, load_lessons, load_memory

CONFIG = BASE / "config.json"
DEFAULT_MODEL = "claude-opus-5-5"


def load_config() -> dict:
    try:
        return json.loads(CONFIG.read_text(encoding="utf-8"))
    except Exception:
        return {}


def save_config(cfg: dict) -> None:
    CONFIG.write_text(json.dumps(cfg, ensure_ascii=False, indent=2), encoding="utf-8")


cfg = load_config()
MODEL = cfg.get("model", DEFAULT_MODEL)
client = None

# Серверный веб-поиск (работает на стороне Anthropic)
ALL_TOOLS = TOOLS + [{"type": "web_search_20260209", "name": "web_search"}]


def get_api_key() -> str:
    """Ключ: из переменной окружения, иначе из config.json рядом с exe, иначе спросить один раз."""
    if os.getenv("ANTHROPIC_API_KEY"):
        return os.environ["ANTHROPIC_API_KEY"]
    if cfg.get("api_key"):
        return cfg["api_key"]
    ui.info("Первый запуск. Нужен API-ключ Anthropic (console.anthropic.com → API Keys).")
    key = ui.console.input("[bold]Вставь ключ: [/]").strip()
    cfg["api_key"] = key
    save_config(cfg)
    ui.info(f"Сохранил в {CONFIG}\n")
    return key


def system_prompt() -> list:
    # Неизменная часть (правила + база знаний) — первым блоком: так она кэшируется и стоит дешевле.
    static = f"""Ты — Moneycode, личный ИИ-помощник пользователя. Работаешь прямо на его компьютере ({platform.system()}).
Говоришь по-русски, коротко и по делу, как человек. Ответы оформляй в Markdown (списки, **жирный**), без воды.

Что умеешь: видеть экран (screenshot), кликать и печатать (mouse, keyboard), открывать программы (open_app),
запускать команды (run_command), читать и писать файлы, ходить по сайтам, Instagram и TikTok через свой браузер (browser),
искать в интернете (web_search), делать видео (make_video, с озвучкой) и обложки (make_image).

Как работаешь:
- Сначала подумай и составь короткий план, потом делай шаг за шагом и проверяй результат (скрин/чтение страницы).
- Для сайтов, Instagram и TikTok используй browser, а не клики по экрану — так надёжнее.
- Если нужно залогиниться — попроси пользователя войти самому в открывшемся окне браузера. Пароли не спрашивай.
- Пиши людям и публикуй только то, что сказал пользователь, и только после его «да». Никакого спама, накруток и обмана.
- Узнал что-то важное о пользователе (имя, возраст, страна, ниша, цели) — сохрани через memory.
- Не удаляй файлы и не делай необратимого без прямой просьбы.
- После задачи, если узнал что-то полезное (рабочий селектор, правильную команду, свою ошибку) — запиши через learn.
  Так ты становишься лучше с каждым запуском.

=== БАЗА ЗНАНИЙ ===
{load_knowledge()}"""
    mem = load_memory()
    mem_txt = "\n".join(f"{i}. {m}" for i, m in enumerate(mem)) or "(пока пусто)"
    dynamic = f"""Твоя память о пользователе:
{mem_txt}

=== ТВОИ УРОКИ ИЗ ОПЫТА (следуй им) ===
{load_lessons() or "(пока нет)"}"""
    return [{"type": "text", "text": static, "cache_control": {"type": "ephemeral"}},
            {"type": "text", "text": dynamic}]


def call_model(messages: list):
    kwargs = dict(
        model=MODEL,
        max_tokens=16000,
        system=system_prompt(),
        tools=ALL_TOOLS,
        messages=messages,
        output_config={"effort": "high"},
        cache_control={"type": "ephemeral"},  # кэш истории диалога — дешевле
        # старые скриншоты/результаты автоматически чистятся, чтобы не забивать контекст
        context_management={"edits": [{"type": "clear_tool_uses_20250919"}]},
        betas=["context-management-2025-06-27"],
    )
    if "haiku" not in MODEL:
        # если модель откажет — сервер сам повторит запрос на запасной
        kwargs["betas"].append("server-side-fallback-2026-07-01")
        kwargs["fallbacks"] = "default"
    with ui.console.status("[bold #22c55e]думаю…[/]", spinner="dots"):
        return client.beta.messages.create(**kwargs)


def ask(messages: list) -> None:
    """Агентный цикл: модель думает → вызывает инструменты → получает результат → снова думает."""
    while True:
        resp = call_model(messages)
        messages.append({"role": "assistant", "content": resp.content})

        if resp.stop_reason == "refusal":
            ui.error("Эту задачу выполнить не могу.")
            return
        for b in resp.content:
            if b.type == "text" and b.text.strip():
                ui.agent_says(b.text)
        if resp.stop_reason == "pause_turn":
            continue
        if resp.stop_reason == "max_tokens":
            ui.info("(ответ обрезан — напиши «продолжай»)")
            return

        calls = [b for b in resp.content if b.type == "tool_use"]
        if not calls:
            return
        results = []
        for c in calls:
            ui.tool_call(c.name, json.dumps(c.input, ensure_ascii=False))
            try:
                out = HANDLERS[c.name](c.input)
                results.append({"type": "tool_result", "tool_use_id": c.id, "content": out})
            except Exception as e:
                results.append({"type": "tool_result", "tool_use_id": c.id, "is_error": True,
                                "content": f"Ошибка: {e}"})
        messages.append({"role": "user", "content": results})


def safe_ask(messages: list, question: str) -> None:
    """Задать вопрос с обработкой ошибок. При сбое диалог откатывается к состоянию до вопроса."""
    start = len(messages)
    messages.append({"role": "user", "content": question})
    try:
        ask(messages)
        return
    except KeyboardInterrupt:
        ui.info("⏹ остановлено")
    except anthropic.AuthenticationError:
        ui.error("Неверный API-ключ. Удали config.json рядом с программой и запусти заново.")
    except anthropic.RateLimitError:
        ui.error("Лимит запросов, подожди минуту.")
    except anthropic.APIStatusError as e:
        ui.error(f"Ошибка API {e.status_code}: {e.message}")
    except anthropic.APIConnectionError:
        ui.error("Нет связи с сервером.")
    del messages[start:]


TRAINING = [
    "Сделай скриншот экрана и опиши, какие окна и программы сейчас открыты. Запиши урок, как устроен мой рабочий стол.",
    "Узнай через команды: версию Windows, имя пользователя, где рабочий стол (OneDrive или нет), сколько места на дисках, установлен ли python. Запомни это в memory.",
    "Посмотри, какие программы установлены (winget list или Пуск) и запомни основные.",
    "Открой в браузере https://www.instagram.com/ . Если я не залогинен — попроси войти. Потом открой директ и прочитай список чатов (НИЧЕГО не отправляй). Запиши уроки, какие кнопки и селекторы сработали.",
    "Открой любой чат в директе Instagram и прочитай последние сообщения (не отправляй ничего). Запиши урок, как это делается.",
    "Найди в интернете курс доллара к рублю и создай на рабочем столе файл moneycode_test.txt с ним. Проверь, что файл есть, и удали его.",
    "Открой Блокнот через open_app, напечатай «Moneycode тест», закрой без сохранения. Запиши урок, как это сделал.",
    "Открой https://web.telegram.org/a/ в браузере и опиши, что видишь (ничего не отправляй).",
    "Открой директ Инсты, найди непрочитанные чаты и кратко перескажи мне, кто что написал (ничего не отправляй).",
    "Придумай 3 варианта короткого ответа на последнее сообщение в любом чате директа, в моём стиле. Покажи мне, НЕ отправляй. Запиши урок про мой стиль общения.",
    "Открой Проводник (win+e), зайди в Загрузки и скажи, какие там 5 самых новых файлов. Сделай то же самое командой dir и сравни, что быстрее.",
    "Создай на рабочем столе таблицу moneycode_test.csv (3 строки: товар;цена) так, чтобы русский Excel открыл её без кракозябр. Проверь чтением и удали.",
    "Открой ms-settings:display и скажи, какое разрешение экрана. Закрой окно. Запомни разрешение в memory.",
    # TikTok
    "Открой https://www.tiktok.com в браузере. Если не залогинен — попроси войти (или скажи, что можно без входа). Опиши, что видишь. Ничего не лайкай и не подписывайся. Запиши урок про устройство сайта.",
    "Спроси меня (если ещё не знаешь из памяти): возраст, страна, ниша для TikTok, есть ли аккаунт. Запомни ответы в memory.",
    "Проверь через web_search актуальные условия монетизации TikTok для моей страны и возраста. Запиши урок с главными цифрами и датой проверки.",
    "Найди через web_search 5 трендовых форматов коротких видео этого месяца. Запиши урок.",
    "Сделай тестовое видео через make_video: 3 слайда про любой факт, без озвучки, сохрани на рабочий стол как moneycode_test.mp4. Проверь, что файл есть (dir). Потом удали. Запиши урок.",
    "Сделай тестовое видео с voiceover (2 слайда, одна фраза озвучки). Если озвучка не работает — разберись почему (есть ли русский голос) и запиши урок. Файл удали.",
    "Открой https://www.tiktok.com/tiktokstudio/upload и опиши форму загрузки (ничего не загружай и не публикуй). Запиши урок, где поле описания и кнопка публикации.",
    "Придумай 10 хуков для TikTok в моей нише. Покажи мне и запиши лучший приём в урок.",
    # Сайты
    "Сделай в Desktop\\moneycode_site красивый лендинг «Moneycode» по базе знаний (тёмная тема, hero, 3 карточки, кнопка). Открой его в browser (file:///...), сделай screenshot, оцени дизайн по 10-балльной и улучши то, что хуже 8. Запиши урок. Потом спроси, удалить ли папку.",
    "Открой https://app.netlify.com/drop и опиши, что там (ничего не загружай). Запиши урок, как выкладывать сайт.",
    # Видео
    "Сделай обложку make_image для YouTube с текстом «Тест Moneycode» в 2 стилях, посмотри их (read_file не подходит — открой через start и screenshot) и запиши урок, какой стиль лучше. Удали файлы.",
    "Проверь, установлен ли CapCut (winget list или Пуск). Запомни в memory.",
    "Проверь интернет: ping -n 3 google.com. Запиши урок, какой пинг считается нормальным.",
    "Прочитай свои уроки и память, найди повторы и противоречия и запиши один итоговый урок-шпаргалку.",
]


def train(n: int) -> None:
    """Тренировка: агент сам выполняет практические задания и копит уроки в lessons.md."""
    tasks = itertools.cycle(TRAINING) if n == 0 else (TRAINING * (n // len(TRAINING) + 1))[:n]
    try:
        for i, t in enumerate(tasks, 1):
            ui.console.rule(f"[bold #facc15]Тренировка {i}/{n or '∞'}[/]")
            ui.info(t)
            msgs = [{"role": "user", "content": t + "\nВ конце обязательно вызови learn с главным уроком."}]
            ask(msgs)
    except KeyboardInterrupt:
        ui.info("⏹ тренировка остановлена")
        return
    except anthropic.APIError as e:
        ui.error(f"Тренировка остановлена: {e}")
        return
    ui.info("✅ Тренировка закончена. Уроки — /lessons")


def status() -> str:
    m = MODEL.replace("claude-", "").replace("-5-5", " 5.5")
    safe = "🛡 безопасно" if tools.SAFE_MODE else "⚡ без подтверждений"
    lessons = load_lessons().count("\n- ")
    return f"💸 Moneycode │ {m} │ {safe} │ память {len(load_memory())} │ уроки {lessons} │ / меню │ Ctrl+C стоп"


def run_menu(title: str, menu: list, messages: list) -> None:
    i = ui.choose(title, [name for name, _ in menu])
    if i is not None:
        safe_ask(messages, menu[i][1])


def selftest() -> None:
    """Проверка, что в exe попало всё нужное (используется при сборке)."""
    import tempfile
    from pathlib import Path

    import imageio_ffmpeg
    import playwright.sync_api  # noqa: F401
    import prompt_toolkit  # noqa: F401
    import pyautogui  # noqa: F401
    import pyperclip  # noqa: F401
    assert "TikTok" in load_knowledge() and "САЙТЫ" in load_knowledge(), "knowledge.md не вшит"
    assert Path(imageio_ffmpeg.get_ffmpeg_exe()).exists(), "нет ffmpeg"
    out = Path(tempfile.mkdtemp()) / "t.mp4"
    r = tools.make_video({"slides": [{"text": "Тест", "seconds": 1}, {"text": "Ещё", "seconds": 1}], "output": str(out)})
    assert out.exists() and out.stat().st_size > 1000, r
    ui.logo()
    ui.help_table()
    ui.agent_says("**Markdown** работает:\n- пункт 1\n- пункт 2")
    print("SELFTEST OK")


def main():
    global client, MODEL
    if "--selftest" in sys.argv:
        return selftest()
    ui.console.clear()
    ui.logo()
    client = anthropic.Anthropic(api_key=get_api_key())
    inp = ui.Input(BASE / ".moneycode_history", status)
    messages = []
    while True:
        try:
            q = inp.read().strip()
        except KeyboardInterrupt:
            continue
        except EOFError:
            break
        if not q:
            continue
        cmd, _, arg = q.partition(" ")
        if cmd == "/exit":
            break
        elif cmd == "/help":
            ui.help_table()
        elif cmd == "/clear":
            ui.console.clear()
            ui.logo()
        elif cmd == "/new":
            messages = []
            ui.info("Новый диалог.")
        elif cmd == "/mem":
            ui.agent_says("\n".join(f"{i}. {m}" for i, m in enumerate(load_memory())) or "Память пуста")
        elif cmd == "/lessons":
            ui.agent_says(load_lessons() or "Уроков пока нет — запусти /train")
        elif cmd == "/safe":
            tools.SAFE_MODE = not tools.SAFE_MODE
            ui.info("Подтверждения " + ("включены 🛡" if tools.SAFE_MODE else "выключены ⚡ — осторожно"))
        elif cmd == "/model":
            names = list(ui.MODELS)
            i = ui.choose("модель", [("● " if n == MODEL else "  ") + ui.MODELS[n] for n in names])
            if i is not None:
                MODEL = names[i]
                cfg["model"] = MODEL
                save_config(cfg)
                ui.info(f"Модель: {ui.MODELS[MODEL]}")
        elif cmd == "/train":
            train(int(arg) if arg.strip().isdigit() else len(TRAINING))
        elif cmd == "/tiktok":
            run_menu("TikTok", ui.TIKTOK_MENU, messages)
        elif cmd == "/site":
            run_menu("сайты", ui.SITE_MENU, messages)
        elif cmd == "/video":
            run_menu("видео", ui.VIDEO_MENU, messages)
        elif cmd.startswith("/"):
            ui.error(f"Нет команды {cmd}. Набери / для меню.")
        else:
            safe_ask(messages, q)


if __name__ == "__main__":
    main()
