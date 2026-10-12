"""Сборка приложения: окно, трей, виджет, голос, интеграции, напоминания."""
import logging
import sys
import time

from PySide6.QtCore import QTimer, Qt, QObject, Signal
from PySide6.QtGui import QIcon, QAction, QPixmap, QPainter, QRadialGradient, QColor
from PySide6.QtNetwork import QLocalServer, QLocalSocket
from PySide6.QtWidgets import QApplication, QSystemTrayIcon, QMenu, QMessageBox

from . import apps, VERSION
from .assistant import Assistant
from .config import settings, resource_path, data_dir
from .ui.theme import QSS
from .ui.splash import Splash
from .ui.main_window import MainWindow
from .ui.chat import ChatView
from .ui.widget import FloatingWidget
from .ui import pages
from .ui.settings_page import SettingsPage
from .ui.common import run_bg

log = logging.getLogger("echo")


class Bridge(QObject):
    """Сигналы из фоновых потоков (аудио, интеграции) в GUI."""
    level = Signal(float)
    listen_state = Signal(str)
    heard = Signal(str)
    notify = Signal(str, str)


def app_icon():
    p = resource_path("assets/echo.ico")
    if p.exists():
        return QIcon(str(p))
    pm = QPixmap(64, 64); pm.fill(Qt.transparent)
    pa = QPainter(pm); pa.setRenderHint(QPainter.Antialiasing)
    g = QRadialGradient(32, 32, 30); g.setColorAt(0, QColor("#ffffff")); g.setColorAt(0.4, QColor("#3ad6ff")); g.setColorAt(1, QColor("#9b5cff"))
    pa.setBrush(g); pa.setPen(Qt.NoPen); pa.drawEllipse(4, 4, 56, 56); pa.end()
    return QIcon(pm)


