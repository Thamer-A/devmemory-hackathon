"""Logging configuration shared by the package."""

import logging

from ledgerly import config

_FORMAT = "%(asctime)s %(levelname)s %(name)s: %(message)s"
_configured = False


def get_logger(name: str) -> logging.Logger:
    global _configured
    if not _configured:
        handler = logging.StreamHandler()
        handler.setFormatter(logging.Formatter(_FORMAT))
        root = logging.getLogger("ledgerly")
        root.addHandler(handler)
        root.setLevel(config.get_log_level())
        _configured = True
    return logging.getLogger(name)
