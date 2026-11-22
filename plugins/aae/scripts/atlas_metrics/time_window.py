"""Time windows: parsing, granularity choice, and the shifted comparison window.

A window is always resolved to absolute UTC start/end, because three Atlas
families want three different encodings of the same range: ISO 8601 strings
(measurements), epoch milliseconds (Performance Advisor, query shapes) and
ISO dates (events). Resolving once keeps those three views consistent.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Optional

from atlas_metrics.constants import GRANULARITY_FALLBACK, GRANULARITY_RULES, Granularity
from atlas_metrics.errors import UsageError

_ISO_DURATION = re.compile(
    r"^P(?:(?P<days>\d+)D)?(?:T(?:(?P<hours>\d+)H)?(?:(?P<minutes>\d+)M)?(?:(?P<seconds>\d+)S)?)?$"
)
_SHORT_DURATION = re.compile(r"^(?P<n>\d+)(?P<unit>[smhdw])$")
_SHORT_UNITS = {"s": 1, "m": 60, "h": 3600, "d": 86400, "w": 7 * 86400}
_SECONDS_PER_GRANULARITY = {
    Granularity.TEN_SECONDS: 10,
    Granularity.ONE_MINUTE: 60,
    Granularity.FIVE_MINUTES: 300,
    Granularity.ONE_HOUR: 3600,
    Granularity.ONE_DAY: 86400,
}


def parse_duration(text: str) -> timedelta:
    """Accept ISO 8601 (PT6H, P7D, P1DT12H) or short form (90m, 6h, 7d, 2w)."""
    raw = text.strip()
    short = _SHORT_DURATION.match(raw.lower())
    if short:
        seconds = int(short["n"]) * _SHORT_UNITS[short["unit"]]
    else:
        iso = _ISO_DURATION.match(raw.upper())
        if not iso or raw.upper() in ("P", "PT"):
            raise UsageError(
                f"cannot read duration {text!r}; use ISO 8601 (PT15M, PT6H, P7D) "
                "or short form (15m, 6h, 7d, 2w)"
            )
        seconds = (
            int(iso["days"] or 0) * 86400
            + int(iso["hours"] or 0) * 3600
            + int(iso["minutes"] or 0) * 60
            + int(iso["seconds"] or 0)
        )
    if seconds <= 0:
        raise UsageError(f"duration {text!r} must be longer than zero")
    return timedelta(seconds=seconds)


def parse_instant(text: str) -> datetime:
    """Accept ISO 8601 with Z or offset; a naive value is taken as UTC."""
    raw = text.strip()
    if raw[-1:] in ("Z", "z"):
        raw = raw[:-1] + "+00:00"
    try:
        value = datetime.fromisoformat(raw)
    except ValueError as exc:
        raise UsageError(
            f"cannot read time {text!r}; use ISO 8601, e.g. 2026-11-20T14:00:00Z"
        ) from exc
    return value if value.tzinfo else value.replace(tzinfo=timezone.utc)


def iso(value: datetime) -> str:
    return value.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def epoch_ms(value: datetime) -> int:
    return int(value.timestamp() * 1000)


def choose_granularity(span: timedelta) -> Granularity:
    seconds = span.total_seconds()
    for upper_bound, granularity in GRANULARITY_RULES:
        if seconds <= upper_bound:
            return granularity
    return GRANULARITY_FALLBACK


@dataclass(frozen=True)
class Window:
    start: datetime
    end: datetime
    granularity: Granularity

    @property
    def span(self) -> timedelta:
        return self.end - self.start

    def shifted(self, back: timedelta) -> "Window":
        """The same-length window `back` earlier, at the same granularity."""
        return Window(self.start - back, self.end - back, self.granularity)

    def padded(self, pad: timedelta, keep_granularity: bool = False,
               now: Optional[datetime] = None) -> "Window":
        """Widen by `pad` on each side, never past now. Keeps a user-chosen granularity."""
        now = now or datetime.now(timezone.utc)
        start, end = self.start - pad, min(self.end + pad, now)
        return Window(start, end, self.granularity if keep_granularity else choose_granularity(end - start))

    def describe(self) -> str:
        return f"{iso(self.start)} → {iso(self.end)} @ {self.granularity}"


def resolve_window(
    last: str = "",
    start: str = "",
    end: str = "",
    granularity: str = "",
    default_last: str = "",
    now: Optional[datetime] = None,
) -> Window:
    """Turn the user's window flags into one absolute Window.

    Exactly one shape is allowed: --last, or --start (with optional --end).
    """
    now = now or datetime.now(timezone.utc)
    if last and (start or end):
        raise UsageError("use either --last or --start/--end, not both")
    if end and not start:
        raise UsageError("--end needs --start")
    if start:
        begin = parse_instant(start)
        finish = parse_instant(end) if end else now
    else:
        span = parse_duration(last or default_last)
        finish, begin = now, now - span
    if finish <= begin:
        raise UsageError(f"window ends before it starts: {iso(begin)} → {iso(finish)}")
    if finish > now + timedelta(minutes=1):
        raise UsageError(f"window ends in the future: {iso(finish)}")
    chosen = _pick_granularity(granularity, finish - begin)
    return Window(begin, finish, chosen)


def _pick_granularity(requested: str, span: timedelta) -> Granularity:
    if not requested:
        return choose_granularity(span)
    try:
        chosen = Granularity(requested.upper())
    except ValueError as exc:
        allowed = ", ".join(g.value for g in Granularity)
        raise UsageError(f"granularity {requested!r} is not one of {allowed}") from exc
    points = span.total_seconds() / _SECONDS_PER_GRANULARITY[chosen]
    if points < 1:
        raise UsageError(
            f"granularity {chosen} is coarser than the whole window ({span}); "
            "pick a finer one or a longer window"
        )
    return chosen
