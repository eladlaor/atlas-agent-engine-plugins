---
name: atlas-metrics-incident
description: "Reconstruct what happened to a MongoDB Atlas cluster around a given time, read-only through the atlas CLI: every node's metrics across the incident window plus padding (worst first, with peak times), the Atlas alerts that opened, updated or resolved in it, and the project events (elections, restarts, scaling, config changes) inside it. Use when the user says \"what happened at 14:00\", \"we had an outage last night\", \"the app was slow between X and Y\", \"post-mortem for the cluster\", \"was there an election\", \"incident timeline\". Never changes the cluster or acknowledges alerts."
---

# Atlas metrics: incident timeline

One report that puts metrics, alerts and events for one stretch of time side by
side, which is the raw material of a post-mortem.

## Run it

The engine is `../../scripts/atlas-metrics.sh`, resolved relative to the directory
of this `SKILL.md`. Call it `$AM` below.

```bash
$AM incident --cluster <name> --start 2026-11-20T14:00:00Z --end 2026-11-20T14:30:00Z
$AM incident --cluster <name> --start 2026-11-20T02:10:00Z --pad-minutes 60 --profile replication
$AM incident --cluster <name> --start 2026-11-20T14:00:00Z --end 2026-11-20T14:30:00Z --format markdown
```

- **`--start` is required.** An incident has a beginning. `--end` defaults to now.
  Convert the user's local time to UTC and state the conversion.
- **Padding** (15 minutes on each side by default) shows what was happening *before*
  the problem. That is often the cause.
- **`--profile`** sets which measurements are shown, as in `atlas-metrics-snapshot`:
  `overview` by default; `replication`, `concurrency` or `latency` are good second looks.

## Read the result

Build the timeline in this order, and quote times:

1. **Events** are what changed: elections, restarts, scaling, config changes, maintenance.
2. **Alerts** are what Atlas noticed, and when: every alert open at any time in the
   window, including ones that opened before it.
3. **Metrics, worst first,** show what the nodes went through, with `peak at` times.

Then say what came first. A primary election 2 minutes before the CPU peak reads
differently from one 2 minutes after. Mark what is correlation and what the evidence
supports as cause.

Exit codes are as in `atlas-metrics-snapshot`. Report 2–5 as failures, never as "nothing found".

## Next steps

- The query behind a CPU peak → `atlas-metrics-query-shapes` over the same window.
- Slow-query logs from the window → `atlas-metrics-advisor --part slow-queries` with the same `--start`/`--end`.
