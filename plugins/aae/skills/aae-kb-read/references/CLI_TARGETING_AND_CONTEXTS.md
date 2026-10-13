---
name: aae-cli-targeting-and-contexts
description: How the agentengine CLI resolves its target (contexts, pins, workspaces, explicit flags) and which commands are safe to run while diagnosing. Verified on CLI 0.1.118.
---

# agentengine targeting: contexts, pins, workspaces

- [Summary](#summary)
- [What is the difference between a login, a context, a pin and a workspace?](#what-is-the-difference-between-a-login-a-context-a-pin-and-a-workspace)
- [Is a context per agent or per project?](#is-a-context-per-agent-or-per-project)
- [Why does `--context ctx_…` say "not found"?](#why-does---context-ctx_-say-not-found)
- [How do I target a workspace without an agent directory?](#how-do-i-target-a-workspace-without-an-agent-directory)
- [Can I pin instead of re-running `init`?](#can-i-pin-instead-of-re-running-init)
- [Is running `init` from the monorepo root safe?](#is-running-init-from-the-monorepo-root-safe)
- [Which commands are safe while diagnosing?](#which-commands-are-safe-while-diagnosing)
- [Why does `deploy` do more on my laptop than in CI?](#why-does-deploy-do-more-on-my-laptop-than-in-ci)

## Summary

Verified 2026-10-08 against the docs and CLI **0.1.118**.

- A **context** names a base URL + org + project. It is **per project**, machine-wide, and
  shared by every agent directory. Name it after the project or repo, never after an agent.
- A **pin** binds an agent directory to a context. A **workspace** is the platform-side
  registration of one agent; only `init` creates it.
- `--context` takes the **display name**, not the `ctx_` ID.
- Explicit target flags are **all four or nothing**, and never combined with `--context`.
- **`deploy list`, `deploy get <id>` and `deploy logs <id>` are the read-only `deploy` forms**
  (re-checked 2026-10-13 on 0.1.118). `deploy cancel` is real and mutating, and an *unknown*
  subcommand still falls through to a real deploy.
- `deploy` does more on an interactive terminal than in CI, and decides by whether stdout is a
  TTY, not by a flag.

## What is the difference between a login, a context, a pin and a workspace?

They answer four different questions.

| Thing | Answers | Lives in |
|---|---|---|
| Login (`auth login`) | Who are you? | `~/.agentengine/auth.json` |
| Context | Which org and project do commands target? | `~/.agentengine/contexts.json` (machine-wide, a local label only) |
| Pin | Which context does this agent folder use? | `<agent>/.agentengine/state.json` |
| Workspace | Where does this agent run on the platform? | The platform; its ID is cached in `state.json` |

The misunderstanding to head off: "pinning connects me to the platform". It only chooses a
target locally. The workspace is the platform object, and `atlas setup`, workspace-scoped
secrets and deploys all need it.

Resolution order for the target: `--context` or explicit flags → directory pin (found by
walking up to `agent.yaml`) → hard error. There is no silent default org.

## Is a context per agent or per project?

Per project. `agentengine context --help`: *"A context names one platform target: a base URL,
an organization, and a project... shared across every agent directory on this machine; an
agent directory binds to one with `agentengine context pin`."*

- One context serves every agent in the same project. Workspaces are the per-agent object.
- A common mistake: creating a second context for the same org and project and naming it
  after an agent, which implies contexts belong to agents.
- `init` auto-names a context `<Project-Name>-<project_id>`. There is no `rename`, and
  `context create` cannot rebind an existing name. To get a short name: `context create` a new
  one, `pin` it, delete the old one.
- Pins and registrations are keyed by an internal `ctx_…` ID, so the display name is cosmetic.

## Why does `--context ctx_…` say "not found"?

Because `--context` takes the **display name**. `context "ctx_..." not found` reads like "this
context was deleted" but means "wrong identifier form". Map the `ctx_` ID from
`<agent>/.agentengine/state.json` to its display name in `~/.agentengine/contexts.json`
before concluding anything.

## How do I target a workspace without an agent directory?

Commands such as `deploy list`, `workspace sessions list` and `secret list` resolve the
workspace from the current directory. Without an agent directory, pass **all four**:
`--workspace-id`, `--project-id`, `--org-id` and `--base-url`. Fewer gives
`incomplete explicit target`, and none of them may be combined with `--context`.

This is the only way to operate from a **git worktree**, which has no `.agentengine` pins.

## Can I pin instead of re-running `init`?

No. `pin` binds a directory to a context but does not register a workspace. After a partial
`init` (for example, run from a directory with no `agent.yaml` above it, which creates the
context and then fails), the fix is `agentengine init --context <existing-name>` from the
agent directory. Recommending "just pin it" produces
`Error: no workspace registered under context "…": run agentengine init --context …`.

## Is running `init` from the monorepo root safe?

Yes, for adding a new agent. Docs (`/manage/monorepo.md`, 2026-10-08): init *"registers any
agents that don't already have an `.agentengine/state.json` file. Agents with an existing
state.json retain their current workspace registration."*

- The orphaning risk applies only to an agent that **has** a live workspace on the platform
  but **no** local `state.json`. Check `agentengine workspace list` rather than assuming.
- The `aae-add-agent` skill wraps this safely.

## Which commands are safe while diagnosing?

- **`deploy`**: `agentengine deploy --help` on 0.1.118 lists four subcommands —
  `cancel`, `list`, `get`, `logs` (re-checked 2026-10-13). **`list`, `get <id>` and
  `logs <id>` are read-only;** `logs <id>` prints the deployment's event log, and
  `get <id>` already prints the Conditions block with the failure reason. **`cancel` is
  mutating.** Any form that is *not* one of those four — including a typo'd subcommand such
  as the non-existent `deploy events` — falls through to a real deploy (observed 2026-10-05).
  *This corrects an earlier rule here that named only `list` and `get`.*
- `status` is for health. Its summary line can lag; trust `deploy list` for which deployment
  is live.
- Read-only and useful: `context current`, `atlas status`, `egress`, `secret list`
  (names and versions only), `logs --source agent|tool --since 30m`, `deploy get <id> --json`,
  `build list`, `workspace list`, `dev status`.
- `--help` on any command is non-mutating and has repeatedly been fresher than the docs.

## Why does `deploy` do more on my laptop than in CI?

Because `agentengine deploy` bootstraps missing setup **only on an interactive terminal**, and
there is no flag for it: the CLI decides by whether stdout is a TTY. Verified against
`agentengine deploy --help`, CLI 0.1.118, 2026-10-13.

**Interactively**, a bare `deploy` checks login, workspace binding, a declared egress policy,
local `.env` entries against project and workspace secrets, the last successful build, and
Atlas setup — and then fixes what is missing: it **runs `agentengine init` when no workspace is
bound**, **runs the combined build-and-deploy path when the workspace has no successful
image**, **offers to store each missing `.env` value** with `agentengine secret set`, and
**runs `agentengine atlas setup`** when Atlas is unlinked.

**Non-interactively it does none of that.** `--help`: *"Non-interactive deploy, redirected
stdout, `--json`, and `--all` never prompt, run init, start a build, or provision Atlas. They
print the missing setup and the commands to fix it."* `--no-wait` never starts a build either,
and `--workspace`/`--all` merely print `agentengine build` when no image exists.

Consequences worth stating out loud:

- **A pipe or a redirect is enough to lose it.** `agentengine deploy | tee deploy.log` and
  `agentengine deploy > out.txt` take the non-interactive path; the same command alone in your
  terminal takes the interactive one. A CI runner has no TTY, so every step there is
  non-interactive whether or not you meant it to be.
- **CI must sequence the steps itself:** `agentengine init` → `agentengine build` →
  `agentengine deploy`. Drop the first two and the job fails on setup rather than performing
  it.
- **Atlas setup and secrets are prerequisites in CI**, not something the pipeline can
  provision. `--yes` only accepts billed Flex defaults and Atlas IP access-list changes
  *during* an interactive `atlas setup`; `--help` states it "is not implied by a TTY", and it
  does not make a non-interactive run provision anything.
- This is a common origin of `no workspace registered under context "…"`: the step that would
  have bound the workspace was skipped because the command was not interactive. See
  [TROUBLESHOOTING.md](TROUBLESHOOTING.md#why-does-atlas-setup-say-no-workspace-registered-under-context).
