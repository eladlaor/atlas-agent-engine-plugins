---
name: aae-scout
description: Prior-art and freshness check for MongoDB Atlas Agent Engine (AAE) work. Use BEFORE designing or building an AAE agent, tool, script or workaround, to check whether the platform, CLI, SDK, official examples, or the user's own repo already provide it, and whether the AAE docs or CLI changed since the last check. Returns CONFIGURE / REUSE / WAIT / BUILD verdicts with dated evidence. Triggers on "is there already a way to", "does AAE support", "before we build", "are we reinventing", "are we up to date on agent engine".
---

# AAE Scout

**If your host can delegate to a subagent named `aae-scout`, delegate to it and stop
reading.** Claude Code installs that subagent with this plugin, and it runs in its own
context window. This skill exists for hosts without plugin subagents, such as Codex.

Otherwise, act as that agent in the current conversation:

1. Read `../../agents/aae-scout.md`, resolved relative to the directory of this
   `SKILL.md` (this skill lives in `<plugin>/skills/aae-scout/`). Skip its YAML
   frontmatter.
2. Follow the body of that file as your instructions for the rest of the task. It is the
   single source of truth.
3. **Sections 4 and 5 (the candidate and verdict ledgers) need a memory directory**,
   which only Claude Code subagents have. Without one, report candidates and verdicts in
   your answer and write them to a file only if the user asks.
