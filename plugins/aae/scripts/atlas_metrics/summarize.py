"""Turn Atlas measurement series into statistics, verdicts and comparisons.

Atlas returns `null` for intervals with no sample. Those are counted as gaps,
never as zero: averaging a gap as 0 makes a down host look idle.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Any, Dict, Iterable, List, Optional

from atlas_metrics.constants import (
    REPORTING_DELAY_SECONDS,
    STALE_GRANULARITY_STEPS,
    Direction,
    Severity,
)
from atlas_metrics.errors import ConfigError
from atlas_metrics.profiles import Threshold

_SEVERITY_RANK = {Severity.OK: 0, Severity.NO_DATA: 0, Severity.WARN: 1, Severity.CRIT: 2}


@dataclass
class SeriesSummary:
    name: str
    units: str
    points: int
    gaps: int
    min: Optional[float]
    avg: Optional[float]
    max: Optional[float]
    last: Optional[float]
    p95: Optional[float]
    peak_at: str
    values: int = 0
    last_at: str = ""
    stale: bool = False
    severity: Severity = Severity.OK
    threshold: Optional[Dict[str, Any]] = None
    baseline: Optional[Dict[str, Any]] = None

    def stat(self, key: str) -> Optional[float]:
        return getattr(self, key)

    def to_dict(self) -> Dict[str, Any]:
        out = {k: getattr(self, k) for k in
               ("name", "units", "points", "gaps", "min", "avg", "max", "last", "p95", "peak_at",
                "last_at", "stale")}
        out["severity"] = str(self.severity)
        if self.threshold:
            out["threshold"] = self.threshold
        if self.baseline:
            out["baseline"] = self.baseline
        return out


def _p95(values: List[float]) -> float:
    ordered = sorted(values)
    index = max(0, int(round(0.95 * (len(ordered) - 1))))
    return ordered[index]


def summarize_series(raw: Dict[str, Any]) -> SeriesSummary:
    name = raw.get("name") or raw.get("metricName") or "?"
    points = raw.get("dataPoints") or []
    present = [(p.get("timestamp", ""), p["value"]) for p in points if p.get("value") is not None]
    values = [float(v) for _, v in present]
    if not values:
        return SeriesSummary(name=name, units=raw.get("units", ""), points=len(points),
                             gaps=len(points), min=None, avg=None, max=None, last=None, p95=None,
                             peak_at="", severity=Severity.NO_DATA)
    peak_ts, _ = max(present, key=lambda item: item[1])
    return SeriesSummary(
        name=name,
        units=raw.get("units", ""),
        points=len(points),
        gaps=len(points) - len(values),
        min=min(values),
        avg=sum(values) / len(values),
        max=max(values),
        last=values[-1],
        p95=_p95(values),
        peak_at=peak_ts,
        values=len(values),
        last_at=present[-1][0],
    )


def check_reporting(summary: SeriesSummary, end: datetime, step_seconds: int,
                    expected_points: int, parse) -> None:
    """For one node's series over a known window: count gaps against the points the window
    should hold (Atlas also returns empty placeholder points between real ones, which are not
    missing data), and mark the series stale if its last real point is too old."""
    if summary.severity is Severity.NO_DATA:
        summary.gaps = expected_points
        return
    summary.gaps = max(0, expected_points - summary.values)
    if not summary.last_at:
        raise ConfigError(f"{summary.name}: a data point has a value but no timestamp")
    silent = (end - parse(summary.last_at)).total_seconds()
    summary.stale = silent > STALE_GRANULARITY_STEPS * step_seconds + REPORTING_DELAY_SECONDS


def evaluate(summary: SeriesSummary, threshold: Optional[Threshold]) -> SeriesSummary:
    if threshold is None or summary.severity is Severity.NO_DATA:
        return summary
    if threshold.units and summary.units and threshold.units != summary.units:
        raise ConfigError(
            f"threshold for {summary.name} expects units {threshold.units}, but Atlas "
            f"returned {summary.units}. Fix the profile's 'units' (and the numbers) to match."
        )
    value = summary.stat(threshold.stat)
    severity = Severity.OK
    if value is not None:
        if _crossed(value, threshold.crit, threshold.direction):
            severity = Severity.CRIT
        elif _crossed(value, threshold.warn, threshold.direction):
            severity = Severity.WARN
    summary.severity = severity
    summary.threshold = threshold.to_dict()
    return summary


def _crossed(value: float, limit: Optional[float], direction: Direction) -> bool:
    if limit is None:
        return False
    return value >= limit if direction is Direction.ABOVE else value <= limit


def attach_baseline(current: SeriesSummary, baseline: SeriesSummary) -> SeriesSummary:
    """Compare against the same series in an earlier window (avg and max)."""
    def delta(now: Optional[float], then: Optional[float]) -> Optional[float]:
        if now is None or then is None or then == 0:
            return None
        return round(100.0 * (now - then) / abs(then), 1)

    current.baseline = {
        "avg": baseline.avg, "max": baseline.max,
        "avg_change_pct": delta(current.avg, baseline.avg),
        "max_change_pct": delta(current.max, baseline.max),
    }
    return current


def worst(severities: Iterable[Severity]) -> Severity:
    result = Severity.OK
    for sev in severities:
        if _SEVERITY_RANK[sev] > _SEVERITY_RANK[result]:
            result = sev
    return result


# ------------------------------------------------------------------ formatting

_BYTE_UNITS = ("B", "KB", "MB", "GB", "TB", "PB")


def human(value: Optional[float], units: str) -> str:
    if value is None:
        return "—"
    if units == "BYTES":
        size, step = float(value), 0
        while abs(size) >= 1024 and step < len(_BYTE_UNITS) - 1:
            size, step = size / 1024, step + 1
        return f"{size:.1f} {_BYTE_UNITS[step]}"
    if units == "BYTES_PER_SECOND":
        return human(value, "BYTES") + "/s"
    if units == "KILOBYTES":
        return human(float(value) * 1024, "BYTES")
    if units == "MEGABYTES":
        return human(float(value) * 1024 * 1024, "BYTES")
    if units == "SECONDS":
        if value < 120:
            return f"{value:.1f} s"
        if value < 2 * 3600:
            return f"{value / 60:.1f} min"
        if value < 2 * 86400:
            return f"{value / 3600:.1f} h"
        return f"{value / 86400:.1f} days"
    if units == "PERCENT":
        return f"{value:.1f}%"
    if units == "MICROSECONDS":
        return f"{value / 1000:.2f} ms"
    if units == "MILLISECONDS":
        return f"{value:.1f} ms" if value < 10000 else f"{value / 1000:.1f} s"
    if units == "SCALAR_PER_SECOND":
        return f"{value:,.1f}/s"
    if units == "MEGABYTES_PER_SECOND":
        return f"{value:.2f} MB/s"
    if units in ("GIGABYTES", "GIGABYTES_PER_HOUR"):
        return f"{value:.2f} GB" + ("/h" if units.endswith("HOUR") else "")
    if float(value).is_integer():
        return f"{int(value):,}"
    return f"{value:,.2f}"
