from PySide6.QtCore import QObject, QRunnable, QThreadPool, Signal
from PySide6.QtWidgets import QFrame, QLabel, QVBoxLayout, QMessageBox


class _Sig(QObject):
    done = Signal(object)
    fail = Signal(str)


class _Job(QRunnable):
    def __init__(self, fn, args):
        super().__init__()
        self.fn, self.args, self.sig = fn, args, _Sig()

    def run(self):
        try:
            self.sig.done.emit(self.fn(*self.args))
        except Exception as e:  # noqa
            self.sig.fail.emit(str(e))


_jobs = set()


def run_bg(fn, *args, done=None, fail=None):
    """Выполнить fn в фоне, результат — в GUI-поток."""
    j = _Job(fn, args)
    _jobs.add(j.sig)
    if done:
        j.sig.done.connect(done)
    j.sig.fail.connect(fail or (lambda e: QMessageBox.warning(None, "E.C.H.O", e)))
    j.sig.done.connect(lambda *_: _jobs.discard(j.sig))
    j.sig.fail.connect(lambda *_: _jobs.discard(j.sig))
    QThreadPool.globalInstance().start(j)


def card(title=None):
    f = QFrame(); f.setObjectName("card")
    lay = QVBoxLayout(f); lay.setContentsMargins(18, 16, 18, 16); lay.setSpacing(10)
    if title:
        t = QLabel(title); t.setObjectName("h2"); lay.addWidget(t)
    return f, lay


def h1(text):
    l = QLabel(text); l.setObjectName("h1")
    return l
