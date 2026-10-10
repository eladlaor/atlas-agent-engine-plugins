---
name: aae-doc-contradictions
description: Places where Atlas Agent Engine doc pages contradict each other, with resolution status and dates.
---

# AAE doc contradictions

- [Summary](#summary)
- [1. SDK package names](#1-sdk-package-names)
- [2. TypeScript LangGraph SDK package name](#2-typescript-langgraph-sdk-package-name)
- [3. `agent.yaml` minimum](#3-agentyaml-minimum)
- [4. `agentengine api-key create`](#4-agentengine-api-key-create)
- [5. `secret set NAME VALUE` vs `--value`](#5-secret-set-name-value-vs---value)
- [6. `get_current_custom_headers` import path](#6-get_current_custom_headers-import-path)
- [7. Is `allowed_callers` enforced?](#7-is-allowed_callers-enforced)
- [8. Which directory to run `dev up` from](#8-which-directory-to-run-dev-up-from)
- [9. Is the flat project layout deprecated?](#9-is-the-flat-project-layout-deprecated)
- [10. Which files does `init` generate?](#10-which-files-does-init-generate)
- [11. Four memory types or six?](#11-four-memory-types-or-six)

## Summary

These are contradictions **inside** the AAE docs. Do not resolve an open one from memory:
tell the user it is ambiguous, and test it. When one resolves, record the date and the
evidence here (or in the user's overlay).

| # | Topic | Status |
|---|---|---|
| 1 | SDK package names | Resolved 2026-10-05: `agent-engine-sdk-*` |
| 2 | TypeScript package name | Likely resolved 2026-10-06 |
| 3 | `agent.yaml` minimum | Leaning resolved 2026-10-08: `sandboxes` required |
| 4 | `api-key create` | Resolved 2026-10-08: real, deprecated |
| 5 | `secret set` value syntax | Resolved 2026-10-04: both forms deprecated |
| 6 | Custom-headers import path | Open |
| 7 | `allowed_callers` enforcement | Open |
| 8 | `dev up` working directory | Open |
| 9 | Flat layout status | Open |
| 10 | Files `init` generates | Open |
| 11 | Memory type count | Open |

## 1. SDK package names

- `create-project` and `migrate` say `uv add agent-engine-runner-shared agent-engine-sdk-langgraph`.
  `ci-cd` has a "Do Not Declare the SDK Packages" section naming them `agentengine-langgraph` /
  `agentengine-core` / `runner-shared` / `agentengine-memory`; its own troubleshooting row
  names `agent-engine-sdk-langgraph`.
- **Resolved 2026-10-05:** `agent-engine-sdk-*` is correct. The packages are on a
  token-gated index and on public PyPI. See
  [VERIFIED_DETAILS.md](VERIFIED_DETAILS.md#sdk-packages-where-they-are-published).

## 2. TypeScript LangGraph SDK package name

- Never stated on the guide pages.
- **Likely resolved 2026-10-06:** `llms.txt` lists `@mongodb-js/agent-engine-sdk-langgraph`.
  Confirm on the page before relying on it.

## 3. `agent.yaml` minimum

- The contract reference's example shows `entrypoint` alone; create-project and migrate say
  `sandboxes` is also required.
- **2026-10-08:** the contract reference's schema table now marks `sandboxes` and
  `sandboxes.agent` as required, while its own minimal example still shows only `entrypoint`.
  Declare `sandboxes.agent` always.

## 4. `agentengine api-key create`

- Appears on the CI/CD page but not in the CLI command list.
- **Resolved 2026-10-08:** the command is real, but `api-key --help` says API keys are
  deprecated in favor of `agentengine service-account`. The CI/CD page still instructs
  `api-key create`.

## 5. `secret set NAME VALUE` vs `--value`

- **Resolved 2026-10-04** (`secret set --help`): both are deprecated. Omit the value for a
  hidden prompt, or pipe with `--stdin`. `--sync` waits until running deployments use the new
  value; `agentengine secret sync` reloads values already stored on the platform.
- **The docs had not caught up on 2026-10-05:** `/deploy/provision-secrets.md` still shows the
  positional VALUE, with literal secrets on the command line. Trust `--help`.

## 6. `get_current_custom_headers` import path

- `agent_engine_runner_shared` on one page, `agent_engine_runner_shared.context` on another.
- **Open.** Check the installed package.
- Related, verified from the SDK 0.11.8 wheel: custom headers arrive lower-cased;
  `get_current_custom_headers()` strips `a2a-*` headers while `get_all_custom_headers()`
  keeps them (`a2a-caller-workspace` marks an A2A dispatch).

## 7. Is `allowed_callers` enforced?

- The A2A page: "The OE checks the calling agent's identity against your allowed_callers list"
  (403 otherwise).
- The limitations page, Agent Isolation: "The Orchestration Engine does not enforce
  authentication or authorization against the calling agents."
- Both live on 2026-10-08. **Open and untested.** Do not rely on `allowed_callers` as a
  security boundary; use separate projects.

## 8. Which directory to run `dev up` from

- `get-started.md`: "Run all subsequent `agentengine` commands from your agent directory."
- `add-features/memory.md`: "Run the following command from the project root: `agentengine dev up`."
- **Open** (2026-10-08). Tell users it is ambiguous; in a monorepo see the `shared/` limitation
  in [DRIFT_LOG.md](DRIFT_LOG.md).

## 9. Is the flat project layout deprecated?

- `create-project.md` documents a flat single-directory manual setup as current.
- `add-features/memory.md`: "If your project uses a flat structure with `agent.yaml` at the
  project root, migrate to the two-level structure before enabling memory. The flat structure
  is deprecated."
- **Open** (2026-10-08). Prefer the two-level layout.

## 10. Which files does `init` generate?

- `cli/agentengine_init.md`: `.agentengine/` and `.devcontainer/devcontainer.json`.
- `create-project.md`: `docker-compose.yml`, `.agentengine/Dockerfile`,
  `.agentengine/entrypoint.py`, `.dockerignore`, `.gitignore`.
- Neither page mentions the other's files. **Open** (2026-10-08).

## 11. Four memory types or six?

- `/add-features/memory-types.md` documents four; the scaffolded `project-config.yaml` and the
  sample in `/add-features/memory.md` list six (adding `entity` and `preferences`).
- **Open and untested** (2026-10-08).
