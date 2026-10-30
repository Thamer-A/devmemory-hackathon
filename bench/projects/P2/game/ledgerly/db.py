"""SQLite connection handling and schema creation."""

import sqlite3

from ledgerly import config

SCHEMA = """
CREATE TABLE IF NOT EXISTS categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS expenses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    amount_cents INTEGER NOT NULL,
    description TEXT NOT NULL,
    category_id INTEGER NOT NULL REFERENCES categories(id),
    spent_on TEXT NOT NULL,
    created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_expenses_spent_on ON expenses(spent_on);

CREATE TABLE IF NOT EXISTS budgets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    category_id INTEGER NOT NULL UNIQUE REFERENCES categories(id),
    monthly_limit INTEGER NOT NULL
);
"""


def get_connection(path: str | None = None) -> sqlite3.Connection:
    conn = sqlite3.connect(path or config.get_db_path())
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def init_schema(conn: sqlite3.Connection) -> None:
    conn.executescript(SCHEMA)
    conn.commit()
