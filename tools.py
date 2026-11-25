"""Инструменты Moneycode: экран, мышь/клава, терминал, файлы, браузер, память."""
import base64
import io
import json
import os
import subprocess
import sys
from pathlib import Path

# В .exe данные лежат рядом с exe, а вшитые файлы — во временной папке PyInstaller
FROZEN = getattr(sys, "frozen", False)
BASE = Path(sys.executable).parent if FROZEN else Path(__file__).parent
BUNDLE = Path(getattr(sys, "_MEIPASS", BASE))
MEMORY_FILE = BASE / "memory.json"
LESSONS_FILE = BASE / "lessons.md"
SAFE_MODE = os.getenv("MONEYCODE_SAFE", "1") != "0"  # 1 = спрашивать перед опасными действиями


def confirm(action: str) -> bool:
    if not SAFE_MODE:
        return True
    ans = input(f"\n⚠️  Moneycode хочет: {action}\n   Разрешить? [y/N] ").strip().lower()
    return ans in ("y", "yes", "д", "да")


def text(s: str) -> list:
    return [{"type": "text", "text": str(s)[:20000]}]


def image_block(png_bytes: bytes) -> dict:
    return {"type": "image", "source": {"type": "base64", "media_type": "image/png",
                                         "data": base64.b64encode(png_bytes).decode()}}


# ---------- Экран, мышь, клавиатура ----------
_scale = 1.0  # во сколько раз скриншот уменьшен относительно реального экрана


def screenshot(_=None):
    global _scale
    import pyautogui
    img = pyautogui.screenshot()
    max_w = 1366
    _scale = img.width / max_w if img.width > max_w else 1.0
    if _scale != 1.0:
        img = img.resize((max_w, int(img.height / _scale)))
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return [image_block(buf.getvalue()),
            {"type": "text", "text": f"Скриншот {img.width}x{img.height}. Координаты давай в этом масштабе."}]


def mouse(inp):
    import pyautogui
    x, y = int(inp["x"] * _scale), int(inp["y"] * _scale)
    act = inp.get("action", "click")
    if act == "move":
        pyautogui.moveTo(x, y, duration=0.2)
    elif act == "double_click":
        pyautogui.doubleClick(x, y)
    elif act == "right_click":
        pyautogui.rightClick(x, y)
    elif act == "scroll":
        pyautogui.moveTo(x, y)
        pyautogui.scroll(int(inp.get("amount", -5)) * 100)
    else:
        pyautogui.click(x, y)
    return text(f"ok: {act} ({inp['x']},{inp['y']})")


def keyboard(inp):
    import pyautogui
    if inp.get("text"):
        try:  # pyperclip нужен для кириллицы
            import pyperclip
            pyperclip.copy(inp["text"])
            pyautogui.hotkey("command" if os.name == "posix" and os.uname().sysname == "Darwin" else "ctrl", "v")
        except Exception:
            pyautogui.write(inp["text"], interval=0.02)
    if inp.get("keys"):
        pyautogui.hotkey(*inp["keys"])
    return text("ok")


# ---------- Терминал и файлы ----------
def run_command(inp):
    cmd = inp["command"]
    if not confirm(f"выполнить команду: {cmd}"):
        return text("Пользователь запретил.")
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=int(inp.get("timeout", 120)))
        return text(f"exit={r.returncode}\n{r.stdout}\n{r.stderr}")
    except subprocess.TimeoutExpired:
        return text("Таймаут")


def read_file(inp):
    try:
        return text(Path(inp["path"]).expanduser().read_text(encoding="utf-8", errors="replace"))
    except Exception as e:
        return text(f"Ошибка: {e}")


def write_file(inp):
    p = Path(inp["path"]).expanduser()
    if not confirm(f"записать файл {p} ({len(inp['content'])} символов)"):
        return text("Пользователь запретил.")
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(inp["content"], encoding="utf-8")
    return text(f"Сохранено: {p}")


# ---------- Браузер (Инста, сайты) ----------
_pw = _ctx = _page = None


