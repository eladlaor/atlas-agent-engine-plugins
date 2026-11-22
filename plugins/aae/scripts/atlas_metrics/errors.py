"""Exception types. Each carries the exit code the CLI should end with."""

from __future__ import annotations

from typing import Any, Dict, Optional

from atlas_metrics.constants import EXIT_ATLAS, EXIT_NO_DATA, EXIT_USAGE


class MetricsError(Exception):
    """Base class. `context` is logged as structured fields."""

    exit_code = EXIT_USAGE

    def __init__(self, message: str, context: Optional[Dict[str, Any]] = None) -> None:
        super().__init__(message)
        self.context: Dict[str, Any] = dict(context or {})


class UsageError(MetricsError):
    """The request is malformed: a bad flag, an unknown profile, a bad window."""

    exit_code = EXIT_USAGE


class ConfigError(MetricsError):
    """The user's config file or a profile in it is invalid."""

    exit_code = EXIT_USAGE


class AtlasCliError(MetricsError):
    """The atlas binary is missing, failed, or returned something unparseable."""

    exit_code = EXIT_ATLAS


class InvalidMeasurementError(AtlasCliError):
    """Atlas rejected one measurement name for this node (INVALID_METRIC_NAME).

    Real clusters reject names the published spec lists: oplog lag exists only on
    secondaries, and some names are not offered on some tiers or versions.
    """

    def __init__(self, measurement: str, message: str, context: Optional[Dict[str, Any]] = None) -> None:
        super().__init__(message, context)
        self.measurement = measurement


class ReadOnlyViolation(MetricsError):
    """A command outside the read-only allowlist was about to run."""

    exit_code = EXIT_USAGE


class TopologyError(MetricsError):
    """The cluster, or the nodes asked for, could not be found."""

    exit_code = EXIT_ATLAS


class NoDataError(MetricsError):
    """Atlas answered, but with nothing to report for the request."""

    exit_code = EXIT_NO_DATA
