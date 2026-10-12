"""Страницы модулей. Все кнопки вызывают реальные функции."""
import json
import os
import time

from PySide6.QtCore import Qt, QTimer
from PySide6.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton, QListWidget, QListWidgetItem,
                               QLineEdit, QTextEdit, QProgressBar, QGridLayout, QTableWidget, QTableWidgetItem,
                               QHeaderView, QFileDialog, QMessageBox, QSpinBox, QComboBox, QInputDialog, QPlainTextEdit)

from .. import pc, security, steam, sysmon
from .common import run_bg, card, h1
from .core import EchoCore, WaveWidget


def page(title, subtitle=""):
    w = QWidget()
    lay = QVBoxLayout(w); lay.setContentsMargins(28, 24, 28, 24); lay.setSpacing(14)
    lay.addWidget(h1(title))
    if subtitle:
        s = QLabel(subtitle); s.setObjectName("muted"); s.setWordWrap(True); lay.addWidget(s)
    return w, lay


class Dashboard(QWidget):
    def __init__(self, app):
        super().__init__()
        self.app = app
        lay = QVBoxLayout(self); lay.setContentsMargins(28, 20, 28, 20)
        self.core = EchoCore(size=300)
        lay.addWidget(self.core, 3)
        self.state = QLabel("Скажите «Эхо» или нажмите на микрофон"); self.state.setAlignment(Qt.AlignCenter)
        self.state.setStyleSheet("font-size:18px;")
        lay.addWidget(self.state)
        self.heard = QLabel(""); self.heard.setAlignment(Qt.AlignCenter); self.heard.setObjectName("muted"); self.heard.setWordWrap(True)
        lay.addWidget(self.heard)
        self.wave = WaveWidget(); lay.addWidget(self.wave)
        row = QHBoxLayout()
        acts = [("🎙 Слушать", app.listener_activate), ("💬 Давай поговорим", lambda: app.toggle_conversation(True)),
                ("⏹ Закончить разговор", lambda: app.toggle_conversation(False)), ("■ Перебить", app.assistant.interrupt),
                ("🖥 Что на экране?", lambda: app.ask("Посмотри на мой экран и кратко скажи, что там.", "voice")),
                ("🎮 Игровой режим", lambda: app.ask_tool("gaming_mode", {"enabled": not app.settings.get("gaming_mode")}))]
        for t, f in acts:
            b = QPushButton(t); b.clicked.connect(f); row.addWidget(b)
        lay.addLayout(row)
        self.modes = QLabel(""); self.modes.setAlignment(Qt.AlignCenter); self.modes.setObjectName("muted")
        lay.addWidget(self.modes)

    def set_state(self, s):
        self.core.set_state(s)
        self.state.setText({"idle": "Скажите «Эхо» или нажмите на микрофон", "listening": "Слушаю…",
                            "thinking": "Думаю…", "speaking": "Говорю… (скажите «стоп», чтобы перебить)"}.get(s, s))


class MonitorPage(QWidget):
    def __init__(self):
        super().__init__()
        w, lay = page("System Monitor", "Загрузка процессора, видеокарты, памяти и температуры в реальном времени.")
        QVBoxLayout(self).addWidget(w); self.layout().setContentsMargins(0, 0, 0, 0)
        c, cl = card("Ресурсы")
        grid = QGridLayout(); cl.addLayout(grid)
        self.bars, self.vals = {}, {}
        for i, (k, n) in enumerate([("cpu", "CPU"), ("ram", "RAM"), ("gpu", "GPU"), ("disk", "Диск C:"),
                                    ("cpu_temp", "Темп. CPU"), ("gpu_temp", "Темп. GPU")]):
            grid.addWidget(QLabel(n), i, 0)
            b = QProgressBar(); b.setRange(0, 100); grid.addWidget(b, i, 1)
            v = QLabel("—"); v.setMinimumWidth(170); grid.addWidget(v, i, 2)
            self.bars[k], self.vals[k] = b, v
        lay.addWidget(c)
        c2, cl2 = card("Топ процессов по памяти")
        self.table = QTableWidget(0, 3); self.table.setHorizontalHeaderLabels(["Процесс", "CPU %", "RAM МБ"])
        self.table.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch); self.table.verticalHeader().hide()
        cl2.addWidget(self.table); lay.addWidget(c2, 1)
        self.timer = QTimer(self, timeout=self.refresh, interval=2000)

    def showEvent(self, e):
        self.timer.start(); self.refresh(); super().showEvent(e)

    def hideEvent(self, e):
        self.timer.stop(); super().hideEvent(e)

    def refresh(self):
        run_bg(lambda: (sysmon.snapshot(), sysmon.top_processes(8)), done=self._show, fail=lambda e: None)

    def _show(self, data):
        s, top = data
        def setv(k, val, text):
            self.bars[k].setValue(int(val or 0)); self.vals[k].setText(text)
        setv("cpu", s["cpu"], f"{s['cpu']:.0f}%")
        setv("ram", s["ram"], f"{s['ram_used']:.1f} / {s['ram_total']:.1f} ГБ")
        setv("disk", s["disk"], f"{s['disk']:.0f}%")
        g = s["gpu"]
        setv("gpu", g["load"] if g else 0, f"{g['load']:.0f}% {g['name']}" if g else "нет данных (NVIDIA)")
        setv("gpu_temp", g["temp"] if g else 0, f"{g['temp']:.0f}°C" if g else "—")
        t = s["cpu_temp"]
        setv("cpu_temp", t, f"{t:.0f}°C" if t else "нужен LibreHardwareMonitor")
        self.table.setRowCount(len(top))
        for r, (n, c, m) in enumerate(top):
            for col, v in enumerate((n, f"{c:.0f}", f"{m:.0f}")):
                self.table.setItem(r, col, QTableWidgetItem(str(v)))


