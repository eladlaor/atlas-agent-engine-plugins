"""Admin commands: profiles (list / show / measurements / validate / init) and doctor."""

from __future__ import annotations

import json

from atlas_metrics.constants import READ_ONLY_COMMANDS, SETUP_HINT, VERIFIED_CLI_VERSION, Command, Severity, Source
from atlas_metrics.context import RunContext
from atlas_metrics.errors import AtlasCliError, ConfigError, MetricsError, UsageError
from atlas_metrics.logging_setup import get_logger
from atlas_metrics.profiles import CATALOG_BY_SOURCE, config_path, load_config
from atlas_metrics.report import Report, Section

log = get_logger("commands.admin")

EXAMPLE_CONFIG = {
    "defaults": {"cluster": "<your-cluster-name>", "nodes": "all", "format": "table", "last": "6h"},
    "profiles": {
        "my-cpu": {
            "extends": "cpu",
            "add": ["SYSTEM_NORMALIZED_CPU_IRQ"],
            "thresholds": {"PROCESS_NORMALIZED_CPU_USER": {"warn": 50, "crit": 80}},
        },
        "cache-pressure": {
            "source": "process",
            "description": "WiredTiger cache under pressure: fill, dirtiness and eviction traffic.",
            "measurements": ["CACHE_FILL_RATIO", "DIRTY_FILL_RATIO", "CACHE_BYTES_READ_INTO",
                             "CACHE_BYTES_WRITTEN_FROM", "EXTRA_INFO_PAGE_FAULTS"],
            "thresholds": {},
        },
    },
}


def cmd_profiles(ctx: RunContext) -> Report:
    action = ctx.args.action
    if action == "list":
        report = Report("profiles", "Measurement profiles",
                        {"config": str(ctx.config.path or "(none — built-ins only)")})
        section = Section("profiles", ["name", "source", "origin", "measurements", "description"])
        for name in sorted(ctx.config.profiles, key=lambda n: (str(ctx.config.profiles[n].source), n)):
            p = ctx.config.profiles[name]
            section.rows.append([name, str(p.source), p.origin, len(p.measurements), p.description])
            section.data.append(p.to_dict())
        report.sections.append(section)
        return report
    if action == "show":
        if not ctx.args.name:
            raise UsageError("profiles show needs a profile name")
        p = ctx.config.profile(ctx.args.name)
        report = Report("profiles", f"Profile {p.name}",
                        {"source": str(p.source), "origin": p.origin, "description": p.description})
        section = Section("measurements", ["measurement", "warn", "crit", "direction", "stat", "units"])
        for m in p.measurements:
            t = p.thresholds.get(m)
            section.rows.append([m, *(["", "", "", "", ""] if t is None else
                                      [t.warn, t.crit, str(t.direction), t.stat, t.units])])
        section.data.append(p.to_dict())
        report.sections.append(section)
        return report
    if action == "measurements":
        source = Source(ctx.args.source or "process")
        report = Report("profiles", f"Valid {source} measurements", {"source": str(source)})
        section = Section("measurements", ["measurement"])
        for m in sorted(CATALOG_BY_SOURCE[source]):
            section.rows.append([m])
        report.sections.append(section)
        return report
    if action == "validate":
        config = load_config(ctx.args.config or "")
        return Report("profiles", "Config is valid",
                      {"config": str(config.path or "(none — built-ins only)"),
                       "profiles": len(config.profiles)})
    if action == "init":
        return _init(ctx)
    raise UsageError(f"unknown profiles action {action!r}")


def _init(ctx: RunContext) -> Report:
    path = config_path(ctx.args.config or "")
    if path.exists():
        raise ConfigError(f"{path} already exists; edit it, or pass --config <new path>")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(EXAMPLE_CONFIG, indent=2) + "\n", encoding="utf-8")
    load_config(str(path))  # prove the example is valid before telling the user it is
    log.info("wrote example config", extra={"path": str(path)})
    return Report("profiles", "Wrote an example config", {"config": str(path),
                                                          "next": "edit defaults.cluster"})


def cmd_doctor(ctx: RunContext) -> Report:
    report = Report("doctor", "atlas-metrics doctor", {})
    section = Section("checks", ["check", "result", "detail"])
    version = ctx.cli.version()
    same = version == VERIFIED_CLI_VERSION
    section.rows.append(["atlas CLI version", "ok" if same else "warn",
                         f"{version} (skills verified on {VERIFIED_CLI_VERSION})"])
    if not same:
        report.severities.append(Severity.WARN)
    try:
        who = ctx.cli.text(Command.AUTH_WHOAMI)
        section.rows.append(["authentication", "ok", who.splitlines()[0] if who else ""])
    except AtlasCliError as exc:
        section.rows.append(["authentication", "crit", str(exc).split(" Setup:")[0][:200]])
        section.rows.append(["setup", "todo", SETUP_HINT])
        report.severities.append(Severity.CRIT)
    missing = []
    for argv in sorted(READ_ONLY_COMMANDS):
        if argv == Command.AUTH_WHOAMI:
            continue
        ok, _ = ctx.cli.help_ok(argv)
        if not ok:
            missing.append(" ".join(argv))
    section.rows.append(["commands present on this CLI", "ok" if not missing else "crit",
                         f"{len(READ_ONLY_COMMANDS) - 1 - len(missing)}/{len(READ_ONLY_COMMANDS) - 1}"
                         + (f"; missing: {', '.join(missing)}" if missing else "")])
    if missing:
        report.severities.append(Severity.CRIT)
    cfg = ctx.config.path
    section.rows.append(["config file", "ok", str(cfg) if cfg else "none (built-in profiles only)"])
    cluster = ctx.flag("cluster")
    if cluster:
        from atlas_metrics.topology import cluster_processes  # local: only when asked

        try:
            procs, paused = cluster_processes(ctx.cli, cluster, allow_paused=True)
            if paused:
                section.rows.append([f"cluster {cluster}", "warn",
                                     f"{len(procs)} processes, PAUSED: no current metrics; "
                                     "past windows (--start/--end) still work"])
                report.severities.append(Severity.WARN)
            else:
                section.rows.append([f"cluster {cluster}", "ok", f"{len(procs)} processes"])
        except MetricsError as exc:
            log.error("doctor cluster check failed", extra={"cluster": cluster, "error": str(exc)})
            section.rows.append([f"cluster {cluster}", "crit", str(exc)[:300]])
            report.severities.append(Severity.CRIT)
    report.sections.append(section)
    return report
