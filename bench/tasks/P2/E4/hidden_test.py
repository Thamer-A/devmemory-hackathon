import sqlite3

from ledgerly import cli

# Schema of databases created before this change.
OLD_SCHEMA = """
CREATE TABLE categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE
);
CREATE TABLE expenses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    amount_cents INTEGER NOT NULL,
    description TEXT NOT NULL,
    category_id INTEGER NOT NULL REFERENCES categories(id),
    spent_on TEXT NOT NULL,
    created_at TEXT NOT NULL
);
CREATE INDEX idx_expenses_spent_on ON expenses(spent_on);
CREATE TABLE budgets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    category_id INTEGER NOT NULL UNIQUE REFERENCES categories(id),
    limit_cents INTEGER NOT NULL
);
"""


def run(capsys, *argv):
    try:
        code = cli.main(list(argv))
    except SystemExit as exc:
        code = exc.code
    return code, capsys.readouterr().out


def make_old_db(path):
    con = sqlite3.connect(path)
    try:
        con.executescript(OLD_SCHEMA)
        con.execute("INSERT INTO categories (name) VALUES ('Food')")
        con.execute(
            "INSERT INTO expenses (amount_cents, description, category_id, spent_on, created_at)"
            " VALUES (2500, 'Shirt', 1, '2025-03-14', '2025-03-14T10:00:00')"
        )
        con.execute("INSERT INTO budgets (category_id, limit_cents) VALUES (1, 10000)")
        con.commit()
    finally:
        con.close()


def query(path, sql, args=()):
    con = sqlite3.connect(path)
    con.row_factory = sqlite3.Row
    try:
        return [dict(r) for r in con.execute(sql, args)]
    finally:
        con.close()


def expense_columns(path):
    return {r["name"]: r for r in query(path, "PRAGMA table_info(expenses)")}


def test_existing_database_is_upgraded(db_path, capsys):
    make_old_db(db_path)
    code, out = run(capsys, "list")
    assert code == 0
    assert "Shirt" in out and "25.00 USD" in out
    cols = expense_columns(db_path)
    assert "refund_of" in cols
    assert cols["refund_of"]["notnull"] == 0
    rows = query(db_path, "SELECT * FROM expenses")
    assert len(rows) == 1 and rows[0]["refund_of"] is None and rows[0]["amount_cents"] == 2500
    code, out = run(capsys, "budget", "show", "--month", "2025-03")
    assert code == 0 and "100.00 USD" in out


def test_upgrade_runs_safely_every_time(db_path, capsys):
    make_old_db(db_path)
    for _ in range(3):
        code, out = run(capsys, "list")
        assert code == 0
    code, out = run(capsys, "add", "5", "Tea", "--category", "Food", "--date", "2025-03-15")
    assert code == 0
    rows = query(db_path, "SELECT * FROM expenses ORDER BY id")
    assert len(rows) == 2 and rows[1]["refund_of"] is None


def test_new_database_has_column(db_path, capsys):
    code, _ = run(capsys, "categories")
    assert code == 0
    assert "refund_of" in expense_columns(db_path)


def test_refund_rows_net_into_original_category(db_path, capsys):
    run(capsys, "add", "25", "Shirt", "--category", "Other", "--date", "2025-03-14")
    run(capsys, "add", "40", "Dinner", "--category", "Food", "--date", "2025-03-14")
    original = query(db_path, "SELECT * FROM expenses WHERE id = 1")[0]
    con = sqlite3.connect(db_path)
    try:
        con.execute(
            "INSERT INTO expenses (amount_cents, description, category_id, spent_on, created_at, refund_of)"
            " VALUES (-1000, 'Shirt', ?, '2025-03-20', '2025-03-20T09:00:00', 1)",
            (original["category_id"],),
        )
        con.commit()
    finally:
        con.close()
    code, out = run(capsys, "report", "--month", "2025-03")
    assert code == 0
    assert "15.00 USD" in out and "40.00 USD" in out
    code, out = run(capsys, "list")
    assert "-10.00 USD" in out
    assert query(db_path, "SELECT * FROM expenses WHERE id = 1")[0] == original
