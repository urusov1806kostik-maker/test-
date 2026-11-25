"""Интерфейс Moneycode в терминале: логотип, меню команд по «/», строка статуса."""
LOGO_BIG = ['███╗   ███╗ ██████╗ ███╗   ██╗███████╗██╗   ██╗ ██████╗ ██████╗ ██████╗ ███████╗', '████╗ ████║██╔═══██╗████╗  ██║██╔════╝╚██╗ ██╔╝██╔════╝██╔═══██╗██╔══██╗██╔════╝', '██╔████╔██║██║   ██║██╔██╗ ██║█████╗   ╚████╔╝ ██║     ██║   ██║██║  ██║█████╗', '██║╚██╔╝██║██║   ██║██║╚██╗██║██╔══╝    ╚██╔╝  ██║     ██║   ██║██║  ██║██╔══╝', '██║ ╚═╝ ██║╚██████╔╝██║ ╚████║███████╗   ██║   ╚██████╗╚██████╔╝██████╔╝███████╗', '╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝   ╚═╝    ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝']
LOGO_SMALL = [' __  __  ___  _  _ _____   _____ ___  ___  ___', '|  \\/  |/ _ \\| \\| | __\\ \\ / / __/ _ \\|   \\| __|', '| |\\/| | (_) | .` | _| \\ V / (_| (_) | |) | _|', '|_|  |_|\\___/|_|\\_|___| |_| \\___\\___/|___/|___|']

from rich.console import Console
from rich.markdown import Markdown
from rich.panel import Panel
from rich.table import Table
from rich.text import Text

console = Console(highlight=False)

ACCENT = "#22c55e"   # зелёный «деньги»
GOLD = "#4ade80"   # светло-зелёный (всё в зелёном стиле)
DIM = "#6b8f71"    # приглушённый зелёный

COMMANDS = {
    "/tiktok": "TikTok: тренды, идеи, сценарии, видео, заработок",
    "/site": "сайты: лендинг, портфолио, выложить в интернет",
    "/video": "видео: ролик с озвучкой, обложка, сценарий",
    "/train": "тренировка: /train 10, /train 0 — бесконечно",
    "/menu": "главное меню (или Ctrl+C)",
    "/new": "новый диалог",
    "/model": "выбрать модель (умнее / дешевле)",
    "/safe": "вкл/выкл подтверждение опасных действий",
    "/mem": "что Moneycode помнит о тебе",
    "/lessons": "уроки из опыта",
    "/clear": "очистить экран",
    "/help": "все команды",
    "/exit": "выход",
}

MODELS = {
    "claude-opus-5-5": "Moneycode Max — самый умный (по умолчанию)",
    "claude-sonnet-5-5": "Moneycode Pro — быстрее и в 2 раза дешевле",
    "claude-haiku-5-5": "Moneycode Lite — самый дешёвый, для простых задач",
}

TIKTOK_MENU = [
    ("Найти тренды в моей нише", "Найди через web_search, что сейчас в тренде в TikTok в моей нише (звуки, форматы, темы). Дай топ-10 с объяснением, почему заходит."),
    ("10 идей для видео", "Придумай 10 идей коротких видео для TikTok в моей нише. Для каждой: хук на первые 2 секунды, суть, длительность, формат."),
    ("Сценарий видео", "Напиши сценарий для TikTok-видео по моей лучшей идее: хук, раскадровка по секундам, текст на экране, озвучка, призыв в конце, подпись и хэштеги."),
    ("Сделать видео (make_video)", "Сделай готовое вертикальное видео для TikTok через make_video: придумай тему в моей нише, 5–7 слайдов с коротким текстом, сохрани на рабочий стол и скажи путь."),
    ("Контент-план на неделю", "Составь контент-план TikTok на 7 дней: тема, формат, время публикации, хук. Сохрани файлом tiktok_plan.csv на рабочий стол (utf-8-sig, разделитель ;)."),
    ("Разбор моего профиля", "Открой мой профиль TikTok в браузере (если не знаешь ник — спроси), прочитай статистику видео и скажи, что заходит, что нет и что менять."),
    ("План заработка", "Составь мне пошаговый план заработка на TikTok с учётом моего возраста, страны и ниши. Проверь через web_search актуальные условия монетизации."),
    ("Опубликовать видео", "Помоги опубликовать видео в TikTok через браузер: спроси путь к файлу и подпись, загрузи через browser upload, перед публикацией покажи мне всё и спроси подтверждение."),
]

