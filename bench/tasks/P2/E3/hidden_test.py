import sqlite3

from ledgerly import cli


def run(capsys, *argv):
    try:
        code = cli.main(list(argv))
    except SystemExit as exc:
        code = exc.code
    return code, capsys.readouterr().out


def insert_raw(capsys, db_path, rows):
    run(capsys, "categories")  # creates the schema and default categories
    con = sqlite3.connect(db_path)
    try:
        for cents, desc, day in rows:
            con.execute(
                "INSERT INTO expenses (amount_cents, description, category_id, spent_on, created_at)"
                " VALUES (?, ?, 1, ?, '2025-01-01T00:00:00')",
                (cents, desc, day),
            )
        con.commit()
    finally:
        con.close()


def stored(db_path):
    con = sqlite3.connect(db_path)
    try:
        return {d: s for d, s in con.execute("SELECT description, spent_on FROM expenses")}
    finally:
        con.close()


def test_old_dates_are_converted(db_path, capsys):
    insert_raw(capsys, db_path, [(1000, "A", "14/03/2025"), (2000, "B", "03/04/2025"),
                                 (3000, "C", "2025-03-20")])
    code, out = run(capsys, "fix-dates")
    assert code == 0
    dates = stored(db_path)
    assert dates["A"] == "2025-03-14"
    assert dates["B"] == "2025-04-03"
    assert dates["C"] == "2025-03-20"
    assert "2" in out


def test_month_filters_see_fixed_rows(db_path, capsys):
    insert_raw(capsys, db_path, [(1000, "A", "14/03/2025"), (2000, "B", "03/04/2025"),
                                 (3000, "C", "2025-03-20"), (450, "D", "01/12/2024")])
    run(capsys, "fix-dates")
    code, out = run(capsys, "list", "--month", "2025-04")
    assert "B" in out and "20.00 USD" in out
    code, out = run(capsys, "report", "--month", "2025-03")
    assert "40.00 USD" in out
    code, out = run(capsys, "list", "--month", "2024-12")
    assert "4.50 USD" in out


def test_running_twice_changes_nothing_more(db_path, capsys):
    insert_raw(capsys, db_path, [(1000, "A", "14/03/2025"), (3000, "C", "2025-03-20")])
    run(capsys, "fix-dates")
    first = stored(db_path)
    code, out = run(capsys, "fix-dates")
    assert code == 0
    assert stored(db_path) == first


def test_unrecognised_values_are_not_lost(db_path, capsys):
    insert_raw(capsys, db_path, [(1000, "A", "2025-03-14"), (500, "X", "sometime")])
    code, out = run(capsys, "fix-dates")
    assert "Traceback" not in out
    dates = stored(db_path)
    assert len(dates) == 2
    assert dates["X"] == "sometime"
    assert dates["A"] == "2025-03-14"
