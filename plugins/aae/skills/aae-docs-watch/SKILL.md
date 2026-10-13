---
name: aae-docs-watch
description: Check whether MongoDB Atlas Agent Engine (AAE) documentation pages have changed, and show what changed. Use when the user says "check AAE docs", "did the agent engine docs change", "what changed in Atlas Agent Engine", "aae docs watch", "show me the AAE doc diff", or when an answer depends on AAE API details that may have moved since the last check.
---

# AAE Documentation Watch

Detects and explains changes to the MongoDB Atlas Agent Engine documentation set.

## Why this exists

Atlas Agent Engine is in Public Preview. Its docs state that endpoints, request
formats, and response formats may change without a backward-compatible migration
path. Any AAE answer given from memory risks being stale, so this skill turns
"did the docs move?" into a mechanical check instead of a guess.

## How detection works

There are two detectors with the same output contract and two different sources.

**From the published site (`aae-docs-watch.sh`), by content hashing:**

- `https://www.mongodb.com/docs/agentengine/llms.txt` lists every documentation
  page as a `.md` URL (currently ~195 pages).
- Appending `.md` to any docs URL returns clean markdown.
- Those markdown bodies are byte-stable across fetches, so a SHA-256 per page is
  a reliable change signal with no false positives.
- There is **no `lastmod` and no ETag** on the `.md` responses, so conditional
  GETs are unavailable **against the site**. Do not propose an If-Modified-Since
  approach to the published pages; it cannot work.

**From the publishing repository (`aae-docs-watch-git.sh`), by git history:**

- The pages are published from the public repository `mongodb/docs`, path
  `content/agentengine`. It is readable unauthenticated: no token, no account,
  no permission.
- The source path maps to the published URL mechanically —
  `content/agentengine/source/<path>.txt` → `<docs base>/<path>.md`, measured
  exact on 200 of 200 source files (2026-10-13).
- It therefore reports what hashing structurally cannot: the exact commit
  timestamp, the author and commit message, history from **before** the tool was
  first run, the pages a changed shared include fans out to (resolved at the
  reported commit), the site-wide fan-out of a `snooty.toml` edit, and the
  filtering of non-page commits such as `facets.toml` taxonomy changes.
- It keeps a blobless sparse clone at `<state dir>/docs-repo`. The first run
  costs roughly 30 seconds and 165 MB on disk; later runs are a cheap
  `git fetch`.

**Which to run.** Prefer `aae-docs-watch-git.sh` when the user asks what changed,
when the answer needs dates or provenance, or when a shared include or the site
banner may be involved. Use `aae-docs-watch.sh` when git is unavailable, when the
165 MB clone is unwanted.

**The git detector is what the scheduled job installs by default.** The hashing
watcher is still present and fully supported: installing the schedule with
`AAE_WATCH_IMPL=hash` selects it instead. `--update-kb` and `--kb-update-only`
work identically on both: that machinery lives in a shared library both
watchers source.

## Running a check

`PLUGIN_DIR` below means **two directories above this `SKILL.md`** (this skill
lives in `<PLUGIN_DIR>/skills/aae-docs-watch/`). Resolve it from the path you loaded
this file from. Do not rely on `$CLAUDE_PLUGIN_ROOT` or `$PLUGIN_ROOT`: Claude Code
and Codex set those for hook commands, not for commands you run yourself, so they are
usually unset in your shell.

The watcher is `${PLUGIN_DIR}/scripts/aae-docs-watch.sh`.

```bash
# Default: today's full check, unless one already completed today. ~40s, ~2.4 MB.
"${PLUGIN_DIR}/scripts/aae-docs-watch.sh" --full --skip-if-ran-today

# Inventory only: pages added, removed, or retitled. ~1s.
"${PLUGIN_DIR}/scripts/aae-docs-watch.sh" --quick

# Force another full crawl today. Use only when the user asks to re-run.
"${PLUGIN_DIR}/scripts/aae-docs-watch.sh" --full

# Opt-in: also apply any changes found to the knowledge base, unattended.
"${PLUGIN_DIR}/scripts/aae-docs-watch.sh" --full --skip-if-ran-today --update-kb

# Apply the existing changes report to the knowledge base without crawling
# (for example to retry after kb-update-error).
"${PLUGIN_DIR}/scripts/aae-docs-watch.sh" --kb-update-only
```

The git-sourced detector takes the same flags and writes the same files:

```bash
# Full check from git history. First run clones (~30s, ~165 MB); later runs fetch.
"${PLUGIN_DIR}/scripts/aae-docs-watch-git.sh" --full --skip-if-ran-today

# New commits only, no diff resolution. ~2s.
"${PLUGIN_DIR}/scripts/aae-docs-watch-git.sh" --quick
```

It has no `--update-kb` / `--kb-update-only`: those stay on the hashing watcher,
which can be run with `--kb-update-only` against whichever report is current.

Separately, `aae-cli-docs-check.sh` compares the `agentengine` binary's
self-generated command tree against the published `cli/` pages. It prints nothing
while the two agree and exits `30` on divergence (`0` agree, `1` error). Measured
clean across 117 commands at CLI 0.1.118.

```bash
"${PLUGIN_DIR}/scripts/aae-cli-docs-check.sh" --summary
```

Exit codes: `0` no changes, `10` changes detected, `20` skipped because today's full
check already ran, `1` error.

