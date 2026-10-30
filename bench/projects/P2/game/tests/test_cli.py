from ledgerly import cli


def run(capsys, *argv):
    code = cli.main(list(argv))
    return code, capsys.readouterr().out


def test_add_and_list(db_path, capsys):
    code, out = run(capsys, "add", "12.50", "Lunch", "--category", "Food", "--date", "2025-03-14")
    assert code == 0
    assert "Added #1" in out
    code, out = run(capsys, "list")
    assert code == 0
    assert "Lunch" in out
    assert "12.50 USD" in out


def test_list_empty(db_path, capsys):
    code, out = run(capsys, "list", "--month", "2025-03")
    assert code == 0
    assert "No expenses found." in out


def test_report(db_path, capsys):
    run(capsys, "add", "10", "A", "--category", "Food", "--date", "2025-03-01")
    run(capsys, "add", "5", "B", "--category", "Transport", "--date", "2025-03-02")
    code, out = run(capsys, "report", "--month", "2025-03")
    assert code == 0
    assert "Food" in out
    assert "15.00 USD" in out


def test_budget_set_and_show(db_path, capsys):
    code, out = run(capsys, "budget", "set", "Food", "200")
    assert code == 0
    assert "200.00 USD" in out
    run(capsys, "add", "25", "Groceries", "--category", "Food", "--date", "2025-03-03")
    code, out = run(capsys, "budget", "show", "--month", "2025-03")
    assert code == 0
    assert "Food" in out
    assert "25.00 USD" in out


def test_categories(db_path, capsys):
    code, out = run(capsys, "categories")
    assert code == 0
    assert out.splitlines()[0] == "Food"
    assert "Other" in out.splitlines()


def test_validation_error_exit_code(db_path, capsys):
    code, out = run(capsys, "add", "1.999", "Lunch")
    assert code == 2
    assert out.startswith("error:")


def test_not_found_exit_code(db_path, capsys):
    code, out = run(capsys, "add", "5", "Thing", "--category", "Nope")
    assert code == 3
    assert "Unknown category" in out
