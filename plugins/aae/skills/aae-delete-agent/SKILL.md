---
name: aae-delete-agent
description: Delete one MongoDB Atlas Agent Engine agent completely and cleanly — workspace, sessions, workspace secrets, Atlas DB user, monorepo entry, and local folder. Use when the user says "delete agent", "remove agent", "tear down agent", "clean up workspace", "start an agent anew", or wants an AAE agent fully removed rather than just undeployed.
---

# AAE Delete Agent

Removes one Atlas Agent Engine agent and everything it left behind.

## Why this exists

**There is no single CLI command for this.** `agentengine workspace delete` removes
only the platform record. Workspace secrets, active sessions, the Atlas database
user, the monorepo manifest entry, the agent folder, and its context all survive —
quietly, and in the case of the Atlas cluster, billably.

The misunderstanding worth heading off: deleting the agent folder is not "undoing"
the agent. It is the one action that makes a clean teardown **harder**, because the
CLI resolves the workspace by walking up from the agent directory to `agent.yaml`.
Delete the folder first and you strand a live remote workspace with no local handle
on it.

## Non-negotiable rules

1. **Phase 0 is read-only.** Build a complete inventory and print it as a table.
   Destroy nothing until the user has confirmed once, against an explicit list of
   what will be destroyed.
2. **Never pass `--yes` before that confirmation.** Interactive deletes prompt for a
   reason; `--yes` exists for after a human has already decided.
3. **Remote first, local last.** Workspace-side teardown completes before anything
   local is touched. This ordering is the whole safety model, not a preference.
4. **Run every `agentengine` command from the agent directory.** The CLI walks up to
   `agent.yaml`. Never run `agentengine init` at the monorepo root.
5. **Fail fast.** Any non-zero exit stops the run. Report which phases completed and
   which did not — a half-finished teardown the user knows about is recoverable; one
   they don't know about is not.
6. **Never print secret values.** `secret list` shows names only, which is fine. Do
   not echo, cat, or resolve a secret's contents at any point.

## Resolving the target

Input is an agent directory, or a name resolvable from the root `agent.yaml`
`agents:` list.

Workspace ID comes from `<agent>/.agentengine/state.json` (schema version 3):

```
.registrations[.pin.context_id].workspace_id
```

`pin.context_id` is a `ctx_…` id; `registrations` is keyed by that id and holds
`workspace_id`, `workspace_name`, and an `atlas` block with `atlas_project_id`,
`cluster_name` and `database_user`. **Prefer the recorded values in this file over
reconstructing any of them from a pattern.**

Cross-check it against `agentengine workspace list` before acting. **Workspace IDs
are identity; names drift**, and `auth status` reports a *cached* workspace name out
of `state.json` rather than the live one. Trust `workspace list`.

If `state.json` is missing, require an explicit `--workspace-id` and **stop** if it
is not supplied. Do not guess from a name.

## Phase 0 — inventory (read-only)

Gather all of this before proposing anything:

| What | Command |
|---|---|
| Auth and active context | `agentengine auth status`, `agentengine context current` |
| The workspace itself | `agentengine workspace get <ws>` |
| Active sessions | `agentengine workspace sessions list` |
| Workspace-scoped secrets | `agentengine secret list --workspace-scope` |
| Project-scoped secrets (names only) | `agentengine secret list` |
| Deployments | `agentengine deploy list` |
| Atlas linkage | `atlas` block in `state.json`: `cluster_name`, `database_user`, `atlas_project_id` |
| Blast radius | Other agents in the root `agent.yaml`; which contexts other agent dirs pin |

Present it as a table, then ask for one confirmation naming exactly what will be
destroyed and what will be kept. That last half matters: a user who thinks the
cluster is going away will not go pause it.

## Phases 1–8

**1. Local runtime.** `agentengine dev stop`.
Offer `agentengine dev clean` **separately and explicitly** — it permanently wipes
local MongoDB volume data, which is a different decision than deleting an agent.

**2. Sessions.** `agentengine workspace sessions stop <id>` for each active session.

**3. Workspace-scoped secrets.** `agentengine secret delete <NAME> --workspace-scope`
for each one, **before** deleting the workspace. Default scope is *project*;
`--workspace-scope` (or `--workspace-id`) is what targets the workspace.

Non-interactive deletion without `--yes` refuses by design — the CLI's own help says
so: *"Without --yes, a non-interactive run refuses instead of deleting."* Do not work
around it. (`context delete` behaves the same way: `--json` requires `--yes`.)

**4. Workspace.** `agentengine workspace delete <ws-id>`. **Irreversible.**

**5. Atlas database user.**

