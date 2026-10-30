from ledgerly import cli


def run(capsys, *argv):
    code = cli.main(list(argv))
    return code, capsys.readouterr().out


def seed(capsys):
    run(capsys, "add", "10", "Lunch with Sam", "--category", "Food", "--date", "2025-03-01")
    run(capsys, "add", "5", "Bus fare", "--category", "Transport", "--date", "2025-03-02")
    run(capsys, "add", "7", "Team LUNCH", "--category", "Food", "--date", "2025-04-03")
    run(capsys, "add", "9", "Sale 50% off", "--category", "Other", "--date", "2025-03-04")


def test_search_case_insensitive(db_path, capsys):
    seed(capsys)
    code, out = run(capsys, "list", "--search", "lunch")
    assert code == 0
    assert "Lunch with Sam" in out
    assert "Team LUNCH" in out
    assert "Bus fare" not in out
    assert "Sale 50% off" not in out


def test_search_combines_with_month(db_path, capsys):
    seed(capsys)
    code, out = run(capsys, "list", "--search", "lunch", "--month", "2025-04")
    assert code == 0
    assert "Team LUNCH" in out
    assert "Lunch with Sam" not in out


def test_search_is_plain_text_not_pattern(db_path, capsys):
    seed(capsys)
    code, out = run(capsys, "list", "--search", "50%")
    assert code == 0
    assert "Sale 50% off" in out
    assert "Lunch with Sam" not in out
    assert "Bus fare" not in out
    code, out = run(capsys, "list", "--search", "_")
    assert "Lunch with Sam" not in out


def test_search_no_match(db_path, capsys):
    seed(capsys)
    code, out = run(capsys, "list", "--search", "zebra")
    assert code == 0
    assert "Lunch" not in out and "Bus" not in out


def test_list_without_search_unchanged(db_path, capsys):
    seed(capsys)
    code, out = run(capsys, "list")
    assert code == 0
    for text in ("Lunch with Sam", "Bus fare", "Team LUNCH", "Sale 50% off"):
        assert text in out
