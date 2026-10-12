from PySide6.QtCore import Qt
from PySide6.QtGui import QIcon
from PySide6.QtWidgets import (QMainWindow, QWidget, QHBoxLayout, QVBoxLayout, QPushButton, QStackedWidget, QLabel,
                               QButtonGroup)

from .. import VERSION
from .common import h1


class MainWindow(QMainWindow):
    def __init__(self, app):
        super().__init__()
        self.app = app
        self.setWindowTitle("E.C.H.O")
        self.resize(1240, 800)
        self.setMinimumSize(980, 640)
        root = QWidget(); root.setObjectName("root"); self.setCentralWidget(root)
        h = QHBoxLayout(root); h.setContentsMargins(0, 0, 0, 0); h.setSpacing(0)
        side = QWidget(); side.setObjectName("sidebar"); side.setFixedWidth(230)
        sv = QVBoxLayout(side); sv.setContentsMargins(12, 18, 12, 12); sv.setSpacing(4)
        logo = QLabel("E.C.H.O"); logo.setStyleSheet("font-size:24px;font-weight:800;letter-spacing:6px;padding:4px 10px 14px;"
                                                     "color:qlineargradient(x1:0,y1:0,x2:1,y2:0,stop:0 #9b5cff,stop:1 #3ad6ff);")
        sv.addWidget(logo)
        self.stack = QStackedWidget()
        self.group = QButtonGroup(self); self.group.setExclusive(True)
        self.pages = {}
        h.addWidget(side); h.addWidget(self.stack, 1)
        self._sv = sv

    def add_page(self, key, title, widget):
        b = QPushButton(title); b.setObjectName("nav"); b.setCheckable(True)
        idx = self.stack.addWidget(widget)
        b.clicked.connect(lambda: self.stack.setCurrentIndex(idx))
        self.group.addButton(b)
        self._sv.addWidget(b)
        self.pages[key] = (b, idx)
        if len(self.pages) == 1:
            b.setChecked(True)

    def finish_sidebar(self):
        self._sv.addStretch(1)
        self.status = QLabel(""); self.status.setObjectName("muted"); self.status.setWordWrap(True)
        self._sv.addWidget(self.status)
        v = QLabel(f"v{VERSION}"); v.setObjectName("muted"); self._sv.addWidget(v)

    def goto(self, key):
        b, idx = self.pages[key]
        b.setChecked(True); self.stack.setCurrentIndex(idx)

    def closeEvent(self, e):
        # закрытие окна — сворачивание в трей, приложение продолжает работать
        e.ignore()
        self.hide()
        self.app.tray_message("E.C.H.O работает в фоне", "Скажите «Эхо» или щёлкните по значку в трее.")
