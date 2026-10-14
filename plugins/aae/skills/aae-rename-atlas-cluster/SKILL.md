---
name: aae-rename-atlas-cluster
description: Give an Atlas Agent Engine workspace's backing Atlas cluster a different name, by migrating it onto a new cluster and repointing Agent Engine — preflight, create, migrate data and Search indexes, re-link, rotate MONGODB_URI, redeploy, verify. Use when the user says "rename the cluster", "rename my Atlas cluster", "change the cluster name", "move my agent to a different cluster", "repoint AAE at another cluster", or asks whether an Atlas cluster can be renamed. Requires the atlas CLI and an Atlas service account with Project Owner. Arguments: --target <new-name> [--agent-dir <dir>] [--auto].
---

# Rename an Atlas cluster behind an Agent Engine workspace

## Why this exists

**Atlas clusters cannot be renamed.** There is no rename in the UI, none in the
Admin API, and none in `atlas clusters update` — that command takes the name as
its path identifier, not as a mutable field. [Modify a Cluster](https://www.mongodb.com/docs/atlas/scale-cluster/)
enumerates every property you may change (tier, type, provider, region, storage,
autoscaling, version, sharding, backup, encryption, tags); the name is not among
them. MongoDB's own answer is to [restore or migrate into a new cluster](https://www.mongodb.com/community/forums/t/rename-project-and-cluster/6675/3).

So a "rename" is a **migration**: create a second cluster under the wanted name,
move the data, repoint Agent Engine, then retire the first.

**The misunderstanding worth heading off:** this is not "update a connection
string". The cluster name is part of the SRV hostname, so it is also the identity
Agent Engine's platform-side Atlas link was established against. Change the secret
alone and the next deploy still syncs egress against the old cluster, while
`app.checkpointer()` — which **returns `None` silently when the URI is bad** —
degrades the agent to stateless with no exception raised anywhere. A migration
that "worked" and quietly lost every conversation thread is the specific failure
this skill exists to prevent.

The project name *is* editable in Atlas. If that is what the user actually wants,
say so and stop — it is one field in project settings and none of this applies.

## What this does and does not touch

| Scope | Behaviour |
|---|---|
| New cluster, data, Search indexes, link, secret, deploy | Automated |
| The old cluster | **Never deleted automatically.** Reported, never destroyed. |
| Atlas DB users, IP access list | Project-scoped — survive untouched, nothing to recreate |
| Backup snapshot history, PIT window | **Lost.** Snapshots do not follow a restore target. |

## Non-negotiable rules

1. **Preflight is read-only and runs first.** `scripts/aae-cluster-rename-preflight.sh`
   creates nothing. A NO-GO stops the run; do not work around a blocker.
2. **One confirmation gate, before Phase 3.** Everything up to and including the
   new cluster's data load is additive and reversible — the live agent keeps
   serving off the old cluster throughout. The cutover is not. Confirm once there,
   naming what changes and what is kept. With `--auto` the gate still applies to
   old-cluster deletion, which is never automatic under any flag.
3. **Never delete the source cluster in this run.** Report it as outstanding, with
   its name and the reminder that it bills until paused or terminated. The user
   deletes it after they have themselves seen a resumed session.
4. **Never print, echo or resolve a secret.** `MONGODB_URI` moves secret-manager →
   stdin → CLI and is never materialised in a shell, a file, or the transcript.
5. **Quiesce before the data cut.** In-flight checkpoint writes during the copy are
   lost. Stop sessions first (`agentengine workspace sessions list` / `stop`).
6. **Fail fast.** Any non-zero exit halts the run. Report which phases completed —
   a half-done migration the user knows about is recoverable.
7. **Read `--help` on the installed binary before prescribing any command.** The
   surface is pinned per CLI version; everything below was verified on **0.1.118**
   and **atlascli 1.59.1**, 2026-10-14.

## Preconditions

- The `atlas` CLI, and an **Atlas service account** with Project Owner on the
  project — `MONGODB_ATLAS_SERVICE_ACCOUNT_CLIENT_ID` / `_SECRET` exported, or a
  service-account `ATLAS_PROFILE`. A *user-account* login is rejected: its refresh
  token expires and the Atlas CLI fails with "session expired" mid-migration,
  which is exactly the long-running unattended case this skill serves.
- `agentengine` authenticated (`agentengine auth login` — a separate identity from
  the Atlas service account; the service account does not cover it).
- Run from the agent directory, the one holding `agent.yaml`.
- Target tier **Flex or M10+**. Setup refuses M0/M2/M5: they pause on inactivity,
  which drops them from egress sync, and they cap Atlas Search indexes.

## Phase 0 — preflight (read-only)

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/aae-cluster-rename-preflight.sh" --target <new-name>
```

It resolves the workspace, project, source cluster and DB user from
`.agentengine/state.json`, verifies the credential is a service account, checks the
source is reachable, unpaused and backed up, confirms the target name is free, and
prints GO / NO-GO. **Read `cluster_name` and `database_user` from that file rather
than reconstructing them** — the user is `agent-engine-` plus the *full* workspace
id, and the id already begins with `ws-`, so the natural-looking template doubles
the prefix and targets a user that does not exist.

Present the inventory as a table before proposing anything.

## Phase 1 — create the target cluster

Mirror the source's provider, region and tier so the migration does not silently
become a resize:

```bash
atlas clusters create <new-name> --projectId <pid> \
  --provider <same> --region <same> --tier <same> [--tag ...]
atlas clusters watch <new-name> --projectId <pid>
```

The name is **positional**, not a flag. Then enable backups on the new cluster so a
baseline starts accruing — the source's snapshot history does not come with the data.

## Phase 2 — move the data (still additive; the agent keeps serving)

Preferred, when the source has Cloud Backup:

```bash
atlas backups snapshots create <source> --projectId <pid> --desc "pre-rename baseline"
atlas backups restores start automated \
  --clusterName <source> --snapshotId <id> \
  --targetClusterName <new-name> --targetProjectId <pid>
```

Note the restore **removes all existing data on the target first** — fine for a
cluster created minutes ago, dangerous if the target was not. Flex clusters support
automated restores only.

Otherwise `mongodump` / `mongorestore` of the checkpoint store (`mdb_store`:
`checkpoints`, `checkpoint_writes`) and the memory database
(`MDB_AGENTIC_STORE_DB` / `MONGOMEM_DB_NAME`). Checkpoints have **no TTL and no
purge command**, so the dump carries every historical checkpoint — offer to prune
before copying rather than after.

**Rebuild the Atlas Search and Vector Search indexes on the target.** A restore
copies documents, not index definitions. Until they exist, the deploy hangs at
`Memory: waiting` — that symptom means this step was skipped.

```bash
atlas clusters search indexes list   --clusterName <source>   --projectId <pid> -o json
atlas clusters search indexes create --clusterName <new-name> --projectId <pid> --file <def>.json
```

## Phase 3 — cutover (**the confirmation gate is here**)

Stop active sessions first, then:

1. **Re-link the platform.** The link written by the original `atlas setup` still
   names the old cluster, in `.agentengine/state.json` and platform-side.

   ```bash
   agentengine atlas cluster list --json          # discover the selection shape
   agentengine atlas cluster save --input -       # feed the target's entry on stdin
   ```

   **The `--input` JSON schema is undocumented** — neither `--help` nor the
   published CLI docs state it. Derive it from the matching entry in
   `cluster list --json` rather than hand-writing it, and record what worked. On
   macOS and Windows `--input -` (stdin) is required; a path is Linux-only and must
   be a temporary, owner-only, untracked file.

   If `cluster save` does not take, fall back to `agentengine atlas setup --force`,
   which resets the local link and reruns setup. Interactive, **without `--yes`**:
   `--yes` authorises billed cluster creation and project-wide IP access changes
   with no prompts. Under `--auto` you may pass `--yes` only after the preflight has
   confirmed the target already exists, so there is nothing left for it to create.

2. **Rotate the secret.** `atlas setup` prints `MONGODB_URI` **once** and offers to
   upload it; accept the upload. If doing it by hand, pipe — never paste:

   ```bash
   <secret-manager read> | agentengine secret set MONGODB_URI --stdin --workspace-scope --sync
   ```

   The positional value and `--value` are deprecated.

3. **Confirm the IP access list** still admits the Atlas-lane egress pair:
   `agentengine atlas setup-ip-access`. There are two egress pairs, one per lane.

4. **`agentengine atlas status`** → expect `egress sync: ok` with the **new** cluster
   listed. "No clusters" means it is still provisioning: **stop, do not deploy.** A
   deploy fired here fails permanently rather than retrying.

## Phase 4 — redeploy

```bash
agentengine deploy --auto
```

A **redeploy is required**; a rebuild is not, since neither scaling nor egress mode
changed. The Orchestration Engine must re-read the URI and the memory service must
build its indexes against the new cluster.

> **Never run `agentengine deploy <unrecognized-subcommand>`** — a CLI
> argument-parsing defect makes it silently run a REAL deploy. Use only
> `deploy list` and `deploy get <id>`.

## Phase 5 — verify, then report

Acceptance is **not** a green deployment. It is:

```bash
agentengine invoke "<prompt>" --session <a-reused-id>
```

- a multi-turn thread on a **reused** `X-Session-ID` resumes with its history —
  this is what proves the checkpointer reconnected rather than silently returned
  `None`;
- a long-term memory fact written before the migration is still retrieved — this is
  what proves the Search indexes rebuilt.

Only once both pass, report: what moved, what was kept and why, that the **old
cluster still exists and still bills**, the lost snapshot history, and the
out-of-band consumers of the old hostname that this run did not touch — the local
gitignored `.env`, CI secrets, Compass or analytics connections, and any second
agent's workspace secret.

## Gotchas

- **`app.checkpointer()` returns `None` on a bad URI instead of raising.** Statelessness
  is the symptom, not an error. Always verify with a reused session id.
- **`Memory: waiting` on deploy = Search/Vector indexes missing** on the new cluster.
- **`auth status` reports a cached workspace name** from `state.json`; the live one
  comes from `workspace list`. Workspace IDs are identity, names drift.
- **Database users and the IP access list are project-scoped**, so they survive the
  move. Do not recreate them, and do not delete the DB user — the project-scoped
  `MONGODB_URI` is shared by every agent in the project.
- **Atlas Agent Engine is in Public Preview**, "for evaluation and prototyping",
  with no SLAs. There is no documented zero-downtime path and no docs page on
  changing the backing cluster at all: Phases 3–5 are composed from verified
  `atlas setup` and cluster-pause recovery behaviour in this plugin's knowledge
  base, not from an official runbook. Log what actually happened.

## Related

- [`aae-kb-read`](../aae-kb-read/SKILL.md) — `RUNBOOKS.md` ("Recover after the Atlas
  cluster pauses"), `CHECKPOINTER.md`, `DRIFT_LOG.md` (what `atlas setup` really does).
- `aae-delete-agent` for removing an agent; `atlas-cli` for control-plane questions;
  `aae-guide` for anything else Agent Engine.
