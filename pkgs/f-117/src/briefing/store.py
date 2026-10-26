"""Keeps every article seen in a small local database, so the week and month
summaries have history to work from even though feeds only hold recent items."""

import hashlib
import json
import os
import sqlite3
import time
from datetime import date, datetime
from pathlib import Path

KEEP_DAYS = 120


def data_dir():
    base = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    path = Path(base) / "briefing-room"
    path.mkdir(parents=True, exist_ok=True)
    return path


def today_start():
    return datetime.now().replace(hour=0, minute=0, second=0, microsecond=0).timestamp()


def unique(rows):
    """Drop repeats of the same headline carried by two feeds in one panel
    (for calendar events, the same event on the same day)."""
    seen, out = set(), []
    for row in rows:
        key = " ".join(row["title"].lower().split())
        if row["event_at"]:
            key += time.strftime("|%Y%m%d", time.localtime(row["event_at"]))
        if key not in seen:
            seen.add(key)
            out.append(dict(row))
    return out


class Store:
    def __init__(self, path=None):
        self.db = sqlite3.connect(path or data_dir() / "briefing.db")
        self.db.row_factory = sqlite3.Row
        self.db.executescript(
            """
            CREATE TABLE IF NOT EXISTS articles (
                id        TEXT PRIMARY KEY,
                panel     TEXT NOT NULL,
                source    TEXT NOT NULL,
                title     TEXT NOT NULL,
                summary   TEXT NOT NULL DEFAULT '',
                link      TEXT NOT NULL DEFAULT '',
                published INTEGER NOT NULL,
                fetched   INTEGER NOT NULL,
                seen      INTEGER NOT NULL DEFAULT 0
            );
            CREATE INDEX IF NOT EXISTS by_panel ON articles (panel, published);
            CREATE TABLE IF NOT EXISTS briefings (
                tab     TEXT NOT NULL,
                period  TEXT NOT NULL,
                created INTEGER NOT NULL,
                data    TEXT NOT NULL,
                PRIMARY KEY (tab, period)
            );
            CREATE TABLE IF NOT EXISTS todos (
                id      INTEGER PRIMARY KEY AUTOINCREMENT,
                key     TEXT UNIQUE,          -- set for built-in reminders
                text    TEXT NOT NULL,
                due     TEXT,                 -- YYYY-MM-DD or NULL
                link    TEXT NOT NULL DEFAULT '',
                done    INTEGER NOT NULL DEFAULT 0,
                created INTEGER NOT NULL
            );
            """
        )
        columns = {r["name"] for r in self.db.execute("PRAGMA table_info(articles)")}
        if "event_at" not in columns:
            self.db.execute("ALTER TABLE articles ADD COLUMN event_at INTEGER")
        todo_columns = {r["name"] for r in self.db.execute("PRAGMA table_info(todos)")}
        if "important" not in todo_columns:
            self.db.execute("ALTER TABLE todos ADD COLUMN important INTEGER NOT NULL DEFAULT 0")
        if "person" not in columns:
            self.db.execute("ALTER TABLE articles ADD COLUMN person INTEGER NOT NULL DEFAULT 0")
        self.db.commit()

    def add(self, articles):
        now = int(time.time())
        before = self.db.total_changes
        self.db.executemany(
            "INSERT OR IGNORE INTO articles "
            "(id, panel, source, title, summary, link, published, fetched, event_at, person) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [
                (
                    hashlib.sha1(f"{a['panel']}|{a['key']}".encode()).hexdigest(),
                    a["panel"],
                    a["source"],
                    a["title"],
                    a["summary"],
                    a["link"],
                    a["published"],
                    now,
                    a.get("event_at"),
                    int(bool(a.get("person"))),
                )
                for a in articles
            ],
        )
        self.db.execute(
            "DELETE FROM articles WHERE published < ? AND (event_at IS NULL OR event_at < ?)",
            (now - KEEP_DAYS * 86400, now),
        )
        self.db.commit()
        return self.db.total_changes - before

    def recent(self, panel, limit=60, max_age_days=45):
        since = int(time.time()) - max_age_days * 86400
        rows = self.db.execute(
            "SELECT * FROM articles WHERE panel = ? AND published >= ? "
            "ORDER BY published DESC LIMIT ?",
            (panel, since, limit * 2),
        )
        return unique(rows)[:limit]

    def since(self, panel, since):
        rows = self.db.execute(
            "SELECT * FROM articles WHERE panel = ? AND published >= ? ORDER BY published DESC",
            (panel, since),
        )
        return unique(rows)

    def upcoming(self, panel, until=None, limit=60, news_days=30):
        """For calendar panels: events from today on, soonest first, followed by
        any plain news items from the last month."""
        start = today_start()
        until = until or start + 400 * 86400
        events = self.db.execute(
            "SELECT * FROM articles WHERE panel = ? AND event_at >= ? AND event_at < ? "
            "ORDER BY event_at LIMIT ?",
            (panel, start, until, limit * 2),
        )
        news = self.db.execute(
            "SELECT * FROM articles WHERE panel = ? AND event_at IS NULL AND published >= ? "
            "ORDER BY published DESC LIMIT ?",
            (panel, time.time() - news_days * 86400, limit),
        )
        return (unique(events) + unique(news))[:limit]

    def seen_before(self, panel, before):
        """Titles that already appeared in this panel before a time (for 'new face')."""
        rows = self.db.execute("SELECT DISTINCT lower(title) FROM articles WHERE panel = ? AND published < ?", (panel, before))
        return {r[0] for r in rows}

    def news_since(self, since):
        """Every non-calendar article since a time, across all panels."""
        rows = self.db.execute(
            "SELECT * FROM articles WHERE event_at IS NULL AND published >= ?", (since,)
        )
        return [dict(r) for r in rows]

    def last_fetched(self):
        row = self.db.execute("SELECT MAX(fetched) FROM articles").fetchone()
        return row[0]

    def stats(self):
        n = self.db.execute("SELECT COUNT(*) FROM articles").fetchone()[0]
        return {"stories": n}

    def first_fetched(self):
        row = self.db.execute("SELECT MIN(fetched) FROM articles").fetchone()
        return row[0]

    def mark_seen(self, article_id):
        self.db.execute("UPDATE articles SET seen = 1 WHERE id = ?", (article_id,))
        self.db.commit()

    def briefing(self, tab, period):
        """The last AI briefing written for this tab and window, or None."""
        row = self.db.execute(
            "SELECT created, data FROM briefings WHERE tab = ? AND period = ?", (tab, period)
        ).fetchone()
        if not row:
            return None
        data = json.loads(row["data"])
        data["created"] = row["created"]
        return data

    def save_briefing(self, tab, period, data):
        self.db.execute(
            "INSERT OR REPLACE INTO briefings (tab, period, created, data) VALUES (?, ?, ?, ?)",
            (tab, period, int(time.time()), json.dumps(data)),
        )
        self.db.commit()

    def drop_unlisted(self, panel_sources):
        """Forget articles from feeds no longer in sources.json.

        `panel_sources` maps panel id -> set of source names; panels built from
        Google News name their publishers per item, so those panels are kept whole."""
        for panel, names in panel_sources.items():
            if names is None:
                continue
            marks = ",".join("?" * len(names))
            self.db.execute(
                f"DELETE FROM articles WHERE panel = ? AND source NOT IN ({marks})", (panel, *names)
            )
        self.db.execute(
            f"DELETE FROM articles WHERE panel NOT IN ({','.join('?' * len(panel_sources))})",
            tuple(panel_sources),
        )
        self.db.commit()

    # -- checklist

    def seed_todos(self, items):
        """Add built-in reminders (from sources.json) that aren't in yet."""
        now = int(time.time())
        self.db.executemany(
            "INSERT OR IGNORE INTO todos (key, text, due, link, created) VALUES (?, ?, ?, ?, ?)",
            [(i["key"], i["text"], i.get("due"), i.get("link", ""), now) for i in items],
        )
        self.db.executemany(
            "UPDATE todos SET important = ? WHERE key = ?",
            [(int(bool(i.get("important"))), i["key"]) for i in items],
        )
        self.db.commit()

    def todos(self):
        """Open reminders first (dated ones by date), then finished ones.
        Built-in reminders whose date has passed are left out."""
        today = date.today().isoformat()
        rows = [dict(r) for r in self.db.execute("SELECT * FROM todos")]
        rows = [r for r in rows if not (r["key"] and r["due"] and r["due"] < today)]
        return sorted(rows, key=lambda r: (r["done"], r["due"] is None, r["due"] or "", r["id"]))

    def add_todo(self, text, due=None, important=False):
        self.db.execute(
            "INSERT INTO todos (text, due, created, important) VALUES (?, ?, ?, ?)",
            (text, due, int(time.time()), int(important)),
        )
        self.db.commit()

    def set_todo_important(self, todo_id, important):
        self.db.execute("UPDATE todos SET important = ? WHERE id = ?", (int(important), todo_id))
        self.db.commit()

    def set_todo_done(self, todo_id, done):
        self.db.execute("UPDATE todos SET done = ? WHERE id = ?", (int(done), todo_id))
        self.db.commit()

    def delete_todo(self, todo_id):
        self.db.execute("DELETE FROM todos WHERE id = ? AND key IS NULL", (todo_id,))
        self.db.commit()
