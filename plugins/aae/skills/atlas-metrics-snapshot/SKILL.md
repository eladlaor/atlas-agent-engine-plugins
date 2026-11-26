---
name: atlas-metrics-snapshot
description: "Right-now health of a MongoDB Atlas cluster from its monitoring metrics, read-only through the atlas CLI: CPU, memory and cache, connections, operation rates, replication lag and query targeting per node, with warn/crit thresholds. Use when the user asks \"how is my cluster doing\", \"is my cluster healthy\", \"check cluster metrics\", \"what's the CPU on my primary\", \"is replication lagging right now\", or wants a quick look at one concern (cpu, memory-cache, connections, replication, concurrency, errors, ...). Never changes the cluster."
---

# Atlas metrics: snapshot

The current state of every node in one cluster, over a short recent window
(15 minutes by default), checked against each profile's thresholds.

## Run it

The engine is `../../scripts/atlas-metrics.sh`, resolved relative to the directory
of this `SKILL.md`. Call it `$AM` below.

```bash
$AM snapshot --cluster <name>                               # overview profile, all nodes
$AM snapshot --cluster <name> --profile replication --nodes secondaries
$AM snapshot --cluster <name> --profile cpu --last 5m --granularity PT10S   # premium monitoring (M40+) only
$AM snapshot --cluster <name> --add TICKETS_AVAILABLE_READS --threshold PROCESS_NORMALIZED_CPU_USER:warn=50,crit=80
```

0. **First run on this machine?** The skills need the read-only service account
   `atlas-metrics-readonly` (Project Read Only + Project Observability Viewer) saved
   as the CLI profile `metrics`. If any command fails with `unauthorized`, `not logged in`
   or `ORG_REQUIRES_ACCESS_LIST`, the engine prints the fix. Follow it, using the setup
   in `atlas-metrics-profiles`.
1. **Cluster.** If the user didn't name one and no config default exists, run
   `$AM hosts --cluster <guess>` or ask. Never guess silently between clusters.
2. **Concern → profile.** Pick the built-in profile that matches the question:
   `overview` (default), `cpu`, `memory-cache`, `operations`, `latency`,
   `query-efficiency`, `connections`, `replication`, `concurrency`, `network`,
   `errors`. `$AM profiles list` shows all of them, including the
   user's own.
3. **Replication lag lives on the secondaries.** A primary doesn't report oplog lag;
   the report notes it once per primary. That's expected, not an error.
4. **Narrow when asked:** `--nodes primary|secondaries|all`, `--shard <replica set>`,
   `--host <text>`.
5. Use `--format json` when you will reason over the numbers, and `--format markdown`
   when you'll paste the result to the user.

## Read the result

- **Exit 1 means a threshold was crossed, or a node stopped reporting.** It is not an
  error. Lead with a `not reporting` node if there is one, then the `crit` rows, then the
  `warn` rows, naming the node and its role.
- **`ATLAS WARNING` lines are Atlas explaining itself,** for example a tier too small
  for that metric. Repeat them to the user and don't drop them.
- **Gaps are missing samples, not zeros.** A node with many gaps is a finding in itself.
  Replication lag is sampled every 85 seconds, so a few gaps on it at 1-minute
  resolution are normal. A status ending in `stale (silent since <time>)` means the node
  stopped reporting then; it is also listed under `not reporting`. Report that before any
  threshold result.
- **`no threshold`** means the profile sets none for that row: nothing was judged, so
  don't call it healthy.
- Thresholds are starting points, not universal truths. If the user says a value is
  normal for them, offer to save it in a profile (`atlas-metrics-profiles`).

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Ran, nothing crossed a threshold, and every node reported |
| 1 | Ran, and something crossed a threshold or a node stopped reporting |
| 2 | Bad flag, profile or config |
| 3 | The atlas CLI failed, or the cluster can't answer (not found, or paused for a "now" question). The message names the command and quotes its error. |
| 4 | Atlas returned no data, including a window where every series came back empty |
| 5 | An internal error in the engine. This is a bug, never a finding about the cluster. |

Report exit codes 2–5 as failures, quoting the message. Never present them as "no issues found".

## Next steps

- "Since when?" or "is this normal?" → `atlas-metrics-history` (with `--compare 7d`).
- Something specific happened at a known time → `atlas-metrics-incident`.
- Slow queries behind high CPU → `atlas-metrics-advisor` and `atlas-metrics-query-shapes`.
- Auth or "command not found" errors → run `$AM doctor`, then the `atlas-cli` specialist.
