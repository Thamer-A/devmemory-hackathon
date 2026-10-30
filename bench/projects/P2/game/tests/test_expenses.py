from datetime import date

import pytest

from ledgerly import config
from ledgerly.errors import AppError, NotFoundError, ValidationError
from ledgerly.services import expense_service, report_service


def test_add_and_get(conn):
    record = expense_service.add_expense(conn, "12.50", "Lunch", "Food", "2025-03-14")
    assert record.amount_cents == 1250
    assert record.category == "Food"
    fetched = expense_service.get_expense(conn, record.id)
    assert fetched == record


def test_add_defaults_to_today(conn):
    record = expense_service.add_expense(conn, "3", "Coffee", "food")
    assert record.spent_on == date.today().strftime(config.DATE_FORMAT)
    assert record.category == "Food"


def test_add_rejects_bad_input(conn):
    with pytest.raises(ValidationError):
        expense_service.add_expense(conn, "1.999", "Lunch", "Food")
    with pytest.raises(ValidationError):
        expense_service.add_expense(conn, "5", "   ", "Food")
    with pytest.raises(ValidationError):
        expense_service.add_expense(conn, "5", "x" * (config.MAX_DESCRIPTION_LEN + 1), "Food")


@pytest.mark.parametrize(
    "bad_date",
    [
        "14/03/2025",
        "2025-3-4",
        "2025/03/14",
        "2025-02-30",
        "14-03-2025",
        "March 14",
        "2025-03-14T00:00",
    ],
)
def test_add_rejects_non_iso_dates(conn, bad_date):
    with pytest.raises(ValidationError):
        expense_service.add_expense(conn, "5", "Lunch", "Food", bad_date)
    assert expense_service.list_expenses(conn) == []


def test_add_accepts_iso_date_with_surrounding_space(conn):
    record = expense_service.add_expense(conn, "5", "Lunch", "Food", " 2025-03-14 ")
    assert record.spent_on == "2025-03-14"


def test_add_unknown_category(conn):
    with pytest.raises(NotFoundError):
        expense_service.add_expense(conn, "5", "Thing", "Nope")


def test_errors_share_a_base_class(conn):
    with pytest.raises(AppError):
        expense_service.get_expense(conn, 999)


def test_list_filters_by_month(conn):
    expense_service.add_expense(conn, "10", "A", "Food", "2025-03-01")
    expense_service.add_expense(conn, "20", "B", "Food", "2025-04-02")
    expense_service.add_expense(conn, "30", "C", "Transport", "2025-03-20")
    assert len(expense_service.list_expenses(conn)) == 3
    march = expense_service.list_expenses(conn, "2025-03")
    assert [r.description for r in march] == ["A", "C"]


def test_list_rejects_bad_month(conn):
    with pytest.raises(ValidationError):
        expense_service.list_expenses(conn, "March")


def test_delete(conn):
    record = expense_service.add_expense(conn, "10", "A", "Food", "2025-03-01")
    expense_service.delete_expense(conn, record.id)
    with pytest.raises(NotFoundError):
        expense_service.get_expense(conn, record.id)
    with pytest.raises(NotFoundError):
        expense_service.delete_expense(conn, record.id)


def test_monthly_report_groups_by_category(conn):
    expense_service.add_expense(conn, "10", "A", "Food", "2025-03-01")
    expense_service.add_expense(conn, "5.50", "B", "Food", "2025-03-09")
    expense_service.add_expense(conn, "40", "C", "Transport", "2025-03-10")
    expense_service.add_expense(conn, "99", "D", "Food", "2025-04-01")
    report = report_service.monthly_report(conn, "2025-03")
    assert [(l.category, l.total_cents) for l in report.lines] == [
        ("Transport", 4000),
        ("Food", 1550),
    ]
    assert report.total_cents == 5550
