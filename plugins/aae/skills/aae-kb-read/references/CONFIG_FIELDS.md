---
name: aae-config-fields
description: Field-by-field reference for agent.yaml and project-config.yaml, merged from the docs, the SDK source, the OpenAPI spec and the CLI validator, with each field's source and what the guides omit. Verified 2026-10-13 on CLI 0.1.118 and SDK 0.11.8.
---

# Config field reference: `agent.yaml` and `project-config.yaml`

- [Summary](#summary)
- [Where each file's truth lives](#where-each-files-truth-lives)
- [Validation behavior](#validation-behavior)
- [`agent.yaml`, single agent](#agentyaml-single-agent)
  - [Identity](#identity)
  - [`features`](#features)
  - [`scaling`](#scaling)
  - [`sandboxes`](#sandboxes)
  - [`network`](#network)
  - [`a2a`](#a2a)
  - [`mcp`](#mcp)
  - [`artifact_repositories`](#artifact_repositories)
  - [Read by the SDK, absent from the docs](#read-by-the-sdk-absent-from-the-docs)
- [`agent.yaml`, monorepo root](#agentyaml-monorepo-root)
- [`project-config.yaml`](#project-configyaml)
  - [Top-level keys](#top-level-keys)
  - [`memory` top level](#memory-top-level)
  - [`memory.voyage`](#memoryvoyage)
  - [`memory.short_term`](#memoryshort_term)
  - [`memory.extraction_llm`](#memoryextraction_llm)
  - [`memory.background_extraction.snapshot`](#memorybackground_extractionsnapshot)
  - [`memory.extraction`](#memoryextraction)
  - [`memory.custom_memory_types`](#memorycustom_memory_types)
  - [`memory.metadata_partition_key` and `metadata_partition_index`](#memorymetadata_partition_key-and-metadata_partition_index)
  - [`memory.capacity` and `memory.tasks`](#memorycapacity-and-memorytasks)
- [What is NOT configurable per agent](#what-is-not-configurable-per-agent)
- [How to refresh this file](#how-to-refresh-this-file)

## Summary

Verified 2026-10-13 on CLI **0.1.118** and SDK **0.11.8**. All four sources were re-read in
full on that date: `agent_config.py` class by class, every `memoryconfig.*` OpenAPI schema,
the five doc pages listed below, and the CLI's own scaffolds plus fresh `agent validate`
probes. No single source lists every field. This file merges four of them and marks where
each field comes from:

- **Docs**: the `agent.yaml` table on `/reference/agent-contract.md`, plus the egress and
  A2A pages.
- **SDK**: `agent_engine_runner_shared/agent_config.py`, the code that reads `agent.yaml` at
  runtime.
- **API**: the OpenAPI schema `memoryconfig.MemoryConfigSchema`. This is the authoritative
  schema for `project-config.yaml`'s `memory:` block; `agentengine memory configure` uploads
  the block to it.
- **CLI**: `agentengine agent validate` and the templates built into the CLI.

The big points:

1. **Unknown keys pass silently.** `agent validate` accepts a misspelled top-level key or
   feature flag, so a typo just does nothing.
2. **`features.memory` is a plain boolean.** It has no sub-settings, so different agents
   can't be given different memory types in config. Control what each agent reads in code.
3. **`project-config.yaml` has more than the guides show.** Per-type extraction prompts,
   metadata partition keys, memory-server replicas and a retry brake exist only in the
   API schema.
4. **`features.durable_workflow` exists only in the SDK source.**
5. **`memory:` is not the only top-level key in `project-config.yaml`.** `memory_only` is a
   second one, written by `agentengine create --memory-only`. It appears in no doc page and
   in no API schema.
6. **`agent validate` enforces one thing hard: an egress policy.** A manifest with no
   `entrypoint` and no `sandboxes` passes, despite the docs marking both required.

## Where each file's truth lives

| File | Most complete source | Read it with |
|---|---|---|
| `agent.yaml` (single agent) | Docs contract table **plus** the SDK's `agent_config.py` (runtime fields) **plus** the egress and A2A pages | `curl -sL https://www.mongodb.com/docs/agentengine/reference/agent-contract.md`; the file in any agent's `.venv/.../agent_engine_runner_shared/` |
| `agent.yaml` (monorepo root) | Docs contract page, "monorepo" section; see [MONOREPO_AND_BUILD.md](MONOREPO_AND_BUILD.md) | same |
| `project-config.yaml` | OpenAPI `components.schemas["memoryconfig.*"]` | `curl -sL --compressed https://www.mongodb.com/docs/api/doc/agentengine.json` |
| `dev.yaml` | Out of scope here; the local-dev docs and the CLI template | — |

## Validation behavior

Re-probed 2026-10-13 with `agentengine agent validate <path>` on minimal manifests
(CLI 0.1.118, read-only):

| Input | Result |
|---|---|
| Unknown top-level key (`bogus_top: 1`) | **Passes** |
| Unknown feature flag (`features.bogus_flag: true`) | **Passes** |
| Unknown sandbox name (`sandboxes.bogus_sandbox`) | Fails: `field bogus_sandbox not found in type agentconfig.SandboxesConfig` |
| Wrong type (`features.memory: {types: [...]}`) | Fails: `cannot unmarshal !!map into bool` |
| `entrypoint` violating the documented regex (`not-valid entry!point`) | **Passes.** The regex is documented but enforced by neither the validator nor the SDK. |
| `entrypoint` and `sandboxes` both absent | **Passes**, though the docs mark both required |
| No egress policy anywhere | Fails: `agent.yaml must declare a network egress policy` |
| Bad egress destination (IP, CIDR, `localhost`, bare `*`, non-leading wildcard) | Fails, per the egress docs |

An egress policy is the only thing the validator insists on, and its error message offers
the deprecated top-level forms (`network.egress_mode`, `network.egress`) alongside
`sandboxes`, so the CLI does not treat them as deprecated.

The SDK reads `features`, `mcp` and `required_secrets` with `extra="ignore"` (unknown keys
dropped) and `a2a` with `extra="forbid"`. A subsection written with no value
(`features:` and nothing under it, likewise `a2a`, `mcp`, `required_secrets`, `connectors`)
is coerced to empty rather than rejected. Run `agent validate` before every deploy, then
read your diff for typos the validator can't see.

## `agent.yaml`, single agent

Source column: **D** docs, **S** SDK source, **C** CLI behavior.

### Identity

| Field | Type | Req. | Default | Notes | Src |
|---|---|---|---|---|---|
| `entrypoint` | string | yes | — | `module.path:attribute`. The docs give regex `^[\w.]+:[\w]+$`, but nothing enforces it: the SDK types the field as an optional non-empty string, and `agent validate` accepts a violating value (tested 2026-10-13). | D |
| `name` | string | no | — | Lowercase alphanumerics and hyphens, no leading or trailing hyphen. In a monorepo, also the workspace name and the A2A discovery name. | D |
| `description` | string | no | — | Up to 500 characters | D |
| `language` | string | no | — | `python` \| `typescript`. In the create-project docs, not the contract table. | S, C |
| `framework` | string | no | — | e.g. `langgraph`, `adk`. Same caveat. | S, C |
| `version` | string | no | — | Not in the contract table. `deploy list` shows it as `VERSION` (e.g. `v0.1.0 (r2)`). | C |
| `agent_card.summary` | string | no | — | Shown in the UI | D |
| `agent_card.capabilities` | list[string] | no | — | Shown in the UI; A2A discovery can filter on them | D |

### `features`

All plain booleans; `null` or omitted means the platform default. Allowlist from the SDK:
`memory`, `guardrails`, `deep_agent`, `playground`, `use_custom_parser`, `durable_workflow`.

| Field | Default | Effect | Src |
|---|---|---|---|
| `memory` | off | Starts the project's memory server for this agent and provides `app.memory`. The runner **writes** every turn (user, assistant and tool messages) automatically at the end of each run and before a human-in-the-loop suspend. It **never reads** automatically; reads happen only where your code calls `app.memory`. Needs `VOYAGE_API_KEY`. No sub-settings. | D, S |
| `guardrails` | off | Enables guardrails integration | D |
| `deep_agent` | off | Required for `app.deep_agent()`; also enables the tool-sandbox filesystem and shell handlers | D, S |
| `playground` | on | `false` skips provisioning the Playground UI (non-chat agents). Read at deploy time only. | D, S |
| `use_custom_parser` | off | Runs the `@app.output_parser` and emits `custom_event` frames. Fails at start if no parser is registered. | D, S |
| `durable_workflow` | off | **Not in the docs.** Opts in to Orchestration Engine-owned durable execution: after a failure, each model and tool call is replayed, instead of resuming from LangGraph's own checkpoints. With `memory` on, turn writes then go through an exactly-once path. CLI 0.1.118 calls `false` LangGraph's "last-resort escape hatch"; ADK has no off-switch. | S, C |

### `scaling`

**Snapshotted at build time: change it, then rebuild.** There is no autoscaling.

| Field | Type | Default | Range | Notes | Src |
|---|---|---|---|---|---|
| `replicas` | int | 4 | 1–512 | Pods per sandbox = maximum concurrent sessions | D |
| `agent_idle_ttl_seconds` | int | 600 | 1–86400 | How long an idle session keeps its agent sandbox | D |
| `tool_idle_ttl_seconds` | int | = agent TTL | 1–86400 | Same, for the tool sandbox | D |

**Docs defect on `agent_idle_ttl_seconds` (live 2026-10-13).** The contract page's row for
this field ends: "`scaling.agent_idle_ttl_seconds` is a legacy alias for this field" — the
field declares itself its own alias. The real legacy name is therefore unknowable from the
docs. If you inherit a manifest with an older TTL key, keep it and test, rather than
assuming this sentence tells you what it was.

### `sandboxes`

Exactly two names are allowed: `agent` (required) and `tool`. A tool assigned to both is
rejected; a tool that matches neither runs in `agent`.

| Field | Type | Notes | Src |
|---|---|---|---|
| `sandboxes.<s>.secrets` | list[string] | Secret names or globs (`*` = all). `MONGODB_URI` is always available. | D |
| `sandboxes.<s>.tools` | list[string] | Tool names or globs. To call an LLM from the tool sandbox, list `invoke_llm` here and the provider key under `sandboxes.tool.secrets`. | D |
| `sandboxes.<s>.network.egress_mode` | enum | `deny_all` (default for a new workspace) \| `allow_list` \| `allow_all`. Omitted with destinations listed means `allow_list`. `allow_all` plus destinations fails validation. | D |
| `sandboxes.<s>.network.egress[].fqdn` | string | Hostname or leading wildcard (`*.x.com`, `*.*.x.com`, `**.x.com`). Rejected: IPs, CIDR, `localhost`, `*.local`, metadata addresses, bare `*`/`**`, non-leading wildcards, more than two `*` labels. | D |
| `sandboxes.<s>.network.egress[].ports` | list[int] | 1–65535, at most 10 per destination. Omitted means all ports, with a warning. At most 50 destinations per workspace. | D |

Egress changes apply at deploy time. `agentengine agent egress add|remove|mode` edits the
file for you. A top-level `network.egress` is the deprecated form; run
`agentengine migrate sandboxes` to move it.

**The CLI's own scaffold still writes the deprecated form** (checked 2026-10-13 on 0.1.118):
`agentengine create` emits a top-level `network.egress` with the chosen LLM host, and
`--open-egress` emits a top-level `network.egress_mode: allow_all`. `agent validate` honors
both and counts the rules. So a freshly created project starts out needing
`agentengine migrate sandboxes`. Note also that the create-project docs describe
`--open-egress` as writing `network.egress_mode` into `project-config.yaml`; it writes it
into `agent.yaml` — `project-config.yaml` has no `network` block.

### `network`

| Field | Type | Notes | Src |
|---|---|---|---|
| `network.atlas_clusters` | list[string] | Atlas cluster hostnames the agent may reach. **Top level, not inside a sandbox.** An Atlas host in `egress` only produces a warning and does not grant access. | D |

### `a2a`

Unknown keys are **rejected** here (`extra="forbid"`).

| Field | Type | Default | Notes | Src |
|---|---|---|---|---|
| `enabled` | bool | `false` | Discoverable and callable. When `false`, the other `a2a` fields are ignored. | D, S |
| `allowed_callers` | list[string] | `[]` | **Workspace IDs**, not names. Empty means any A2A-enabled agent in the project. Whether the Orchestration Engine enforces it is contradicted in the docs (see [DOC_CONTRADICTIONS.md](DOC_CONTRADICTIONS.md)). | D |
| `skills[].name`, `skills[].description` | string | — | Required per skill | D, S |
| `skills[].example_input`, `skills[].example_output` | string | — | Optional | D, S |
| `input_modes`, `output_modes` | list[string] | `[]` | MIME types; discovery filters | D |

### `mcp`

| Field | Type | Default | Notes | Src |
|---|---|---|---|---|
| `mcp.servers.<name>.transport` | enum | `streamable_http` | `streamable_http` only | D, S |
| `.url` | string | — | Endpoint. Must be an absolute `http(s)` URL; `http` is rejected unless `auth.type` is `none`. The **only** field in `agent.yaml` where `${VAR}` is substituted (see below). | D, S |
| `.headers` | map | `{}` | Static headers. The SDK rejects the credential headers `authorization`, `cookie` and `proxy-authorization` — use `auth.token_env` instead. | D, S |
| `.auth.type` | enum | `none` (SDK) | Docs: `bearer_env`, `oauth`, and mark the field **required**. SDK also accepts `none` and `client_credentials`, and defaults to `none`. | D, S |
| `.auth.token_env` | string | — | For `bearer_env`; the variable must be set in `.env` | D, S |
| `.auth.scope`, `.auth.client_name` | string | — | For `oauth` | D, S |
| `.auth.redirect_uri` | string | — | Loopback redirect for interactive OAuth. SDK only. | S |
| `.auth.token_url`, `.auth.client_id_env`, `.auth.client_secret_env` | string | — | For `client_credentials`. SDK only. `token_url` must be an absolute **https** URL. | S |
| `.allowed_tools` | list[string] | all | Fail-closed allowlist of remote tools | D, S |
| `.timeout_seconds` | int | 30 | Per tool call, and for discovery. Must be > 0. | D, S |

An MCP server listed here still needs its hostname in egress.

**Per-type auth field matrix (SDK, `extra="ignore"` but validated).** Each `auth.type`
declares both required and allowed fields, and a field that is merely *unsupported* for the
chosen type is rejected, not ignored:

| `auth.type` | Required | Also allowed |
|---|---|---|
| `none` | — | — |
| `bearer_env` | `token_env` | — |
| `oauth` | — | `redirect_uri`, `client_name`, `scope` |
| `client_credentials` | `client_id_env`, `client_secret_env` | `token_url`, `scope` |

`token_env`, `client_id_env` and `client_secret_env` may not name a platform-owned
environment variable; the SDK rejects it with "Please use a different environment variable
name", so tenant YAML cannot redirect a platform secret to an outbound server.

**`${VAR}` interpolation.** The SDK substitutes `${VAR}` at exactly one allowlisted YAML
path, `mcp.servers.*.url`, from a tenant-owned subset of the environment — never raw
`os.environ`. Everywhere else (prompts included) a literal `${...}` passes through
untouched. Only the braced form is recognised; bare `$name` is left alone so URLs with real
`$` characters survive. A malformed marker (`${VAR` unclosed, `${}`, `${1bad}`,
`${VAR with spaces}`) and an unset variable both raise, naming the YAML path. There is no
escape for a literal `${...}` at that path.

### `artifact_repositories`

Private package registries for managed builds; credentials are injected at build time only.

| Field | Type | Req. | Default | Notes |
|---|---|---|---|---|
| `name` | string | yes | — | `^[a-z][a-z0-9-]*$`, unique. PyPI: must match a `[[tool.uv.index]]` name. |
| `type` | enum | yes | — | `pypi` \| `npm` |
| `secret` | string | yes | — | Secret name, `^[A-Z][A-Z0-9_]{0,127}$` |
| `scope` | enum | no | `project` | `project` \| `workspace` |
| `auth` | enum | no | `token` | `token` \| `basic` |
| `username` | string | when `basic` | `__token__` (PyPI token) | |
| `npm_scope` | string | no | — | e.g. `@acme`; npm only |

When the list is non-empty, `agent validate` also checks the lockfiles beside `agent.yaml`.

### Read by the SDK, absent from the docs

Parsed by `agent_config.py`. Behavior unverified; don't rely on them without a test.

| Field | SDK note |
|---|---|
| `required_secrets.aer` | list[string] |
| `required_secrets.tools` | map tool → secrets. `invoke_llm` is a reserved key, because model calls run in the tool sandbox. |
| `required_secrets.disable_restriction` | "Parsed for compatibility; ignored at enforcement." |
| `connectors[].source` | Path to a connector `tool.yaml`, relative to `agent.yaml` |

The SDK reads nothing else from `agent.yaml`. `name`, `description`, `version`, `scaling`,
`sandboxes`, `network`, `agent_card` and `artifact_repositories` are consumed by the CLI and
the platform at build and deploy time, never by the runtime.

Which file it reads is resolved in a fixed order: an explicit path argument, then
`AGENTIC_AGENT_CONFIG_PATH` (baked into runtime images), then `AGENTIC_AGENT_WORKDIR` (set
by generated local-dev stacks), then the current directory. A missing file is treated as an
empty config rather than an error, so a unit test that constructs `App` outside an agent
directory silently gets defaults.

**No OpenAPI schema describes `agent.yaml`.** The manifest-shaped schemas in the spec
(`main.WorkspaceDTO`, `main.WorkspaceFeatures`, `main.AgentCard`, `main.AgentSkill`) are
server-side projections of a *deployed* workspace, not the authoring contract, and they
lag it: `main.WorkspaceFeatures` carries only `memory`, `guardrails`, `playground` and
`use_custom_parser`, omitting `deep_agent` and `durable_workflow`. Do not read field
coverage for `agent.yaml` out of them.

Deprecated: `services:` (moved to `dev.yaml`) and the flat single-directory project layout.

## `agent.yaml`, monorepo root

A top-level `agents:` list makes the file a monorepo manifest. Each listed directory holds its
own single-agent `agent.yaml`.

| Field | Type | Req. | Notes |
|---|---|---|---|
| `agents[].name` | string | yes | Same rules as `name`; unique in the list |
| `agents[].path` | string | yes | Relative to the repo root, cannot leave it. Also sets the build archive root (see [MONOREPO_AND_BUILD.md](MONOREPO_AND_BUILD.md)). |

## `project-config.yaml`

Project-wide: one memory configuration shared by every agent in the project. Only the
`memory:` block is uploaded (`agentengine memory configure`), and the memory server reads it
only at startup (`agentengine memory apply`). Endpoints:
`GET|PUT /api/v1/projects/{id}/memory/config` and `POST .../memory/config/sync`.

Source column: **A** API schema, **D** docs sample, **C** CLI template.

### Top-level keys

`memory:` is **not** the only one. `agentengine create --memory-only` writes a second key,
and it is absent from every doc page and from the OpenAPI schema.

| Field | Type | Default | Notes | Src |
|---|---|---|---|---|
| `memory` | mapping | — | The only block uploaded by `agentengine memory configure`. Everything in the sections below lives under it. | A, D, C |
| `memory_only` | bool | omitted | **CLI-local, undocumented.** Written as `true` by `agentengine create --memory-only`. Tells `agentengine dev up` to start only the Orchestration Engine and the memory server, with no agent. It is also the "memory-only project marker" that `agentengine memory configure` walks up to when resolving which `project-config.yaml` to upload. Not part of the uploaded document, so the platform never sees it. | C |

No other top-level key appears in either CLI template, in the docs samples, or in the API
schema. In particular there is no project name, version, or defaults block, and no
`network:` block — despite the create-project page saying `--open-egress` writes
`network.egress_mode` here (it writes it to `agent.yaml`).

### `memory` top level

`log_level` is the only scalar directly under `memory:`. Every other member of
`memoryconfig.MemoryConfigSchema` is a nested mapping or list, each covered by a section
below (verified against all eleven properties of that schema, 2026-10-13).

| Field | Type | Notes | Src |
|---|---|---|---|
| `log_level` | enum | `debug` \| `info` \| `warning` \| `error` \| `critical`. Omit for `info`; an empty string is rejected. | A, D |

### `memory.voyage`

| Field | Type | Default | Notes | Src |
|---|---|---|---|---|
| `model` | string | `voyage-4-large` | Embedding model | A, D |
| `dimension` | int | 1024 | Must match the model | A, D |

The key is not set here: it is the project secret `VOYAGE_API_KEY`.

### `memory.short_term`

| Field | Type | Default | Notes | Src |
|---|---|---|---|---|
| `embed_on_write` | bool | `false` | Embed each turn synchronously at write time, so it is searchable by relevance immediately. Adds write latency. | A, D |

### `memory.extraction_llm`

| Field | Type | Notes | Src |
|---|---|---|---|
| `provider` | enum | `openai` \| `anthropic` \| `gemini` \| `cerebras` | A, D |
| `model` | string | Overrides the provider's default model | A, D |
| `base_url` | string | Gateway endpoint. HTTPS (loopback HTTP allowed); embedded credentials rejected. | A, D |
| `api_key_secret` | enum | `LLM_API_KEY` \| `OPENAI_API_KEY` \| `ANTHROPIC_API_KEY` \| `GEMINI_API_KEY` \| `CEREBRAS_API_KEY`. Omit to auto-detect. **No other name is accepted.** | A, D |
| `auth_header` | enum | `authorization` (Bearer) \| `api-key` (Azure-style). Omit for the provider default. | A, D |

### `memory.background_extraction.snapshot`

A snapshot is the chunk of conversation that extraction reads. Defaults are from the docs
sample; the API schema gives types only.

| Field | Type | Default | Notes | Src |
|---|---|---|---|---|
| `max_messages` | int | 20 | Promote a snapshot after this many messages | A, D |
| `stale_minutes` | int | 3 | …or after this much idle time. The docs sample ships `3`, the CLI scaffold ships `1` (both checked 2026-10-13); the API schema gives no default, so which one the server falls back to when the key is omitted is **unverified**. | A, D, C |
| `embed_stm_before_promotion` | bool | `true` | Batch-embed short-term turns before the promotion check | A, D |
| `topic_shift_enabled` | bool | `false` | Exact effect undocumented | A, D |
| `topic_shift_threshold` | number | 0.35 | Used when topic shift is on | A, D |
| `delete_promoted` | bool | `false` | Delete short-term turns once promoted | A, D |
| `ttl_days` | int | 30 | Short-term retention | A, D |

Fewer, larger snapshots mean fewer extraction runs; see
[TOKEN_AND_COST_ACCOUNTING.md](TOKEN_AND_COST_ACCOUNTING.md#how-do-i-limit-what-memory-extraction-costs).

### `memory.extraction`

| Field | Type | Notes | Src |
|---|---|---|---|
| `enabled` | list[enum] | API enum: `semantic`, `episodic`, `taxonomic`, `preferences`, `procedural`. `[]` extracts nothing; **removing the line re-enables all types.** The docs sample and CLI template also list `entity`, which the API enum does not. | A, D, C |
| `semantic.prompt`, `episodic.prompt`, `procedural.prompt`, `taxonomic.prompt`, `preferences.prompt` | string | Per-type override of the extraction prompt. **In the API schema and the CLI template, absent from the guides. Whether it changes what gets extracted is NOT TESTED** (see [DRIFT_LOG.md](DRIFT_LOG.md#2026-10-11--a-per-type-extraction-prompt-exists-only-in-the-cli-template)). | A, C |

An application can still save any built-in type through the SDK when its extraction is off.

### `memory.custom_memory_types`

At most 5. **Create-only**: an accepted declaration can't be edited or removed; declare a new
name instead. Switched off on the live platform as of 2026-10-10, so declaring one rejects the
whole upload (see [DRIFT_LOG.md](DRIFT_LOG.md#2026-10-10--custom-memory-types-are-rejected-by-the-live-platform)).
Not available in local dev.

| Field | Type | Notes | Src |
|---|---|---|---|
| `name` | string | Starts lowercase; lowercase, digits, `_`; at most 64 characters; not a built-in name | A, D |
| `collection` | string | Target collection | A, D |
| `tags[].name` | string | Up to 10 filterable tag keys; one level of dot nesting | A, D |

### `memory.metadata_partition_key` and `metadata_partition_index`

**API schema only; untested.** These look like the platform's way to filter memory by a
metadata attribute, which is one possible route to per-agent or per-tenant separation.

| Field | Type | Notes |
|---|---|---|
| `metadata_partition_key[].name`, `.type` | string | At most 10. Filterable metadata attributes indexed by semantic, episodic, procedural and short-term memory. **Not taxonomic.** **Create-only:** keys can be added but never removed or retyped. |
| `metadata_partition_index.<type>` | list[string] | Which search index carries the partition fields, per memory type: `vector`, `text` or both. Omitted means vector only. Freely mutable; affects newly provisioned indexes only. |

Because the key is permanent, test it in a scratch project first.

### `memory.capacity` and `memory.tasks`

**API schema only.**

| Field | Type | Notes |
|---|---|---|
| `capacity.min_replicas`, `capacity.max_replicas` | int | Replica count of the project's memory server. Infrastructure only. |
| `tasks.legacy_retry` | bool | Default `false`. An emergency brake: reverts failed background tasks to three retries, then dead-letter. Enabling it can terminate a backlog of retries at once. |

## What is NOT configurable per agent

| Want | Status |
|---|---|
| Give one agent only some memory types | Not in config. `features.memory` is all or nothing. Restrict reads in your code (`enabled_sources`, or the per-type search calls). |
| Stop one agent's turns from being extracted, but keep its reads | Not available. Turning `memory` off removes `app.memory` too. |
| A different extraction type list or prompt per agent | Not available; `project-config.yaml` is project-wide. |
| Filter reads by agent | No `agent_id` filter on the search methods. Turns are tagged with the workspace ID; whether that tag survives extraction is untested. `metadata_partition_key` may be the lever; also untested. |

## How to refresh this file

1. `agentengine agent validate --help` and `agentengine memory configure --help` on the
   installed CLI.
2. Re-dump the API schema: `components.schemas` entries starting `memoryconfig.` in the
   OpenAPI JSON.
3. Diff `agent_config.py` in a fresh agent `.venv` against the SDK version above.
4. Re-read `/reference/agent-contract.md` and `/add-features/memory.md`.
5. Scaffold throwaway projects and diff the templates: `agentengine create --memory-only`
   and `agentengine create --open-egress` each emit keys the other scaffold does not.
6. Update the date in the description and the summary, and say which sources you actually
   re-read if it was not all four.
