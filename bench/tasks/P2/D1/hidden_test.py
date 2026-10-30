import re

import pytest

from ledgerly import cli


def test_version_flag(capsys):
    with pytest.raises(SystemExit) as exc:
        cli.main(["--version"])
    assert exc.value.code == 0
    captured = capsys.readouterr()
    assert re.search(r"\b0\.1\.0\b", captured.out + captured.err)


def test_commands_still_work(db_path, capsys):
    assert cli.main(["categories"]) == 0
    assert "Food" in capsys.readouterr().out
