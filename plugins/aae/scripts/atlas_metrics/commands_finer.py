"""Finer-scope commands: per collection, per query shape, per Search index."""

from __future__ import annotations

from typing import Any, Dict, List, Tuple

from atlas_metrics.constants import (
    DEFAULT_HISTORY_WINDOW,
    DEFAULT_TOP_N,
    ClusterView,
    Command,
    Source,
)
from atlas_metrics.commands_cluster import (
    add_series_section,
    nodes_for,
    resolve_profile,
    summarize_payload,
    window_for,
)
from atlas_metrics.context import SERIES_COLUMNS, RunContext, collect_atlas_notes, window_context
from atlas_metrics.errors import AtlasCliError, NoDataError, UsageError
from atlas_metrics.logging_setup import get_logger
from atlas_metrics.measurement_catalog import QUERY_SHAPE_COMMANDS
from atlas_metrics.report import Report, Section
from atlas_metrics.summarize import SeriesSummary, human
from atlas_metrics.time_window import epoch_ms, iso

log = get_logger("commands.finer")

NAMESPACE_COLUMNS = ["namespace", "measurement", "last", "avg", "max", "p95", "peak at", "status"]

PIN_HINT = (
    "Collection latency is collected for the busiest namespaces automatically and for any "
    "namespace you pin. Pinning changes a cluster setting, so these skills never do it: pin in "
    "the Atlas UI (Metrics → Collection latency) or with `atlas api collectionLevelMetrics "
    "pinNamespaces` yourself."
)


def _split_namespace(namespace: str) -> Tuple[str, str]:
    db, dot, coll = namespace.partition(".")
    if not dot or not db or not coll:
        raise UsageError(f"namespace {namespace!r} must look like <database>.<collection>")
    return db, coll


# ------------------------------------------------------------------ collections

def cmd_collections(ctx: RunContext) -> Report:
    profile = resolve_profile(ctx, Source.COLLECTION, "collection-latency")
    window = window_for(ctx, DEFAULT_HISTORY_WINDOW)
    cluster = ctx.flag("cluster")
    if not cluster:
        raise UsageError("--cluster is required")
    view = ClusterView(ctx.args.view.upper()) if ctx.args.view else ClusterView.PRIMARY
    top = ctx.args.top or DEFAULT_TOP_N
    span = {"start": iso(window.start), "end": iso(window.end)}
    report = Report("collections", f"Collection latency on {cluster} — profile {profile.name}",
                    {"cluster": cluster, "view": str(view), "profile": profile.name,
                     **window_context(window)})
    report.context.pop("granularity")  # Atlas picks it for this endpoint

    ranked_payload = ctx.cli.api(Command.COLL_NAMESPACES,
                                 {"clusterName": cluster, "clusterView": str(view), **span})
    collect_atlas_notes(report, ranked_payload)
    ranked = list((ranked_payload or {}).get("rankedNamespaces") or [])
    pinned_payload = ctx.cli.api(Command.COLL_PINNED, {"clusterName": cluster})
    pinned = list((pinned_payload or {}).get("pinnedNamespaces") or [])

    ranking = Section("Busiest namespaces by total execution time", ["rank", "namespace", "pinned"])
    for i, ns in enumerate(ranked[:top], 1):
        ranking.rows.append([i, ns, "yes" if ns in pinned else ""])
        ranking.data.append({"rank": i, "namespace": ns, "pinned": ns in pinned})
    ranking.notes.append(PIN_HINT)
    report.sections.append(ranking)

    targets = list(ctx.args.namespace or []) or ranked[:top]
    if not targets:
        raise NoDataError(f"no collection-level activity recorded for {cluster} in "
                          f"{window.describe()}, and no --namespace given. {PIN_HINT}")
    rows: List[Tuple[str, SeriesSummary]] = []
    for ns in targets:
        db, coll = _split_namespace(ns)
        payload = ctx.cli.api(Command.COLL_MEASUREMENTS, {
            "clusterName": cluster, "clusterView": str(view), "databaseName": db,
            "collectionName": coll, "metrics": list(profile.measurements), **span})
        collect_atlas_notes(report, payload)
        rows += [(ns, s) for s in summarize_payload(payload, profile, f"collStats {ns}")]
    add_series_section(report, profile.description, rows, NAMESPACE_COLUMNS)
    return report


# ----------------------------------------------------------------- query shapes

_SHAPE_SORT_KEYS = {
    "total-time": "totalWorkingMillis", "avg-time": "avgWorkingMillis", "count": "execCount",
    "p99": "p99ExecMicros", "docs-examined": "docsExamined", "docs-ratio": "docsExaminedRatio",
    "keys-ratio": "keysExaminedRatio", "cpu": "cpuTime", "bytes-read": "bytesRead",
}
SHAPE_SORTS = tuple(_SHAPE_SORT_KEYS)


