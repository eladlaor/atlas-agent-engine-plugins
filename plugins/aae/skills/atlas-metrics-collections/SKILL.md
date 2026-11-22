---
name: atlas-metrics-collections
description: "Per-collection latency for a MongoDB Atlas cluster, read-only through the atlas CLI: the busiest namespaces ranked by total execution time, then each collection's read / write / command rates and average, p50, p95 and p99 latency. Use when the user asks \"which collection is slow\", \"latency per collection\", \"what's the p99 on my orders collection\", \"busiest collections\", \"collection-level metrics\", or \"why is this one collection slow\". Never changes the cluster, and never pins namespaces."
---

# Atlas metrics: per-collection latency

Answers "which collection" questions. First comes the cluster's ranking of the
busiest namespaces, then latency and rates for the top ones, or for the namespaces
you name.

## Run it

The engine is `../../scripts/atlas-metrics.sh`, resolved relative to the directory
of this `SKILL.md`. Call it `$AM` below.

```bash
$AM collections --cluster <name> --last 6h                       # top 10 namespaces
$AM collections --cluster <name> --namespace app.orders --namespace app.users
$AM collections --cluster <name> --profile collection-percentiles --top 5
$AM collections --cluster <name> --view secondary --last 1h      # reads served by secondaries
```

- `--view primary|secondary|individual_process` picks which nodes' traffic is
  aggregated. The default is `primary`.
- `--profile collection-percentiles` shows p50/p95/p99 for every operation type. The
  default `collection-latency` shows rates, averages and p99.
- Atlas picks the time resolution for this endpoint itself, so `--granularity` has no effect here.

## Read the result

- **The ranking is by total execution time,** not by average. A collection with
  cheap but frequent queries can rank first. Say which it is.
- **`pinned`** marks namespaces someone pinned in Atlas, which keeps their latency
  collected even when they aren't among the busiest.
- **An empty result is not "no latency".** Atlas collects this only for the busiest
  namespaces and for pinned ones. If the user's collection is missing, tell them how
  to pin it. Pinning changes a cluster setting, so this skill never pins: the user
  does it in the Atlas UI or with `atlas api collectionLevelMetrics pinNamespaces`.
- Collection-level latency needs a dedicated (M10+) cluster. Atlas's own warning
  says so when it applies, so repeat it.

Exit codes are as in `atlas-metrics-snapshot`. Report 2–4 as failures, never as "nothing found".

## Next steps

- Which query on that collection → `atlas-metrics-query-shapes --namespace <db.coll>`.
- A missing index → `atlas-metrics-advisor --namespace <db.coll>`.
