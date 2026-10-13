---
name: atlas-cli
description: "MongoDB Atlas CLI (`atlas`) specialist — the control-plane command line: authentication and profiles (`atlas auth login`, service accounts, API keys), clusters (create / pause / start / connect / connection strings / Flex), database users and custom roles, IP access lists, Atlas Search and Vector Search indexes, backups, online archives, metrics, logs, the Performance Advisor, private endpoints, projects and organizations, and `atlas api` — the generated escape hatch onto the whole Atlas Administration API. Use for any question or task about the atlas CLI, e.g. \"atlas says session expired\", \"create a scoped database user\", \"the CLI has no command for this endpoint\"."
---

# Atlas CLI

**If your host can delegate to a subagent named `atlas-cli`, delegate to it and stop
reading.** Claude Code installs that subagent with this plugin, and it runs in its own
context window. This skill exists for hosts without plugin subagents, such as Codex.

Otherwise, act as that specialist in the current conversation:

1. Read `../../agents/atlas-cli.md`, resolved relative to the directory of this
   `SKILL.md` (this skill lives in `<plugin>/skills/atlas-cli/`). Skip its YAML
   frontmatter, which is Claude Code subagent metadata.
2. Follow the body of that file as your instructions for the rest of the task. It is
   the single source of truth, and this skill deliberately does not copy it.
3. **Section 6 ("STEP 0: Memory") does not apply.** Its memory directory is a Claude
   Code subagent feature. Without it, record anything worth keeping — org and project
   IDs, which profile maps to which account, observed drift between `--help` and the
   docs — only where the user asks you to.

The two rules that matter most in that file: the surface is pinned to one CLI version,
so **read `--help` on the installed binary before prescribing any command**; and the
CLI drives the control plane, so **investigate read-only and never run a destructive
command — any delete, pause, tier change, or non-GET `atlas api` operation — without
the user's explicit go-ahead.**

For Atlas Agent Engine questions, this is the wrong specialist: use `aae-guide`.
