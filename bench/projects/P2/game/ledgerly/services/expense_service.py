import sqlite3
from dataclasses import dataclass
from datetime import date, datetime

from ledgerly import config, money
from ledgerly.errors import NotFoundError, ValidationError
from ledgerly.logging_setup import get_logger
from ledgerly.repositories import expenses as expense_repo
from ledgerly.services import category_service

log = get_logger(__name__)


@dataclass(frozen=True)
class ExpenseRecord:
    id: int
    amount_cents: int
    description: str
    category: str
    spent_on: str


def _to_record(row: sqlite3.Row) -> ExpenseRecord:
    return ExpenseRecord(
        id=row["id"],
        amount_cents=row["amount_cents"],
        description=row["description"],
        category=row["category"],
        spent_on=row["spent_on"],
    )


def validate_month(month: str) -> str:
    try:
        datetime.strptime(month, config.MONTH_FORMAT)
    except (TypeError, ValueError):
        raise ValidationError(f"Month must look like YYYY-MM, got {month!r}") from None
    return month


def add_expense(
    conn: sqlite3.Connection,
    amount_text: str,
    description: str,
    category_name: str,
    spent_on: str | None = None,
) -> ExpenseRecord:
    cents = money.parse_amount(amount_text)
    text = (description or "").strip()
    if not text:
        raise ValidationError("Description is required")
    if len(text) > config.MAX_DESCRIPTION_LEN:
        raise ValidationError(
            f"Description is longer than {config.MAX_DESCRIPTION_LEN} characters"
        )
    category = category_service.require_category(conn, category_name)
    when = (spent_on or "").strip() or date.today().strftime(config.DATE_FORMAT)

    created_at = datetime.now().isoformat(timespec="seconds")
    expense_id = expense_repo.add(conn, cents, text, category["id"], when, created_at)
    conn.commit()
    log.info("added expense %s (%s cents) to %s", expense_id, cents, category["name"])
    return get_expense(conn, expense_id)


def get_expense(conn: sqlite3.Connection, expense_id: int) -> ExpenseRecord:
    row = expense_repo.get(conn, expense_id)
    if row is None:
        raise NotFoundError(f"No expense with id {expense_id}")
    return _to_record(row)


def list_expenses(conn: sqlite3.Connection, month: str | None = None) -> list[ExpenseRecord]:
    if month is not None:
        validate_month(month)
    return [_to_record(row) for row in expense_repo.list_expenses(conn, month)]


def delete_expense(conn: sqlite3.Connection, expense_id: int) -> None:
    if not expense_repo.delete(conn, expense_id):
        raise NotFoundError(f"No expense with id {expense_id}")
    conn.commit()
    log.info("deleted expense %s", expense_id)