def _browser():
    global _pw, _ctx, _page
    if _page is None or _page.is_closed():
        from playwright.sync_api import sync_playwright
        _pw = _pw or sync_playwright().start()
        # Отдельный профиль: залогинься в Инсту один раз — дальше сессия сохранится
        if _ctx is None:
            # Edge есть на любом Windows, потом Chrome, потом встроенный Chromium Playwright
            for ch in ("msedge", "chrome", None):
                try:
                    _ctx = _pw.chromium.launch_persistent_context(
                        str(BASE / "browser_profile"), headless=False, channel=ch,
                        viewport={"width": 1280, "height": 800})
                    break
                except Exception:
                    if ch is None:
                        raise
        _page = _ctx.pages[0] if _ctx.pages else _ctx.new_page()
    return _page


def browser(inp):
    act = inp["action"]
    try:
        page = _browser()
        if act == "open":
            page.goto(inp["url"], wait_until="domcontentloaded")
            page.wait_for_timeout(1500)
            return text(f"Открыто: {page.url}")
        if act == "click":
            if inp.get("selector"):
                page.click(inp["selector"], timeout=8000)
            elif inp.get("text"):
                page.get_by_text(inp["text"], exact=False).first.click(timeout=8000)
            else:
                page.mouse.click(inp["x"], inp["y"])
            page.wait_for_timeout(1000)
            return text("ok")
        if act == "type":
            if inp.get("press_enter") and not confirm(f"отправить в браузере текст: «{inp['text']}»"):
                return text("Пользователь запретил отправку.")
            if inp.get("selector"):
                page.click(inp["selector"], timeout=8000)
            page.keyboard.type(inp["text"], delay=30)
            if inp.get("press_enter"):
                page.keyboard.press("Enter")
            page.wait_for_timeout(800)
            return text("ok")
        if act == "read":
            return text(f"URL: {page.url}\n\n" + page.inner_text("body")[:15000])
        if act == "screenshot":
            return [image_block(page.screenshot()), {"type": "text", "text": "Скрин браузера 1280x800."}]
        if act == "scroll":
            page.mouse.wheel(0, int(inp.get("amount", 800)))
            page.wait_for_timeout(700)
            return text("ok")
        return text(f"Неизвестное действие {act}")
    except Exception as e:
        return text(f"Ошибка браузера: {e}")


# ---------- Память («обучение») ----------
def load_memory() -> list:
    try:
        return json.loads(MEMORY_FILE.read_text(encoding="utf-8"))
    except Exception:
        return []


def memory(inp):
    mem = load_memory()
    if inp["action"] == "remember":
        mem.append(inp["fact"])
    elif inp["action"] == "forget":
        i = int(inp["index"])
        if 0 <= i < len(mem):
            mem.pop(i)
    MEMORY_FILE.write_text(json.dumps(mem, ensure_ascii=False, indent=2), encoding="utf-8")
    return text("Память:\n" + "\n".join(f"{i}. {m}" for i, m in enumerate(mem)))


# ---------- Мелочи: ожидание, буфер, запуск программ ----------
def wait(inp):
    import time
    time.sleep(min(float(inp.get("seconds", 2)), 60))
    return text("ok")


def clipboard(inp):
    import pyperclip
    if inp.get("text") is not None:
        pyperclip.copy(inp["text"])
        return text("Скопировано в буфер")
    return text(pyperclip.paste() or "(буфер пуст)")


def open_app(inp):
    """Открыть программу через поиск Пуска (работает для любых установленных программ)."""
    import time
    import pyautogui
    pyautogui.press("win")
    time.sleep(0.8)
    try:
        import pyperclip
        pyperclip.copy(inp["name"])
        pyautogui.hotkey("ctrl", "v")
    except Exception:
        pyautogui.write(inp["name"], interval=0.03)
    time.sleep(1.2)
    pyautogui.press("enter")
    time.sleep(2)
    return text(f"Запускаю «{inp['name']}». Сделай screenshot, чтобы проверить.")


# ---------- Самообучение: уроки из опыта ----------
def load_lessons() -> str:
    try:
        return LESSONS_FILE.read_text(encoding="utf-8")[-12000:]
    except Exception:
        return ""


