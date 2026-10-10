---
name: aae-troubleshooting
description: Symptom-first Q&A for Atlas Agent Engine failures - misleading errors, gateway failures, paused clusters, half-finished init, sandbox routing - and the misdiagnoses that recur.
---

# AAE troubleshooting

- [Summary](#summary)
- [Why does my gateway return 404?](#why-does-my-gateway-return-404)
- [Why does a deployed agent say the provider "rejected this project's configured API key" when the key works locally?](#why-does-a-deployed-agent-say-the-provider-rejected-this-projects-configured-api-key-when-the-key-works-locally)
- [Why does `app.llm()` report "Connection error" when a direct request works?](#why-does-appllm-report-connection-error-when-a-direct-request-works)
- [Why does invoke return 503 while `status` says healthy?](#why-does-invoke-return-503-while-status-says-healthy)
- [Why did my deploy fail with `OENotReady`?](#why-did-my-deploy-fail-with-oenotready)
- [Why does the deploy hang at `Memory: waiting`?](#why-does-the-deploy-hang-at-memory-waiting)
- [Why does `atlas setup` say "no workspace registered under context"?](#why-does-atlas-setup-say-no-workspace-registered-under-context)
- [Why does `--context` say my context is "not found"?](#why-does---context-say-my-context-is-not-found)
- [Why did a read-only investigation start a deployment?](#why-did-a-read-only-investigation-start-a-deployment)
- [Why does the hosted runtime fail an Atlas SRV lookup when my URI is right?](#why-does-the-hosted-runtime-fail-an-atlas-srv-lookup-when-my-uri-is-right)
- [Why does the build fail after I changed the package version?](#why-does-the-build-fail-after-i-changed-the-package-version)
- [Why does the first invoke after a rollout lose its tool pod?](#why-does-the-first-invoke-after-a-rollout-lose-its-tool-pod)
- [Why isn't the fact my agent just learned in memory yet?](#why-isnt-the-fact-my-agent-just-learned-in-memory-yet)
- [Which misdiagnoses keep recurring?](#which-misdiagnoses-keep-recurring)

## Summary

Read the user's files (`agent.yaml`, `src/<module>/llm.py`, `project-config.yaml`, `dev.yaml`)
and probe before naming a cause. Most AAE failures have a misleading surface message. The
three that cost the most time: a **gateway IP allowlist** reported as a bad API key; a
**paused Atlas cluster** behind a healthy `status`; and a **typo'd `deploy` subcommand** that
deploys.

## Why does my gateway return 404?

Wrong path or unknown model, not auth. A wrong auth header gives **401**.

- Path: pasting a full `/v1/messages` URL where a base URL belongs doubles the path.
- Model: Anthropic-protocol gateways answer an unknown model with
  `not_found_error: "The model does not exist…"`. Model **aliases** written by the scaffold or
  wizard are the prime suspect.
- Probe before diagnosing, with the key injected so it never reaches the transcript or shell
  history, e.g. `-H @<(printf 'x-api-key: %s' "$(<secret-manager read>)")`. Probe the base URL
  and the model ID separately.
- The classic misdiagnosis: blaming the URL when the base URL is right and the model alias is
  the culprit.

## Why does a deployed agent say the provider "rejected this project's configured API key" when the key works locally?

Usually the gateway is rejecting the **source IP**, not the key. Observed 2026-10-04: the CLI
reported "LLM provider rejected this project's configured API key", while the runtime log
(`agentengine logs --since 20m`) showed a **403** `PermissionDeniedError … RBAC: access denied`.
A bad key gives **401**.

- Deployed agents leave from AAE's fixed public egress IPs, not from your laptop or VPN.
  A gateway that allowlists IPs, or is reachable only on a private network or VPN, blocks them
  even though `dev up` worked.
- Fix: allowlist the non-Atlas egress pair on the gateway (fetch it live from
  `GET https://agentengine.mongodb.com/api/v1/platform/agent-egress-ips`), or use a gateway
  or provider endpoint that is publicly reachable.
- Always read the runtime log before trusting the CLI's summary of an LLM failure.

## Why does `app.llm()` report "Connection error" when a direct request works?

The provider request is running in the **tool sandbox**, which lacks the key or the egress
entry. Give both sandboxes the LLM secret and the gateway egress, then redeploy (egress applies
at deploy time). Check the live policy with `agentengine egress`. Detail:
[SDK_ADAPTERS.md](SDK_ADAPTERS.md#where-do-model-calls-actually-run).

## Why does invoke return 503 while `status` says healthy?

The backing Atlas cluster is probably **paused**. Run `agentengine atlas status` first: a
paused cluster shows `egress sync: ok (no clusters)` with a hint that paused clusters are
omitted. There are no runtime logs in this state. `workspace sessions list` failing with
"Failed to query execution data from Orchestration Engine" is the same cause. Resume the
cluster and follow [the recovery runbook](RUNBOOKS.md#recover-after-the-atlas-cluster-pauses).

## Why did my deploy fail with `OENotReady`?

`OENotReady … the orchestration engine could not reach MongoDB via MONGODB_URI` means the
deploy ran before the cluster accepted connections, usually while it was resuming. The failed
record is permanent, but the Orchestration Engine itself recovers once MongoDB is reachable.
Check `status` and invoke before redeploying.

The misunderstanding to head off: "CrashLoopBackOff is terminal, so a redeploy is mandatory."
Kubernetes keeps retrying with backoff; an immutable `failed` deployment record is not a
live state.

## Why does the deploy hang at `Memory: waiting`?

The memory service cannot build its Search and Vector Search indexes on your cluster. Usually
the cluster is a free/shared tier (no Search), or its IP Access List does not admit AAE's
**Atlas-lane** egress IPs. Fetch those live with `agentengine atlas setup-ip-access`; they
differ from the pair external services need (see
[DRIFT_LOG.md](DRIFT_LOG.md#2026-10-08--there-are-two-egress-ip-pairs-one-per-lane)).

## Why does `atlas setup` say "no workspace registered under context"?

`init` never finished registering the workspace. The usual cause is running `init` from a
directory with no `agent.yaml` above it: it walks the prompts, creates the context, then fails
with `no agent.yaml found in current directory or any parent`. Fix: `cd` into the agent
directory and run `agentengine init --context <the-created-name>`. `pin` is not a substitute.

## Why does `--context` say my context is "not found"?

You passed the `ctx_…` ID. `--context` takes the display name. Map one to the other in
`~/.agentengine/contexts.json`.

## Why did a read-only investigation start a deployment?

An unknown `deploy` subcommand (for example `deploy events <id>`) falls through to a bare
`deploy` and starts a real one (observed 2026-10-05, CLI 0.1.118). Only `deploy list` and
`deploy get <id>` are read-only.

## Why does the hosted runtime fail an Atlas SRV lookup when my URI is right?

Check the platform's Atlas link and egress sync with `agentengine atlas status`, even when the
Atlas IP list and `MONGODB_URI` look correct. Atlas connectivity goes through the Atlas link,
not an ordinary egress rule; do not add cluster hostnames to the LLM egress list to fix it.

## Why does the build fail after I changed the package version?

The lockfile is stale. Run `uv lock`, rerun the checks, and build again. Locally, a new
dependency is not installed while `uv.lock` exists (`--frozen`): `uv lock`, then
`agentengine dev stop` and `dev up`.

## Why does the first invoke after a rollout lose its tool pod?

A transient reservation loss right after rollout. Check `agentengine status`; when healthy,
retry once in a fresh session. Investigate tool logs and traces if it repeats.

## Why isn't the fact my agent just learned in memory yet?

Long-term memory extraction is **asynchronous**. A turn recorded now is available in a later
conversation, not the next turn. Test recall in a new session after extraction has had time
to run.

## Which misdiagnoses keep recurring?

Each of these was made at least once while building this knowledge base. The rule beside it is
what prevents a repeat.

| Misdiagnosis | Rule |
|---|---|
| Recommended `pin` to recover a half-finished `init` | Pin is not a workspace; `init --context <name>` from the agent dir |
| Blamed the URL for a gateway 404 | Read `llm.py`, probe with curl; 404 is path or model, 401 is auth |
| Said a cluster might not be needed with memory off | `MONGODB_URI` is required for every deploy |
| Treated a context as belonging to one agent | Contexts are per project; name them after the project |
| Read `context "ctx_…" not found` as "deleted" | `--context` takes the display name |
| Called the documented egress IPs "stale" | There are two lanes; fetch both live |
| Called OpenTelemetry "absent" from reading the guides | Check the OpenAPI spec before declaring anything absent |
| Took a `failed` deployment record as a dead Orchestration Engine | Records are immutable; check `status`, then invoke |
| Concluded the SDK was unpublished after a 0.0.0 install | Suspect the Python version (3.14 resolves a placeholder) |
| Said `app.llm()` always runs in the tool sandbox | It depends on `invoke_llm` routing; give both sandboxes key and egress |
| Called a configuration "proven" that was only in someone else's notes | "Proven" means run end to end in this project, with a date |
| Asserted how `atlas setup` authenticated from a missing file | Ask or check; absence of a profile file is not evidence of the auth mode |
