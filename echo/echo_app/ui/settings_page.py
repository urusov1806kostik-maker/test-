"""Полноценные настройки: ИИ, характер, голос, микрофон, распознавание, система, приватность, интеграции."""
import asyncio

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton, QLineEdit, QComboBox, QCheckBox,
                               QSlider, QFormLayout, QScrollArea, QMessageBox, QDoubleSpinBox, QSpinBox, QPlainTextEdit,
                               QInputDialog, QProgressDialog)

from ..config import settings, PERSONALITIES
from ..voice.tts import VOICES
from .. import pc
from .common import card, h1, run_bg

MODELS = ["claude-opus-5-5", "claude-sonnet-5-5", "claude-haiku-5-5", "claude-fable-5-1"]
PERS_NAMES = {"friendly": "Дружелюбный", "professional": "Деловой", "funny": "Весёлый", "jarvis": "Дворецкий (JARVIS)",
              "gamer": "Геймер", "custom": "Свой…"}


class SettingsPage(QScrollArea):
    def __init__(self, app):
        super().__init__()
        self.app = app
        self.setWidgetResizable(True)
        root = QWidget(); self.setWidget(root)
        lay = QVBoxLayout(root); lay.setContentsMargins(28, 24, 28, 24); lay.setSpacing(14)
        lay.addWidget(h1("Настройки"))

        # ---- ИИ ----
        c, cl = card("Искусственный интеллект (Claude API)"); f = QFormLayout(); cl.addLayout(f)
        self.key = QLineEdit(); self.key.setEchoMode(QLineEdit.Password)
        self.key.setPlaceholderText("sk-ant-… (хранится в Диспетчере учётных данных Windows)" if not settings.get_secret("anthropic_api_key") else "•••••• сохранён")
        kr = QHBoxLayout(); kr.addWidget(self.key, 1)
        b = QPushButton("Сохранить"); b.clicked.connect(self.save_key); kr.addWidget(b)
        t = QPushButton("Проверить"); t.clicked.connect(self.test_key); kr.addWidget(t)
        f.addRow("API-ключ:", kr)
        self.model = QComboBox(); self.model.setEditable(True); self.model.addItems(MODELS); self.model.setCurrentText(settings.get("model"))
        self.model.currentTextChanged.connect(lambda v: settings.set("model", v)); f.addRow("Модель:", self.model)
        self.pers = QComboBox()
        for k, v in PERS_NAMES.items():
            self.pers.addItem(v, k)
        self.pers.setCurrentIndex(list(PERS_NAMES).index(settings.get("personality")) if settings.get("personality") in PERS_NAMES else 0)
        self.pers.currentIndexChanged.connect(self.pers_changed); f.addRow("Характер:", self.pers)
        self.custom = QPlainTextEdit(settings.get("custom_personality")); self.custom.setFixedHeight(70)
        self.custom.setPlaceholderText("Опишите свой стиль общения E.C.H.O")
        self.custom.textChanged.connect(lambda: settings.set("custom_personality", self.custom.toPlainText()))
        f.addRow("Свой стиль:", self.custom)
        self.uname = QLineEdit(settings.get("user_name")); self.uname.editingFinished.connect(lambda: settings.set("user_name", self.uname.text()))
        f.addRow("Как к вам обращаться:", self.uname)
        self.ctx = QSpinBox(); self.ctx.setRange(4, 200); self.ctx.setValue(settings.get("history_context"))
        self.ctx.valueChanged.connect(lambda v: settings.set("history_context", v)); f.addRow("Сообщений контекста:", self.ctx)
        self._check(f, "Долговременная память", "memory_enabled")
        lay.addWidget(c)

        # ---- Голос ----
        c, cl = card("Голос"); f = QFormLayout(); cl.addLayout(f)
        self._check(f, "Голосовые ответы (на голосовые запросы E.C.H.O отвечает голосом)", "tts_enabled")
        self._check(f, "Озвучивать и ответы в текстовом чате", "speak_text_replies")
        self.voice = QComboBox()
        for k, v in VOICES.items():
            self.voice.addItem(v, k)
        idx = self.voice.findData(settings.get("voice"))
        self.voice.setCurrentIndex(max(0, idx))
        self.voice.currentIndexChanged.connect(lambda: settings.set("voice", self.voice.currentData()))
        vr = QHBoxLayout(); vr.addWidget(self.voice, 1)
        mv = QPushButton("Ещё голоса…"); mv.clicked.connect(self.more_voices); vr.addWidget(mv)
        tb = QPushButton("▶ Прослушать"); tb.clicked.connect(lambda: self.app.assistant.tts.say("Привет! Я Эхо, ваш персональный помощник. Чем займёмся?"))
        vr.addWidget(tb); f.addRow("Голос:", vr)
        f.addRow("Скорость речи:", self._slider("voice_rate", -50, 50))
        f.addRow("Громкость голоса:", self._slider("voice_volume", -50, 50))
        lay.addWidget(c)

        # ---- Микрофон ----
        c, cl = card("Микрофон и распознавание"); f = QFormLayout(); cl.addLayout(f)
        self.mic = QComboBox(); self.mic.addItem("По умолчанию", -1)
        try:
            import sounddevice as sd
            for i, d in enumerate(sd.query_devices()):
                if d["max_input_channels"] > 0:
                    self.mic.addItem(d["name"], i)
        except Exception as e:
            self.mic.addItem(f"Ошибка аудио: {e}", -1)
        self.mic.setCurrentIndex(max(0, self.mic.findData(settings.get("mic_index"))))
        self.mic.currentIndexChanged.connect(lambda: settings.set("mic_index", self.mic.currentData()))
        f.addRow("Микрофон:", self.mic)
        self.wake = QLineEdit(settings.get("wake_word")); self.wake.setEnabled(False); f.addRow("Слово активации:", self.wake)
        self.stt = QComboBox()
        for k, v in (("auto", "Авто (Google онлайн, Vosk офлайн)"), ("vosk", "Только локально (Vosk)"), ("google", "Google Web Speech")):
            self.stt.addItem(v, k)
        self.stt.setCurrentIndex(max(0, self.stt.findData(settings.get("stt_engine"))))
        self.stt.currentIndexChanged.connect(lambda: settings.set("stt_engine", self.stt.currentData()))
        f.addRow("Распознавание:", self.stt)
        vb = QPushButton("Скачать офлайн-модель Vosk (45 МБ)" if not self.app.listener.stt.vosk_available() else "Модель Vosk установлена ✓")
        vb.clicked.connect(self.download_vosk); f.addRow("Локальная модель:", vb)
        sp = QDoubleSpinBox(); sp.setRange(0.4, 3.0); sp.setSingleStep(0.1); sp.setValue(settings.get("silence_timeout")); sp.setSuffix(" с")
        sp.valueChanged.connect(lambda v: settings.set("silence_timeout", v)); f.addRow("Пауза = конец фразы:", sp)
        ct = QSpinBox(); ct.setRange(5, 300); ct.setValue(settings.get("conversation_timeout")); ct.setSuffix(" с")
        ct.valueChanged.connect(lambda v: settings.set("conversation_timeout", v)); f.addRow("Продолжение диалога без «Эхо»:", ct)
        lay.addWidget(c)

        # ---- Система ----
        c, cl = card("Система и безопасность"); f = QFormLayout(); cl.addLayout(f)
        self._check(f, "Запускать вместе с Windows", "autostart", on_change=pc.set_autostart)
        self._check(f, "Запускать свёрнутым в трей", "start_minimized")
        self._check(f, "Показывать виджет поверх рабочего стола", "show_widget", on_change=self.app.set_widget_visible)
        self._check(f, "Подтверждать опасные действия", "confirm_dangerous")
        self._check(f, "Разрешить E.C.H.O управлять мышью/интерфейсом (Vision)", "allow_ui_control")
        self._check(f, "Озвучивать уведомления из Telegram/Discord", "read_notifications")
        lay.addWidget(c)

        # ---- Интеграции ----
        c, cl = card("Telegram"); f = QFormLayout(); cl.addLayout(f)
        cl.insertWidget(1, self._muted("Официальный API: получите api_id и api_hash на my.telegram.org → API development tools."))
        self.tg_id = QLineEdit(str(settings.get("telegram_api_id"))); f.addRow("api_id:", self.tg_id)
        self.tg_hash = QLineEdit(); self.tg_hash.setEchoMode(QLineEdit.Password)
        self.tg_hash.setPlaceholderText("•••• сохранён" if settings.get_secret("telegram_api_hash") else "api_hash"); f.addRow("api_hash:", self.tg_hash)
        r = QHBoxLayout()
        b1 = QPushButton("Подключить"); b1.setObjectName("primary"); b1.clicked.connect(self.tg_connect); r.addWidget(b1)
        b2 = QPushButton("Выйти"); b2.clicked.connect(self.tg_logout); r.addWidget(b2)
        self.tg_state = QLabel(""); r.addWidget(self.tg_state, 1); f.addRow(r)
        lay.addWidget(c)

        c, cl = card("Discord"); f = QFormLayout(); cl.addLayout(f)
        cl.insertWidget(1, self._muted("Через официального бота (discord.com/developers). Self-bot запрещён правилами Discord, поэтому "
                                       "E.C.H.O видит только серверы, куда добавлен ваш бот. Включите Message Content и Server Members Intent."))
        self.dc = QLineEdit(); self.dc.setEchoMode(QLineEdit.Password)
        self.dc.setPlaceholderText("•••• сохранён" if settings.get_secret("discord_token") else "Токен бота"); f.addRow("Токен:", self.dc)
        r = QHBoxLayout()
        b1 = QPushButton("Подключить"); b1.setObjectName("primary"); b1.clicked.connect(self.dc_connect); r.addWidget(b1)
        b2 = QPushButton("Отключить"); b2.clicked.connect(self.dc_disconnect); r.addWidget(b2)
        self.dc_state = QLabel(""); r.addWidget(self.dc_state, 1); f.addRow(r)
        lay.addWidget(c)
        lay.addStretch(1)
        self._refresh_states()

    # helpers
    def _muted(self, t):
        l = QLabel(t); l.setObjectName("muted"); l.setWordWrap(True)
        return l

    def _check(self, form, text, key, on_change=None):
        cb = QCheckBox(text); cb.setChecked(bool(settings.get(key)))

        def ch(v):
            settings.set(key, bool(v))
            if on_change:
                try:
                    on_change(bool(v))
                except Exception as e:
                    QMessageBox.warning(self, "E.C.H.O", str(e))
        cb.toggled.connect(ch); form.addRow(cb)
        return cb

    def _slider(self, key, lo, hi):
        w = QWidget(); h = QHBoxLayout(w); h.setContentsMargins(0, 0, 0, 0)
        s = QSlider(Qt.Horizontal); s.setRange(lo, hi); s.setValue(int(settings.get(key)))
        lab = QLabel(f"{s.value():+d}%"); lab.setMinimumWidth(50)
        s.valueChanged.connect(lambda v: (settings.set(key, v), lab.setText(f"{v:+d}%")))
        h.addWidget(s, 1); h.addWidget(lab)
        return w

    def _refresh_states(self):
        a = self.app.assistant
        self.tg_state.setText("✓ подключён" if a.telegram and a.telegram.connected else "не подключён")
        self.dc_state.setText("✓ подключён" if a.discord and a.discord.connected else (a.discord.error if a.discord and a.discord.error else "не подключён"))

    # actions
    def pers_changed(self):
        settings.set("personality", self.pers.currentData())

    def save_key(self):
        try:
            settings.set_secret("anthropic_api_key", self.key.text().strip())
            self.key.clear(); self.key.setPlaceholderText("•••••• сохранён")
            QMessageBox.information(self, "E.C.H.O", "Ключ сохранён в защищённом хранилище Windows.")
        except Exception as e:
            QMessageBox.warning(self, "E.C.H.O", str(e))

    def test_key(self):
        def t():
            c = self.app.assistant.client()
            if not c:
                return "Ключ не задан"
            r = c.messages.create(model=settings.get("model"), max_tokens=30, messages=[{"role": "user", "content": "Скажи «Связь установлена»."}])
            return "✓ " + "".join(b.text for b in r.content if b.type == "text")
        run_bg(t, done=lambda r: QMessageBox.information(self, "Claude API", r))

    def more_voices(self):
        from ..voice.tts import list_edge_voices
        def load():
            return asyncio.run(list_edge_voices(""))
        def got(vs):
            v, ok = QInputDialog.getItem(self, "Голоса", "Нейронный голос Microsoft:", sorted(vs), 0, False)
            if ok:
                if self.voice.findData(v) < 0:
                    self.voice.addItem(v, v)
                self.voice.setCurrentIndex(self.voice.findData(v))
        run_bg(load, done=got)

    def download_vosk(self):
        from ..voice.stt import download_vosk
        dlg = QProgressDialog("Загрузка модели Vosk…", None, 0, 100, self); dlg.setWindowModality(Qt.WindowModal); dlg.show()
        run_bg(download_vosk, done=lambda p: (dlg.close(), QMessageBox.information(self, "Vosk", f"Готово: {p}")),
               fail=lambda e: (dlg.close(), QMessageBox.warning(self, "Vosk", e)))

    def tg_connect(self):
        try:
            if self.tg_id.text().strip():
                settings.set("telegram_api_id", self.tg_id.text().strip())
            if self.tg_hash.text().strip():
                settings.set_secret("telegram_api_hash", self.tg_hash.text().strip())
            tg = self.app.ensure_telegram()
            if tg.start():
                settings.set("telegram_enabled", True)
                return self._refresh_states()
            phone, ok = QInputDialog.getText(self, "Telegram", "Номер телефона (+7…):")
            if not ok:
                return
            tg.send_code(phone.strip())
            code, ok = QInputDialog.getText(self, "Telegram", "Код из Telegram:")
            if not ok:
                return
            try:
                tg.sign_in(code.strip())
            except RuntimeError as e:
                if "пароль" not in str(e):
                    raise
                pw, ok = QInputDialog.getText(self, "Telegram", "Пароль 2FA:", QLineEdit.Password)
                tg.sign_in(code.strip(), pw)
            settings.set("telegram_enabled", True)
        except Exception as e:
            QMessageBox.warning(self, "Telegram", str(e))
        self._refresh_states()

    def tg_logout(self):
        if self.app.assistant.telegram:
            try:
                self.app.assistant.telegram.logout()
            except Exception as e:
                QMessageBox.warning(self, "Telegram", str(e))
        settings.set("telegram_enabled", False)
        self._refresh_states()

    def dc_connect(self):
        try:
            if self.dc.text().strip():
                settings.set_secret("discord_token", self.dc.text().strip())
            self.app.start_discord()
            settings.set("discord_enabled", True)
            self.dc_state.setText("подключение…")
            from PySide6.QtCore import QTimer
            QTimer.singleShot(5000, self._refresh_states)
        except Exception as e:
            QMessageBox.warning(self, "Discord", str(e))

    def dc_disconnect(self):
        if self.app.assistant.discord:
            self.app.assistant.discord.stop()
        settings.set("discord_enabled", False)
        self._refresh_states()
