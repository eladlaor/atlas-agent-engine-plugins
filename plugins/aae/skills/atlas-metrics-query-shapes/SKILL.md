---
name: atlas-metrics-query-shapes
description: "Per-query-pattern statistics for a MongoDB Atlas cluster (query shape insights), read-only through the atlas CLI: the top query shapes by total time, average or p99 latency, execution count, documents examined per returned, CPU or bytes read, filterable by namespace and command, and one shape in full with the app and driver that sent it. Use when the user asks \"which query is slowest\", \"what queries hit this collection\", \"top queries by CPU\", \"which app sends this query\", \"query stats\", \"query shapes\". Never changes the cluster."
---

# Atlas metrics: query shapes

A **query shape** is a query with its values stripped out: `{status: ?string}`
covers every `find({status: "x"})`. Atlas aggregates statistics per shape. This
skill ranks the shapes and can open one in full.

## Run it

The engine is `../../scripts/atlas-metrics.sh`, resolved relative to the directory
of this `SKILL.md`. Call it `$AM` below.

```bash
$AM query-shapes --cluster <name> --last 24h                     # top 10 by total time
$AM query-shapes --cluster <name> --sort p99 --top 5
$AM query-shapes --cluster <name> --sort docs-ratio --namespace app.orders --command find
$AM query-shapes --cluster <name> --shape <queryShapeHash> --format json
```

- `--sort` takes `total-time` (the default), `avg-time`, `count`, `p99`,
  `docs-examined`, `docs-ratio`, `keys-ratio`, `cpu` or `bytes-read`. Match it to the
  question: "slowest" → `p99` or `avg-time`; "most load" → `total-time` or `cpu`;
  "missing index" → `docs-ratio`.
- `--command` filters by MongoDB command type: find, aggregate, distinct, count,
  insert, update or delete. Repeat it for several.
- Internal system queries are hidden. `--include-system` shows them.

## Read the result

- **`docs examined/returned` far above 1 means the query scans to find a few
  documents.** That is the classic missing-index signature. Hand off to
  `atlas-metrics-advisor`.
- **The shape hash identifies the shape.** Open it with `--shape <hash>` to see the
  full shape and the `firstSeen`/`lastSeen` application and driver, which answers
  "who sends this".
- **No shapes returned:** this feature needs MongoDB 8.0+ on a dedicated (M10+)
  cluster. Atlas's warning, or the report's own note, says so. Repeat it rather than
  reporting "no slow queries".

Exit codes are as in `atlas-metrics-snapshot`. Report 2–4 as failures, never as "nothing found".
