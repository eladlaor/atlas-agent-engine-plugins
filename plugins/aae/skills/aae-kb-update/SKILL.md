---
name: aae-kb-update
description: "Promote generic MongoDB Atlas Agent Engine (AAE) findings from the user's personal aae-guide notes into the shipped aae-kb-read knowledge base, in a local clone of the plugin repository. Proposes each new generic entry with project-specific details stripped, and edits nothing until the user approves. Use when the user says \"update the kb\", \"promote my AAE notes\", \"ship what I learned\", \"aae-kb-update\", or \"add this to the plugin's knowledge base\"."
---

# AAE KB Update

- [Summary](#summary)
- [Inputs](#inputs)
- [Hard rules](#hard-rules)
- [Procedure](#procedure)
- [What counts as generic](#what-counts-as-generic)
- [Leak scan](#leak-scan)

## Summary

`aae-guide` writes what it learns to the user's **personal notes**, never to the shipped
knowledge base. This skill is the deliberate step that moves the **generic** part of
those notes into `aae-kb-read`, so every user of the plugin gets it on the next update.
It proposes, the user approves, then it edits a local clone of the plugin repository.
It never commits or publishes.

## Inputs

- **Personal notes.** Default: `~/.claude/agent-memory/aae-guide/MEMORY.md`. The user
  may name other files instead, for example in Codex, where that directory doesn't exist.
- **The plugin repository clone.** The path the user gives, or ask for it. It is valid
  only if `plugins/aae/skills/aae-kb-read/references/` exists under it **and** it is a git
  working tree (`git -C <path> rev-parse --is-inside-work-tree`). If either check fails,
  stop and say why.

## Hard rules

- **Never edit the installed plugin** (anything under `~/.claude/plugins/` or
  `~/.codex/`). A plugin update overwrites it, and nobody else would ever see the change.
- **No edits before approval.** Show the full proposal first, then apply only the
  entries the user approved.
- **The knowledge base is public.** Nothing project-specific may go in. When unsure,
  leave the entry out and say so.
- **Never change the personal notes**, except to mark promoted entries, and only if the
  user agrees (step 7).
- **No git.** The user commits and releases when they choose to.

## Procedure

1. **Read** the personal notes, the `aae-kb-read` `SKILL.md` index, and every reference
   file a candidate entry could belong to.
2. **Classify** each entry in the notes as one of:
   - **already shipped:** the same fact is in a reference file, at the same or a newer
     date. Skip it.
   - **project-specific:** see [What counts as generic](#what-counts-as-generic). Skip it.
   - **generic and new, or newer than the shipped version:** a candidate.
3. **Rewrite each candidate** for a public reader:
   - strip everything listed under [Leak scan](#leak-scan), using placeholders such as
     `<project_id>` and `<workspace_id>`;
   - phrase it neutrally ("the CLI reports…", not "I saw…");
   - keep its date, and its CLI or SDK version where that matters;
   - use the format of the target file: drift entries as *Docs say / Observed /
     Resolution*, newest first; runbooks as numbered steps; troubleshooting as a
     question heading.
4. **Choose a target** for each one: the reference file and section, using the
   `aae-kb-read` index. Replace an older shipped entry rather than duplicating it.
5. **Propose** a single table and wait:

   | # | Source entry (date) | Target file › section | New or replaces | What was stripped |
   |---|---|---|---|---|

   Under it, show the exact text of each proposed entry. Also list the skipped entries in
   one line each, with the reason, so the user can overrule a skip.
6. **Apply** only the approved entries:
   - Edit the reference files in the clone.
   - Keep each file's TOC accurate.
   - Add one terse line per change under `[Unreleased]` in the repository's
     `CHANGELOG.md`, in Keep a Changelog form.
   - If a new reference file was needed, add it to the `aae-kb-read` index too.
7. **Verify:**
   - Run the [leak scan](#leak-scan) over the changed files.
   - Check that each changed file's TOC anchors still resolve.
   - Report the files changed.
   - Offer to mark the promoted entries in the personal notes with
     `(promoted YYYY-MM-DD)`, so the next run skips them.

## What counts as generic

**Generic**, so promote it: true for any AAE user on the same CLI or SDK version. That
covers platform behavior, CLI quirks, drift from the docs, doc contradictions, limits,
working runbooks, and misdiagnoses worth warning about.

**Project-specific**, so skip it:
- the user's org, project, workspace and context IDs and names;
- their cluster names and regions;
- their agents and repositories;
- their model gateway and its hostname;
- their machine setup;
- their team's internal processes;
- anything learned only from a private source, such as internal chat, a ticket tracker
  or enterprise search. Private knowledge does not become public by being rephrased.

## Leak scan

Before proposing anything, and again after applying it, search the text for:

- 24-hex-character IDs (`[0-9a-f]{24}`), `ws-` IDs, and build or deploy IDs;
- hostnames that aren't public docs or product hosts, and any `corp`/`internal` domain;
- names of people, teams, customers, or private repositories;
- local paths (`/Users/`, `/home/`), secret-manager references (`op://`), and model
  aliases named after a person;
- Slack channels and ticket keys.

Report every hit. Either remove it, or explain why it is public and keep it.