class SecurityPage(QWidget):
    def __init__(self):
        super().__init__()
        w, lay = page("E.C.H.O Security", "Microsoft Defender, угрозы, подозрительные процессы и автозагрузка.")
        QVBoxLayout(self).addWidget(w); self.layout().setContentsMargins(0, 0, 0, 0)
        row = QHBoxLayout()
        for t, f in [("Состояние защиты", self.status), ("Быстрая проверка", self.quick), ("Полная проверка (фон)", self.full),
                     ("Проверить файл…", self.file), ("Угрозы", self.threats), ("Подозрительные процессы", self.procs),
                     ("Автозагрузка", self.startup)]:
            b = QPushButton(t); b.clicked.connect(f); row.addWidget(b)
        lay.addLayout(row)
        self.out = QTextEdit(); self.out.setReadOnly(True); lay.addWidget(self.out, 1)

    def _run(self, title, fn, *a):
        self.out.setPlainText(f"{title}… подождите")
        run_bg(fn, *a, done=lambda r: self.out.setPlainText(r if isinstance(r, str) else json.dumps(r, ensure_ascii=False, indent=2, default=str)),
               fail=lambda e: self.out.setPlainText("Ошибка: " + e))

    def status(self): self._run("Проверка", security.report)
    def quick(self): self._run("Быстрая проверка Defender (несколько минут)", security.quick_scan)
    def full(self): self._run("Запуск", security.full_scan_start)
    def threats(self): self._run("Загрузка", lambda: security.threats() or "Угроз не обнаружено")
    def procs(self): self._run("Анализ", lambda: security.suspicious_processes() or "Подозрительных процессов нет")
    def startup(self): self._run("Анализ", lambda: "\n".join(f"{i['name']}  —  {i['command']}  [{i['location']}]" for i in security.startup_items()) or "Пусто")

    def file(self):
        p, _ = QFileDialog.getOpenFileName(self, "Файл для проверки")
        if p:
            self._run(f"Проверка {p}", security.scan_file, p)


