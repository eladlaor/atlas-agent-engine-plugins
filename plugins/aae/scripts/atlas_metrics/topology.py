"""Cluster name -> the MongoDB processes (host:port) that serve it.

Every per-host metrics endpoint is keyed by process ID, not by cluster name,
and `atlas processes list` returns every process in the project. A process
belongs to the cluster if its user-facing hostname appears in the cluster's
connection strings, or starts with "<cluster-name>-" (which also catches the
config servers and shard members a mongos-only connection string omits).
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict, Iterable, List, Set
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
    )


def cluster_processes(cli: AtlasCli, cluster_name: str) -> List[Process]:
    """All processes of one cluster. Fails loudly if none match."""
    if not cluster_name:
        raise UsageError("--cluster is required")
    try:
        cluster = cli.curated([*Command.CLUSTERS_DESCRIBE, cluster_name])
    except AtlasCliError as exc:
        raise TopologyError(f"could not describe cluster {cluster_name!r}: {exc}") from exc
    if (cluster or {}).get("paused"):
        raise TopologyError(
            f"cluster {cluster_name!r} is paused; a paused cluster reports no metrics. "
            "Resume it first (this engine will not)."
        )
    conn_hosts = _hosts_in_connection_strings(cluster or {})
    prefix = f"{cluster_name.lower()}-"
    raw = _results(cli.curated([*Command.PROCESSES_LIST, "--limit", _PROCESS_PAGE_LIMIT]),
                   "processes list")
    matched = []
    for item in raw:
        proc = _to_process(item)
        alias_host = proc.alias.rsplit(":", 1)[0].lower()
        if alias_host in conn_hosts or alias_host.startswith(prefix):
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
    return sorted(matched, key=lambda p: (p.shard, p.replica_set, not p.is_primary, p.alias))


def select_nodes(
    processes: Iterable[Process], nodes: str = "", shard: str = "", host: str = ""
) -> List[Process]:
    """Narrow processes by role, shard (replica-set name or shard name) and host."""
    selected = list(processes)
    if shard:
        selected = [p for p in selected if shard in (p.replica_set, p.shard)]
        if not selected:
            raise TopologyError(f"no process belongs to shard/replica set {shard!r}")
    if host:
        selected = [p for p in selected if host in p.alias or host in p.process_id]
        if not selected:
            raise TopologyError(f"no process matches host {host!r}")
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
