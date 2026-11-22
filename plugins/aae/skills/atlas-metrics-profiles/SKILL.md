---
name: atlas-metrics-profiles
description: "Configure the atlas-metrics skills: list and show the built-in measurement profiles, list every valid measurement name per source (process, disk, database, collection, Search), create or edit the user's own profiles and thresholds in ~/.config/atlas-metrics/config.json, set defaults (cluster, project, nodes, window, output format), validate the config, and run the doctor check of CLI version, auth and command availability. Use when the user says \"make a metrics profile\", \"change the CPU threshold\", \"alert me at 60% instead\", \"which metrics can I track\", \"set my default cluster\", \"atlas-metrics doctor\", \"metrics skills not working\"."
---

# Atlas metrics: profiles, config and doctor

Every `atlas-metrics-*` skill reads its measurements and thresholds from a
**profile**. The built-ins cover common concerns. The user's own config file adds
profiles, adjusts built-ins, and sets defaults.

## Run it

The engine is `../../scripts/atlas-metrics.sh`, resolved relative to the directory
of this `SKILL.md`. Call it `$AM` below.

```bash
$AM profiles list                                   # built-in and user profiles
$AM profiles show overview                          # measurements + thresholds
$AM profiles measurements --source process          # every valid name for that source
$AM profiles init                                   # write an example config (refuses to overwrite)
$AM profiles validate                               # check the config before relying on it
$AM doctor --cluster <name>                         # CLI version, auth, commands, cluster
```

## Editing the config

The config lives at `~/.config/atlas-metrics/config.json`. `ATLAS_METRICS_CONFIG` or
`--config` points elsewhere. It is JSON with two keys:

```json
{
  "defaults": {"cluster": "prod", "nodes": "all", "format": "table", "last": "6h"},
  "profiles": {
    "my-cpu": {"extends": "cpu", "add": ["SYSTEM_NORMALIZED_CPU_IRQ"],
               "thresholds": {"PROCESS_NORMALIZED_CPU_USER": {"warn": 50, "crit": 80}}},
    "overview": {"thresholds": {"SYSTEM_NORMALIZED_CPU_IOWAIT": {"warn": 20, "crit": 40}}},
    "cache-pressure": {"source": "process",
                       "measurements": ["CACHE_FILL_RATIO", "DIRTY_FILL_RATIO", "EXTRA_INFO_PAGE_FAULTS"]}
  }
}
```

- **There are three ways to define a profile.** `extends` + `add`/`remove`/`thresholds`
  adjusts another profile. Using a built-in's own name with only `thresholds` tunes the
  built-in. `source` + `measurements` builds one from scratch.
- **A threshold** takes `warn`/`crit` plus optional `direction` (`above` by default, or
  `below` for "too low", like free tickets), `stat` (`max` by default, or `min`, `avg`,
  `last`, `p95`) and `units`. When `units` is set and Atlas returns a different unit,
  the run stops rather than comparing the wrong numbers.
- **Defaults** may hold `project_id`, `atlas_profile` (the `atlas` CLI profile),
  `cluster`, `nodes`, `format` and `last`. A command-line flag always wins.
- **Read the file before editing it, and edit it in place.** Never overwrite the
  user's file wholesale. Run `profiles validate` after every change. Measurement
  names come from `profiles measurements --source <source>`; a typo fails the
  validation with the bad name.

## First-time setup: the service account every user needs

The skills are meant to run as a dedicated, read-only service account. Walk the user
through this once per Atlas project. A Project Owner can do it, and no organization
role is needed.

1. In the project: **Project Identity & Access → Applications → Service Accounts →
   Create service account**, named `atlas-metrics-readonly`, with exactly two roles:
   **Project Read Only** and **Project Observability Viewer**. Never a data-access role
   (it can read documents), never Owner. The user stores the secret in a password
   manager. Never ask them to paste it into the chat.
2. **If the organization enforces an API access list** (reads fail with
   `403 ORG_REQUIRES_ACCESS_LIST` while `atlas auth whoami` works), the user adds their
   current IP to the account's **API Access List**. The engine's error names the IP.
   Never add it for them: listing an IP is a write that needs an Owner, and making it
   automatic would defeat the control.
3. In the user's own terminal:
   `env -u MONGODB_ATLAS_CLIENT_ID -u MONGODB_ATLAS_CLIENT_SECRET atlas auth login --profile metrics`
   (choose ServiceAccount). The `env -u` stops exported credentials from taking over.
4. Set `"atlas_profile": "metrics"` in the config (`$AM profiles init` writes one), then
   run `$AM doctor --cluster <name>`.

## When something fails

`$AM doctor` checks, in order:
- that the installed CLI is the version these skills were verified on (a different
  version is a warning);
- that `atlas auth whoami` succeeds;
- that every command the engine uses exists on this CLI;
- when you pass `--cluster`, that the cluster resolves to its processes.

Auth problems belong to the `atlas-cli` specialist.
