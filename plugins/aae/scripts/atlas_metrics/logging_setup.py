"""JSON-structured logging to stderr. stdout is reserved for the report."""

from __future__ import annotations

import json
import logging
import os
import sys

from atlas_metrics.constants import ENGINE_NAME, LOG_LEVEL_ENV

_RESERVED = set(vars(logging.makeLogRecord({})).keys()) | {"message", "asctime"}


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "ts": self.formatTime(record, "%Y-%m-%dT%H:%M:%S%z"),
            "level": record.levelname.lower(),
            "logger": record.name,
            "msg": record.getMessage(),
        }
        for key, value in vars(record).items():
            if key not in _RESERVED:
                payload[key] = value
        if record.exc_info:
            payload["exc"] = self.formatException(record.exc_info)
        return json.dumps(payload, default=str)


def configure_logging(level_name: str = "") -> logging.Logger:
    level = (level_name or os.environ.get(LOG_LEVEL_ENV) or "warning").upper()
    if level not in logging._nameToLevel:  # noqa: SLF001 - stdlib has no public lookup
        raise ValueError(f"unknown log level {level!r}; use debug, info, warning or error")
    handler = logging.StreamHandler(sys.stderr)
    handler.setFormatter(JsonFormatter())
    root = logging.getLogger(ENGINE_NAME)
    root.handlers[:] = [handler]
    root.setLevel(level)
    root.propagate = False
    return root


def get_logger(name: str) -> logging.Logger:
    return logging.getLogger(f"{ENGINE_NAME}.{name}")
