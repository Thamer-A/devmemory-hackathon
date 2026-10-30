from ledgerly import cli


def run(capsys, *argv):
    code = cli.main(list(argv))
    return code, capsys.readouterr().out


def test_highest_budget(db_path, capsys):
    run(capsys, "budget", "set", "Food", "200")
    run(capsys, "budget", "set", "Transport", "350.50")
    run(capsys, "budget", "set", "Health", "100")
    code, out = run(capsys, "budget", "highest")
    assert code == 0
    assert "Transport" in out
    assert "350.50 USD" in out
    assert "Food" not in out and "Health" not in out


def test_highest_follows_updates(db_path, capsys):
    run(capsys, "budget", "set", "Food", "200")
    run(capsys, "budget", "set", "Transport", "350")
    run(capsys, "budget", "set", "Food", "500")
    code, out = run(capsys, "budget", "highest")
    assert code == 0
    assert "Food" in out and "500.00 USD" in out
    assert "Transport" not in out


def test_highest_with_no_budgets(db_path, capsys):
    code, out = run(capsys, "budget", "highest")
    assert code in (0, 3)
    assert "Traceback" not in out


def test_existing_budget_show_still_works(db_path, capsys):
    run(capsys, "budget", "set", "Food", "200")
    run(capsys, "add", "50", "G", "--category", "Food", "--date", "2025-03-03")
    code, out = run(capsys, "budget", "show", "--month", "2025-03")
    assert code == 0 and "25%" in out