**Read the username from `.atlas.database_user` in `state.json`. Do not construct
it.** The naming is `agent-engine-` + the *full* workspace ID — and the workspace ID
already begins with `ws-`. So for a workspace `ws-<hex>` the user is
`agent-engine-ws-<hex>`, which means the natural-looking template
`agent-engine-ws-<ws-id>` expands to a **doubled `ws-` prefix** and targets a user
that does not exist. Read the recorded value instead; it sits in the same file you
resolved the workspace from.

`agentengine` has no delete for database users — `atlas database-user` is list/save
only. If the Atlas CLI is installed and authenticated:

```bash
atlas dbusers delete <username> --projectId <atlas_project_id>
```

Omit `--force` so the Atlas CLI prompts as well. The default `--authDB admin` is
correct for these SCRAM users.

If the Atlas CLI is **not** installed — which is the common case — print the exact
Atlas UI path and leave the deletion to the user. Do not offer to install the CLI
mid-teardown.

> **CRITICAL GATE.** The project-scoped `MONGODB_URI` secret written by
> `agentengine atlas setup` most likely embeds **this** workspace's database user,
> and that secret is shared by every agent in the project. If any other
> agent or workspace remains, **do not delete the user.** Say plainly that doing so
> would break database access for the surviving agents, and recommend re-running
> `agentengine atlas setup` from a surviving agent first.

**6. Shared resources — never delete automatically.** The Atlas cluster, the project
IP access list, and project secrets (`MONGODB_URI`, `LLM_API_KEY`, `A2A_JWT_SECRET`,
`VOYAGE_API_KEY`) are listed only. Suggest removal **only** when
`agentengine workspace list` shows zero remaining workspaces. Note that the Atlas
cluster **bills independently until paused or terminated** — deleting agents does
not stop the meter.

**7. Local cleanup.** Remove the agent's entry from the root `agent.yaml` `agents:`
list, then remove the agent folder — prefer `git rm -r` and leave committing to the
user.

**`git rm -r` is not the end of it.** It removes only *tracked* files, so everything
git was ignoring stays on disk, and `git status` stays clean while it does. For a
typical agent that leaves at least:

| Leftover | Why it survives |
|---|---|
| `.env` | gitignored — **this is the agent's live credentials** |
| `uv.lock` | untracked whenever the project kept the upstream template's ignore rule |
| `.venv/`, `__pycache__/`, `.pytest_cache/` | gitignored build and tool output |
| `.devcontainer/`, other tool dirs | gitignored per project |
| the agent directory itself | git only removes a directory once it is empty |

So after `git rm -r`, **always** enumerate what remains and show it:

```bash
git clean -nxd <agent-dir>     # -n = dry run. Never run it without -n here.
find <agent-dir> -type f       # the plain view, including ignored files
```

Then stop and let the user decide, one directory at a time. **Do not delete these
automatically, and do not pipe them into `git clean -fxd`.** The `.env` holds working
credentials — often the only copy outside a password manager, and frequently still
valid for a shared gateway or project-scoped resource that outlives this agent. A
teardown that silently destroys them is worse than one that leaves tidy-up to do.

Report the leftovers explicitly in Phase 8 under "manual steps still outstanding",
naming the `.env` paths. Reporting "agent deleted" while its secrets sit on disk
unmentioned is the failure this step exists to prevent.

Delete a context (`agentengine context delete <name>`) **only** if no other agent
directory's `state.json` pins its `ctx_…` id. Pins are keyed by the internal context
id, not the display name; resolve via `~/.agentengine/contexts.json`. The long
auto-generated context name is cosmetic.

**8. Verify and report.** Confirm `agentengine workspace list` no longer shows the
ws-id. Then report four things: what was removed, what was kept and **why**, any
files left on disk from Phase 7 — naming every `.env` among them — and any manual
steps still outstanding. A teardown is not "complete" while the deleted agent's
credentials are still sitting in the working tree.

## Gotchas

- **`agentengine deploy <unrecognized-subcommand>` silently runs a REAL deploy.**
  This is a CLI argument-parsing defect, and it is destructive in exactly the
  situation this skill operates in. Use **only** `deploy list` and `deploy get <id>`.
  Never any other deploy verb.
- **`auth status` shows a cached workspace name** from `state.json`. The live name
  comes from `workspace list`.
- **Workspace IDs are identity; names drift.** Match on the id, always.
- **A clean `git status` does not mean a clean directory.** Ignored files are
  invisible to it, so the agent's `.env`, lockfile and caches can survive a
  `git rm -r` with no sign that anything is left. Check with `git clean -nxd`.

## Handing off

For anything that is not teardown — writing the agent contract, debugging a deploy,
memory identity, guardrails — hand off to **aae-guide**.
