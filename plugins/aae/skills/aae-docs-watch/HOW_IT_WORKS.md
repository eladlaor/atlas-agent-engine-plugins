# AAE docs watcher: how it works

- [Summary](#summary)
- [How do the pieces fit together?](#how-do-the-pieces-fit-together)
- [Why read git history instead of the pages?](#why-read-git-history-instead-of-the-pages)
- [What does the git-sourced detector cost, and what does it not do?](#what-does-the-git-sourced-detector-cost-and-what-does-it-not-do)
- [What does `--update-kb` add?](#what-does---update-kb-add)
- [How does the daily crawl run, and what can I configure?](#how-does-the-daily-crawl-run-and-what-can-i-configure)

## Summary

A shell script detects changes to the AAE docs with no AI involved, so detecting a change
costs no AI tokens. Two detectors exist: the scheduled default reads the git history of
the public repository the docs are published from, and the original hashes every
published page and compares the hashes with the last run. A session-start hook tells you once when
something changed, and warns once a day if the watcher is failing. Optionally, a daily
`launchd` job runs the check on your Mac, and the opt-in `--update-kb` flag updates the
knowledge base when the docs changed. Commands and the state-file layout are in the
[user guide](../../../../knowledge/usage_guides/USER_GUIDE.md).

## How do the pieces fit together?

Three separate pieces. The session-start hook does **not** crawl anything; it only reads
the result of the last crawl.

| Piece | Runs | Does |
|---|---|---|
| **The crawl** (`aae-docs-watch.sh`) | Daily at 10:00 via `launchd` if you [schedule it](../../../../README.md#optional-extras), retried hourly until it succeeds; or when you ask | Fetches every docs page, compares hashes with the baseline, writes `report.json` and per-page diffs. With `--update-kb`, then starts the knowledge-base update if anything changed |
| **The session-start hook** | When a session starts | Reads `report.json`. If it says `changes` and you haven't been told yet, shows a one-line notice, once, including the update's summary when there was one. Also warns, once a day, if the watcher or the update is failing |
| **The git-sourced check** (`aae-docs-watch-git.sh`) | Daily, and when you ask. The scheduled default | Fetches the publishing repository, resolves the changed pages from the commit range, writes the same `report.json` plus a `changes-summary.md`. See [below](#why-read-git-history-instead-of-the-pages) |
| **The `aae-docs-watch` skill** | When you ask ("check the AAE docs") | Runs a check on demand and explains the diffs |

Without a schedule or a request, nothing new is detected; the hook keeps reading the old
result.

What updates on its own, and what doesn't:

- **Updated by every crawl:** the watcher's **baseline** (page hashes and saved copies in
  `~/.local/state/aae-docs-watch/`), so the next crawl compares against today's docs.
- **Not updated automatically by default:** the guide's knowledge base (`aae-kb-read`)
  and its card. The notice tells the model to re-read changed pages before stating AAE
  details. Turning a doc change into knowledge is a deliberate step: run `aae-kb-update`
  in docs mode, which proposes the edits first. Or opt in to `--update-kb`, below.
- **A failed crawl** (for example, the Mac wakes briefly at 10:00 before its network is
  up) keeps the previous baseline. The first request is retried for a few minutes, and
  the schedule tries again every hour until one run succeeds that day.
- **A broken watcher is announced.** If the last check failed, or no check has succeeded
  for over a day while the schedule is installed, the session-start notice says so, once
  a day. Silence therefore means "checked, no changes", never "not checked".

## Why read git history instead of the pages?

Because the history answers questions the pages cannot. Hashing can say only "this page
differs from the copy I took last time". The docs are published from the public
repository `mongodb/docs`, path `content/agentengine`, and reading its history gives the
exact commit time, the author and the commit message, and real file-level diffs.

`aae-docs-watch-git.sh` does that. It keeps a clone of the publishing repository and
compares the commit it last reported on with the current one, then maps each changed
source file to its published URL —
`content/agentengine/source/<path>.txt` → `<docs base>/<path>.md`, exact on 200 of 200
source files when measured on 2026-10-13.

Five things fall out of that which hashing never had:

| | What the git source adds |
|---|---|
| Provenance | The commit timestamp, author and message behind each change |
| Retroactive history | Changes from **before** the tool was first run. A hashing baseline starts at its own first crawl, and a page edited and reverted between two runs is invisible to it |
| Include fan-out | A shared include is not a published page. When one changes, the detector resolves every page that transcludes it — at the reported commit, not at the current tree |
| Site-wide fan-out | A one-line `snooty.toml` edit changes the banner or a substituted constant on up to all ~196 published pages while touching zero source pages. This is the single largest change a naive "source files only" filter would miss, so it is handled as a special case |
| Noise filtering | Commits that touch no published page — a `facets.toml` taxonomy edit, say — are classified out instead of reported |

It also writes `changes-summary.md` beside `report.json`: a human-readable digest that
collapses a CLI-reference regeneration — roughly 37 `cli/` pages changing together from
one release — into a single line. `report.json` still lists every one of those pages, so
the machine contract is unchanged.

**The misunderstanding to avoid:** reading this as "the hashing approach was wrong". It
was not. The published site really does send no `Last-Modified` and no `ETag`, so a
conditional GET against the site still cannot work, and hashing is still the only way to
detect a change *in the published page itself*. What changed is that the publishing
repository turned out to be public, which makes a better source available — not a
correction to the old reasoning about the site.

## What does the git-sourced detector cost, and what does it not do?

A one-time clone of about 30 seconds and 165 MB on disk, under `docs-repo/` in the state
directory. It is a blobless sparse clone: file contents are fetched on demand and only
`content/agentengine` is checked out. Every later run is a `git fetch`. It needs `git` on
`PATH` and no credentials at all — the repository is public.

What it deliberately does not change:

- **The output contract.** It writes the same `report.json` (the same 10 keys, still a
  compact single line), the same state layout and the same exit codes (`0` no changes,
  `10` changes, `20` skipped, `1` error). The session-start hook, the `aae-kb-update`
  runner, the `aae-scout` freshness gate and the `launchd` job are untouched. The test
  suite proves this by feeding a git-produced report to the real `session-notice.sh` and
  `install-schedule.sh`.
- **What runs on a schedule.** The hashing watcher is still present and is still what the
  `launchd` job runs. Switching the scheduled job over, and removing the hashing path, has
  not happened yet; until it does, the git detector is something you run explicitly.

Alongside it, `aae-cli-docs-check.sh` guards a different axis: it generates the CLI's own
command reference from the installed binary and compares it with the published `cli/`
pages, exiting `30` if they disagree. Measured at zero drift across 117 commands on CLI
0.1.118, so a clean run is the expected result and anything else is news.

Both are covered by dependency-free shell suites: `tests/run-tests.sh` (27 tests) and
`tests/cli-docs-check/run-tests.sh` (19 tests).

## What does `--update-kb` add?

An unattended knowledge-base update, only when the docs changed. It is off unless you
pass the flag, to the watcher or to `install-schedule.sh install`.

1. The crawl finds changes and writes `report.json`, as always.
2. The watcher starts an AI runner without anyone present: `claude -p` if `claude` is on
   `PATH`, else `codex exec` (set `AAE_KB_RUNNER` to choose). The runner follows the
   `aae-kb-update` skill in docs mode with `--auto`.
3. For each changed, added or removed page, it finds the knowledge entries that rest on
   it, decides whether each is confirmed, stale, or missing a new fact, and writes the
   update:

   | What | Where it lands |
   |---|---|
   | Generic platform facts (a new role, key, flag or limit) | The matching `aae-kb-read` reference file, such as `DRIFT_LOG.md` or `VERIFIED_DETAILS.md`, in your clone of this repo (`AAE_KB_REPO`) |
   | Stale claims in the `aae-guide` card | The card, in the same clone |
   | Consequences for your own setup | Your personal notes |
   | Generic facts, when no clone is set | Your personal notes, marked `baseline candidate`, for notes mode to ship later from a clone |

   Every entry is dated and cites the docs page. Nothing is committed, and the installed
   plugin is never edited.
4. It writes a summary to `kb-update.md` in the state directory, and records the report
   in `kb-update-processed`, so the same report is never applied twice.
5. The next session-start notice says the knowledge base was updated, with the summary's
   first line; the model gets the whole summary.

**The runner is guarded.** It can read and write only two places: the watcher's state
directory and your clone. Claude gets only file tools (`Read`, `Edit`, `Write`, `Glob`,
`Grep`): no shell, no web, no MCP servers. It runs in `acceptEdits` mode, which approves
edits inside those two directories only, and any other access is denied because nobody is
there to approve it. Codex runs in its `workspace-write` sandbox over the same two
directories. Everything else the runner needs (the skill, a snapshot of your notes, and,
without a clone, a copy of the shipped knowledge base) is copied into the state
directory first. **It never edits your notes:** it writes its notes updates to
`notes-pending.md`, and the watcher script appends that file to your notes under a dated
separator after the run succeeds, keeping the pre-run copy in
`kb-update-notes-before.md` ([why a staging file](../../../../knowledge/usage_guides/USER_GUIDE.md#why-does-the-automatic-update-write-my-notes-through-a-staging-file)). Claude runs on Sonnet by default (`AAE_KB_MODEL`), with a
spending cap (`AAE_KB_MAX_USD`, default $2) and a 15-minute time limit. A runner failure
never changes the crawl's result: it is written to `kb-update-error`, shown in the
session-start notice, and can be retried with `aae-docs-watch.sh --kb-update-only`.

**The misunderstanding to avoid:** reading `--update-kb` as "the plugin updates itself".
The shipped knowledge base changes only in your clone, and only when you review, commit
and release it. Every other user gets it on their next plugin update after that.

## How does the daily crawl run, and what can I configure?

The daily docs crawl is a scheduled job **on your own machine**, like a cron entry.
On macOS it uses `launchd` (the macOS equivalent of cron): `install` writes
`~/Library/LaunchAgents/com.eladlaor.aae-docs-watch.plist`, which runs the docs check
every day at 10:00 (change it with `--hour` / `--minute`), and again every hour until a
run succeeds that day. If the Mac is asleep at that time, it runs on wake. Nothing runs in the cloud.
Check it with `install-schedule.sh status`. On Linux, add an equivalent cron entry
yourself.

With `--update-kb`, these environment variables are read at install time and stored in
the job, when set:

| Variable | Meaning | Default |
|---|---|---|
| `AAE_KB_REPO` | Absolute path to your git clone of this repo. Reference-file and guide-card updates go there | Unset: they go to your notes as `baseline candidate` |
| `AAE_KB_RUNNER` | `claude` or `codex` | `claude` if on `PATH`, else `codex` |
| `AAE_KB_MAX_USD` | Spending cap for one `claude` run | `2` |
| `AAE_KB_MODEL` | Model for the `claude` runner | `sonnet` |
| `AAE_KB_NOTES` | Your personal notes file | `~/.claude/agent-memory/aae-guide/MEMORY.md` |

For example:
`AAE_KB_REPO=~/code/atlas-agent-engine-plugins plugins/aae/scripts/install-schedule.sh install --update-kb`.
`install` checks the clone and that a runner is on the job's `PATH`, and stops if not.

