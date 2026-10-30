# game — project map

Engine: python. Files indexed: 25. Built deterministically (0 LLM tokens) at 2026-10-30T18:45:57+00:00.

## Conventions (observed)
- `SQL statements` occurs only in ledgerly/repositories/ (observed); go through that module instead of repeating it.
- `float() on money` occurs nowhere in source (observed); avoid introducing it.
- `os.environ / settings reads` occurs only in ledgerly/config.py (observed); go through that module instead of repeating it.
- `print(` occurs only in ledgerly/ui.py (observed); go through that module instead of repeating it.
- `raise Exception/ValueError` occurs nowhere in source (observed); avoid introducing it.
- `sqlite3.connect / DB connection` occurs only in ledgerly/db.py (observed); go through that module instead of repeating it.
- `errors.ValidationError(...)` is the shared entry point, called from 6 files.
- `errors.NotFoundError(...)` is the shared entry point, called from 5 files.
- Tunables live in `ledgerly/config.py` (7 keys, used by 7 files); add new constants there.

## Files
- `ledgerly/__init__.py`
- `ledgerly/__main__.py`
- `ledgerly/cli.py` — fn: _cmd_add, _cmd_budget, _cmd_categories, _cmd_list, _cmd_report, build_parser, main
- `ledgerly/config.py` — fn: get_db_path, get_log_level; 7 config keys
- `ledgerly/db.py` — fn: get_connection, init_schema
- `ledgerly/errors.py` — fn: AppError, ConflictError, NotFoundError, ValidationError
- `ledgerly/logging_setup.py` — fn: get_logger
- `ledgerly/money.py` — fn: format_cents, parse_amount
- `ledgerly/ui.py` — fn: emit, emit_table
- `ledgerly/repositories/__init__.py`
- `ledgerly/repositories/budgets.py` — fn: get_limit, list_limits, set_limit
- `ledgerly/repositories/categories.py` — fn: add, ensure, get_by_name, list_all
- `ledgerly/repositories/expenses.py` — fn: add, delete, get, list_expenses, sum_for_category, totals_by_category
- `ledgerly/services/__init__.py`
- `ledgerly/services/budget_service.py` — fn: BudgetStatus, all_statuses, set_budget, status_for_month
- `ledgerly/services/category_service.py` — fn: ensure_defaults, list_categories, require_category
- `ledgerly/services/expense_service.py` — fn: ExpenseRecord, _to_record, add_expense, delete_expense, get_expense, list_expenses, validate_month, validate_spent_on
- `ledgerly/services/report_service.py` — fn: CategoryTotal, MonthlyReport, monthly_report
- `tests/conftest.py` — fn: conn, db_path
- `tests/test_budget.py` — fn: test_all_statuses, test_month_status_counts_only_that_month, test_month_status_without_budget, test_percent_used_can_exceed_100, test_percent_used_floors_small_fractions, test_percent_used_rounds_down, test_percent_used_zero_when_nothing_spent, test_remaining_is_limit_minus_spent
- `tests/test_cli.py` — fn: run, test_add_and_list, test_add_rejects_non_iso_date, test_budget_set_and_show, test_budget_show_remaining_negative_when_overspent, test_categories, test_categories_sort_by_name, test_list_empty
- `tests/test_expenses.py` — fn: test_add_accepts_iso_date_with_surrounding_space, test_add_and_get, test_add_defaults_to_today, test_add_rejects_bad_input, test_add_rejects_non_iso_dates, test_add_unknown_category, test_delete, test_errors_share_a_base_class
- `tests/test_money.py` — fn: test_format_cents, test_format_cents_negative_and_currency, test_parse_amount_invalid, test_parse_amount_returns_int, test_parse_amount_valid
