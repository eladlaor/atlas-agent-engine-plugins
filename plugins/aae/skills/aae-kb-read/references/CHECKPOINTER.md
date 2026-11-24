---
name: aae-checkpointer
description: What app.checkpointer() returns, where LangGraph graph state is stored and under which key, the serialization and Send restrictions, unbounded retention, how it differs from memory, and why ADK has no equivalent.
---

# The LangGraph checkpointer

- [Summary](#summary)
- [What does `app.checkpointer()` return, and how do I wire it?](#what-does-appcheckpointer-return-and-how-do-i-wire-it)
- [Where does the state actually go?](#where-does-the-state-actually-go)
- [What is the checkpoint keyed on?](#what-is-the-checkpoint-keyed-on)
- [What may I put in graph state?](#what-may-i-put-in-graph-state)
- [Do I need it for human-in-the-loop?](#do-i-need-it-for-human-in-the-loop)
- [How long are checkpoints kept?](#how-long-are-checkpoints-kept)
- [How is the checkpointer different from memory?](#how-is-the-checkpointer-different-from-memory)
- [What is the ADK equivalent?](#what-is-the-adk-equivalent)
- [What is not documented?](#what-is-not-documented)

## Summary

Verified **2026-10-14** against the live docs and `agent-engine-sdk-langgraph` **0.11.8**.
AAE is in Public Preview: no SLAs, and details may change without a backward-compatible
migration path. Facts read from the wheel rather than a doc page are marked **[wheel]**;
those names are internal and may change without notice.

- The checkpointer saves **one conversation's graph state** so a suspended run resumes where
  it stopped. It is not memory, not RAG, and not a user profile.
- One call, no arguments: `graph.compile(checkpointer=app.checkpointer())`.
- It **returns `None`** instead of raising when `MONGODB_URI` is unset — a stateless graph
  compiles happily and nothing tells you.
- Checkpoints land in **your** Atlas cluster and grow **without a TTL or any purge command**.
- **LangGraph only.** ADK has no checkpointer and no opt-out.
- The richest source is the SDK package page, not the guides:
  `/docs/agentengine/sdk/python/packages/agent-engine-sdk-langgraph.md`.

## What does `app.checkpointer()` return, and how do I wire it?

```python
return graph.compile(checkpointer=app.checkpointer())
```

That is the whole surface — it takes **no arguments**. The docs name only `MongoDBSaver`; the
object you actually get is `PlatformCheckpointer`, a `BaseCheckpointSaver` subclass that wraps
`MongoDBSaver(client, db_name=...)` from `langgraph-checkpoint-mongodb`. **[wheel]**

**There is no async variant.** One class implements both the sync and `a*` legs;
`AsyncMongoDBSaver` is not used anywhere in the SDK. **[wheel]**

**Two silent `None` returns** — logged as warnings, never raised **[wheel]**:

- the runtime mode is not AER (the platform is managing durability instead), or
- `MONGODB_URI` is unset. The source calls this deliberate: agents "compile a stateless graph
  rather than failing every native invocation".

Since `compile(checkpointer=None)` is legal, a missing URI costs you all persistence with no
error. Check the logs, not the exception.

`app.close()` closes the `MongoClient` that `checkpointer()` opened. **[wheel]**

## Where does the state actually go?

Your own cluster, via `MONGODB_URI`. The database is resolved in this order (all documented in
the package page's Configuration table):

1. `CHECKPOINT_DB_NAME` — exact name; skips project scoping entirely.
2. `MDB_AGENTIC_STORE_DB` — default **`mdb_store`**, the per-project LangGraph checkpoint store.
3. Otherwise `mdb_store` plus per-project scoping resolved against the live cluster, so the SDK
   and the Orchestration Engine converge on one database. The legacy base name
   `mdb_agentic_store` is still recognized.

Collections are `checkpoints` and `checkpoint_writes` with an index on
`(thread_id, checkpoint_ns, checkpoint_id)` — these are `MongoDBSaver`'s own defaults and the
SDK overrides nothing, but **no AAE doc states them**. The SDK creates everything on the first
`app.checkpointer()` call; no CLI command provisions it.

Timeouts, all documented: `CHECKPOINTER_SERVER_SELECTION_TIMEOUT` (5.0s),
`CHECKPOINTER_CONNECT_TIMEOUT` (5.0s), `CHECKPOINTER_SOCKET_TIMEOUT` (15.0s). A paused cluster
or an over-narrow database user shows up here first, as an IO timeout rather than a permission
error — see [DRIFT_LOG.md](DRIFT_LOG.md) (2026-10-08) for the narrow-user scoping trap.

## What is the checkpoint keyed on?

> By default the LangGraph checkpoint `thread_id` is `session_id:workspace_id`.

**The caller passes no config.** The platform builds it: client `X-Session-ID` header (or
`--session`) → `ctx.session_id` → `f"{session_id}:{workspace_id}"` → `configurable.thread_id`.
On resume the platform adds `configurable.checkpoint_id`. Your graph code never constructs a
`RunnableConfig`. **[wheel]**

In AAE's vocabulary: a **session** is the conversation and maps to one `thread_id`; a **run /
execution** is one turn and is *not* the checkpoint key. `workspace_id` comes from the pod's
`APP_ID`, and on managed runtimes a missing `APP_ID` **fails closed** rather than falling back
to a bare key. **[wheel]**

The suffix exists because two agents in one project reusing a `session_id` would otherwise read
and write each other's checkpoint documents. **[wheel]**

Overriding with `@app.resolve_thread_id` costs you three things, all documented:

- the key becomes **invisible to `/query/sessions*` history lookups**, which only understand
  default-derived keys;
- you get **no workspace suffix**, so collision isolation is yours to enforce;
- **reads are scoped-only** — there is deliberately no fallback to the bare key, since a bare
  key is readable by every workspace on the shared store.

Session IDs are 1–128 chars of letters, numbers, `_` and `-`; a `:` is rejected with HTTP 400.

## What may I put in graph state?

The contract is explicit:

> Every value in your graph state must be serializable to JSON or BSON for the checkpoint to
> succeed, such as primitives, lists, dicts, `datetime`, `Enum`, and LangChain `BaseMessage`
> subclasses. Do not store lambdas, closures, file handles, database connections, or custom
> classes in your graph state without serialization support.

So LangChain message objects **are** handled. Mechanically it is LangGraph's
`JsonPlusSerializer`. **[wheel]**

**One hard rejection worth knowing:** the platform checkpointer refuses application-authored
`Send` writes — LangGraph's dynamic fan-out — raising `UnsupportedDurableGraphError`. **[wheel]**
Graphs from `app.deep_agent()` are an internal exception because LangChain routes tool calls
through `Send`; the docs state plainly that this "does not make `Send` a supported application
API". Use fixed edges, compiled subgraphs, or deep-agent task delegation.

Checkpoints are ordinary documents, so MongoDB's 16 MB limit applies — but that is inference.
**No AAE doc states a per-checkpoint size cap or an error code for exceeding one.**

## Do I need it for human-in-the-loop?

**Pass it.** No page says "`interrupt()` requires a checkpointer" in those words, but the HITL
page describes the sandbox saving a checkpoint on suspend and restoring from it on resume, the
contract explains checkpoints exist "between suspend and resume actions", and every official
example compiles with one.

The nuance: in **durable-workflow** mode the suspension record is Orchestration-Engine-side —
"OE activity history, never this scratch, is the durable replay source" **[wheel]** — so the
native leg carries less weight there than in native-checkpoint mode.

Separately, and often confused with checkpointing: on resume the OE **returns cached results
for every step that completed before the suspend**, so a pre-suspend email is not sent twice.
That guarantee covers only calls routed through `app.llm()` and `@app.tool()`.

Forking a session is not LangGraph time-travel: AAE creates a **new session** rather than
patching the source `thread_id`.

## How long are checkpoints kept?

**Forever, by default.** `MongoDBSaver`'s `ttl` defaults to `None` and the SDK passes no `ttl`,
so no TTL index is ever created. **[wheel]** No doc page mentions checkpoint retention,
cleanup, archival or a size quota, and no CLI command deletes them. The only deletion surface
is LangGraph's own `delete_thread(thread_id)`.

This is a real gap, and the data sits on **your** cluster and **your** storage bill. Plan a
purge yourself.

Note that `scaling.agent_idle_ttl_seconds` and `tool_idle_ttl_seconds` reclaim the **sandbox**,
not the checkpoint. Losing a sandbox does not lose conversation state — that is the point.

## How is the checkpointer different from memory?

**The checkpointer persists one conversation's graph state so a run can resume where it
stopped; memory distills facts across conversations so a later, different conversation can use
them.**

| | Checkpointer | Memory |
|---|---|---|
| Keyed on | `session_id:workspace_id` | `user_id` |
| Written | synchronously, exact state | asynchronously, LLM-extracted and distilled |
| Owned by | LangGraph, in `checkpoints` | the platform's memory service |
| Read by | thread key | Atlas Vector / Atlas Search, Voyage embeddings |

Four traps from conflating them:

1. **"My fact isn't there on the next turn."** Memory extraction is asynchronous — it surfaces
   in a *later* conversation. The checkpointer is immediate and within-session. This is the
   most common confusion by a wide margin.
2. **Setting `features.memory: false` does not disable checkpointing.** `MONGODB_URI` is
   required either way.
3. **The service-account memory-identity trap does not hit checkpoints.** When every end user
   behind one service account collapses into a single memory scope, distinct `X-Session-ID`
   values still keep conversation state cleanly separated. People assume both are broken.
4. **Reusing a session ID to dodge `pool full` also merges message history.** Sandbox economy
   and per-session isolation pull against each other.

## What is the ADK equivalent?

There isn't one. `app.checkpointer()` is LangGraph-only: the ADK package contains no
`checkpointer` symbol at all **[wheel]**, and the method is among the 14 the ADK adapter lacks
(see [SDK_ADAPTERS.md](SDK_ADAPTERS.md)).

Its analog is `PlatformSessionService`, in-memory scratch for one OE attempt, because ADK's
`Runner` still needs a `BaseSessionService`. Its docstring is the clearest statement available:
**"ADK is durable-only, so there is no native session DB path"** — reconstruction always comes
from OE `previous_state`. **[wheel]**

On ADK, durability is the platform's, with no opt-out and no database knob. None of this
appears in any guide page.

## What is not documented?

State these as gaps rather than extrapolating:

- **Collection names** `checkpoints` / `checkpoint_writes` — right for the saver's defaults, but
  absent from every AAE page.
- **Any per-checkpoint size limit.** 16 MB is MongoDB's, not a documented AAE rule.
- **Whether checkpoints and memory share one database.** The SDK source says all platform
  stores live in one; the limitations page scopes a narrow user to both `MDB_AGENTIC_STORE_DB`
  **and** `MONGOMEM_DB_NAME`. Unresolved — what is safe is that checkpoints follow
  `MDB_AGENTIC_STORE_DB` and never share the `checkpoints` collection with memory.
- **The exact failure mode when you omit the checkpointer.** The `None` return is verified from
  source; what LangGraph then does on `interrupt()` is untested.
- **How a user selects native-checkpoint vs durable-workflow mode.** The package page assumes
  you know, and links to a docs path that is not public.
- **Retention, purge, archival or quota** — nothing, anywhere.
