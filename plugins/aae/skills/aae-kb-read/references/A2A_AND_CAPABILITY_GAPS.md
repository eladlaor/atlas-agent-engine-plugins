---
name: aae-a2a-and-capability-gaps
description: Atlas Agent Engine A2A token and ACL facts, and the confirmed absence of native RAG, evals and scheduling, with what to build on instead. Verified 2026-10-06 to 2026-10-08.
---

# A2A facts and capability gaps

- [Summary](#summary)
- [Why does a long A2A call fail with 401?](#why-does-a-long-a2a-call-fail-with-401)
- [How do I group agents inside one project?](#how-do-i-group-agents-inside-one-project)
- [Does AAE have RAG or vector search built in?](#does-aae-have-rag-or-vector-search-built-in)
- [Does AAE have evals?](#does-aae-have-evals)
- [Can AAE run an agent on a schedule?](#can-aae-run-an-agent-on-a-schedule)
- [Can agent code see its place in an A2A call tree?](#can-agent-code-see-its-place-in-an-a2a-call-tree)

## Summary

- The A2A token lives **5 minutes** and does not refresh; the call timeout caps at **300 s**.
  A long call fails with **401, not a timeout**. A2A is intra-project only.
- **No RAG, no evals, no scheduling** ship with AAE as of 2026-10-08. Each has a known
  build-it-yourself pattern below.

## Why does a long A2A call fail with 401?

Verified 2026-10-08 (CLI 0.1.118).

- The Orchestration Engine injects a short-lived `a2a-token` JWT. A call still in flight past
  5 minutes fails with **401**. Do not diagnose it as a hang.
- `invoke_agent(timeout=...)` defaults to and caps at 300 s, which is no shorter than the
  token's life, so a long call can hit 401 before its timeout.
- A2A is **intra-project only**, and unavailable from the tool sandbox.
- `allowed_callers` in the **callee's** `agent.yaml` is the ACL. Whether the platform enforces
  it is contradicted in the docs; see [DOC_CONTRADICTIONS.md](DOC_CONTRADICTIONS.md#7-is-allowed_callers-enforced).
- The `a2a:` block is MongoDB's own RPC, not the open A2A protocol; see
  [VERIFIED_DETAILS.md](VERIFIED_DETAILS.md#the-a2a-block-is-not-the-a2a-wire-protocol).

## How do I group agents inside one project?

**There is no grouping feature.** The hierarchy is organization → project → workspace, with
one workspace per agent and nothing in between (verified 2026-10-08 against
`/manage/project-org-workspace/` and `/add-features/agent-to-agent/`). A "group" exists only as
your own convention, assembled from three pieces of which just one is enforced:

| Piece | What it does | Enforced |
|---|---|---|
| `a2a.allowed_callers` in the callee's `agent.yaml` | Allowlist of **workspace IDs** that may call this agent; others get `403` and do not see it in discovery | Claimed by the A2A page, contradicted by the limitations page — see [DOC_CONTRADICTIONS.md](DOC_CONTRADICTIONS.md#7-is-allowed_callers-enforced) |
| Capability tags on the agent card (`agent_card.capabilities`) | A caller can discover only agents carrying a given tag | No — it filters discovery results, nothing more |
| A workspace naming prefix | Readability | No |

Three problems to solve before relying on it:

1. **`allowed_callers` holds workspace IDs, not names.** Every fresh deployment of the same
   repo into a different project gets different IDs, so a list committed to `agent.yaml` is
   correct in exactly one project. Fill it in per project at deploy time.
2. **It is not a security boundary.** Until the doc contradiction above is settled by a test,
   treat it as access control between agents you own, not as protection from a hostile one.
   For real isolation, separate projects.
3. **A group cannot own resources.** A secret scopes to the project or to one workspace; there
   is no scope covering a set of workspaces. The same holds for egress and memory, which are
   per workspace and per project respectively.

**The mistake to avoid:** looking for a "sub-project" setting.

## Does AAE have RAG or vector search built in?

No. The only embedding-backed feature is long-term **memory** (conversational, Voyage-powered).
**It is not a corpus retrieval tool**; do not pitch it as RAG.

Corpus retrieval is a plain `@app.tool()` that runs `$vectorSearch` against your Atlas cluster.
There is no managed index, ingest or chunking layer. If the user has no multi-step reasoning,
tools or durable memory need, a plain app against Atlas Vector Search is cheaper than AAE.

## Does AAE have evals?

No. Re-verified 2026-10-08 with four independent checks, all negative:

1. **CLI 0.1.118:** `test`, `eval`, `evals`, `evaluate`, `dataset`, `golden`, `benchmark` all
   return `unknown command`. Nothing eval-shaped under `dev`.
2. **Docs inventory** (`https://www.mongodb.com/docs/agentengine/llms.txt`): no evaluation
   page. "Test Your Agent" (`/deploy/test.md`) is manual: drive the Playground, read the
   responses, resend by hand.
3. **Config schema:** no `agent.yaml` or `project-config.yaml` field references a test, eval,
   dataset or fixture path.
4. **OpenAPI spec:** no evaluation endpoints. "evaluate" appears only in feature-flag paths.

What to build on instead (all verified 2026-10-08):

- Drive cases with `agentengine invoke --session … --json`.
- Read outputs and step data from `GET /api/v1/projects/{id}/sessions/{sid}/runs`,
  `/traces?session_id=…`, `/node-executions`, `/executions/{id}`.
- Score offline from `agentengine logs --session-id … --json` and `logs export` (24 h window,
  gzipped JSON Lines).
- Mirror spans into an external eval or observability tool with the API's OTLP trace export.
- Unit-test in-process with the SDK's test harness ([SDK_ADAPTERS.md](SDK_ADAPTERS.md#how-do-i-unit-test-an-agent-without-deploying-it)).

A `tests/golden/*.yaml` layout, or any similar convention, is entirely the user's own. Never
imply AAE knows what the directory is.

## Can AAE run an agent on a schedule?

Not natively (checked 2026-10-06). The pattern is an external scheduler that:

1. Mints a token: `POST https://agentengine.mongodb.com/api/v1/oauth/token` with a service
   account (1 h token; calling too often returns 429, so cache it).
2. Calls `POST /api/v1/projects/<project_id>/workspaces/<workspace_id>/invoke`.

Any scheduler works (a cloud function on a timer, a CI cron). Check that the scheduler may hold
the service-account secret before choosing it. Reuse a session ID per job so each run does not
reserve a fresh sandbox pair.

## Can agent code see its place in an A2A call tree?

Barely, and three distinct things get confused here. Checked against the live docs and SDK
0.11.8, 2026-10-13.

- **`parent_execution_id` and `root_session_id` have no documented SDK accessor.** Both are
  documented as platform linkage — the child execution points at its caller, the root session
  groups the whole cross-agent tree under the originating user session — and both appear in
  traces and on `ExecutionLog` (see
  [TOKEN_AND_COST_ACCOUNTING.md](TOKEN_AND_COST_ACCOUNTING.md#how-does-an-a2a-fan-out-roll-up)),
  but nothing documented hands them to code running *inside* the agent. The one lineage
  identifier your code definitely holds is `AgentResponse.execution_id`, which the **caller**
  gets back from `invoke_agent()`. Absence of documentation is not proof of absence; probe the
  runtime context before designing around it.
- **Caller identity is reachable, with the right accessor.** `a2a-caller-workspace` is a real
  platform header, and `get_current_custom_headers()` strips every `a2a-*` header — but
  `get_all_custom_headers()` keeps them (see
  [DOC_CONTRADICTIONS.md](DOC_CONTRADICTIONS.md#6-get_current_custom_headers-import-path)).
  Reaching for the wrong one is what makes people conclude the information is unavailable.
- **Whether `custom_headers` propagate transitively is undocumented.** The docs describe
  `custom_headers` only as a per-call parameter of `invoke_agent()`, and say nothing about
  what C receives when A → B → C and B does not re-pass them. **Assume no auto-forwarding and
  re-pass explicitly in every hop.** If the assumption turns out to be wrong you are merely
  redundant; if it is right and one agent forgets, anything you carry in those headers
  truncates silently, with no error. One three-agent deploy settles it: have B call C without
  passing headers, and assert on what C reads.
- **Also undocumented:** whether a callee's work appears inside the caller's trace, or only as
  a separate session in the callee's own workspace.
