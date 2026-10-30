import sqlite3


def set_limit(conn: sqlite3.Connection, category_id: int, cents: int) -> None:
    conn.execute(
        "INSERT INTO budgets (category_id, monthly_limit) VALUES (?, ?)"
        " ON CONFLICT(category_id) DO UPDATE SET monthly_limit = excluded.monthly_limit",
        (category_id, cents),
    )


def get_limit(conn: sqlite3.Connection, category_id: int) -> int | None:
    row = conn.execute(
        "SELECT monthly_limit FROM budgets WHERE category_id = ?", (category_id,)
    ).fetchone()
    return None if row is None else int(row["monthly_limit"])


def list_limits(conn: sqlite3.Connection) -> list[sqlite3.Row]:
    return conn.execute(
        "SELECT c.id AS category_id, c.name AS category, b.monthly_limit AS monthly_limit"
        " FROM budgets b JOIN categories c ON c.id = b.category_id"
        " ORDER BY c.name"
    ).fetchall()
