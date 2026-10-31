from ledgerly import cli


def run(capsys, *argv):
    try:
        code = cli.main(list(argv))
    except SystemExit as exc:
        code = exc.code
    return code, capsys.readouterr().out


def row(out, category):
    lines = [l for l in out.splitlines() if l.strip().startswith(category)]
    assert len(lines) == 1, out
    return lines[0]


def test_percent_shown_only_for_budgeted_categories(db_path, capsys):
    run(capsys, "budget", "set", "Food", "100")
    run(capsys, "add", "42.99", "A", "--category", "Food", "--date", "2025-03-02")
    run(capsys, "add", "5", "B", "--category", "Transport", "--date", "2025-03-03")
    code, out = run(capsys, "report", "--month", "2025-03")
    assert code == 0
    food = row(out, "Food")
    assert "42.99 USD" in food and "42%" in food
    transport = row(out, "Transport")
    assert "5.00 USD" in transport and "%" not in transport
    assert "47.99 USD" in row(out, "Total")


def test_over_budget_percent(db_path, capsys):
    run(capsys, "budget", "set", "Food", "100")
    run(capsys, "add", "120", "A", "--category", "Food", "--date", "2025-03-02")
    code, out = run(capsys, "report", "--month", "2025-03")
    assert code == 0
    assert "120%" in row(out, "Food")


def test_percent_uses_only_that_month(db_path, capsys):
    run(capsys, "budget", "set", "Food", "200")
    run(capsys, "add", "150", "Old", "--category", "Food", "--date", "2025-02-10")
    run(capsys, "add", "20", "New", "--category", "Food", "--date", "2025-03-10")
    code, out = run(capsys, "report", "--month", "2025-03")
    assert code == 0
    assert "10%" in row(out, "Food")


def test_report_without_budgets(db_path, capsys):
    run(capsys, "add", "10", "A", "--category", "Food", "--date", "2025-03-01")
    run(capsys, "add", "5", "B", "--category", "Transport", "--date", "2025-03-02")
    code, out = run(capsys, "report", "--month", "2025-03")
    assert code == 0
    assert "15.00 USD" in out
    assert "%" not in row(out, "Food") and "%" not in row(out, "Transport")
