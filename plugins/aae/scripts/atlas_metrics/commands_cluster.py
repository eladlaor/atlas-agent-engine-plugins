"""Host-level commands: hosts, process (snapshot / history / compare), storage."""

from __future__ import annotations

from typing import Any, Dict, List, Optional, Tuple

from atlas_metrics.constants import (
    DEFAULT_HISTORY_WINDOW,
    DEFAULT_SNAPSHOT_WINDOW,
    DEFAULT_TOP_N,
    Command,
    Source,
)
from atlas_metrics.context import (
    COMPARE_COLUMNS,
    SERIES_COLUMNS,
    SNAPSHOT_COLUMNS,
    RunContext,
    collect_atlas_notes,
    series_data,
    series_row,
    window_context,
)
from atlas_metrics.errors import AtlasCliError, NoDataError
from atlas_metrics.logging_setup import get_logger
from atlas_metrics.profiles import Profile, adjust_profile
from atlas_metrics.report import Report, Section
from atlas_metrics.summarize import SeriesSummary, attach_baseline, evaluate, human, summarize_series
from atlas_metrics.time_window import Window, iso, parse_duration, resolve_window
from atlas_metrics.topology import Process, cluster_processes, describe_processes, select_nodes

log = get_logger("commands.cluster")


# ------------------------------------------------------------------ shared bits

def resolve_profile(ctx: RunContext, source: Source, default_name: str) -> Profile:
    base = ctx.config.profile(ctx.args.profile or default_name, source)
    return adjust_profile(base, ctx.args.add or [], ctx.args.remove or [], ctx.args.threshold or [])


def nodes_for(ctx: RunContext, default_nodes: str = "") -> Tuple[str, List[Process]]:
    cluster = ctx.flag("cluster")
    processes = cluster_processes(ctx.cli, cluster)
    nodes = ctx.flag("nodes", fallback=default_nodes)
    return cluster, select_nodes(processes, nodes, ctx.args.shard or "", ctx.args.host or "")


def window_for(ctx: RunContext, default_last: str) -> Window:
    return resolve_window(
        last=ctx.args.last or ("" if ctx.args.start else ctx.config.default("last")),
        start=ctx.args.start or "", end=ctx.args.end or "",
        granularity=ctx.args.granularity or "", default_last=default_last,
    )


def window_flags(window: Window) -> List[str]:
    return ["--granularity", str(window.granularity), "--start", iso(window.start),
            "--end", iso(window.end)]


def measurement_series(payload: Any, what: str) -> List[Dict[str, Any]]:
    if not isinstance(payload, dict):
        raise AtlasCliError(f"{what} returned an unexpected shape: {str(payload)[:200]}")
    for key in ("measurements", "indexStatsMeasurements", "hardwareMeasurements"):
        if isinstance(payload.get(key), list):
            return payload[key]
    raise AtlasCliError(f"{what} returned no measurements list: {str(payload)[:200]}")


def summarize_payload(payload: Any, profile: Profile, what: str) -> List[SeriesSummary]:
    wanted = set(profile.measurements)
    out = []
    for raw in measurement_series(payload, what):
        if raw.get("name") in wanted:
            out.append(evaluate(summarize_series(raw), profile.thresholds.get(raw.get("name"))))
    order = {m: i for i, m in enumerate(profile.measurements)}
    return sorted(out, key=lambda s: order.get(s.name, len(order)))


def fetch_process(ctx: RunContext, proc: Process, profile: Profile, window: Window,
                  report: Report) -> List[SeriesSummary]:
    payload = ctx.cli.curated([*Command.METRICS_PROCESSES, proc.process_id,
                               *window_flags(window), "--type", ",".join(profile.measurements)])
    collect_atlas_notes(report, payload)
    return summarize_payload(payload, profile, f"metrics processes {proc.alias}")


def add_series_section(report: Report, title: str, rows: List[Tuple[str, SeriesSummary]],
                       columns: List[str]) -> Section:
    section = Section(title, columns)
    for scope, summary in rows:
        section.rows.append(series_row(scope, summary, columns))
        section.data.append(series_data(scope, summary))
        report.severities.append(summary.severity)
    report.sections.append(section)
    return section


# --------------------------------------------------------------------- commands

def cmd_hosts(ctx: RunContext) -> Report:
    cluster, selected = nodes_for(ctx)
    report = Report("hosts", f"Processes of cluster {cluster}", {"cluster": cluster})
    section = Section("processes", ["alias", "role", "replica set", "shard", "process id"])
    for item in describe_processes(selected):
        section.rows.append([item["alias"], item["role"], item["replicaSet"], item["shard"],
                             item["processId"]])
        section.data.append(item)
    report.sections.append(section)
    return report


