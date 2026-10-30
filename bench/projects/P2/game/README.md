# Ledgerly

Ledgerly is a small personal expense tracker for the command line. Expenses are
stored in a local SQLite database, grouped by category, and can be summarised
per month and checked against monthly budgets.

## Usage

```
python -m ledgerly add 12.50 "Lunch with Sam" --category Food --date 2025-03-14
python -m ledgerly list
python -m ledgerly list --month 2025-03
python -m ledgerly report --month 2025-03
python -m ledgerly budget set Food 300
python -m ledgerly budget show --month 2025-03
python -m ledgerly categories
```

The database lives in `ledgerly.db` in the current directory. Set the
`LEDGERLY_DB` environment variable to use a different file.

## Tests

```
python -m pytest
```
