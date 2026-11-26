# Atlas Metrics Skills — User Guide

- [Summary](#summary)
- [How do I set up the identity the skills run as?](#how-do-i-set-up-the-identity-the-skills-run-as)
- [How do I run my first check?](#how-do-i-run-my-first-check)
- [Which skill answers which question?](#which-skill-answers-which-question)
- [How do I choose the time window?](#how-do-i-choose-the-time-window)
- [How do I choose which nodes to look at?](#how-do-i-choose-which-nodes-to-look-at)
- [What is a profile, and how do I change one?](#what-is-a-profile-and-how-do-i-change-one)
- [How do thresholds work?](#how-do-thresholds-work)
- [How do I read a report?](#how-do-i-read-a-report)
- [Troubleshooting](#troubleshooting)
  - [Why does every command fail with "unauthorized"?](#why-does-every-command-fail-with-unauthorized)
  - [Why does every read fail with "ORG_REQUIRES_ACCESS_LIST" when the login works?](#why-does-every-read-fail-with-org_requires_access_list-when-the-login-works)
  - [Do I have to add every network I work from?](#do-i-have-to-add-every-network-i-work-from)
  - [Can I look at a cluster that is paused now?](#can-i-look-at-a-cluster-that-is-paused-now)
  - [Why does it say no processes belong to my cluster?](#why-does-it-say-no-processes-belong-to-my-cluster)
  - [Why is my collection missing from the collection-latency report?](#why-is-my-collection-missing-from-the-collection-latency-report)
  - [Why are query shapes, the Performance Advisor or Search metrics empty?](#why-are-query-shapes-the-performance-advisor-or-search-metrics-empty)
  - [Why did the run stop with "expects units"?](#why-did-the-run-stop-with-expects-units)
  - [Why does doctor report missing commands after I upgraded the CLI?](#why-does-doctor-report-missing-commands-after-i-upgraded-the-cli)
- [What is deliberately out of scope?](#what-is-deliberately-out-of-scope)
- [How was this verified?](#how-was-this-verified)
- [Reference](#reference)
  - [Commands and their flags](#commands-and-their-flags)
  - [Exit codes](#exit-codes)
  - [Files and environment variables](#files-and-environment-variables)

## Summary

Nine read-only skills that turn the monitoring data Atlas already records about a
cluster into answers: cluster, node, disk, database, collection, query pattern and
Search index, over any time window, against thresholds you can change. They never
connect to your database, never see your documents, and never change anything; when a
fix needs a change (an index, a pin), they tell you what to do.

1. Once per project, create the service account `atlas-metrics-readonly` and save it as
   the CLI profile `metrics` ([setup](#how-do-i-set-up-the-identity-the-skills-run-as)).
2. Run `atlas-metrics.sh profiles init`, set `"atlas_profile": "metrics"` in the config,
   then `atlas-metrics.sh doctor --cluster <name>`.
3. Ask Claude "how is my cluster `<name>` doing?", or run
   `atlas-metrics.sh snapshot --cluster <name>`.

Needs the `atlas` CLI (verified on 1.60.1; another version works if `doctor` finds every
command), `python3` 3.9+, and a dedicated cluster (M10 and up). Free and Flex clusters
expose little or no data. Query shapes need MongoDB 8.0+.

## How do I set up the identity the skills run as?

Create a dedicated, read-only service account in the project you want to monitor, once
per project. A Project Owner can do it; no organization role is needed.

| Step | What |
|---|---|
| 1 | In the project: **Project Identity & Access → Applications → Create Application → Service Account**, named `atlas-metrics-readonly`. Keep the secret in a password manager, never in a chat or repo. |
| 2 | Give it exactly **Project Read Only** (metrics, disks, databases, collections, Search, alerts, events) and **Project Observability Viewer** (query shapes and query values in the Performance Advisor, without access to documents). Never a data-access role or Owner. |
| 3 | If your organization only accepts API calls from listed IPs, add each IP you work from to the account's **API Access List** (see [troubleshooting](#why-does-every-read-fail-with-org_requires_access_list-when-the-login-works)). |
| 4 | In your own terminal: `env -u MONGODB_ATLAS_CLIENT_ID -u MONGODB_ATLAS_CLIENT_SECRET atlas auth login --profile metrics`, choose **ServiceAccount**, paste the ID and secret. To script it, pipe the secret from your vault into `atlas config set client_id <id> -P metrics` and `atlas config set client_secret <secret> -P metrics`; optionally `atlas config set project_id <project-id> -P metrics`. |
| 5 | Set `"atlas_profile": "metrics"` (and `"project_id"` if the profile has none) in `~/.config/atlas-metrics/config.json`, then run `atlas-metrics.sh doctor --cluster <name>`. |

The secret expires on the date you chose: when `doctor` later fails authentication,
rotate it and repeat step 4.

## How do I run my first check?

```bash
AM=plugins/aae/scripts/atlas-metrics.sh        # in a clone; installed, it sits in the plugin's directory

$AM doctor --cluster prod                       # CLI version, auth, every command, the cluster
$AM hosts --cluster prod                        # its nodes and their roles
$AM snapshot --cluster prod                     # how it's doing right now
```

Fix anything `doctor` marks `crit` first; it names the cause of nearly every later
failure. You can ask Claude, which picks the skill and explains the result, or run the
engine yourself in scripts and CI: it exits 1 when a threshold is crossed or a node
stops reporting, so `atlas-metrics.sh snapshot --cluster prod || notify` is a working
health check.

## Which skill answers which question?

| Ask | Skill | Engine command |
|---|---|---|
| "How is my cluster doing?" "Is replication lagging?" | `atlas-metrics-snapshot` | `snapshot` |
| "What did CPU do over the last day?" "Is this worse than last week?" | `atlas-metrics-history` | `history [--compare 7d]` |
| "Am I running out of disk?" "Which database is biggest?" | `atlas-metrics-storage` | `storage` |
| "Which collection is slow?" "What's the p99 on orders?" | `atlas-metrics-collections` | `collections` |
| "Which query is slowest?" "Which app sends this query?" | `atlas-metrics-query-shapes` | `query-shapes` |
| "Is my Search index lagging?" "Search errors?" | `atlas-metrics-search` | `search` |
| "Why are queries slow?" "Which index should I add or drop?" | `atlas-metrics-advisor` | `advisor` |
| "What happened at 14:00?" "Post-mortem for last night" | `atlas-metrics-incident` | `incident` |
| "Change the CPU threshold" "Which metrics can I track?" "It's not working" | `atlas-metrics-profiles` | `profiles`, `doctor` |

A typical drill-down: `snapshot` → `history --compare 7d` (when did it start?) →
`collections` (which collection?) → `query-shapes` (which query?) → `advisor` (which
index?), which you then create yourself.

## How do I choose the time window?

Use `--last 6h` (also `15m`, `7d`, `2w`, or ISO 8601 such as `PT6H`) to count back from
now, or `--start 2026-11-20T14:00:00Z [--end ...]` for an exact UTC range. Not both.
`snapshot` defaults to 15 minutes, most others to 6 hours. `incident` requires `--start`
and pads 15 minutes each side (`--pad-minutes`). `history --compare 7d` adds the same
window a week earlier, with baseline and change columns.

**Granularity**, the time between data points, is picked for you, because Atlas rejects
a mismatch: 1 minute (`PT1M`) for windows up to an hour, 5 minutes (`PT5M`) up to a
day, 1 hour (`PT1H`) up to 7 days, 1 day (`P1D`) beyond. Atlas keeps each only so long:

| Granularity | Kept for |
|---|---|
| 10 seconds | 8 hours, only with premium monitoring (a project with an M40 or larger cluster) |
| 1 minute, 5 minutes | 48 hours |
| 1 hour | 63 days |
| 1 day | Forever |

So a window starting more than 48 hours ago gets hourly points even if it is short, and
one too short for what Atlas still keeps is refused with the width to use. Use
`--granularity PT10S` for finer points over a short, recent window; a granularity Atlas
no longer has is refused with the one to use instead.

## How do I choose which nodes to look at?

| Flag | Selects |
|---|---|
| `--nodes all` (default) | Every process of the cluster |
| `--nodes primary` | The primary of each replica set (or shard) |
| `--nodes secondaries` | Every secondary |
| `--shard atlas-abc123-shard-0` | One replica set or shard; `hosts` shows the names |
| `--host shard-00-02` | Processes whose hostname contains this text |

Flags combine. `search` and `advisor --part slow-queries` default to the primary.

## What is a profile, and how do I change one?

A profile is a named list of measurements, with optional thresholds, that a command
reads. `profiles show <name>` prints one; `profiles measurements --source <source>`
lists every measurement you can add.

| Source | Built-in profiles |
|---|---|
| process | `overview`, `cpu`, `memory-cache`, `operations`, `latency`, `query-efficiency`, `connections`, `replication`, `concurrency`, `network`, `errors` |
| disk | `disk` |
| database | `database-size` |
| collection | `collection-latency`, `collection-percentiles` |
| search-index, search-hardware | `search-index`, `search-hardware` |

Built-ins hold only measurements a live cluster accepted. You can add any other name;
if a node rejects it, the report says so and the run continues. A primary rejects oplog
lag and window, so read the secondaries' rows.

**For one run**, use the repeatable `--add`, `--remove` and `--threshold` flags:

```bash
$AM snapshot --cluster prod --profile cpu \
  --add SYSTEM_NORMALIZED_CPU_IRQ \
  --remove SYSTEM_NORMALIZED_CPU_STEAL \
  --threshold PROCESS_NORMALIZED_CPU_USER:warn=50,crit=80
```

**To save profiles and defaults**, write and edit the config file:

```bash
$AM profiles init        # writes ~/.config/atlas-metrics/config.json (refuses to overwrite)
$AM profiles validate    # run after every edit
```

```json
{
  "defaults": {"cluster": "prod", "atlas_profile": "metrics"},
  "profiles": {
    "my-cpu": {"extends": "cpu", "add": ["SYSTEM_NORMALIZED_CPU_IRQ"],
               "thresholds": {"PROCESS_NORMALIZED_CPU_USER": {"warn": 50, "crit": 80}}},
    "overview": {"thresholds": {"SYSTEM_NORMALIZED_CPU_IOWAIT": {"warn": 20, "crit": 40}}},
    "low-tickets": {"source": "process", "measurements": ["TICKETS_AVAILABLE_READS"],
                    "thresholds": {"TICKETS_AVAILABLE_READS": {"warn": 20, "crit": 5, "direction": "below"}}}
  }
}
```

A profile either extends another (`extends`, then `add` / `remove` / `thresholds`),
tunes a built-in by reusing its name, or is built from scratch with `source` and
`measurements`. Other `defaults` keys: `project_id`, `nodes`, `format`, `last`. A flag
beats the config, which beats the built-in default, with two exceptions: `search` and
slow queries keep reading the primary unless `--nodes` says otherwise, and `last`
replaces every command's default window, including `snapshot`'s 15 minutes. Validation is strict: a typo stops every
command with a message, rather than silently watching nothing.

## How do thresholds work?

| Key | Default | Meaning |
|---|---|---|
| `warn`, `crit` | — | The limits. At least one is required. |
| `direction` | `above` | `above` fires at or over the limit; `below` fires at or under it (free tickets, free disk). |
| `stat` | `max` (`above`) / `min` (`below`) | Which window statistic is compared: `min`, `avg`, `max`, `last` or `p95`. `max` catches any spike; `avg` or `p95` ignores brief ones. |
| `units` | none | The unit Atlas must report (`PERCENT`, `MILLISECONDS`, `BYTES`...). If it differs, the run stops. |

For `above`, warn must be at or below crit; for `below`, the reverse. The built-in
thresholds are starting points; tune them to your workload.

## How do I read a report?

Read the `ATLAS WARNING` lines first: they are Atlas's own messages and usually explain
an empty section. Then `verdict`, the worst threshold result (`ok`, `warn`, `crit`).

| Column | Meaning |
|---|---|
| `last`, `avg`, `max`, `p95`, `min` | Statistics over the window |
| `peak at` | When the maximum happened |
| `gaps` | Intervals with no sample. Never counted as zero, so a silent node doesn't look idle. |
| `status` | `ok`, `warn`, `crit` or `no-data`. `stale (N latest points missing)` means the node stopped reporting. |

`--format table` (default) is for the terminal, `markdown` for tickets and post-mortems,
`json` for scripts: it holds every raw statistic and full log lines.

## Troubleshooting

### Why does every command fail with "unauthorized"?

The identity has no role on the project, or its credentials are missing or expired;
logging in alone grants nothing. Run `atlas auth whoami` to see who the CLI is, then
`doctor`. Two usual causes:

- Exported `MONGODB_ATLAS_CLIENT_ID` / `_SECRET` variables override any saved profile.
  Name a profile (`--atlas-profile` or `defaults.atlas_profile`) and the engine drops
  them; for `atlas auth login`, prefix `env -u` as in [setup](#how-do-i-set-up-the-identity-the-skills-run-as) step 4.
- The service account was created in another organization. It can only get roles in
  its own, so create it in the organization that owns the project.

### Why does every read fail with "ORG_REQUIRES_ACCESS_LIST" when the login works?

Your organization only accepts API calls from listed IPs, and yours isn't listed. The
roles are fine. The engine prints the IP Atlas saw. Add it under **Project Identity &
Access → Applications → `atlas-metrics-readonly` → API Access List**, or as a Project
Owner with your own login (never the read-only profile):

```bash
echo '[{"ipAddress": "203.0.113.7"}]' | atlas api serviceAccounts createAccessList \
  --groupId <project-id> --clientId <service-account-client-id> --version 2024-08-05 -P <your-owner-profile>
```

### Do I have to add every network I work from?

Yes, while the access list is enforced: each network gives your laptop a new IP. A VPN
with a fixed exit IP, or running from a host with a static IP, needs only one entry.

The skills never add the IP themselves. That would need an Owner credential on the same
machine, and if whatever holds the secret can list its own network, a stolen secret
works from anywhere again, which is what the list exists to prevent. If the list is a
burden, raise it with your organization owner.

### Can I look at a cluster that is paused now?

Yes, for the time before the pause. "Now" questions (`--last`) are refused with the
last report time; an explicit window ending before it works:

```bash
$AM hosts --cluster prod                                   # shows when it last reported
$AM history --cluster prod --start 2026-11-20T18:00:00Z --end 2026-11-20T22:55:00Z
```

### Why does it say no processes belong to my cluster?

Either it is a free (M0) or Flex cluster, which has no per-process metrics, or it is in
another project: pass `--project-id` or set `defaults.project_id`. The error lists the
processes it did see.

### Why is my collection missing from the collection-latency report?

Atlas tracks latency only for its busiest collections plus ones you **pin**. Pin it in
the Atlas UI (Metrics → Collection latency) or with `atlas api collectionLevelMetrics
pinNamespaces`, wait for data, and run again. The skills never pin.

### Why are query shapes, the Performance Advisor or Search metrics empty?

Usually an `ATLAS WARNING` line says why. Query shapes need MongoDB 8.0+ on a dedicated
cluster. The Performance Advisor needs a dedicated cluster and queries that were
actually slow in the window. Search metrics need a Search or Vector Search index; with
several on one collection, name one with `--index`. With no warning, widen the window
(`--last 7d`) before concluding all is well.

### Why did the run stop with "expects units"?

A threshold declares `units` and Atlas reports another. Check the unit in the `json`
output, then fix the threshold's `units` and numbers together.

### Why does doctor report missing commands after I upgraded the CLI?

The CLI sometimes renames `atlas api` operations. Update the renamed entry in
`plugins/aae/scripts/atlas_metrics/constants.py` (class `Command`), run
`tests/run-tests.sh atlas_metrics`, then `doctor` again. Affected commands fail loudly
until then.

## What is deliberately out of scope?

| Not included | Why |
|---|---|
| Anything that writes: pinning, creating or dropping indexes, acknowledging alerts, changing the slow-query threshold | Read-only by design. Reports tell you the change to make. |
| Per-shard aggregate measurements | CLI 1.60.1 doesn't expose them. Use `--shard` with per-process metrics. |
| Downloading raw server logs | Not metrics, and large. Use `atlas logs download`. |
| Per-collection size | Atlas has none. Database level is the finest. |
| Alert configuration | A write. Use the Atlas UI or the `atlas-cli` specialist. |

## How was this verified?

An offline suite (`tests/run-tests.sh atlas_metrics`, also on Python 3.9) runs against a
fake `atlas` and proves, among other things, that every command sent is a read.

Every command was last run live on 2026-11-24 with CLI 1.60.1, as the read-only service
account, against two replica sets with Search indexes: a paused M10 over a past window,
and a running M20 under about 15 minutes of real agent load. The reports showed the load
(operation rates up 85–180%, real query shapes and slow queries, index drop candidates,
per-index Search metrics, a crossed threshold). Rerun with
`tests/live/atlas_metrics_live.sh --cluster <name>` (`--end <time>` for a paused
cluster); it masks hostnames and IDs.

Not verified live yet:

- **Suggested indexes and schema advice with content.** The Performance Advisor had
  nothing to suggest; the calls and formats are verified.
- **Search query counts above zero.** Verified at zero only.
- **Sharded clusters** (mongos and config servers).
- **10-second granularity.** Neither cluster has premium monitoring.

## Reference

### Commands and their flags

Every command takes `--cluster`, `--project-id`, `--atlas-profile`, `--format`,
`--config` and `--log-level`. `<cmd> --help` lists everything.

| Command | Window | Nodes | Profile flags | Own flags |
|---|---|---|---|---|
| `hosts` | — | yes | — | — |
| `snapshot` | yes (15m) | yes | yes | — |
| `history` | yes (6h) | yes | yes | `--compare DURATION` |
| `storage` | yes (15m) | yes | `--threshold` | `--part disks\|databases`, `--disk-profile`, `--database-profile`, `--database`, `--top` |
| `collections` | yes (6h) | — | yes | `--namespace`, `--view primary\|secondary\|individual_process`, `--top` |
| `query-shapes` | yes (6h) | — | — | `--namespace`, `--command`, `--sort`, `--top`, `--shape HASH`, `--include-system` |
| `search` | yes (6h) | yes (primary) | yes | `--namespace`, `--index` |
| `advisor` | yes (6h) | yes (primary) | — | `--part suggested-indexes\|drop-indexes\|schema\|slow-queries`, `--namespace`, `--top`, `--lines` |
| `incident` | `--start` required | yes | yes | `--pad-minutes` |
| `profiles` | — | — | — | `list \| show NAME \| measurements --source S \| validate \| init` |
| `doctor` | — | — | — | — |

"Window" means `--last` / `--start` / `--end` / `--granularity`. "Nodes" means
`--nodes` / `--shard` / `--host`. "Profile flags" means `--profile` / `--add` /
`--remove` / `--threshold`.

### Exit codes

| Code | Meaning |
|---|---|
| 0 | Ran; no threshold crossed, and every node reporting |
| 1 | Ran; a threshold was crossed, or a node stopped reporting (named under `not reporting`) |
| 2 | Usage or config error: bad flag, unknown profile, invalid config |
| 3 | The `atlas` CLI failed, timed out or returned non-JSON, or the cluster can't answer (not found, or paused for a "now" question). The message quotes the command and its error. |
| 4 | Atlas answered with no data for the request, including when every series came back empty |
| 5 | Internal error in the engine: a bug to report, never a finding about the cluster |

### Files and environment variables

| Name | Purpose |
|---|---|
| `plugins/aae/scripts/atlas-metrics.sh` | The engine's entry point |
| `plugins/aae/scripts/atlas_metrics/` | The engine (Python standard library only) |
| `plugins/aae/scripts/atlas_metrics/builtin_profiles.json` | Built-in profiles |
| `~/.config/atlas-metrics/config.json` | Your profiles and defaults |
| `ATLAS_METRICS_CONFIG` | Use another config file (or `--config`) |
| `ATLAS_METRICS_ATLAS_BIN` | Use another `atlas` binary |
| `ATLAS_METRICS_LOG_LEVEL` | `debug` / `info` / `warning` (default) / `error`. JSON logs go to stderr; `info` shows every `atlas` command run. |
| `ATLAS_METRICS_NOW` | Tests only: pins "now" to an ISO time. |
