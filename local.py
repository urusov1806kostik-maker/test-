"""Свой мозг Moneycode: открытая нейросеть прямо на компе через Ollama. Без ключей и оплаты."""
import json
import os
import re
import shutil
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

HOST = os.getenv("OLLAMA_HOST", "http://127.0.0.1:11434")
if not HOST.startswith("http"):
    HOST = "http://" + HOST
# к локальному движку — напрямую, мимо прокси
_local = urllib.request.build_opener(urllib.request.ProxyHandler({}))

LOCAL_MODELS = {
    "qwen3:4b": "Moneycode Home Lite — для слабых компов (8 ГБ памяти, ~3 ГБ места)",
    "qwen3:8b": "Moneycode Home — оптимально (16 ГБ памяти, ~5 ГБ места)",
    "qwen3:14b": "Moneycode Home Max — умнее (32 ГБ памяти или видеокарта, ~9 ГБ места)",
}
DEFAULT_LOCAL = "qwen3:8b"
NUM_CTX = 16384


def _call(path, data=None, timeout=900):
    body = json.dumps(data).encode() if data is not None else None
    req = urllib.request.Request(HOST + path, data=body, headers={"Content-Type": "application/json"})
    return _local.open(req, timeout=timeout)


def running() -> bool:
    try:
        with _call("/api/tags", timeout=3) as r:
            return r.status == 200
    except Exception:
        return False


def models() -> list:
    try:
        with _call("/api/tags", timeout=5) as r:
            return [m["name"] for m in json.loads(r.read()).get("models", [])]
    except Exception:
        return []


def _exe():
    exe = shutil.which("ollama")
    if exe:
        return exe
    for p in (Path(os.getenv("LOCALAPPDATA", "")) / "Programs" / "Ollama" / "ollama.exe",
              Path("C:/Program Files/Ollama/ollama.exe")):
        if p.exists():
            return str(p)
    return None


def ensure_ready(model: str, confirm, info, progress) -> str | None:
    """Ставит движок и скачивает модель, если нужно. Возвращает текст ошибки или None."""
    if not running():
        exe = _exe()
        if not exe:
            if os.name != "nt":
                return "Установи Ollama: https://ollama.com/download"
            if not confirm("установить движок для своего мозга (Ollama, бесплатно, ~1 ГБ)"):
                return "Без движка свой мозг не работает. Можно включить облачный в Настройках."
            info("Ставлю движок… (пару минут)")
            subprocess.run(["winget", "install", "-e", "--id", "Ollama.Ollama",
                            "--accept-source-agreements", "--accept-package-agreements"])
            exe = _exe()
            if not exe:
                return "Не получилось поставить автоматически. Скачай вручную: https://ollama.com/download и запусти Moneycode снова."
        flags = 0x08000000 if os.name == "nt" else 0  # CREATE_NO_WINDOW
        subprocess.Popen([exe, "serve"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, creationflags=flags)
        for _ in range(30):
            if running():
                break
            time.sleep(1)
        else:
            return "Движок не запустился. Перезагрузи комп и попробуй снова."
    have = models()
    if model not in have and f"{model}:latest" not in have:
        info(f"Качаю мозг {model} — один раз, несколько ГБ. Можно свернуть окно.")
        try:
            with _call("/api/pull", {"model": model, "stream": True}, timeout=None) as r:
                for line in r:
                    if line.strip():
                        j = json.loads(line)
                        if j.get("error"):
                            return f"Ошибка загрузки: {j['error']}"
                        progress(j)
        except Exception as e:
            return f"Не скачалось: {e}. Проверь интернет и место на диске."
    return None


def chat(model: str, messages: list, tools: list) -> dict:
    """Один шаг диалога. Возвращает сообщение ассистента (content, tool_calls)."""
    data = {"model": model, "messages": messages, "tools": tools, "stream": False, "think": False,
            "options": {"num_ctx": NUM_CTX, "temperature": 0.6}}
    try:
        with _call("/api/chat", data) as r:
            return json.loads(r.read())["message"]
    except urllib.error.HTTPError as e:
        err = e.read().decode(errors="replace")
        if "think" in err:  # модель без режима «думать» — повторяем без параметра
            data.pop("think")
            with _call("/api/chat", data) as r:
                return json.loads(r.read())["message"]
        raise RuntimeError(f"движок ответил ошибкой: {err[:300]}")


def to_ollama_tools(tools: list, skip=()) -> list:
    return [{"type": "function", "function": {"name": t["name"], "description": t["description"],
                                              "parameters": t["input_schema"]}}
            for t in tools if t["name"] not in skip]


def strip_think(text: str) -> str:
    return re.sub(r"<think>.*?</think>", "", text or "", flags=re.S).strip()


# ---------- Поиск в интернете (без ключей) ----------
def web_search(inp) -> list:
    q = inp["query"]
    try:
        req = urllib.request.Request("https://html.duckduckgo.com/html/?" + urllib.parse.urlencode({"q": q}),
                                     headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"})
        html = urllib.request.urlopen(req, timeout=20).read().decode("utf-8", errors="replace")
        items = re.findall(r'class="result__a"[^>]*href="([^"]+)"[^>]*>(.*?)</a>.*?class="result__snippet"[^>]*>(.*?)</a>',
                           html, re.S)
        clean = lambda s: re.sub(r"<[^>]+>", "", s).replace("&amp;", "&").replace("&quot;", '"').strip()  # noqa: E731
        out = []
        for href, title, snip in items[:8]:
            m = re.search(r"uddg=([^&]+)", href)
            url = urllib.parse.unquote(m.group(1)) if m else href
            out.append(f"- {clean(title)}\n  {url}\n  {clean(snip)}")
        if out:
            return [{"type": "text", "text": f"Результаты по «{q}»:\n" + "\n".join(out)}]
    except Exception:
        pass
    return [{"type": "text", "text": "Поиск не ответил. Открой browser open https://duckduckgo.com/?q="
             + urllib.parse.quote(q) + " и сделай read."}]


# ---------- База знаний по кусочкам (маленькой модели весь текст не влезет) ----------
def split_knowledge(text: str) -> list:
    parts, cur, title = [], [], "Общее"
    for line in text.splitlines():
        if re.match(r"^#{1,3} ", line):
            if cur:
                parts.append((title, "\n".join(cur)))
            title, cur = line.lstrip("# ").strip(), [line]
        else:
            cur.append(line)
    if cur:
        parts.append((title, "\n".join(cur)))
    return [p for p in parts if len(p[1].strip()) > len(p[0]) + 5]


def knowledge_search(sections: list, query: str, top=3) -> str:
    words = [w for w in re.findall(r"\w+", query.lower()) if len(w) > 2]
    scored = []
    for title, body in sections:
        t, b = title.lower(), body.lower()
        score = sum(3 * t.count(w[:5]) + b.count(w[:5]) for w in words)
        if score:
            scored.append((score, body))
    scored.sort(key=lambda x: -x[0])
    found = "\n\n".join(b for _, b in scored[:top])[:7000]
    return found or "Ничего не нашёл. Попробуй другие слова (например: instagram, tiktok, сайт, видео, windows, код)."
