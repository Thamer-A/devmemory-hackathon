import sqlite3

from ledgerly import config
from ledgerly.errors import NotFoundError, ValidationError
from ledgerly.repositories import categories as category_repo


def ensure_defaults(conn: sqlite3.Connection) -> None:
    category_repo.ensure(conn, config.DEFAULT_CATEGORIES)
    conn.commit()


def list_categories(conn: sqlite3.Connection) -> list[str]:
    return [row["name"] for row in category_repo.list_all(conn)]


def require_category(conn: sqlite3.Connection, name: str) -> sqlite3.Row:
    cleaned = (name or "").strip()
    if not cleaned:
        raise ValidationError("Category is required")
    row = category_repo.get_by_name(conn, cleaned)
    if row is None:
        raise NotFoundError(f"Unknown category: {cleaned}")
    return row
