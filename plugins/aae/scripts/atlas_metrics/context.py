"""What every command receives: the CLI, the config, the parsed flags."""

from __future__ import annotations

import argparse
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Set

from atlas_metrics.atlas_cli import AtlasCli
from atlas_metrics.constants import OutputFormat, Severity
from atlas_metrics.errors import AtlasCliError
from atlas_metrics.profiles import Config
from atlas_metrics.report import Report
from atlas_metrics.summarize import SeriesSummary, human
from atlas_metrics.time_window import Window, iso


@dataclass
class RunContext:
    cli: AtlasCli
    config: Config
    args: argparse.Namespace
    fmt: OutputFormat
    notes: List[str] = field(default_factory=list)  # added to the report as warnings
    # Measurement names Atlas rejected, per process, so they aren't re-requested for
    # every disk or database of the same node.
    rejected: Dict[str, Set[str]] = field(default_factory=dict)

    def flag(self, name: str, config_key: str = "", fallback: str = "") -> str:
        """Flag value, else the config default, else the built-in fallback."""
        value = getattr(self.args, name, None)
        if value:
            return value
        return self.config.default(config_key or name) or fallback


def require_list(payload: Any, key: str, what: str) -> List[Any]:
    """The list under `key`, or a loud error. A missing key is a changed response
    format, not an empty result: Atlas returns empty lists as `[]` (checked live
    2026-11-22), so treating absence as "nothing found" would hide a break."""
    if not isinstance(payload, dict) or not isinstance(payload.get(key), list):
        raise AtlasCliError(f"{what}: expected a '{key}' list in the response, got: "
                            f"{str(payload)[:200]}")
    return payload[key]


def collect_atlas_notes(report: Report, payload: Any) -> None:
    """Keep Atlas's own warnings and tier limits; they explain empty results."""
    if not isinstance(payload, dict):
        return
    for key in ("warningMessage", "message"):
        if payload.get(key):
            report.add_warning(str(payload[key]))
    scale = payload.get("scale") or {}
    if scale.get("minimumTier"):
        report.add_warning(f"needs at least tier {scale['minimumTier']} "
                           f"({scale.get('docsUrl', 'see Atlas docs')})")


SERIES_COLUMNS = ["node", "measurement", "last", "avg", "max", "p95", "peak at", "gaps", "status"]
SNAPSHOT_COLUMNS = ["node", "measurement", "last", "max", "gaps", "status"]
COMPARE_COLUMNS = ["node", "measurement", "avg", "max", "baseline avg", "Δ avg %",
                   "baseline max", "Δ max %", "status"]


def series_row(scope: str, s: SeriesSummary, columns: List[str]) -> List[Any]:
    status = str(s.severity)
    if s.threshold is None and s.severity is Severity.OK:
        status = "no threshold"
    if s.stale:
        status = f"{status}, stale (silent since {s.last_at})"
    by_column: Dict[str, Any] = {
        "node": scope, "scope": scope, "namespace": scope, "measurement": s.name,
        "last": human(s.last, s.units), "avg": human(s.avg, s.units),
        "max": human(s.max, s.units), "min": human(s.min, s.units),
        "p95": human(s.p95, s.units), "peak at": s.peak_at, "gaps": s.gaps,
        "status": status,
    }
    if s.baseline:
        by_column.update({
            "baseline avg": human(s.baseline["avg"], s.units),
            "baseline max": human(s.baseline["max"], s.units),
            "Δ avg %": _pct(s.baseline["avg_change_pct"]),
            "Δ max %": _pct(s.baseline["max_change_pct"]),
        })
    return [by_column.get(c, "") for c in columns]


def series_data(scope: str, s: SeriesSummary) -> Dict[str, Any]:
    data = s.to_dict()
    data["scope"] = scope
    return data


def _pct(value: Optional[float]) -> str:
    return "—" if value is None else f"{value:+.1f}%"


def window_context(window: Window) -> Dict[str, str]:
    return {"window": f"{iso(window.start)} → {iso(window.end)}",
            "granularity": str(window.granularity)}
