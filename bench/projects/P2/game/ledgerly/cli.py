"""Command line interface."""

import argparse
import sqlite3
from datetime import date
from typing import Sequence

from ledgerly import config, db, money, ui
from ledgerly.errors import AppError
from ledgerly.services import budget_service, category_service, expense_service, report_service


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="ledgerly", description="Personal expense tracker")
    sub = parser.add_subparsers(dest="command", required=True)

    add = sub.add_parser("add", help="record an expense")
    add.add_argument("amount")
    add.add_argument("description")
    add.add_argument("--category", default=config.FALLBACK_CATEGORY)
    add.add_argument("--date", dest="spent_on", default=None)

    ls = sub.add_parser("list", help="list expenses")
    ls.add_argument("--month", default=None, help="only this month (YYYY-MM)")

    report = sub.add_parser("report", help="monthly totals by category")
    report.add_argument("--month", required=True, help="month (YYYY-MM)")

    budget = sub.add_parser("budget", help="manage monthly budgets")
    budget_sub = budget.add_subparsers(dest="budget_command", required=True)
    budget_set = budget_sub.add_parser("set", help="set a category budget")
    budget_set.add_argument("category")
    budget_set.add_argument("amount")
    budget_show = budget_sub.add_parser("show", help="show budgets against spending")
    budget_show.add_argument("--month", default=None, help="month (YYYY-MM), default current")

    categories = sub.add_parser("categories", help="list categories")
    categories.add_argument(
        "--sort-by-name", action="store_true", help="sort alphabetically instead of by id"
    )
    return parser


def _cmd_add(conn: sqlite3.Connection, args: argparse.Namespace) -> None:
    record = expense_service.add_expense(
        conn, args.amount, args.description, args.category, args.spent_on
    )
    ui.emit(
        f"Added #{record.id}: {money.format_cents(record.amount_cents)} "
        f"{record.category} on {record.spent_on}"
    )


def _cmd_list(conn: sqlite3.Connection, args: argparse.Namespace) -> None:
    records = expense_service.list_expenses(conn, args.month)
    if not records:
        ui.emit("No expenses found.")
        return
    rows = [
        (r.id, r.spent_on, r.category, money.format_cents(r.amount_cents), r.description)
        for r in records
    ]
    ui.emit_table(rows, ["ID", "Date", "Category", "Amount", "Description"])


def _cmd_report(conn: sqlite3.Connection, args: argparse.Namespace) -> None:
    report = report_service.monthly_report(conn, args.month)
    if not report.lines:
        ui.emit(f"No expenses in {report.month}.")
        return
    rows = [(line.category, money.format_cents(line.total_cents)) for line in report.lines]
    rows.append(("Total", money.format_cents(report.total_cents)))
    ui.emit(f"Report for {report.month}")
    ui.emit_table(rows, ["Category", "Total"])


def _cmd_budget(conn: sqlite3.Connection, args: argparse.Namespace) -> None:
    if args.budget_command == "set":
        cents = budget_service.set_budget(conn, args.category, args.amount)
        ui.emit(f"Budget for {args.category} set to {money.format_cents(cents)}")
        return
    month = args.month or date.today().strftime(config.MONTH_FORMAT)
    statuses = budget_service.all_statuses(conn, month)
    if not statuses:
        ui.emit("No budgets set.")
        return
    rows = [
        (
            s.category,
            money.format_cents(s.limit),
            money.format_cents(s.spent),
            money.format_cents(s.remaining),
            f"{s.percent_used}%",
        )
        for s in statuses
    ]
    ui.emit(f"Budgets for {month}")
    ui.emit_table(rows, ["Category", "Limit", "Spent", "Remaining", "Used"])


def _cmd_categories(conn: sqlite3.Connection, args: argparse.Namespace) -> None:
    names = category_service.list_categories(conn)
    if args.sort_by_name:
        names = sorted(names, key=str.casefold)
    for name in names:
        ui.emit(name)


_HANDLERS = {
    "add": _cmd_add,
    "list": _cmd_list,
    "report": _cmd_report,
    "budget": _cmd_budget,
    "categories": _cmd_categories,
}


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    conn = db.get_connection()
    try:
        db.init_schema(conn)
        category_service.ensure_defaults(conn)
        _HANDLERS[args.command](conn, args)
    except AppError as exc:
        ui.emit(f"error: {exc}")
        return exc.exit_code
    finally:
        conn.close()
    return 0
