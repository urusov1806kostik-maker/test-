BG = "#07070b"
PANEL = "#111118"
PANEL2 = "#191922"
BORDER = "#26263a"
TEXT = "#e8e8f2"
MUTED = "#8a8aa3"
PURPLE = "#9b5cff"
CYAN = "#3ad6ff"
DANGER = "#ff4d6d"
OK = "#39e09b"

QSS = f"""
* {{ font-family: 'Segoe UI', 'Inter', sans-serif; font-size: 14px; color: {TEXT}; }}
QMainWindow, QDialog, #root {{ background: {BG}; }}
QWidget#sidebar {{ background: {PANEL}; border-right: 1px solid {BORDER}; }}
QPushButton#nav {{ text-align: left; padding: 10px 16px; border: none; border-radius: 10px; color: {MUTED}; background: transparent; }}
QPushButton#nav:hover {{ background: {PANEL2}; color: {TEXT}; }}
QPushButton#nav:checked {{ background: qlineargradient(x1:0,y1:0,x2:1,y2:0, stop:0 rgba(155,92,255,0.35), stop:1 rgba(58,214,255,0.12));
    color: white; border-left: 3px solid {PURPLE}; }}
QPushButton {{ background: {PANEL2}; border: 1px solid {BORDER}; border-radius: 10px; padding: 8px 14px; }}
QPushButton:hover {{ border-color: {PURPLE}; background: #1f1f2c; }}
QPushButton:pressed {{ background: #2a2140; }}
QPushButton#primary {{ background: qlineargradient(x1:0,y1:0,x2:1,y2:0, stop:0 {PURPLE}, stop:1 {CYAN}); border: none; color: white; font-weight: 600; }}
QPushButton#danger {{ border-color: {DANGER}; color: {DANGER}; }}
QPushButton#round {{ border-radius: 22px; min-width: 44px; min-height: 44px; max-width: 44px; max-height: 44px; padding: 0; font-size: 18px; }}
QLineEdit, QTextEdit, QPlainTextEdit, QSpinBox, QDoubleSpinBox, QComboBox {{ background: {PANEL2}; border: 1px solid {BORDER};
    border-radius: 10px; padding: 8px 10px; selection-background-color: {PURPLE}; }}
QLineEdit:focus, QTextEdit:focus, QPlainTextEdit:focus {{ border-color: {CYAN}; }}
QComboBox QAbstractItemView {{ background: {PANEL2}; border: 1px solid {BORDER}; selection-background-color: {PURPLE}; }}
QListWidget, QTableWidget {{ background: {PANEL}; border: 1px solid {BORDER}; border-radius: 12px; padding: 4px; gridline-color: {BORDER}; }}
QListWidget::item {{ padding: 8px; border-radius: 8px; }}
QListWidget::item:selected, QTableWidget::item:selected {{ background: rgba(155,92,255,0.35); }}
QHeaderView::section {{ background: {PANEL2}; border: none; padding: 6px; color: {MUTED}; }}
QScrollArea {{ border: none; background: transparent; }}
QScrollBar:vertical {{ background: transparent; width: 8px; }}
QScrollBar::handle:vertical {{ background: #33334a; border-radius: 4px; min-height: 30px; }}
QScrollBar::add-line, QScrollBar::sub-line {{ height: 0; }}
QProgressBar {{ background: {PANEL2}; border: none; border-radius: 6px; height: 12px; text-align: center; color: transparent; }}
QProgressBar::chunk {{ border-radius: 6px; background: qlineargradient(x1:0,y1:0,x2:1,y2:0, stop:0 {PURPLE}, stop:1 {CYAN}); }}
QCheckBox::indicator {{ width: 18px; height: 18px; border-radius: 5px; border: 1px solid {BORDER}; background: {PANEL2}; }}
QCheckBox::indicator:checked {{ background: {PURPLE}; border-color: {PURPLE}; }}
QSlider::groove:horizontal {{ height: 6px; background: {PANEL2}; border-radius: 3px; }}
QSlider::handle:horizontal {{ width: 16px; margin: -5px 0; border-radius: 8px; background: {CYAN}; }}
QSlider::sub-page:horizontal {{ background: {PURPLE}; border-radius: 3px; }}
QTabWidget::pane {{ border: none; }}
QTabBar::tab {{ background: transparent; padding: 8px 16px; color: {MUTED}; }}
QTabBar::tab:selected {{ color: white; border-bottom: 2px solid {CYAN}; }}
QLabel#h1 {{ font-size: 24px; font-weight: 700; }}
QLabel#h2 {{ font-size: 16px; font-weight: 600; color: {CYAN}; }}
QLabel#muted {{ color: {MUTED}; }}
QFrame#card {{ background: {PANEL}; border: 1px solid {BORDER}; border-radius: 16px; }}
QToolTip {{ background: {PANEL2}; color: {TEXT}; border: 1px solid {PURPLE}; }}
QMenu {{ background: {PANEL}; border: 1px solid {BORDER}; }}
QMenu::item:selected {{ background: {PURPLE}; }}
"""
