import sqlite3
from datetime import date

from ledgerly import cli, db, config
from ledgerly.services import report_service

TODAY = date.today().strftime(config.DATE_FORMAT)
MONTH = date.today().strftime(config.MONTH_FORMAT)


def run(capsys, *argv):
    code = cli.main(list(argv))
    return code, capsys.readouterr().out


def raw_rows(db_path):
    con = sqlite3.connect(db_path)
    con.row_factory = sqlite3.Row
    try:
        return [dict(r) for r in con.execute("SELECT * FROM expenses ORDER BY id")]
    finally:
        con.close()


def category_total(db_path, name):
    conn = db.get_connection()
    try:
        report = report_service.monthly_report(conn, MONTH)
    finally:
        conn.close()
    for line in report.lines:
        if line.category == name:
            return line.total_cents
    return 0


def test_full_refund_default_amount(db_path, capsys):
    run(capsys, "add", "25", "Headphones", "--category", "Transport", "--date", TODAY)
    code, out = run(capsys, "refund", "1")
    assert code == 0
    rows = raw_rows(db_path)
    assert len(rows) == 2
    original, refund = rows
    assert original["amount_cents"] == 2500 and original["description"] == "Headphones"
    assert refund["amount_cents"] == -2500
    assert refund["refund_of"] == original["id"]
    assert original["refund_of"] is None
    assert category_total(db_path, "Transport") == 0


def test_partial_refund_nets_into_original_category(db_path, capsys):
    run(capsys, "add", "25", "Shirt", "--category", "Other", "--date", TODAY)
    run(capsys, "add", "40", "Dinner", "--category", "Food", "--date", TODAY)
    code, out = run(capsys, "refund", "1", "10")
    assert code == 0
    rows = raw_rows(db_path)
    refund = [r for r in rows if r["refund_of"] == 1]
    assert len(refund) == 1 and refund[0]["amount_cents"] == -1000
    assert refund[0]["category_id"] == rows[0]["category_id"]
    assert category_total(db_path, "Other") == 1500
    assert category_total(db_path, "Food") == 4000
    code, out = run(capsys, "list")
    assert "-10.00 USD" in out
    code, out = run(capsys, "report", "--month", MONTH)
    assert "15.00 USD" in out


def test_refund_more_than_original_is_conflict(db_path, capsys):
    run(capsys, "add", "25", "Shirt", "--category", "Other", "--date", TODAY)
    code, out = run(capsys, "refund", "1", "25.01")
    assert code == 4
    assert out.startswith("error:")
    assert len(raw_rows(db_path)) == 1
    assert category_total(db_path, "Other") == 2500


def test_refund_exactly_original_amount_allowed(db_path, capsys):
    run(capsys, "add", "25", "Shirt", "--category", "Other", "--date", TODAY)
    code, out = run(capsys, "refund", "1", "25")
    assert code == 0
    assert category_total(db_path, "Other") == 0


def test_refund_unknown_expense(db_path, capsys):
    code, out = run(capsys, "refund", "99")
    assert code == 3


def test_original_never_deleted_or_edited(db_path, capsys):
    run(capsys, "add", "25", "Shirt", "--category", "Other", "--date", "2025-03-14")
    before = raw_rows(db_path)[0]
    run(capsys, "refund", "1", "5")
    after = raw_rows(db_path)[0]
    assert before == after
