import pytest

from ledgerly import db
from ledgerly.services import category_service


@pytest.fixture
def db_path(tmp_path, monkeypatch):
    path = str(tmp_path / "test.db")
    monkeypatch.setenv("LEDGERLY_DB", path)
    return path


@pytest.fixture
def conn(db_path):
    connection = db.get_connection()
    db.init_schema(connection)
    category_service.ensure_defaults(connection)
    yield connection
    connection.close()
