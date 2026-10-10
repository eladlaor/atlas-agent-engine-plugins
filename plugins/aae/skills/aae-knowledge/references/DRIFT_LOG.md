---
name: aae-drift-log
description: Dated log of observed drift between the Atlas Agent Engine docs and the live platform or CLI, newest first.
---

# AAE drift log

- [Summary](#summary)
- [2026-10-10 — CLI 0.1.119 release notes are ahead of the docs](#2026-10-10--cli-01119-release-notes-are-ahead-of-the-docs)
- [2026-10-10 — the SDK reference and the guides disagree on names](#2026-10-10--the-sdk-reference-and-the-guides-disagree-on-names)
- [2026-10-10 — custom memory types are rejected by the live platform](#2026-10-10--custom-memory-types-are-rejected-by-the-live-platform)
- [2026-10-10 — per-agent `dev up` cannot see monorepo `shared/` path dependencies](#2026-10-10--per-agent-dev-up-cannot-see-monorepo-shared-path-dependencies)
- [2026-10-10 — the scaffold still writes the deprecated top-level `network.egress`](#2026-10-10--the-scaffold-still-writes-the-deprecated-top-level-networkegress)
- [2026-10-10 — new service-account role `AGENT_DEVELOPER`](#2026-10-10--new-service-account-role-agent_developer)
- [2026-10-09 — the local-mode memory package is now `agent-engine-sdk-memory`](#2026-10-09--the-local-mode-memory-package-is-now-agent-engine-sdk-memory)
- [2026-10-08 — there are two egress IP pairs, one per lane](#2026-10-08--there-are-two-egress-ip-pairs-one-per-lane)
- [2026-10-08 — the agent contract now marks `sandboxes` as required](#2026-10-08--the-agent-contract-now-marks-sandboxes-as-required)
- [2026-10-08 — multi-agent deploy surface](#2026-10-08--multi-agent-deploy-surface)
- [2026-10-08 — `api-key` is deprecated in favor of `service-account`](#2026-10-08--api-key-is-deprecated-in-favor-of-service-account)
- [2026-10-08 — memory is project-scoped, and PyPI's local-mode package is a placeholder](#2026-10-08--memory-is-project-scoped-and-pypis-local-mode-package-is-a-placeholder)
- [2026-10-08 — a cost surface exists in the API and in no guide](#2026-10-08--a-cost-surface-exists-in-the-api-and-in-no-guide)
- [2026-10-08 — the OpenAPI spec is ahead of the guides (OTLP trace export)](#2026-10-08--the-openapi-spec-is-ahead-of-the-guides-otlp-trace-export)
- [2026-10-08 — `--context ctx_…` reports "not found"](#2026-10-08----context-ctx_-reports-not-found)
- [2026-10-08 — a `.agentengineignore` inside an agent dir can be inert](#2026-10-08--a-agentengineignore-inside-an-agent-dir-can-be-inert)
- [2026-10-08 — `workspace sessions list` fails when the cluster is paused](#2026-10-08--workspace-sessions-list-fails-when-the-cluster-is-paused)
- [2026-10-08 — memory types: four in one page, six in another](#2026-10-08--memory-types-four-in-one-page-six-in-another)
- [2026-10-05 — a typo'd `deploy` subcommand runs a real deploy](#2026-10-05--a-typod-deploy-subcommand-runs-a-real-deploy)
- [2026-10-05 — `agentengine status` summary lags `deploy list`](#2026-10-05--agentengine-status-summary-lags-deploy-list)
- [2026-10-05 — deploying while the cluster resumes fails; the Orchestration Engine self-heals](#2026-10-05--deploying-while-the-cluster-resumes-fails-the-orchestration-engine-self-heals)
- [2026-10-05 — paused cluster: invoke returns 503 while `status` says healthy](#2026-10-05--paused-cluster-invoke-returns-503-while-status-says-healthy)
- [2026-10-05 — `workspace delete` exists although the docs say it does not](#2026-10-05--workspace-delete-exists-although-the-docs-say-it-does-not)
- [2026-10-05 — `provision-secrets` still shows secret values on the command line](#2026-10-05--provision-secrets-still-shows-secret-values-on-the-command-line)
- [2026-10-04 — local dev ports are random](#2026-10-04--local-dev-ports-are-random)
- [2026-10-04 — what `atlas setup` actually does](#2026-10-04--what-atlas-setup-actually-does)
- [How to add an entry](#how-to-add-an-entry)

## Summary

Newest first. Each entry: what the docs say, what was observed, and what to do. All CLI
observations are from `agentengine` **0.1.118** unless stated. Rules that fall out of this log:

- **Trust `--help` over the web docs**, and the OpenAPI spec over both for endpoints.
- **Absence in the guides proves only "undocumented"**, never "unbuilt". Check the OpenAPI
  JSON before declaring a capability missing.
- **Only `deploy list` and `deploy get <id>` are read-only.** Every other `deploy` form,
  including a typo, starts a real deployment.
- **Fetch egress IPs live.** There are two pairs for two purposes.

## 2026-10-10 — CLI 0.1.119 release notes are ahead of the docs

- **Docs say** (re-crawled 2026-10-10): the service-account memory-identity limitation is
  unconditional ("The platform ignores any end-user `user_id` value"); the install page says
  runtime images come from MongoDB's private Amazon ECR registry; the memory sample lists
  `entity` as a valid extraction type; only LangGraph and Google ADK adapters are documented.
- **Observed:** `agentengine` **0.1.119** was released on 2026-10-08 on the public GitHub
  releases of `mongodb/agent-engine-client-libraries` (binaries attached; the docs only
  describe the signed-in download page). Its notes include "Gate invoke user_id delegation
  behind per-project opt-in", "Propagate parent user_id to A2A child executions", "Prevent
  projects from enabling entity memory extraction", "make public GHCR the unconditional
  default" for images, and an OpenAI Agents adapter marked "[After PubPreview]". None of these
  is in the guides yet. The OpenAPI spec has run-level `user_id` / invoker fields described
  as "the delegation target the run executed as", but no opt-in setting was found.
- **Resolution:** untested; the card was checked on 0.1.118. Keep prescribing the
  standalone-memory workaround for per-user memory until a doc or a test shows the opt-in.
  Do not enable `entity` extraction. Re-check after upgrading to 0.1.119.

## 2026-10-10 — the SDK reference and the guides disagree on names

- **Deep-agent backend:** `/build/build-deep-agent.md` calls the default backend
  `AgentEngineToolSandboxBackend` (import path
  `agent_engine_sdk_langgraph.backends.tool_sandbox`); the Python and TypeScript SDK API
  references call it `AgentEngineToolPodBackend`. Check the installed package before importing.
- **TypeScript package:** the SDK reference now names `@mongodb-js/agent-engine-sdk-langgraph`
  (npm `latest` 0.11.8). The Python packages `agent-engine-sdk-langgraph`, `-sdk-adk`,
  `-sdk-memory` and `agent-engine-runner-shared` are all 0.11.8 on public PyPI.
- **`agent.yaml` keys the card lacked:** the contract table also lists `name`,
  `description`, `features.guardrails`, `features.deep_agent`, `artifact_repositories` and
  `scaling.agent_idle_ttl_seconds` (1–86400, default 600). `language` and `framework` appear
  in create-project, not in the contract table.

## 2026-10-10 — custom memory types are rejected by the live platform

- **Docs say** (`/add-features/memory.md`, "Declare Custom Memory Types"): declare
  `custom_memory_types:` in `project-config.yaml`, then `memory configure` and `memory apply`.
  No feature gate is mentioned.
- **Observed:** `agentengine memory configure --yes` fails with
  `upload memory config: set memory config: custom_memory_types is not enabled on this deployment`.
  The **whole** upload is rejected; nothing is stored, and `memory status` stays `not_provisioned`.
- **Resolution:** the feature is switched off platform-side and a user cannot enable it per
  project. Comment out the `custom_memory_types:` block and upload the rest of the config.
  Re-test after doc or CLI changes.

## 2026-10-10 — per-agent `dev up` cannot see monorepo `shared/` path dependencies

- **Docs say** (`/manage/monorepo.md`): `shared/` is "included in all builds"; path
  dependencies resolve because the archive root is the repo root.
- **Observed:** `agentengine dev up` from `agents/<a>`, and `dev up --workspace <a>` from the
  root, both mount **only the agent dir** at `/app`. The app container's `uv sync` fails with
  `cannot normalize a relative path beyond the base directory: /app/../../shared/<lib>`.
  MongoDB, the memory server and the Orchestration Engine come up healthy; the app does not.
  Whether `dev up --all` from the root mounts the whole repo is **untested** (it needs a root
  `.env` with an LLM key).
- **Resolution:** none yet. Builds and deploys are unaffected; local dev of agents with
  `shared/` path deps is.

## 2026-10-10 — the scaffold still writes the deprecated top-level `network.egress`

- **Docs say** (`/network-egress.md`): declare egress per sandbox under
  `sandboxes.<name>.network`; the top-level form is migrated with `agentengine migrate sandboxes`.
- **Observed:** `agentengine create --llm anthropic-compatible …` writes top-level
  `network.egress`. `agentengine agent validate` accepts both forms.
- Also observed the same day:
  - `agent validate` on a monorepo **root** `agent.yaml` fails with "must declare a network
    egress policy". Validate the per-agent files only.
  - `network.atlas_clusters` entries must match `<prefix>.<5–7 char id>.mongodb.net`
    (a validator rule, not in the docs).
  - `sandboxes.tool.tools: [invoke_llm]` validates.

## 2026-10-10 — new service-account role `AGENT_DEVELOPER`

- **Docs / earlier knowledge:** project service-account roles are `PROJECT_OWNER` and
  `PROJECT_READ_ONLY`.
- **Observed** (`service-account create --help` and the console's *Connect to workspace*
  dialog): project roles are `PROJECT_OWNER`, `PROJECT_READ_ONLY`, **`AGENT_DEVELOPER`**.
  `AGENT_DEVELOPER` has no Atlas equivalent and "can invoke, build, and deploy agents".
  Stored names differ from the flag names: `PROJECT_READ_ONLY` → `PROJECT_MEMBER`,
  `ORG_GROUP_CREATOR` → `ORG_ADMIN`. The legacy names `PROJECT_MEMBER`, `ORG_ADMIN` and
  `ORG_MEMBER` are accepted with a deprecation warning.
- **Resolution:** no invoke-only role is visible in `--help`, so a client that only needs
  to invoke still gets build and deploy rights through `AGENT_DEVELOPER`. Say so when
  recommending it.
- **Update 2026-10-10:** the OpenAPI spec and `/manage/inspect-traces.md` ("Agent Developer")
  know the role, but `/api-keys-service-accounts.md` still lists only `PROJECT_OWNER` /
  `PROJECT_READ_ONLY` and `ORG_GROUP_CREATOR` / `ORG_READ_ONLY`, and says a project account
  needs `PROJECT_OWNER` to invoke.

## 2026-10-09 — the local-mode memory package is now `agent-engine-sdk-memory`

- **Docs said** (until 2026-10-08, `/add-features/memory-only.md` and `/add-features/memory-mcp.md`):
  local mode uses `agentic-platform-memory`; hosted mode uses `agent-engine-sdk-memory`.
- **Observed** (docs re-crawl, 2026-10-09): both pages now name `agent-engine-sdk-memory` for
  local mode too, including the install command. Anchor IDs still say `agentic-platform-memory`.
- **Resolution:** one package for local and hosted. The `aae-guide` card's "local mode uses
  `agentic-platform-memory`" line was stale and was corrected on 2026-10-10.
- **Update 2026-10-10:** the SDK reference imports `Memory` from `agent_engine_sdk_memory` in
  every mode, but `/add-features/memory-only.md`'s local-mode snippet still says
  `from agentic_platform_memory import Memory, MemoryRequestContext` right after installing
  `agent-engine-sdk-memory`. That import is the stale part; use `agent_engine_sdk_memory`.

## 2026-10-08 — there are two egress IP pairs, one per lane

- **Docs say** (`/network-egress.md`): `34.196.57.85` and `54.227.181.25` are the egress IPs
  "for destinations outside of Atlas".
- **Observed** (unauthenticated GETs against the platform API):
  - `GET https://agentengine.mongodb.com/api/v1/platform/agent-egress-ips` →
    `34.196.57.85/32`, `54.227.181.25/32`. **Non-Atlas lane:** allowlist these on LLM
    gateways, SaaS APIs, anything your agent calls. Not on Atlas.
  - `GET https://agentengine.mongodb.com/api/v1/platform/egress-ips` (marked deprecated) →
    `aws/us-east-1`: `44.214.209.237/32`, `52.44.27.64/32`. **Atlas lane:** what
    `agentengine atlas setup` / `atlas setup-ip-access` put in the Atlas IP Access List.
- **Correction of earlier entries:** on 2026-10-04 and 2026-10-05 the documented pair was
  recorded as "stale" because `atlas setup` allowlisted the other pair and the Atlas list
  never contained the documented one. That conflated the two lanes. Neither pair is stale.
- **Resolution:** Atlas IP list ← `agentengine atlas setup-ip-access` (or the `egress-ips`
  endpoint). External services ← `agent-egress-ips`. Fetch both live; never hardcode.
- **Re-checked 2026-10-10:** both endpoints return the same pairs; the docs still list only
  the non-Atlas pair.

## 2026-10-08 — the agent contract now marks `sandboxes` as required

- **Docs said** (`/reference/agent-contract.md`, earlier): `entrypoint` alone is the minimum.
- **Observed:** the schema table now marks `sandboxes` **and** `sandboxes.agent` as required,
  though the same page's "minimal agent.yaml" example still shows only `entrypoint`.
  New in the table: `scaling.tool_idle_ttl_seconds`. Only two sandbox names are allowed
  (`agent`, `tool`); a tool assigned to both is rejected; unassigned tools default to the
  agent sandbox. A tool-sandbox LLM call needs `invoke_llm` in `sandboxes.tool.tools` and the
  key in `sandboxes.tool.secrets`.
- **Resolution:** declare `sandboxes.agent` in every `agent.yaml`. See
  [DOC_CONTRADICTIONS.md](DOC_CONTRADICTIONS.md) item 3.

## 2026-10-08 — multi-agent deploy surface

From `--help`:

- `deploy --auto` is single-agent only; it rejects `--workspace` and `--all`.
- `deploy --all` and `deploy --workspace` never start a build. Run `agentengine build --all`
  first (one archive, N builds).
- `--all` and any non-interactive deploy never prompt and never run `init` or `atlas setup`;
  they print what setup is missing.
- A bare interactive `deploy` checks that every populated `.env` key exists as a platform
  secret and offers to store the missing ones.
- `secret set` gained `--from-file -`, `--project-scope`, `--workspace <name>`. `--context`
  requires `--project-scope`.
- `context current` now describes its "Source" as a tier: `--context` flag or directory pin.
- The claim that `atlas setup` grants its DB user `readWriteAnyDatabase` is **not** stated in
  `/deploy/atlas-setup.md`. **Resolved 2026-10-10:** `/reference/limitations.md` ("Database
  Access") states it, and says to create a narrower user scoped to `MDB_AGENTIC_STORE_DB` and
  `MONGOMEM_DB_NAME` and store it as a `MONGODB_URI` workspace secret.

## 2026-10-08 — `api-key` is deprecated in favor of `service-account`

- **Docs say** (`/deploy/ci-cd.md`): create credentials with `agentengine api-key create`.
- **Observed:** the command exists, but `api-key --help` says API keys are deprecated; use
  `agentengine service-account`.
- **Resolution:** prescribe service accounts. The CI/CD page lags.

## 2026-10-08 — memory is project-scoped, and PyPI's local-mode package is a placeholder

- **Docs say** (`/add-features/memory.md`): memory is configured at project level; "All agents
  in a project share the same memory service, store, and settings". Per agent there is only
  an on/off switch (`features.memory`). Scopes (`/memory-types.md`): private (user identity)
  for semantic, episodic and procedural; org (project-wide) for taxonomic.
- **Observed:** no agent or workspace namespace is documented anywhere;
  `MemoryRequestContext` carries only `user_id` and `session_id`. The A2A page does not say
  which memory identity a callee uses or whether `user_id` propagates. The public REST memory
  operations (config get/put/sync, context, retrieval, runtime, search, turns, project memory
  MCP) include **no delete endpoint**.
- **Observed:** public PyPI's `agentic-platform-memory`, the package the older docs said to
  `pip install`, is version 0.0.1, a two-line placeholder that does nothing.
- **Resolution:** treat per-agent memory isolation as **not** a platform feature; separate
  projects if you need it. Do not install `agentic-platform-memory` from PyPI. More memory
  config keys: [VERIFIED_DETAILS.md](VERIFIED_DETAILS.md#memory-scoping-and-config-keys-the-card-omits).

## 2026-10-08 — a cost surface exists in the API and in no guide

- **Docs say:** nothing about dollars. `/manage/monitor.md` covers logs, deployment events,
  health and a policy-denials tile. `/manage/inspect-traces.md` shows token counts in the UI.
  The CLI has no `cost`, `usage` or `trace` command.
- **Observed:** `GET /api/v1/projects/{id}/cost/dashboard?period=…&workspace_id=…` (OpenAPI
  tag `Cost`) returns `total_cost_usd`, token splits, `unpriced_llm_calls`, `by_model[]`,
  `by_workspace[]`, `daily_trend[]`. `ExecutionLog` carries per-step `cost_usd`.
- **Resolution:** detail in [TOKEN_AND_COST_ACCOUNTING.md](TOKEN_AND_COST_ACCOUNTING.md).
  Undocumented means unstable: say both.

## 2026-10-08 — the OpenAPI spec is ahead of the guides (OTLP trace export)

- **Docs say:** nothing. No guide page, no `llms.txt` entry, no CLI command for trace export
  or OpenTelemetry.
- **Observed:** the OpenAPI spec (`https://www.mongodb.com/docs/api/doc/agentengine.json`) has
  `trace-export/config`, `trace-export/presets` and `GET /traces`: a project-level OTLP
  exporter with content-redaction and egress-mirroring modes. An earlier reading (2026-10-05)
  concluded "OpenTelemetry is absent"; that was right about the guides and wrong about the
  platform.
- **Resolution:** **check the OpenAPI JSON before declaring any capability absent.** Fetch it
  with `curl -sL --compressed`. Detail: [VERIFIED_DETAILS.md](VERIFIED_DETAILS.md#otlp-trace-export-exists-in-the-api).

## 2026-10-08 — `--context ctx_…` reports "not found"

- **Observed:** `--context ctx_<id>` fails with `context "ctx_..." not found`, which reads as
  "this context was deleted" but means "wrong identifier form". `--context` takes the
  **display name**.
- **Resolution:** map `ctx_` IDs (in `<agent>/.agentengine/state.json`) to display names via
  `~/.agentengine/contexts.json` before declaring a context dead. Detail:
  [CLI_TARGETING_AND_CONTEXTS.md](CLI_TARGETING_AND_CONTEXTS.md).

## 2026-10-08 — a `.agentengineignore` inside an agent dir can be inert

- **Docs say** (`/deploy/agent-image.md`, "Archive Root"): the archive root is the agent dir
  by default, but the **monorepo root** when the agent dir is listed verbatim in the root
  `agent.yaml` `agents[].path`. `.agentengineignore` is read from the archive root only.
- **Observed:** after converting a single-agent project to a monorepo, the per-agent ignore
  file was silently ignored and repo-level folders (docs, editor config, the changelog) were
  uploaded on every build of every agent.
- **Resolution:** move `.agentengineignore` to the repo root when converting. Detail:
  [MONOREPO_AND_BUILD.md](MONOREPO_AND_BUILD.md#what-does-the-build-actually-upload).

## 2026-10-08 — `workspace sessions list` fails when the cluster is paused

- **Observed:** `agentengine workspace sessions list` fails with
  *"Failed to query execution data from Orchestration Engine"*.
- **Resolution:** same family as the paused-cluster 503 below. Check the Atlas cluster state
  before treating it as a platform fault.

## 2026-10-08 — memory types: four in one page, six in another

- **Docs say** (`/add-features/memory-types.md`): semantic, episodic, procedural, taxonomic.
- **Observed:** the scaffolded `project-config.yaml` comment (CLI 0.1.118, first seen
  2026-10-05) lists "semantic, episodic, taxonomic, **entity**, **preferences**, procedural".
  On 2026-10-08 `/add-features/memory.md` carried the same six-type comment in its sample.
- **Resolution:** unresolved and untested. Do not promise `entity` or `preferences`.
- **Update 2026-10-10:** CLI 0.1.119's release notes include "Prevent projects from enabling
  entity memory extraction", while `/add-features/memory.md` still lists `entity` as valid.

## 2026-10-05 — a typo'd `deploy` subcommand runs a real deploy

- **Docs say:** nothing. Expectation: an unknown subcommand errors out.
- **Observed:** `agentengine deploy events <deployment-id>` (there is no `events`
  subcommand) did **not** error. The CLI fell through to bare `agentengine deploy` and started
  a live deployment during what was meant to be a read-only investigation.
- **Resolution:** **the only safe `deploy` verbs are `deploy list` and `deploy get <id>`.**
  `deploy get <id>` already prints the Conditions block with the failure reason.

## 2026-10-05 — `agentengine status` summary lags `deploy list`

- **Observed:** after a new deployment succeeded, `status` still named the previous
  deployment in its summary line while correctly reporting 4/4 healthy. `deploy list` showed
  the new one.
- **Resolution:** trust `deploy list` for **which** deployment is live. Use `status` for
  health only.

## 2026-10-05 — deploying while the cluster resumes fails; the Orchestration Engine self-heals

- **Observed:** the Atlas cluster paused overnight; the Orchestration Engine (OE) lost MongoDB
  and went into CrashLoopBackOff. A deploy fired while the cluster was resuming failed with
  `OENotReady — TenantEnvironment "te-<project_id>" is not yet available … the orchestration
  engine could not reach MongoDB via MONGODB_URI`. Secrets and sandbox conditions were all
  green; no runtime logs appear in this state.
- **What was misread at first:** the failed deployment record was taken as proof the OE was
  permanently down and a redeploy mandatory. Wrong mechanism: CrashLoopBackOff is a
  Kubernetes state that keeps retrying with backoff (capped near 5 minutes). A `status` run
  *before* that deploy already showed the OE healthy on the previous deployment.
- **Rules that survive:**
  - A deploy fired before the cluster genuinely accepts connections fails, and its record is
    stamped `failed` **permanently**. Deployment records never flip back.
  - A resuming replica set reports "running" before all nodes finish election. Wait until it
    actually serves.
  - The OE recovers by itself once MongoDB is reachable. Check `agentengine status`, then
    invoke, before reaching for a redeploy.
- **Unconfirmed:** whether a redeploy was strictly unnecessary. Next time, **invoke first**
  and record the answer. Runbook: [RUNBOOKS.md](RUNBOOKS.md#recover-after-the-atlas-cluster-pauses).

## 2026-10-05 — paused cluster: invoke returns 503 while `status` says healthy

- **Observed:** with the backing Atlas cluster paused, `agentengine status` reported ready and
  healthy 4/4, while `invoke` failed fast with 503 "agent is currently unavailable … may still
  be starting up", and there were no runtime logs. `agentengine atlas status` showed
  `egress sync: ok (no clusters)` with the hint "Paused clusters … are omitted from egress sync".
- **Resolution:** on "agent unavailable" plus healthy status, run `agentengine atlas status`
  **first**.
- **Also observed:** `agentengine deploy --auto` reported "session expired … refresh token:
  context deadline exceeded" after the laptop slept, but the server-side build and deploy
  completed. Check `build list` / `deploy list` before re-running.

## 2026-10-05 — `workspace delete` exists although the docs say it does not

- **Docs say** (`/manage/project-org-workspace/manage-project/`): workspace has `list`, `get`,
  `create`, `update`; "There is no CLI delete command."
- **Observed** (`agentengine workspace --help`): `list`, `get`, **`sessions`**, `create`,
  `update`, **`delete`**.
- **Resolution:** trust `--help`. Treat `workspace delete` as live and destructive. It does not
  remove secrets, sessions or the Atlas DB user; the `aae-delete-agent` skill does the full
  teardown.

## 2026-10-05 — `provision-secrets` still shows secret values on the command line

- **Docs say** (`/deploy/provision-secrets.md`): `agentengine secret set NAME VALUE [...]`,
  with worked examples that paste literal values such as a full `MONGODB_URI`.
- **Observed** (`secret set --help`): the positional VALUE and `--value` are both deprecated.
  Omit the value for a hidden prompt, or pipe with `--stdin`.
- **Resolution:** never follow the page's example shape; it writes secrets into shell history.
  Use `<secret-manager read> | agentengine secret set NAME --stdin`.

## 2026-10-04 — local dev ports are random

- **Earlier knowledge said:** Orchestration Engine on `:51331`, MongoDB on `:51333`.
- **Observed** (`dev.yaml`): only the playground is pinned (`:3000`). The OE, runtime, tool,
  memory-server and MongoDB host ports are random unless pinned in `dev.yaml` `services:`.
  Dev modes: hot-reload (one app container, the default) and `--isolated` (one container per
  process, the production topology).
- **Resolution:** read the actual ports from `agentengine dev status`.

## 2026-10-04 — what `atlas setup` actually does

- Interactive picker lists existing clusters (tier and state), "create new", and "refresh".
  Free and shared tiers are not selectable.
- Creates a per-workspace DB user named `agent-engine-<workspace_id>`. Its role was not
  verified (see the 2026-10-08 deploy-surface entry).
- Shows the `MONGODB_URI` **once**, asks before uploading it, asks before changing the IP list.
- Skips the Voyage key prompt when memory is off.
- Writes the Atlas link (IDs only, no secrets) into `.agentengine/state.json`.
- The pin and workspace registrations in `state.json` are keyed by an internal `ctx_…` ID,
  not by the context display name.

## How to add an entry

Add new entries at the top, dated, in this shape. Update an entry in place when it is
superseded, and say what it corrects; do not leave a wrong rule standing unannotated.

```
### <YYYY-MM-DD> — <one-line symptom> (CLI <version>)
Docs say: <quote or page>
Observed: <what actually happened>
Resolution: <what to do>
```
