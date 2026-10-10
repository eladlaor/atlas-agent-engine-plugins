---
name: aae-verified-details
description: Doc- and spec-verified Atlas Agent Engine facts that the guides omit or bury, each dated.
---

# AAE verified details

- [Summary](#summary)
- [Where is the freshest description of the platform?](#where-is-the-freshest-description-of-the-platform)
- [Limits beyond the card](#limits-beyond-the-card)
- [OTLP trace export exists in the API](#otlp-trace-export-exists-in-the-api)
- [Policy Engine: seven policy types](#policy-engine-seven-policy-types)
- [The `a2a:` block is not the A2A wire protocol](#the-a2a-block-is-not-the-a2a-wire-protocol)
- [Stream chunks change when guardrails are on](#stream-chunks-change-when-guardrails-are-on)
- [Memory scoping and config keys the card omits](#memory-scoping-and-config-keys-the-card-omits)
- [Where does the Voyage key for memory come from?](#where-does-the-voyage-key-for-memory-come-from)
- [The `A2A_JWT_SECRET` project secret](#the-a2a_jwt_secret-project-secret)
- [Creation paths: what the CLI can and cannot create](#creation-paths-what-the-cli-can-and-cannot-create)
- [SDK packages: where they are published](#sdk-packages-where-they-are-published)

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
  a non-public staging host on 2026-10-05. Use the URLs above instead.
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

## OTLP trace export exists in the API

Verified 2026-10-08 against the OpenAPI spec. Not in any guide, no CLI command.

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
- How to say it: "the API supports OTLP export; the guides don't document it; verify against
  the OpenAPI spec". Expect to need an egress allowance for the collector endpoint.

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

Verified 2026-10-05, updated 2026-10-10.

- The packages are named `agent-engine-sdk-*` (`agent-engine-sdk`, `-sdk-adk`,
  `-sdk-langgraph`, `-sdk-memory`, `agent-engine-runner-shared`).
- They are on a **token-gated private index**
  (`https://ignore:$ACCESS_TOKEN@agentengine.mongodb.com/api/v1/packages/python/simple`;
  `ignore` is a placeholder user, the service-account access token is the password) **and on
  public PyPI**: 0.11.7 on 2026-10-05, 0.11.8 on 2026-10-10.
- TypeScript names listed in `llms.txt` (2026-10-06): `@mongodb-js/agent-engine-sdk-langgraph`,
  `-sdk`, `-runner-shared`, `-sdk-memory`. Confirm on the page before relying on them.
- Install trap (Python 3.14 resolves a placeholder): see [SDK_ADAPTERS.md](SDK_ADAPTERS.md).
