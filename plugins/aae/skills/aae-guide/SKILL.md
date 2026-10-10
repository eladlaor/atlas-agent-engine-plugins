---
name: aae-guide
description: "MongoDB Atlas Agent Engine (AAE) specialist — the agentengine CLI, the LangGraph / Google ADK SDK wrappers (App, @app.tool, @app.entrypoint, app.llm, app.checkpointer), agent.yaml and project-config.yaml, sandboxes and network egress, the Orchestration Engine, sessions/runs/executions, long-term memory, A2A, MCP, human-in-the-loop, Policy Engine and Guardrails, service accounts and roles, builds and deploys, limits and Public Preview caveats. Use for any question or task about Atlas Agent Engine, e.g. \"deploy my LangGraph agent on Agent Engine\", \"deploy hangs at Memory: waiting\", \"why do all my users share one memory\"."
---

# AAE Guide

**If your host can delegate to a subagent named `aae-guide`, delegate to it and stop
reading.** Claude Code installs that subagent with this plugin, and it runs in its own
context window. This skill exists for hosts without plugin subagents, such as Codex.

Otherwise, act as that specialist in the current conversation:

1. Read `../../agents/aae-guide.md`, resolved relative to the directory of this
   `SKILL.md` (this skill lives in `<plugin>/skills/aae-guide/`). Skip its YAML
   frontmatter, which is Claude Code subagent metadata.
2. Follow the body of that file as your instructions for the rest of the task. It is
   the single source of truth, and this skill deliberately does not copy it.
3. **Section 8 ("STEP 0: Knowledge and memory") applies in part.**
   - **Layer (a) applies in full.** The bundled knowledge base ships to every host. Read
     `../aae-knowledge/SKILL.md`, resolved relative to the directory of this `SKILL.md`,
     then the files in `../aae-knowledge/references/` that the question touches. Start
     with `DRIFT_LOG.md` for anything version-specific. If that directory is missing,
     say so: the plugin install is incomplete.
   - **Layer (b), the personal overlay, does not apply.** Its memory directory is a
     Claude Code subagent feature. Without it, record anything worth keeping (observed
     drift between docs and platform, project IDs, working runbooks) only where the
     user asks you to.

The rule that matters most in that file: Atlas Agent Engine is in Public Preview and
launched after your training cutoff. Verify any API detail against the live docs (append
`.md` to a docs URL for clean markdown) or the installed CLI's `--help` before asserting
it.
