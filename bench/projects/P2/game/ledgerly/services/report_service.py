import sqlite3
from dataclasses import dataclass

from ledgerly.repositories import expenses as expense_repo
from ledgerly.services.expense_service import validate_month


@dataclass(frozen=True)
class CategoryTotal:
    category: str
    total_cents: int


@dataclass(frozen=True)
class MonthlyReport:
    month: str
    lines: list[CategoryTotal]

    @property
    def total_cents(self) -> int:
        return sum(line.total_cents for line in self.lines)


def monthly_report(conn: sqlite3.Connection, month: str) -> MonthlyReport:
    validate_month(month)
    rows = expense_repo.totals_by_category(conn, month)
    lines = [CategoryTotal(row["category"], int(row["total_cents"])) for row in rows]
    return MonthlyReport(month=month, lines=lines)
