"""Performance Advisor and incident reconstruction."""

from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional, Tuple

from atlas_metrics.commands_cluster import (
    SNAPSHOT_COLUMNS,
    add_series_section,
    fetch_process,
    nodes_for,
    require_answerable,
    resolve_profile,
    window_for,
)
from atlas_metrics.constants import (
    DEFAULT_HISTORY_WINDOW,
    DEFAULT_SLOW_LOG_LINES,
    DEFAULT_TOP_N,
    INCIDENT_PADDING_SECONDS,
    MAX_PAGES,
    PAGE_SIZE,
    Command,
    Source,
)
from atlas_metrics.context import RunContext, collect_atlas_notes, require_list, window_context
from atlas_metrics.errors import AtlasCliError, UsageError
from atlas_metrics.logging_setup import get_logger
from atlas_metrics.report import Report, Section
from atlas_metrics.summarize import SeriesSummary, human
from atlas_metrics.time_window import Window, epoch_ms, iso, parse_instant

log = get_logger("commands.advice")

ADVISOR_PARTS = ("suggested-indexes", "drop-indexes", "schema", "slow-queries")


def _index_keys(index: Any) -> str:
    if isinstance(index, list):
        return ", ".join(f"{k}: {v}" for item in index if isinstance(item, dict) for k, v in item.items())
    return str(index)


# ---------------------------------------------------------------------- advisor

def cmd_advisor(ctx: RunContext) -> Report:
    parts = list(ctx.args.part or ADVISOR_PARTS)
    window = window_for(ctx, DEFAULT_HISTORY_WINDOW)
    cluster = ctx.flag("cluster")
    if not cluster:
        raise UsageError("--cluster is required")
    require_answerable(ctx, cluster)
    top = ctx.args.top or DEFAULT_TOP_N
    report = Report("advisor", f"Performance Advisor for {cluster}",
                    {"cluster": cluster, "window": f"{iso(window.start)} → {iso(window.end)}",
                     "parts": ", ".join(parts)})
    namespaces = ctx.args.namespace or []
    if "suggested-indexes" in parts:
        _suggested(ctx, cluster, window, namespaces, top, report)
    if "drop-indexes" in parts:
        _drop(ctx, cluster, report)
    if "schema" in parts:
        _schema(ctx, cluster, report)
    if "slow-queries" in parts:
        _slow(ctx, window, namespaces, report)
    return report


def _suggested(ctx: RunContext, cluster: str, window: Window, namespaces: List[str], top: int,
               report: Report) -> None:
    payload = ctx.cli.api(Command.ADVISOR_SUGGESTED, {
        "clusterName": cluster, "namespaces": namespaces,
        "since": epoch_ms(window.start), "until": epoch_ms(window.end)})
    collect_atlas_notes(report, payload)
    section = Section("Suggested indexes (never created by these skills)",
                      ["namespace", "index", "weight", "queries improved"])
    for item in require_list(payload, "suggestedIndexes", "suggested indexes")[:top]:
        section.rows.append([item.get("namespace"), _index_keys(item.get("index")),
                             human(item.get("weight"), "SCALAR"), len(item.get("impact") or [])])
        section.data.append(item)
    shapes = sorted(require_list(payload, "shapes", "suggested indexes"),
                    key=lambda s: s.get("inefficiencyScore") or 0, reverse=True)
    if shapes:
        section.notes.append("Most inefficient query shapes: " + "; ".join(
            f"{s.get('namespace')} avg {s.get('avgMs')} ms ×{s.get('count')} "
            f"(score {s.get('inefficiencyScore')})" for s in shapes[:5]))
    report.sections.append(section)


