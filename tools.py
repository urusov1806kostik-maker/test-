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
        if act == "upload":
            # Загрузка файла в сайт (видео в TikTok, фото в Инсту): ищем input[type=file]
            path = str(Path(inp["path"]).expanduser())
            if not Path(path).exists():
                return text(f"Файл не найден: {path}")
            page.set_input_files(inp.get("selector") or "input[type=file]", path, timeout=15000)
            page.wait_for_timeout(3000)
            return text(f"Файл загружен: {path}. Сделай read/screenshot, чтобы проверить.")
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


# ---------- Видео для TikTok / Reels / Shorts ----------
FONTS = ["C:/Windows/Fonts/arialbd.ttf", "C:/Windows/Fonts/segoeuib.ttf", "C:/Windows/Fonts/arial.ttf",
         "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "/Library/Fonts/Arial Bold.ttf"]
PALETTES = [("#0f172a", "#7c3aed"), ("#022c22", "#16a34a"), ("#1c1917", "#ea580c"),
            ("#082f49", "#0ea5e9"), ("#3b0764", "#db2777"), ("#111827", "#ca8a04")]


def _font(size):
    from PIL import ImageFont
    for f in FONTS:
        if Path(f).exists():
            return ImageFont.truetype(f, size)
    return ImageFont.load_default(size=size)


def _slide(txt, image, idx, W=1080, H=1920, title_size=None):
    from PIL import Image, ImageDraw
    if image and Path(image).expanduser().exists():
        img = Image.open(Path(image).expanduser()).convert("RGB")
        k = max(W / img.width, H / img.height)
        img = img.resize((int(img.width * k) + 1, int(img.height * k) + 1))
        left, top = (img.width - W) // 2, (img.height - H) // 2
        img = img.crop((left, top, left + W, top + H))
        img = Image.alpha_composite(img.convert("RGBA"), Image.new("RGBA", (W, H), (0, 0, 0, 110))).convert("RGB")
    else:  # градиентный фон
        a, b = PALETTES[idx % len(PALETTES)]
        ca, cb = Image.new("RGB", (1, 1), a).getpixel((0, 0)), Image.new("RGB", (1, 1), b).getpixel((0, 0))
        img = Image.new("RGB", (W, H))
        d = ImageDraw.Draw(img)
        for y in range(H):
            t = y / H
            d.line([(0, y), (W, y)], fill=tuple(int(ca[i] + (cb[i] - ca[i]) * t) for i in range(3)))
    d = ImageDraw.Draw(img)
    k = min(W, H) / 1080
    size = title_size or int((96 if len(txt) < 40 else 78 if len(txt) < 90 else 62) * k)
    font = _font(size)
    lines, cur = [], ""
    for word in txt.split():  # перенос строк по ширине
        test = (cur + " " + word).strip()
        if d.textlength(test, font=font) <= W - int(140 * k):
            cur = test
        else:
            lines.append(cur)
            cur = word
    lines.append(cur)
    lh = int(size * 1.25)
    y = (H - lh * len(lines)) // 2
    for line in lines:
        w = d.textlength(line, font=font)
        d.text(((W - w) / 2, y), line, font=font, fill="white", stroke_width=max(3, size // 20), stroke_fill="black")
        y += lh
    return img


def tts(txt: str, wav_path: Path, rate: float = 1) -> str | None:
    """Озвучка голосом Windows (System.Speech, офлайн). Русский голос есть, если стоит русский языковой пакет."""
    if os.name != "nt":
        return "озвучка работает только на Windows"
    tfile = wav_path.with_suffix(".txt")
    tfile.write_text(txt, encoding="utf-8")
    r_int = max(-10, min(10, int((rate - 1) * 10)))
    ps = (
        "Add-Type -AssemblyName System.Speech;"
        "$s=New-Object System.Speech.Synthesis.SpeechSynthesizer;"
        "$v=$s.GetInstalledVoices()|?{$_.VoiceInfo.Culture.Name -like 'ru*'}|select -First 1;"
        "if($v){$s.SelectVoice($v.VoiceInfo.Name)};"
        f"$s.Rate={r_int};"
        f"$s.SetOutputToWaveFile('{wav_path}');"
        f"$s.Speak([IO.File]::ReadAllText('{tfile}',[Text.Encoding]::UTF8));$s.Dispose()"
    )
    r = subprocess.run(["powershell", "-NoProfile", "-Command", ps], capture_output=True, text=True)
    if r.returncode != 0 or not wav_path.exists():
        return (r.stderr or "нет файла")[-500:]
    return None


SIZES = {"tiktok": (1080, 1920), "youtube": (1280, 720), "square": (1080, 1080), "story": (1080, 1920)}


def make_image(inp):
    """Обложка/картинка с крупным текстом: превью YouTube, обложка TikTok, пост, сторис."""
    W, H = SIZES.get(inp.get("format", "tiktok"), (1080, 1920))
    out = Path(inp.get("output") or (Path.home() / "Desktop" / "moneycode_cover.png")).expanduser()
    out.parent.mkdir(parents=True, exist_ok=True)
    _slide(inp["text"], inp.get("image"), int(inp.get("style", 0)), W, H).save(out)
    return text(f"Картинка готова: {out} ({W}x{H})")


def make_video(inp):
    """Вертикальное видео 1080x1920 из слайдов с текстом (+ картинки, + музыка)."""
    import tempfile
    import imageio_ffmpeg
    slides = inp["slides"]
    if not slides:
        return text("Нет слайдов")
    out = Path(inp.get("output") or (Path.home() / "Desktop" / "moneycode_video.mp4")).expanduser()
    out.parent.mkdir(parents=True, exist_ok=True)
    tmp = Path(tempfile.mkdtemp(prefix="moneycode_"))
    voice_wav = None
    if inp.get("voiceover"):
        voice_wav = tmp / "voice.wav"
        err = tts(inp["voiceover"], voice_wav, inp.get("voice_rate", 1))
        if err:
            return text(f"Озвучка не получилась: {err}. Сделай без voiceover или проверь голоса Windows.")
        import wave
        with wave.open(str(voice_wav)) as w:
            dur = w.getnframes() / w.getframerate() + 0.6
        weights = [max(len(sl.get("text", "")), 8) for sl in slides]
        slides = [dict(sl, seconds=dur * wt / sum(weights)) for sl, wt in zip(slides, weights)]
    ff = imageio_ffmpeg.get_ffmpeg_exe()
    cmd = [ff, "-y", "-loglevel", "error"]
    for i, sl in enumerate(slides):  # каждый слайд — отдельный вход точной длины
        p = tmp / f"s{i:03d}.png"
        _slide(sl.get("text", ""), sl.get("image"), i).save(p)
        cmd += ["-loop", "1", "-framerate", "30", "-t", f"{float(sl.get('seconds', 3)):.3f}", "-i", str(p)]
    n = len(slides)
    vf = "".join(f"[{i}:v]" for i in range(n)) + f"concat=n={n}:v=1:a=0,format=yuv420p[v]"
    music = inp.get("music")
    music = str(Path(music).expanduser()) if music and Path(music).expanduser().exists() else None
    amap = []
    if voice_wav and music:
        cmd += ["-i", str(voice_wav), "-stream_loop", "-1", "-i", music]
        vf += f";[{n}:a]apad[vo];[{n + 1}:a]volume=0.15[m];[vo][m]amix=inputs=2:duration=first:normalize=0[a]"
        amap = ["-map", "[a]"]
    elif voice_wav:
        cmd += ["-i", str(voice_wav)]
        vf += f";[{n}:a]apad[a]"  # тишина в конце, чтобы видео не обрезалось по голосу
        amap = ["-map", "[a]"]
    elif music:
        cmd += ["-stream_loop", "-1", "-i", music]
        amap = ["-map", f"{n}:a"]
    cmd += ["-filter_complex", vf, "-map", "[v]"] + amap
    if amap:
        cmd += ["-c:a", "aac", "-shortest"]
    cmd += ["-c:v", "libx264", "-preset", "veryfast", "-r", "30", "-movflags", "+faststart", str(out)]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        return text(f"Ошибка ffmpeg: {r.stderr[-1500:]}")
    total = sum(float(s.get("seconds", 3)) for s in slides)
    return text(f"Видео готово: {out} ({len(slides)} слайдов, ~{total:.0f} сек, 1080x1920)")


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


HANDLERS = {"make_image": make_image, "make_video": make_video, "wait": wait, "clipboard": clipboard, "open_app": open_app, "learn": learn, "screenshot": screenshot, "mouse": mouse, "keyboard": keyboard, "run_command": run_command,
            "read_file": read_file, "write_file": write_file, "browser": browser, "memory": memory}

S = lambda props, req: {"type": "object", "properties": props, "required": req}  # noqa: E731

TOOLS = [
    {"name": "make_video", "description": (
        "Сделать вертикальное видео 1080x1920 (TikTok/Reels/Shorts) из слайдов: крупный текст на градиенте "
        "или поверх картинки, опционально музыка (mp3). Текст на слайде — коротко, до ~12 слов."),
     "input_schema": S({"slides": {"type": "array", "items": {"type": "object", "properties": {
                            "text": {"type": "string"}, "image": {"type": "string", "description": "путь к картинке"},
                            "seconds": {"type": "number"}}, "required": ["text"]}},
                        "output": {"type": "string", "description": "путь .mp4, по умолчанию рабочий стол"},
                        "music": {"type": "string", "description": "путь к mp3/m4a (фоном, тихо)"},
                        "voiceover": {"type": "string", "description": "текст озвучки голосом Windows; длительность слайдов подстроится"},
                        "voice_rate": {"type": "number", "description": "скорость речи 0.5–2, по умолчанию 1"}},
                       ["slides"])},
    {"name": "make_image", "description": "Картинка с крупным текстом: обложка TikTok, превью YouTube, пост, сторис.",
     "input_schema": S({"text": {"type": "string"}, "image": {"type": "string", "description": "фон (путь), иначе градиент"},
                        "format": {"type": "string", "enum": ["tiktok", "youtube", "square", "story"]},
                        "style": {"type": "integer", "description": "номер цветовой схемы 0–5"},
                        "output": {"type": "string"}}, ["text"])},
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
        "Свой браузер Moneycode (для Instagram, TikTok и сайтов). action: open(url), click(selector|text|x,y), "
        "type(text, selector?, press_enter?), read (текст страницы), screenshot, scroll(amount), "
        "upload(path, selector?) — загрузить файл в форму сайта. "
        "Instagram: https://www.instagram.com/direct/inbox/ — директ."),
     "input_schema": S({"action": {"type": "string", "enum": ["open", "click", "type", "read", "screenshot", "scroll", "upload"]},
                        "url": {"type": "string"}, "path": {"type": "string"}, "selector": {"type": "string"}, "text": {"type": "string"},
                        "x": {"type": "integer"}, "y": {"type": "integer"}, "amount": {"type": "integer"},
                        "press_enter": {"type": "boolean"}}, ["action"])},
    {"name": "memory", "description": "Долгая память. remember(fact) — запомнить о пользователе/задачах навсегда; forget(index).",
     "input_schema": S({"action": {"type": "string", "enum": ["remember", "forget"]},
                        "fact": {"type": "string"}, "index": {"type": "integer"}}, ["action"])},
]
