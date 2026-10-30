import csv
import io

from ledgerly import cli


def run(capsys, *argv):
    code = cli.main(list(argv))
    return code, capsys.readouterr().out


def parse(out):
    return list(csv.reader(io.StringIO(out)))


def test_export_all(db_path, capsys):
    run(capsys, "add", "12.50", "Lunch, with Sam", "--category", "Food", "--date", "2025-03-14")
    run(capsys, "add", "3", 'Bus "night" ride', "--category", "Transport", "--date", "2025-04-01")
    code, out = run(capsys, "export")
    assert code == 0
    rows = parse(out)
    assert len(rows) == 3
    assert [h.strip().lower() for h in rows[0]] == ["id", "date", "category", "amount", "description"]
    assert rows[1] == ["1", "2025-03-14", "Food", "12.50", "Lunch, with Sam"]
    assert rows[2] == ["2", "2025-04-01", "Transport", "3.00", 'Bus "night" ride']


def test_export_month_filter(db_path, capsys):
    run(capsys, "add", "10", "A", "--category", "Food", "--date", "2025-03-01")
    run(capsys, "add", "20", "B", "--category", "Food", "--date", "2025-04-01")
    code, out = run(capsys, "export", "--month", "2025-04")
    assert code == 0
    rows = parse(out)
    assert len(rows) == 2
    assert rows[1][3] == "20.00"
    assert rows[1][4] == "B"


def test_export_bad_month(db_path, capsys):
    code, out = run(capsys, "export", "--month", "March")
    assert code == 2


def test_export_does_not_modify_data(db_path, capsys):
    run(capsys, "add", "10", "A", "--category", "Food", "--date", "2025-03-01")
    run(capsys, "export")
    code, out = run(capsys, "list")
    assert "A" in out and "10.00 USD" in out
