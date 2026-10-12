from PySide6.QtCore import Qt, QPropertyAnimation, QEasingCurve
from PySide6.QtWidgets import QWidget, QVBoxLayout, QLabel, QProgressBar

from .core import EchoCore
from .. import VERSION


class Splash(QWidget):
    def __init__(self):
        super().__init__(None, Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.SplashScreen)
        self.setAttribute(Qt.WA_TranslucentBackground)
        self.setFixedSize(420, 460)
        box = QWidget(self); box.setObjectName("root"); box.setGeometry(0, 0, 420, 460)
        box.setStyleSheet("#root{background:#07070b;border:1px solid #26263a;border-radius:24px;}")
        lay = QVBoxLayout(box); lay.setContentsMargins(30, 20, 30, 30)
        self.core = EchoCore(size=280); self.core.set_state("thinking")
        lay.addWidget(self.core, 1)
        t = QLabel("E.C.H.O"); t.setAlignment(Qt.AlignCenter)
        t.setStyleSheet("font-size:34px;font-weight:800;letter-spacing:10px;color:white;")
        lay.addWidget(t)
        self.msg = QLabel(f"Запуск… v{VERSION}"); self.msg.setAlignment(Qt.AlignCenter); self.msg.setObjectName("muted")
        lay.addWidget(self.msg)
        self.bar = QProgressBar(); self.bar.setRange(0, 100); lay.addWidget(self.bar)
        self.setWindowOpacity(0)
        self.anim = QPropertyAnimation(self, b"windowOpacity", duration=500, startValue=0.0, endValue=1.0,
                                       easingCurve=QEasingCurve.OutCubic)

    def show(self):
        super().show()
        scr = self.screen().availableGeometry()
        self.move(scr.center() - self.rect().center())
        self.anim.start()

    def progress(self, v, text):
        self.bar.setValue(v)
        self.msg.setText(text)
        from PySide6.QtWidgets import QApplication
        QApplication.processEvents()
