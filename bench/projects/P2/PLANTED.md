# P2 (ledgerly) planted facts

Synthetic Python fixture for benchmarking coding agents with and without project memory. The project agents see is `game/` (directory name kept for parity with P1); this file and the other top-level files are not visible to the agent.

## Planted conventions (discoverable from code; also listed in CLAUDE.baseline.md)

| ID | Convention | Where it holds in v0 |
|----|-----------|----------------------|
| K1 | Money is integer cents; no `float(` anywhere | `money.py`, all services/repos |
| K2 | Package raises only `AppError` subclasses | `errors.py`, services |
| K3 | `os.environ` only in `config.py` | `config.py` |
| K4 | `sqlite3.connect` only in `db.py` | `db.get_connection` |
| K5 | All SQL only in `repositories/` | `repositories/*.py` (db.py holds only DDL) |
| K6 | `print` only in `ui.py` | `ui.emit` / `ui.emit_table` |

## Planted history facts (come only from session-0 transcripts)

| ID | Fact | Session | Notes |
|----|------|---------|-------|
| H1 | Refunds plan: negative expense rows linked by nullable `refund_of`, originals never edited/deleted; refund > original raises ConflictError; reports net refunds into original category; CLI `refund EXPENSE_ID [AMOUNT]` defaulting to full amount | S0a (plan only, no edits) | Exists nowhere in code; a later refunds task should need it |
| H2 | Dates: `spent_on` always ISO `YYYY-MM-DD`, validated via `config.DATE_FORMAT`, else `ValidationError` (rationale: mixed stored formats broke month filters) | S0b (edits) | Rationale only in transcript |
| S1 | Budgets column is `budgets.monthly_limit` (cents) | S0c | Stale after v2: renamed to `limit_cents` |
| S2 | Function `budget_service.month_status` (returns percent used) | S0d | Stale after v2: renamed to `status_for_month` |
| D | Distractor: `categories --sort-by-name` | S0e | Irrelevant to later tasks |

v2 (uncaptured refactor, `apply_v2.py`): `monthly_limit` -> `limit_cents`, `month_status` -> `status_for_month`, applied by word-boundary regex across all `.py` files; fails loudly if either old name is absent.

## Absent from v0 by design
Refunds (and the word "refund"), CSV export, `--version`, recurring expenses, category rename, `limit_cents`.

## How it was generated
Hand-written by an AI agent (Claude) from a spec: stdlib-only Python, `game/` v0 with 4 test modules, `history_script.json` (prompts for headless sessions S0a-S0e, model haiku, run later on v0), `apply_v2.py` (deterministic refactor; accepts a target dir). Tests verified with `python -m pytest -q` in `game/`; convention greps and an `apply_v2.py` run on a scratch copy were checked at creation time. No benchmark results are implied by this fixture.
