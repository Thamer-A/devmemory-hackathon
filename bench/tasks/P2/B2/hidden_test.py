import re
import sqlite3

from ledgerly import cli

ISO = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def run(capsys, *argv):
    code = cli.main(list(argv))
    return code, capsys.readouterr().out


def dates(db_path):
    con = sqlite3.connect(db_path)
    try:
        return [r[0] for r in con.execute("SELECT spent_on FROM expenses")]
    finally:
        con.close()


def descriptions(db_path):
    con = sqlite3.connect(db_path)
    try:
        return [r[0] for r in con.execute("SELECT description FROM expenses")]
    finally:
        con.close()


def write_csv(tmp_path, rows):
    path = tmp_path / "in.csv"
    lines = ["amount,description,category,date"] + [",".join(r) for r in rows]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return str(path)


def test_import_valid_rows(db_path, tmp_path, capsys):
    path = write_csv(tmp_path, [("12.50", "Lunch", "Food", "2025-03-14"),
                                ("3", "Bus", "Transport", "2025-03-15")])
    code, out = run(capsys, "import", path)
    assert code == 0
    assert sorted(dates(db_path)) == ["2025-03-14", "2025-03-15"]
    code, out = run(capsys, "list", "--month", "2025-03")
    assert "Lunch" in out and "12.50 USD" in out and "Bus" in out


def test_import_rejects_day_first_dates(db_path, tmp_path, capsys):
    path = write_csv(tmp_path, [("5", "Coffee", "Food", "14/03/2025")])
    code, out = run(capsys, "import", path)
    assert code == 2
    assert out.lstrip().startswith("error:") or "error" in out.lower()
    assert "Coffee" not in descriptions(db_path)
    assert dates(db_path) == []


def test_import_never_stores_non_iso_dates(db_path, tmp_path, capsys):
    path = write_csv(tmp_path, [("5", "Tea", "Food", "2025-03-01"),
                                ("6", "Cake", "Food", "03/14/2025"),
                                ("7", "Pie", "Food", "2025-3-4")])
    code, out = run(capsys, "import", path)
    assert code == 2
    assert all(ISO.match(d) for d in dates(db_path))
    names = descriptions(db_path)
    assert "Cake" not in names and "Pie" not in names


def test_import_unknown_category(db_path, tmp_path, capsys):
    path = write_csv(tmp_path, [("5", "Tea", "Nope", "2025-03-01")])
    code, out = run(capsys, "import", path)
    assert code == 3