SITE_MENU = [
    ("Лендинг для бизнеса", "Сделай красивый современный лендинг (по базе знаний: hero, преимущества, шаги, цены, FAQ, контакты, адаптив, анимации) для бизнеса, который я назову. Если не назвал — спроси, какой бизнес и контакты. Папка на рабочем столе. Открой, проверь скриншотом, поправь."),
    ("Сайт-портфолио", "Сделай мне сайт-портфолио: обо мне, навыки, работы, контакты. Спроси, чем я занимаюсь и какие контакты указать. Тёмный современный дизайн, анимации при скролле. Проверь скриншотом."),
    ("Интернет-магазин (витрина)", "Сделай сайт-витрину товаров: карточки с фото, ценой и кнопкой «Заказать в Telegram». Спроси, какие товары и ник в Telegram. Проверь скриншотом."),
    ("Улучшить мой сайт", "Спроси путь к папке моего сайта, прочитай файлы, сделай скриншот и улучши дизайн по базе знаний (отступы, шрифты, адаптив, анимации). Перед перезаписью файлов покажи, что поменяешь."),
    ("Выложить сайт в интернет", "Помоги выложить мой сайт в интернет бесплатно через Netlify Drop (по базе знаний). Спроси путь к папке. Логинюсь я сам."),
    ("Заработать на сайтах", "Составь пошаговый план, как мне заработать на создании сайтов: портфолио, где искать клиентов, что писать, цены. Проверь цены через web_search."),
]

VIDEO_MENU = [
    ("Ролик с озвучкой", "Сделай короткое видео для TikTok/Reels/Shorts на тему из моей ниши (если не знаешь — спроси): хук, 5–7 слайдов, озвучка voiceover живым языком. Через make_video на рабочий стол."),
    ("Топ-5 ролик", "Сделай видео в формате «Топ-5 …» по моей нише: слайд-хук, 5 слайдов, финальный призыв. С озвучкой. Через make_video."),
    ("Обложка / превью", "Сделай обложку через make_image. Спроси: для TikTok или превью YouTube, и какой текст. Сделай 3 варианта разными стилями."),
    ("Видео из моих фото", "Спроси папку с моими фото, сделай из них вертикальное видео с подписями и музыкой (если есть mp3 — спроси путь) через make_video."),
    ("Сценарий для YouTube", "Напиши сценарий длинного видео для YouTube на тему, которую я назову: хук, блоки с таймкодами, призыв. И 5 вариантов названия + текст для превью."),
    ("Серия роликов", "Сделай серию из 3 роликов на одну тему (часть 1, 2, 3) через make_video с озвучкой, файлы на рабочий стол."),
]