def _drop(ctx: RunContext, cluster: str, report: Report) -> None:
    payload = ctx.cli.api(Command.ADVISOR_DROP, {"clusterName": cluster})
    collect_atlas_notes(report, payload)
    section = Section("Index drop candidates (never dropped by these skills)",
                      ["kind", "namespace", "index", "size", "accesses", "since"])
    for kind in ("unusedIndexes", "redundantIndexes", "hiddenIndexes"):
        for item in require_list(payload, kind, "index drop suggestions"):
            section.rows.append([kind.replace("Indexes", ""), item.get("namespace"),
                                 item.get("name") or _index_keys(item.get("index")),
                                 human(item.get("sizeBytes"), "BYTES"), item.get("accessCount"),
                                 item.get("since")])
            section.data.append({"kind": kind, **item})
    report.sections.append(section)


def _schema(ctx: RunContext, cluster: str, report: Report) -> None:
    payload = ctx.cli.api(Command.ADVISOR_SCHEMA, {"clusterName": cluster})
    collect_atlas_notes(report, payload)
    section = Section("Schema advice", ["recommendation", "namespaces", "description"])
    for item in require_list(payload, "recommendations", "schema advice"):
        affected = [a.get("namespace", str(a)) if isinstance(a, dict) else str(a)
                    for a in item.get("affectedNamespaces") or []]
        section.rows.append([item.get("recommendation"), ", ".join(affected),
                             (item.get("description") or "")[:160]])
        section.data.append(item)
    report.sections.append(section)


def _slow(ctx: RunContext, window: Window, namespaces: List[str], report: Report) -> None:
    _, nodes = nodes_for(ctx, default_nodes="primary")
    lines = ctx.args.lines or DEFAULT_SLOW_LOG_LINES
    duration_ms = int(window.span.total_seconds() * 1000)
    for proc in nodes:
        ns_payload = ctx.cli.api(Command.ADVISOR_NAMESPACES, {
            "processId": proc.process_id, "since": epoch_ms(window.start), "duration": duration_ms})
        collect_atlas_notes(report, ns_payload)
        slow_ns = [n.get("namespace") for n in
                   require_list(ns_payload, "namespaces", "slow-query namespaces")]
        payload = ctx.cli.api(Command.ADVISOR_SLOW_LOGS, {
            "processId": proc.process_id, "since": epoch_ms(window.start), "duration": duration_ms,
            "nLogs": lines, "namespaces": namespaces, "includeMetrics": True, "includeOpType": True})
        collect_atlas_notes(report, payload)
        entries = list(require_list(payload, "slowQueries", "slow query logs"))
        entries.sort(key=lambda e: (e.get("metrics") or {}).get("operationExecutionTime") or 0,
                     reverse=True)
        section = Section(f"Slow queries on {proc.label()}",
                          ["namespace", "op", "ms", "docs examined", "returned", "examined/returned",
                           "index used", "sort"])
        for entry in entries[:lines]:
            m = entry.get("metrics") or {}
            section.rows.append([entry.get("namespace"), entry.get("opType"),
                                 m.get("operationExecutionTime"), m.get("docsExamined"),
                                 m.get("docsReturned"), m.get("docsExaminedReturnedRatio"),
                                 m.get("hasIndexCoverage"), m.get("hasSort")])
            section.data.append(entry)
        section.notes.append(f"namespaces with slow queries: {', '.join(filter(None, slow_ns)) or 'none'}")
        section.notes.append("Full log lines are in --format json (field 'line').")
        report.sections.append(section)


# --------------------------------------------------------------------- incident

