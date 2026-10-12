"""SQLite: история диалогов, воспоминания, напоминания, свои команды."""
import sqlite3
import threading
import time

from .config import data_dir

SCHEMA = """
CREATE TABLE IF NOT EXISTS messages(id INTEGER PRIMARY KEY, session INTEGER, role TEXT, content TEXT, source TEXT, ts REAL);
CREATE TABLE IF NOT EXISTS memories(id INTEGER PRIMARY KEY, text TEXT UNIQUE, ts REAL);
CREATE TABLE IF NOT EXISTS reminders(id INTEGER PRIMARY KEY, text TEXT, due REAL, done INTEGER DEFAULT 0);
CREATE TABLE IF NOT EXISTS custom_commands(id INTEGER PRIMARY KEY, phrase TEXT UNIQUE, actions TEXT);
CREATE TABLE IF NOT EXISTS sessions(id INTEGER PRIMARY KEY, started REAL, title TEXT);
"""


class DB:
    def __init__(self, path=None):
        self.path = path or data_dir() / "echo.db"
        self.conn = sqlite3.connect(str(self.path), check_same_thread=False)
        self.conn.row_factory = sqlite3.Row
        self.lock = threading.Lock()
        with self.lock:
            self.conn.executescript(SCHEMA)
            self.conn.commit()
        self.session = self.new_session()

    def _q(self, sql, args=(), fetch=False):
        with self.lock:
            cur = self.conn.execute(sql, args)
            self.conn.commit()
            return cur.fetchall() if fetch else cur.lastrowid

    # сессии / история
    def new_session(self):
        return self._q("INSERT INTO sessions(started,title) VALUES(?,?)", (time.time(), ""))

    def add_message(self, role, content, source="text"):
        self._q("INSERT INTO messages(session,role,content,source,ts) VALUES(?,?,?,?,?)",
                (self.session, role, content, source, time.time()))

    def recent_messages(self, limit=30):
        rows = self._q("SELECT role,content,source,ts FROM messages ORDER BY id DESC LIMIT ?", (limit,), True)
        return [dict(r) for r in reversed(rows)]

    def clear_history(self):
        self._q("DELETE FROM messages")

    # память
    def add_memory(self, text):
        self._q("INSERT OR IGNORE INTO memories(text,ts) VALUES(?,?)", (text.strip(), time.time()))

    def memories(self):
        return [dict(r) for r in self._q("SELECT id,text FROM memories ORDER BY id", fetch=True)]

    def delete_memory(self, mid):
        self._q("DELETE FROM memories WHERE id=?", (mid,))

    def clear_memories(self):
        self._q("DELETE FROM memories")

    # напоминания
    def add_reminder(self, text, due):
        return self._q("INSERT INTO reminders(text,due) VALUES(?,?)", (text, due))

    def due_reminders(self):
        rows = self._q("SELECT id,text,due FROM reminders WHERE done=0 AND due<=?", (time.time(),), True)
        for r in rows:
            self._q("UPDATE reminders SET done=1 WHERE id=?", (r["id"],))
        return [dict(r) for r in rows]

    def reminders(self):
        return [dict(r) for r in self._q("SELECT id,text,due FROM reminders WHERE done=0 ORDER BY due", fetch=True)]

    def delete_reminder(self, rid):
        self._q("DELETE FROM reminders WHERE id=?", (rid,))

    # свои команды
    def custom_commands(self):
        return [dict(r) for r in self._q("SELECT id,phrase,actions FROM custom_commands", fetch=True)]

    def set_custom_command(self, phrase, actions):
        self._q("INSERT OR REPLACE INTO custom_commands(phrase,actions) VALUES(?,?)", (phrase.lower().strip(), actions))

    def delete_custom_command(self, cid):
        self._q("DELETE FROM custom_commands WHERE id=?", (cid,))