def cmd_query_shapes(ctx: RunContext) -> Report:
    window = window_for(ctx, DEFAULT_HISTORY_WINDOW)
    cluster = ctx.flag("cluster")
    if not cluster:
        raise UsageError("--cluster is required")
    commands = ctx.args.shape_command or []
    bad = [c for c in commands if c not in QUERY_SHAPE_COMMANDS]
    if bad:
        raise UsageError(f"--command {bad} not in {sorted(QUERY_SHAPE_COMMANDS)}")
    span = {"since": epoch_ms(window.start), "until": epoch_ms(window.end)}
    report = Report("query-shapes", f"Query shapes on {cluster}",
                    {"cluster": cluster, "window": f"{iso(window.start)} → {iso(window.end)}"})
    if ctx.args.shape:
        return _shape_details(ctx, cluster, span, report)
    top = ctx.args.top or DEFAULT_TOP_N
    sort_key = _SHAPE_SORT_KEYS[ctx.args.sort or "total-time"]
    payload = ctx.cli.api(Command.SHAPE_SUMMARIES, {
        "clusterName": cluster, "namespaces": ctx.args.namespace or [], "commands": commands,
        "nSummaries": max(top, 100), **span})
    collect_atlas_notes(report, payload)
    summaries = [s for s in (payload or {}).get("summaries") or []
                 if ctx.args.include_system or not s.get("systemQuery")]
    summaries.sort(key=lambda s: s.get(sort_key) or 0, reverse=True)
    report.context["sorted by"] = ctx.args.sort or "total-time"
    section = Section(f"Top {top} query shapes", ["#", "namespace", "command", "count", "avg",
                                                   "p99", "total", "docs examined/returned",
                                                   "keys examined/returned", "shape hash"])
    for i, s in enumerate(summaries[:top], 1):
        section.rows.append([
            i, s.get("namespace"), s.get("command"), human(s.get("execCount"), "SCALAR"),
            human(s.get("avgWorkingMillis"), "MILLISECONDS"), human(s.get("p99ExecMicros"), "MICROSECONDS"),
            human(s.get("totalWorkingMillis"), "MILLISECONDS"), human(s.get("docsExaminedRatio"), "SCALAR"),
            human(s.get("keysExaminedRatio"), "SCALAR"), (s.get("queryShapeHash") or "")[:16]])
        section.data.append(s)
    if not summaries:
        section.notes.append("No query shapes recorded. Query shape insights need MongoDB 8.0+ "
                             "and a dedicated (M10+) cluster.")
    section.notes.append("Show one shape in full with --shape <hash>.")
    report.sections.append(section)
    return report


def _shape_details(ctx: RunContext, cluster: str, span: Dict[str, Any], report: Report) -> Report:
    payload = ctx.cli.api(Command.SHAPE_DETAILS, {"clusterName": cluster,
                                                  "queryShapeHash": ctx.args.shape, **span})
    collect_atlas_notes(report, payload)
    stats = (payload or {}).get("queryStats") or {}
    section = Section(f"Query shape {ctx.args.shape}", ["field", "value"])
    for key in ("namespace", "command", "queryShape", "execCount", "avgWorkingMillis",
                "p50ExecMicros", "p90ExecMicros", "p99ExecMicros", "docsExamined", "docsReturned",
                "docsExaminedRatio", "keysExamined", "keysExaminedRatio", "bytesRead", "cpuTime"):
        section.rows.append([key, stats.get(key)])
    for seen in ("firstSeen", "lastSeen"):
        info = (payload or {}).get(seen) or {}
        section.rows.append([seen, f"{info.get('applicationName', '')} "
                                   f"{info.get('driverName', '')} {info.get('driverVersion', '')}".strip()])
    section.data.append(payload or {})
    report.sections.append(section)
    return report


# ----------------------------------------------------------------------- search

def cmd_search(ctx: RunContext) -> Report:
    mode = "index" if (ctx.args.namespace or ctx.args.index) else "hardware"
    profile = resolve_profile(ctx, Source.SEARCH_INDEX if mode == "index" else Source.SEARCH_HARDWARE,
                              "search-index" if mode == "index" else "search-hardware")
    window = window_for(ctx, DEFAULT_HISTORY_WINDOW)
    cluster, nodes = nodes_for(ctx, default_nodes="primary")
    span = {"granularity": str(window.granularity), "start": iso(window.start), "end": iso(window.end)}
    report = Report("search", f"Atlas Search {mode} metrics on {cluster} — profile {profile.name}",
                    {"cluster": cluster, "profile": profile.name, **window_context(window)})
    rows: List[Tuple[str, SeriesSummary]] = []
    for proc in nodes:
        base = {"processId": proc.process_id, **span, "metrics": list(profile.measurements)}
        if mode == "hardware":
            payload = ctx.cli.api(Command.FTS_HARDWARE, base)
            collect_atlas_notes(report, payload)
            for key in ("hardwareMeasurements", "statusMeasurements"):
                rows += [(proc.label(), s) for s in
                         summarize_payload({"measurements": (payload or {}).get(key) or []},
                                           profile, "search hardware")]
            continue
        if not ctx.args.namespace:
            raise UsageError("--index needs --namespace <database>.<collection>")
        db, coll = _split_namespace(ctx.args.namespace[0])
        params = {**base, "databaseName": db, "collectionName": coll}
        if ctx.args.index:
            payload = ctx.cli.api(Command.FTS_ONE_INDEX, {**params, "indexName": ctx.args.index})
        else:
            payload = ctx.cli.api(Command.FTS_INDEXES, params)
        collect_atlas_notes(report, payload)
        rows += [(f"{proc.alias} {_index_label(raw, ctx.args.index)}", s)
                 for raw, s in _index_series(payload, profile)]
    if not rows:
        raise NoDataError(f"no Atlas Search {mode} metrics for {cluster} in {window.describe()}. "
                          "Search metrics exist only where an Atlas Search or Vector Search index "
                          "is defined.", {"warnings": report.atlas_warnings})
    add_series_section(report, profile.description, rows, SERIES_COLUMNS)
    return report


def _index_series(payload: Any, profile) -> List[Tuple[Dict[str, Any], SeriesSummary]]:
    if not isinstance(payload, dict):
        raise AtlasCliError(f"search index metrics returned an unexpected shape: {str(payload)[:200]}")
    out = []
    for raw in payload.get("indexStatsMeasurements") or []:
        summaries = summarize_payload({"measurements": [raw]}, profile, "search index")
        out += [(raw, s) for s in summaries]
    return out


def _index_label(raw: Dict[str, Any], explicit: str) -> str:
    return explicit or raw.get("indexName") or raw.get("indexId") or ""
