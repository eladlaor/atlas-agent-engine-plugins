---
name: aae-drift-log
description: Dated log of observed drift between the Atlas Agent Engine docs and the live platform or CLI, newest first.
---

# AAE drift log

- [Summary](#summary)
- [2026-11-24 — service-account roles now use Atlas names; `AGENT_DEVELOPER` is gone](#2026-11-24--service-account-roles-now-use-atlas-names-agent_developer-is-gone)
- [2026-11-24 — the docs no longer say service-account invokes share one memory identity](#2026-11-24--the-docs-no-longer-say-service-account-invokes-share-one-memory-identity)
- [2026-11-24 — CLI commands moved: `deploy --build`, `agent create-tool`, `agent validate`](#2026-11-24--cli-commands-moved-deploy---build-agent-create-tool-agent-validate)
- [2026-11-24 — `app.llm()` before `app.deep_agent()` is allowed again, per the release notes](#2026-11-24--appllm-before-appdeep_agent-is-allowed-again-per-the-release-notes)
- [2026-11-24 — trace export is now documented](#2026-11-24--trace-export-is-now-documented)
- [2026-11-24 — pool-full: raise `replicas` first, and a shared session ID shares state](#2026-11-24--pool-full-raise-replicas-first-and-a-shared-session-id-shares-state)
- [2026-11-24 — `sandboxes.agent.secrets: []` does not keep a secret out of the agent sandbox](#2026-11-24--sandboxesagentsecrets--does-not-keep-a-secret-out-of-the-agent-sandbox)
- [2026-11-12 — the egress page now lists all four IPs as one list](#2026-11-12--the-egress-page-now-lists-all-four-ips-as-one-list)
- [2026-11-12 — `secret set --sync` and `secret sync` time out although the secret is live (CLI 0.1.124)](#2026-11-12--secret-set---sync-and-secret-sync-time-out-although-the-secret-is-live-cli-01124)
- [2026-10-13 — `deepagents` 0.7.16 has no planner, and there is no default system prompt](#2026-10-13--deepagents-0716-has-no-planner-and-there-is-no-default-system-prompt)
- [2026-10-13 — the deep-agent page claims a custom `backend` is rejected; it is not](#2026-10-13--the-deep-agent-page-claims-a-custom-backend-is-rejected-it-is-not)
- [2026-10-13 — a missing `features.deep_agent` fails at run time, not build time](#2026-10-13--a-missing-featuresdeep_agent-fails-at-run-time-not-build-time)
- [2026-10-13 — `agent validate` does not enforce the required fields](#2026-10-13--agent-validate-does-not-enforce-the-required-fields)
- [2026-10-13 — `project-config.yaml` has a second top-level key, `memory_only`](#2026-10-13--project-configyaml-has-a-second-top-level-key-memory_only)
- [2026-10-13 — `--open-egress` writes to `agent.yaml`, not `project-config.yaml`](#2026-10-13----open-egress-writes-to-agentyaml-not-project-configyaml)
- [2026-10-11 — a per-type extraction prompt exists only in the CLI template](#2026-10-11--a-per-type-extraction-prompt-exists-only-in-the-cli-template)
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
- **`deploy list`, `deploy get <id>` and `deploy logs <id>` are read-only** (corrected
  2026-10-13 on 0.1.118; an earlier version of this rule omitted `logs`). `deploy cancel` is
  mutating, and any form outside those four — including a typo — starts a real deployment.
- **Fetch egress IPs live.** There are two pairs; as of 2026-11-12 the docs list all four as
  one list. External allowlists need the non-Atlas pair and should carry all four.
- **A `validate` pass proves almost nothing.** It enforces an egress policy and little else —
  not `entrypoint`, not `sandboxes`, not unknown keys.

## 2026-11-24 — service-account roles now use Atlas names; `AGENT_DEVELOPER` is gone

- **Earlier knowledge** (2026-10-10 entry below, CLI 0.1.118): project roles `PROJECT_OWNER`,
  `PROJECT_READ_ONLY`, `AGENT_DEVELOPER`; org roles `ORG_GROUP_CREATOR`, `ORG_READ_ONLY`.
- **Docs say** (`/api-keys-service-accounts.md`, fetched 2026-11-24): "Service account roles
  use Atlas role names": project `PROJECT_OWNER`, `PROJECT_READ_ONLY`; org `ORG_OWNER`,
  `ORG_GROUP_CREATOR`, `ORG_READ_ONLY`. To invoke, a project account needs `PROJECT_OWNER`; an
  org account needs `ORG_GROUP_CREATOR` or `ORG_OWNER`.
- **Observed** (`service-account create --help`, CLI 0.1.126; the change first appears in the
  0.1.120 release notes as "Offer Atlas role names for service accounts"): the same five roles,
  no `AGENT_DEVELOPER`. `ORG_OWNER` "is accepted only where the organization has the owner role
  enabled". New: creating an account "can also create a paired Atlas service account", which
  needs Atlas service-account pairing turned on for the org or project. In a terminal the CLI
  asks before turning it on; `--enable-atlas-pairing` turns it on without a prompt; declining,
  or no terminal and no flag, creates nothing. A created pair's Atlas ID is printed.
- **Resolution:** prescribe `--role PROJECT_OWNER` for a client that invokes, and say that it
  also grants build and deploy: there is still no invoke-only role. Add `--enable-atlas-pairing`
  in scripts. Re-check `--help` before naming a role; this list has changed twice.

## 2026-11-24 — the docs no longer say service-account invokes share one memory identity

- **Docs said** (until 2026-10-19, on six pages): a service-account invoke uses the service
  account's own identity for memory and ignores `user_id`, so every end user behind it shares
  one memory scope.
- **Docs say now:** nothing. Docs commit `e531bd2` in `mongodb/docs` (2026-10-19) removed the
  banner from the memory, memory-types, memory-extraction, service-accounts and invoke pages
  and the section from the limitations page, calling it "no longer true". Left behind
  (2026-11-24): the invoke page's `--user-id` flag row still says a service account "cannot use
  this flag to act as another user", linking to the deleted note.
- **Observed** (2026-11-24): CLI 0.1.126 `invoke --help`: "on a project that enforces
  identity, only a service account may name a user other than itself; other callers are
  rejected with 403". The OpenAPI spec's `user_id` description still says "Service accounts
  cannot yet act as another user." The 0.1.119–0.1.121 release notes mention gating `user_id`
  delegation behind a per-project opt-in; no doc says how to turn it on.
- **Resolution: documented as changed, live behaviour unverified.** Test before relying on
  per-user memory: on a memory-enabled agent, invoke through the service account as
  `--user-id a` and state a fact; once extraction has run, ask for it as `--user-id b` in a
  new session; check the trace's "Run as" (`user_id`) and "Invoked by" (`invoker_user_id`).
  If B sees A's fact, the collapse still applies and the standalone-memory workaround stands
  (see [VERIFIED_DETAILS.md](VERIFIED_DETAILS.md#what-does-the-memory-service-trust-keep-and-drop)).

## 2026-11-24 — CLI commands moved: `deploy --build`, `agent create-tool`, `agent validate`

- **Earlier knowledge** (CLI 0.1.118–0.1.121): `agentengine deploy --auto` built and deployed;
  `agentengine create-tool` and `agentengine validate` were top-level.
- **Observed** (release notes and CLI 0.1.126 `--help`, 2026-11-24):
  - 0.1.123, breaking: a bare `deploy` "deploys the last successful image and fails if none
    exists". `deploy --build` is the one-step build-and-deploy path, single-agent only (it
    rejects `--build-id`, `--version`, `--no-wait`, `--workspace`, `--all`). `--auto` still
    works but prints "Flag --auto has been deprecated, use --build instead".
  - 0.1.122, breaking: `create-tool` moved to `agentengine agent create-tool`; the old path is
    an unknown command. 0.1.123 changed its auth options and takes the connector name as a
    positional argument; 0.1.124 makes `agent validate`, `build` and `deploy --build` reject
    connectors missing their network, secret or tool grants (`agent validate --fix` adds them).
  - A top-level `agentengine validate` fails with "command moved: use 'agentengine agent
    validate' with the same arguments".
- **Resolution:** use `deploy --build`, `agent create-tool` and `agent validate`. Where an
  older entry in this knowledge base says `deploy --auto`, read `deploy --build`.

## 2026-11-24 — `app.llm()` before `app.deep_agent()` is allowed again, per the release notes

- **Docs say** (`/build/build-deep-agent.md`, fetched 2026-11-24): do not wrap the LLM with
  `app.llm()` before passing it to `app.deep_agent()`; it registers the `__default__` LLM ID
  twice and the agent fails to start.
- **Observed:** the CLI 0.1.122 release notes (2026-10-28): "`app.deepAgent()` and
  `App.deep_agent()` now work when you register the orchestrator model with `app.llm()` before
  building the graph." Not tested here.
- **Resolution:** from CLI 0.1.122 and the SDK released with it, pre-registering is supported
  per the release notes; on older SDKs, or when unsure, pass the bare model as the page says.

## 2026-11-24 — trace export is now documented

- **Earlier knowledge** (2026-10-08 entry below): trace export existed only in the OpenAPI spec.
- **Docs say** (`/manage/inspect-traces.md`, "Export Traces to Arize", added by docs commit
  `3449371` on 2026-11-18): project-level export over OTLP/HTTP (`HTTP/protobuf`, the only
  supported protocol), configured from the Traces page's *Trace Export* window, with an Arize
  preset or "Custom (no preset)" for any other OTLP destination. "Currently, you must export
  the full content of your traces … Metadata-only redaction is not yet available." Egress mode
  shows as read-only "Agent Engine + customer mirror".
- **Resolution:** point users at the guide; the API endpoints in
  [VERIFIED_DETAILS.md](VERIFIED_DETAILS.md#otlp-trace-export-exists-in-the-api) remain the
  scripted path. Full content means prompts, completions and tool payloads leave the
  platform: get the data owner's sign-off. Delivery is best-effort (product team, 2026-11-10).

## 2026-11-24 — pool-full: raise `replicas` first, and a shared session ID shares state

- **Docs say** (`/deploy/invoke-agent.md#pool-full-errors` and `/reference/limitations.md`,
  fetched 2026-11-24): each session reserves one agent and one tool sandbox; `scaling.replicas`
  (1–512, default 4) is the number of concurrent sessions; a full pool fails new invokes. The
  remedies table now leads with **increasing `scaling.replicas`**, then shorter idle TTLs,
  reusing a session ID ("Requests that share a session ID also share the same session state.
  Do not reuse a session ID if your workload requires isolation"), and `app.finish_session()`.
- **Observed:** CLI 0.1.126 `workspace sessions --help`: "Testing sessions created from the
  Playground or 'agentengine invoke' may be reclaimed automatically when the workspace is at
  capacity. Other sessions are user-managed and stay reserved until they go idle or you stop
  them." Field observation (CLI 0.1.120, 2026-10-24): the error is HTTP 503 "All agent
  instances are currently busy" (`POOL_EXHAUSTED` with `Retry-After` in the spec); idle
  sessions held their slots for the 10-minute default idle TTL; and **A2A calls reserve
  sessions in the callee workspace**, so a busy orchestrator can fill its callees' pools.
- **Resolution:** size `replicas` for every workspace, A2A callees included, and rebuild after
  changing it. Reuse a session ID only within one user's conversation. Call
  `app.finish_session()` in one-shot callees. Inspect and free slots with
  `agentengine workspace sessions list` / `stop <session-id>`.

## 2026-11-24 — `sandboxes.agent.secrets: []` does not keep a secret out of the agent sandbox

*Field observation, 2026-10-24, CLI 0.1.120, SDK 0.11.10; one project, not re-tested on
0.1.126.*

- **Docs say** (`/reference/agent-contract.md`): `sandboxes.<s>.secrets` lists the secret names
  "available to" that sandbox. No page says undeclared secrets are withheld, and
  `/reference/limitations.md` says "Agents have access to all secrets in their project".
- **Observed:** with `sandboxes.agent.secrets: []` and a workspace secret listed only under
  `sandboxes.tool.secrets`, the secret was present in the agent sandbox's environment on every
  session, before any tool call. The SDK's tool server hard-codes its restriction off, and
  `required_secrets.disable_restriction` is "ignored at enforcement".
- **Resolution:** do not use per-sandbox secret lists as an isolation boundary. Keep a secret
  that one agent must not see in a different project, or outside Agent Engine.

## 2026-11-12 — the egress page now lists all four IPs as one list

- **Docs say** (`/network-egress.md#egress-ip-addresses`, fetched 2026-11-12): "The Atlas
  Agent Engine uses the following egress IP addresses for destinations outside of Atlas:"
  `34.196.57.85`, `54.227.181.25`, `52.44.27.64`, `44.214.209.237`, and "the external
  service's allowlist must include these addresses." Until at least 2026-10-10 the page listed
  only the first two.
- **Observed** (unauthenticated GETs, 2026-11-12): unchanged from 2026-10-08.
  `agent-egress-ips` → `34.196.57.85/32`, `54.227.181.25/32`; `egress-ips` →
  `aws/us-east-1`: `44.214.209.237/32`, `52.44.27.64/32`.
- **Resolution:** the endpoints still split the pairs by lane, and the non-Atlas pair is the one
  outbound internet traffic is known to use. The docs now ask external services to allowlist
  the Atlas-lane pair as well, so treat it as a buffer, not a substitute: **external services
  (LLM gateways, SaaS APIs) → all four; the Atlas IP Access List → the Atlas-lane pair**, as
  `atlas setup` writes it. Allowlisting helps only if the target is reachable from the public
  internet; a gateway on a private network or VPN stays unreachable from a deployed agent
  whatever its allowlist says. This corrects the 2026-10-08 entry's "not on Atlas" framing for
  external services and its note that the docs list only the non-Atlas pair.

## 2026-11-12 — `secret set --sync` and `secret sync` time out although the secret is live (CLI 0.1.124)

*Single field report, 2026-11-11, CLI 0.1.124; not confirmed by the product docs.*

- **Docs say** (CLI `--help`): `--sync` waits until the next message can use the new value;
  `secret sync` reloads stored values into running deployments.
- **Observed:** in a project whose deploy events say "Application secrets are served by the
  credential broker", both commands time out after **5 minutes** every time. The runtime
  secrets status stays `{"ready": false, "source": "broker", "reason": "pending"}`, yet the
  new value is in use within about **2 minutes**.
- **Resolution:** on a broker-backed project, treat the timeout as a false failure. Verify the
  change with an `agentengine invoke` that exercises the secret instead of re-running `sync`.

## 2026-10-13 — `deepagents` 0.7.16 has no planner, and there is no default system prompt

- **Docs say** (`/build/build-deep-agent.md`, checked 2026-10-13): if `system_prompt` is
  omitted, "the agent uses the default prompt from the `deepagents` library." The page never
  mentions planning or todos either way, and the wider "deep agents" framing in circulation
  describes a planning/todo tool as a defining feature.
- **Observed** (introspected `deepagents==0.7.16`, the version SDK 0.11.8 pins, installed in a
  clean venv): there is **no `deepagents.middleware.todo` module and nothing todo-shaped in the
  package exports**. The built-in tool suite is exactly `ls`, `read_file`, `write_file`,
  `edit_file`, `glob`, `grep`, `execute`, `task`. And `create_deep_agent`'s own contract is the
  opposite of the doc on prompts: with `system_prompt=None` and no harness profile defining
  `base_system_prompt`/`system_prompt_suffix`, "the model receives an empty authored system
  prompt."
- **Resolution:** a deep agent on AAE is **filesystem + shell + subagent delegation + skills**,
  not a planner. Always pass `system_prompt=` explicitly — omitting it yields no instructions
  at all, not a sensible default. If an agent needs a plan, build the planning step yourself.
  Note the doc also pins `deepagents==0.5.3` in its `pyproject.toml` snippet, which is the
  release *before* the todo tool was removed; following the doc would give a different tool set
  than the SDK expects. Pin the SDK's version.

## 2026-10-13 — the deep-agent page claims a custom `backend` is rejected; it is not

- **Docs say** (`/build/build-deep-agent.md`, "Security Validations", checked 2026-10-13):
  "Supplying a custom backend bypasses the platform's sandbox and the platform rejects the
  backend."
- **Observed** (SDK 0.11.8, `runtime.py`): `app.deep_agent()` accepts any `backend` passed to
  it and uses it verbatim; `AgentEngineToolPodBackend()` is only substituted when `backend` is
  `None`. The docstring calls this a "Security note", not a rejection. No guard exists.
- **Resolution:** treat the custom-backend path as **working and unaudited**, not blocked. Do
  not rely on the platform to stop you from bypassing its own sandbox. Related, resolving an
  older open contradiction: `AgentEngineToolSandboxBackend` **is**
  `AgentEngineToolPodBackend` — a module-level alias in `backends/tool_sandbox.py`, the same
  class object. Both imports work; the name disagreement is cosmetic.

## 2026-10-13 — a missing `features.deep_agent` fails at run time, not build time

- **Docs say** (`/reference/agent-contract.md`, checked 2026-10-13): calling `app.deep_agent()`
  without `features.deep_agent: true` causes an error **at build time**.
- **Observed** (SDK 0.11.8, `runtime.py`): the `RuntimeError` is raised when `deep_agent()`
  executes — i.e. when the entrypoint runs in the agent sandbox — so a build succeeds and the
  agent fails on first invoke. The message itself is clear and actionable; only the timing
  claim is wrong.
- **Resolution:** do not expect `build` or `validate` to catch a missing `deep_agent` flag.
  Verify the flag is set before deploying, and smoke-invoke after deploy.

## 2026-10-13 — `agent validate` does not enforce the required fields

- **Docs say** (`/reference/agent-contract.md`, checked 2026-10-13): `entrypoint` is required
  and must match `^[\w.]+:[\w]+$`; `sandboxes` is required.
- **Observed** (CLI 0.1.118, minimal standalone manifests): a **missing** `entrypoint` passes.
  A **malformed** one (`not-valid entry!point`) passes — neither the CLI nor the SDK enforces
  the published regex, so it is documentation-only. A missing `sandboxes` block passes.
  Unknown top-level keys and unknown feature flags pass. An unknown *sandbox name* is
  rejected. **A missing egress policy is the only hard failure.**
- **Resolution:** treat a `validate` pass as "the egress policy parses", nothing more. Read
  the diff for typos yourself; see
  [CONFIG_FIELDS.md](CONFIG_FIELDS.md#validation-behavior).

## 2026-10-13 — `project-config.yaml` has a second top-level key, `memory_only`

- **Docs say:** nothing. No doc page and no OpenAPI schema mentions it; the guides present
  `memory:` as the file's only content.
- **Observed** (CLI 0.1.118): `agentengine create --memory-only` writes `memory_only: true`
  at the top level. It drives `dev up` to start only the Orchestration Engine and the memory
  server, and marks the project for stack resolution by `memory configure`. It is not
  uploaded, so the platform never sees it.
- **Resolution:** recognize it in a scaffolded file rather than deleting it as a stray key.
  Effects beyond `dev up` and stack resolution are **unverified**.

## 2026-10-13 — `--open-egress` writes to `agent.yaml`, not `project-config.yaml`

- **Docs say** (`/build/create-project.md`, checked 2026-10-13): `--open-egress` sets
  `network.egress_mode` in `project-config.yaml`.
- **Observed** (CLI 0.1.118): it writes `network.egress_mode: allow_all` into **`agent.yaml`**,
  at the deprecated top level — see
  [the 2026-10-10 scaffold entry](#2026-10-10--the-scaffold-still-writes-the-deprecated-top-level-networkegress).
- **Resolution:** look in `agent.yaml`. Editing `project-config.yaml` to chase this changes
  nothing.

## 2026-10-11 — a per-type extraction prompt exists only in the CLI template

**Status: NOT TESTED.** Treat the key as unconfirmed until the test below passes.

- **Docs say** (`/add-features/memory.md`, checked 2026-10-11): the only extraction control
  is `memory.extraction.enabled`, on or off per type for the whole project. No prompt,
  threshold or filter.
- **Observed** (CLI 0.1.118): the `project-config.yaml` template built into the binary says
  "Each type may also take an optional 'prompt' to override the system default", shown as
  `extraction: { semantic: { prompt: "..." } }`. `agent-engine-sdk-memory` 0.11.8 has no
  delete or update for taxonomic terms, so a generic term, once extracted, stays.
- **Resolution: open.** To test it, run two arms, each with fresh terms:
  1. **Control, no prompt.** Hold a conversation that defines one generic industry term
     and one invented, project-specific term. Wait past `stale_minutes`, then confirm
     both were stored as taxonomic memory. If the generic term isn't stored, the test
     proves nothing.
  2. **With the prompt.** Set `extraction.taxonomic.prompt` to skip general industry
     terms, then run `agentengine memory configure` (does it accept the key?) and
     `agentengine memory apply`. Repeat with a new generic term and a new invented term.
     Pass: only the invented term is stored.

  Extraction is an LLM call, so one run per arm is weak evidence. Update this entry with
  the result.

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
- **Still gated 2026-11-09** (single field report, CLI 0.1.124, memory server 0.11.12): custom
  memory types remain behind a platform flag, while `/add-features/memory.md` still documents
  them (checked 2026-11-12). Do not promise them until a live test succeeds.

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
- **Re-confirmed 2026-10-13** (`service-account create --help`, 0.1.118): `--role` still takes
  `PROJECT_OWNER`, `PROJECT_READ_ONLY`, `AGENT_DEVELOPER` for projects and
  `ORG_GROUP_CREATOR`, `ORG_READ_ONLY` for orgs, with the same stored-name mapping. The doc
  lag above is unchanged.
- **Superseded 2026-11-24:** `AGENT_DEVELOPER` is gone; roles now use Atlas names. See
  [the 2026-11-24 entry](#2026-11-24--service-account-roles-now-use-atlas-names-agent_developer-is-gone).

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
- **Superseded in part 2026-11-12:** the docs now list all four addresses for destinations
  outside Atlas. External services should allowlist all four; see
  [the 2026-11-12 entry](#2026-11-12--the-egress-page-now-lists-all-four-ips-as-one-list).

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

- `deploy --auto` is single-agent only; it rejects `--workspace` and `--all`. (Renamed
  `deploy --build` in 0.1.123; see the 2026-11-24 entry on moved commands.)
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
- **Update 2026-11-12:** the endpoint has a page in the published API reference (first seen 2026-11-12)
  (`https://www.mongodb.com/docs/api/doc/agentengine/operation/operation-get-api-v1-projects-parameter-cost-dashboard`).
  The figures are still **estimates** of provider spend. The guides and the CLI remain silent.

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
- **Superseded 2026-11-24:** the guides now document trace export; see
  [the 2026-11-24 entry](#2026-11-24--trace-export-is-now-documented).

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
- **Resolution:** **the safe `deploy` verbs are `deploy list`, `deploy get <id>` and
  `deploy logs <id>`.** `deploy get <id>` already prints the Conditions block with the failure
  reason; `deploy logs <id>` prints the full event log. `deploy cancel` is the fourth
  subcommand and is mutating. Anything else falls through.
- **Corrected 2026-10-13** (`agentengine deploy --help`, 0.1.118): this entry previously named
  only `list` and `get`, which wrongly pushed `deploy logs` — a documented, read-only
  subcommand — out of the safe set during diagnosis.

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
