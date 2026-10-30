import sqlite3
from typing import Iterable

from ledgerly.errors import ConflictError


def add(conn: sqlite3.Connection, name: str) -> int:
    try:
        cur = conn.execute("INSERT INTO categories (name) VALUES (?)", (name,))
    except sqlite3.IntegrityError:
        raise ConflictError(f"Category already exists: {name}") from None
    return int(cur.lastrowid)


def ensure(conn: sqlite3.Connection, names: Iterable[str]) -> None:
    conn.executemany(
        "INSERT OR IGNORE INTO categories (name) VALUES (?)",
        [(name,) for name in names],
    )


def get_by_name(conn: sqlite3.Connection, name: str) -> sqlite3.Row | None:
    return conn.execute(
        "SELECT id, name FROM categories WHERE name = ? COLLATE NOCASE", (name,)
    ).fetchone()


def list_all(conn: sqlite3.Connection) -> list[sqlite3.Row]:
    return conn.execute("SELECT id, name FROM categories ORDER BY id").fetchall()
