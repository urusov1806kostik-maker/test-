"""Moneycode — личный ИИ-агент, который работает с твоим компом.

Запуск:  python moneycode.py
Команды в чате:  /new — новый диалог,  /mem — память,  /lessons — уроки,
                 /train N — тренировка N заданий (/train 0 — бесконечно),  /exit — выход
"""
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

from tools import BASE, HANDLERS, TOOLS, load_knowledge, load_lessons, load_memory

MODEL = "claude-opus-5-5"
CONFIG = BASE / "config.json"


def get_api_key() -> str:
    """Ключ: из переменной окружения, иначе из config.json рядом с exe, иначе спросить один раз."""
    if os.getenv("ANTHROPIC_API_KEY"):
        return os.environ["ANTHROPIC_API_KEY"]
    try:
        return json.loads(CONFIG.read_text(encoding="utf-8"))["api_key"]
    except Exception:
        pass
    print("Первый запуск. Нужен API-ключ Anthropic (console.anthropic.com → API Keys).")
    key = input("Вставь ключ: ").strip()
    CONFIG.write_text(json.dumps({"api_key": key}), encoding="utf-8")
    print(f"Сохранил в {CONFIG}\n")
    return key


client = None

# Серверный веб-поиск (работает на стороне Anthropic)
ALL_TOOLS = TOOLS + [{"type": "web_search_20260209", "name": "web_search"}]


def system_prompt() -> str:
    mem = load_memory()
    mem_txt = "\n".join(f"{i}. {m}" for i, m in enumerate(mem)) or "(пока пусто)"
    return f"""Ты — Moneycode, личный ИИ-помощник пользователя. Работаешь прямо на его компьютере ({platform.system()}).
Говоришь по-русски, коротко и по делу, как человек.

Что умеешь: видеть экран (screenshot), кликать и печатать (mouse, keyboard), запускать команды (run_command),
читать и писать файлы, ходить по сайтам и в Instagram через свой браузер (browser), искать в интернете (web_search).

Как работаешь:
- Сначала подумай и составь короткий план, потом делай шаг за шагом и проверяй результат (скрин/чтение страницы).
- Для сайтов и Instagram используй browser, а не клики по экрану — так надёжнее.
- Если нужно залогиниться — попроси пользователя войти самому в открывшемся окне браузера. Пароли не спрашивай.
- В Instagram пиши только то и только тем, кого назвал пользователь. Никакого спама и массовых рассылок.
- Узнал что-то важное о пользователе (имя, предпочтения, привычные задачи) — сохрани через memory.
- Не удаляй файлы и не делай необратимого без прямой просьбы.

- После задачи, если узнал что-то полезное (рабочий селектор, правильную команду, свою ошибку) — запиши через learn.
  Так ты становишься лучше с каждым запуском.

Твоя память о пользователе:
{mem_txt}

=== БАЗА ЗНАНИЙ ===
{load_knowledge()}

=== ТВОИ УРОКИ ИЗ ОПЫТА (следуй им) ===
{load_lessons() or "(пока нет)"}"""


def ask(messages: list) -> None:
    """Агентный цикл: модель думает → вызывает инструменты → получает результат → снова думает."""
    while True:
        resp = client.beta.messages.create(
            model=MODEL,
            max_tokens=16000,
            system=system_prompt(),
            tools=ALL_TOOLS,
            messages=messages,
            output_config={"effort": "high"},
            # если основная модель откажет — сервер сам повторит запрос на запасной
            betas=["server-side-fallback-2026-07-01", "context-management-2025-06-27"],
            fallbacks="default",
            # старые скриншоты/результаты автоматически чистятся, чтобы не забивать контекст
            context_management={"edits": [{"type": "clear_tool_uses_20250919"}]},
        )

        if resp.stop_reason == "refusal":
            print("\nMoneycode: эту задачу выполнить не могу.\n")
            messages.append({"role": "assistant", "content": resp.content})
            return

        messages.append({"role": "assistant", "content": resp.content})
        for b in resp.content:
            if b.type == "text" and b.text.strip():
                print(f"\nMoneycode: {b.text}")

        if resp.stop_reason == "pause_turn":
            continue
        if resp.stop_reason == "max_tokens":
            print("\n(ответ обрезан — напиши «продолжай»)")
            return

        calls = [b for b in resp.content if b.type == "tool_use"]
        if not calls:
            return

        results = []
        for c in calls:
            print(f"  ⚙️  {c.name} {json.dumps(c.input, ensure_ascii=False)[:150]}")
            try:
                out = HANDLERS[c.name](c.input)
                results.append({"type": "tool_result", "tool_use_id": c.id, "content": out})
            except Exception as e:
                results.append({"type": "tool_result", "tool_use_id": c.id, "is_error": True,
                                "content": f"Ошибка: {e}"})
        messages.append({"role": "user", "content": results})


