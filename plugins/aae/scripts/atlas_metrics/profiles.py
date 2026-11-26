"""Profiles (named measurement sets with thresholds) and the user's config file.

The config file is JSON so the engine stays standard-library only:

    {
      "defaults": {"project_id": "...", "cluster": "...", "nodes": "primary",
                   "format": "table", "last": "6h", "atlas_profile": "work"},
      "profiles": {
        "my-cpu": {"extends": "cpu", "add": ["SYSTEM_CPU_IRQ"], "remove": [],
                   "thresholds": {"PROCESS_NORMALIZED_CPU_USER": {"warn": 50}}}
      }
    }

A user profile either defines `source` + `measurements` from scratch, or
`extends` another profile (built-in or user) and adjusts it with add / remove /
thresholds. Every measurement name is checked against the catalog for its
source, so a typo fails here instead of as an opaque Atlas 400.
"""

from __future__ import annotations

import json
import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from atlas_metrics import measurement_catalog as catalog
from atlas_metrics.constants import (
    BUILTIN_PROFILES_FILE,
    CONFIG_PATH_ENV,
    DEFAULT_CONFIG_RELATIVE_PATH,
    Direction,
    NodeSelector,
    OutputFormat,
    Source,
)
from atlas_metrics.errors import ConfigError, UsageError
from atlas_metrics.logging_setup import get_logger

log = get_logger("profiles")

CATALOG_BY_SOURCE = {
    Source.PROCESS: catalog.PROCESS_MEASUREMENTS,
    Source.DISK: catalog.DISK_MEASUREMENTS,
    Source.DATABASE: catalog.DATABASE_MEASUREMENTS,
    Source.COLLECTION: catalog.COLLECTION_MEASUREMENTS,
    Source.SEARCH_INDEX: catalog.SEARCH_INDEX_MEASUREMENTS,
    Source.SEARCH_HARDWARE: catalog.SEARCH_HARDWARE_MEASUREMENTS,
}
_DEFAULT_KEYS = {"project_id", "atlas_profile", "cluster", "nodes", "format", "last"}
_PROFILE_KEYS = {"source", "description", "measurements", "thresholds", "extends", "add", "remove"}
_THRESHOLD_KEYS = {"warn", "crit", "direction", "units", "stat"}
_STATS = ("min", "avg", "max", "last", "p95")
_MAX_EXTENDS_DEPTH = 10


@dataclass(frozen=True)
class Threshold:
    warn: Optional[float]
    crit: Optional[float]
    direction: Direction
    units: str  # "" = accept any units
    stat: str  # which summary statistic is compared

    def to_dict(self) -> Dict[str, Any]:
        return {"warn": self.warn, "crit": self.crit, "direction": str(self.direction),
                "units": self.units, "stat": self.stat}


@dataclass(frozen=True)
class Profile:
    name: str
    source: Source
    description: str
    measurements: Tuple[str, ...]
    thresholds: Dict[str, Threshold] = field(default_factory=dict)
    origin: str = "builtin"

    def to_dict(self) -> Dict[str, Any]:
        return {
            "name": self.name, "source": str(self.source), "origin": self.origin,
            "description": self.description, "measurements": list(self.measurements),
            "thresholds": {k: v.to_dict() for k, v in self.thresholds.items()},
        }


@dataclass
class Config:
    path: Optional[Path]
    defaults: Dict[str, str]
    profiles: Dict[str, Profile]

    def default(self, key: str) -> str:
        return self.defaults.get(key, "")

    def profile(self, name: str, source: Optional[Source] = None) -> Profile:
        if name not in self.profiles:
            known = ", ".join(sorted(self.profiles))
            raise UsageError(f"unknown profile {name!r}. Known profiles: {known}")
        prof = self.profiles[name]
        if source is not None and prof.source is not source:
            fitting = ", ".join(sorted(n for n, p in self.profiles.items() if p.source is source))
            raise UsageError(
                f"profile {name!r} reads {prof.source} metrics, but this command needs a "
                f"{source} profile: {fitting}"
            )
        return prof


# ---------------------------------------------------------------------- loading

def config_path(explicit: str = "") -> Path:
    if explicit:
        return Path(explicit).expanduser()
    env = os.environ.get(CONFIG_PATH_ENV)
    if env:
        return Path(env).expanduser()
    return Path.home().joinpath(*DEFAULT_CONFIG_RELATIVE_PATH)


def _read_json(path: Path, what: str) -> Dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ConfigError(f"{what} {path} is not valid JSON: {exc}") from exc
    except OSError as exc:
        raise ConfigError(f"cannot read {what} {path}: {exc}") from exc
    if not isinstance(data, dict):
        raise ConfigError(f"{what} {path} must be a JSON object")
    return data