class EchoApp:
    def __init__(self, qapp: QApplication, minimized=False):
        self.qapp = qapp
        self.settings = settings
        qapp.setStyleSheet(QSS)
        qapp.setWindowIcon(app_icon())
        qapp.setQuitOnLastWindowClosed(False)
        splash = Splash(); splash.show()

        splash.progress(10, "Загрузка ядра ИИ…")
        self.bridge = Bridge()
        self.assistant = Assistant()
        a = self.assistant

        splash.progress(25, "Поиск установленных программ…")
        run_bg(apps.index.scan, done=lambda n: log.info("apps indexed: %s", n), fail=lambda e: log.warning(e))

        splash.progress(40, "Инициализация голоса…")
        from .voice.tts import TTS
        from .voice.listener import Listener
        a.tts = TTS(on_level=self.bridge.level.emit)
        self.listener = Listener(a, on_level=lambda v: None, on_state=self.bridge.listen_state.emit, on_text=self.bridge.heard.emit)

        splash.progress(60, "Создание интерфейса…")
        self.win = MainWindow(self)
        self.dashboard = pages.Dashboard(self)
        self.chat = ChatView()
        self.win.add_page("home", "◉  Главная", self.dashboard)
        self.win.add_page("chat", "💬  AI Chat", self.chat)
        self.win.add_page("vision", "👁  Vision", pages.VisionPage(self))
        self.win.add_page("steam", "🎮  Steam / Игры", pages.SteamPage(self))
        self.win.add_page("monitor", "📊  System Monitor", pages.MonitorPage())
        self.win.add_page("security", "🛡  Security", pages.SecurityPage())
        self.win.add_page("files", "📁  Файлы", pages.FilesPage())
        self.win.add_page("translate", "🌐  Переводчик", pages.TranslatePage(self))
        self.win.add_page("memory", "🧠  Память", pages.MemoryPage(self))
        self.win.add_page("reminders", "⏰  Напоминания", pages.RemindersPage(self))
        self.win.add_page("commands", "⚡  Свои команды", pages.CommandsPage(self))
        self.settings_page = SettingsPage(self)
        self.win.add_page("settings", "⚙  Настройки", self.settings_page)
        self.win.finish_sidebar()
        self.widget = FloatingWidget()
        self.widget.clicked.connect(self.listener_activate)
        self.widget.open_main.connect(self.show_main)

        # история в чат
        for m in a.db.recent_messages(40):
            self.chat.add(m["content"], m["role"], m["source"], animate=False)

        # сигналы
        self.chat.send.connect(lambda t: self.ask(t, "text"))
        self.chat.mic.connect(self.listener_activate)
        self.chat.stop.connect(a.interrupt)
        a.user_message.connect(lambda t, s: (self.chat.add(t, "user", s), self.chat.set_thinking(True)))
        a.reply_started.connect(self.chat.begin_reply)
        a.reply_delta.connect(self.chat.delta)
        a.reply_finished.connect(self.chat.finish_reply)
        a.state_changed.connect(self.set_state)
        a.status.connect(lambda s: self.win.status.setText(s))
        a.action_done.connect(lambda s: self.win.status.setText("✓ " + s))
        a.confirm_request.connect(self.confirm_dialog)
        a.mode_changed.connect(self.on_mode)
        self.bridge.level.connect(self.dashboard.core.set_level)
        self.bridge.level.connect(self.dashboard.wave.set_level)
        self.bridge.level.connect(self.widget.core.set_level)
        self.bridge.listen_state.connect(self.set_state)
        self.bridge.heard.connect(lambda t: self.dashboard.heard.setText(f"«{t}»"))
        self.bridge.notify.connect(self.on_notification)

        splash.progress(75, "Трей и автозапуск…")
        self.tray = QSystemTrayIcon(app_icon())
        menu = QMenu()
        for text, fn in [("Открыть E.C.H.O", self.show_main), ("Слушать", self.listener_activate),
                         ("Режим беседы", lambda: self.toggle_conversation(True)), ("Виджет вкл/выкл", self.toggle_widget)]:
            act = QAction(text, menu); act.triggered.connect(fn); menu.addAction(act)
        self.mute_act = QAction("Выключить микрофон", menu, checkable=True)
        self.mute_act.toggled.connect(self.set_mic_muted); menu.addAction(self.mute_act)
        menu.addSeparator()
        q = QAction("Выход", menu); q.triggered.connect(self.quit); menu.addAction(q)
        self.tray.setContextMenu(menu)
        self.tray.setToolTip(f"E.C.H.O v{VERSION}")
        self.tray.activated.connect(lambda r: r == QSystemTrayIcon.Trigger and self.show_main())
        self.tray.show()
        if settings.get("autostart"):
            try:
                from .pc import set_autostart
                set_autostart(True)
            except Exception:
                pass

        splash.progress(85, "Интеграции…")
        if settings.get("telegram_enabled"):
            run_bg(lambda: self.ensure_telegram().start(), done=lambda ok: log.info("telegram: %s", ok), fail=lambda e: log.warning("tg %s", e))
        if settings.get("discord_enabled"):
            try:
                self.start_discord()
            except Exception as e:
                log.warning("discord %s", e)

        splash.progress(95, "Запуск микрофона…")
        self.listener.start()
        self.reminder_timer = QTimer(timeout=self.check_reminders, interval=15000); self.reminder_timer.start()
        self.mic_check = QTimer(timeout=self._mic_status, interval=3000); self.mic_check.start()
        splash.progress(100, "Готово")
        QTimer.singleShot(400, splash.close)
        if not (minimized or settings.get("start_minimized")):
            QTimer.singleShot(450, self.show_main)
        if settings.get("show_widget"):
            QTimer.singleShot(500, self.widget.show)
        if not settings.get_secret("anthropic_api_key"):
            QTimer.singleShot(1500, lambda: self.chat.add(
                "Добро пожаловать! Чтобы я мог полноценно разговаривать, укажите ключ Claude API в Настройках. "
                "Без ключа работают локальные команды: «Эхо, открой ютуб», «Эхо, запусти КС», «Эхо, громкость 30».", "system"))

    # ---------- действия ----------
    def ask(self, text, source="text", goto_chat=False):
        if goto_chat:
            self.win.goto("chat")
        self.assistant.submit(text, source)

    def ask_tool(self, name, args):
        res = self.assistant.tools.run(name, args, lambda q: QMessageBox.question(self.win, "E.C.H.O", q) == QMessageBox.Yes)
        self.win.status.setText(str(res))
        self.assistant.speak(str(res))

    def listener_activate(self):
        self.assistant.interrupt()
        self.listener.activate()

    def toggle_conversation(self, on):
        self.assistant.conversation_mode = on
        self.on_mode("conversation", on)
        self.assistant.speak("Режим беседы включён. Говорите свободно." if on else "Режим беседы выключен.")
        if on:
            self.listener.activate()

    def on_mode(self, mode, on):
        a = self.assistant
        parts = []
        if a.conversation_mode: parts.append("💬 режим беседы")
        if a.translate_mode: parts.append(f"🌐 перевод → {a.translate_target}")
        if settings.get("gaming_mode"): parts.append("🎮 игровой режим")
        self.dashboard.modes.setText("  ·  ".join(parts))

    def set_state(self, s):
        if s == "idle" and (self.assistant.conversation_mode or time.time() < self.listener.followup_until):
            self.listener.followup_until = max(self.listener.followup_until, time.time() + settings.get("conversation_timeout"))
            s = "listening"
        self.dashboard.set_state(s)
        self.widget.set_state(s)

    def confirm_dialog(self, question):
        box = QMessageBox(QMessageBox.Question, "E.C.H.O — подтверждение", question + "\n\n(Можно ответить голосом: «да» / «нет»)",
                          QMessageBox.Yes | QMessageBox.No, self.win)
        box.setWindowFlag(Qt.WindowStaysOnTopHint)
        self._confirm_box = box
        box.finished.connect(lambda r: self.assistant.pending_confirm and self.assistant.answer_confirm(box.result() == QMessageBox.Yes))
        self.listener.followup_until = time.time() + 60
        box.open()
        def close_if_answered():
            if not self.assistant.pending_confirm and box.isVisible():
                box.done(0)
            elif box.isVisible():
                QTimer.singleShot(300, close_if_answered)
        QTimer.singleShot(300, close_if_answered)

    def on_notification(self, title, text):
        self.tray_message(title, text[:200])
        if settings.get("read_notifications") and not settings.get("gaming_mode") and self.assistant.tts:
            if not self.assistant.tts.busy():
                self.assistant.tts.say(f"{title} пишет: {text[:150]}")

    def tray_message(self, title, text):
        self.tray.showMessage(title, text, app_icon(), 4000)

    def check_reminders(self):
        for r in self.assistant.db.due_reminders():
            self.tray_message("⏰ Напоминание", r["text"])
            self.assistant.tts.say(f"Напоминаю: {r['text']}")
            self.chat.add(f"⏰ Напоминание: {r['text']}", "system")

    def _mic_status(self):
        if self.listener.error:
            self.win.status.setText(self.listener.error)

    def ensure_telegram(self):
        if self.assistant.telegram is None:
            from .integrations.telegram import TelegramClient
            self.assistant.telegram = TelegramClient(on_message=lambda n, t: self.bridge.notify.emit(f"Telegram: {n}", t))
        return self.assistant.telegram

    def start_discord(self):
        from .integrations.discord_bot import DiscordClient
        if self.assistant.discord:
            self.assistant.discord.stop()
        self.assistant.discord = DiscordClient(on_message=lambda n, t: self.bridge.notify.emit(f"Discord: {n}", t))
        self.assistant.discord.start()

    def set_mic_muted(self, m):
        self.listener.muted = m
        self.win.status.setText("Микрофон выключен" if m else "Микрофон включён")

    def set_widget_visible(self, v):
        self.widget.setVisible(v)

    def toggle_widget(self):
        v = not self.widget.isVisible()
        settings.set("show_widget", v)
        self.widget.setVisible(v)

    def show_main(self):
        self.win.showNormal(); self.win.raise_(); self.win.activateWindow()

    def quit(self):
        self.listener.stop()
        self.tray.hide()
        self.qapp.quit()


