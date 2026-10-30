import pytest

from ledgerly.errors import ValidationError
from ledgerly.money import format_cents, parse_amount


@pytest.mark.parametrize(
    "text, expected",
    [
        ("12", 1200),
        ("12.5", 1250),
        ("12.50", 1250),
        ("0.01", 1),
        ("  3.99 ", 399),
        ("1000", 100000),
    ],
)
def test_parse_amount_valid(text, expected):
    assert parse_amount(text) == expected


@pytest.mark.parametrize(
    "text", ["", "abc", "1.234", "0", "-5", "NaN", "Infinity", "1,5"]
)
def test_parse_amount_invalid(text):
    with pytest.raises(ValidationError):
        parse_amount(text)


def test_parse_amount_returns_int():
    assert isinstance(parse_amount("19.99"), int)


def test_format_cents():
    assert format_cents(1250) == "12.50 USD"
    assert format_cents(5) == "0.05 USD"
    assert format_cents(123456789) == "1,234,567.89 USD"


def test_format_cents_negative_and_currency():
    assert format_cents(-250, currency="EUR") == "-2.50 EUR"
