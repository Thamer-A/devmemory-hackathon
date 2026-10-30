import sqlite3


def set_limit(conn: sqlite3.Connection, category_id: int, cents: int) -> None:
    conn.execute(
        "INSERT INTO budgets (category_id, limit_cents) VALUES (?, ?)"
        " ON CONFLICT(category_id) DO UPDATE SET limit_cents = excluded.limit_cents",
        (category_id, cents),
    )


def get_limit(conn: sqlite3.Connection, category_id: int) -> int | None:
    row = conn.execute(
        "SELECT limit_cents FROM budgets WHERE category_id = ?", (category_id,)
    ).fetchone()
    return None if row is None else int(row["limit_cents"])


def list_limits(conn: sqlite3.Connection) -> list[sqlite3.Row]:
    return conn.execute(
        "SELECT c.id AS category_id, c.name AS category, b.limit_cents AS limit_cents"
        " FROM budgets b JOIN categories c ON c.id = b.category_id"
        " ORDER BY c.name"
    ).fetchall()
