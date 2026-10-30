import sqlite3
from dataclasses import dataclass

from ledgerly import money
from ledgerly.errors import NotFoundError
from ledgerly.logging_setup import get_logger
from ledgerly.repositories import budgets as budget_repo
from ledgerly.repositories import expenses as expense_repo
from ledgerly.services import category_service
from ledgerly.services.expense_service import validate_month

log = get_logger(__name__)


@dataclass(frozen=True)
class BudgetStatus:
    category: str
    limit: int
    spent: int

    @property
    def remaining(self) -> int:
        """Limit minus spent, in cents. Negative when the budget is exceeded."""
        return self.limit - self.spent

    @property
    def percent_used(self) -> int:
        """Spent as a whole percent of the limit, rounded down. Can exceed 100."""
        return self.spent * 100 // self.limit


def set_budget(conn: sqlite3.Connection, category_name: str, amount_text: str) -> int:
    category = category_service.require_category(conn, category_name)
    cents = money.parse_amount(amount_text)
    budget_repo.set_limit(conn, category["id"], cents)
    conn.commit()
    log.info("budget for %s set to %s cents", category["name"], cents)
    return cents


def month_status(conn: sqlite3.Connection, category_name: str, month: str) -> BudgetStatus:
    validate_month(month)
    category = category_service.require_category(conn, category_name)
    limit = budget_repo.get_limit(conn, category["id"])
    if limit is None:
        raise NotFoundError(f"No budget set for {category['name']}")
    spent = expense_repo.sum_for_category(conn, category["id"], month)
    return BudgetStatus(category=category["name"], limit=limit, spent=spent)


def all_statuses(conn: sqlite3.Connection, month: str) -> list[BudgetStatus]:
    validate_month(month)
    return [month_status(conn, row["category"], month) for row in budget_repo.list_limits(conn)]
