"""AI Chat: общая история с голосом, стриминг ответа, плавное появление сообщений."""
import time

from PySide6.QtCore import Qt, QPropertyAnimation, QEasingCurve, QTimer, Signal, QParallelAnimationGroup
from PySide6.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QLabel, QScrollArea, QFrame, QPushButton,
                               QPlainTextEdit, QGraphicsOpacityEffect, QSizePolicy)

from .theme import PANEL2, BORDER, MUTED


class Bubble(QFrame):
    def __init__(self, text, role, source="text"):
        super().__init__()
        self.role = role
        self.raw = text
        lay = QVBoxLayout(self); lay.setContentsMargins(14, 10, 14, 10); lay.setSpacing(4)
        head = QLabel(("🎙 " if source == "voice" else "") + ("Вы" if role == "user" else "E.C.H.O" if role == "assistant" else "Система")
                      + "  ·  " + time.strftime("%H:%M"))
        head.setStyleSheet(f"color:{MUTED};font-size:11px;background:transparent;border:none;")
        self.label = QLabel()
        self.label.setWordWrap(True)
        self.label.setTextInteractionFlags(Qt.TextSelectableByMouse | Qt.LinksAccessibleByMouse)
        self.label.setOpenExternalLinks(True)
        self.label.setStyleSheet("background:transparent;border:none;font-size:14px;")
        self.label.setSizePolicy(QSizePolicy.Preferred, QSizePolicy.Minimum)
        lay.addWidget(head); lay.addWidget(self.label)
        if role == "user":
            css = "background:qlineargradient(x1:0,y1:0,x2:1,y2:1,stop:0 rgba(155,92,255,0.55),stop:1 rgba(90,60,200,0.45));border-radius:16px;"
        elif role == "assistant":
            css = f"background:{PANEL2};border:1px solid {BORDER};border-radius:16px;"
        else:
            css = "background:rgba(58,214,255,0.08);border:1px dashed rgba(58,214,255,0.4);border-radius:12px;"
        self.setStyleSheet(f"Bubble{{{css}}}")
        self.setMaximumWidth(720)
        self.set_text(text, final=True)

    def set_text(self, text, final=False):
        self.raw = text
        if final and self.role == "assistant":
            self.label.setTextFormat(Qt.MarkdownText)
        else:
            self.label.setTextFormat(Qt.PlainText)
        self.label.setText(text + ("" if final else " ▍"))
        fm = self.label.fontMetrics()
        longest = max((fm.horizontalAdvance(l) for l in (text or " ").splitlines()), default=0)
        self.label.setMinimumWidth(min(620, longest + 8))


class ChatView(QWidget):
    send = Signal(str)
    mic = Signal()
    stop = Signal()

    def __init__(self):
        super().__init__()
        lay = QVBoxLayout(self); lay.setContentsMargins(0, 0, 0, 0)
        self.scroll = QScrollArea(); self.scroll.setWidgetResizable(True)
        self.inner = QWidget(); self.inner.setStyleSheet("background:transparent;")
        self.vbox = QVBoxLayout(self.inner); self.vbox.setSpacing(10); self.vbox.addStretch(1)
        self.scroll.setWidget(self.inner)
        lay.addWidget(self.scroll, 1)
        self.typing = QLabel("E.C.H.O думает…"); self.typing.setObjectName("muted"); self.typing.hide()
        lay.addWidget(self.typing)

        row = QHBoxLayout()
        self.input = QPlainTextEdit(); self.input.setPlaceholderText("Напишите сообщение… (Enter — отправить, Shift+Enter — новая строка)")
        self.input.setFixedHeight(64)
        self.input.keyPressEvent = self._key
        self.btn_mic = QPushButton("🎙"); self.btn_mic.setObjectName("round"); self.btn_mic.setToolTip("Говорить (без слова «Эхо»)")
        self.btn_stop = QPushButton("■"); self.btn_stop.setObjectName("round"); self.btn_stop.setToolTip("Перебить ответ")
        self.btn_send = QPushButton("➤"); self.btn_send.setObjectName("round"); self.btn_send.setToolTip("Отправить")
        self.btn_send.clicked.connect(self._send)
        self.btn_mic.clicked.connect(self.mic.emit)
        self.btn_stop.clicked.connect(self.stop.emit)
        row.addWidget(self.input, 1); row.addWidget(self.btn_mic); row.addWidget(self.btn_stop); row.addWidget(self.btn_send)
        lay.addLayout(row)
        self.current = None
        self._dots = 0
        self._typing_timer = QTimer(self, timeout=self._anim_typing, interval=400)

    def _key(self, e):
        if e.key() in (Qt.Key_Return, Qt.Key_Enter) and not e.modifiers() & Qt.ShiftModifier:
            self._send()
        else:
            QPlainTextEdit.keyPressEvent(self.input, e)

    def _send(self):
        t = self.input.toPlainText().strip()
        if t:
            self.input.clear()
            self.send.emit(t)

    def _anim_typing(self):
        self._dots = (self._dots + 1) % 4
        self.typing.setText("E.C.H.O думает" + "." * self._dots)

    def set_thinking(self, on):
        self.typing.setVisible(on)
        (self._typing_timer.start if on else self._typing_timer.stop)()

    def add(self, text, role, source="text", animate=True):
        b = Bubble(text, role, source)
        wrap = QHBoxLayout()
        if role == "user":
            wrap.addStretch(1); wrap.addWidget(b)
        else:
            wrap.addWidget(b); wrap.addStretch(1)
        holder = QWidget(); holder.setLayout(wrap); holder.setStyleSheet("background:transparent;")
        self.vbox.insertWidget(self.vbox.count() - 1, holder)
        if animate:
            eff = QGraphicsOpacityEffect(holder); holder.setGraphicsEffect(eff)
            grp = QParallelAnimationGroup(holder)
            fade = QPropertyAnimation(eff, b"opacity", duration=380, startValue=0.0, endValue=1.0, easingCurve=QEasingCurve.OutCubic)
            holder.setMaximumHeight(0)
            grow = QPropertyAnimation(holder, b"maximumHeight", duration=320, startValue=0, endValue=2000, easingCurve=QEasingCurve.OutCubic)
            grp.addAnimation(fade); grp.addAnimation(grow)
            grp.finished.connect(lambda: (holder.setGraphicsEffect(None), holder.setMaximumHeight(16777215)))
            grp.start()
        QTimer.singleShot(60, self._scroll_bottom)
        return b

    def _scroll_bottom(self):
        sb = self.scroll.verticalScrollBar(); sb.setValue(sb.maximum())

    # стриминг
    def begin_reply(self):
        self.set_thinking(False)
        self.current = self.add("", "assistant")

    def delta(self, chunk):
        if self.current is None:
            self.begin_reply()
        self.current.set_text(self.current.raw + chunk)
        self._scroll_bottom()

    def finish_reply(self, text):
        self.set_thinking(False)
        if self.current is not None:
            self.current.set_text(text or self.current.raw, final=True)
        self.current = None
        QTimer.singleShot(60, self._scroll_bottom)

    def clear(self):
        while self.vbox.count() > 1:
            w = self.vbox.takeAt(0).widget()
            if w:
                w.deleteLater()
