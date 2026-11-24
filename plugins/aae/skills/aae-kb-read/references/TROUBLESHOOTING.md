---
name: aae-troubleshooting
description: Symptom-first Q&A for Atlas Agent Engine failures - misleading errors, gateway failures, paused clusters, half-finished init, sandbox routing - and the misdiagnoses that recur.
---

# AAE troubleshooting

- [Summary](#summary)
- [Why does my gateway return 404?](#why-does-my-gateway-return-404)
- [Why does a deployed agent say the provider "rejected this project's configured API key" when the key works locally?](#why-does-a-deployed-agent-say-the-provider-rejected-this-projects-configured-api-key-when-the-key-works-locally)
- [Why does `app.llm()` report "Connection error" when a direct request works?](#why-does-appllm-report-connection-error-when-a-direct-request-works)
- [Why does an invoke with a bad LLM key hang instead of failing?](#why-does-an-invoke-with-a-bad-llm-key-hang-instead-of-failing)
- [Why does `secret set --sync` time out when the new value already works?](#why-does-secret-set---sync-time-out-when-the-new-value-already-works)
- [Why does invoke return 503 while `status` says healthy?](#why-does-invoke-return-503-while-status-says-healthy)
- [Why does invoke return 503 "All agent instances are currently busy"?](#why-does-invoke-return-503-all-agent-instances-are-currently-busy)
- [Why did my deploy fail with `OENotReady`?](#why-did-my-deploy-fail-with-oenotready)
- [What does a deploy success rate below 100% tell me?](#what-does-a-deploy-success-rate-below-100-tell-me)
- [Why does the deploy hang at `Memory: waiting`?](#why-does-the-deploy-hang-at-memory-waiting)
- [Why does `atlas setup` say "no workspace registered under context"?](#why-does-atlas-setup-say-no-workspace-registered-under-context)
- [Why does `--context` say my context is "not found"?](#why-does---context-say-my-context-is-not-found)
- [Why did a read-only investigation start a deployment?](#why-did-a-read-only-investigation-start-a-deployment)
- [Why does the hosted runtime fail an Atlas SRV lookup when my URI is right?](#why-does-the-hosted-runtime-fail-an-atlas-srv-lookup-when-my-uri-is-right)
- [Why does the build fail after I changed the package version?](#why-does-the-build-fail-after-i-changed-the-package-version)
- [Why does the first invoke after a rollout lose its tool pod?](#why-does-the-first-invoke-after-a-rollout-lose-its-tool-pod)
- [Why isn't the fact my agent just learned in memory yet?](#why-isnt-the-fact-my-agent-just-learned-in-memory-yet)
- [Why does a tool call fail now and then with `tool pod request failed: … EOF`?](#why-does-a-tool-call-fail-now-and-then-with-tool-pod-request-failed--eof)
- [Why does a streamed run end in an `error` chunk with no message?](#why-does-a-streamed-run-end-in-an-error-chunk-with-no-message)
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
  `GET https://agentengine.mongodb.com/api/v1/platform/agent-egress-ips`), plus the Atlas-lane
  pair as a buffer, since `/network-egress.md` lists all four for external services (checked
  2026-11-12; it listed only the first pair until at least 2026-10-10) ([DRIFT_LOG.md](DRIFT_LOG.md#2026-11-12--the-egress-page-now-lists-all-four-ips-as-one-list)).
  Allowlisting cannot help a gateway that is not reachable from the public internet at all:
  use a gateway or provider endpoint that is.
- Always read the runtime log before trusting the CLI's summary of an LLM failure.

## Why does `app.llm()` report "Connection error" when a direct request works?

The provider request is running in the **tool sandbox**, which lacks the key or the egress
entry. Give both sandboxes the LLM secret and the gateway egress, then redeploy (egress applies
at deploy time). Check the live policy with `agentengine egress`. Detail:
[SDK_ADAPTERS.md](SDK_ADAPTERS.md#where-do-model-calls-actually-run).

## Why does an invoke with a bad LLM key hang instead of failing?

Because the provider's **401** is not always propagated to the caller. *Field report,
2026-11-11, CLI 0.1.124; unconfirmed.* With an invalid `LLM_API_KEY`, some workspaces return
`llm_credential_rejected` quickly, while others hang for minutes (240 s and 1,156 s were seen)
before failing. The 401 is in the runtime log the whole time.

- On a slow or hanging invoke, read `agentengine logs --since 15m` before waiting it out.
- Set a client-side timeout on `invoke` / `invokeStream`; do not rely on the platform to fail fast.
- After rotating the key, verify with one short invoke rather than trusting `secret set` output.

## Why does `secret set --sync` time out when the new value already works?

On a project whose secrets are served by the credential broker (deploy events say "Application
secrets are served by the credential broker"), `--sync` and `secret sync` were seen to time
out after 5 minutes every time while the new value was live within about 2 minutes (CLI
0.1.124, field report 2026-11-11). Ignore the timeout and verify with an invoke. Detail in
[DRIFT_LOG.md](DRIFT_LOG.md#2026-11-12--secret-set---sync-and-secret-sync-time-out-although-the-secret-is-live-cli-01124).

## Why does invoke return 503 while `status` says healthy?

The backing Atlas cluster is probably **paused**. Run `agentengine atlas status` first: a
paused cluster shows `egress sync: ok (no clusters)` with a hint that paused clusters are
omitted. There are no runtime logs in this state. `workspace sessions list` failing with
"Failed to query execution data from Orchestration Engine" is the same cause. Resume the
cluster and follow [the recovery runbook](RUNBOOKS.md#recover-after-the-atlas-cluster-pauses).

## Why does invoke return 503 "All agent instances are currently busy"?

The **pool is full**: every sandbox pair is reserved by a session, and `scaling.replicas` caps
concurrent sessions. It is not the paused-cluster 503 above; read the message. Raise
`scaling.replicas` and **rebuild** (it is snapshotted at build time), then look at who holds
the slots with `agentengine workspace sessions list` and free them with
`agentengine workspace sessions stop <session-id>`. Idle sessions keep their slot until the
idle TTL (default 10 minutes). Only Playground and `agentengine invoke` test sessions are
reclaimed at capacity; REST and service-account sessions are not (0.1.126 `--help`). If the
workspace is an A2A callee, its slots are also taken by other agents' calls. Detail:
[DRIFT_LOG.md](DRIFT_LOG.md#2026-11-24--pool-full-raise-replicas-first-and-a-shared-session-id-shares-state).

## Why did my deploy fail with `OENotReady`?

`OENotReady … the orchestration engine could not reach MongoDB via MONGODB_URI` means the
deploy ran before the cluster accepted connections, usually while it was resuming. The failed
record is permanent, but the Orchestration Engine itself recovers once MongoDB is reachable.
Check `status` and invoke before redeploying.

The misunderstanding to head off: "CrashLoopBackOff is terminal, so a redeploy is mandatory."
Kubernetes keeps retrying with backoff; an immutable `failed` deployment record is not a
live state.

## What does a deploy success rate below 100% tell me?

Very little on its own. It is a console tile that appears in **no doc page, no `llms.txt`
entry and no OpenAPI schema**, computed over deployment records that are immutable. Treat it
as a UI aggregate and never build an SLO on it.

**Why it is structurally never 100%.** A deployment record never flips back to succeeded: one
fired into a bad window (a resuming cluster, a missing secret) stays `failed` forever, even
when the identical next deploy of the same build succeeds. So **retrying a transient failure
lowers the rate**. See
[DRIFT_LOG.md](DRIFT_LOG.md#2026-10-05--deploying-while-the-cluster-resumes-fails-the-orchestration-engine-self-heals).

**The signal is the individual failed deployment, not the ratio.** Inspect in this order, all
read-only:

1. `agentengine deploy list` — which deployment is actually live (`agentengine status`'s
   summary line lags).
2. `agentengine deploy get <id>` — the `Conditions` block carries the failure reason.
3. `agentengine deploy logs <id>` — the full event log. API equivalent:
   `GET /api/v1/projects/{id}/deployments/{deployment_id}/events`.
4. `agentengine logs --since 30m --source agent|tool` — runtime errors.

**What a failure means operationally:** the previous deployment keeps serving, so a failed
deploy does not take the agent down. The converse also holds — `succeeded` plus `healthy` is
not proof the agent answers. Invoke it.

The likeliest causes each have their own entry here: a paused or still-electing Atlas cluster
(`OENotReady`), a missing project or workspace secret, a `Memory: waiting` hang, and an egress
policy that rejects the LLM gateway host.

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

The second cause is a **non-interactive `deploy`**. A bare `deploy` binds the workspace for you
only on an interactive terminal; under CI, a redirect, a pipe, `--json` or `--all` it just
prints the missing setup. See
[CLI_TARGETING_AND_CONTEXTS.md](CLI_TARGETING_AND_CONTEXTS.md#why-does-deploy-do-more-on-my-laptop-than-in-ci).

## Why does `--context` say my context is "not found"?

You passed the `ctx_…` ID. `--context` takes the display name. Map one to the other in
`~/.agentengine/contexts.json`.

## Why did a read-only investigation start a deployment?

An unknown `deploy` subcommand (for example `deploy events <id>`, which does not exist) falls
through to a bare `deploy` and starts a real one (observed 2026-10-05, CLI 0.1.118).

`agentengine deploy` has exactly four subcommands (re-checked 2026-10-13 on 0.1.118):
`list`, `get`, `logs` and `cancel`. **`list`, `get <id>` and `logs <id>` are read-only;
`cancel` is mutating.** Anything outside those four deploys.

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

## Why does a tool call fail now and then with `tool pod request failed: … EOF`?

*Field observation, 2026-10-25, CLI 0.1.120, SDK 0.11.10; one project; not in the docs.*

A connection keep-alive race, not a broken tool. The tool sandbox's server closes idle
connections after **5 seconds**, while the Orchestration Engine reuses pooled connections to
it. A tool call sent about 5 seconds after the previous one on the same connection can go out
just as the server closes it: it fails in milliseconds, never reaches the tool (no access-log
line), and the next call works. Nothing retries it: the SDK retries only when the
Orchestration Engine marks a failure retryable, and here it does not. The error surfaces as an
exception from the tool call, not as an error result. Graphs that call tools on a steady
4.5 to 5.5 second rhythm (progress reports, for example) hit it repeatedly.

- Add a bounded retry for this transport error in your tool-call helper, and only for tools
  that are safe to repeat.
- Make fewer, larger tool round trips.
- Report it with the timestamps; the fix belongs in the platform.

## Why does a streamed run end in an `error` chunk with no message?

*Field observation, 2026-10-25, CLI 0.1.120; not in the docs.*

The `invokeStream` `error` chunk can arrive with **empty `content`**. The real message is on
the execution record: `GET /api/v1/projects/<project_id>/executions?workspace_id=<workspace_id>&session_id=<session_id>`
and read `.error`. One message seen this way, `workflow operation failed`, came from the
platform after every graph step had succeeded; treat it as a transient and retry from a point
that is safe to repeat. `agentengine logs --session-id <id>` may find nothing for such a
session; search an unfiltered time window instead.

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
