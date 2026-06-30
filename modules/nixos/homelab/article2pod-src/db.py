# ~/nixos-config/modules/nixos/homelab/article2pod-src/db.py
import sqlite3
import os
import uuid
from datetime import datetime, timezone
from contextlib import contextmanager

DB_PATH = os.environ.get("ARTICLE2POD_DB", "/var/lib/article2pod/db.sqlite")


def _connect():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    return conn


@contextmanager
def get_db():
    conn = _connect()
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def init_db():
    with get_db() as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS articles (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                guid        TEXT    NOT NULL UNIQUE,
                url         TEXT    NOT NULL UNIQUE,
                title       TEXT,
                author      TEXT,
                pub_date    TEXT,
                status      TEXT    NOT NULL DEFAULT 'queued',
                duration    INTEGER,
                size_bytes  INTEGER,
                added_at    TEXT    NOT NULL,
                processed_at TEXT,
                error       TEXT
            )
        """)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS settings (
                key   TEXT PRIMARY KEY,
                value TEXT NOT NULL
            )
        """)


def enqueue(url: str) -> dict | None:
    """Insert a new article URL. Returns the row or None if already exists."""
    guid = str(uuid.uuid4())
    now = datetime.now(timezone.utc).isoformat()
    try:
        with get_db() as conn:
            conn.execute(
                "INSERT INTO articles (guid, url, added_at) VALUES (?, ?, ?)",
                (guid, url, now),
            )
        return {"guid": guid, "url": url, "status": "queued", "added_at": now}
    except sqlite3.IntegrityError:
        return None  # already queued


def get_next_queued() -> sqlite3.Row | None:
    with get_db() as conn:
        return conn.execute(
            "SELECT * FROM articles WHERE status = 'queued' ORDER BY added_at LIMIT 1"
        ).fetchone()


def mark_processing(article_id: int):
    with get_db() as conn:
        conn.execute(
            "UPDATE articles SET status = 'processing' WHERE id = ?",
            (article_id,),
        )


def mark_done(article_id: int, title: str, author: str, pub_date: str,
              duration: int, size_bytes: int):
    now = datetime.now(timezone.utc).isoformat()
    with get_db() as conn:
        conn.execute(
            """UPDATE articles
               SET status='done', title=?, author=?, pub_date=?,
                   duration=?, size_bytes=?, processed_at=?, error=NULL
               WHERE id=?""",
            (title, author, pub_date, duration, size_bytes, now, article_id),
        )


def mark_failed(article_id: int, error: str):
    now = datetime.now(timezone.utc).isoformat()
    with get_db() as conn:
        conn.execute(
            "UPDATE articles SET status='failed', error=?, processed_at=? WHERE id=?",
            (error[:2000], now, article_id),
        )


def get_all() -> list[sqlite3.Row]:
    with get_db() as conn:
        return conn.execute(
            "SELECT * FROM articles ORDER BY added_at DESC"
        ).fetchall()


def delete_article(guid: str) -> bool:
    """Delete an article record by guid. Returns True if a row was deleted."""
    with get_db() as conn:
        result = conn.execute("DELETE FROM articles WHERE guid = ?", (guid,))
        return result.rowcount > 0


def get_setting(key: str, default: str = "") -> str:
    with get_db() as conn:
        row = conn.execute("SELECT value FROM settings WHERE key = ?", (key,)).fetchone()
        return row["value"] if row else default


def set_setting(key: str, value: str) -> None:
    with get_db() as conn:
        conn.execute(
            "INSERT INTO settings (key, value) VALUES (?, ?) "
            "ON CONFLICT(key) DO UPDATE SET value = excluded.value",
            (key, value),
        )


def get_done() -> list[sqlite3.Row]:
    with get_db() as conn:
        return conn.execute(
            "SELECT * FROM articles WHERE status='done' ORDER BY processed_at DESC"
        ).fetchall()
