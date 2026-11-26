"""Cluster name -> the MongoDB processes (host:port) that serve it.

Every per-host metrics endpoint is keyed by process ID, not by cluster name,
and `atlas processes list` returns every process in the project. A process
belongs to the cluster if its user-facing hostname appears in the cluster's
connection strings, or starts with "<cluster-name>-" (which also catches the
config servers and shard members a mongos-only connection string omits).
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any, Dict, Iterable, List, Set, Tuple
from urllib.parse import urlsplit

from atlas_metrics.atlas_cli import AtlasCli
from atlas_metrics.constants import PRIMARY_ROLES, SECONDARY_ROLES, Command, NodeSelector
from atlas_metrics.errors import AtlasCliError, TopologyError, UsageError
from atlas_metrics.logging_setup import get_logger

log = get_logger("topology")
_PROCESS_PAGE_LIMIT = "500"


@dataclass(frozen=True)
class Process:
    process_id: str  # hostname:port, the key every metrics endpoint wants
    alias: str  # user-facing hostname:port, what the user recognises
    role: str  # typeName, e.g. REPLICA_PRIMARY
    replica_set: str
    shard: str
    last_ping: str = ""

    @property
    def is_primary(self) -> bool:
        return self.role in PRIMARY_ROLES

    @property
    def is_secondary(self) -> bool:
        return self.role in SECONDARY_ROLES

    def label(self) -> str:
        return f"{self.alias} ({self.role})"


def _results(payload: Any, what: str) -> List[Dict[str, Any]]:
    if isinstance(payload, list):
        return payload
    if isinstance(payload, dict) and isinstance(payload.get("results"), list):
        return payload["results"]
    raise AtlasCliError(f"{what} returned an unexpected shape: {str(payload)[:200]}")


def _hosts_in_connection_strings(cluster: Dict[str, Any]) -> Set[str]:
    hosts: Set[str] = set()
    strings = cluster.get("connectionStrings") or {}
    for key in ("standard", "standardPrivate"):
        uri = strings.get(key)
        if not uri:
            continue
        netloc = urlsplit(uri).netloc.split("@")[-1]
        for item in netloc.split(","):
            hosts.add(item.split(":")[0].lower())
    return hosts


def _to_process(raw: Dict[str, Any]) -> Process:
    try:
        port = raw["port"]
        hostname = raw["hostname"]
    except KeyError as exc:
        raise AtlasCliError(f"process entry without {exc}: {str(raw)[:200]}") from exc
    alias_host = raw.get("userAlias") or hostname
    return Process(
        process_id=raw.get("id") or f"{hostname}:{port}",
        alias=f"{alias_host}:{port}",
        role=raw.get("typeName", ""),
        replica_set=raw.get("replicaSetName", ""),
        shard=raw.get("shardName", ""),
        last_ping=raw.get("lastPing", ""),
    )


def cluster_processes(cli: AtlasCli, cluster_name: str,
                      allow_paused: bool = False) -> Tuple[List[Process], bool]:
    """All processes of one cluster, and whether it is paused. Fails loudly if none match.

    A paused cluster reports nothing new, but Atlas keeps what it recorded before the
    pause. So a paused cluster is allowed only for an explicit past window
    (`allow_paused`), and refused for "now"-relative questions.
    """
    if not cluster_name:
        raise UsageError("--cluster is required")
    try:
        cluster = cli.curated([*Command.CLUSTERS_DESCRIBE, cluster_name])
    except AtlasCliError as exc:
        raise TopologyError(f"could not describe cluster {cluster_name!r}: {exc}") from exc
    paused = bool((cluster or {}).get("paused"))
    conn_hosts = _hosts_in_connection_strings(cluster or {})
    # Atlas member hostnames: <name>-shard-00-01.<domain> or <name>-config-00-00.<domain>.
    # A bare "<name>-" prefix would also take in cluster "<name>-analytics".
    member = re.compile(rf"^{re.escape(cluster_name.lower())}-(shard|config)-\d+-\d+\.")
    raw = _results(cli.curated([*Command.PROCESSES_LIST, "--limit", _PROCESS_PAGE_LIMIT]),
                   "processes list")
    matched = []
    for item in raw:
        proc = _to_process(item)
        alias_host = proc.alias.rsplit(":", 1)[0].lower()
        if alias_host in conn_hosts or member.match(alias_host):
            matched.append(proc)
    log.info("resolved cluster", extra={"cluster": cluster_name, "matched": len(matched),
                                        "project_processes": len(raw)})
    if not matched:
        seen = sorted({_to_process(i).alias for i in raw})[:20]
        raise TopologyError(
            f"no processes in this project belong to cluster {cluster_name!r}. "
            f"Processes seen: {seen or 'none'}. Free (M0) and Flex clusters expose no "
            "per-process metrics.",
            {"cluster": cluster_name},
        )
    ordered = sorted(matched, key=lambda p: (p.shard, p.replica_set, not p.is_primary, p.alias))
    if paused and not allow_paused:
        last = last_report(ordered)
        raise TopologyError(
            f"cluster {cluster_name!r} is paused (last report {last or 'unknown'}), so it has "
            "no current metrics. Resume it (this engine will not), or look at the time before "
            f"the pause with an explicit window, e.g. --start <time> --end {last or '<time>'}."
        )
    return ordered, paused


def last_report(processes: Iterable[Process]) -> str:
    pings = sorted(p.last_ping for p in processes if p.last_ping)
    return pings[-1] if pings else ""


def select_nodes(
    processes: Iterable[Process], nodes: str = "", shard: str = "", host: str = ""
) -> List[Process]:
    """Narrow processes by role, shard (replica-set name or shard name) and host."""
    selected = list(processes)
    if shard:
        selected = [p for p in selected if shard in (p.replica_set, p.shard)]
        if not selected:
            raise UsageError(f"no process belongs to shard/replica set {shard!r}; "
                             "`hosts` lists them")
    if host:
        selected = [p for p in selected if host in p.alias or host in p.process_id]
        if not selected:
            raise UsageError(f"no process matches host {host!r}; `hosts` lists them")
    selector = NodeSelector(nodes) if nodes else NodeSelector.ALL
    if selector is NodeSelector.PRIMARY:
        selected = [p for p in selected if p.is_primary]
    elif selector is NodeSelector.SECONDARIES:
        selected = [p for p in selected if p.is_secondary]
    if not selected:
        raise TopologyError(f"no {selector} node found in the selection")
    return selected


def describe_processes(processes: Iterable[Process]) -> List[Dict[str, str]]:
    return [
        {"alias": p.alias, "processId": p.process_id, "role": p.role,
         "replicaSet": p.replica_set, "shard": p.shard}
        for p in processes
    ]