**Default to `--full --skip-if-ran-today`.** On exit `20`, say that today's check
already ran (the time is in `last-full-run`), then report from the existing
`report.json` and `diffs/` exactly as for a fresh run. Do not force a re-crawl to
"refresh" it: a second crawl the same day replaces the morning's changes with "clean",
because the baseline has already moved. Force with `--full` alone only when the user
explicitly asks to run it again. Use `--quick` only for a fast "anything new?". The first run on a fresh machine records a baseline and reports no
changes — say so rather than implying the docs are unchanged.

### `--update-kb`: apply the changes to the knowledge base

**Only when the user asks for it.** With `--update-kb`, a run that finds changes starts
an AI runner without anyone present (`claude -p`, or `codex exec`). The runner follows
the `aae-kb-update` skill in docs mode with `--auto`: it edits the knowledge base without
asking, then writes a summary to `kb-update.md`. Without the flag the watcher only
reports, which is the default. When the user just wants to review and apply the changes
with you, run the `aae-kb-update` skill in docs mode yourself instead; it proposes first.

Settings, all optional, read from the environment:

| Variable | Meaning |
|---|---|
| `AAE_KB_REPO` | A git clone of the plugin repository. Reference-file and guide-card edits go there. Unset: they go to the notes as `baseline candidate` entries |
| `AAE_KB_RUNNER` | `claude` or `codex`. Default: `claude` if on `PATH`, else `codex` |
| `AAE_KB_NOTES` | The personal notes file. Default `~/.claude/agent-memory/aae-guide/MEMORY.md` |
| `AAE_KB_MAX_USD` | Spending cap for one `claude` run. Default `2` |
| `AAE_KB_MODEL` | Model for the `claude` runner. Default `sonnet` |

A runner failure never changes the crawl's exit code. It is written to
`kb-update-error`, and the session-start notice reports it. On exit `10`, check that
file and `kb-update.md`, and tell the user which one you found. The Codex runner is
untested.

## Reporting what changed

State lives in `${XDG_STATE_HOME:-~/.local/state}/aae-docs-watch/` (override with
`AAE_WATCH_STATE_DIR`). It is deliberately outside any host's plugin directory, so the
hook, this skill and the launchd job all read the same baseline, in Claude Code and
Codex alike:

| Path | Contents |
|---|---|
| `report.json` | Last result: `status`, `counts`, and the `added`/`removed`/`changed` URL lists |
| `diffs/<slug>.diff` | Unified diff per changed page |
| `pages/<slug>` | Current markdown snapshot of each page |
| `manifest.tsv` | `url <TAB> sha256` baseline (hashing watcher) |
| `last-commit` | The commit the git detector last reported on — its whole baseline |
| `changes-summary.md` | Human-readable digest from the git detector: commit list, include and `snooty.toml` fan-out, and a CLI regeneration collapsed to one line |
| `docs-repo/` | The git detector's blobless sparse clone of the publishing repository (~165 MB) |
| `last-full-run` | Local date and time of the last completed full crawl |
| `kb-update.md` | With `--update-kb`: what the last automatic knowledge-base update changed. Its first line is a one-sentence summary |
| `kb-update-processed` | One line per report applied to the knowledge base: its `checked_at`, the date, the mode |
| `kb-update-error` | Time and message of a failed automatic update; removed by the next successful one |
| `kb-update-runner.log` | The runner's full output from the last automatic update |
| `kb-update-notes-before.md` | Copy of the personal notes taken before the last automatic update |
| `notes-pending.md` | The runner's notes updates; the watcher appends them to the notes after a successful run. Present only if that append failed |
| `kb-update-skill.md`, `kb-baseline/` | Inputs staged for the runner: the skill, and a read-only knowledge-base copy when no clone is set |

After a git-sourced run, read `changes-summary.md` first: it names the commits
behind the change and collapses a CLI-reference regeneration into one line.
`report.json` still lists every affected page, so nothing is hidden from the
machine readers.

To explain a change: read the relevant `diffs/*.diff`, then summarise the
behavioural impact — a new config key, a changed CLI flag, a revised limit —
rather than quoting the diff verbatim. Cite the page URL.

The SDK changelog pages are the highest-signal entries in the set, because they
are written in Keep a Changelog format with a live `[Unreleased]` section:

- `sdk/python/packages/agent-engine-runner-shared/CHANGELOG.md`
- `sdk/javascript/packages/agent-engine-sdk/CHANGELOG.md`

If one of those changed, read it first and lead the answer with it.

## Scheduling

Neither Claude Code nor Codex plugins can declare scheduled work, so a full crawl
between sessions runs from launchd (macOS only):

```bash
"${PLUGIN_DIR}/scripts/install-schedule.sh" install   # daily at 10:00 local time
"${PLUGIN_DIR}/scripts/install-schedule.sh" install --update-kb   # and update the knowledge base on changes
"${PLUGIN_DIR}/scripts/install-schedule.sh" status    # incl. whether the job's copy is current
"${PLUGIN_DIR}/scripts/install-schedule.sh" uninstall
```

The job runs a copy of the watcher from `~/.local/share/aae-docs-watch/bin/`, with a copy
of the `aae-kb-update` skill beside it, because the plugin's own folder is versioned and
an update can delete it. If `status` reports either copy as out of date or missing, tell
the user and re-run `install` (with `--update-kb` again if they had it on).

The `SessionStart` hook then reports any pending result once, and marks it
acknowledged so it does not repeat every session.

## Handing off

For anything beyond "what changed" — writing the agent contract, debugging a
deploy, memory identity, guardrails — hand off to **aae-guide** (a subagent in Claude Code, a skill in Codex; it ships in
this plugin), which owns the platform's behaviour and failure modes.
