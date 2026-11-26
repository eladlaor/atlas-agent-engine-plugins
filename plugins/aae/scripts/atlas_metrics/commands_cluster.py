"""Host-level commands: hosts, process (snapshot / history / compare), storage."""

from __future__ import annotations

from typing import Any, Dict, List, Optional, Tuple  # noqa: F401 - Optional used in signatures

from atlas_metrics.constants import (
    DEFAULT_HISTORY_WINDOW,
    DEFAULT_SNAPSHOT_WINDOW,
    DATABASE_SIZE_MEASUREMENT,
    DEFAULT_TOP_N,
    Command,
    Severity,
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
from atlas_metrics.errors import AtlasCliError, InvalidMeasurementError, NoDataError, UsageError
from atlas_metrics.logging_setup import get_logger
from atlas_metrics.profiles import Profile, adjust_profile
from atlas_metrics.report import Report, Section
from atlas_metrics.summarize import (
    SeriesSummary,
    attach_baseline,
    check_reporting,
    evaluate,
    human,
    summarize_series,
)
from atlas_metrics.time_window import Window, iso, parse_duration, parse_instant, resolve_window
from atlas_metrics.topology import (
    Process,
    cluster_processes,
    describe_processes,
    last_report,
    select_nodes,
)

log = get_logger("commands.cluster")


# ------------------------------------------------------------------ shared bits

def resolve_profile(ctx: RunContext, source: Source, default_name: str) -> Profile:
    base = ctx.config.profile(ctx.args.profile or default_name, source)
    return adjust_profile(base, ctx.args.add or [], ctx.args.remove or [], ctx.args.threshold or [])


def nodes_for(ctx: RunContext, default_nodes: str = "", allow_paused: Optional[bool] = None,
              cluster: str = "") -> Tuple[str, List[Process]]:
    cluster = cluster or ctx.flag("cluster")
    if allow_paused is None:  # a paused cluster only answers for an explicit past window
        allow_paused = bool(getattr(ctx.args, "start", None))
    processes, paused = cluster_processes(ctx.cli, cluster, allow_paused=allow_paused)
    if paused:
        ctx.notes.append(f"cluster {cluster} is paused; it last reported at "
                         f"{last_report(processes) or 'an unknown time'}. Measurements after "
                         "that are empty.")
    # A command with its own node default keeps it unless --nodes names others: the
    # config's defaults.nodes is for commands that have none.
    nodes = getattr(ctx.args, "nodes", None) or default_nodes or ctx.config.default("nodes")
    # Cluster-level commands (collections, query-shapes) have no --shard / --host flags.
    return cluster, select_nodes(processes, nodes, getattr(ctx.args, "shard", None) or "",
                                 getattr(ctx.args, "host", None) or "")


def require_answerable(ctx: RunContext, cluster: str) -> None:
    """For cluster-level commands that never list nodes: apply the same paused-cluster
    rule as nodes_for (refuse "now", allow an explicit past window, with a note)."""
    nodes_for(ctx, allow_paused=None, cluster=cluster)


def window_for(ctx: RunContext, default_last: str, check_points: bool = True) -> Window:
    return resolve_window(
        last=ctx.args.last or ("" if ctx.args.start else ctx.config.default("last")),
        start=ctx.args.start or "", end=ctx.args.end or "",
        granularity=ctx.args.granularity or "", default_last=default_last,
        check_points=check_points,
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


def summarize_payload(payload: Any, profile: Profile, what: str,
                      requested: Optional[List[str]] = None) -> List[SeriesSummary]:
    """Summaries for the measurements this request asked for (default: the profile's)."""
    wanted = set(requested if requested is not None else profile.measurements)
    out = []
    for raw in measurement_series(payload, what):
        if raw.get("name") in wanted:
            out.append(evaluate(summarize_series(raw), profile.thresholds.get(raw.get("name"))))
    order = {m: i for i, m in enumerate(profile.measurements)}
    return sorted(out, key=lambda s: order.get(s.name, len(order)))


def fetch_measurements(ctx: RunContext, argv: List[str], profile: Profile, window: Window,
                       report: Report, scope: str, what: str,
                       process_id: str = "") -> List[SeriesSummary]:
    """One node's series. A measurement Atlas rejects for this node is dropped and named
    in the report (never silently); the request is retried with the rest. If Atlas
    accepts none of them, that is no data, not an empty healthy result."""
    known_bad = ctx.rejected.setdefault(process_id, set()) if process_id else set()
    wanted = [m for m in profile.measurements if m not in known_bad]
    while wanted:
        try:
            payload = ctx.cli.curated([*argv, *window_flags(window), "--type", ",".join(wanted)])
        except InvalidMeasurementError as exc:
            if exc.measurement not in wanted:
                raise
            wanted.remove(exc.measurement)
            known_bad.add(exc.measurement)
            why = (" Oplog measurements are reported by secondaries only."
                   if exc.measurement.startswith("OPLOG_") else "")
            report.add_warning(f"Atlas does not offer {exc.measurement} on {scope} "
                               f"(INVALID_METRIC_NAME).{why}")
            continue
        collect_atlas_notes(report, payload)
        summaries = summarize_payload(payload, profile, what, requested=wanted)
        absent = [m for m in wanted if m not in {s.name for s in summaries}]
        if absent:
            report.add_warning(f"Atlas returned no series for {', '.join(absent)} on {scope}.")
        return summaries
    raise NoDataError(f"Atlas offers none of profile {profile.name}'s measurements on {scope} "
                      f"(all rejected: {sorted(known_bad) or sorted(profile.measurements)}).",
                      {"warnings": report.atlas_warnings})


def fetch_process(ctx: RunContext, proc: Process, profile: Profile, window: Window,
                  report: Report) -> List[SeriesSummary]:
    return fetch_measurements(ctx, [*Command.METRICS_PROCESSES, proc.process_id], profile,
                              window, report, proc.label(), f"metrics processes {proc.alias}",
                              process_id=proc.process_id)


def add_series_section(report: Report, title: str, rows: List[Tuple[str, SeriesSummary]],
                       columns: List[str], node_window: Optional[Window] = None) -> Section:
    """Add one table of series. With node_window, each row's scope is one node (or one of
    its partitions) over that window: gaps are counted against the points the window should
    hold, a series whose last point is too old is stale, and a node whose every series is
    empty or stale makes the verdict warn, because a health check must not pass while a node
    is silent."""
    if node_window is not None:
        for _, summary in rows:
            check_reporting(summary, node_window.end, node_window.step_seconds,
                            node_window.expected_points, parse_instant)
    if not rows:
        raise NoDataError(f"{title}: no series at all.", {"warnings": report.atlas_warnings})
    if all(s.severity is Severity.NO_DATA for _, s in rows):
        raise NoDataError(f"{title}: Atlas returned only empty series ({len(rows)}). "
                          "The nodes were not reporting, or this measurement has no points at "
                          "this granularity in so short a window: widen it.", {"warnings": report.atlas_warnings})
    missing = sum(1 for _, s in rows if s.severity is Severity.NO_DATA)
    stale = sum(1 for _, s in rows if s.stale)
    if missing:
        report.context["series without data"] = missing
    if stale:
        report.context["stale series"] = stale
    if node_window is not None:
        by_scope: Dict[str, List[SeriesSummary]] = {}
        for scope, summary in rows:
            by_scope.setdefault(scope, []).append(summary)
        silent = [scope for scope, summaries in by_scope.items()
                  if all(s.severity is Severity.NO_DATA or s.stale for s in summaries)]
        if silent:
            report.context["not reporting"] = "; ".join(silent)
            report.severities.append(Severity.WARN)
    section = Section(title, columns)
    for scope, summary in rows:
        section.rows.append(series_row(scope, summary, columns))
        section.data.append(series_data(scope, summary))
        report.severities.append(summary.severity)
    report.sections.append(section)
    return section


# --------------------------------------------------------------------- commands

def cmd_hosts(ctx: RunContext) -> Report:
    cluster, selected = nodes_for(ctx, allow_paused=True)
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
    baseline_window: Optional[Window] = None
    if compare:
        window, baseline_window = window.with_baseline(parse_duration(compare),
                                                       explicit=bool(ctx.args.granularity))
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
    if baseline_window and rows and all(
            s.baseline is None or (s.baseline.get("avg") is None and s.baseline.get("max") is None)
            for _, s in rows):
        report.add_warning(f"the earlier window ({iso(baseline_window.start)} → "
                           f"{iso(baseline_window.end)}) has no data, so nothing is compared.")
    if not rows:
        raise NoDataError(f"Atlas returned no {profile.name} measurements for {cluster} in "
                          f"{window.describe()}", {"warnings": report.atlas_warnings})
    if baseline_window:
        columns = COMPARE_COLUMNS
    else:
        columns = SNAPSHOT_COLUMNS if mode == "snapshot" else SERIES_COLUMNS
    add_series_section(report, f"{profile.description}", rows, columns, node_window=window)
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
        # Live 2026-11-22: database sizes are sampled far less often than per-node metrics;
        # a 15-minute window came back all-empty while 6 hours had every value. Sizes are
        # the latest sample, so a longer default window costs nothing.
        explicit = bool(ctx.args.last or ctx.args.start)
        db_window = window if explicit else window_for(ctx, DEFAULT_HISTORY_WINDOW)
        if not explicit:
            report.context["database window"] = f"{iso(db_window.start)} → {iso(db_window.end)}"
        _storage_databases(ctx, primaries, db_window, report)
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
            rows += [(f"{proc.alias} {partition}", s) for s in fetch_measurements(
                ctx, [*Command.METRICS_DISKS_DESCRIBE, proc.process_id, partition], profile,
                window, report, f"{proc.alias} {partition}", f"disk {partition}",
                process_id=f"{proc.process_id}/disk")]
    add_series_section(report, "Disks — " + profile.description, rows, SNAPSHOT_COLUMNS,
                       node_window=window)


def _storage_databases(ctx: RunContext, nodes: List[Process], window: Window, report: Report) -> None:
    profile = ctx.config.profile(ctx.args.database_profile or "database-size", Source.DATABASE)
    top = ctx.args.top or DEFAULT_TOP_N
    per_node = {proc.process_id: _list_names(
        ctx.cli.curated([*Command.METRICS_DATABASES_LIST, proc.process_id]),
        "databaseName", f"databases list {proc.alias}") for proc in nodes}
    if ctx.args.database:  # one check across all nodes: a shard may lack a database
        everywhere = sorted({n for names in per_node.values() for n in names})
        unknown = sorted(set(ctx.args.database) - set(everywhere))
        if unknown:
            raise UsageError(f"--database {unknown} not found on any node; seen: {everywhere}")
    any_value = False
    for proc in nodes:
        names = per_node[proc.process_id]
        if ctx.args.database:
            names = [n for n in names if n in set(ctx.args.database)]
        if not names:
            continue
        table: List[Dict[str, Any]] = []
        for name in names:
            latest = {s.name: s for s in fetch_measurements(
                ctx, [*Command.METRICS_DATABASES_DESCRIBE, proc.process_id, name], profile,
                window, report, f"{proc.alias} {name}", f"database {name}",
                process_id=f"{proc.process_id}/database")}
            table.append({"database": name, **{k: (v.last, v.units) for k, v in latest.items()}})
        sort_key = (DATABASE_SIZE_MEASUREMENT if DATABASE_SIZE_MEASUREMENT in profile.measurements
                    else profile.measurements[0])
        any_value = any_value or any((row.get(m) or (None, ""))[0] is not None
                                     for row in table for m in profile.measurements)
        table.sort(key=lambda r: (r.get(sort_key) or (0, ""))[0] or 0, reverse=True)
        columns = ["database", *profile.measurements]
        section = Section(f"Databases on {proc.label()} (by {sort_key.lower()}, top {top})",
                          [c.replace("DATABASE_", "").lower() for c in columns])
        for row in table[:top]:
            section.rows.append([row["database"]] + [human(*(row.get(m) or (None, ""))) for m in
                                                     profile.measurements])
            section.data.append({"database": row["database"],
                                 **{m: (row.get(m) or (None, ""))[0] for m in profile.measurements}})
        if len(table) > top:
            section.notes.append(f"{len(table) - top} smaller databases omitted; raise --top to see them")
        report.sections.append(section)
    if not any_value:
        raise NoDataError("Atlas returned no database measurements in the window. Database "
                          "sizes are sampled only every few hours or so; widen it, e.g. --last 6h.",
                          {"warnings": report.atlas_warnings})