class SteamPage(QWidget):
    def __init__(self, app):
        super().__init__()
        self.app = app
        w, lay = page("Steam & Gaming Assistant", "Установленные игры находятся автоматически. Двойной клик — запуск.")
        QVBoxLayout(self).addWidget(w); self.layout().setContentsMargins(0, 0, 0, 0)
        row = QHBoxLayout()
        for t, f in [("Обновить", self.refresh), ("Запустить", self.launch), ("Открыть Steam", steam.open_steam),
                     ("Запущенные игры", self.running), ("Закрыть игру", self.close)]:
            b = QPushButton(t); b.clicked.connect(f); row.addWidget(b)
        lay.addLayout(row)
        self.list = QListWidget(); self.list.itemDoubleClicked.connect(lambda *_: self.launch()); lay.addWidget(self.list, 1)
        self.info = QLabel(""); self.info.setObjectName("muted"); lay.addWidget(self.info)
        self.games = {}

    def showEvent(self, e):
        if not self.games:
            self.refresh()
        super().showEvent(e)

    def refresh(self):
        def got(g):
            self.games = g
            self.app.assistant.tools._games = g
            self.list.clear()
            for a, x in sorted(g.items(), key=lambda kv: kv[1]["name"]):
                it = QListWidgetItem("🎮  " + x["name"]); it.setData(Qt.UserRole, a); self.list.addItem(it)
            self.info.setText(f"Найдено игр: {len(g)}" if g else "Steam или игры не найдены")
        run_bg(steam.find_games, done=got)

    def _sel(self):
        it = self.list.currentItem()
        return it.data(Qt.UserRole) if it else None

    def launch(self):
        a = self._sel()
        if a:
            steam.launch_game(a); self.info.setText(f"Запускаю {self.games[a]['name']}")

    def running(self):
        run_bg(steam.running_games, self.games, done=lambda r: self.info.setText(
            "Запущено: " + ", ".join(x["name"] for x in r.values()) if r else "Игры не запущены"))

    def close(self):
        a = self._sel()
        if a and QMessageBox.question(self, "E.C.H.O", f"Закрыть {self.games[a]['name']}? Несохранённый прогресс может потеряться.") == QMessageBox.Yes:
            self.info.setText("Закрыто" if steam.close_game(a, self.games) else "Игра не запущена")


class VisionPage(QWidget):
    def __init__(self, app):
        super().__init__()
        self.app = app
        w, lay = page("E.C.H.O Vision", "Анализ экрана через Claude: текст, ошибки, кнопки, помощь с настройкой. "
                      "Управление мышью — только если разрешено в настройках, и с подтверждением.")
        QVBoxLayout(self).addWidget(w); self.layout().setContentsMargins(0, 0, 0, 0)
        self.q = QLineEdit(); self.q.setPlaceholderText("Вопрос о содержимом экрана (например: что за ошибка? где кнопка экспорта?)")
        lay.addWidget(self.q)
        row = QHBoxLayout()
        presets = [("Спросить", None), ("Распознать текст", "Распознай и выпиши весь текст на экране."),
                   ("Объяснить ошибку", "Найди на экране ошибку и объясни, что она значит и как её исправить."),
                   ("Найти кнопки", "Перечисли основные кнопки и элементы управления на экране и где они находятся."),
                   ("Скриншот", "__shot")]
        for t, pr in presets:
            b = QPushButton(t); b.clicked.connect(lambda _=False, pr=pr: self.ask(pr)); row.addWidget(b)
        lay.addLayout(row)
        lay.addWidget(QLabel("Ответ появится в AI Chat."), 0)
        lay.addStretch(1)

    def ask(self, preset):
        if preset == "__shot":
            p = pc.screenshot()[1]
            QMessageBox.information(self, "E.C.H.O", f"Сохранено: {p}")
            return
        text = preset or self.q.text().strip()
        if text:
            self.app.ask(f"[Посмотри на экран через look_at_screen] {text}", "text", goto_chat=True)


class MemoryPage(QWidget):
    def __init__(self, app):
        super().__init__()
        self.app = app
        w, lay = page("E.C.H.O Memory", "Долговременные воспоминания и история диалогов (общая для голоса и чата).")
        QVBoxLayout(self).addWidget(w); self.layout().setContentsMargins(0, 0, 0, 0)
        c, cl = card("Воспоминания")
        self.mem = QListWidget(); cl.addWidget(self.mem)
        row = QHBoxLayout()
        for t, f in [("Добавить", self.add), ("Удалить выбранное", self.delete), ("Очистить память", self.clear_mem)]:
            b = QPushButton(t); b.clicked.connect(f); row.addWidget(b)
        cl.addLayout(row); lay.addWidget(c, 1)
        c2, cl2 = card("История")
        self.hist = QPlainTextEdit(); self.hist.setReadOnly(True); cl2.addWidget(self.hist)
        b = QPushButton("Удалить всю историю"); b.setObjectName("danger"); b.clicked.connect(self.clear_hist); cl2.addWidget(b)
        lay.addWidget(c2, 1)

    def showEvent(self, e):
        self.refresh(); super().showEvent(e)

    def refresh(self):
        db = self.app.assistant.db
        self.mem.clear()
        for m in db.memories():
            it = QListWidgetItem(m["text"]); it.setData(Qt.UserRole, m["id"]); self.mem.addItem(it)
        self.hist.setPlainText("\n".join(f"[{time.strftime('%d.%m %H:%M', time.localtime(m['ts']))}] "
                                         f"{'Вы' if m['role'] == 'user' else 'ECHO'}: {m['content']}" for m in db.recent_messages(300)))

    def add(self):
        t, ok = QInputDialog.getText(self, "Память", "Что запомнить?")
        if ok and t.strip():
            self.app.assistant.db.add_memory(t); self.refresh()

    def delete(self):
        it = self.mem.currentItem()
        if it:
            self.app.assistant.db.delete_memory(it.data(Qt.UserRole)); self.refresh()

    def clear_mem(self):
        if QMessageBox.question(self, "E.C.H.O", "Удалить все воспоминания?") == QMessageBox.Yes:
            self.app.assistant.db.clear_memories(); self.refresh()

    def clear_hist(self):
        if QMessageBox.question(self, "E.C.H.O", "Удалить всю историю диалогов?") == QMessageBox.Yes:
            self.app.assistant.clear_history(); self.app.chat.clear(); self.refresh()