def cmd_process(ctx: RunContext, mode: str) -> Report:
    """mode: snapshot (short window, last/max) or history (any window, full stats)."""
    profile = resolve_profile(ctx, Source.PROCESS, "overview")
    window = window_for(ctx, DEFAULT_SNAPSHOT_WINDOW if mode == "snapshot" else DEFAULT_HISTORY_WINDOW)
    cluster, nodes = nodes_for(ctx)
    compare = getattr(ctx.args, "compare", "") or ""
    baseline_window: Optional[Window] = window.shifted(parse_duration(compare)) if compare else None
    title = f"{'Snapshot' if mode == 'snapshot' else 'History'} of {cluster} — profile {profile.name}"
    report = Report(mode, title, {"cluster": cluster, "profile": profile.name,
                                  "nodes": len(nodes), **window_context(window)})
    if baseline_window:
        report.context["compared with"] = f"{iso(baseline_window.start)} → {iso(baseline_window.end)}"
    rows: List[Tuple[str, SeriesSummary]] = []
    for proc in nodes:
        current = fetch_process(ctx, proc, profile, window, report)
        if baseline_window:
            before = {s.name: s for s in fetch_process(ctx, proc, profile, baseline_window, report)}
            current = [attach_baseline(s, before[s.name]) if s.name in before else s for s in current]
        rows += [(proc.label(), s) for s in current]
    if not rows:
        raise NoDataError(f"Atlas returned no {profile.name} measurements for {cluster} in "
                          f"{window.describe()}", {"warnings": report.atlas_warnings})
    if baseline_window:
        columns = COMPARE_COLUMNS
    else:
        columns = SNAPSHOT_COLUMNS if mode == "snapshot" else SERIES_COLUMNS
    add_series_section(report, f"{profile.description}", rows, columns)
    return report


def cmd_storage(ctx: RunContext) -> Report:
    parts = set(ctx.args.part or ["disks", "databases"])
    window = window_for(ctx, DEFAULT_SNAPSHOT_WINDOW)
    cluster, nodes = nodes_for(ctx)
    report = Report("storage", f"Storage of {cluster}", {"cluster": cluster, **window_context(window)})
    if "disks" in parts:
        _storage_disks(ctx, nodes, window, report)
    if "databases" in parts:
        primaries = [p for p in nodes if p.is_primary] or nodes[:1]
        _storage_databases(ctx, primaries, window, report)
    return report


def _list_names(payload: Any, key: str, what: str) -> List[str]:
    results = payload.get("results") if isinstance(payload, dict) else payload
    if not isinstance(results, list):
        raise AtlasCliError(f"{what} returned an unexpected shape: {str(payload)[:200]}")
    return [r[key] for r in results if isinstance(r, dict) and r.get(key)]


def _storage_disks(ctx: RunContext, nodes: List[Process], window: Window, report: Report) -> None:
    profile = adjust_profile(ctx.config.profile(ctx.args.disk_profile or "disk", Source.DISK),
                             [], [], ctx.args.threshold or [])
    rows: List[Tuple[str, SeriesSummary]] = []
    for proc in nodes:
        partitions = _list_names(ctx.cli.curated([*Command.METRICS_DISKS_LIST, proc.process_id]),
                                 "partitionName", f"disks list {proc.alias}")
        for partition in partitions:
            payload = ctx.cli.curated([*Command.METRICS_DISKS_DESCRIBE, proc.process_id, partition,
                                       *window_flags(window), "--type", ",".join(profile.measurements)])
            collect_atlas_notes(report, payload)
            rows += [(f"{proc.alias} {partition}", s)
                     for s in summarize_payload(payload, profile, f"disk {partition}")]
    add_series_section(report, "Disks — " + profile.description, rows, SNAPSHOT_COLUMNS)


def _storage_databases(ctx: RunContext, nodes: List[Process], window: Window, report: Report) -> None:
    profile = ctx.config.profile(ctx.args.database_profile or "database-size", Source.DATABASE)
    top = ctx.args.top or DEFAULT_TOP_N
    for proc in nodes:
        names = _list_names(ctx.cli.curated([*Command.METRICS_DATABASES_LIST, proc.process_id]),
                            "databaseName", f"databases list {proc.alias}")
        if ctx.args.database:
            names = [n for n in names if n in set(ctx.args.database)]
        table: List[Dict[str, Any]] = []
        for name in names:
            payload = ctx.cli.curated([*Command.METRICS_DATABASES_DESCRIBE, proc.process_id, name,
                                       *window_flags(window), "--type", ",".join(profile.measurements)])
            collect_atlas_notes(report, payload)
            latest = {s.name: s for s in summarize_payload(payload, profile, f"database {name}")}
            table.append({"database": name, **{k: (v.last, v.units) for k, v in latest.items()}})
        table.sort(key=lambda r: (r.get("DATABASE_STORAGE_SIZE") or (0, ""))[0] or 0, reverse=True)
        columns = ["database", *profile.measurements]
        section = Section(f"Databases on {proc.label()} (largest first, top {top})",
                          [c.replace("DATABASE_", "").lower() for c in columns])
        for row in table[:top]:
            section.rows.append([row["database"]] + [human(*(row.get(m) or (None, ""))) for m in
                                                     profile.measurements])
            section.data.append({"database": row["database"],
                                 **{m: (row.get(m) or (None, ""))[0] for m in profile.measurements}})
        if len(table) > top:
            section.notes.append(f"{len(table) - top} smaller databases omitted; raise --top to see them")
        report.sections.append(section)
