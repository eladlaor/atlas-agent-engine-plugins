---
name: aae-token-and-cost-accounting
description: How Atlas Agent Engine tracks LLM tokens and cost - automatic capture at app.llm(), the cost/dashboard endpoint, gateway pricing gaps, A2A roll-up by root_session_id, and unverified retention. Verified 2026-10-08.
---

# Token and cost accounting

- [Summary](#summary)
- [Do I need to instrument anything?](#do-i-need-to-instrument-anything)
- [What bites people?](#what-bites-people)
- [Which fields exist at which granularity?](#which-fields-exist-at-which-granularity)
- [Where do I read it from?](#where-do-i-read-it-from)
- [How does an A2A fan-out roll up?](#how-does-an-a2a-fan-out-roll-up)
- [Who bills what?](#who-bills-what)
- [How do I keep history before it ages out?](#how-do-i-keep-history-before-it-ages-out)

## Summary

Verified 2026-10-08 against the OpenAPI spec (`https://www.mongodb.com/docs/api/doc/agentengine.json`,
contract `2026-09-20-preview`), four guide pages, and CLI 0.1.118 `--help`. **Schema-verified,
not response-verified**: the endpoints were not called.

1. **It is automatic.** The Orchestration Engine records usage for every LLM call it routes.
2. **There is cost, not just tokens:** `GET /api/v1/projects/{id}/cost/dashboard` returns
   `total_cost_usd`.
3. **A gateway does not blind it.** Capture is at the SDK wrapper, not the vendor SDK.
4. **It is undocumented in the guides and has no CLI.** It lives in the OpenAPI spec and the
   UI. The spec warns endpoints may change without a migration path; pin and re-check.

## Do I need to instrument anything?

No. Every `app.llm(...)` call is routed through the Orchestration Engine
(`/reference/agent-contract.md`), and the LangGraph adapter ships an instrumentor "for
recording LLM and tool calls during execution". Capture is provider-neutral: a custom
`base_url` or an OpenAI-/Anthropic-compatible gateway is counted like a first-party provider.

## What bites people?

1. **Anything outside `app.llm()` is invisible.** No tokens, no cost, no audit, no policy, no
   replay. An agent that builds its own client and calls `.invoke()` directly spends money
   that appears nowhere. Say so when reviewing any agent that constructs a model client.
2. **Tokens are trustworthy; dollars may not be.** The summary carries `unpriced_llm_calls`,
   which implies a price table keyed by model string. *Inference, not documented:* a gateway
   model alias probably lands there, with tokens counted and `cost_usd` zero or absent.
   **Before promising dollar attribution on a gateway, call the endpoint and compare
   `unpriced_llm_calls` with `total_llm_calls`.** If they match, price
   `by_model[].total_tokens` yourself.
3. **Retention is unverified.** The numbers that exist are query windows, not retention
   guarantees: agent logs at most 6 h per query, `logs export` at most 24 h, UI trace filters
   1 h / 24 h / 7 d / 30 d, cost dashboard `period` up to 90 d. Do not infer 90-day retention.

## Which fields exist at which granularity?

- **Per step** (`SessionRunStep`): `prompt_tokens`, `completion_tokens`, `total_tokens`,
  "present only on a settled llm step". **No cached-token or reasoning-token field exists
  anywhere in the spec**; cache-hit accounting is on you.
- **Per run** (`SessionRun`): the same three, absent when the run has no settled LLM step.
- **Per session** (`CheckpointSession`): `total_tokens`, "a lower bound… **excludes
  memory-extraction tokens**".
- **Per step, richest** (`ExecutionLog`, `kind: llm|tool|memory|a2a|guardrail|policy`):
  `prompt_tokens`, `completion_tokens`, **`cost_usd`**, `model`, `span_id`,
  `root_execution_id`, `root_session_id`, `a2a_parent_execution_id`,
  `a2a_caller_workspace_id`, `a2a_target_agent_id/name`. **Summing `ExecutionLog` rows with
  `kind: llm` is the accurate path**; the session total under-reports.
- **Dashboard** (`CostDashboardResponse`): `summary` (`total_prompt_tokens`,
  `total_completion_tokens`, `total_tokens`, `total_cost_usd`, `total_llm_calls`,
  `unpriced_llm_calls`), `by_model[]`, `by_workspace[]` (`total_cost_usd`, `total_tokens`,
  `call_count`, `percentage`), `daily_trend[]`.

## Where do I read it from?

```
GET /api/v1/projects/{id}/cost/dashboard?period=7d|30d|90d[&workspace_id=…]   # tag: Cost
GET /api/v1/projects/{id}/sessions?workspace_id=…&since=…&until=…
GET /api/v1/projects/{id}/sessions/{session_id}/runs                          # steps[] with tokens
GET /api/v1/projects/{id}/execution-logs?session_id=…                         # cost_usd, paginated
GET /api/v1/projects/{id}/traces?session_id=…                                 # session_id REQUIRED
```

- Auth: a service account → `POST /api/v1/oauth/token` (1 h token).
- UI: the Playground traces drawer shows per-step counts; Monitor → Traces has a `Tokens`
  column, and the runs timeline can size bars by tokens. Whether the UI shows the cost
  dashboard is unverified.
- CLI: nothing. No `cost`, `usage`, `trace` or `session` command in 0.1.118.
- **`invoke` and `invokeStream` responses carry no usage block** (`response`, `status`,
  `execution_id`, `error`… only). Per-request accounting needs a follow-up
  `GET …/runs` keyed by the returned execution or session.

## How does an A2A fan-out roll up?

`/add-features/agent-to-agent.md`, Observability: *"The target runs as a child execution
linked to the caller through `parent_execution_id`. A shared `root_session_id` groups the full
cross-agent call tree under the originating user session."*

- One user question → one `root_session_id`, however wide the fan-out. Per-agent attribution
  comes from `by_workspace[]` or `a2a_target_agent_id`; the roll-up from `root_session_id`.
- **It is also a budget lever.** The child inherits the parent's root session, so their
  combined tokens count toward one `MAX_TOKENS_PER_SESSION`. Caveats: a cap can be exceeded by
  one call, a session cap by more under concurrency, and memory-extraction tokens count toward
  neither.

## Who bills what?

AAE bills infrastructure, not your tokens. `cost_usd` and `total_cost_usd` are AAE's
**estimate** of your provider spend, not an AAE invoice line. The provider or gateway bills
the tokens; the Atlas cluster bills separately. **No dollar-denominated budget or alert
exists**: Policy Engine caps are token counts.

## How do I keep history before it ages out?

Export paths: `agentengine logs export --service <agent|tool>` (gzipped JSON Lines, 24 h
window), the REST reads above, and the **OTLP trace export** in the API (see
[VERIFIED_DETAILS.md](VERIFIED_DETAILS.md#otlp-trace-export-exists-in-the-api)), which needs an
egress allowance for the collector.

No official collection template ships. A team that wants history walks `sessions → runs` (or
`execution-logs`) on a schedule and stores rows keyed by `root_session_id`, `workspace_id` and
`model`.
