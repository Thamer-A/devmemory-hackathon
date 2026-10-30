import sqlite3

_SELECT = """
SELECT e.id, e.amount_cents, e.description, c.name AS category, e.spent_on
FROM expenses e
JOIN categories c ON c.id = e.category_id
"""


def add(
    conn: sqlite3.Connection,
    amount_cents: int,
    description: str,
    category_id: int,
    spent_on: str,
    created_at: str,
) -> int:
    cur = conn.execute(
        "INSERT INTO expenses (amount_cents, description, category_id, spent_on, created_at)"
        " VALUES (?, ?, ?, ?, ?)",
        (amount_cents, description, category_id, spent_on, created_at),
    )
    return int(cur.lastrowid)


def get(conn: sqlite3.Connection, expense_id: int) -> sqlite3.Row | None:
    return conn.execute(_SELECT + " WHERE e.id = ?", (expense_id,)).fetchone()


def list_expenses(conn: sqlite3.Connection, month: str | None = None) -> list[sqlite3.Row]:
    if month is None:
        return conn.execute(_SELECT + " ORDER BY e.spent_on, e.id").fetchall()
    return conn.execute(
        _SELECT + " WHERE substr(e.spent_on, 1, 7) = ? ORDER BY e.spent_on, e.id",
        (month,),
    ).fetchall()


def delete(conn: sqlite3.Connection, expense_id: int) -> bool:
    cur = conn.execute("DELETE FROM expenses WHERE id = ?", (expense_id,))
    return cur.rowcount > 0


def totals_by_category(conn: sqlite3.Connection, month: str) -> list[sqlite3.Row]:
    return conn.execute(
        "SELECT c.name AS category, SUM(e.amount_cents) AS total_cents"
        " FROM expenses e JOIN categories c ON c.id = e.category_id"
        " WHERE substr(e.spent_on, 1, 7) = ?"
        " GROUP BY c.id ORDER BY total_cents DESC, c.name",
        (month,),
    ).fetchall()


def sum_for_category(conn: sqlite3.Connection, category_id: int, month: str) -> int:
    row = conn.execute(
        "SELECT COALESCE(SUM(amount_cents), 0) AS total FROM expenses"
        " WHERE category_id = ? AND substr(spent_on, 1, 7) = ?",
        (category_id, month),
    ).fetchone()
    return int(row["total"])