def logo_only() -> None:
    lines = LOGO_BIG if console.width >= 84 else LOGO_SMALL
    w = max(len(x) for x in lines)
    lines = [x.ljust(w) for x in lines]  # одинаковая ширина — логотип не «едет» при центрировании
    n = len(lines)
    for i, line in enumerate(lines):
        # градиент: тёмно-зелёный сверху → светло-зелёный снизу
        c = ["#15803d", "#16a34a", "#22c55e", "#22c55e", "#4ade80", "#86efac"][min(i, 5)] if n > 4 else ACCENT
        pad = " " * max(0, (console.width - w) // 2)
        console.print(Text(pad + line, style=f"bold {c}"), overflow="crop", no_wrap=True)
    console.print(Text("твой ИИ-агент для компа, Инсты и TikTok", style=DIM), justify="center")
    console.print()


def logo() -> None:
    logo_only()
    t = Table.grid(padding=(0, 2))
    t.add_column(style=f"bold {ACCENT}", justify="right")
    t.add_column(style=DIM)
    for cmd in ("/tiktok", "/site", "/video", "/train", "/help"):
        t.add_row(cmd, COMMANDS[cmd])
    console.print(t, justify="center")
    console.print()


def help_table() -> None:
    t = Table(show_header=False, box=None, padding=(0, 2))
    t.add_column(style=f"bold {ACCENT}")
    t.add_column()
    for k, v in COMMANDS.items():
        t.add_row(k, v)
    console.print(Panel(t, title="команды", border_style=DIM, title_align="left"))


def agent_says(text: str) -> None:
    console.print(Panel(Markdown(text), border_style=ACCENT, title="[bold]Moneycode[/]", title_align="left",
                        padding=(0, 1)))


def tool_call(name: str, args: str) -> None:
    console.print(Text(f"  ⚙ {name} ", style=f"bold {GOLD}") + Text(args[:140], style=DIM))


def info(msg: str) -> None:
    console.print(Text(msg, style=DIM))


def error(msg: str) -> None:
    console.print(Text(f"✖ {msg}", style="bold red"))


def choose(title: str, items: list) -> int | None:
    """Нумерованное меню. Возвращает индекс или None."""
    t = Table(show_header=False, box=None, padding=(0, 2))
    t.add_column(style=f"bold {ACCENT}", justify="right")
    t.add_column()
    for i, it in enumerate(items, 1):
        t.add_row(str(i), it)
    console.print(Panel(t, title=title, border_style=ACCENT, title_align="left"))
    ans = console.input(f"[{ACCENT}]номер (Enter — отмена): [/]").strip()
    if ans.isdigit() and 1 <= int(ans) <= len(items):
        return int(ans) - 1
    return None


PICK_STYLE = None


def pick(title: str, options: list, default=None):
    """Меню со стрелками ↑↓ и Enter. options = [(значение, текст)]. Esc/Ctrl+C — None."""
    global PICK_STYLE
    try:
        from prompt_toolkit.shortcuts import choice
        from prompt_toolkit.styles import Style
        PICK_STYLE = PICK_STYLE or Style.from_dict({
            "frame.border": ACCENT, "selected-option": f"bold {ACCENT}", "number": DIM,
            "bottom-toolbar": "noreverse #6b8f71",
        })
        return choice(message=[("bold " + ACCENT, title)], options=options, default=default,
                      style=PICK_STYLE, symbol="❯", show_frame=True,
                      bottom_toolbar=" ↑↓ выбрать · Enter ок · Ctrl+C назад")
    except KeyboardInterrupt:
        return None
    except Exception:
        i = choose(title, [str(t) for _, t in options])  # запасной вариант — по номеру
        return None if i is None else options[i][0]


class Input:
    """Поле ввода как в OpenCode: подсказки команд при вводе «/», история, статус снизу."""

    def __init__(self, history_path, status_fn):
        self.status_fn = status_fn
        self.session = None
        try:
            from prompt_toolkit import PromptSession
            from prompt_toolkit.completion import Completer, Completion
            from prompt_toolkit.history import FileHistory
            from prompt_toolkit.styles import Style

            class SlashCompleter(Completer):
                def get_completions(self, document, complete_event):
                    word = document.text_before_cursor
                    if word.startswith("/") and " " not in word:
                        for cmd, desc in COMMANDS.items():
                            if cmd.startswith(word):
                                yield Completion(cmd, start_position=-len(word), display_meta=desc)

            self.session = PromptSession(
                history=FileHistory(str(history_path)),
                completer=SlashCompleter(),
                complete_while_typing=True,
                bottom_toolbar=lambda: [("class:bar", " " + self.status_fn() + " ")],
                style=Style.from_dict({
                    "bar": f"bg:#14532d #ffffff",
                    "bottom-toolbar": "noreverse",
                    "prompt": f"bold {ACCENT}",
                    "completion-menu.completion": "bg:#1f2937 #e5e7eb",
                    "completion-menu.completion.current": f"bg:{ACCENT} #000000",
                    "completion-menu.meta.completion": "bg:#111827 #9ca3af",
                    "completion-menu.meta.completion.current": f"bg:{ACCENT} #000000",
                }),
            )
        except Exception:
            self.session = None  # нет полноценной консоли — простой ввод

    def read(self) -> str:
        if self.session is not None:
            try:
                return self.session.prompt([("class:prompt", "❯ ")])
            except (KeyboardInterrupt, EOFError):
                raise
            except Exception:
                self.session = None
        console.print(Text(self.status_fn(), style=DIM))
        return console.input(f"[bold {ACCENT}]❯ [/]")
