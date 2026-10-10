---
name: aae-scout
description: "Prior-art and freshness check for MongoDB Atlas Agent Engine (AAE) work. Use BEFORE designing or building an AAE agent, tool, script, workaround or config pattern, and whenever AAE knowledge may be stale. It checks whether the AAE docs or the agentengine CLI changed since the last check, then whether the platform, CLI, SDK, official examples, or the user's own repo already provide what is about to be built, and returns a CONFIGURE / REUSE / WAIT / BUILD verdict per need with dated evidence. Read-only. Triggers on 'is there already a way to', 'does AAE support', 'before we build', 'are we reinventing', 'are we up to date on agent engine'."
---

# AAE Scout

The "don't reinvent the wheel, don't work from stale knowledge" check for work on
**MongoDB Atlas Agent Engine** (AAE). AAE is in Public Preview, launched after your
training cutoff, and its docs and CLI change weekly. Two failures cost the most here:

1. **Building something the platform already does,** or is visibly about to do.
2. **Building on a fact that changed last week.**

This skill prevents both. Keep it cheap and fast: find and check things; do not design
solutions. For platform design and debugging, hand off to **`aae-guide`**.

**Ledger directory.** Sections 4 and 5 keep two files in
`${XDG_STATE_HOME:-$HOME/.local/state}/aae-scout/` (call it `LEDGER_DIR`). It sits outside
either host's config, so Claude Code and Codex share one ledger. Create it on first write.

## 0. Hard rules

- **Read-only.** Never run a mutating command: no `agentengine deploy` (the only safe forms
  are `deploy list` and `deploy get <id>`; an unrecognized `deploy` subcommand can fall
  through to a **real deploy**), no `init`, `create`, `secret set`, `self-update`,
  `install`, or `upgrade`. `--help` is always safe.
- **Never print a secret.** Don't read `.env` files or credential stores.
- **A claim that something doesn't exist carries its search list and date.** "AAE has no
  X" is only credible if you say where you looked and when.
- **No silent fallback.** If a required source can't be reached, say which one, and mark
  the verdict as unverified. Never fill the gap from memory.
- **Private sources stay private.** Anything found through an organization-only source
  (enterprise search, an internal tracker, a chat workspace) is labelled `private` and is
  never copied into public artifacts.

## 1. Freshness gate (always first)

**Docs.** The `aae-docs-watch` plugin keeps its state in
`${AAE_WATCH_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/aae-docs-watch}`.

1. Read `report.json` there and check its modification time.
2. If it is missing or older than 24 hours, run the watcher's `--quick` mode. To find the
   script: `find ~/.claude/plugins ~/.codex -name aae-docs-watch.sh 2>/dev/null | head -1`.
   **If the script isn't found, stop the gate and tell the user to install
   `aae-docs-watch`.** Don't crawl by hand instead.
3. If the report says `changes`, read the `diffs/*.diff` files relevant to the question.
   Lead with them, describing the change in behaviour (a new key, a changed flag, a
   revised limit), not the raw diff.
4. A `baseline` status means **nothing was compared**. Say exactly that; never say "no
   changes".

**CLI.**

1. Compare `agentengine version` (local) with the latest release from
   `https://api.github.com/repos/mongodb/agent-engine-client-libraries/releases/latest`
   (unauthenticated; read `tag_name` and `body`).
2. If local is behind, report both versions and the release notes that touch the question.
3. **Never upgrade.** AAE's own limitations page says to pin the CLI and read the release
   notes before upgrading.

Print one freshness line at the top of every answer, for example:
`Freshness: docs checked 2026-10-08 (clean) · CLI 0.1.118 local / 0.1.121 latest`.

## 2. Prior-art search: in this order

Search every rung that could plausibly cover the need. Record each one you checked, even
when it turned up nothing.

| # | Where | How |
|---|---|---|
| 1 | **Platform, native** | `https://www.mongodb.com/docs/agentengine/llms.txt` titles and descriptions, then the relevant `.md` pages (append `?allTabs=true` for all language variants). Check `reference/limitations.md` for "not supported" statements. |
| 2 | **CLI** | `agentengine --help` and the relevant subcommand `--help`. The installed CLI is often newer than the web docs. |
| 3 | **SDK** | The SDK pages listed in `llms.txt`, **including their `CHANGELOG.md` `[Unreleased]` sections.** An entry there means the feature is coming. |
| 4 | **Official examples** | `https://api.github.com/repos/mongodb/agent-engine-examples/git/trees/HEAD?recursive=1`: templates and example agents. |
| 5 | **User's own work** | The current repo (`grep -r`), `~/.claude/agents`, `~/.claude/skills`, installed plugin skills, and `knowledge/` docs. Someone may already have solved it here. |
| 6 | **Org-private sources** | Only if the user has one configured (for example an enterprise-search MCP tool in this session). Look for feature requests, internal example agents, and answered questions. Label hits `private`. |
| 7 | **Framework level** | When the need belongs to LangGraph or Google ADK rather than to AAE, check that framework's docs. AAE runs your graph unchanged, so a framework feature usually just works. |

## 3. Verdicts

Give exactly one verdict per need:

| Verdict | Meaning | Must include |
|---|---|---|
| **CONFIGURE** | The platform already does it | The exact config key, flag, or endpoint, plus the doc URL |
| **REUSE** | Something existing does it: an example, the user's repo, a plugin | Path or URL, and what to adapt |
| **WAIT** | It's on the way: an SDK `[Unreleased]` entry, an open feature request, a doc page marked upcoming | The evidence and its date, plus the **smallest** interim workaround |
| **BUILD** | Nothing found | The full list of where you searched, with dates, plus whether it should become a plugin utility (section 4) |

Then hand off: "For the design, ask `aae-guide`" whenever the verdict leads into platform
specifics.

## 4. Plugin-utility candidates

Hunting for utilities worth adding to the AAE plugins is part of this skill's job. A need
becomes a **candidate** when either holds:

- it got a BUILD or WAIT verdict, and the workaround is **generic**, not tied to one
  project; or
- it has come up **twice or more** (check your ledger).

Append each candidate to `${LEDGER_DIR}/UTILITY_CANDIDATES.md`:

```
## <short name> — <date first seen>
- Need: <one sentence>
- Seen: <dates / projects>
- Evidence it isn't native: <searched rungs + date>
- Proposed form: skill | script | subagent | hook | template
- Status: candidate | proposed | built | obsolete (platform shipped it, <date>)
```

Report new candidates at the end of your answer. The user decides what gets built.

## 5. Verdict ledger: re-check when the docs move

Keep `${LEDGER_DIR}/VERDICTS.md`: need, verdict, date, and the doc pages the
verdict rests on. When the freshness gate shows that one of those pages changed, **re-check
every WAIT and BUILD verdict that depends on it** and tell the user, for example:
"`morning schedule` was BUILD on 2026-10-06; the scheduling page changed today, re-checking…".
A workaround the platform has made obsolete is technical debt the user doesn't know about.

## 6. Output format

```
Freshness: <line>

| Need | Verdict | Evidence (checked <date>) |
|---|---|---|

Searched: <rungs checked, including empty ones>
New plugin-utility candidates: <none | list>
Hand-off: <aae-guide for X | none>
```

Keep it short. Lead with the verdicts.
