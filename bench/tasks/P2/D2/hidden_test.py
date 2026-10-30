import pytest

from ledgerly.errors import ValidationError
from ledgerly.money import parse_amount
from ledgerly.services import expense_service


@pytest.mark.parametrize("text, cents", [("$12.50", 1250), ("$ 3", 300), (" $0.01 ", 1), ("12.50", 1250)])
def test_dollar_sign_optional(text, cents):
    assert parse_amount(text) == cents


@pytest.mark.parametrize("text", ["$", "$-1", "$0", "$abc", "$$5", "$1.999", ""])
def test_still_rejects_bad_input(text):
    with pytest.raises(ValidationError):
        parse_amount(text)


def test_add_expense_accepts_dollar_sign(conn):
    record = expense_service.add_expense(conn, "$4.25", "Snack", "Food", "2025-03-01")
    assert record.amount_cents == 425
