"""Argument parsing and dispatch. Precedence: flag > config defaults > built-in."""

from __future__ import annotations

import argparse
import sys
from typing import Callable, Dict, List, Optional

from atlas_metrics.atlas_cli import AtlasCli
from atlas_metrics.commands_admin import cmd_doctor, cmd_profiles
from atlas_metrics.commands_advice import ADVISOR_PARTS, cmd_advisor, cmd_incident
from atlas_metrics.commands_cluster import cmd_hosts, cmd_process, cmd_storage
from atlas_metrics.commands_finer import SHAPE_SORTS, cmd_collections, cmd_query_shapes, cmd_search
from atlas_metrics.constants import (
    ENGINE_NAME,
    EXIT_FINDINGS,
    EXIT_INTERNAL,
    EXIT_OK,
    ClusterView,
    Granularity,
    NodeSelector,
    OutputFormat,
    Severity,
    Source,
)
from atlas_metrics.context import RunContext
from atlas_metrics.errors import MetricsError
from atlas_metrics.logging_setup import configure_logging, get_logger
from atlas_metrics.profiles import load_config
from atlas_metrics.report import Report, render

log = get_logger("cli")
_OFFLINE = {"profiles"}  # commands that never call Atlas


def _common(p: argparse.ArgumentParser) -> None:
    g = p.add_argument_group("target")
    g.add_argument("--cluster", help="cluster name (default: config defaults.cluster)")
    g.add_argument("--project-id", help="Atlas project ID (default: the CLI profile's project)")
    g.add_argument("--atlas-profile", help="atlas CLI profile name (-P)")
    o = p.add_argument_group("output")
    o.add_argument("--format", choices=[f.value for f in OutputFormat])
    o.add_argument("--config", help="config file (default: ~/.config/atlas-metrics/config.json)")
    o.add_argument("--log-level", default="", help="debug | info | warning | error (stderr, JSON)")


def _window(p: argparse.ArgumentParser) -> None:
    g = p.add_argument_group("time window")
    g.add_argument("--last", help="how far back from now: 15m, 6h, 7d, PT6H, P7D")
    g.add_argument("--start", help="window start, ISO 8601 UTC, e.g. 2026-11-20T14:00:00Z")
    g.add_argument("--end", help="window end (default: now)")
    g.add_argument("--granularity", choices=[x.value for x in Granularity],
                   help="time between data points (default: chosen from the window length)")


def _nodes(p: argparse.ArgumentParser) -> None:
    g = p.add_argument_group("node selection")
    g.add_argument("--nodes", choices=[n.value for n in NodeSelector])
    g.add_argument("--shard", help="replica set or shard name, e.g. atlas-abc123-shard-0")
    g.add_argument("--host", help="only processes whose hostname contains this text")


