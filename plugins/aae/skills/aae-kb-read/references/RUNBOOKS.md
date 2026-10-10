---
name: aae-runbooks
description: Numbered Atlas Agent Engine procedures - first deploy, build and prove a hosted invocation, connect an external client, and recover after the Atlas cluster pauses. Each pinned to the CLI version it was run on.
---

# AAE runbooks

- [Summary](#summary)
- [First deploy of a scaffolded agent](#first-deploy-of-a-scaffolded-agent)
- [Build, deploy and prove a hosted invocation](#build-deploy-and-prove-a-hosted-invocation)
- [Connect an external client to a deployed workspace](#connect-an-external-client-to-a-deployed-workspace)
- [Recover after the Atlas cluster pauses](#recover-after-the-atlas-cluster-pauses)
- [Hand-off report after a deploy](#hand-off-report-after-a-deploy)

## Summary

| Runbook | CLI | Verified |
|---|---|---|
| First deploy of a scaffolded agent | 0.1.118 | 2026-10-04 to 2026-10-05, end to end |
| Build, deploy and prove a hosted invocation | 0.1.118 | 2026-10-04 |
| Connect an external client | 0.1.118 | 2026-10-10, from the console's *Connect to workspace* dialog |
| Recover after the Atlas cluster pauses | 0.1.118 | 2026-10-05 |

Adding or removing one agent in a monorepo: use the `aae-add-agent` and `aae-delete-agent`
skills. Before running any of these, read `--help` for each command on the installed CLI and
pin the version you ran in anything you write down.

## First deploy of a scaffolded agent

Prerequisites: the `agentengine` CLI installed (signed-in binary download, no package
manager); explicit **Project Owner** on the target project; an existing Atlas cluster of
Flex or M10+ tier (not free/shared); the LLM key in a secret manager.

1. `agentengine auth login`. Identity only; it says nothing about org or project.
2. `agentengine create --dir <repo> --name <agent>`. Passing `--dir` avoids the doubled
   `<slug>/agents/<slug>` path.
3. `cd <repo>/agents/<slug>`. **Every command below runs from this directory**, the one holding
   `agent.yaml`.
4. `agentengine dev up`. Open the playground at `localhost:3000` and expect a real LLM reply.
   Other ports are random; read them from `agentengine dev status`. Local dev reads secrets
   **only** from `.env`.
5. `agentengine init`. Creates the context, pins this directory and registers the workspace.
   If a previous `init` half-succeeded, run `agentengine init --context <existing-name>`
   instead. Never substitute `pin`.
6. `agentengine context current`. Check the org, project and "Source: directory pin" before
   anything billed.
7. `agentengine atlas setup`, interactive, **without `--yes`** (which can create a billed
   cluster and change IP access with no prompts). Pick the existing cluster. It shows
   `MONGODB_URI` **once**; never paste it anywhere.
8. Store the LLM key: `<secret-manager read> | agentengine secret set LLM_API_KEY --stdin`
   (add `--workspace-scope` to keep it from other agents in the project). The positional value
   and `--value` are deprecated.
9. If the model goes through a gateway, make sure its host is in the egress policy **for both
   sandboxes**, and allowlist AAE's non-Atlas egress IPs on the gateway (fetch them live from
   `GET https://agentengine.mongodb.com/api/v1/platform/agent-egress-ips`).
10. `agentengine deploy --auto`. Build and deploy take roughly 5 to 10 minutes each. If the
    CLI reports "session expired" (for example after the laptop sleeps), check
    `agentengine deploy list` before re-running: the server side often finishes anyway.
11. Verify: `agentengine deploy list` shows the new row as `succeeded`, then
    `agentengine invoke "Say hi" --session <a-reused-id>` returns a real reply. If the first
    invoke after rollout loses a tool-pod reservation, retry once in a fresh session.

## Build, deploy and prove a hosted invocation

The stricter procedure for handing an agent over as working. Acceptance is a **hosted**
invocation that exercises the LLM (and, where relevant, one read-only tool), not a green
deployment or a local run.

Prerequisites: the agent's purpose and a safe test prompt; its source directory; the target
org and project; the existing Atlas cluster and DB user; the model gateway's base URL, auth
header and model ID; a Voyage key only if memory is wanted.

1. **Inspect before changing anything:** `agentengine --version`, the relevant `--help`, the
   repo's instructions, `agent.yaml`, the lockfile, `.agentengine/state.json`, git status, the
   current build and deployment, the platform secret **names**, the Atlas link and the egress
   policy.
2. **Wire the model.** For an OpenAI-compatible gateway that authenticates with an `api-key`
   header, a LangGraph agent typically uses
   `ChatOpenAI(base_url=<gateway-base-url>, model=<model-id>, default_headers={"api-key": key}, use_responses_api=False)`
   and passes it to `app.llm()`. For Anthropic-protocol gateways, the base URL is the one the
   client appends `/v1/messages` to. Probe the gateway with curl before building (see
   [TROUBLESHOOTING.md](TROUBLESHOOTING.md#why-does-my-gateway-return-404)).
3. **Give both sandboxes the key and the egress.** As of CLI 0.1.118 the scaffold writes the
   top-level form below; the docs now prefer per-sandbox egress under `sandboxes.<name>.network`
   and offer `agentengine migrate sandboxes`. Check `/network-egress.md` for the current shape.
   ```yaml
   sandboxes:
     agent:
       secrets: [LLM_API_KEY]
     tool:
       secrets: [LLM_API_KEY]
   network:
     egress:
       - fqdn: <gateway-host>
         ports: [443]
   ```
   One egress entry with no `component` applies to both sandboxes; a duplicate FQDN fails
   validation. The secret name must match exactly across code, manifest and platform.
4. **Bind the workspace and Atlas:** `agentengine init`, then `agentengine atlas status`. If
   the right Atlas project is linked and egress sync is healthy, keep it. Otherwise
   interactive `agentengine atlas setup`, `agentengine atlas link`, and `atlas status` again.
5. **Store secrets:** project scope for shared `MONGODB_URI` and (with memory)
   `VOYAGE_API_KEY`; workspace scope for the agent's LLM key. Confirm with
   `agentengine secret list` and `agentengine secret list --workspace-scope` (names and
   versions only). A changed `.env` updates nothing on the platform; re-run `secret set`
   (optionally `--sync`). `secret sync` only reloads values already stored.
6. **Memory, if enabled:** inspect `project-config.yaml`, then `agentengine memory configure`,
   `agentengine memory apply --wait`, `agentengine memory status`.
7. **Check and build:** run the project's tests, `uv lock` if dependencies or the version
   changed, then `agentengine agent validate` and `agentengine build --json`.
8. **Deploy that build:** `agentengine deploy --build-id <build_id> --json`, then
   `agentengine deploy get <deployment_id> --json`, `agentengine status --json`,
   `agentengine egress`.
9. **Prove it:** `agentengine invoke --json --user-id <test-user> "<safe prompt>"`. Record the
   session and execution IDs and inspect the trace. Read
   `agentengine logs --source agent --since 30m` and `agentengine logs --source tool --since 30m`.
10. **Prove the claimed features separately:** memory recall in a **new** session (extraction is
    asynchronous); approval and rejection on a safe target if the agent changes external state.

## Connect an external client to a deployed workspace

Source: the workspace page's **Connect to workspace** dialog in the AAE console (also a
"Connect" button in the page header). The dialog is read-only and creates nothing. Verified
2026-10-10, CLI 0.1.118.

1. **Create a service account** (the secret is shown once):
   `agentengine service-account create <client-name> --project-id '<project_id>' --role AGENT_DEVELOPER`
2. **Mint an access token** (1 h; curl prompts for the secret without echoing it):
   ```bash
   read -r -p "Client ID: " CLIENT_ID
   ACCESS_TOKEN=$(curl --fail-with-body --silent --show-error \
     --user "$CLIENT_ID" --data grant_type=client_credentials \
     'https://agentengine.mongodb.com/api/v1/oauth/token' | jq -er .access_token)
   ```
3. **Invoke** (streaming, SSE):
   ```bash
   curl -N -s 'https://agentengine.mongodb.com/api/v1/projects/<project_id>/workspaces/<workspace_id>/invokeStream' \
     -X POST -H "Authorization: Bearer $ACCESS_TOKEN" -H "Content-Type: application/json" \
     -d '{"message": "Hello, agent!"}'
   ```
   Non-streaming: the same path ending in `/invoke`. Send `X-Session-ID` to reuse a session;
   otherwise each call reserves a fresh sandbox pair.
4. **Optional, forward credentials:** any header prefixed `X-Mdb-Agent-Engine-Custom-` reaches
   the agent with the prefix stripped and lower-cased (`…-Custom-Authorization` →
   `authorization`), readable with `get_current_custom_headers()`. Headers are not persisted;
   resend them on resume.

Name these traps when prescribing it:

- **Memory identity collapse:** every end user behind this service account shares one memory
  scope, and `user_id` in the request is ignored.
- The token lasts 1 h with no refresh; the client must re-mint it.
- `--project-id` is the AAE project ID, which equals the Atlas project ID.
- `AGENT_DEVELOPER` also grants build and deploy; no invoke-only role exists.
- In the console, `scaling.replicas` appears as **INSTANCES** ("Standby: warmed up and ready";
  "Active: currently handling a request").

## Recover after the Atlas cluster pauses

Use when the backing cluster was paused (by a person, a schedule or an org policy) and the
agent now returns 503 "agent is currently unavailable" while `agentengine status` looks
healthy. Verified 2026-10-05, CLI 0.1.118.

Why: the Orchestration Engine loses MongoDB when the cluster pauses and recovers by itself once
the cluster serves again. **A redeploy is not automatically needed**, and one fired too early
fails permanently.

1. **Resume the cluster** in the Atlas UI. Wait until it genuinely serves connections, not just
   until it shows "running": a resuming replica set reports running before all nodes finish
   election.
2. **Check the Atlas IP Access List** holds the AAE Atlas-lane pair (fetch it live with
   `agentengine atlas setup-ip-access` or the `egress-ips` endpoint; see
   [DRIFT_LOG.md](DRIFT_LOG.md#2026-10-08--there-are-two-egress-ip-pairs-one-per-lane)).
3. `agentengine atlas status` → expect `egress sync: ok` and at least one cluster in the last
   sync. "No clusters" means it is still paused: stop, do not deploy.
4. `agentengine status`. If the Orchestration Engine is healthy and components are ready, it
   has self-healed: go to step 6.
5. **Only if it has not recovered**, redeploy the last good build:
   `agentengine deploy --build-id <last-good-build>`, then confirm with `agentengine deploy list`
   (not the `status` summary line, which lags).
6. `agentengine invoke "Say hi" --session <a-reused-id>` → expect a real reply. Retry once in a
   fresh session if the first invoke loses a tool-pod reservation. Record whether step 5 was
   needed: it is still unconfirmed whether a redeploy is ever required here.

While diagnosing, only `deploy list` and `deploy get <id>` are safe `deploy` forms.

## Hand-off report after a deploy

Report in plain language, never including secret values or a credential-bearing URI:

1. What the agent does, and which actions are simulated versus live.
2. The source revision (commit SHA, or "archive build; no commit").
3. Build ID and status, deployment ID and status, deployed version, workspace health, and the
   live egress policy.
4. One successful hosted invocation, with session and execution IDs and what it proved.
5. Memory-recall and approval evidence, when those features are claimed.
6. Remaining limitations and the exact action needed from the user, if any.

Do not call the work complete on a build, a rollout, a local smoke test or a memory write alone.
