# Ledgerly

Personal expense tracker CLI (Python 3.10+, stdlib only, SQLite).

## Layout
- `ledgerly/cli.py` argparse commands; `ledgerly/ui.py` terminal output
- `ledgerly/services/` business rules; `ledgerly/repositories/` all SQL
- `ledgerly/config.py`, `db.py`, `money.py`, `errors.py`, `logging_setup.py`
- `tests/` pytest suite (tmp sqlite DB via `LEDGERLY_DB`)

## Conventions
- Money is always integer cents; never use floats. Parse/format via `money.py`.
- Raise only `AppError` subclasses (`ValidationError`, `NotFoundError`, `ConflictError`).
- `os.environ` is read only in `config.py`.
- `sqlite3.connect` is called only in `db.py`.
- SQL lives only in `repositories/`; services call repositories with a `conn`.
- `print` is used only in `ui.py`; everything else goes through `ui.emit`.
- New behaviour gets tests in `tests/`.

## Tests
Run `python -m pytest -q` from the project root.
