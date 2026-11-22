---
name: atlas-metrics-advisor
description: "MongoDB Atlas Performance Advisor findings, read-only through the atlas CLI: slow-query log lines with documents examined vs returned, suggested indexes with their estimated impact, unused / redundant / hidden indexes that are candidates to drop, and schema advice. Use when the user asks \"why are my queries slow\", \"slow queries\", \"what index should I add\", \"which indexes are unused\", \"can I drop any indexes\", \"schema recommendations\", \"Performance Advisor\". Never creates or drops an index, never changes a setting."
---

# Atlas metrics: Performance Advisor

There are four parts, all on by default. Pick some with `--part`.

| Part | Answers |
|---|---|
| `slow-queries` | Which operations were slow, on which namespace, and how much they scanned |
| `suggested-indexes` | Which index Atlas suggests, and how many slow query shapes it would help |
| `drop-indexes` | Unused, redundant and hidden indexes: space and write cost with no read benefit |
| `schema` | Schema anti-patterns Atlas detected, such as unbounded arrays or oversized documents |

## Run it

The engine is `../../scripts/atlas-metrics.sh`, resolved relative to the directory
of this `SKILL.md`. Call it `$AM` below.

```bash
$AM advisor --cluster <name> --last 24h
$AM advisor --cluster <name> --part slow-queries --namespace app.orders --lines 20
$AM advisor --cluster <name> --part suggested-indexes --part drop-indexes --format markdown
$AM advisor --cluster <name> --part slow-queries --nodes all --format json   # full log lines in 'line'
```

- Slow queries are read per node, from the primary by default. Use `--nodes all`
  when secondaries serve reads.
- The window applies to slow queries and suggested indexes. Drop candidates and
  schema advice are Atlas's current view, whatever the window.

## Read the result

- **This skill recommends. It never acts.** Creating or dropping an index changes the
  cluster, so present the exact index and let the user decide. Point them to the
  `atlas-cli` specialist, or to the Atlas UI, to apply it.
- **A slow query with `index used = False` and a high examined/returned ratio** is the
  strongest case for a suggested index. Connect the two when the same namespace
  appears in both parts.
- **Before recommending a drop,** check that `accesses` is zero over a period that
  covers the workload's full cycle. A monthly report job may use an index that looks
  unused this week. Say so.
- The Performance Advisor needs a dedicated (M10+) cluster. Repeat Atlas's warning
  when it appears.

Exit codes are as in `atlas-metrics-snapshot`. Report 2–4 as failures, never as "nothing found".
