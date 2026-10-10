---
name: aae-monorepo-and-build
description: What agentengine create scaffolds, the two agent.yaml schemas, monorepo conversion and naming, adding an agent, and what the build archive actually uploads. Verified on CLI 0.1.118.
---

# Monorepos, scaffolding and the build archive

- [Summary](#summary)
- [What does `agentengine create` actually lay down?](#what-does-agentengine-create-actually-lay-down)
- [How do I tell a monorepo from a single agent?](#how-do-i-tell-a-monorepo-from-a-single-agent)
- [Is the parent folder the "workspace directory"?](#is-the-parent-folder-the-workspace-directory)
- [How do I convert to a monorepo?](#how-do-i-convert-to-a-monorepo)
- [How are the repo and agent folders named, and can I rename them?](#how-are-the-repo-and-agent-folders-named-and-can-i-rename-them)
- [How do I add an agent to an existing monorepo?](#how-do-i-add-an-agent-to-an-existing-monorepo)
- [What does the build actually upload?](#what-does-the-build-actually-upload)
- [How do I build and deploy several agents at once?](#how-do-i-build-and-deploy-several-agents-at-once)

## Summary

- `agentengine create` lays down a monorepo-*shaped* folder, not a monorepo.
- `agent.yaml` has **two schemas** under one filename: `entrypoint:` means one agent;
  `agents: [{name, path}]` means a monorepo root index. Nothing else tells them apart.
- The build archive root is the **agent dir**, or the **repo root** when the agent is listed
  in the root `agent.yaml`. `.agentengineignore` is read from the archive root only.
- There is no CLI command to add an agent to an existing project; use the `aae-add-agent` skill.

## What does `agentengine create` actually lay down?

Verified 2026-10-05.

```
<repo>/                       <- --dir controls this (default ./<slug>)
├── project-config.yaml       <- project-scoped memory config; not a monorepo artifact
└── agents/<slug>/            <- the agent dir; slug comes from --name
    ├── agent.yaml            <- per-agent format: entrypoint + sandboxes
    └── .agentengine/state.json
```

- With no root `agent.yaml`, this is a **single-agent project whose agent lives one level
  down**. Commands work because you `cd agents/<slug>` first.
- `create` always makes a whole new project (its own `.git` and `project-config.yaml`).
  `create --memory-only` produces a project dir with `project-config.yaml` and no agent.
- `project-config.yaml` is project-scoped (memory, Voyage, extraction config). Its position
  at the root says nothing about whether the repo is a monorepo.

## How do I tell a monorepo from a single agent?

Look for a root `agent.yaml` containing `agents:`. That is the only signal.

- There is no `kind:` tag. Docs: "Do not put `entrypoint` in the root file." A root file with
  `entrypoint` is silently treated as a single agent.
- In a monorepo, each per-agent `pyproject.toml` is **mandatory** and needs `[project].name`
  and a `[build-system]` table.
- Optional monorepo extras: a root `.env` (shared `MONGODB_URI` or provider key), a root
  `pyproject.toml`, and `shared/` (included in all builds).
- `agents/` is convention only. Each `path` must be repo-root-relative, not absolute, and may
  not escape with `../`.

## Is the parent folder the "workspace directory"?

No, it is the other way round. `/build/create-project.md` (2026-10-08): `create` "creates a
**project directory** that contains a `project-config.yaml` file, and scaffolds your agent's
**workspace directory** in a `<project-directory>/agents/<slug>` subdirectory." The folder
holding `agent.yaml`, `.env` and `pyproject.toml` is the workspace directory, and you run
`agentengine` commands from it.

- There is no `agentengine project init` or `agentengine agent init`. Only `create`
  (offline scaffold) and `init` (register).
- Platform identity does not live in the project dir: `state.json` (workspace, org and
  project IDs) is written into the **agent** dir, and contexts live in
  `~/.agentengine/contexts.json`.

## How do I convert to a monorepo?

1. Add a root `agent.yaml` with the `agents:` list.
2. When migrating from a flat single-agent layout, move `agent.yaml`, `pyproject.toml`, `.env`,
   `src/` **and `.agentengine/`** into `agents/<name>/`. Skipping `.agentengine/` orphans the
   existing workspace registration.
3. Move `.agentengineignore` to the repo root (see [the archive root](#what-does-the-build-actually-upload)).
4. Re-run `agentengine init` from the repo root. Agents with an existing `state.json` keep
   their registration (doc claim); each listed agent without one becomes a new workspace.
5. Check `agentengine workspace list` shows exactly the workspaces you expect.

## How are the repo and agent folders named, and can I rename them?

Verified 2026-10-05 with a scratch scaffold (`--name "Acme Assistant" --dir <path>/myrepo` →
`myrepo/agents/acme-assistant/`).

- `--name` sets the display name, slugified into the agent dir, the `agent.yaml` `name:`, and
  the Python module (`agent_acme_assistant`).
- `--dir` sets the repo dir and **defaults to `./<slug>`**, which is why omitting it produces
  the doubled `<slug>/agents/<slug>/`. That doubling is normal, not a bug. Suggest `--dir`.
- Renaming the repo dir is a `mv`, but the agent is bound by a directory pin; after moving,
  re-pin with `agentengine init --context <name>`.
- Renaming the agent dir is expensive: agent name, module, entrypoint and workspace
  registration all follow it.

## How do I add an agent to an existing monorepo?

There is no command for it (CLI 0.1.118: `agentengine agent` has only `validate`,
`bump-version`, `egress`). Use the `aae-add-agent` skill. By hand, the simplest paths are:

- Copy a sibling agent dir **minus `.agentengine/` and `.env`**, rename it, or
- `agentengine create --dir <scratch> --name X --llm … --yes --json </dev/null` (local only),
  read `slug`, `module` and `agent_dir` from the JSON, transplant only `agent_dir` into
  `agents/<slug>`, and append it to the root `agents:` list.

Then register it (root `init` is safe; see
[CLI_TARGETING_AND_CONTEXTS.md](CLI_TARGETING_AND_CONTEXTS.md#is-running-init-from-the-monorepo-root-safe))
and confirm `workspace list` shows exactly one new workspace.

## What does the build actually upload?

Verified 2026-10-08 against `/deploy/agent-image.md` ("Archive Root").

**Rule:** the build packages the **agent directory** by default, but the **monorepo root**
when the agent dir is listed verbatim in the root `agent.yaml` `agents[].path`.

1. A path dependency on a sibling dir such as `shared/<lib>` or `packages/<lib>` **does
   resolve** in builds. It is the documented pattern.
2. A uv workspace is not needed and is worse: it forces one shared `uv.lock` across agents.
3. **`.agentengineignore` is read from the archive root only.** One left inside an agent dir
   after a monorepo conversion is inert; the build silently falls back to CLI defaults and
   uploads everything else in the repo.
4. Always excluded, and `!` negation cannot override it: `.env*`, `*.pem`, `*.key`, `.git`,
   `.aws`, `.ssh`, `.kube`, `.docker/config.json`. Uploaded: `.npmrc`, `pyproject.toml`.
   Keep registry tokens out of those.
5. Local `dev up` does **not** follow this rule: it mounts only the agent dir, so `shared/`
   path deps fail locally (see [DRIFT_LOG.md](DRIFT_LOG.md)).

## How do I build and deploy several agents at once?

From `--help`, 2026-10-08:

- `deploy --auto` is single-agent only.
- `agentengine build --all` builds every listed agent (one archive, N builds).
  `deploy --all` and `deploy --workspace <name>` deploy existing builds; they never build.
- Non-interactive deploys never prompt and never run `init` or `atlas setup`; they print what
  is missing.
- `agent validate` works on per-agent files only; on the root `agent.yaml` it fails with
  "must declare a network egress policy".
