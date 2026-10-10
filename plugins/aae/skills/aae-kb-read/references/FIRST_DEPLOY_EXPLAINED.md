---
name: aae-first-deploy-explained
description: Q&A teaching write-up of how the pieces of a first Atlas Agent Engine deploy fit together - login, context, pin, workspace, atlas setup, egress IPs and secrets. Based on a first deploy on CLI 0.1.118, 2026-10-04.
---

# First deploy, explained

- [Summary](#summary)
- [What is the difference between logging in, a context, a pin, and a workspace?](#what-is-the-difference-between-logging-in-a-context-a-pin-and-a-workspace)
- [Why did `init` fail from my home folder, and why is the path doubled?](#why-did-init-fail-from-my-home-folder-and-why-is-the-path-doubled)
- [What exactly does `agentengine atlas setup` do?](#what-exactly-does-agentengine-atlas-setup-do)
- [Why does the agent need a cluster at all if memory is off?](#why-does-the-agent-need-a-cluster-at-all-if-memory-is-off)
- [Why did it add two IP addresses to Atlas, and why those two?](#why-did-it-add-two-ip-addresses-to-atlas-and-why-those-two)
- [Where do secrets live: `.env` or the platform?](#where-do-secrets-live-env-or-the-platform)
- [What files do `init` and `atlas setup` leave in my agent folder?](#what-files-do-init-and-atlas-setup-leave-in-my-agent-folder)
- [Why did my LLM smoke test return 404?](#why-did-my-llm-smoke-test-return-404)
- [What usually goes wrong, and what is the lesson?](#what-usually-goes-wrong-and-what-is-the-lesson)

## Summary

The path that worked on CLI 0.1.118 (2026-10-04), all from the agent directory:

1. `agentengine dev up` → the local playground at `localhost:3000` answers through the gateway.
2. `agentengine init --context <name>` → registers the workspace.
3. `<secret-manager read> | agentengine secret set LLM_API_KEY --stdin` → the LLM key as a
   platform secret.
4. `agentengine atlas setup` → picks an existing Flex/M10+ cluster, creates a per-workspace DB
   user, uploads `MONGODB_URI`, allowlists the platform's Atlas-lane IPs.
5. `agentengine deploy --auto`.

The numbered procedure is in [RUNBOOKS.md](RUNBOOKS.md#first-deploy-of-a-scaffolded-agent).

## What is the difference between logging in, a context, a pin, and a workspace?

They answer four different questions.

| Thing | Answers | Lives where |
|---|---|---|
| Login (`auth login`) | Who are you? | `~/.agentengine/auth.json` |
| Context | Which org and project do commands target? | `~/.agentengine/contexts.json` (machine-wide, local label only) |
| Pin | Which context does this agent folder use? | `<agent>/.agentengine/state.json` |
| Workspace | Where does this agent run on the platform? | On the platform; its ID cached in `state.json` |

**The misconception to head off:** "pinning connects me to the platform." It only chooses a
target locally. The workspace is the platform-side object, and only `init` creates it. Without
it, `atlas setup` fails with `no workspace registered under context`.

The pin and the registration are keyed by an internal context ID (`ctx_…`), not the display
name, so the long auto-generated context name is cosmetic.

## Why did `init` fail from my home folder, and why is the path doubled?

`init` searches upward from the current folder for `agent.yaml`, the way git looks for `.git`.
From your home folder there is none, so it created the context and then stopped: a
half-success. Fix it with `init --context <name>` from the agent folder.

The doubled path (`<slug>/agents/<slug>`) is the normal layout: the outer folder is the
**project directory** (it holds `project-config.yaml`), and `agents/<slug>/` is the first
agent's **workspace directory**. A second agent would be `agents/<other>/`. Pass `--dir` to
`create` to name the outer one yourself.

## What exactly does `agentengine atlas setup` do?

Five things, in order:

1. Uses the Atlas project with the same ID as the AAE project.
2. Lets you pick a cluster. Free/shared tiers are hidden. It also offers "create new", which
   is billed.
3. Creates a DB user dedicated to this workspace, `agent-engine-<workspace_id>`.
4. Shows `MONGODB_URI` **once**, then uploads it as a **project** secret.
5. Adds the platform's two Atlas-lane outbound IPs to the Atlas project's IP Access List.

It skips the Voyage key when `features.memory` is off.

**The misconception:** "it will create a paid cluster." Only if you choose "create new" or
pass `--yes`. Picking an existing cluster costs nothing extra.

## Why does the agent need a cluster at all if memory is off?

The platform stores session state and execution records in **your** cluster, and requires
`MONGODB_URI` for every deploy regardless of memory. Local `dev up` does not need it: it runs
its own MongoDB container.

## Why did it add two IP addresses to Atlas, and why those two?

Deployed agents do not run on your machine. Their traffic leaves MongoDB's cloud from a small
fixed set of addresses, and Atlas blocks unknown addresses, so those must be allowlisted.

**The misconception:** "there is one pair of AAE IPs." There are two:

- The **Atlas lane** (what `atlas setup` adds to Atlas), from the `egress-ips` endpoint.
- The **non-Atlas lane** (what LLM gateways and other external services see, and must
  allowlist), from the `agent-egress-ips` endpoint. These are the ones in `/network-egress.md`.

Fetch both live rather than trusting a list. Detail in
[DRIFT_LOG.md](DRIFT_LOG.md#2026-10-08--there-are-two-egress-ip-pairs-one-per-lane).

## Where do secrets live: `.env` or the platform?

Both, for different runs:

- **Local (`dev up`)** reads only `<agent>/.env`. It is never uploaded: the build always
  excludes `.env*`.
- **Deployed** reads only platform secrets (`agentengine secret set`). These are
  **project-scoped by default**, so every agent in the project can read them. Use
  `--workspace-scope` for anything one agent alone should see.

## What files do `init` and `atlas setup` leave in my agent folder?

- `.agentengine/`: dev container files and `state.json` (pin, workspace and Atlas link IDs;
  **no secrets**).
- `.devcontainer/` and `.agentengineignore` (what the build upload excludes; it only counts at
  the archive root, see [MONOREPO_AND_BUILD.md](MONOREPO_AND_BUILD.md#what-does-the-build-actually-upload)).
- `.claude/skills/` and `.agents/skills/`: vendor skills (docs lookup, deploy
  troubleshooting, SDK-shape validation, a template guide). They load only when the coding
  assistant is started inside the agent folder, and being vendor-maintained they are often
  fresher than anything else. Read them when working in such a project.

## Why did my LLM smoke test return 404?

In the first deploy behind this write-up, the model name, not the URL or the auth header. The
scaffold had written a model **alias**, and the gateway answered
`not_found_error: The model does not exist`. Replacing it with the real model ID in `llm.py`
and `project-config.yaml` fixed it.

Rule of thumb: **401 means bad credentials; 404 means a wrong path or an unknown model.** For
Anthropic-protocol gateways the base URL is the part before `/v1/messages`, which the client
appends.

## What usually goes wrong, and what is the lesson?

| Slip | Lesson |
|---|---|
| Blaming the URL for a 404 | Read the project files and probe with curl before naming a cause |
| Suggesting `pin` instead of re-running `init` | A pin is not a workspace; `init --context <name>` recovers a half-done init |
| Assuming no cluster is needed with memory off | `MONGODB_URI` is required for every deploy |
| Fearing a context rename breaks the workspace | Registration is keyed by the internal context ID; the name is cosmetic |
| Pasting the `MONGODB_URI` into a chat or ticket | Anything "shown once" is a secret; if it leaks, rotate the DB user's password |
