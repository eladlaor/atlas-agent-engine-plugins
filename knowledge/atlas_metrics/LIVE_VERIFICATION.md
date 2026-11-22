# Atlas Metrics Skills — Live Verification Record

- [Summary](#summary)
- [Environment](#environment)
- [Results by command](#results-by-command)
- [Bugs and gaps found by live runs](#bugs-and-gaps-found-by-live-runs)
- [What live runs established about the API](#what-live-runs-established-about-the-api)
- [Not covered by this run](#not-covered-by-this-run)
- [How to re-run](#how-to-re-run)

## Summary

Every engine command ran on 2026-11-22 against a real Atlas project, as the
recommended read-only service account, and returned real recorded data. The test
cluster was paused, so the run used an explicit window ending just before the pause,
which the engine supports for post-mortems. The run found five engine bugs and several
facts the published API spec gets wrong or leaves out, all fixed and covered by offline
regression tests. The only command that still fails is a request at 10-second
resolution for a two-day-old window: Atlas answers it with a server error, and the
engine now explains why.

This repository is public, so no hostnames, project IDs, namespaces or query text are recorded here.

## Environment

| Item | Value |
|---|---|
| Date | 2026-11-22 |
| atlas CLI | 1.59.1 |
| Identity | Project-level service account with Project Read Only + Project Observability Viewer, CLI profile `metrics` |
| Organization policy | API access list enforced (`ORG_REQUIRES_ACCESS_LIST`) |
| Cluster | Replica set, 3 nodes, M10, MongoDB 8.0, with an Atlas Search index. **Paused**; the run used windows ending at 22:55Z, 4 minutes before its last report. |

## Results by command

Output of `tests/live/atlas_metrics_live.sh --end 2026-11-20T22:55:00Z` (hosts masked):

| Command | Exit | Result |
|---|---|---|
| `doctor` | 1 | All checks ok; 23/23 commands present; the cluster flagged `warn` because it is paused (expected) |
| `hosts` | 0 | 3 processes, with the paused warning |
| `snapshot` overview, 3 nodes | 0 | 41 rows; the primary's oplog-lag rejection is reported once |
| `snapshot` × 10 more profiles, primary | 0 | 3–12 rows each, all with real data |
| `history --compare 1d` | 0 | 13 rows with baseline deltas |
| `history` over 7 days | 0 | 13 rows at 1-hour granularity |
| `history --granularity PT10S` | 3 | Atlas HTTP 500 for a two-day-old window; the engine explains 10-second retention (expected) |
| `storage` (6-hour window) | 0 | 24 disk rows across 3 nodes, 3 databases ranked by size with real values |
| `collections` | 0 | 1 ranked namespace, 8 latency rows |
| `collections --profile collection-percentiles` | 0 | 12 percentile rows |
| `query-shapes` | 0 | No shapes in the window; the API call was accepted (version 2025-03-12, millisecond window) |
| `search` (hardware, 3 nodes) | 0 | 21 rows |
| `search --namespace` (per index) | 0 | 8 rows, labelled with the collection's single index ID |
| `advisor` (all four parts) | 0 | 3 real slow queries; suggested, droppable and schema sections empty |
| `incident` (2-hour window) | 0 | 41 measurement rows, 3 project events, no alerts |

Separately, from an unlisted IP, the access-list refusal exited 3 with the caller's
IP and the listing steps.

## Bugs and gaps found by live runs

1. **`doctor` checked the wrong identity.** `atlas auth whoami` ran without the named
   profile. Fixed: it now carries `--profile`.
2. **One rejected measurement failed the whole node.** Atlas refuses some names per node
   (see below). Fixed: the engine drops a rejected name for that node, says so in the
   report, and retries. If every name is rejected, it's still an error.
3. **A paused cluster was unusable even for its own history.** Fixed: a paused cluster
   answers for an explicit past window, with a warning. Questions about "now" are refused
   with its last report time.
4. **A misleading empty-query-shapes note** blamed requirements the cluster met. Fixed.
5. **An all-empty database table reported success.** Over a 15-minute window, every database
   size came back empty, and the table of dashes still exited 0. Fixed: that's now no data
   (exit 4), with a hint to widen the window. Without an explicit window, the databases part
   looks back 6 hours.

## What live runs established about the API

| Finding | Consequence in the engine |
|---|---|
| Oplog lag and the oplog window (`OPLOG_*` except the rate) exist **only on secondaries**, in `SECONDS`. A primary rejects them with `INVALID_METRIC_NAME`. | Per-node rejection handling. The lag threshold (warn 10 s, crit 60 s) is declared in `SECONDS`. |
| These spec-listed names were **rejected on every node**: the 6 transaction counters, `AVG_MAJORITY_WRITE_CONCERN_WRITE_TIME`, `RESTARTS_IN_LAST_HOUR`, `CONNECTION_RATE_LIMITING_REJECTED_CONNECTIONS`, `INGRESS_QUEUE_WAIT_TIME`. | Removed from the built-in profiles, and the `transactions` profile is gone. They're still allowed in custom profiles. |
| Units match the profiles' thresholds: normalized CPU and disk space are `PERCENT`, query targeting is `SCALAR`. Memory comes back in `KILOBYTES` / `MEGABYTES`, which the spec doesn't list. | Formatting added for `KILOBYTES`, `MEGABYTES` and `SECONDS`. |
| Some data points have **no `value` key** at all, rather than `null`. | Counted as gaps (tested). |
| Empty results **keep their fields** (`[]`). | A *missing* field is treated as a changed format (exit 3). |
| Unpinned `atlas api` calls warn about the default version. | Every call pins the version `--help` lists. |
| Events and alerts include `totalCount`. | Paging stops at the total. |
| **Database sizes are sampled only every few hours.** A 15-minute window was all-empty; 6 hours, 1 day and 7 days all had every value. | A 6-hour default for the databases part, and a widen-the-window hint. |
| Per-collection Search metrics list the collection's index IDs, but each **series carries no index name**. | With one index, series are labelled by its ID. With several, the engine requires `--index`. |
| A `PT10S` request for an old window returns **HTTP 500 `UNEXPECTED_ERROR`**, not an empty series. | The error now explains the retention limit. |
| The access list applies to **every** service account, including one with Project Owner. | No self-listing; the docs explain the trade-off. |

## Not covered by this run

- **A cluster under real load.** With little traffic in the window, query shapes were
  empty and the advisor's suggestion sections had nothing to show. The calls and response
  formats are verified; their contents under load are not.
- **A crossed threshold on live data.** Nothing crossed a threshold. The threshold logic
  is covered offline.
- **Sharded clusters** (mongos and config servers): not available in the test project.

## How to re-run

```bash
tests/live/atlas_metrics_live.sh --cluster <name> --atlas-profile metrics \
  [--namespace <db.coll>] [--search-namespace <db.coll>] [--end <ISO time, for a paused cluster>]
```

The summary it prints masks hostnames and IDs, so it can be pasted into this file.
