"""Компактный виджет поверх рабочего стола: ядро + статус. Клик — слушать, двойной клик — открыть окно, перетаскивание мышью."""
from PySide6.QtCore import Qt, QPoint, Signal
from PySide6.QtWidgets import QWidget, QVBoxLayout, QLabel

from .core import EchoCore
from ..config import settings


class FloatingWidget(QWidget):
    clicked = Signal()
    open_main = Signal()

    def __init__(self):
        super().__init__(None, Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool)
        self.setAttribute(Qt.WA_TranslucentBackground)
        self.setFixedSize(150, 175)
        lay = QVBoxLayout(self); lay.setContentsMargins(0, 0, 0, 0); lay.setSpacing(0)
        self.core = EchoCore(size=140); self.core.setMinimumSize(140, 140)
        self.label = QLabel("E.C.H.O"); self.label.setAlignment(Qt.AlignCenter)
        self.label.setStyleSheet("color:#e8e8f2;font-weight:600;background:rgba(10,10,16,170);border-radius:9px;padding:3px 6px;")
        lay.addWidget(self.core); lay.addWidget(self.label)
        self._drag = None
        self._moved = False
        pos = settings.get("widget_pos")
        if pos:
            self.move(QPoint(*pos))
        else:
            g = self.screen().availableGeometry()
            self.move(g.right() - 180, g.bottom() - 220)

    def set_state(self, s):
        self.core.set_state(s)
        self.label.setText({"listening": "Слушаю…", "thinking": "Думаю…", "speaking": "Говорю…"}.get(s, "E.C.H.O"))

    def mousePressEvent(self, e):
        if e.button() == Qt.LeftButton:
            self._drag = e.globalPosition().toPoint() - self.frameGeometry().topLeft()
            self._moved = False

    def mouseMoveEvent(self, e):
        if self._drag is not None and e.buttons() & Qt.LeftButton:
            self.move(e.globalPosition().toPoint() - self._drag)
            self._moved = True

    def mouseReleaseEvent(self, e):
        if self._moved:
            settings.set("widget_pos", [self.x(), self.y()])
        elif e.button() == Qt.LeftButton:
            self.clicked.emit()
        self._drag = None

    def mouseDoubleClickEvent(self, e):
        self.open_main.emit()
