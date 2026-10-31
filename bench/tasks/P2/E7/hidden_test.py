import pytest

from ledgerly import money
from ledgerly.errors import AppError


@pytest.mark.parametrize("total, parts, expected", [
    (1000, 3, [334, 333, 333]),
    (1000, 4, [250, 250, 250, 250]),
    (1, 3, [1, 0, 0]),
    (0, 2, [0, 0]),
    (101, 2, [51, 50]),
    (7, 1, [7]),
    (1250, 6, [209, 209, 208, 208, 208, 208]),
])
def test_split_examples(total, parts, expected):
    assert money.split_cents(total, parts) == expected


def test_split_invariants():
    for total in range(0, 2000, 37):
        for parts in range(1, 10):
            shares = money.split_cents(total, parts)
            assert len(shares) == parts
            assert sum(shares) == total
            assert all(isinstance(s, int) for s in shares)
            assert max(shares) - min(shares) <= 1
            assert shares == sorted(shares, reverse=True)


@pytest.mark.parametrize("parts", [0, -1, -5])
def test_rejects_bad_parts(parts):
    with pytest.raises(AppError):
        money.split_cents(100, parts)


def test_existing_helpers_unchanged():
    assert money.parse_amount("12.50") == 1250
    assert money.format_cents(123456) == "1,234.56 USD"
