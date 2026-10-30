from datetime import date

from ledgerly import cli, config


def run(capsys, *argv):
    code = cli.main(list(argv))
    return code, capsys.readouterr().out


def test_within_budget(db_path, capsys):
    run(capsys, "budget", "set", "Food", "100")
    run(capsys, "add", "42.99", "A", "--category", "Food", "--date", "2025-03-02")
    code, out = run(capsys, "budget", "check", "Food", "--month", "2025-03")
    assert code == 0
    assert "42.99" in out
    assert "100.00" in out
    assert "42" in out and "%" in out


def test_exactly_at_limit_is_not_over(db_path, capsys):
    run(capsys, "budget", "set", "Food", "100")
    run(capsys, "add", "100", "A", "--category", "Food", "--date", "2025-03-02")
    code, out = run(capsys, "budget", "check", "Food", "--month", "2025-03")
    assert code == 0


def test_over_budget_exits_4(db_path, capsys):
    run(capsys, "budget", "set", "Food", "100")
    run(capsys, "add", "120", "A", "--category", "Food", "--date", "2025-03-02")
    code, out = run(capsys, "budget", "check", "Food", "--month", "2025-03")
    assert code == 4
    assert "120" in out


def test_other_months_ignored(db_path, capsys):
    run(capsys, "budget", "set", "Food", "100")
    run(capsys, "add", "120", "A", "--category", "Food", "--date", "2025-02-02")
    code, out = run(capsys, "budget", "check", "Food", "--month", "2025-03")
    assert code == 0


def test_month_defaults_to_current(db_path, capsys):
    today = date.today().strftime(config.DATE_FORMAT)
    run(capsys, "budget", "set", "Food", "10")
    run(capsys, "add", "15", "A", "--category", "Food", "--date", today)
    code, out = run(capsys, "budget", "check", "Food")
    assert code == 4


def test_no_budget_and_unknown_category(db_path, capsys):
    code, out = run(capsys, "budget", "check", "Health", "--month", "2025-03")
    assert code == 3
    code, out = run(capsys, "budget", "check", "Nope", "--month", "2025-03")
    assert code == 3
    code, out = run(capsys, "budget", "check", "Food", "--month", "March")
    assert code in (2, 3)
