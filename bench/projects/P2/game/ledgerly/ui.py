"""Terminal output. All user-facing text goes through this module."""

from typing import Sequence


def emit(text: str = "") -> None:
    print(text)


def emit_table(rows: Sequence[Sequence[object]], headers: Sequence[str]) -> None:
    cells = [[str(c) for c in row] for row in rows]
    widths = [len(h) for h in headers]
    for row in cells:
        for i, cell in enumerate(row):
            widths[i] = max(widths[i], len(cell))

    def line(values: Sequence[str]) -> str:
        return "  ".join(v.ljust(w) for v, w in zip(values, widths)).rstrip()

    emit(line(list(headers)))
    emit(line(["-" * w for w in widths]))
    for row in cells:
        emit(line(row))
