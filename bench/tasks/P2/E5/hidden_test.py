from ledgerly import cli, db
from ledgerly.services import budget_service


def run(capsys, *argv):
    try:
        code = cli.main(list(argv))
    except SystemExit as exc:
        code = exc.code
    return code, capsys.readouterr().out


def limits():
    conn = db.get_connection()
    try:
        return {s.category: s.limit for s in budget_service.all_statuses(conn, "2025-03")}
    finally:
        conn.close()


def seed(capsys):
    run(capsys, "budget", "set", "Food", "200")
    run(capsys, "budget", "set", "Transport", "33.33")


def test_raise_all_limits(db_path, capsys):
    seed(capsys)
    code, out = run(capsys, "budget", "adjust", "10")
    assert code == 0
    assert limits() == {"Food": 22000, "Transport": 3666}
    code, out = run(capsys, "budget", "show", "--month", "2025-03")
    assert "220.00 USD" in out and "36.66 USD" in out


def test_lower_all_limits_rounds_down(db_path, capsys):
    seed(capsys)
    code, out = run(capsys, "budget", "adjust", "-25")
    assert code == 0
    assert limits() == {"Food": 15000, "Transport": 2499}


def test_adjustments_compound(db_path, capsys):
    run(capsys, "budget", "set", "Food", "100")
    run(capsys, "budget", "adjust", "10")
    run(capsys, "budget", "adjust", "10")
    assert limits() == {"Food": 12100}


def test_refuses_zero_or_negative_result(db_path, capsys):
    seed(capsys)
    for pct in ("-100", "-150"):
        code, out = run(capsys, "budget", "adjust", pct)
        assert code in (2, 4)
        assert "Traceback" not in out
    assert limits() == {"Food": 20000, "Transport": 3333}


def test_rejects_non_numeric_percent(db_path, capsys):
    seed(capsys)
    code, _ = run(capsys, "budget", "adjust", "lots")
    assert code == 2
    assert limits() == {"Food": 20000, "Transport": 3333}


def test_no_budgets(db_path, capsys):
    code, out = run(capsys, "budget", "adjust", "10")
    assert code in (0, 3)
    assert "Traceback" not in out