def load_config(explicit_path: str = "") -> Config:
    builtin_raw = _read_json(Path(__file__).with_name(BUILTIN_PROFILES_FILE), "built-in profiles")
    path = config_path(explicit_path)
    user: Dict[str, Any] = {}
    if path.exists():
        user = _read_json(path, "config file")
    elif explicit_path or os.environ.get(CONFIG_PATH_ENV):
        raise ConfigError(f"config file not found: {path}")
    unknown = set(user) - {"defaults", "profiles"}
    if unknown:
        raise ConfigError(f"{path}: unknown top-level keys {sorted(unknown)}; "
                          "allowed: defaults, profiles")
    defaults = user.get("defaults", {})
    bad_defaults = set(defaults) - _DEFAULT_KEYS
    if bad_defaults:
        raise ConfigError(f"{path}: unknown defaults {sorted(bad_defaults)}; "
                          f"allowed: {sorted(_DEFAULT_KEYS)}")
    _check_defaults(path, defaults)
    raw_all: Dict[str, Tuple[Dict[str, Any], str]] = {
        name: (body, "builtin") for name, body in builtin_raw.items()
    }
    for name, body in (user.get("profiles") or {}).items():
        raw_all[name] = (body, "user-override" if name in builtin_raw else "user")
    profiles = {name: _build(name, raw_all, builtin_raw, 0) for name in raw_all}
    log.info("config loaded", extra={"path": str(path), "exists": path.exists(),
                                     "profiles": len(profiles)})
    return Config(path if path.exists() else None,
                  {k: str(v) for k, v in defaults.items()}, profiles)


def _check_defaults(path: Path, defaults: Dict[str, Any]) -> None:
    """Fail at load time, not as a crash deep inside a command."""
    allowed = {"nodes": [n.value for n in NodeSelector], "format": [f.value for f in OutputFormat]}
    for key, values in allowed.items():
        if key in defaults and defaults[key] not in values:
            raise ConfigError(f"{path}: defaults.{key} is {defaults[key]!r}; use one of {values}")
    if "last" in defaults:
        from atlas_metrics.time_window import parse_duration  # avoids an import cycle

        try:
            parse_duration(str(defaults["last"]))
        except UsageError as exc:
            raise ConfigError(f"{path}: defaults.last: {exc}") from exc


def _build(
    name: str,
    raw_all: Dict[str, Tuple[Dict[str, Any], str]],
    builtin_raw: Dict[str, Any],
    depth: int,
) -> Profile:
    if depth > _MAX_EXTENDS_DEPTH:
        raise ConfigError(f"profile {name!r}: 'extends' chain is too deep or circular")
    body, origin = raw_all[name]
    if not isinstance(body, dict):
        raise ConfigError(f"profile {name!r} must be a JSON object")
    unknown = set(body) - _PROFILE_KEYS
    if unknown:
        raise ConfigError(f"profile {name!r}: unknown keys {sorted(unknown)}")

    parent_name = body.get("extends")
    if origin == "user-override" and not parent_name and "measurements" not in body:
        # Overriding a built-in by name without redefining it adjusts the built-in.
        raw_all = dict(raw_all)
        raw_all[f"__builtin__{name}"] = (builtin_raw[name], "builtin")
        parent_name = f"__builtin__{name}"
    if parent_name:
        if parent_name == name or parent_name not in raw_all:
            raise ConfigError(f"profile {name!r} extends unknown profile {parent_name!r}")
        parent = _build(parent_name, raw_all, builtin_raw, depth + 1)
        source = parent.source
        if body.get("source") and body["source"] != str(source):
            raise ConfigError(f"profile {name!r}: source {body['source']!r} conflicts with "
                              f"the {source} source of {parent_name!r}")
        measurements = list(body.get("measurements") or parent.measurements)
        thresholds = dict(parent.thresholds)
        description = body.get("description") or f"{parent.description} (adjusted)"
    else:
        source = _source(name, body.get("source"))
        measurements = list(body.get("measurements") or [])
        thresholds = {}
        description = body.get("description", "")
    for extra in body.get("add") or []:
        if extra not in measurements:
            measurements.append(extra)
    removed = set(body.get("remove") or [])
    measurements = [m for m in measurements if m not in removed]
    if not measurements:
        raise ConfigError(f"profile {name!r} has no measurements")
    _check_names(name, source, measurements)
    unknown = sorted(set(body.get("thresholds") or {}) - set(measurements))
    if unknown:
        raise ConfigError(f"profile {name!r}: thresholds for {unknown}, which are not "
                          "measurements of this profile (add them with 'add', or fix the name)")
    for metric, spec in (body.get("thresholds") or {}).items():
        thresholds[metric] = _threshold(name, metric, spec, thresholds.get(metric))
    thresholds = {k: v for k, v in thresholds.items() if k in measurements}
    return Profile(name, source, description, tuple(measurements), thresholds, origin)