def learn(inp):
    with LESSONS_FILE.open("a", encoding="utf-8") as f:
        f.write(f"- [{inp.get('topic', 'общее')}] {inp['lesson']}\n")
    return text("Урок сохранён.")


def load_knowledge() -> str:
    for p in (BUNDLE / "knowledge.md", BASE / "knowledge.md"):
        if p.exists():
            return p.read_text(encoding="utf-8")
    return ""


HANDLERS = {"wait": wait, "clipboard": clipboard, "open_app": open_app, "learn": learn, "screenshot": screenshot, "mouse": mouse, "keyboard": keyboard, "run_command": run_command,
            "read_file": read_file, "write_file": write_file, "browser": browser, "memory": memory}

S = lambda props, req: {"type": "object", "properties": props, "required": req}  # noqa: E731

TOOLS = [
    {"name": "open_app", "description": "Открыть любую программу по названию через Пуск (Telegram, Блокнот, Chrome, Word...).",
     "input_schema": S({"name": {"type": "string"}}, ["name"])},
    {"name": "wait", "description": "Подождать N секунд (до 60), например пока грузится программа.",
     "input_schema": S({"seconds": {"type": "number"}}, [])},
    {"name": "clipboard", "description": "Буфер обмена: без text — прочитать, с text — скопировать.",
     "input_schema": S({"text": {"type": "string"}}, [])},
    {"name": "learn", "description": (
        "Записать урок из опыта, чтобы в следующий раз сделать лучше: что сработало, что нет, "
        "какой селектор/кнопка/команда правильная. Вызывай после задачи, если узнал что-то полезное."),
     "input_schema": S({"topic": {"type": "string", "description": "instagram / windows / код / ..."},
                        "lesson": {"type": "string"}}, ["lesson"])},
    {"name": "screenshot", "description": "Скриншот всего экрана компьютера. Делай перед кликами по экрану.",
     "input_schema": S({}, [])},
    {"name": "mouse", "description": "Мышь: click, double_click, right_click, move, scroll по координатам последнего скриншота.",
     "input_schema": S({"action": {"type": "string", "enum": ["click", "double_click", "right_click", "move", "scroll"]},
                        "x": {"type": "integer"}, "y": {"type": "integer"},
                        "amount": {"type": "integer", "description": "для scroll: минус = вниз"}}, ["action", "x", "y"])},
    {"name": "keyboard", "description": "Напечатать текст и/или нажать сочетание клавиш, напр. keys=['ctrl','s'].",
     "input_schema": S({"text": {"type": "string"}, "keys": {"type": "array", "items": {"type": "string"}}}, [])},
    {"name": "run_command", "description": "Выполнить команду в терминале (cmd/PowerShell на Windows, bash на Linux/Mac).",
     "input_schema": S({"command": {"type": "string"}, "timeout": {"type": "integer"}}, ["command"])},
    {"name": "read_file", "description": "Прочитать текстовый файл.", "input_schema": S({"path": {"type": "string"}}, ["path"])},
    {"name": "write_file", "description": "Создать/перезаписать файл.",
     "input_schema": S({"path": {"type": "string"}, "content": {"type": "string"}}, ["path", "content"])},
    {"name": "browser", "description": (
        "Свой браузер Moneycode (для Instagram и сайтов). action: open(url), click(selector|text|x,y), "
        "type(text, selector?, press_enter?), read (текст страницы), screenshot, scroll(amount). "
        "Instagram: https://www.instagram.com/direct/inbox/ — директ."),
     "input_schema": S({"action": {"type": "string", "enum": ["open", "click", "type", "read", "screenshot", "scroll"]},
                        "url": {"type": "string"}, "selector": {"type": "string"}, "text": {"type": "string"},
                        "x": {"type": "integer"}, "y": {"type": "integer"}, "amount": {"type": "integer"},
                        "press_enter": {"type": "boolean"}}, ["action"])},
    {"name": "memory", "description": "Долгая память. remember(fact) — запомнить о пользователе/задачах навсегда; forget(index).",
     "input_schema": S({"action": {"type": "string", "enum": ["remember", "forget"]},
                        "fact": {"type": "string"}, "index": {"type": "integer"}}, ["action"])},
]