def cmd_incident(ctx: RunContext) -> Report:
    if not ctx.args.start:
        raise UsageError("incident needs --start (and usually --end): the time the problem began")
    core = window_for(ctx, DEFAULT_HISTORY_WINDOW, check_points=False)  # checked once padded
    if ctx.args.pad_minutes is not None and ctx.args.pad_minutes < 0:
        raise UsageError("--pad-minutes must be zero or more")
    pad = timedelta(seconds=ctx.args.pad_minutes * 60 if ctx.args.pad_minutes is not None
                    else INCIDENT_PADDING_SECONDS)
    window = core.padded(pad, keep_granularity=bool(ctx.args.granularity))
    profile = resolve_profile(ctx, Source.PROCESS, "overview")
    cluster, nodes = nodes_for(ctx)
    report = Report("incident", f"Incident on {cluster}",
                    {"cluster": cluster, "incident": f"{iso(core.start)} → {iso(core.end)}",
                     "padding": str(pad), "profile": profile.name, **window_context(window)})
    rows: List[Tuple[str, SeriesSummary]] = []
    for proc in nodes:
        rows += [(proc.label(), s) for s in fetch_process(ctx, proc, profile, window, report)]
    rows.sort(key=lambda r: {"crit": 0, "warn": 1}.get(str(r[1].severity), 2))
    add_series_section(report, "Measurements across the padded window (worst first)", rows,
                       SNAPSHOT_COLUMNS + ["peak at"], node_window=window)
    _alerts(ctx, cluster, window, report)
    _events(ctx, cluster, window, report)
    return report


def _instant(alert: Dict[str, Any], key: str) -> Optional[datetime]:
    stamp = alert.get(key)
    if not stamp:
        return None
    try:
        return parse_instant(stamp)
    except UsageError as exc:
        raise AtlasCliError(f"alert {alert.get('id', '?')}: unreadable {key} time {stamp!r}") from exc


def _open_during(alert: Dict[str, Any], window: Window) -> bool:
    """Opened before the window ended, and not resolved before it started."""
    created, resolved = _instant(alert, "created"), _instant(alert, "resolved")
    if created is None:
        raise AtlasCliError(f"alert {alert.get('id', '?')} has no created time")
    return created <= window.end and (resolved is None or resolved >= window.start)


def _all_pages(ctx: RunContext, command: Tuple[str, ...], params: Dict[str, Any], what: str,
               section: Section) -> List[Dict[str, Any]]:
    """Every page of a `results` list endpoint, up to MAX_PAGES (then a note says so)."""
    items: List[Dict[str, Any]] = []
    for page in range(1, MAX_PAGES + 1):
        payload = ctx.cli.api(command, {**params, "itemsPerPage": PAGE_SIZE, "pageNum": page})
        batch = require_list(payload, "results", what)
        items += batch
        total = payload.get("totalCount") if isinstance(payload, dict) else None
        if len(batch) < PAGE_SIZE or (isinstance(total, int) and len(items) >= total):
            return items
    section.notes.append(f"Stopped after {MAX_PAGES * PAGE_SIZE} {what}; any further ones were "
                         "not fetched, so this list may be incomplete.")
    return items


def _alerts(ctx: RunContext, cluster: str, window: Window, report: Report) -> None:
    section = Section("Alerts open at any time during the window",
                      ["created", "resolved", "status", "severity", "event", "metric", "host"])
    for alert in _all_pages(ctx, Command.ALERTS, {}, "alerts", section):
        if alert.get("clusterName") not in (None, cluster):
            continue
        if not _open_during(alert, window):
            continue
        section.rows.append([alert.get("created"), alert.get("resolved"), alert.get("status"),
                             alert.get("severity"), alert.get("eventTypeName"),
                             alert.get("metricName"), alert.get("hostnameAndPort")])
        section.data.append(alert)
    report.sections.append(section)


def _events(ctx: RunContext, cluster: str, window: Window, report: Report) -> None:
    section = Section("Project events in the window", ["created", "event", "host", "user"])
    events = list(_all_pages(ctx, Command.EVENTS, {
        "clusterNames": [cluster], "minDate": iso(window.start), "maxDate": iso(window.end)},
        "events", section))
    events.sort(key=lambda e: e.get("created") or "")
    for event in events:
        host = event.get("hostname") or ""
        if event.get("port"):
            host = f"{host}:{event['port']}"
        section.rows.append([event.get("created"), event.get("eventTypeName"), host,
                             event.get("username") or event.get("publicKey") or ""])
        section.data.append(event)
    report.sections.append(section)
