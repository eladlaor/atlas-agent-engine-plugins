---
name: aae-kb-read
description: "The aae-guide's bundled MongoDB Atlas Agent Engine (AAE) knowledge base: a dated drift log of where the live platform and CLI disagree with the docs, verified details the guides omit (OpenAPI-only endpoints, Policy Engine types, cost accounting, OTLP export), doc contradictions, CLI targeting rules, monorepo and build-archive rules, SDK adapter facts, numbered runbooks (first deploy, connect an external client, recover after a cluster pause), troubleshooting traps, and how this plugin complements the skills the agentengine CLI installs. Load it when answering or acting on any AAE question, before relying on the aae-guide card's 2026-10-10 snapshot."
---

# AAE KB Read

The baseline knowledge the `aae-guide` specialist carries beyond its card. Every entry is
dated and, where it matters, pinned to a CLI or SDK version. **Freshness is the point:**
AAE is in Public Preview, and a fact here is a strong prior, not a guarantee. Re-verify
against the live docs (append `.md` to a docs URL) or the installed CLI's `--help` before
asserting anything version-specific.

## How to use it

1. Resolve paths relative to this `SKILL.md`: the files below live in `references/`.
2. Read only the files the question touches. The index says when each one applies.
3. **When this knowledge and the `aae-guide` card disagree, the newer dated entry wins.**
   The card's sections 3 to 7 are a 2026-10-10 snapshot; check the dates when a file here disagrees.
4. If the user keeps a personal overlay (Claude Code: `~/.claude/agent-memory/aae-guide/MEMORY.md`),
   apply the same rule between the overlay and this baseline: newer dated entry wins, then
   re-verify against the live docs.

## Index

| File | Holds | Read it when |
|---|---|---|
| [DRIFT_LOG.md](references/DRIFT_LOG.md) | Dated "docs say / observed / resolution" entries, newest first | Before asserting any CLI behavior, egress IP, package name, or config key; whenever live behavior surprises you |
| [VERIFIED_DETAILS.md](references/VERIFIED_DETAILS.md) | Facts the guides omit or bury: extra limits, the OpenAPI spec as the freshest source, OTLP trace export, Policy Engine types, the `a2a:` block's real nature, memory scoping and config keys, creation paths, the Voyage key, the A2A signing secret | "Does AAE support X?", "is there an endpoint for X?", memory design, governance questions |
| [DOC_CONTRADICTIONS.md](references/DOC_CONTRADICTIONS.md) | Places where AAE doc pages contradict each other, and which are resolved | Before quoting a package name, an `agent.yaml` minimum, a `secret set` syntax, or `allowed_callers` enforcement |
| [CLI_TARGETING_AND_CONTEXTS.md](references/CLI_TARGETING_AND_CONTEXTS.md) | Context vs pin vs workspace, `--context` takes a display name, explicit target flags, which `deploy` verbs are read-only | Any CLI sequence; "context not found"; working from a git worktree; diagnosing without mutating |
| [MONOREPO_AND_BUILD.md](references/MONOREPO_AND_BUILD.md) | What `create` scaffolds, the two `agent.yaml` schemas, monorepo conversion, naming, adding an agent, the build archive root, `.agentengineignore`, multi-agent deploy flags | Repo layout, adding or renaming agents, shared libraries, "why did the build upload X?" |
| [SDK_ADAPTERS.md](references/SDK_ADAPTERS.md) | LangGraph vs ADK `App` surface (from SDK wheels), `deep_agent`, where model calls run, the test harness, PyPI and the Python 3.14 trap | Choosing a framework, porting between them, unit-testing an agent, package install failures |
| [IDENTITY_ATLAS_AND_AUTH.md](references/IDENTITY_ATLAS_AND_AUTH.md) | How AAE projects and orgs relate to Atlas ones, the Atlas service account for `atlas setup`, MongoDB as a hard requirement, service-account roles | Org/project ID confusion, `atlas setup` auth failures, "do I need Atlas?", role choice |
| [TOKEN_AND_COST_ACCOUNTING.md](references/TOKEN_AND_COST_ACCOUNTING.md) | How tokens and cost are captured, the `cost/dashboard` endpoint, gateway pricing gaps, A2A roll-up, retention unknowns | Any cost, token, usage, or budget question |
| [A2A_AND_CAPABILITY_GAPS.md](references/A2A_AND_CAPABILITY_GAPS.md) | A2A token lifetime and ACL, and what AAE does not ship: RAG, evals, scheduling, with what to build on instead | A2A design, "does AAE have RAG / evals / cron?" |
| [RUNBOOKS.md](references/RUNBOOKS.md) | Numbered procedures: first deploy, build-and-verify on the platform, connect an external client, recover after the Atlas cluster pauses | Doing any of those tasks |
| [TROUBLESHOOTING.md](references/TROUBLESHOOTING.md) | Symptom-first Q&A: misleading errors, gateway failures, paused clusters, half-finished `init`, and the misdiagnoses that recur | A user reports an error or odd behavior |
| [CLI_SKILLS_AND_THIS_PLUGIN.md](references/CLI_SKILLS_AND_THIS_PLUGIN.md) | The skills `agentengine init` installs into each project, what this plugin adds on top of them, and which one answers which question | Working inside a project that has `.claude/skills/` or `.agents/skills/` from the CLI; "why use this plugin?" |
| [FIRST_DEPLOY_EXPLAINED.md](references/FIRST_DEPLOY_EXPLAINED.md) | Q&A teaching write-up of the first-deploy setup | Teaching or recapping how login, context, workspace, Atlas setup and secrets fit together |

## Recording new findings

This skill ships read-only with the plugin. Write new dated findings to the user's own
overlay (see step 4 above) in the shape the drift log uses:

```
### <YYYY-MM-DD> — <one-line symptom> (CLI <version>)
Docs say: <quote or page>
Observed: <what actually happened>
Resolution: <what to do>
```

Findings that hold for every AAE user reach this knowledge base only through the
`aae-kb-update` skill, which proposes them with project details stripped and edits a clone
of the plugin repository after the user approves.
