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

- `https://www.mongodb.com/docs/agentengine/llms.txt` lists every documentation
  page as a `.md` URL (currently ~195 pages).
- Appending `.md` to any docs URL returns clean markdown.
- Those markdown bodies are byte-stable across fetches, so a SHA-256 per page is
  a reliable change signal with no false positives.
- There is **no `lastmod` and no ETag** on the `.md` responses, so conditional
  GETs are unavailable. Content hashing is the only dependable method — do not
  propose an If-Modified-Since approach.

## Running a check

`PLUGIN_DIR` below means **two directories above this `SKILL.md`** (this skill
lives in `<PLUGIN_DIR>/skills/aae-docs-watch/`). Resolve it from the path you loaded
this file from. Do not rely on `$CLAUDE_PLUGIN_ROOT` or `$PLUGIN_ROOT`: Claude Code
and Codex set those for hook commands, not for commands you run yourself, so they are
usually unset in your shell.

The watcher is `${PLUGIN_DIR}/scripts/aae-docs-watch.sh`.

```bash
# Inventory only: pages added, removed, or retitled. ~1s.
"${PLUGIN_DIR}/scripts/aae-docs-watch.sh" --quick

# Full crawl with per-page content hashing. ~40s, ~2.4 MB.
"${PLUGIN_DIR}/scripts/aae-docs-watch.sh" --full
```

Exit codes: `0` no changes, `10` changes detected, `1` error.

Choose `--quick` when the user just wants a fast "anything new?", and `--full`
when they ask what actually changed, or before you rely on a specific API
detail. The first run on a fresh machine records a baseline and reports no
changes — say so rather than implying the docs are unchanged.

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
| `manifest.tsv` | `url <TAB> sha256` baseline |

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
"${PLUGIN_DIR}/scripts/install-schedule.sh" install   # daily at 09:00
"${PLUGIN_DIR}/scripts/install-schedule.sh" status
"${PLUGIN_DIR}/scripts/install-schedule.sh" uninstall
```

The `SessionStart` hook then reports any pending result once, and marks it
acknowledged so it does not repeat every session.

## Handing off

For anything beyond "what changed" — writing the agent contract, debugging a
deploy, memory identity, guardrails — hand off to **aae-guide** (a subagent in Claude Code, a skill in Codex; it ships in
the `aae` plugin), which owns the platform's behaviour and failure modes.