def setup_logging():
    from logging.handlers import RotatingFileHandler
    h = RotatingFileHandler(data_dir() / "echo.log", maxBytes=2_000_000, backupCount=2, encoding="utf-8")
    logging.basicConfig(level=logging.INFO, handlers=[h], format="%(asctime)s %(name)s %(levelname)s %(message)s")


def main():
    setup_logging()
    if sys.platform == "win32":
        import ctypes
        try:
            ctypes.windll.shcore.SetProcessDpiAwareness(2)   # реальные пиксели для Vision/кликов
        except Exception:
            pass
        ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID("ECHO.Assistant")
    qapp = QApplication(sys.argv)
    qapp.setApplicationName("E.C.H.O")
    # один экземпляр: повторный запуск открывает окно
    sock = QLocalSocket(); sock.connectToServer("ECHO-single")
    if sock.waitForConnected(300):
        sock.write(b"show"); sock.flush(); sock.waitForBytesWritten(300)
        return 0
    server = QLocalServer(); QLocalServer.removeServer("ECHO-single"); server.listen("ECHO-single")
    echo = EchoApp(qapp, minimized="--minimized" in sys.argv)
    server.newConnection.connect(lambda: (server.nextPendingConnection(), echo.show_main()))
    sys.excepthook = lambda t, v, tb: log.error("uncaught", exc_info=(t, v, tb))
    return qapp.exec()
