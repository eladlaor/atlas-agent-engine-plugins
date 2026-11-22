# Plan: read-only Atlas cluster metrics skills

- [Summary](#summary)
- [Decisions](#decisions)
- [What was built](#what-was-built)
- [Ground truth used](#ground-truth-used)
- [Success criteria and status](#success-criteria-and-status)
- [Open items](#open-items)

## Summary

Nine read-only skills that answer monitoring questions about an Atlas cluster, from
whole-cluster health down to a single collection, query pattern or Search index. They
share one engine and adjustable measurement profiles. They come with a dedicated user
guide in `knowledge/atlas_metrics/`, linked from the README. The engine and docs are
built and tested offline. Live verification against a real cluster is the remaining step.

## Decisions

| Question | Decision | Why |
|---|---|---|
| One skill with modes, or several? | **Nine skills** | Distinct trigger phrases are what make the right skill load. The owner asked to maximize finer-scope coverage. |
| Include the Performance Advisor? | **Yes** (`atlas-metrics-advisor`) | Usually the next question after a metric looks bad |
| Where does the logic live? | **One engine**, `plugins/aae/scripts/atlas_metrics/` (Python standard library, runs on 3.9) | The skills stay thin, the behavior is testable, and the plugin's "bash + python3 only" rule holds |
| How is "read-only" enforced? | **An allowlist in code** (`constants.Command`) checked before every call | A rule in prose can't be tested. This one is, twice. |
| How is it adjustable? | **Profiles** (built-in JSON plus a user config) with `extends` / `add` / `remove` / `thresholds`, plus per-run flags | New concerns become config, not code |
| Docs location | `knowledge/atlas_metrics/` (the user guide, plus the live verification record) | Its own place, as requested |

## What was built

| Piece | Path |
|---|---|
| Engine entry point | `plugins/aae/scripts/atlas-metrics.sh` |
| Engine | `plugins/aae/scripts/atlas_metrics/` |
| Skills | `plugins/aae/skills/atlas-metrics-{snapshot,history,storage,collections,query-shapes,search,advisor,incident,profiles}/` |
| Offline tests | `tests/cases/atlas_metrics.sh`, fixtures and fake CLI in `tests/fixtures/atlas_metrics/` |
| Live suite | `tests/live/atlas_metrics_live.sh` |
| User guide | `knowledge/atlas_metrics/ATLAS_METRICS_USER_GUIDE.md` |

## Ground truth used

- `--help` on `atlascli 1.59.1` for every command and flag.
- The Atlas Admin API spec (`mongodb/openapi`, `openapi/v2.json`, fetched 2026-11-22)
  for response shapes and the valid measurement names. The names were generated into
  `measurement_catalog.py`, not typed by hand.
- The CLI exits 0 and prints the parent's help for an unknown operation, so `doctor`
  checks for the operation's own usage line instead.
- Per-shard measurements exist in the API but not in CLI 1.59.1, so they are out of scope.

## Success criteria and status

| Criterion | Status |
|---|---|
| Every command runs only allowlisted reads (proved against a recording fake CLI) | Done |
| Failures exit non-zero and quote the command and the CLI's error. Never an empty report. | Done |
| Thresholds, inheritance, unit checks, window and granularity rules are covered by tests | Done (66 offline tests) |
| Every documented example command parses against the real argument parser | Done |
| No real hostnames or IDs in the added files | Done (tested) |
| Runs on Python 3.9 | Done (tested) |
| Independent code review; every finding fixed or answered | Done: 9 bugs fixed, each with a regression test |
| Setup (service account, roles, CLI profile, access list) works live and is documented for every user | Done |
| Cluster-level commands (collections, query shapes, advisor index and schema parts) verified live | Done: see `knowledge/atlas_metrics/LIVE_VERIFICATION.md` |
| Per-node commands (snapshot, history, storage, Search, slow queries, incident) verified live | Done, against the paused cluster's recorded window: see `LIVE_VERIFICATION.md` |

## Open items

- Re-run the live suite on a cluster under real load, to see query shapes, index
  suggestions and a crossed threshold with live data.
- Sharded clusters (mongos, config servers) are untested live.