class RemindersPage(QWidget):
    def __init__(self, app):
        super().__init__()
        self.app = app
        w, lay = page("Reminders", "Можно сказать: «Эхо, напомни через 20 минут проверить духовку».")
        QVBoxLayout(self).addWidget(w); self.layout().setContentsMargins(0, 0, 0, 0)
        row = QHBoxLayout()
        self.text = QLineEdit(); self.text.setPlaceholderText("О чём напомнить")
        self.mins = QSpinBox(); self.mins.setRange(1, 100000); self.mins.setValue(10); self.mins.setSuffix(" мин")
        b = QPushButton("Добавить"); b.setObjectName("primary"); b.clicked.connect(self.add)
        row.addWidget(self.text, 1); row.addWidget(self.mins); row.addWidget(b); lay.addLayout(row)
        self.list = QListWidget(); lay.addWidget(self.list, 1)
        d = QPushButton("Удалить выбранное"); d.clicked.connect(self.delete); lay.addWidget(d)

    def showEvent(self, e):
        self.refresh(); super().showEvent(e)

    def refresh(self):
        self.list.clear()
        for r in self.app.assistant.db.reminders():
            it = QListWidgetItem(f"⏰ {time.strftime('%d.%m %H:%M', time.localtime(r['due']))} — {r['text']}")
            it.setData(Qt.UserRole, r["id"]); self.list.addItem(it)

    def add(self):
        if self.text.text().strip():
            self.app.assistant.db.add_reminder(self.text.text().strip(), time.time() + self.mins.value() * 60)
            self.text.clear(); self.refresh()

    def delete(self):
        it = self.list.currentItem()
        if it:
            self.app.assistant.db.delete_reminder(it.data(Qt.UserRole)); self.refresh()


class CommandsPage(QWidget):
    def __init__(self, app):
        super().__init__()
        self.app = app
        w, lay = page("Custom Commands & Smart Actions",
                      "Своя фраза → несколько команд подряд. Пример: «игровой вечер» → «запусти дискорд», «запусти кс», «громкость 40».")
        QVBoxLayout(self).addWidget(w); self.layout().setContentsMargins(0, 0, 0, 0)
        self.phrase = QLineEdit(); self.phrase.setPlaceholderText("Фраза (например: игровой вечер)")
        self.steps = QPlainTextEdit(); self.steps.setPlaceholderText("Команды, по одной в строке"); self.steps.setFixedHeight(110)
        lay.addWidget(self.phrase); lay.addWidget(self.steps)
        row = QHBoxLayout()
        for t, f in [("Сохранить", self.save), ("Выполнить выбранную", self.run), ("Удалить выбранную", self.delete)]:
            b = QPushButton(t); b.clicked.connect(f); row.addWidget(b)
        lay.addLayout(row)
        self.list = QListWidget(); self.list.itemClicked.connect(self.load); lay.addWidget(self.list, 1)

    def showEvent(self, e):
        self.refresh(); super().showEvent(e)

    def refresh(self):
        self.list.clear()
        for c in self.app.assistant.db.custom_commands():
            it = QListWidgetItem(f"{c['phrase']}  →  {' | '.join(json.loads(c['actions']))}"); it.setData(Qt.UserRole, c)
            self.list.addItem(it)

    def load(self, it):
        c = it.data(Qt.UserRole)
        self.phrase.setText(c["phrase"]); self.steps.setPlainText("\n".join(json.loads(c["actions"])))

    def save(self):
        steps = [s.strip() for s in self.steps.toPlainText().splitlines() if s.strip()]
        if self.phrase.text().strip() and steps:
            self.app.assistant.db.set_custom_command(self.phrase.text(), json.dumps(steps, ensure_ascii=False)); self.refresh()

    def run(self):
        it = self.list.currentItem()
        if it:
            self.app.ask(it.data(Qt.UserRole)["phrase"], "text")

    def delete(self):
        it = self.list.currentItem()
        if it:
            self.app.assistant.db.delete_custom_command(it.data(Qt.UserRole)["id"]); self.refresh()


