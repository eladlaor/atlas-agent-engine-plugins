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
$AM snapshot --cluster <name> --profile cpu --last 5m --granularity PT10S
$AM snapshot --cluster <name> --add TICKETS_AVAILABLE_READS --threshold PROCESS_NORMALIZED_CPU_USER:warn=50,crit=80
```

1. **Cluster.** If the user didn't name one and no config default exists, run
   `$AM hosts --cluster <guess>` or ask. Never guess silently between clusters.
2. **Concern → profile.** Pick the built-in profile that matches the question:
   `overview` (default), `cpu`, `memory-cache`, `operations`, `latency`,
   `query-efficiency`, `connections`, `replication`, `concurrency`, `network`,
   `transactions`, `errors`. `$AM profiles list` shows all of them, including the
   user's own.
3. **Narrow when asked:** `--nodes primary|secondaries|all`, `--shard <replica set>`,
   `--host <text>`.
4. Use `--format json` when you will reason over the numbers, and `--format markdown`
   when you'll paste the result to the user.

## Read the result

- **Exit 1 means a threshold was crossed.** It is not an error. Lead with the `crit`
  rows, then the `warn` rows, naming the node and its role.
- **`ATLAS WARNING` lines are Atlas explaining itself,** for example a tier too small
  for that metric. Repeat them to the user and don't drop them.
- **Gaps are missing samples, not zeros.** A node with many gaps is a finding in itself.
- Thresholds are starting points, not universal truths. If the user says a value is
  normal for them, offer to save it in a profile (`atlas-metrics-profiles`).

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Ran, and nothing crossed a threshold |
| 1 | Ran, and something crossed a threshold |
| 2 | Bad flag, profile or config |
| 3 | The atlas CLI failed. The message names the command and quotes its error. |
| 4 | Atlas returned no data |

Report exit codes 2–4 as failures, quoting the message. Never present them as "no issues found".

## Next steps

- "Since when?" or "is this normal?" → `atlas-metrics-history` (with `--compare 7d`).
- Something specific happened at a known time → `atlas-metrics-incident`.
- Slow queries behind high CPU → `atlas-metrics-advisor` and `atlas-metrics-query-shapes`.
- Auth or "command not found" errors → run `$AM doctor`, then the `atlas-cli` specialist.