def _profile(p: argparse.ArgumentParser) -> None:
    g = p.add_argument_group("profile")
    g.add_argument("--profile", help="measurement profile (see `profiles list`)")
    g.add_argument("--add", action="append", metavar="MEASUREMENT", help="add a measurement")
    g.add_argument("--remove", action="append", metavar="MEASUREMENT", help="drop a measurement")
    g.add_argument("--threshold", action="append", metavar="M:warn=N,crit=N",
                   help="set or override a threshold for this run")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog=ENGINE_NAME,
        description="Read-only Atlas cluster metrics through the atlas CLI. Never changes the cluster.",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("hosts", help="list the cluster's processes and roles")
    _common(p), _nodes(p)

    for name, text in (("snapshot", "how the cluster is doing right now (default last 15m)"),
                       ("history", "statistics over a window (default last 6h), optional compare")):
        p = sub.add_parser(name, help=text)
        _common(p), _window(p), _nodes(p), _profile(p)
        if name == "history":
            p.add_argument("--compare", metavar="DURATION",
                           help="also fetch the same window this long earlier (1d, 7d) and show Δ%%")

    p = sub.add_parser("storage", help="disk space / IOPS / latency, and per-database sizes")
    _common(p), _window(p), _nodes(p)
    p.add_argument("--part", action="append", choices=["disks", "databases"])
    p.add_argument("--disk-profile")
    p.add_argument("--database-profile")
    p.add_argument("--database", action="append", help="only these databases")
    p.add_argument("--top", type=int)
    p.add_argument("--threshold", action="append", metavar="M:warn=N,crit=N")

    p = sub.add_parser("collections", help="per-collection latency and busiest namespaces")
    _common(p), _window(p), _profile(p)
    p.add_argument("--namespace", action="append", help="db.collection (repeatable)")
    p.add_argument("--view", choices=[v.value.lower() for v in ClusterView])
    p.add_argument("--top", type=int)

    p = sub.add_parser("query-shapes", help="per query-shape statistics, or one shape in full")
    _common(p), _window(p)
    p.add_argument("--namespace", action="append")
    p.add_argument("--command", dest="shape_command", action="append",
                   help="MongoDB command type: find, aggregate, update, ...")
    p.add_argument("--sort", choices=SHAPE_SORTS)
    p.add_argument("--top", type=int)
    p.add_argument("--shape", help="query shape hash: show its details")
    p.add_argument("--include-system", action="store_true")

    p = sub.add_parser("search", help="Atlas Search: process hardware, or per-index metrics")
    _common(p), _window(p), _nodes(p), _profile(p)
    p.add_argument("--namespace", action="append", help="db.collection of the indexed collection")
    p.add_argument("--index", help="one Search index name")

    p = sub.add_parser("advisor", help="slow queries, suggested / droppable indexes, schema advice")
    _common(p), _window(p), _nodes(p)
    p.add_argument("--part", action="append", choices=ADVISOR_PARTS)
    p.add_argument("--namespace", action="append")
    p.add_argument("--top", type=int)
    p.add_argument("--lines", type=int, help="slow-query log lines per node")

    p = sub.add_parser("incident", help="metrics + alerts + events around a time")
    _common(p), _window(p), _nodes(p), _profile(p)
    p.add_argument("--pad-minutes", type=int, help="context before/after the window (default 15)")

    p = sub.add_parser("profiles", help="list / show / measurements / validate / init")
    _common(p)
    p.add_argument("action", choices=["list", "show", "measurements", "validate", "init"])
    p.add_argument("name", nargs="?")
    p.add_argument("--source", choices=[s.value for s in Source])

    p = sub.add_parser("doctor", help="check CLI version, auth and every command the engine uses")
    _common(p)
    return parser


_DISPATCH: Dict[str, Callable[[RunContext], Report]] = {
    "hosts": cmd_hosts,
    "snapshot": lambda ctx: cmd_process(ctx, "snapshot"),
    "history": lambda ctx: cmd_process(ctx, "history"),
    "storage": cmd_storage,
    "collections": cmd_collections,
    "query-shapes": cmd_query_shapes,
    "search": cmd_search,
    "advisor": cmd_advisor,
    "incident": cmd_incident,
    "profiles": cmd_profiles,
    "doctor": cmd_doctor,
}


class _OfflineCli:
    """Stands in for AtlasCli on commands that must not need the atlas binary."""


def main(argv: Optional[List[str]] = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        configure_logging(args.log_level)
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    ctx: Optional[RunContext] = None
    try:
        config = load_config(args.config or "")
        fmt = OutputFormat(args.format or config.default("format") or OutputFormat.TABLE.value)
        if args.command in _OFFLINE:
            cli = _OfflineCli()
        else:
            cli = AtlasCli(project_id=args.project_id or config.default("project_id"),
                           profile=args.atlas_profile or config.default("atlas_profile"))
        ctx = RunContext(cli=cli, config=config, args=args, fmt=fmt)  # type: ignore[arg-type]
        report = _DISPATCH[args.command](ctx)
        for note in ctx.notes:
            report.add_warning(note)
        rendered = render(report, fmt)
    except MetricsError as exc:
        log.error("command failed", extra={"command": args.command, "error": str(exc),
                                           "exit_code": exc.exit_code, **exc.context})
        print(f"error: {exc}", file=sys.stderr)
        for note in (ctx.notes if ctx is not None else []):
            print(f"note: {note}", file=sys.stderr)
        return exc.exit_code
    except Exception as exc:  # noqa: BLE001 - the last line before exit; logged and re-coded
        log.exception("internal error", extra={"command": args.command})
        print(f"internal error in atlas-metrics (a bug, not a cluster finding): "
              f"{type(exc).__name__}: {exc}", file=sys.stderr)
        return EXIT_INTERNAL
    print(rendered)
    return EXIT_FINDINGS if report.verdict in (Severity.WARN, Severity.CRIT) else EXIT_OK
