---
name: aae-sdk-adapters
description: The LangGraph and Google ADK App surfaces as verified from the SDK wheels (0.11.7 and 0.11.8), deep_agent, where model calls run, the in-process test harness, and install traps.
---

# SDK adapters: LangGraph vs Google ADK

- [Summary](#summary)
- [What do the two adapters share?](#what-do-the-two-adapters-share)
- [What can only the LangGraph adapter do?](#what-can-only-the-langgraph-adapter-do)
- [Does code port between them?](#does-code-port-between-them)
- [Is `deep_agent` a platform feature or a LangGraph one?](#is-deep_agent-a-platform-feature-or-a-langgraph-one)
- [Where do model calls actually run?](#where-do-model-calls-actually-run)
- [How do I unit-test an agent without deploying it?](#how-do-i-unit-test-an-agent-without-deploying-it)
- [What do input, output and headers look like at runtime?](#what-do-input-output-and-headers-look-like-at-runtime)
- [Why did the SDK install as version 0.0.0?](#why-did-the-sdk-install-as-version-000)

## Summary

Verified by installing the wheels and reading the `App` classes, not from the docs:
SDK **0.11.7** on 2026-10-05, **0.11.8** on 2026-10-10. Re-verify on any SDK bump.

- The shared contract is tiny; "the SDK" is not one interface.
- LangGraph has 14 `App` methods ADK lacks, including guardrails, A2A, checkpointer and
  `deep_agent`. ADK has none LangGraph lacks.
- Tool bodies port; `main.py` is a rewrite.
- **Pick LangGraph** if you want deep agents, guardrails hooks or A2A helpers out of the box.

## What do the two adapters share?

`agent_engine_sdk/app.py` defines `BaseApp(ABC)` with exactly four abstract members:
`tool()`, `tools()`, `get_tool_definitions()`, `entrypoint()`. Both adapters subclass it.

Also present on both: `agent_config`, `memory`, `llm()`, `get_agent()`, `run()`,
`get_current_user_id()`.

## What can only the LangGraph adapter do?

LangGraph-only (14): `prepare_agent_input()`, `resolve_thread_id()`, `output_parser()`,
`warm_up()`, `deep_agent()`, `checkpointer()`, `close()`, `get_tools()`,
`get_tool_schemas()`, `suspend()`, `finish_session()`, `validate_llm_response()`,
`validate_output()`, `a2a_tools()`.

What that means on ADK:

- **Guardrails** (`validate_llm_response`, `validate_output`) and **A2A** (`a2a_tools`) have no
  `App`-level entry point.
- No `checkpointer()`: durability is the platform's, with no opt-out. LangGraph can fall back
  to `native_checkpoint`; ADK has no `durable_workflow: false` fallback.
- Suspend / human-in-the-loop exists as **module-level functions in
  `agent_engine_sdk_adk/suspend.py`**, not `app.suspend()`. Use native ADK constructors on the
  callables returned by `app.tools()`, never on the raw `@app.tool` function:
  `FunctionTool(fn, require_confirmation=True)`, `LongRunningFunctionTool(fn)`.

## Does code port between them?

| | ADK | LangGraph |
|---|---|---|
| `llm(x)` takes / returns | `BaseLlm` → `SecureLlm` | `BaseChatModel` → `SecureWrappedLLM` |
| `@entrypoint` returns | an ADK agent (`LlmAgent`) | a `CompiledStateGraph` |
| Tool list accessor | `tools()` only | `tools()`, `get_tools()`, `get_tool_schemas()` |

`@app.tool` bodies port nearly unchanged (same kwargs: `is_local`, `network`, `timeout`,
`redact_fields`). `main.py` is a rewrite. Moving off ADK early is cheap.

## Is `deep_agent` a platform feature or a LangGraph one?

Both names exist, and they are different things.

- **`features.deep_agent` in `agent.yaml`** is framework-neutral. It gates registration of
  the tool sandbox's built-in `filesystem_ls/read/write/edit/glob/grep/download` and
  `shell_execute` handlers. Default **off**, deliberately, so agents that don't need them get
  no filesystem or shell attack surface.
- **`App.deep_agent(llm, *, tools, subagents, system_prompt, middleware, checkpointer, store,
  skills, backend)`** is **LangGraph-only**. It returns a `CompiledStateGraph` to use inside
  `@app.entrypoint`, wraps the model itself, and defaults the backend to the tool-sandbox
  backend. It rejects string model specs in subagents to prevent bypassing the Orchestration
  Engine. (So do not wrap the LLM in `app.llm()` before passing it in.)
- The ADK adapter has **no** client wiring to those built-in handlers. The handlers implement
  LangChain's `deepagents` protocols by name, so `deep_agent()` is the LangGraph adapter
  exposing a LangChain library, not a platform primitive ADK forgot. ADK's own delegation
  (`sub_agents` + `transfer_to_agent`) works; the filesystem-as-memory layer is what you would
  hand-roll on ADK.

## Where do model calls actually run?

Every `app.llm()` call is routed through the Orchestration Engine, which is why calls made
outside the wrapper are unaudited, unpriced and do not replay on resume.

Which **sandbox** makes the provider request depends on configuration:

- The SDK 0.11.8 `SecretsConfig` comment: "`invoke_llm` is a reserved key: the platform runs
  model calls in a tool pod". The contract reference: the tool sandbox loads your entrypoint
  lazily, "triggered by the first `invoke_llm` call", and to call an LLM from the tool sandbox
  you list `invoke_llm` in `sandboxes.tool.tools` and declare the key under
  `sandboxes.tool.secrets`.
- **Practical rule:** give **both** sandboxes the LLM key and the gateway egress entry. The
  tell-tale symptom of missing it: a direct HTTP probe from the agent works, but `app.llm()`
  reports "Connection error".

## How do I unit-test an agent without deploying it?

SDK 0.11.8 ships an in-process harness: `agent_engine_sdk_langgraph.testing` provides
`FakeChatModel`, `build_test_graph(app, llm)`, `build_test_agent`, and
`execution_context(user_id=…, custom_headers=…)`. Set `RUNNER_MODE=tool` **before** the app
module is imported. AAE itself ships no eval framework; see
[A2A_AND_CAPABILITY_GAPS.md](A2A_AND_CAPABILITY_GAPS.md).

## What do input, output and headers look like at runtime?

From the SDK 0.11.8 wheel:

- Default input: `payload["message"]` becomes one `HumanMessage`, plus `user_id` and
  `session_id` keys. Hooks to change that: `@app.prepare_agent_input`,
  `@app.resolve_thread_id`, `@app.output_parser`.
- Output: `AgentOutput.response["response"]` is the last AI message content. That is what an
  A2A caller receives as `result`.
- A2A from code: `app._runtime.a2a` is the direct client (documented, but no public accessor).
  `AgentResponse.status` is `completed`, `failed` or `input-required`. `invoke_agent` takes no
  session parameter.
- Custom headers arrive lower-cased. `get_current_custom_headers()` strips `a2a-*` headers;
  `get_all_custom_headers()` keeps them.
- `app.memory`: explicit `user_id` arguments win over the ambient identity.
  `save_semantic(..., upsert=True)` upserts by label.
- `agentengine invoke` has `--user-id` and `--payload` but **no custom-header flag**; use the
  REST API to test headers.

## Why did the SDK install as version 0.0.0?

Installing `agent-engine-sdk-langgraph` under **Python 3.14** silently resolves to
`agent_engine_sdk_langgraph_placeholder` 0.0.0: no error, just a stub. Use Python **3.11 or
3.12** (templates pin `requires-python >=3.11`). When a package resolves to 0.0.0, suspect the
interpreter version before concluding the package is unpublished.

Separately, public PyPI's `agentic-platform-memory` is a 0.0.1 placeholder; the memory SDK is
`agent-engine-sdk-memory` (see [DRIFT_LOG.md](DRIFT_LOG.md)).