def _source(name: str, value: Any) -> Source:
    try:
        return Source(value)
    except ValueError as exc:
        allowed = ", ".join(s.value for s in Source)
        raise ConfigError(f"profile {name!r}: source {value!r} is not one of {allowed}") from exc


def _check_names(name: str, source: Source, measurements: List[str]) -> None:
    valid = CATALOG_BY_SOURCE[source]
    bad = [m for m in measurements if m not in valid]
    if bad:
        raise ConfigError(
            f"profile {name!r}: {bad} are not valid {source} measurements. "
            f"Run `atlas-metrics profiles measurements --source {source}` for the list."
        )


def _threshold(name: str, metric: str, spec: Any, base: Optional[Threshold]) -> Threshold:
    if not isinstance(spec, dict):
        raise ConfigError(f"profile {name!r}: threshold for {metric} must be an object")
    unknown = set(spec) - _THRESHOLD_KEYS
    if unknown:
        raise ConfigError(f"profile {name!r}: threshold {metric} has unknown keys {sorted(unknown)}")
    try:
        direction = Direction(spec.get("direction", str(base.direction) if base else "above"))
    except ValueError as exc:
        raise ConfigError(f"profile {name!r}: {metric}.direction must be above or below") from exc
    stat = spec.get("stat") or (base.stat if base else ("max" if direction is Direction.ABOVE else "min"))
    if stat not in _STATS:
        raise ConfigError(f"profile {name!r}: {metric}.stat must be one of {_STATS}")
    warn = _number(name, metric, "warn", spec.get("warn", base.warn if base else None))
    crit = _number(name, metric, "crit", spec.get("crit", base.crit if base else None))
    if warn is None and crit is None:
        raise ConfigError(f"profile {name!r}: threshold {metric} needs warn and/or crit")
    if warn is not None and crit is not None:
        ordered = warn <= crit if direction is Direction.ABOVE else warn >= crit
        if not ordered:
            raise ConfigError(f"profile {name!r}: {metric} warn={warn} and crit={crit} are in "
                              f"the wrong order for direction '{direction}'")
    return Threshold(warn, crit, direction, spec.get("units", base.units if base else ""), stat)


def _number(name: str, metric: str, key: str, value: Any) -> Optional[float]:
    if value is None:
        return None
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ConfigError(f"profile {name!r}: {metric}.{key} must be a number, got {value!r}")
    return float(value)


def parse_threshold_overrides(items: List[str]) -> Dict[str, Dict[str, float]]:
    """--threshold METRIC:warn=70,crit=90 (repeatable) -> {metric: {warn, crit}}."""
    out: Dict[str, Dict[str, Any]] = {}
    for item in items:
        metric, sep, rest = item.partition(":")
        if not sep or not metric or not rest:
            raise UsageError(f"--threshold {item!r}: expected METRIC:warn=N,crit=N")
        spec: Dict[str, Any] = {}
        for part in rest.split(","):
            key, eq, value = part.partition("=")
            if not eq or key not in _THRESHOLD_KEYS:
                raise UsageError(f"--threshold {item!r}: bad part {part!r}")
            if key in ("warn", "crit"):
                try:
                    spec[key] = float(value)
                except ValueError as exc:
                    raise UsageError(f"--threshold {item!r}: {key} is not a number") from exc
            else:
                spec[key] = value
        out[metric] = spec
    return out


def adjust_profile(
    base: Profile, add: List[str], remove: List[str], threshold_flags: List[str]
) -> Profile:
    """Apply one-off command-line adjustments on top of a resolved profile."""
    if not (add or remove or threshold_flags):
        return base
    measurements = [m for m in list(base.measurements) + [a for a in dict.fromkeys(add) if a not in base.measurements]
                    if m not in set(remove)]
    if not measurements:
        raise UsageError("after --remove, the profile has no measurements left")
    _check_names(base.name, base.source, measurements)
    thresholds = dict(base.thresholds)
    for metric, spec in parse_threshold_overrides(threshold_flags).items():
        if metric not in measurements:
            raise UsageError(f"--threshold {metric}: not a measurement of this run "
                             f"(add it with --add {metric})")
        try:
            thresholds[metric] = _threshold(base.name, metric, spec, thresholds.get(metric))
        except ConfigError as exc:
            raise UsageError(str(exc)) from exc
    thresholds = {k: v for k, v in thresholds.items() if k in measurements}
    return Profile(base.name, base.source, base.description, tuple(measurements),
                   thresholds, f"{base.origin}+flags")
