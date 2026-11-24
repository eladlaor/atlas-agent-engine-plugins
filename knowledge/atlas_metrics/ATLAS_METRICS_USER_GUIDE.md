# Atlas Metrics Skills — User Guide

- [Summary](#summary)
- [What do these skills do, and what will they never do?](#what-do-these-skills-do-and-what-will-they-never-do)
- [What do I need before the first run?](#what-do-i-need-before-the-first-run)
  - [Which identity should the skills run as, and with what permissions?](#which-identity-should-the-skills-run-as-and-with-what-permissions)
- [How do I run my first check?](#how-do-i-run-my-first-check)
- [Which skill answers which question?](#which-skill-answers-which-question)
- [Do I ask Claude, or run the engine myself?](#do-i-ask-claude-or-run-the-engine-myself)
- [How do I choose the time window?](#how-do-i-choose-the-time-window)
  - [What is "granularity", and why don't I usually set it?](#what-is-granularity-and-why-dont-i-usually-set-it)
- [How do I choose which nodes to look at?](#how-do-i-choose-which-nodes-to-look-at)
- [What is a profile, and which ones are built in?](#what-is-a-profile-and-which-ones-are-built-in)
- [How do I adjust a profile for one run?](#how-do-i-adjust-a-profile-for-one-run)
- [How do I save my own profiles and defaults?](#how-do-i-save-my-own-profiles-and-defaults)
- [How do thresholds work?](#how-do-thresholds-work)
- [How do I read a report?](#how-do-i-read-a-report)
- [Which output format should I use?](#which-output-format-should-i-use)
- [How do I drill from "the cluster is slow" down to one query?](#how-do-i-drill-from-the-cluster-is-slow-down-to-one-query)
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

Nine skills that read a MongoDB Atlas cluster's monitoring data through the `atlas`
CLI and turn it into answers. They cover the whole cluster, each node, each disk,
each database, each collection, each query pattern and each Search index, over any
time window, against thresholds you can change. **They are read-only**: no skill
creates, drops, pins, pauses or acknowledges anything.

To start:

1. **Create the required service account in the project you want to monitor:**
   `atlas-metrics-readonly`, with the roles **Project Read Only** and **Project
   Observability Viewer**, saved as the `atlas` CLI profile `metrics`. The steps are in
   [Which identity should the skills run as](#which-identity-should-the-skills-run-as-and-with-what-permissions).
   Every user needs this once per project.
2. Run `atlas-metrics.sh profiles init`, set `"atlas_profile": "metrics"` in the config it
   writes, then run `plugins/aae/scripts/atlas-metrics.sh doctor --cluster <name>`.
3. Ask Claude "how is my cluster `<name>` doing?", or run `atlas-metrics.sh snapshot --cluster <name>`.
4. Save your own thresholds and default cluster in the same config file.

## What do these skills do, and what will they never do?

They answer monitoring questions: how the cluster is doing now, how it did over a
window, how that compares with last week, which collection or query is slow, how full
the disks are, whether a Search index is lagging, and what happened around an incident.

Every answer comes from one engine, `plugins/aae/scripts/atlas-metrics.sh`. The skills
are thin instructions that tell the assistant which engine command answers which
question, and how to read the result.

**The engine never changes the cluster.** Every Atlas command it may run is on a fixed
allowlist of reads, and the code refuses anything else before running it. Tests prove
the allowlist holds no write operation and that every command the engine actually
sends is on it. Where a fix needs a write (pinning a collection, creating or dropping
an index), the skill tells you the exact change and leaves it to you.

**The misunderstanding to avoid:** these skills don't query your database. They read
the measurements Atlas already records about your cluster's servers through Atlas's
management API. They never connect to MongoDB itself, so they need no database user
and can't see your documents.

## What do I need before the first run?

| Need | Detail |
|---|---|
| `atlas` CLI | Verified on **1.60.1**. Another version works if `doctor` finds every command. |
| `python3` 3.9+ | The engine uses the standard library only. macOS's built-in `python3` is enough. |
| Authentication | `atlas auth login`, or a service account through `MONGODB_ATLAS_CLIENT_ID` / `MONGODB_ATLAS_CLIENT_SECRET`. A service account doesn't expire mid-session the way a user login can. |
| Atlas role | **Project Read Only** plus **Project Observability Viewer**. Read Only covers the metrics. Observability Viewer adds query shape statistics and un-redacted query values in the Performance Advisor, without the right to read documents that a data-access role would grant. |
| Cluster tier | Most metrics need a dedicated cluster (M10 and up). Free (M0) and Flex clusters expose little or no per-process data, and Atlas says so in the report. Query shapes also need MongoDB 8.0+. |

Pick the project with `--project-id`, with a CLI profile (`--atlas-profile`), or in the
config file. Otherwise the CLI's default profile decides.

### Which identity should the skills run as, and with what permissions?

Use **a dedicated service account that can only read**, stored in its own CLI profile.

**Logging in is not the same as having access.** Atlas checks two separate things:
who you are (authentication), and what that identity may do (roles). Roles are granted
per organization or per project. A service account that logs in fine but holds no role
on your project gets `unauthorized` on every command, and no new login fixes that.

**A service account belongs to exactly one organization.** It can only get roles on
projects inside that organization. One created in organization A can never be added to
a project in organization B, however long you look in B's access screens. Create the
metrics account in the organization that owns the project.

**The CLI prefers exported variables over saved profiles.** When your shell exports
`MONGODB_ATLAS_CLIENT_ID` / `MONGODB_ATLAS_CLIENT_SECRET` (common when other tools
need Atlas access), the CLI authenticates as that identity whatever profile is saved,
and even `atlas auth login` reports "already authenticated" as it. The engine guards
against this: **when you name a profile (`--atlas-profile` or `defaults.atlas_profile`),
it removes the `MONGODB_ATLAS_*` credential variables before calling the CLI**, so the
profile you chose is the one that answers. With no profile named, the CLI's normal
order applies.

The recommended setup, done once:

| Step | Who | What |
|---|---|---|
| 1 | You, as **Project Owner** (no organization role needed) | Inside the project: **Project Identity & Access → Applications → Create Application → Service Account**, named e.g. `atlas-metrics-readonly`. This creates a *project-level* service account, which Atlas adds to the organization as a member with no organization permissions. An organization owner can instead create one under **Organization → Identity & Access → Applications** and add it to several projects. Keep the secret out of chats and repos. |
| 2 | You | Give it **Project Read Only** and **Project Observability Viewer**. Together they cover every skill, including query shapes and the query values in slow-query logs and index suggestions. Don't use a data-access role, which would also let the account read documents, and never Owner. |
| 3 | You, if your organization requires it | **API access list.** If the organization only accepts API calls from listed IPs, the account logs in but every read fails with `403 ORG_REQUIRES_ACCESS_LIST`. Add each IP you work from under the service account's **API Access List**. See [Do I have to add every network I work from?](#do-i-have-to-add-every-network-i-work-from) |
| 4 | You, in your own terminal | `env -u MONGODB_ATLAS_CLIENT_ID -u MONGODB_ATLAS_CLIENT_SECRET atlas auth login --profile metrics`, choose **ServiceAccount**, and paste the ID and secret at the prompt. **Scripted alternative** (for example from a password manager): `atlas config set client_id <id> -P metrics` and `atlas config set client_secret <secret> -P metrics`, with the secret piped from the vault, never typed into a chat. Add `atlas config set project_id <project-id> -P metrics` to give the profile a default project. |
| 5 | You | Set `"atlas_profile": "metrics"` in `~/.config/atlas-metrics/config.json` (and `"project_id"` if the profile has none), then run `atlas-metrics.sh doctor --cluster <name>`. |

Service-account secrets have an expiry date that you choose when you create them. When
`doctor` starts failing authentication months later, rotate the secret and repeat step 4.

## How do I run my first check?

```bash
AM=plugins/aae/scripts/atlas-metrics.sh        # in a clone; installed, it sits in the plugin's directory

$AM doctor --cluster prod                       # CLI version, auth, all 23 commands, the cluster
$AM hosts --cluster prod                        # its nodes and their roles
$AM snapshot --cluster prod                     # how it's doing right now
```

`doctor` prints one row per check. Fix anything marked `crit` before going further:
nearly every later failure traces back to auth, a missing command, or a wrong cluster
name, and `doctor` names each one.

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

## Do I ask Claude, or run the engine myself?

Either. **Asking** ("which collection on prod got slower since yesterday?") lets the
assistant pick the skill, the flags and the follow-up, then explain the result.
**Running the engine** gives you the same report directly, which suits scripts, cron
jobs and CI: the exit code is 1 when a threshold is crossed, so
`atlas-metrics.sh snapshot --cluster prod || notify` is a working health check.

In Claude Code and Codex the skills load from the plugin. The engine works the same
from any shell.

## How do I choose the time window?

Use one of two shapes, never both:

- `--last 6h` counts back from now. It takes `15m`, `90m`, `6h`, `7d` or `2w`, or ISO
  8601 such as `PT6H` and `P7D`.
- `--start 2026-11-20T14:00:00Z [--end ...]` gives an exact range in UTC. `--end`
  defaults to now.

Defaults: `snapshot` uses the last 15 minutes; `history`, `collections`,
`query-shapes`, `search` and `advisor` use the last 6 hours. `incident` requires
`--start` and pads the window by 15 minutes on each side (`--pad-minutes`).

`history --compare 7d` fetches the same-length window seven days earlier and adds
`baseline avg`, `Δ avg %`, `baseline max` and `Δ max %` columns.

### What is "granularity", and why don't I usually set it?

Granularity is the time between two data points: 10 seconds, 1 minute, 5 minutes,
1 hour or 1 day. Atlas rejects a request whose granularity doesn't suit its window,
so the engine picks it from the window length, then from the window's age:

| Window up to | Granularity |
|---|---|
| 1 hour | 1 minute (`PT1M`) |
| 1 day | 5 minutes (`PT5M`) |
| 7 days | 1 hour (`PT1H`) |
| longer | 1 day (`P1D`) |

Atlas keeps each granularity only for a while, then compacts it into the next
coarser one:

| Granularity | Kept for |
|---|---|
| 10 seconds | 8 hours, and only with premium monitoring (a project with an M40 or larger cluster) |
| 1 minute, 5 minutes | 48 hours |
| 1 hour | 63 days |
| 1 day | Forever |

So a window that starts more than 48 hours ago gets hourly points, even when it is
short. A window shorter than the only granularity Atlas still has for it (say, 15
minutes from last week) is refused with the width to widen it to. `--compare`
moves both windows to whatever the older one needs, so they stay comparable.

Override it with `--granularity PT10S` when you need finer points over a short,
recent window. A granularity you name that Atlas no longer has for the window is
refused before any call, with the one to use instead.

## How do I choose which nodes to look at?

| Flag | Selects |
|---|---|
| `--nodes all` (default) | Every process of the cluster |
| `--nodes primary` | The primary of each replica set (or shard) |
| `--nodes secondaries` | Every secondary |
| `--shard atlas-abc123-shard-0` | One replica set or shard; `hosts` shows the names |
| `--host shard-00-02` | Processes whose hostname contains this text |

The flags combine: `--shard ... --nodes secondaries` gives that shard's secondaries.
`search` and `advisor --part slow-queries` default to the primary, to keep the
output short.

## What is a profile, and which ones are built in?

A **profile** is a named list of measurements plus optional thresholds, for one
**source** (one kind of Atlas endpoint). Every metrics command reads one profile.
`profiles show <name>` prints it, and `profiles measurements --source <source>` lists
every name you can add.

| Profile | Source | Shows |
|---|---|---|
| `overview` | process | CPU, memory, cache, connections, operation rates, replication lag, query targeting |
| `cpu` | process | Process and host CPU: user, kernel, I/O wait, steal |
| `memory-cache` | process | Cache fill and dirtiness, cache traffic, resident memory, swap, page faults |
| `operations` | process | Operation and document rates by type, in-memory sorts |
| `latency` | process | Average read / write / command execution time |
| `query-efficiency` | process | Documents and keys scanned per returned, in-memory sorts, sort spills |
| `connections` | process | Connections, cursors, request rate |
| `replication` | process | Replication lag and oplog window (secondaries only), oplog growth, replicated operation rates |
| `concurrency` | process | Read/write tickets, lock queues, throttled operations |
| `network` | process | Bytes in and out, requests |
| `errors` | process | Assertions, killed queries |
| `disk` | disk | Space used and free, IOPS, read/write latency, throughput, queue depth |
| `database-size` | database | Data, storage and index size; document, collection and index counts |
| `collection-latency` | collection | Read / write / command rates, average and p99 latency |
| `collection-percentiles` | collection | p50 / p95 / p99 for every operation type |
| `search-index` | search-index | Query counts and errors, write rates, size on disk, index lag |
| `search-hardware` | search-hardware | Search process CPU, memory, JVM heap, disk use, page faults |

The process source alone has over 170 measurements. The profiles are starting
points, not the limit.

**The built-in profiles contain only measurements a live cluster accepted.** The
published API spec lists some names that real clusters reject (`INVALID_METRIC_NAME`):
on a MongoDB 8.0 replica set, the transaction counters, majority write-concern time,
restarts, connection rate-limiting and ingress queue wait were all refused, so they
aren't in the built-ins. You can still add any spec name to your own profile. If a node
rejects it, the report says so for that node, and the rest of the run continues.
**Oplog lag and the oplog window are reported by secondaries only.** A primary rejects
them, which the report notes, so look at the secondaries' rows.

## How do I adjust a profile for one run?

Three repeatable flags change a profile for a single run without editing anything:

```bash
$AM snapshot --cluster prod --profile cpu \
  --add SYSTEM_NORMALIZED_CPU_IRQ \
  --remove SYSTEM_NORMALIZED_CPU_STEAL \
  --threshold PROCESS_NORMALIZED_CPU_USER:warn=50,crit=80
```

`--threshold METRIC:key=value,...` takes the same keys as the config file: `warn`,
`crit`, `direction`, `stat` and `units`.

## How do I save my own profiles and defaults?

```bash
$AM profiles init        # writes ~/.config/atlas-metrics/config.json (refuses to overwrite)
$AM profiles validate    # run after every edit
```

The file is JSON with two optional keys:

```json
{
  "defaults": {
    "cluster": "prod",
    "project_id": "<24-hex project id>",
    "atlas_profile": "work",
    "nodes": "all",
    "format": "table",
    "last": "6h"
  },
  "profiles": {
    "my-cpu": {
      "extends": "cpu",
      "add": ["SYSTEM_NORMALIZED_CPU_IRQ"],
      "remove": ["SYSTEM_NORMALIZED_CPU_STEAL"],
      "thresholds": {"PROCESS_NORMALIZED_CPU_USER": {"warn": 50, "crit": 80}}
    },
    "overview": {
      "thresholds": {"SYSTEM_NORMALIZED_CPU_IOWAIT": {"warn": 20, "crit": 40}}
    },
    "low-tickets": {
      "source": "process",
      "description": "Concurrency starvation",
      "measurements": ["TICKETS_AVAILABLE_READS", "TICKETS_AVAILABLE_WRITE"],
      "thresholds": {
        "TICKETS_AVAILABLE_READS": {"warn": 20, "crit": 5, "direction": "below", "stat": "min"}
      }
    }
  }
}
```

There are three ways to define a profile:

1. **Extend** another profile (`extends`), then `add`, `remove` and override
   `thresholds`. The child inherits the parent's thresholds.
2. **Tune a built-in in place** by using its name with only `thresholds` (or
   `add`/`remove`). `overview` above keeps its measurements and changes one threshold.
3. **Build from scratch** with `source` and `measurements`.

The config sits in `~/.config/atlas-metrics/config.json`. `ATLAS_METRICS_CONFIG` or
`--config` points elsewhere, which is handy for one config per environment. A
command-line flag always beats a config default, which always beats the built-in default.

**Validation is strict on purpose.** An unknown key, a misspelled measurement, an
unknown source, or warn/crit in the wrong order stops every command with a message
naming the problem. A config that silently ignored a typo would quietly stop
watching the thing you meant to watch.

## How do thresholds work?

| Key | Default | Meaning |
|---|---|---|
| `warn`, `crit` | — | The limits. At least one is required. |
| `direction` | `above` | `above` fires when the value reaches the limit or exceeds it; `below` fires when it falls to the limit or under it (free tickets, free disk). |
| `stat` | `max` (`above`) / `min` (`below`) | Which statistic of the window is compared: `min`, `avg`, `max`, `last` or `p95`. `max` catches any spike; `avg` or `p95` ignores brief ones. |
| `units` | none | The unit Atlas must report, such as `PERCENT`, `MILLISECONDS` or `BYTES`. If it differs, the run stops instead of comparing mismatched numbers. |

For `above`, warn must be at or below crit. For `below`, warn must be at or above
crit. The built-in thresholds are conservative starting points. Tune them to what is
normal for your workload.

## How do I read a report?

Every report has the same parts:

- **The header** gives the cluster, profile, window and granularity.
- **`verdict`** is the worst threshold result in the report: `ok`, `warn` or `crit`.
  It appears only when the report evaluated thresholds.
- **`ATLAS WARNING` lines** are Atlas's own messages, usually that the cluster tier
  is too small for that data. They explain empty sections, so read them first.
- **Sections** are tables. For series these columns appear:

| Column | Meaning |
|---|---|
| `last`, `avg`, `max`, `p95`, `min` | Statistics over the window, in readable units |
| `peak at` | When the maximum happened |
| `gaps` | Intervals with no sample. **Gaps are never counted as zero**: a node that stops reporting must not look idle. |
| `status` | `ok`, `warn`, `crit`, or `no-data`. A `stale (N latest points missing)` suffix means the node stopped reporting partway through the window. |

## Which output format should I use?

| `--format` | Use it for |
|---|---|
| `table` (default) | Reading in a terminal |
| `markdown` | Pasting into a ticket, a post-mortem or a chat |
| `json` | Scripts, and the assistant when it reasons over numbers. It holds every raw statistic, the thresholds, and full log lines (for example the slow-query `line` field). |

## How do I drill from "the cluster is slow" down to one query?

A typical path, which the skills suggest at each step:

1. `snapshot`: the primary's CPU is `crit`, and query targeting is high.
2. `history --last 24h --compare 7d`: it started at 09:40 and is 3× last week.
3. `collections --start <09:30>`: `app.orders` leads total execution time, with p99 up.
4. `query-shapes --namespace app.orders --sort docs-ratio`: one `find` examines 2,000
   documents per document returned.
5. `advisor --namespace app.orders`: a suggested index on `{status: 1, created: -1}`.
   You create it. The skill doesn't.

## Troubleshooting

### Why does every command fail with "unauthorized"?

Either the identity is logged in but holds no role on the project, or the credentials
are missing or expired. Run `atlas auth whoami` to see *who* the CLI is, then `$AM doctor`.
Two traps cause most cases. Exported `MONGODB_ATLAS_CLIENT_ID`/`_SECRET` variables
override the saved login; naming a profile with `--atlas-profile` makes the engine
ignore them. And a service account from a different organization can never reach the
project. See [Which identity should the skills run as](#which-identity-should-the-skills-run-as-and-with-what-permissions).
The `atlas-cli` specialist covers auth in depth.

### Why does every read fail with "ORG_REQUIRES_ACCESS_LIST" when the login works?

Your organization only accepts Admin API calls from IP addresses on the service
account's access list, and the address you're calling from isn't on it. Logging in
still succeeds (`atlas auth whoami` reports the account), so this looks like a
permissions problem, but it isn't. The roles are fine.

The engine prints the IP Atlas saw, taken from the error itself. Add that address in the
project: **Project Identity & Access → Applications → `atlas-metrics-readonly` → API
Access List → Add Access List Entry**. Or, as a Project Owner with your own login (never
the read-only profile):

```bash
echo '[{"ipAddress": "203.0.113.7"}]' | atlas api serviceAccounts createAccessList \
  --groupId <project-id> --clientId <service-account-client-id> --version 2024-08-05 -P <your-owner-profile>
```

### Do I have to add every network I work from?

Yes, while the organization enforces an access list. A laptop takes a new public IP on
each network (office, home, hotspot, VPN), and each new one needs an entry before the
account works from it. To make that rare:

| Option | Entries | When it fits |
|---|---|---|
| A VPN with a fixed exit IP (a corporate VPN's egress range, or a dedicated-IP VPN) | One address or range | You move between networks often |
| List the networks you really use | One per network | Home and office, where addresses change rarely |
| Run the skills from a fixed host (a small VM or CI runner with a static IP) | One | Scheduled health checks |

**Why don't the skills add the current IP automatically?** It would take a Project
Owner credential stored on the same machine, so that a refused call could list itself.
That defeats the control. An access list exists so that a stolen secret is useless from
an unknown network, and if whatever holds the secret can also list its own network,
holding the secret is enough again. It would also put an Owner credential next to a
read-only one. So the skills stop at telling you the IP and the exact command, and
adding it stays a deliberate step by an owner. If the requirement itself is a burden,
take it to your organization owner rather than working around it.

### Can I look at a cluster that is paused now?

Yes, for the time before it was paused. A paused cluster reports nothing new, but
Atlas keeps what it recorded. Questions about "now" (`--last`) are refused with the
cluster's last report time. An explicit window (`--start … --end …`) ending before
that time works, and the report carries a warning that the cluster is paused:

```bash
$AM hosts --cluster prod                                   # shows when it last reported
$AM history --cluster prod --start 2026-11-20T18:00:00Z --end 2026-11-20T22:55:00Z
```

### Why does it say no processes belong to my cluster?

The engine maps a cluster to its processes by the hostnames in the cluster's
connection string, plus hostnames that start with `<cluster-name>-`. If neither
matches, the error lists the processes it did see. There are two common causes:

- **A free (M0) or Flex cluster.** These have no per-process metrics to read.
- **Wrong project.** The cluster exists, but in another project. Pass
  `--project-id` or set `defaults.project_id`.

### Why is my collection missing from the collection-latency report?

Atlas collects per-collection latency only for the namespaces it ranks busiest, plus
any namespace someone **pinned**. Pinning changes a cluster setting, so the skills
never do it. Pin the collection in the Atlas UI (Metrics → Collection latency) or
with `atlas api collectionLevelMetrics pinNamespaces`, wait for data to accumulate,
and run again.

### Why are query shapes, the Performance Advisor or Search metrics empty?

Each has a precondition, and Atlas usually names the missing one in an `ATLAS WARNING` line:

- **Query shapes** need MongoDB 8.0+ on a dedicated cluster.
- **The Performance Advisor** needs a dedicated cluster, and slow-query data needs
  queries that were actually slow during the window.
- **Search metrics** exist only where an Atlas Search or Vector Search index is defined.
  For a collection with several Search indexes, name one with `--index`: Atlas's
  per-collection response doesn't say which series belongs to which index.

An empty section with no warning means Atlas had nothing for that window. Widen it
with `--last 7d` before concluding there is no problem.

### Why did the run stop with "expects units"?

A threshold declares `units`, and Atlas reported the measurement in a different unit.
The engine stops rather than comparing, say, a millisecond threshold against seconds.
Check the unit Atlas reports in the `json` output, then fix the threshold's `units`
and its numbers together.

### Why does doctor report missing commands after I upgraded the CLI?

The CLI renames some `atlas api` operations between releases. The engine names every
operation in one place, `plugins/aae/scripts/atlas_metrics/constants.py` (class
`Command`). Update the renamed entry there, run the test suite
(`tests/run-tests.sh atlas_metrics`), and run `doctor` again. Until then, the
commands that use the renamed operation fail with the CLI's own error. None of them
silently returns nothing.

## What is deliberately out of scope?

| Not included | Why |
|---|---|
| Anything that writes: pinning, creating or dropping indexes, acknowledging alerts, changing the slow-query threshold | These skills are read-only by design. Each report tells you the change to make yourself. |
| Per-shard aggregate measurements | The Admin API has them, but CLI 1.60.1 doesn't expose the operation. Use `--shard` with per-process metrics instead. |
| Downloading raw server logs | Logs aren't metrics, and they can be large. Use `atlas logs download`. |
| Per-collection size | Atlas exposes no per-collection size measurement. Database level is the finest available. |
| Alert configuration | Configuring alerts is a write. Use the Atlas UI or the `atlas-cli` specialist. |

## How was this verified?

The engine has an offline test suite (`tests/run-tests.sh atlas_metrics`). It runs
against a fake `atlas` that records every command it receives. It proves the
read-only allowlist, fail-fast errors, thresholds, profile inheritance, window and
granularity rules, and the parsing of each response shape. It also runs on Python 3.9.

Every command was last run live on 2026-11-24 with CLI 1.60.1, as the read-only
service account, against two replica sets with Atlas Search indexes: a paused M10 over a
past window, and a running M20 under real load from an Atlas Agent Engine agent fleet
(about 15 minutes of agent sessions). Under that load the reports showed what the agents
did: query, insert and update rates up 85–180% against the hour before, the platform's
own collections as the busiest namespaces, real query shapes and slow queries, index
drop candidates, per-index Search metrics by index name, and a crossed threshold (query
targeting on the secondaries). Rerun the live suite with
`tests/live/atlas_metrics_live.sh --cluster <name>` (add `--end <time>` for a paused
cluster). It prints a summary with hostnames and IDs masked.

Not verified live yet:

- **Suggested indexes and schema advice with content.** The Performance Advisor had
  nothing to suggest for that load. The calls and response formats are verified.
- **Search query counts above zero.** The load's Search queries didn't run, so the
  per-index query series were verified at zero only.
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
| 0 | Ran; no threshold crossed |
| 1 | Ran; at least one threshold crossed |
| 2 | Usage or config error: bad flag, unknown profile, invalid config |
| 3 | The `atlas` CLI failed, timed out or returned non-JSON, or the cluster can't answer (not found, or paused for a "now" question). The message quotes the command and its error. |
| 4 | Atlas answered with no data for the request, including when every series came back empty |
| 5 | Internal error in the engine. This is a bug to report, never a finding about the cluster. |

### Files and environment variables

| Name | Purpose |
|---|---|
| `plugins/aae/scripts/atlas-metrics.sh` | The engine's entry point |
| `plugins/aae/scripts/atlas_metrics/` | The engine (Python standard library only) |
| `plugins/aae/scripts/atlas_metrics/builtin_profiles.json` | Built-in profiles |
| `~/.config/atlas-metrics/config.json` | Your profiles and defaults |
| `ATLAS_METRICS_CONFIG` | Use another config file |
| `ATLAS_METRICS_ATLAS_BIN` | Use another `atlas` binary |
| `ATLAS_METRICS_LOG_LEVEL` | `debug` / `info` / `warning` (default) / `error`. JSON logs go to stderr; `info` shows every `atlas` command run. |
| `ATLAS_METRICS_NOW` | Tests only: pins "now" to an ISO time, so fixed-date fixtures don't age past the retention rules. |
