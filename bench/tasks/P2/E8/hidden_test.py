from ledgerly import cli


def run(capsys, *argv):
    code = cli.main(list(argv))
    return code, capsys.readouterr().out


def last_line(out):
    return [l for l in out.splitlines() if l.strip()][-1]


def test_total_line(db_path, capsys):
    run(capsys, "add", "12.50", "Lunch", "--category", "Food", "--date", "2025-03-14")
    run(capsys, "add", "3", "Bus", "--category", "Transport", "--date", "2025-04-01")
    code, out = run(capsys, "list")
    assert code == 0
    assert "Lunch" in out and "Bus" in out
    last = last_line(out)
    assert "total" in last.lower()
    assert "15.50 USD" in last


def test_total_follows_month_filter(db_path, capsys):
    run(capsys, "add", "12.50", "Lunch", "--category", "Food", "--date", "2025-03-14")
    run(capsys, "add", "3", "Bus", "--category", "Transport", "--date", "2025-04-01")
    code, out = run(capsys, "list", "--month", "2025-04")
    assert code == 0
    last = last_line(out)
    assert "total" in last.lower() and "3.00 USD" in last
    assert "15.50" not in out


def test_total_uses_money_format(db_path, capsys):
    run(capsys, "add", "1200", "Rent", "--category", "Housing", "--date", "2025-03-01")
    run(capsys, "add", "0.99", "Gum", "--category", "Food", "--date", "2025-03-02")
    code, out = run(capsys, "list")
    assert "1,200.99 USD" in last_line(out)


def test_empty_list_unchanged(db_path, capsys):
    code, out = run(capsys, "list", "--month", "2025-03")
    assert code == 0
    assert "No expenses found." in out
