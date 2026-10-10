---
name: aae-kb-update
description: "Update the aae-guide's MongoDB Atlas Agent Engine (AAE) knowledge from one of two sources. Notes mode promotes generic findings from the user's personal aae-guide notes into the shipped aae-kb-read knowledge base, in a local clone of the plugin repository, proposing first and editing only after approval. Docs mode applies the docs watcher's latest changes report: it finds the knowledge entries that rest on each changed page, and confirms, corrects or extends them. Use when the user says \"update the kb\", \"promote my AAE notes\", \"ship what I learned\", \"apply the docs changes to the kb\", \"update the kb from the docs diff\", \"aae-kb-update\", or \"add this to the plugin's knowledge base\". Arguments: notes | docs [--auto] [--repo <path>]."
---

# AAE KB Update

- [Summary](#summary)
- [Choosing the mode](#choosing-the-mode)
- [Rules for both modes](#rules-for-both-modes)
- [The processed-report record](#the-processed-report-record)
- [Notes mode](#notes-mode)
  - [Notes mode: inputs](#notes-mode-inputs)
  - [Notes mode: hard rules](#notes-mode-hard-rules)
  - [Notes mode: procedure](#notes-mode-procedure)
- [Docs mode](#docs-mode)
  - [Docs mode: inputs](#docs-mode-inputs)
  - [Docs mode: hard rules](#docs-mode-hard-rules)
  - [Docs mode: procedure](#docs-mode-procedure)
  - [Docs mode: the --auto summary](#docs-mode-the---auto-summary)
- [What counts as generic](#what-counts-as-generic)
- [Leak scan](#leak-scan)

## Summary

The shipped knowledge base (`aae-kb-read` and the `aae-guide` card) changes only through
this skill. It has two sources, kept apart on purpose:

| Mode | Source | Writes to | Approval |
|---|---|---|---|
| **notes** | The user's personal `aae-guide` notes | Reference files in a git clone of the plugin repository | Always: proposes, edits only what the user approves |
| **docs** | The docs watcher's latest changes report: `report.json`, `diffs/`, `pages/` | Reference files and the guide card in the clone (or the notes, without a clone); user-specific consequences in the notes | Interactive by default; `--auto` applies without asking, for the opt-in watcher flow only |

It never commits, publishes, or edits an installed plugin.

## Choosing the mode

- Take the mode from the first argument (`notes` or `docs`), else from the request:
  "promote my notes", "ship what I learned" mean notes mode; "apply the docs changes",
  "the docs changed, update the kb" mean docs mode.
- If neither makes it clear, ask which one. Don't guess.
- `--auto` is valid **only** with `docs`. With `notes`, or with no mode, refuse it and say
  why: promoting personal notes into a public knowledge base always needs a person.
- `--repo <path>` names the plugin repository clone. Without it, use env `AAE_KB_REPO`.

## Rules for both modes

- **Never edit the installed plugin** (anything under `~/.claude/plugins/` or
  `~/.codex/`). A plugin update overwrites it, and nobody else would ever see the change.
- **No git.** The user commits and releases when they choose to.
- **A valid clone** has `plugins/aae/skills/aae-kb-read/references/` under it **and** is a
  git working tree: `git -C <path> rev-parse --is-inside-work-tree` interactively; in
  `--auto`, where no shell is available, check that `<path>/.git` exists. If either check
  fails, stop and say why.
- **Edits keep the target file's shape:** drift entries as *Docs say / Observed /
  Resolution*, newest first; runbooks as numbered steps; troubleshooting as a question
  heading. Keep each changed file's TOC accurate, and replace an older entry rather than
  duplicating it.
- **Every change to the clone gets one terse line** under `[Unreleased]` in its
  `CHANGELOG.md`, in Keep a Changelog form. If a new reference file was needed, add it to
  the `aae-kb-read` index too.

## The processed-report record

Docs mode records each watcher report it has dealt with, so the same report is never
applied twice. The file is `kb-update-processed` in the watcher's state directory: one
line per report, tab-separated:

```
<report checked_at>	<date processed, YYYY-MM-DD>	<docs-auto | docs-interactive>
```

Append the line after applying, also when nothing needed editing or the user approved
nothing: the report has been dealt with. Before starting, if the report's `checked_at` is
already in the file, stop and say when it was processed. **Write nothing at all** in that
case: no edit, no new line, and in `--auto` no `kb-update.md` either, because that file
still holds the summary of the run that did process the report.

## Notes mode

`aae-guide` writes what it learns to the user's **personal notes**, never to the shipped
knowledge base. Notes mode is the deliberate step that moves the **generic** part of
those notes into `aae-kb-read`, so every user of the plugin gets it on the next update.
It proposes, the user approves, then it edits a local clone of the plugin repository.

### Notes mode: inputs

- **Personal notes.** Default: `~/.claude/agent-memory/aae-guide/MEMORY.md`. The user
  may name other files instead, for example in Codex, where that directory doesn't exist.
- **The plugin repository clone.** `--repo`, `AAE_KB_REPO`, or ask for it. Validate it as
  in [Rules for both modes](#rules-for-both-modes).

### Notes mode: hard rules

- **No edits before approval.** Show the full proposal first, then apply only the
  entries the user approved.
- **The knowledge base is public.** Nothing project-specific may go in. When unsure,
  leave the entry out and say so.
- **Never change the personal notes**, except to mark promoted entries, and only if the
  user agrees (step 7).

### Notes mode: procedure

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
   - use the format of the target file.
4. **Choose a target** for each one: the reference file and section, using the
   `aae-kb-read` index. Replace an older shipped entry rather than duplicating it.
5. **Propose** a single table and wait:

   | # | Source entry (date) | Target file › section | New or replaces | What was stripped |
   |---|---|---|---|---|

   Under it, show the exact text of each proposed entry. Also list the skipped entries in
   one line each, with the reason, so the user can overrule a skip.
6. **Apply** only the approved entries, in the clone, with the CHANGELOG line.
7. **Verify:**
   - Run the [leak scan](#leak-scan) over the changed files.
   - Check that each changed file's TOC anchors still resolve.
   - Report the files changed.
   - Offer to mark the promoted entries in the personal notes with
     `(promoted YYYY-MM-DD)`, so the next run skips them.

## Docs mode

The docs watcher (`aae-docs-watch`) says **which** pages changed. Docs mode works out
**what that means for the knowledge**: which entries rest on a changed page, whether they
still hold, and what new fact is worth recording. Docs content is public, so its text
needs no leak scan.

### Docs mode: inputs

- **The watcher state directory:** `${AAE_WATCH_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/aae-docs-watch}`,
  or the path you were given.
  - `report.json`: `status`, `checked_at`, and the `changed`, `added`, `removed` URL lists.
  - `diffs/<slug>.diff`: the unified diff for a changed page.
  - `pages/<slug>`: the current markdown of a page, used for added pages.
  - The slug is the URL without `https://www.mongodb.com/docs/agentengine/`, with each
    `/` replaced by `__`. Use only the diffs for URLs in the current `changed` list; the
    directory keeps older ones.
- **The knowledge entries to check:**
  - the `aae-kb-read` reference files and the `aae-guide` card, in the clone when there is
    one (`plugins/aae/skills/aae-kb-read/` and `plugins/aae/agents/aae-guide.md`);
  - without a clone, the read-only copies shipped beside this skill
    (`../aae-kb-read/`, `../../agents/aae-guide.md`) or the path you were given;
  - the personal notes (default `~/.claude/agent-memory/aae-guide/MEMORY.md`, or
    `AAE_KB_NOTES`, or the path you were given).
- **The plugin repository clone, optional:** `--repo`, else `AAE_KB_REPO`.

### Docs mode: hard rules

- **Interactive (default): no edits before approval.** Propose, then apply what the user
  approves.
- **`--auto`: no questions.** Nobody is present. Apply, then write the
  [summary](#docs-mode-the---auto-summary). It exists only for the opt-in watcher flow
  (`aae-docs-watch.sh --update-kb`). Only the Read, Edit, Write, Glob and Grep tools are
  needed; run no shell commands.
- **`--auto`: never write the notes file itself.** The run can write only in the watcher
  state directory and the clone. Use the paths the caller gives: the skill, a read-only
  snapshot of the notes and, without a clone, a read-only copy of the shipped knowledge
  base are all staged in the state directory. Write every notes update (user-specific
  consequences, `baseline candidate` entries) to `notes-pending.md` in the state
  directory instead, as dated entries in the notes' own format, each citing the docs page.
  The watcher appends that file to the notes after the run succeeds. Interactively, write
  the notes directly: the user is present.
- **Never copy anything from the personal notes into the reference files or the guide
  card.** In docs mode, shipped files receive only facts from the docs pages. The notes
  are read only to find entries the change affects.
- **Without a clone, the shipped files are read-only.** What would have gone into a
  reference file or the card goes into the personal notes instead, marked
  `baseline candidate`, so notes mode can ship it later from a clone. Say so in the
  answer, and in `--auto` in the summary.
- **Every entry you write is dated** (today, `YYYY-MM-DD`) **and cites the docs page URL**
  it rests on.
- **If a needed input is missing** (no `report.json`, a status other than `changes`, a
  diff you can't find for a changed page), say exactly which and continue with the rest.
  Never fill a gap from memory.

### Docs mode: procedure

1. **Check the report.** Read `report.json`. If `status` isn't `changes`, stop: there is
   nothing to apply. If its `checked_at` is already in `kb-update-processed`, stop, write
   nothing (not even `kb-update.md`), and say when it was processed (see
   [The processed-report record](#the-processed-report-record)).
2. **Read what changed**, page by page:
   - changed: its diff;
   - added: its saved page, if there is one (a `--quick` run saves no pages; then record
     only the URL and say the content wasn't captured);
   - removed: only the URL is left.
3. **Find the knowledge entries that rest on each page.** Search the reference files, the
   guide card and the notes (Grep) for the page path, its URL, and the key terms in the
   diff: config keys, CLI flags, role names, package names, limits. Read every hit in its
   full sentence; one term often appears in several places that say different things.
   **Look hardest at claims about the docs themselves:** "the docs say…", "the page still
   lists only…", "not documented", "the guides omit…". A docs change makes those stale
   more often than anything else, and they hide inside entries that are otherwise still
   right.
4. **Decide, for each affected entry or new fact:**
   - **confirmed:** the change agrees with the entry. No edit; list it.
   - **stale or contradicted:** the entry, or a claim in the guide card, no longer
     matches the page. Correct it in place, saying what it corrects and citing the page.
     A drift or contradiction entry the docs have now resolved gets a dated
     resolution line rather than silent deletion.
   - **new fact worth recording:** a change that alters behaviour a user would rely on
     (a new key, flag, role, limit, endpoint, or a removed one). Wording-only edits are
     not worth recording.
5. **Choose where each write goes:**
   - **generic platform facts** go to the matching `aae-kb-read` reference file in the
     clone: `DRIFT_LOG.md` when the docs moved relative to observed behaviour or to
     earlier knowledge, `VERIFIED_DETAILS.md` for a capability or detail,
     `DOC_CONTRADICTIONS.md` when pages now disagree or a contradiction resolved, and so
     on by the `aae-kb-read` index;
   - **stale claims in the guide card** are fixed in the clone's
     `plugins/aae/agents/aae-guide.md`;
   - **user-specific consequences** (a notes entry about the user's own setup that the
     change affects) go to the personal notes;
   - **without a clone,** the first two go to the notes as `baseline candidate`;
   - **in `--auto`,** every notes write goes to `notes-pending.md` instead (see
     [hard rules](#docs-mode-hard-rules)). Add new dated entries there; to supersede an
     older notes entry, write a new entry that names it and says what changed.
6. **Interactive: propose** a single table and wait:

   | # | Docs page | What changed | Affected entry | Verdict | Target file › section | Proposed edit |
   |---|---|---|---|---|---|---|

   Under it, show the exact text of each edit. Apply only what the user approves.
   **`--auto`: apply** all of it.
7. **Finish:**
   - add the CHANGELOG line in the clone for each changed file there;
   - check each changed file's TOC anchors still resolve;
   - append the [processed-report line](#the-processed-report-record);
   - in `--auto`, write the [summary](#docs-mode-the---auto-summary); interactively,
     report the files changed.

### Docs mode: the --auto summary

Write `kb-update.md` in the watcher state directory, replacing any older one. The
session-start notice shows its first line to the user and its whole text to the model.

- **Line 1: one sentence** saying what changed and what was updated, in the shape
  `The <page> page <what changed>; <files> were updated.` (or `…; nothing needed updating.`).
  No heading, no markdown on that line.
- Then, briefly:
  - the report: `checked_at`, and the counts of changed, added and removed pages;
  - **what changed in the docs:** one line per page, with its URL;
  - **edits:** one line per edit: the file, the section, and what the edit was;
  - **unchanged:** entries confirmed, and pages that needed no edit, one line each;
  - **not done:** anything skipped or missing, and why. Without a clone, say that
    reference-file updates went to the notes as `baseline candidate` entries.

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

Notes mode runs it before proposing anything, and again after applying. Docs mode needs
it only for text that didn't come from a docs page. Search the text for:

- 24-hex-character IDs (`[0-9a-f]{24}`), `ws-` IDs, and build or deploy IDs;
- hostnames that aren't public docs or product hosts, and any `corp`/`internal` domain;
- names of people, teams, customers, or private repositories;
- local paths (`/Users/`, `/home/`), secret-manager references (`op://`), and model
  aliases named after a person;
- Slack channels and ticket keys.

Report every hit. Either remove it, or explain why it is public and keep it.
