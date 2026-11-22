---
name: atlas-metrics-search
description: "Atlas Search and Vector Search metrics for a MongoDB Atlas cluster, read-only through the atlas CLI: per-index query counts, errors, write rates, size on disk and index lag, or the Search process's own CPU, memory, JVM heap and disk use. Use when the user asks \"how is my search index doing\", \"vector search latency or errors\", \"is my search index lagging\", \"how big is my search index\", \"mongot memory\", \"Atlas Search metrics\". Never changes the cluster or any index."
---

# Atlas metrics: Search and Vector Search

There are two modes, chosen by the flags:

- **Hardware** (the default) covers the Search process on each node: CPU, resident
  memory, JVM heap, disk use and page faults.
- **Index** (`--namespace`) covers the indexes on one collection: query counts and
  errors, insert/update/delete rates, size on disk and replication lag (how far the
  index trails the collection).

## Run it

The engine is `../../scripts/atlas-metrics.sh`, resolved relative to the directory
of this `SKILL.md`. Call it `$AM` below.

```bash
$AM search --cluster <name>                                       # Search process, primary node
$AM search --cluster <name> --nodes all --last 24h
$AM search --cluster <name> --namespace app.products              # every index on the collection
$AM search --cluster <name> --namespace app.products --index default --last 7d
```

- Nodes default to the primary here, only to keep the output short. Each node runs
  its own Search process, and queries can land on any node that matches the
  application's read preference. Use `--nodes all` before concluding that Search is healthy.
- Profiles: `search-hardware` and `search-index`. Adjust them with
  `--add`/`--remove`/`--threshold`, or define your own (`atlas-metrics-profiles`).

## Read the result

- **`NUMBER_OF_ERROR_QUERIES` above zero is worth reporting** even when it is small:
  a failing Search query returns an error to the application.
- **`REPLICATION_LAG` on an index means Search results are stale** by about that
  much. New documents aren't searchable yet.
- **JVM current memory close to JVM max** means the Search process is short of heap.
- **No data:** Search metrics exist only where an Atlas Search or Vector Search index
  is defined. The engine says so, and you should repeat it rather than report "healthy".

Exit codes are as in `atlas-metrics-snapshot`. Report 2–4 as failures, never as "nothing found".
