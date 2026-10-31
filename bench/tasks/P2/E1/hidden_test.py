from ledgerly import cli


def run(capsys, *argv):
    try:
        code = cli.main(list(argv))
    except SystemExit as exc:  # argparse rejects bad option values this way
        code = exc.code
    captured = capsys.readouterr()
    return code, captured.out


def seed(capsys):
    rows = [
        ("12.50", "Lunch", "Food", "2025-03-01"),
        ("80", "Train pass", "Transport", "2025-03-02"),
        ("5", "Coffee", "Food", "2025-03-03"),
        ("1200", "Rent", "Housing", "2025-03-04"),
        ("45.99", "Concert", "Entertainment", "2025-03-05"),
        ("60", "Groceries", "Food", "2025-04-01"),
        ("30", "Pharmacy", "Health", "2025-04-02"),
    ]
    for amount, desc, category, day in rows:
        code, _ = run(capsys, "add", amount, desc, "--category", category, "--date", day)
        assert code == 0


def in_order(out, names):
    pos = [out.find(n) for n in names]
    return all(p >= 0 for p in pos) and pos == sorted(pos)


def test_top_defaults_to_five_largest(db_path, capsys):
    seed(capsys)
    code, out = run(capsys, "top")
    assert code == 0
    assert in_order(out, ["Rent", "Train pass", "Groceries", "Concert", "Pharmacy"])
    assert "Lunch" not in out and "Coffee" not in out
    assert "1,200.00 USD" in out


def test_top_limit(db_path, capsys):
    seed(capsys)
    code, out = run(capsys, "top", "--limit", "2")
    assert code == 0
    assert in_order(out, ["Rent", "Train pass"])
    assert "Groceries" not in out and "Concert" not in out


def test_top_month(db_path, capsys):
    seed(capsys)
    code, out = run(capsys, "top", "--month", "2025-04")
    assert code == 0
    assert in_order(out, ["Groceries", "Pharmacy"])
    assert "Rent" not in out and "Lunch" not in out


def test_top_month_and_limit(db_path, capsys):
    seed(capsys)
    code, out = run(capsys, "top", "--month", "2025-03", "--limit", "1")
    assert code == 0
    assert "Rent" in out
    assert "Train pass" not in out and "Groceries" not in out


def test_top_rejects_bad_input(db_path, capsys):
    seed(capsys)
    code, _ = run(capsys, "top", "--month", "March")
    assert code == 2
    code, _ = run(capsys, "top", "--limit", "0")
    assert code == 2


def test_top_empty(db_path, capsys):
    code, out = run(capsys, "top")
    assert code == 0
    assert "Traceback" not in out
