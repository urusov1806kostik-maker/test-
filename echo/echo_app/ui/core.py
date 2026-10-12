"""Анимированное ядро E.C.H.O и звуковая волна."""
import math
import random

from PySide6.QtCore import Qt, QTimer, QPointF, QRectF
from PySide6.QtGui import QPainter, QColor, QRadialGradient, QPen, QConicalGradient, QPainterPath, QLinearGradient
from PySide6.QtWidgets import QWidget

from .theme import PURPLE, CYAN

STATE_COLORS = {"idle": (PURPLE, CYAN), "listening": (CYAN, "#7cf7ff"), "thinking": ("#c77dff", PURPLE),
                "speaking": (PURPLE, "#ff7bd5"), "offline": ("#555566", "#333344")}


class EchoCore(QWidget):
    def __init__(self, parent=None, size=260):
        super().__init__(parent)
        self.setMinimumSize(size, size)
        self.t = 0.0
        self.level = 0.0
        self._target = 0.0
        self.state = "idle"
        self.timer = QTimer(self, timeout=self._tick)
        self.timer.start(16)

    def set_level(self, v):
        self._target = max(0.0, min(1.0, v))

    def set_state(self, s):
        self.state = s
        self.update()

    def _tick(self):
        self.t += 0.016
        self.level += (self._target - self.level) * 0.25
        self._target *= 0.92
        if self.isVisible():
            self.update()

    def paintEvent(self, _):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)
        w, h = self.width(), self.height()
        c = QPointF(w / 2, h / 2)
        r = min(w, h) * 0.30
        c1, c2 = (QColor(x) for x in STATE_COLORS.get(self.state, STATE_COLORS["idle"]))
        pulse = 1 + 0.04 * math.sin(self.t * 2.2) + self.level * 0.25
        if self.state == "thinking":
            pulse += 0.03 * math.sin(self.t * 9)

        # внешнее свечение
        g = QRadialGradient(c, r * 2.2 * pulse)
        glow = QColor(c1); glow.setAlpha(90)
        g.setColorAt(0, glow); g.setColorAt(1, QColor(0, 0, 0, 0))
        p.setBrush(g); p.setPen(Qt.NoPen)
        p.drawEllipse(c, r * 2.2 * pulse, r * 2.2 * pulse)

        # вращающиеся кольца
        for i, (rad, speed, span, width) in enumerate([(1.55, 40, 250, 2), (1.35, -65, 120, 3), (1.75, 25, 60, 1.5), (1.2, 90, 200, 1)]):
            pen = QPen(c2 if i % 2 else c1, width)
            pen.setCapStyle(Qt.RoundCap)
            col = pen.color(); col.setAlpha(200 - i * 35); pen.setColor(col)
            p.setPen(pen); p.setBrush(Qt.NoBrush)
            rr = r * rad * (1 + self.level * 0.1)
            p.drawArc(QRectF(c.x() - rr, c.y() - rr, rr * 2, rr * 2), int(self.t * speed * 16) % 5760, span * 16)

        # деформируемая сфера (реагирует на голос)
        path = QPainterPath()
        n = 90
        for k in range(n + 1):
            a = k / n * math.tau
            d = 1 + (0.05 + self.level * 0.22) * math.sin(a * 5 + self.t * 3) * math.sin(a * 3 - self.t * 2)
            pt = QPointF(c.x() + math.cos(a) * r * d * pulse, c.y() + math.sin(a) * r * d * pulse)
            path.moveTo(pt) if k == 0 else path.lineTo(pt)
        cg = QConicalGradient(c, -self.t * 60)
        cg.setColorAt(0, c1); cg.setColorAt(0.5, c2); cg.setColorAt(1, c1)
        p.setBrush(cg); p.setPen(Qt.NoPen)
        p.drawPath(path)
        inner = QRadialGradient(c, r * pulse)
        inner.setColorAt(0, QColor(255, 255, 255, 200)); inner.setColorAt(0.35, QColor(255, 255, 255, 30)); inner.setColorAt(1, QColor(0, 0, 0, 120))
        p.setBrush(inner); p.drawPath(path)


class WaveWidget(QWidget):
    def __init__(self, parent=None, bars=48):
        super().__init__(parent)
        self.setMinimumHeight(60)
        self.vals = [0.0] * bars
        self.level = 0.0
        self.timer = QTimer(self, timeout=self._tick)
        self.timer.start(33)

    def set_level(self, v):
        self.level = max(self.level, min(1.0, v))

    def _tick(self):
        self.vals = self.vals[1:] + [self.level * (0.6 + random.random() * 0.4)]
        self.level *= 0.7
        if self.isVisible():
            self.update()

    def paintEvent(self, _):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)
        w, h = self.width(), self.height()
        n = len(self.vals)
        bw = w / n
        grad = QLinearGradient(0, 0, w, 0)
        grad.setColorAt(0, QColor(PURPLE)); grad.setColorAt(1, QColor(CYAN))
        p.setPen(Qt.NoPen); p.setBrush(grad)
        for i, v in enumerate(self.vals):
            bh = max(3, v * h * 0.95)
            p.drawRoundedRect(QRectF(i * bw + bw * 0.2, (h - bh) / 2, bw * 0.6, bh), 2, 2)
