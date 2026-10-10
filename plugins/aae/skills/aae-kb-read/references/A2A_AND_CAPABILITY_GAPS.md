---
name: aae-a2a-and-capability-gaps
description: Atlas Agent Engine A2A token and ACL facts, and the confirmed absence of native RAG, evals and scheduling, with what to build on instead. Verified 2026-10-06 to 2026-10-08.
---

# A2A facts and capability gaps

- [Summary](#summary)
- [Why does a long A2A call fail with 401?](#why-does-a-long-a2a-call-fail-with-401)
- [Does AAE have RAG or vector search built in?](#does-aae-have-rag-or-vector-search-built-in)
- [Does AAE have evals?](#does-aae-have-evals)
- [Can AAE run an agent on a schedule?](#can-aae-run-an-agent-on-a-schedule)

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
