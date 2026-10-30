"""Money helpers. Amounts are carried around as integer cents."""

from decimal import Decimal, InvalidOperation

from ledgerly import config
from ledgerly.errors import ValidationError


def parse_amount(text: str) -> int:
    """Convert user text such as "12.5" into integer cents (1250)."""
    raw = (text or "").strip()
    if not raw:
        raise ValidationError("Amount is required")
    try:
        value = Decimal(raw)
    except InvalidOperation:
        raise ValidationError(f"Invalid amount: {raw!r}") from None
    if not value.is_finite():
        raise ValidationError(f"Invalid amount: {raw!r}")
    if value.as_tuple().exponent < -2:
        raise ValidationError("Amount cannot have more than 2 decimal places")
    if value <= 0:
        raise ValidationError("Amount must be greater than zero")
    return int(value * 100)


def format_cents(cents: int, currency: str = config.DEFAULT_CURRENCY) -> str:
    sign = "-" if cents < 0 else ""
    whole, fraction = divmod(abs(cents), 100)
    return f"{sign}{whole:,}.{fraction:02d} {currency}"
