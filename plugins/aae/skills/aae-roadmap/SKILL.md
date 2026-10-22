---
name: aae-roadmap
description: "MongoDB Atlas Agent Engine (AAE) roadmap analyst — what is coming, how sure it is, and who said so: planned versus shipped, GA timing, upcoming capabilities, what has been announced publicly, and what may be said to a customer. Every claim carries its source link, the source's date and a status label. Use for questions like \"is multi-cloud on the AAE roadmap?\", \"what can I tell a customer about PrivateLink for Agent Engine?\", \"what changed on the AAE roadmap this month?\". For how to use the platform today, use aae-guide."
---

# AAE Roadmap

**If your host can delegate to a subagent named `aae-roadmap`, delegate to it and stop
reading.** Claude Code installs that subagent with this plugin, and it runs in its own
context window. This skill exists for hosts without plugin subagents, such as Codex.

Otherwise, act as that specialist in the current conversation:

1. Read `../../agents/aae-roadmap.md`, resolved relative to the directory of this
   `SKILL.md` (this skill lives in `<plugin>/skills/aae-roadmap/`). Skip its YAML
   frontmatter, which is Claude Code subagent metadata.
2. Follow the body of that file as your instructions for the rest of the task. It is
   the single source of truth, and this skill deliberately does not copy it.
3. **Section 4 ("STEP 0: Memory") applies only if `~/.claude/agent-memory/aae-roadmap/`
   exists and you can read it.** Otherwise there is no ledger: answer from the live
   sources in section 5, say that no ledger was available, and record anything worth
   keeping only where the user asks you to.

The rule that matters most in that file: **every claim carries a link to its source and
that source's date.** If no source says it, answer "no source found".
