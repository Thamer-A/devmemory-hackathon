"""Runtime configuration. Environment access is centralised here."""

import os

DEFAULT_DB_PATH = "ledgerly.db"
DEFAULT_CURRENCY = "USD"
MAX_DESCRIPTION_LEN = 120
DATE_FORMAT = "%Y-%m-%d"
MONTH_FORMAT = "%Y-%m"
DEFAULT_CATEGORIES = [
    "Food",
    "Transport",
    "Housing",
    "Utilities",
    "Entertainment",
    "Health",
    "Other",
]
FALLBACK_CATEGORY = "Other"


def get_db_path() -> str:
    return os.environ.get("LEDGERLY_DB", DEFAULT_DB_PATH)


def get_log_level() -> str:
    return os.environ.get("LEDGERLY_LOG", "WARNING").upper()
