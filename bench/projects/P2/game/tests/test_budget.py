import pytest

from ledgerly.errors import NotFoundError, ValidationError
from ledgerly.services import budget_service, expense_service


def test_set_budget_returns_cents(conn):
    assert budget_service.set_budget(conn, "Food", "300") == 30000


def test_set_budget_overwrites(conn):
    budget_service.set_budget(conn, "Food", "300")
    budget_service.set_budget(conn, "Food", "250.25")
    status = budget_service.month_status(conn, "Food", "2025-03")
    assert status.limit == 25025


def test_set_budget_validates(conn):
    with pytest.raises(ValidationError):
        budget_service.set_budget(conn, "Food", "-1")
    with pytest.raises(NotFoundError):
        budget_service.set_budget(conn, "Nope", "10")


def test_month_status_counts_only_that_month(conn):
    budget_service.set_budget(conn, "Food", "100")
    expense_service.add_expense(conn, "30", "A", "Food", "2025-03-02")
    expense_service.add_expense(conn, "12.34", "B", "Food", "2025-03-20")
    expense_service.add_expense(conn, "50", "C", "Food", "2025-04-01")
    expense_service.add_expense(conn, "70", "D", "Transport", "2025-03-05")
    status = budget_service.month_status(conn, "Food", "2025-03")
    assert status.category == "Food"
    assert status.limit == 10000
    assert status.spent == 4234


def test_month_status_without_budget(conn):
    with pytest.raises(NotFoundError):
        budget_service.month_status(conn, "Health", "2025-03")


def test_all_statuses(conn):
    budget_service.set_budget(conn, "Food", "100")
    budget_service.set_budget(conn, "Transport", "50")
    statuses = budget_service.all_statuses(conn, "2025-03")
    assert [s.category for s in statuses] == ["Food", "Transport"]
    assert all(s.spent == 0 for s in statuses)
