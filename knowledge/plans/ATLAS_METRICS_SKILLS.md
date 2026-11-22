# Plan: a skills catalog for reading Atlas cluster metrics

- [Summary](#summary)
- [Goal and deliverable](#goal-and-deliverable)
- [Ground truth: what the installed CLI offers](#ground-truth-what-the-installed-cli-offers)
- [Proposed skill catalog](#proposed-skill-catalog)
- [Cross-cutting rules every skill follows](#cross-cutting-rules-every-skill-follows)
- [Structure of the catalog document](#structure-of-the-catalog-document)
- [Success criteria (TDD)](#success-criteria-tdd)
- [Work items](#work-items)
- [Open decisions for the owner](#open-decisions-for-the-owner)

## Summary

Write **one doc**, `knowledge/specs/ATLAS_METRICS_SKILLS.md`. It specifies a small set
of read-only skills that use the `atlas` CLI to fetch an Atlas cluster's monitoring
measurements (CPU, memory, connections, operations, disk, per-database size, and slow
queries). This plan covers the doc only. Each skill is built later in its own change,
and the doc is the contract that build is tested against.

The catalog has four skills. A shared first step finds the cluster's hosts, because every
metrics command needs a `host:port`, not a cluster name.

## Goal and deliverable

| Item | Value |
|---|---|
| Deliverable | `knowledge/specs/ATLAS_METRICS_SKILLS.md`, a specification and not a teaching doc, so it is not written as Q&A |
| Audience | Anyone using this plugin. The repo is public, so the doc stays generic: no real hostnames, project IDs or org names |
| Out of scope | Writing the skills, alerting, dashboards, Agent Engine's own run metrics (those belong to `aae-guide`) |
| Relationship to `atlas-cli` | The skills are **narrow procedures**. The `atlas-cli` agent stays the general expert, and each skill hands off to it for anything outside metrics (for example, auth failures) |

## Ground truth: what the installed CLI offers

Checked against `atlascli 1.59.1` `--help` on 2026-11-22:

| Command | Returns | Needs |
|---|---|---|
| `atlas processes list` | The cluster's hosts (`host:port`) and their roles (primary or secondary) | Project Read Only role |
| `atlas metrics processes <host:port>` | Per-host measurements; `--type` filters which ones | `--granularity` (PT10S, PT1M, PT5M, PT1H, P1D) plus either `--period` or `--start`/`--end`, which cannot be combined |
| `atlas metrics disks list / describe` | Disk partitions, then I/O, latency and free-space measurements | host:port + partition name |
| `atlas metrics databases list / describe` | Databases on a host, then per-database measurements | host:port + database name |
| `atlas performanceAdvisor namespaces / slowQueryLogs / suggestedIndexes` | Slow-query namespaces, log lines and index suggestions | host:port (or process ID) |
| `atlas api` (`getHostMeasurements` and siblings) | Fallback for anything the commands above don't expose | `--version` |

`[verify]` during the build: whether free and Flex tiers return measurements at all,
and which `--type` values are valid (the help text points to the Admin API spec rather
than listing them).

## Proposed skill catalog

| # | Skill name | User asks | Core commands | Output |
|---|---|---|---|---|
| 0 | *(shared step, not a skill)* find hosts | n/a | `processes list` filtered to the cluster | List of host:port + role; the primary is marked |
| 1 | `atlas-metrics-snapshot` | "How is my cluster doing right now?" | `metrics processes` on every host, short window | One table per host: CPU, memory, connections, ops/sec, replication lag, query targeting |
| 2 | `atlas-metrics-history` | "What happened between 14:00 and 15:00?" / "last 24h" | `metrics processes` with `--start/--end` or `--period`, granularity picked from the window length | Min / avg / max / last per measurement, peaks flagged with timestamps |
| 3 | `atlas-metrics-storage` | "Am I running out of disk?" / "Which database is biggest?" | `metrics disks` + `metrics databases` | Disk free %, IOPS, latency; databases ranked by size |
| 4 | `atlas-slow-queries` | "Why are queries slow?" | `performanceAdvisor` namespaces → slowQueryLogs → suggestedIndexes | Slowest namespaces, sample queries, suggested indexes (never created automatically) |

A fifth "triage" skill (run 1 → 3 → 4 and summarize) is **deliberately not proposed** yet.
It would only chain the others. Add it after real use shows the chaining is repetitive.

## Cross-cutting rules every skill follows

1. **Read-only, always.** No skill runs a mutating command. `slowOperationThreshold`
   (which changes a setting) and index creation are excluded by name.
2. **Verify against `--help` first.** The doc pins the CLI version it was written for and
   tells the skill to re-check flags on the installed binary, as `atlas-cli` already does.
3. **Fail fast and say why.** Missing auth, wrong project, cluster not found, or a tier
   without metrics each stop with the exact command that failed and its error. Never an
   empty table that looks like "all quiet".
4. **Pick granularity from the window**, using one rule table in the doc (for example, ≤1h → PT1M,
   ≤1 day → PT5M, ≤1 week → PT1H, longer → P1D). This prevents the mismatch Atlas rejects.
5. **Always use `-o json`** and summarize from it. Don't parse the human-readable table output.
6. **Inputs:** `--cluster <name>` (required), `--project-id`/`--profile` (optional; the
   active profile is the default), and window flags where relevant.

## Structure of the catalog document

1. TOC + summary (what the skills are, the read-only promise)
2. Prerequisites: CLI version, auth, required Atlas role
3. The shared host-discovery step
4. One section per skill: purpose, trigger phrases, inputs, exact command sequence,
   output shape, failure cases, acceptance tests
5. Granularity rule table
6. What is deliberately excluded, and why
7. `[verify]` list carried forward to the build

## Success criteria (TDD)

The doc is done when:

- Every command and flag it names exists in `atlas <cmd> --help` on 1.59.1. A checker
  extracts each `atlas ...` line from the doc and runs `--help` on it, reusing the
  `tests/cli-docs-check` approach.
- Every skill section has all seven subsections listed above.
- It contains no real hostname, project ID or org ID. A grep test for `mongodb.net` and
  24-hex IDs is wired into `tests/cases/`.
- Each skill has at least two acceptance tests written as given / when / then, so the later
  build starts from failing tests.

## Work items

1. Write a failing test, `tests/cases/metrics_skills_doc.sh`: the section-completeness and no-real-IDs checks.
2. Write the doc to satisfy it.
3. Run the CLI-flag check against the doc and fix any drift.
4. Add an `[Unreleased] → Added` line to `CHANGELOG.md`.
5. Commit on this worktree's branch and push.

## Open decisions for the owner

1. **Four separate skills, or one `atlas-metrics` skill with modes** (snapshot / history /
   storage / slow-queries)? Recommendation: **four**. Each has distinct trigger phrases,
   which is what makes a skill get picked automatically.
2. **Should slow queries (Performance Advisor) be in scope?** It isn't a "metric" in the
   strict sense, but it is usually the next question. Recommendation: include it.
3. **Location:** `knowledge/specs/` (recommended; it's a contract for a future build) vs. a
   reference file inside the `atlas-cli` skill.
