from ledgerly import cli


def run(capsys, *argv):
    try:
        code = cli.main(list(argv))
    except SystemExit as exc:
        code = exc.code
    return code, capsys.readouterr().out


def seed(capsys):
    run(capsys, "add", "10", "Lunch", "--category", "Food", "--date", "2025-03-01")
    run(capsys, "add", "4", "Bus", "--category", "Transport", "--date", "2025-03-02")
    run(capsys, "budget", "set", "Food", "200")


def test_rename_moves_expenses_and_budget(db_path, capsys):
    seed(capsys)
    code, out = run(capsys, "rename-category", "Food", "Groceries")
    assert code == 0
    code, out = run(capsys, "list")
    assert code == 0
    assert "Groceries" in out and "Lunch" in out
    assert "Food" not in out
    code, out = run(capsys, "budget", "show", "--month", "2025-03")
    assert code == 0
    assert "Groceries" in out and "200.00 USD" in out and "10.00 USD" in out
    code, out = run(capsys, "report", "--month", "2025-03")
    assert "Groceries" in out and "Food" not in out


def test_new_name_usable_old_name_gone(db_path, capsys):
    seed(capsys)
    run(capsys, "rename-category", "Food", "Groceries")
    code, _ = run(capsys, "add", "5", "Snack", "--category", "Groceries", "--date", "2025-03-03")
    assert code == 0
    code, _ = run(capsys, "add", "5", "Snack", "--category", "Food", "--date", "2025-03-03")
    assert code == 3
    code, out = run(capsys, "categories")
    names = out.splitlines()
    assert "Groceries" in names
    assert "Food" not in names
    assert len(names) == 7


def test_rename_onto_existing_is_refused(db_path, capsys):
    seed(capsys)
    code, out = run(capsys, "rename-category", "Food", "Transport")
    assert code in (2, 4)
    assert "Traceback" not in out
    code, out = run(capsys, "categories")
    names = out.splitlines()
    assert "Food" in names and "Transport" in names
    code, out = run(capsys, "list")
    assert "Food" in out


def test_rename_unknown_category(db_path, capsys):
    code, _ = run(capsys, "rename-category", "Nope", "Other2")
    assert code == 3
