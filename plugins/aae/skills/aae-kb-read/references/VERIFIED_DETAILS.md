---
name: aae-verified-details
description: Doc- and spec-verified Atlas Agent Engine facts that the guides omit or bury, each dated.
---

# AAE verified details

- [Summary](#summary)
- [Where is the freshest description of the platform?](#where-is-the-freshest-description-of-the-platform)
- [Limits beyond the card](#limits-beyond-the-card)
- [Where does the runtime run, and can I choose a region?](#where-does-the-runtime-run-and-can-i-choose-a-region)
- [OTLP trace export exists in the API](#otlp-trace-export-exists-in-the-api)
- [Policy Engine: seven policy types](#policy-engine-seven-policy-types)
- [Where are policies and guardrails authored?](#where-are-policies-and-guardrails-authored)
- [The `a2a:` block is not the A2A wire protocol](#the-a2a-block-is-not-the-a2a-wire-protocol)
- [Stream chunks change when guardrails are on](#stream-chunks-change-when-guardrails-are-on)
- [Memory scoping and config keys the card omits](#memory-scoping-and-config-keys-the-card-omits)
- [What does the memory service trust, keep and drop?](#what-does-the-memory-service-trust-keep-and-drop)
- [Which memory recall calls inherit the session, and what does app-bound mode refuse?](#which-memory-recall-calls-inherit-the-session-and-what-does-app-bound-mode-refuse)
- [Where does the Voyage key for memory come from?](#where-does-the-voyage-key-for-memory-come-from)
- [The `A2A_JWT_SECRET` project secret](#the-a2a_jwt_secret-project-secret)
- [Creation paths: what the CLI can and cannot create](#creation-paths-what-the-cli-can-and-cannot-create)
- [SDK packages: where they are published](#sdk-packages-where-they-are-published)
- [Which doc pages does this knowledge base only point to?](#which-doc-pages-does-this-knowledge-base-only-point-to)

## Summary

Facts verified against the docs, the OpenAPI spec, or `--help`, each dated. The biggest
lessons: the **OpenAPI spec is the most complete source** (trace export and cost endpoints
exist there and nowhere else); **Policy Engine has seven types**; AAE's `a2a:` block is
**MongoDB's own RPC, not the open A2A protocol**; and **memory has no per-agent scope**.

## Where is the freshest description of the platform?

Verified 2026-10-08.

- **OpenAPI spec:** `https://www.mongodb.com/docs/api/doc/agentengine.json` (or `.yaml`).
  133 paths, contract `2026-09-20-preview`. It is well ahead of the guides. Fetch it with
  `curl -sL --compressed`; the server gzips regardless of extension, and without
  `--compressed` you get binary.
- **Rendered API reference:** `https://www.mongodb.com/docs/api/doc/agentengine`.
- The `https://dochub.mongodb.org/core/agentic-platform-api` link in the guides redirected to
  a non-public staging host on 2026-10-05; on 2026-11-24 it redirects to the public
  `https://www.mongodb.com/docs/api/doc/agentengine/`. Link that URL directly.
- **Pin the API contract** per request with `Accept: application/vnd.agent-engine-<VERSION>+json`
  (streaming: `Accept: text/event-stream, application/vnd.agent-engine-<VERSION>+json`). The
  only version is `2026-09-20-preview`; an unknown one returns `406 UNSUPPORTED_API_VERSION`.
  Unpinned requests get the latest contract. The OAuth token, MCP, health and login routes
  ignore the header. Source: `/reference/limitations.md`, "Pin an API Contract" (2026-11-24).
- **Page inventory:** `https://www.mongodb.com/docs/agentengine/llms.txt` lists every guide
  page as a `.md` URL.
- Make the OpenAPI JSON the first stop for "does AAE have an endpoint for X".

## Limits beyond the card

Verified against `/reference/limitations.md` on 2026-10-04.

- `scaling.agent_idle_ttl_seconds` and `scaling.tool_idle_ttl_seconds` release sandboxes
  sooner when you cannot reuse session IDs.
- **The 512-sandbox ceiling is per Orchestration Engine, so per project.** The
  `scaling.replicas` of every agent in the project count toward the same 512. The documented
  workaround is spreading agents across projects.
- Session ID: 1 to 128 characters, `[A-Za-z0-9_-]`. Passed as `--session` or `X-Session-ID`.
- Orchestration Engine compute: 0.5 vCPU / 512 MB (the agent sandbox is 0.5 vCPU / 2 GB).
- Per org: 100 org service accounts. Per project: 100 API keys, 100 credential providers,
  100 project service accounts.
- The limitations page says **nothing** about PrivateLink, private endpoints or VPC peering.

## Where does the runtime run, and can I choose a region?

As of 2026-11-12. **Today, in AWS `us-east-1` only, and no, you cannot choose.** No guide
page states the runtime region; this rests on a product-team statement (2026-11-06) plus one
live signal.

- The platform's own egress endpoint labels the Atlas-lane addresses `aws/us-east-1`
  (`GET https://agentengine.mongodb.com/api/v1/platform/egress-ips`, fetched 2026-11-12).
  No doc, CLI flag or `agent.yaml` key selects a runtime region or cloud.
- Your **Atlas cluster** can live in any region or cloud (`AGENTENGINE_ATLAS_CLUSTER_REGION`
  only picks where `atlas setup` creates one). Everything durable — checkpoints, memory, your
  data — lives in that cluster, so placing it elsewhere works today at a cross-region latency
  cost on every call. No runtime region-migration path is documented.
- So the honest data-residency answer is: data at rest can sit where your cluster sits;
  compute, and the data in flight through it, is in `us-east-1`.
- **Do not move a linked Atlas project to another Atlas organization.** It breaks Agent Engine
  for that project and is unsupported (product-team statement, 2026-11-05); see
  [IDENTITY_ATLAS_AND_AUTH.md](IDENTITY_ATLAS_AND_AUTH.md#can-i-move-a-linked-project-to-another-org).

## OTLP trace export exists in the API

Verified 2026-10-08 against the OpenAPI spec. **Documented since 2026-11-18** in
`/manage/inspect-traces.md` ("Export Traces to Arize": Arize preset or "Custom (no preset)",
`HTTP/protobuf` only, set up from the Traces page; full content only, as "metadata-only
redaction is not yet available"). Still no CLI command (0.1.126, 2026-11-24).

- `GET|PUT /api/v1/projects/{id}/trace-export/config`. Fields: `enabled`; `endpoint` (your
  OTLP/HTTP collector, must be https, no loopback or internal addresses); `protocol`
  (**`http/protobuf` only** in v1); `headers` (non-secret only); `headers_secret_ref` (a
  reference to a stored project secret; raw values are never accepted or returned);
  `resource_attributes`; `sampling_policy`; `insecure_skip_verify`; and two enums:
  - `content_mode`: `metadata_only` (default) or `full`, i.e. span payload redaction.
  - `egress_mode`: `platform_only` (default), `platform_and_customer_mirror`, or `customer_only`.
- `GET /api/v1/projects/{id}/trace-export/presets`: a vendor-neutral preset catalog filled at
  runtime. No vendor names appear in the spec, so **do not promise a named observability
  vendor preset without calling the endpoint.**
- `GET /api/v1/projects/{id}/traces?session_id=…[&workspace_id=…]`: **`session_id` is
  required**. There is no "list all traces"; enumerate sessions first with
  `GET /api/v1/projects/{id}/sessions`.
- How to say it (updated 2026-11-24): "trace export over OTLP/HTTP is documented in the
  Traces guide and scriptable through the API". The API's `content_mode` default is
  `metadata_only`, but the guide says only full-content export is available today.
- **Observed 2026-10-22 (CLI 0.1.120):** the live preset catalog held exactly one preset, Arize
  (`https://otlp.arize.com/v1/traces`). Any other vendor means a generic OTLP endpoint, untested.
- **What export means for data** (product-team statements 2026-11-09/10; the full-content
  requirement is in the guide since 2026-11-18). An eval or observability tool is useful only with
  `content_mode: full`, which sends **prompts, completions and tool payloads** to that vendor:
  get the data owner's sign-off first. Delivery is asynchronous and **best-effort**: confirm
  spans actually arrive before relying on them. AAE runs no evaluations itself; export is how
  evals are bolted on. Only new runs are exported, not history.

## Policy Engine: seven policy types

Verified 2026-10-05 against `/manage/governance/policy-engine.md`.

- Types: `AUTHORIZED_TOOLS`, `AUTHORIZED_MODELS`, `MAX_TOOL_CALLS_PER_EXECUTION`,
  `MAX_LLM_CALLS_PER_EXECUTION`, `MAX_EXECUTION_DURATION_MS`, `MAX_TOKENS_PER_EXECUTION`,
  `MAX_TOKENS_PER_SESSION`.
- Org and project scopes merge: allowlists intersect, numeric caps take the lower value.
- Endpoints: `POST /api/v1/organizations/{orgId}/policies/preview`,
  `GET /api/v1/projects/{projectId}/policies/effective`,
  `GET /api/v1/organizations/{orgId}/policies/rollout`.
- A denial returns `error_code: policy_denied`.
- **A child agent called over A2A inherits the parent's root session**, so delegated calls
  share one `MAX_TOKENS_PER_SESSION` budget.
- No policy type governs which agents may be *called*. `a2a.allowed_callers` (static YAML in
  the callee) is inbound-only.
- Unverified: whether `invoke_a2a_agent` is matched by `AUTHORIZED_TOOLS`.

## Where are policies and guardrails authored?

**In the console or over REST. There is no code path, and no CLI path.** Verified 2026-10-13
on CLI 0.1.118: there is no `policy` and no `guardrail` command group (`agentengine policy` and
`agentengine guardrail` both return `unknown command`), and no key in `agent.yaml` or
`project-config.yaml` declares either. `features.guardrails` is only an on/off switch for the
agent.

- **Policies** are authored at **org or project** scope, and merge most-restrictively
  (allowlists intersect, numeric caps take the lower value). Types are listed in the section
  above.
- **Guardrails** are project-scoped. The only type is `output_validation`, whose rules are
  regexes under `config.match_patterns`; actions rank `block` > `require_review` > `modify` >
  `log_only`.
- **For GitOps, script the REST API rather than looking for a config file:**
  `GET|PUT /api/v1/projects/{id}/policies`, `/policies/effective`,
  `POST /api/v1/organizations/{orgId}/policies/preview` — a dry run that names the projects
  whose effective allowlist would become empty, worth running before narrowing an org
  allowlist — and `/policies/rollout`.
- **Timing:** policy changes take about a minute to propagate and each execution snapshots
  policy at start, so a cap can be overshot by one call. Guardrail changes apply from the next
  execution.

**The expectation to head off:** that governance should be declarative beside the agent. The
separation is deliberate — these are admin-plane controls set *over* the developer, so editing
`agent.yaml` cannot relax them.

## The `a2a:` block is not the A2A wire protocol

Verified 2026-10-05 against `/add-features/agent-to-agent.md`.

- The product page says AAE is "built on open standards like MCP and A2A".
- The `a2a:` block is MongoDB's own Orchestration-Engine-brokered RPC over private
  `/a2a/discover` and `/a2a/invoke` endpoints, with a proprietary 5-minute JWT, and
  **same-project only** ("cross-project routing is not yet implemented").
- Absent: a JSON-RPC or gRPC binding, `/.well-known/agent-card.json`, an `A2A-Version` header,
  the protocol's full task-state set. AAE exposes only `completed`, `failed` and
  `input-required`. The vocabulary (skills, input modes, "AgentCard") is borrowed; conformance
  is not.
- **Do not tell anyone AAE "speaks A2A".** The MCP half of the claim is concretely true
  (`mcp.servers.<name>.transport: streamable_http`). Talking to an external A2A agent needs a
  bridge you build: a `@app.tool()`-wrapped client plus an egress entry.
- The `a2a:` keys are documented in the A2A guide but **absent from the agent-contract schema
  table** (as of 2026-10-05). So are `features.durable_workflow` (written by the 0.1.118
  scaffold) and `network.egress_mode`. Treat the A2A guide as authoritative for `a2a:`.
  Known feature flags also include `features.guardrails` and `features.deep_agent`.

## Stream chunks change when guardrails are on

Verified 2026-10-05 against `/deploy/invoke-agent.md`, chunk-types table.
`subagent_start` and `subagent_end` chunks are emitted **only when guardrails are disabled**.
Turning on `features.guardrails` changes the `invokeStream` frame mix. This matters for any
UI that renders subagent nodes from the stream.

## Memory scoping and config keys the card omits

Verified 2026-10-08 against `/add-features/memory.md`, `/memory-types.md`, and the API
reference.

- Memory is configured **per project**. All agents in a project share one memory service,
  store and settings. Per agent there is only `features.memory` on/off. No agent or workspace
  namespace exists. Treat per-agent isolation as **not** a platform feature.
- Scopes: private (user identity) for semantic, episodic and procedural; project-wide for
  taxonomic.
- No delete endpoint is listed among the public REST memory operations.
- **The CLI cannot read, edit or delete memories.** `agentengine memory` has exactly three
  subcommands — `configure`, `apply`, `status` (0.1.118, re-checked 2026-10-13) — and all
  three manage the memory *service*, not its contents.
- **The Atlas collections are storage, not an edit surface.** The memory store is visible in
  Data Explorer or Compass as the database `mdb_memory_<project_id>`, so you can read what was
  stored. Editing a document's text there bypasses the memory service, which leaves the stored
  embedding describing the **old** text, so search keeps matching the thing you just changed.
  Combined with the missing delete endpoint and the SDK's delete-procedural-only support, there
  is no safe documented way to correct or bulk-remove a user's memories.
- Config keys beyond the card: `short_term.embed_on_write`;
  `background_extraction.snapshot.{max_messages: 20, stale_minutes: 3, embed_stm_before_promotion,
  topic_shift_enabled, topic_shift_threshold: 0.35, delete_promoted: false, ttl_days: 30}`;
  `extraction_llm.{provider, model, base_url, api_key_secret, auth_header}`.
- The memory-extraction LLM accepts its key as `LLM_API_KEY` or a provider-named secret. If
  your agents use a differently named key, memory extraction will not find it.
- TypeScript memory client: `@mongodb-js/agent-engine-sdk-memory`.
- CLI 0.1.118 has `agentengine memory status`. `memory configure --help` shows no
  deprecation, although the docs say it will be removed.
- Custom memory types: see the 2026-10-10 entry in [DRIFT_LOG.md](DRIFT_LOG.md).
- Undocumented and **untested**: a per-type `extraction.<type>.prompt`, mentioned only in
  the CLI 0.1.118 template. See the 2026-10-11 entry in [DRIFT_LOG.md](DRIFT_LOG.md). To limit
  extraction cost, see [TOKEN_AND_COST_ACCOUNTING.md](TOKEN_AND_COST_ACCOUNTING.md#how-do-i-limit-what-memory-extraction-costs).

## What does the memory service trust, keep and drop?

*Field observations, 2026-11-09, on CLI 0.1.124, memory server 0.11.12 and
`agent-engine-sdk-memory` 0.11.11. One reporter, not confirmed in the docs; re-test before
relying on any of them.*

- **It trusts the `user_id` the caller sends.** The memory MCP server and REST API take
  `user_id` from the request; a search over MCP **without** a `user_id` returned other users'
  memories. Identity enforcement is the calling application's job. This matters most for the
  card's standard workaround for the service-account identity collapse (call the memory
  service directly with explicit `user_id`): that moves enforcement into your code, so never
  let an end user choose the `user_id`, and do not expose the memory MCP server to anything
  that is not already trusted.
- **No delete and no TTL for long-term memories found** in the MCP server, the REST API or the
  SDK (the SDK's procedural-only delete aside). **Conflicting statement:** a product-team
  answer (2026-11-11) says memories can be deleted manually, without naming the surface. Until
  someone shows the delete call, treat deletion as unconfirmed: do not promise it, and do not
  deny it outright. Nothing documented expires long-term memories (the `ttl_days` key applies
  to short-term snapshots). The fallback correction path is deleting the documents in your own
  cluster, with the embedding caveat above. Plan retention and right-to-erasure handling before
  storing personal data.
- **No review step.** Extracted memories are stored directly; there is no pending or approval
  state, and no end-user editing.
- `build_context_from_sources` accepts memory types only, not arbitrary sources.
- Taxonomic extraction never produced a record on the hosted service in that test.
- Local-mode extraction hard-codes `max_tokens=2000`, which can truncate the extraction JSON.
- A non-default `MONGOMEM_DB_NAME` was ignored by the extraction workers.
- Custom memory types are still gated off, although `/add-features/memory.md` documents them
  (checked 2026-11-12); see the 2026-10-10 entry in [DRIFT_LOG.md](DRIFT_LOG.md).

## Which memory recall calls inherit the session, and what does app-bound mode refuse?

Verified 2026-11-24 against the memory SDK API reference (`agent-engine-sdk-memory`,
`docs/api/memory.md` and `docs/capability-matrix.md`). First recorded 2026-10-23.

- **Episodes are stored without a session.** `search_episodes(query, user_id=None,
  visibility=None, session_id=None, top_k=50)` does not inherit a bound or ambient
  `session_id`; pass one to filter to a single conversation. It takes no `metadata_filter`.
  `session_id` scopes only conversation I/O (`record_turn` and the short-term leg of
  `build_context`).
- **Passing `visibility`** (for example `"org"`) stops the ambient user being substituted for
  `user_id`; supply one if you still want a user filter.
- **`metadata_filter`** exists on `build_context`, `build_context_from_sources` and
  `discover_procedures`. Keys are full index paths (`{"metadata.tier": "gold"}`) for attributes
  declared in the project's metadata partition configuration.
- **App-bound mode** (the pre-wired `app.memory` in a deployed agent) raises
  `MemoryNotSupportedError` for `build_context(format_style=…)` and `include_memories=True`;
  both work only against the hosted and local HTTP services. It also refuses per-turn
  tool-call metadata on `record_turn`.
- **Recall is your code's job.** The LangGraph adapter never calls `build_context` for you
  (SDK 0.11.10, 2026-10-24). A worked example with explicit recall and save tools is the
  `insurance-agent` template in `mongodb/agent-engine-examples`.

## Where does the Voyage key for memory come from?

Verified 2026-10-10 against the docs and CLI 0.1.118 `--help`.

- It is an Atlas **model API key**, created in the Atlas UI: project → Services →
  **AI Model APIs** → Model API Keys → Create model API key. Shown once. It authenticates
  against `ai.mongodb.com`, not `api.voyageai.com`.
- Roles to create one: at project level **Project Owner** or **Project Model Owner**; at org
  level Organization Owner (the key must be linked to a project). This is plain Atlas RBAC:
  Organization Owner **is** honored here, unlike for AAE agent management.
- Cloud/geography `any` means unscoped. Scoped keys need a paid Voyage tier. Whether AAE
  memory accepts geo-scoped keys is unverified; use an unscoped key.
- Store it with `agentengine secret set VOYAGE_API_KEY --project-scope` (`--stdin` to pipe),
  or `agentengine atlas voyage-api-key list|save`, which uses the Atlas service-account
  profile and writes `VOYAGE_API_KEY` as a project secret itself.
- The AAE console's Memory page has no key-creation control and shows "Memory isn't
  configured yet" until `memory configure` and a deploy.

## The `A2A_JWT_SECRET` project secret

Observed 2026-10-04 to 2026-10-10.

- After the first cloud deploy in a project, an `A2A_JWT_SECRET` project secret appears
  without anyone creating it. It is the key the Orchestration Engine uses to sign and verify
  the short-lived A2A JWTs (agent-to-agent calls and agent registration at startup).
- Local `dev up` does **not** create it. For local A2A, put the same value in every
  participating agent's `.env`; the public docs cover only this local case.
- It is one symmetric key per project, stable across deploys. **Do not delete or overwrite
  it**; without it A2A discovery comes back empty and the A2A endpoints fail.
- It is readable like any project secret. That reinforces the isolation rule: the
  Orchestration Engine does not authenticate agents to each other, so use separate projects
  when agents must not trust each other.

## Creation paths: what the CLI can and cannot create

Verified 2026-10-05 against the docs and `--help`.

| Thing | How it can be created |
|---|---|
| **Organization** | Atlas UI (Atlas-backed orgs) · the AAE console (non-Atlas-backed) · the interactive "Create a new organization…" choice inside `agentengine init` |
| **Project** | Same three paths as an organization |
| **Workspace** | `agentengine init` (registers the agent dir) · `agentengine workspace create` · `POST /api/v1/projects/{project_id}/workspaces` |
| **Orchestration Engine** | **No creation path in any interface.** It is provisioned with the project, as the tenant environment `te-<project_id>`. Never tell anyone to "create an OE". |

- `agentengine organization` and `agentengine project` are **list/get only**. Creating
  either from the CLI exists only inside `init`'s interactive flow, which makes scripting it
  impossible.
- The workspace commands are a thin wrapper over the platform API: `GET`/`POST`
  `/api/v1/projects/{id}/workspaces`, `GET`/`PATCH`/`DELETE` `.../{workspace_id}`.
  Service-account auth: `POST /api/v1/oauth/token`.
- `init` does not always create a workspace: `--workspace-id` links an existing one, an
  existing `.agentengine/state.json` makes it skip registration, and a name collision on the
  platform reuses the existing workspace.
- The docs name "the Atlas Agent Engine UI" without giving a URL. In practice:
  `https://agentengine.mongodb.com/project/<project_id>/workspaces/<workspace_id>/deployments`.

## SDK packages: where they are published

Verified 2026-10-05, updated 2026-10-10 and 2026-11-24.

- The packages are named `agent-engine-sdk-*` (`agent-engine-sdk`, `-sdk-adk`,
  `-sdk-langgraph`, `-sdk-memory`, `agent-engine-runner-shared`).
- They are on a **token-gated private index**
  (`https://ignore:$ACCESS_TOKEN@agentengine.mongodb.com/api/v1/packages/python/simple`;
  `ignore` is a placeholder user, the service-account access token is the password) **and on
  public PyPI**: 0.11.7 on 2026-10-05, 0.11.8 on 2026-10-10.
- TypeScript names listed in `llms.txt` (2026-10-06): `@mongodb-js/agent-engine-sdk-langgraph`,
  `-sdk`, `-runner-shared`, `-sdk-memory`. Confirmed on npm 2026-11-24.
- **Re-checked 2026-11-24:** every Python package, plus the new
  `agent-engine-sdk-openai-agents` (Python only, no npm package), is **0.11.15** on PyPI
  (2026-11-19), and the four npm packages are 0.11.15 too. The SDK reference (`/sdk/python.md`)
  calls `agent-engine-sdk` and `agent-engine-runner-shared` internal core packages that
  "agents don't install or import directly", although `create-project` still runs
  `uv add agent-engine-runner-shared …` and helpers such as `get_current_custom_headers` are
  imported from it.
- Install trap (Python 3.14 resolves a placeholder): see [SDK_ADAPTERS.md](SDK_ADAPTERS.md).

## Which doc pages does this knowledge base only point to?

Pages with no deeper entry here, each checked 2026-11-24. Read the page itself; append `.md`.

- `/add-features/openapi-tools/`: turns an OpenAPI 3.0 document into connector tools with
  `agentengine agent create-tool` (experimental). One base URL for every operation; 30-second
  timeout per call; responses over 200,000 bytes are truncated. The page lists OAuth token
  acquisition as out of scope, but 0.1.126 `--help` offers `--provider` (a project OAuth app):
  trust `--help`.
- `/add-features/remote-mcp/`: bearer-token or OAuth 2.1 MCP servers. **OAuth works only in
  local development** (`agentengine dev mcp auth login` before `dev up`); deployed agents do
  not support it.
- `/add-features/memory-extraction/`: the four extraction stages, and reconciliation of each
  new memory as `ADD`, `UPDATE` (the old version is kept, marked superseded) or `REINFORCE`.
- `/build/build-adk-agent/`: the ADK adapter is durable-only; `AgentTool` wrappers and runtime
  `NodeTool` / `run_node()` are rejected before execution, so use configured `sub_agents`.
- `/build/install-authenticate/`: Podman works on Linux and WSL with `podman-docker` and
  `podman-compose` (Docker Compose v2 is still recommended). The CLI sends usage analytics by
  default; opt out with `AGENTENGINE_TELEMETRY_ENABLED=false` (none are sent when `CI` is set).
- `/build/run-local/`: hot-reload versus `--isolated` mode (one container per service, closer
  to production), logs, restarts, new dependencies, private artifact repositories.
- `/deploy/deploy-build/`: `deploy` start, list, status, event log and cancel; build limits of
  10 concurrent and 100 per rolling 24 hours.
- `/manage/monitoring-ui/`: the console's Monitoring page — invocations, errors, tokens,
  memory, policy, compute and networking metrics per project and workspace, over 1h to 30d.
- `/manage/support-access/`: an Organization Admin can grant MongoDB engineers time-bound,
  read-only, org-wide access to sandbox logs and data; it expires on its own and can be
  revoked.
- `/network-egress/atlas-cluster-link/`: the linked cluster is part of the base egress policy
  (reachable in `deny_all` too). Re-run `agentengine atlas setup` to link another cluster;
  one in a different Atlas project needs the Atlas service account to be Project Owner there.
- `/network-egress/egress-get-started/`: a tutorial for per-sandbox `network.egress` and
  `egress_mode`, with common patterns (LLM API in the tool sandbox only, lock down, CLI
  add/remove).
- `/cli/corporate-tls/`: behind TLS-inspecting proxies, `agentengine dev up --ca-bundle
  <root.pem>` (or `AGENTENGINE_CA_BUNDLE` in the process environment, never `.env`) trusts the
  company CA at build and run time.
- **Moving a linked project to another Atlas org:** no page covers it; it breaks Agent Engine
  (product-team statement). See
  [IDENTITY_ATLAS_AND_AUTH.md](IDENTITY_ATLAS_AND_AUTH.md#can-i-move-a-linked-project-to-another-org).
