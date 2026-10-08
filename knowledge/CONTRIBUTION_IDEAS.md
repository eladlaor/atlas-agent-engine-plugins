# Contribution Ideas

- [Summary](#summary)
- [How to use this file](#how-to-use-this-file)
- [1. An add-on agent-orchestration supervisor for AAE](#1-an-add-on-agent-orchestration-supervisor-for-aae)
- [2. A scheduled-invoke helper](#2-a-scheduled-invoke-helper)
- [3. A fleet spec kit: agent spec cards plus an A2A message contract](#3-a-fleet-spec-kit-agent-spec-cards-plus-an-a2a-message-contract)
- [4. A golden-set evaluation harness for AAE agents](#4-a-golden-set-evaluation-harness-for-aae-agents)

## Summary

A running list of things worth building on or for MongoDB Atlas Agent Engine, each
recorded with the observation that motivated it. An idea earns a place here when it
names a **specific gap** — something the platform demonstrably does not do — rather
than a general wish.

Current list: four ideas. Ideas 2–4 came out of planning a multi-agent fleet on AAE
(2026-10-06 to 2026-10-08). That fleet is also the intended proving ground for idea 1.
New candidates are collected by the `aae-scout` agent (in its `UTILITY_CANDIDATES.md`
memory file) and promoted here once they meet the bar above.

## How to use this file

Each entry states the gap first, in the platform's own terms, then the proposal.
Keep the evidence attached: an idea whose motivating observation turns out to be
wrong should be struck, not quietly reinterpreted into something else.

Mark unverified claims with `[verify]`. Entries here are proposals, not commitments.

---

## 1. An add-on agent-orchestration supervisor for AAE

**Status:** idea, unbuilt. Recorded 2026-10-05.

### What's the gap?

The Orchestration Engine orchestrates **executions and resources, not work**.
Roughly 80% system orchestration, 20% genuine agent orchestration. The name misleads
in one specific way: it invites you to expect a planner or supervisor that decomposes
a task and assigns roles across agents. **It does none of that. It never decides
which agent does what.**

What it *does* do for inter-agent work is real and worth crediting — it brokers every
A2A call:

- hosts the registry (`/a2a/discover`, `/a2a/invoke`, with each agent's skills pushed
  at startup)
- enforces `allowed_callers`
- mints a short-lived `a2a-token`
- creates a child execution linked by `parent_execution_id`
- preserves human-in-the-loop end-to-end

Constraints: intra-project only, unavailable from the tool sandbox, 5-minute token
with no refresh, 300s timeout.

But **nothing in AAE runs a multi-agent task.** The unit of execution is always one
agent's graph. There is no multi-agent workflow object, no role assignment, no plan
the platform owns. You *can* build supervisor/worker topologies, because
`app.a2a_tools()` exposes `discover_available_agents` and `invoke_a2a_agent` **as LLM
tools** — the model decides to delegate, and the OE executes the delegation. **The
supervisor is your router agent, not the OE.**

Stated for a customer: *"it gives you discovery, brokered invocation, access control,
and a unified trace across agents — you still write the coordination logic."*

That last sentence is the gap. Everyone who builds a multi-agent system on AAE writes
the same coordination logic, separately, from scratch.

### The proposal

A reusable **agent-orchestration supervisor** built for AAE: the coordination layer
the platform deliberately leaves to the developer, packaged so it does not have to be
rewritten per project.

Plausible shape — a supervisor agent, deployed like any other AAE agent, that:

- Reads the project's A2A registry and treats the available agents as a capability
  pool rather than as tools the LLM happens to know about
- Accepts a task, decomposes it, and assigns sub-tasks to agents by advertised skill
- Owns the plan as **data**, not as prompt text — inspectable, resumable, and
  diffable, which is precisely what an LLM-chooses-the-next-tool loop is not
- Handles partial failure explicitly: retry, reassign, escalate to human review, or
  abandon with a recorded reason
- Aggregates results and reconciles conflicting answers from different agents

### Why this is a genuine fit rather than a wish

- **It works with the grain of the platform, not against it.** It needs no
  platform change — A2A, discovery, access control, child executions, and unified
  tracing already exist. The supervisor is an agent like any other.
- **The trace story is already solved.** A2A calls render as nested subagent nodes
  under a shared `root_session_id`, so a supervisor's plan execution is observable
  for free. That is usually the hardest part of a multi-agent system.
- **HITL survives delegation.** A target agent that suspends for human review pauses
  the call rather than failing, so a plan can legitimately include human steps.

### Open questions

1. **Does the 5-minute `a2a-token` lifetime with no refresh bound how long a plan
   step can run?** A supervisor coordinating long sub-tasks may hit `401` mid-plan.
   The 300s invoke timeout is a harder ceiling still. These two limits may constrain
   the design more than anything else. `[verify]`
2. **Is a plan-as-data supervisor better than a well-prompted router agent?** The
   honest answer may be "only above some task complexity." Worth finding where that
   line is before building.
3. **Intra-project only** means a supervisor cannot coordinate across projects — and
   the project is the isolation boundary. So a multi-tenant supervisor is not
   expressible today.
4. **Memory interaction.** All agents in a project share one memory store, with no
   per-agent partition. A supervisor and its workers would share memory by default,
   which may be a feature or a leak depending on the use case.
5. **Where would this live?** A contribution to AAE itself, a standalone open-source
   package, or a template in `agentengine create`?

### Evidence

Derived from the A2A and agent-contract documentation reviewed 2026-10-05, plus the
`first-try` agent. The motivating verdict — "orchestrates executions and resources,
not work" — is an **inference from the absence** of any multi-agent workflow object
in the platform. It is well supported, but it is an absence argument: if AAE ships a
workflow primitive, this idea's premise disappears. Re-check before building.

---

## 2. A scheduled-invoke helper

**Status:** idea, unbuilt. Recorded 2026-10-08.

### What's the gap?

AAE has no way to run an agent on a schedule. The docs index (checked 2026-10-06) has no
scheduling, cron, or trigger page. An agent runs only when something calls its invoke
endpoint. Everyone who wants a daily or nightly agent writes the same small script around
an external scheduler (cron, launchd, a cloud function, CI):

1. `POST /api/v1/oauth/token` with a service account, `grant_type=client_credentials`.
   Tokens last 1 hour and are rate-limited (`429`), so fetch one per run.
2. `POST /api/v1/projects/{project_id}/workspaces/{workspace_id}/invoke`, with a dated
   `X-Session-ID` so a rerun on the same day reuses one sandbox pair.

Two complications are easy to miss:

- **A paused Atlas cluster makes invoke return `503` while `agentengine status` still
  reports healthy.** A scheduled job on an auto-pausing cluster has to start the cluster,
  wait until it really accepts connections, and retry `503` within a time limit.
- **Silence looks like success.** If the agent never starts, nothing reports it. The
  scheduler itself has to alert on any response other than 2xx.

### The proposal

A script (plus a skill that explains it) that takes a project, workspace, message, and
service-account credentials from the host's secret store. Optionally it starts a named
Atlas cluster first. It retries `503` with backoff up to a limit, and exits non-zero with
the execution ID on failure. It works the same from cron, launchd, or a cloud scheduler.

### Evidence

`deploy/invoke-agent.md` and `api-keys-service-accounts.md`, read 2026-10-06. The paused-cluster
behaviour was observed 2026-10-05. **Re-check before building:** native scheduling is a
plausible future feature, and if it ships this idea is obsolete.

---

## 3. A fleet spec kit: agent spec cards plus an A2A message contract

**Status:** idea, unbuilt. Recorded 2026-10-08.

### What's the gap?

AAE gives multi-agent systems discovery, brokered calls, and `allowed_callers` (see idea 1).
It gives no help with **specifying** a fleet: what each agent is for, its input and output,
who may call it, its time budget, its pass bar. Without that, tuning one agent quietly
breaks another. The A2A limits also have to be designed in from the start, not discovered
later: 300 s timeout, 5-minute token, intra-project only, no authentication between agents
in a project.

### The proposal

A skill that scaffolds:

- a **spec-card template**: purpose, non-goals, invocation, I/O, knowledge sources, tools,
  A2A callers, model and budget, sandbox config, pass bar, change log;
- a **message contract**: a request envelope with a call chain and a deadline, a response
  envelope with status values and citations, cycle and hop rules, and time budgets that
  shrink down the chain to fit the 300 s limit;
- an **index**, checked against the 25-workspace project limit.

Generalized from the specification of a 16-agent fleet.

---

## 4. A golden-set evaluation harness for AAE agents

**Status:** idea, unbuilt. Recorded 2026-10-08.

### What's the gap?

AAE ships **no evaluation tooling**: no eval datasets, no LLM judge, no regression suites.
Testing means manually driving the Playground. Every team that cares about quality builds
its own harness.

### The proposal

A small harness that runs each agent's golden question set through `agentengine invoke`
(locally against `dev up`, or deployed). It scores rule-based criteria (citations present,
payload shape, item counts, latency) and LLM-judged criteria (fairness, specificity), and
fails when results regress past a baseline. Paired with idea 3, the pass bar on each spec
card becomes executable.

**Open question:** is this better as a plugin script, or as an AAE agent that evaluates the
other agents over A2A? A2A's 300 s limit and its intra-project scope favour a local harness
first. `[verify]`
