"""Time windows: parsing, granularity choice, and the shifted comparison window.

A window is always resolved to absolute UTC start/end, because three Atlas
families want three different encodings of the same range: ISO 8601 strings
(measurements), epoch milliseconds (Performance Advisor, query shapes) and
ISO dates (events). Resolving once keeps those three views consistent.
"""

from __future__ import annotations

import os
import re
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Optional, Tuple

from atlas_metrics.constants import (
    GRANULARITY_FALLBACK,
    GRANULARITY_RETENTION_SECONDS,
    GRANULARITY_RULES,
    NOW_OVERRIDE_ENV,
    Granularity,
)
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
_FINEST_FIRST = sorted(Granularity, key=_SECONDS_PER_GRANULARITY.__getitem__)


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


def utc_now() -> datetime:
    """The current time, or the instant in NOW_OVERRIDE_ENV (used by the offline tests, whose
    fixture windows are fixed dates that must not age past Atlas's retention limits)."""
    override = os.environ.get(NOW_OVERRIDE_ENV, "")
    return parse_instant(override) if override else datetime.now(timezone.utc)


def iso(value: datetime) -> str:
    return value.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def epoch_ms(value: datetime) -> int:
    return int(value.timestamp() * 1000)


def _human(seconds: float) -> str:
    for size, unit in ((86400, "day"), (3600, "hour"), (60, "minute")):
        if seconds >= size or unit == "minute":
            amount = f"{max(seconds, 0) / size:.1f}".rstrip("0").rstrip(".")
            return f"{amount} {unit}" + ("" if amount == "1" else "s")
    raise AssertionError("unreachable")


def retained(granularity: Granularity, start: datetime, now: datetime) -> bool:
    """True if Atlas still keeps `granularity` data for a window starting at `start`."""
    limit = GRANULARITY_RETENTION_SECONDS[granularity]
    return limit is None or (now - start).total_seconds() <= limit


def _coarsen_until_retained(granularity: Granularity, start: datetime, now: datetime) -> Granularity:
    for candidate in _FINEST_FIRST[_FINEST_FIRST.index(granularity):]:
        if retained(candidate, start, now):
            return candidate
    raise AssertionError("P1D is kept forever, so some granularity must be retained")


def choose_granularity(span: timedelta, start: Optional[datetime] = None,
                       now: Optional[datetime] = None) -> Granularity:
    """The finest granularity that suits the span and that Atlas still keeps for `start`."""
    seconds = span.total_seconds()
    chosen = next((g for upper, g in GRANULARITY_RULES if seconds <= upper), GRANULARITY_FALLBACK)
    if start is None:
        return chosen
    return _coarsen_until_retained(chosen, start, now or utc_now())


def _require_retained(granularity: Granularity, start: datetime, now: datetime) -> None:
    """For a granularity the user chose: refuse it if Atlas no longer has it for this window."""
    if retained(granularity, start, now):
        return
    limit = GRANULARITY_RETENTION_SECONDS[granularity]
    coarser = _coarsen_until_retained(granularity, start, now)
    raise UsageError(
        f"Atlas keeps {granularity} data for {_human(limit)} only, and this window starts "
        f"{_human((now - start).total_seconds())} ago, so there is none to return. Use "
        f"--granularity {coarser}, or leave --granularity out and the engine picks one Atlas still has."
    )


def _require_points(granularity: Granularity, span: timedelta, start: datetime, now: datetime,
                    explicit: bool) -> None:
    if span.total_seconds() >= _SECONDS_PER_GRANULARITY[granularity]:
        return
    if explicit:
        raise UsageError(
            f"granularity {granularity} is coarser than the whole window ({span}); "
            "pick a finer one or a longer window"
        )
    raise UsageError(
        f"this window starts {_human((now - start).total_seconds())} ago, where Atlas keeps only "
        f"{granularity} data, which is coarser than the whole window ({span}). Widen the window to "
        f"at least {_human(_SECONDS_PER_GRANULARITY[granularity])}."
    )


@dataclass(frozen=True)
class Window:
    start: datetime
    end: datetime
    granularity: Granularity

    @property
    def span(self) -> timedelta:
        return self.end - self.start

    @property
    def step_seconds(self) -> int:
        return _SECONDS_PER_GRANULARITY[self.granularity]

    @property
    def expected_points(self) -> int:
        return max(1, int(self.span.total_seconds() // self.step_seconds))

    def with_baseline(self, back: timedelta, explicit: bool = False,
                      now: Optional[datetime] = None) -> Tuple["Window", "Window"]:
        """This window and the same-length one `back` earlier, at one shared granularity.

        The baseline starts further back, so it may be past what Atlas keeps at this
        granularity: then both windows move to a coarser one (or, if the user chose the
        granularity, the request is refused), so the comparison stays like for like.
        """
        now = now or utc_now()
        start = self.start - back
        if explicit:
            _require_retained(self.granularity, start, now)
            granularity = self.granularity
        else:
            granularity = _coarsen_until_retained(self.granularity, start, now)
            _require_points(granularity, self.span, start, now, explicit=False)
        return (Window(self.start, self.end, granularity),
                Window(start, self.end - back, granularity))

    def padded(self, pad: timedelta, keep_granularity: bool = False,
               now: Optional[datetime] = None) -> "Window":
        """Widen by `pad` on each side, never past now. Keeps a user-chosen granularity."""
        now = now or utc_now()
        start, end = self.start - pad, min(self.end + pad, now)
        if keep_granularity:
            _require_retained(self.granularity, start, now)
            _require_points(self.granularity, end - start, start, now, explicit=True)
            return Window(start, end, self.granularity)
        granularity = choose_granularity(end - start, start, now)
        _require_points(granularity, end - start, start, now, explicit=False)
        return Window(start, end, granularity)

    def describe(self) -> str:
        return f"{iso(self.start)} → {iso(self.end)} @ {self.granularity}"


def resolve_window(
    last: str = "",
    start: str = "",
    end: str = "",
    granularity: str = "",
    default_last: str = "",
    now: Optional[datetime] = None,
    check_points: bool = True,
) -> Window:
    """Turn the user's window flags into one absolute Window.

    Exactly one shape is allowed: --last, or --start (with optional --end). With
    check_points=False the window may be shorter than its granularity, for a caller that
    widens it first (incident pads it) and checks the widened window.
    """
    now = now or utc_now()
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
    if begin > now:
        raise UsageError(f"window starts in the future: {iso(begin)}")
    if finish <= begin:
        raise UsageError(f"window ends before it starts: {iso(begin)} → {iso(finish)}")
    if finish > now + timedelta(minutes=1):
        raise UsageError(f"window ends in the future: {iso(finish)}")
    chosen = _pick_granularity(granularity, begin, finish, now, check_points)
    return Window(begin, finish, chosen)


def _pick_granularity(requested: str, start: datetime, end: datetime, now: datetime,
                      check_points: bool = True) -> Granularity:
    span = end - start
    if not requested:
        chosen = choose_granularity(span, start, now)
        if check_points:
            _require_points(chosen, span, start, now, explicit=False)
        return chosen
    try:
        chosen = Granularity(requested.upper())
    except ValueError as exc:
        allowed = ", ".join(g.value for g in Granularity)
        raise UsageError(f"granularity {requested!r} is not one of {allowed}") from exc
    if check_points:
        _require_points(chosen, span, start, now, explicit=True)
    _require_retained(chosen, start, now)
    return chosen