TRAINING = [
    "Сделай скриншот экрана и опиши, какие окна и программы сейчас открыты. Запиши урок, как устроен мой рабочий стол.",
    "Узнай через команды: версию Windows, имя пользователя, где рабочий стол (OneDrive или нет), сколько места на дисках. Запомни это в memory.",
    "Посмотри, какие программы установлены (winget list или Пуск) и запомни основные.",
    "Открой в браузере https://www.instagram.com/ . Если я не залогинен — попроси войти. Потом открой директ и прочитай список чатов (НИЧЕГО не отправляй). Запиши уроки, какие кнопки и селекторы сработали.",
    "Открой любой чат в директе Instagram и прочитай последние сообщения (не отправляй ничего). Запиши урок, как это делается.",
    "Найди в интернете курс доллара к рублю и создай на рабочем столе файл moneycode_test.txt с ним. Проверь, что файл есть, и удали его.",
    "Открой Блокнот через Пуск, напечатай «Moneycode тест», закрой без сохранения. Запиши урок, как это сделал.",
    "Напиши Python-скрипт, который выводит 10 чисел Фибоначчи, запусти его, проверь вывод, удали скрипт.",
    "Открой https://web.telegram.org/a/ в браузере и опиши, что видишь (ничего не отправляй).",
    "Открой https://www.instagram.com/explore/ и найди через поиск любой популярный аккаунт. Прочитай его профиль (ничего не нажимай «Подписаться»). Запиши урок, как работает поиск.",
    "Открой директ Инсты, найди непрочитанные чаты и кратко перескажи мне, кто что написал (ничего не отправляй).",
    "Придумай 3 варианта короткого ответа на последнее сообщение в любом чате директа, в моём стиле. Покажи мне, НЕ отправляй. Запиши урок про мой стиль общения.",
    "Открой Проводник (win+e), зайди в Загрузки и скажи, какие там 5 самых новых файлов. Сделай то же самое командой dir и сравни, что быстрее.",
    "Создай на рабочем столе таблицу moneycode_test.csv (3 строки: товар;цена) так, чтобы русский Excel открыл её без кракозябр. Проверь чтением и удали.",
    "Найди в интернете 3 свежие идеи, как заработать школьнику/студенту законно в интернете. Кратко опиши и запомни в memory, что меня интересует заработок.",
    "Открой https://mail.google.com и опиши, что видишь (вход/входящие). Ничего не отправляй.",
    "Сделай скриншот, найди на экране панель задач и часы, скажи время. Запиши урок про координаты панели задач.",
    "Напиши и запусти Python-скрипт, который выводит свободное место на всех дисках в ГБ. Удали скрипт после проверки.",
    "Открой YouTube в браузере, найди видео «как заработать в инстаграме» и перескажи названия первых 5 результатов.",
    "Прочитай свои уроки и память, найди повторы и противоречия и запиши один итоговый урок-шпаргалку.",
]


def train(n: int) -> None:
    """Тренировка: агент сам выполняет практические задания и копит уроки в lessons.md."""
    import itertools
    tasks = itertools.cycle(TRAINING) if n == 0 else (TRAINING * (n // len(TRAINING) + 1))[:n]
    for i, t in enumerate(tasks, 1):
        print(f"\n===== Тренировка {i}/{n or '∞ (Ctrl+C — стоп)'}: {t}\n")
        ask([{"role": "user", "content": t + "\nВ конце обязательно вызови learn с главным уроком."}])
    print("\n✅ Тренировка закончена. Уроки — в lessons.md (команда /lessons).")


def selftest() -> None:
    """Проверка, что в exe попало всё нужное (используется при сборке)."""
    import playwright.sync_api  # noqa: F401
    import pyautogui  # noqa: F401
    import pyperclip  # noqa: F401
    assert "Instagram" in load_knowledge(), "knowledge.md не вшит"
    print("SELFTEST OK")


def main():
    global client
    if "--selftest" in sys.argv:
        return selftest()
    client = anthropic.Anthropic(api_key=get_api_key())
    print("💸 Moneycode запущен. Пиши задачу. (/new, /mem, /lessons, /train N, /exit)\n")
    messages = []
    while True:
        try:
            q = input("Ты: ").strip()
        except (EOFError, KeyboardInterrupt):
            break
        if not q:
            continue
        if q == "/exit":
            break
        if q == "/new":
            messages = []
            print("Новый диалог.")
            continue
        if q == "/lessons":
            print(load_lessons() or "Уроков пока нет — запусти /train")
            continue
        if q.startswith("/train"):
            parts = q.split()
            try:
                train(int(parts[1]) if len(parts) > 1 else len(TRAINING))
            except (anthropic.APIError, KeyboardInterrupt) as e:
                print(f"Тренировка остановлена: {e}")
            continue
        if q == "/mem":
            print("\n".join(f"{i}. {m}" for i, m in enumerate(load_memory())) or "Память пуста")
            continue
        messages.append({"role": "user", "content": q})
        try:
            ask(messages)
        except anthropic.AuthenticationError:
            print("Нет/неверный API-ключ. Задай ANTHROPIC_API_KEY (см. README).")
            messages.pop()
        except anthropic.RateLimitError:
            print("Лимит запросов, подожди минуту.")
            messages.pop()
        except anthropic.APIStatusError as e:
            print(f"Ошибка API {e.status_code}: {e.message}")
            messages.pop()
        except anthropic.APIConnectionError:
            print("Нет связи с сервером.")
            messages.pop()
        print()


if __name__ == "__main__":
    main()
