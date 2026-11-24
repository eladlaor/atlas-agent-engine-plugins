---
name: atlas-metrics-history
description: "MongoDB Atlas cluster metrics over a time window, read-only through the atlas CLI: min / avg / max / p95 and the time of the peak per measurement and node, optionally compared with the same window a day or a week earlier (Δ%). Use when the user asks \"what did CPU look like over the last 24 hours\", \"show me metrics between 14:00 and 15:00\", \"is this higher than last week\", \"trend of connections this week\", \"compare today with yesterday\", or wants any profile's history. Never changes the cluster."
---

# Atlas metrics: history and comparison

Statistics for a window of any length, per node and measurement. Add `--compare`
to set it against an earlier window of the same length.

## Run it

The engine is `../../scripts/atlas-metrics.sh`, resolved relative to the directory
of this `SKILL.md`. Call it `$AM` below.

```bash
$AM history --cluster <name> --last 24h
$AM history --cluster <name> --start 2026-11-20T14:00:00Z --end 2026-11-20T15:00:00Z --profile latency
$AM history --cluster <name> --last 6h --compare 7d          # same 6h, one week earlier
$AM history --cluster <name> --last 7d --profile connections --nodes primary --format json
```

- **Window:** use `--last` (`90m`, `6h`, `7d`, or ISO `PT6H`) or `--start`/`--end`
  in ISO 8601 UTC, never both. Convert the user's local times to UTC, and state the
  conversion.
- **Time resolution** is chosen from the window length (up to 1h → 1 minute, up to
  1 day → 5 minutes, up to 7 days → 1 hour, longer → 1 day). Override it with
  `--granularity` only when the user asks for finer or coarser points. Atlas keeps
  1- and 5-minute points for 48 hours and hourly ones for 63 days, so the engine moves
  an older window to the finest resolution Atlas still has. A window shorter than that
  (15 minutes last week) is refused with the width to widen it to: widen it, don't
  report "no data".
- **A paused cluster** answers only for an explicit `--start`/`--end` ending before it
  paused (`$AM hosts` shows when it last reported). That's how to do a post-mortem on
  a cluster someone paused afterwards.
- **Profile and nodes** work as in `atlas-metrics-snapshot`. `$AM profiles list`
  shows the choices.

## Read the result

- **`peak at` answers "when".** Quote it, in the user's timezone when you know it.
- **With `--compare`,** `Δ avg %` and `Δ max %` are relative changes. A large Δ on a
  small baseline is noise. Say so rather than alarming the user.
- Exit 1 means a threshold was crossed somewhere in the window. That says the
  measurement went past the line at some point; it does not mean it is still past it.
- `gaps` counts missing samples. They are never treated as zero.

Exit codes are as in `atlas-metrics-snapshot` (0 ok, 1 thresholds crossed, 2 usage,
3 CLI failure or cluster unavailable, 4 no data, 5 engine bug). Report 2–5 as failures, never as "nothing found".

## Next steps

- A peak lines up with an incident → `atlas-metrics-incident` for alerts and events around it.
- Which collection or query drove it → `atlas-metrics-collections`, `atlas-metrics-query-shapes`.