class FilesPage(QWidget):
    def __init__(self):
        super().__init__()
        w, lay = page("File Manager", "Поиск файлов в папках пользователя, открытие, показ в проводнике, проверка на вирусы.")
        QVBoxLayout(self).addWidget(w); self.layout().setContentsMargins(0, 0, 0, 0)
        row = QHBoxLayout()
        self.q = QLineEdit(); self.q.setPlaceholderText("Часть имени файла"); self.q.returnPressed.connect(self.search)
        b = QPushButton("Найти"); b.setObjectName("primary"); b.clicked.connect(self.search)
        row.addWidget(self.q, 1); row.addWidget(b); lay.addLayout(row)
        fr = QHBoxLayout()
        for name in ("Загрузки", "Документы", "Рабочий стол", "Изображения", "Скриншоты"):
            bb = QPushButton(name); bb.clicked.connect(lambda _=False, n=name: pc.open_folder(n.lower())); fr.addWidget(bb)
        lay.addLayout(fr)
        self.list = QListWidget(); self.list.itemDoubleClicked.connect(lambda it: pc.open_path(it.text())); lay.addWidget(self.list, 1)
        ar = QHBoxLayout()
        for t, f in [("Открыть", lambda: self._cur(pc.open_path)), ("Показать в папке", lambda: self._cur(lambda p: pc.open_path(os.path.dirname(p)))),
                     ("Проверить на вирусы", lambda: self._cur(lambda p: run_bg(security.scan_file, p, done=lambda r: QMessageBox.information(self, "Defender", r))))]:
            bb = QPushButton(t); bb.clicked.connect(f); ar.addWidget(bb)
        lay.addLayout(ar)

    def _cur(self, fn):
        it = self.list.currentItem()
        if it:
            fn(it.text())

    def search(self):
        q = self.q.text().strip()
        if not q:
            return
        self.list.clear(); self.list.addItem("Поиск…")
        def got(res):
            self.list.clear()
            self.list.addItems(res or ["Ничего не найдено"])
        run_bg(pc.search_files, q, None, 200, 20.0, done=got)


class TranslatePage(QWidget):
    LANGS = {"en": "Английский", "de": "Немецкий", "fr": "Французский", "es": "Испанский", "it": "Итальянский",
             "uk": "Украинский", "pl": "Польский", "tr": "Турецкий", "zh": "Китайский", "ja": "Японский", "ko": "Корейский", "pt": "Португальский"}

    def __init__(self, app):
        super().__init__()
        self.app = app
        w, lay = page("Live Translate", "Голосовой переводчик: говорите по-русски — E.C.H.O переводит и озвучивает; "
                      "иностранную речь переводит на русский. Голосом: «Эхо, включи переводчик на английский».")
        QVBoxLayout(self).addWidget(w); self.layout().setContentsMargins(0, 0, 0, 0)
        row = QHBoxLayout()
        self.lang = QComboBox()
        for k, v in self.LANGS.items():
            self.lang.addItem(v, k)
        self.btn = QPushButton("Включить переводчик"); self.btn.setObjectName("primary"); self.btn.clicked.connect(self.toggle)
        row.addWidget(QLabel("Язык:")); row.addWidget(self.lang); row.addWidget(self.btn); row.addStretch(1)
        lay.addLayout(row)
        self.inp = QPlainTextEdit(); self.inp.setPlaceholderText("Или введите текст для перевода"); lay.addWidget(self.inp)
        b = QPushButton("Перевести и озвучить"); b.clicked.connect(self.translate_text); lay.addWidget(b)
        lay.addStretch(1)
        app.assistant.mode_changed.connect(lambda m, on: m == "translate" and self.btn.setText("Выключить переводчик" if on else "Включить переводчик"))

    def toggle(self):
        a = self.app.assistant
        a.set_translate(not a.translate_mode, self.lang.currentData())
        if a.translate_mode:
            self.app.listener_activate()
            self.app.toggle_conversation(True)

    def translate_text(self):
        t = self.inp.toPlainText().strip()
        if t:
            self.app.assistant.translate_target = self.lang.currentData()
            self.app.win.goto("chat")
            self.app.assistant.submit(t, "text", translate=True)
