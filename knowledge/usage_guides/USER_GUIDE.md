# Atlas Agent Engine Plugins — User Guide

- [Summary](#summary)
- [What is this plugin?](#what-is-this-plugin)
- [How do I install it?](#how-do-i-install-it)
- [What does the guide already know, and where does it keep what it learns?](#what-does-the-guide-already-know-and-where-does-it-keep-what-it-learns)
- [How do I ship what I learned to every user of the plugin?](#how-do-i-ship-what-i-learned-to-every-user-of-the-plugin)
- [The docs changed. How do I bring the knowledge base up to date?](#the-docs-changed-how-do-i-bring-the-knowledge-base-up-to-date)
- [Can the knowledge base update itself when the docs change?](#can-the-knowledge-base-update-itself-when-the-docs-change)
  - [Why does the automatic update write my notes through a staging file?](#why-does-the-automatic-update-write-my-notes-through-a-staging-file)
- [How do I type `ae` instead of `agentengine`?](#how-do-i-type-ae-instead-of-agentengine)
- [Why a symlink instead of a shell alias?](#why-a-symlink-instead-of-a-shell-alias)
- [How do I know when the AAE docs change?](#how-do-i-know-when-the-aae-docs-change)
- [How do I check I'm not rebuilding something AAE already does?](#how-do-i-check-im-not-rebuilding-something-aae-already-does)
- [How does change detection actually work?](#how-does-change-detection-actually-work)
- [Why does it crawl every page instead of checking a timestamp?](#why-does-it-crawl-every-page-instead-of-checking-a-timestamp)
- [How do I schedule the check?](#how-do-i-schedule-the-check)
  - [Why does the schedule run a copy of the watcher?](#why-does-the-schedule-run-a-copy-of-the-watcher)
  - [Why didn't my check run again today?](#why-didnt-my-check-run-again-today)
- [Where does state live?](#where-does-state-live)
- [Why am I not getting notified?](#why-am-i-not-getting-notified)

## Summary

One plugin, `aae`, for working with MongoDB Atlas Agent Engine (AAE), in Claude Code or
Codex. It carries the `aae-guide` specialist, its bundled `aae-kb-read` base, the
`aae-kb-update` skill, the `aae-scout` prior-art check, the add-agent / delete-agent
skills, an `ae` shortcut, and the docs watcher that tells you when AAE documentation
pages change. Install `aae` and optionally schedule the watcher with launchd; the first
check records a baseline, and your host tells you at session start whenever the docs have
moved. Opt in to `--update-kb` and a changed page also updates the knowledge base, with a
summary in the same notice.

Change detection is deterministic and costs no AI tokens: a script hashes every page
and compares the hashes with the last run. The model reads only the diffs of the pages
that changed, and nothing at all on a day with no changes.

## What is this plugin?

One plugin, `aae`, with two halves that belong together.

**The guide.** It centres on **`aae-guide`**, the specialist for Atlas Agent Engine — the
runtime model, the SDK surface, the config contract, and the failure modes. In Claude
Code it is a subagent; in Codex, a skill. Alongside it: the `aae-kb-read` base, the
`aae-kb-update` skill that keeps it current, the `aae-scout` skill, and the
`aae-add-agent` / `aae-delete-agent` skills.

**The docs watcher.** The `aae-docs-watch` skill, a session-start hook and an optional
daily job answer "did the AAE docs change?" mechanically instead of by guessing. AAE is in Public Preview
and its own docs warn that formats may change without a backward-compatible
migration path, so stale knowledge is the default failure mode here.

## How do I install it?

See the repository README for both hosts. In Claude Code:

```bash
/plugin marketplace add eladlaor/atlas-agent-engine-plugins
/plugin install aae@atlas-agent-engine-plugins
```

In Codex:

```bash
codex plugin marketplace add eladlaor/atlas-agent-engine-plugins
codex plugin add aae@atlas-agent-engine-plugins
```

Then **trust the plugin's hook when prompted**: Codex skips plugin hooks until you do.

The first docs check, scheduled or on demand, records the baseline and reports no
changes by design: there is nothing to compare against yet.


## What does the guide already know, and where does it keep what it learns?

It ships with a knowledge base, the **`aae-kb-read`** skill, and keeps your own notes
separately.

- **The baseline** (`plugins/aae/skills/aae-kb-read/`) is the same for every user, in
  Claude Code and Codex: a dated drift log of where the live platform and CLI disagree
  with the docs, verified details the guides omit, doc contradictions, numbered runbooks
  and symptom-first troubleshooting. Every entry carries the date and the CLI or SDK
  version it was checked on. A plugin update replaces it.
- **Your overlay** (Claude Code only) is `~/.claude/agent-memory/aae-guide/MEMORY.md`. The
  guide writes your project IDs, your cluster and gateway, runbooks that worked for you,
  and drift you observe there. A plugin update never touches it.

When the two disagree, the newer dated entry wins, and the guide re-checks the live docs
before relying on it.

**The misunderstanding to avoid:** treating the baseline as current documentation. It is
a dated record of what was true when checked. AAE is in Public Preview and moves weekly,
so the guide still verifies version-specific details against the live docs or `--help`.

## How do I ship what I learned to every user of the plugin?

Run the **`aae-kb-update`** skill in **notes mode** ("promote my AAE notes") with a local
clone of this repository. It reads your personal notes, picks out the entries that hold for every AAE user, strips
anything project-specific (IDs, hostnames, names, local paths), and shows you each
proposed entry and the reference file it would go into. It edits the clone only after you
approve, and adds a `CHANGELOG.md` line. Committing and releasing stay with you.

**The misunderstanding to avoid:** expecting the guide to update the shipped knowledge
base on its own. It writes only to your personal notes. Moving a finding into the public
baseline is always a deliberate, reviewed step.

## The docs changed. How do I bring the knowledge base up to date?

Run **`aae-kb-update` in docs mode** ("apply the docs changes to the kb"), ideally with a
clone of this repository. It reads the watcher's latest report and the diffs, and for
each changed, added or removed page:

1. finds the knowledge entries that rest on it: the `aae-kb-read` reference files, the
   `aae-guide` card, and your personal notes;
2. decides whether each is **confirmed**, **stale**, or missing a **new fact** worth
   recording;
3. proposes the edits in one table, and applies the ones you approve.

Generic platform facts go into the matching reference file in your clone (`DRIFT_LOG.md`,
`VERIFIED_DETAILS.md`, `DOC_CONTRADICTIONS.md` and so on), stale claims in the guide card
are fixed in the clone, and consequences for your own setup go into your notes. Every
entry is dated and cites the docs page. Without a clone, what would have gone into the
reference files goes into your notes, marked `baseline candidate`, so notes mode can ship
it later.

It records each report it has applied in `kb-update-processed` in the watcher's state
directory, so running it twice on the same report changes nothing.

**The misunderstanding to avoid:** expecting docs mode to copy your notes into the public
files. In docs mode the shipped files receive only facts from the public docs pages; your
notes are read only to see which of your entries a change affects.

## Can the knowledge base update itself when the docs change?

Yes, if you opt in with `--update-kb`. After a crawl that found changes, the watcher
starts an AI runner without anyone present, which runs `aae-kb-update` in docs mode with
`--auto`: the same procedure as above, minus the approval step. It then writes a short
summary to `kb-update.md`, and the next session-start notice says
"Knowledge base updated:" with the summary's first line.

```bash
# Once, on demand:
AAE_KB_REPO=~/code/atlas-agent-engine-plugins <aae-plugin-dir>/scripts/aae-docs-watch.sh --full --update-kb
# Every day, via the schedule:
AAE_KB_REPO=~/code/atlas-agent-engine-plugins <aae-plugin-dir>/scripts/install-schedule.sh install --update-kb
```

| Variable | Meaning | Default |
|---|---|---|
| `AAE_KB_REPO` | Your git clone of this repository; reference-file and guide-card edits go there | Unset: those edits go to your notes as `baseline candidate` |
| `AAE_KB_RUNNER` | `claude` or `codex` | `claude` if on `PATH`, else `codex` |
| `AAE_KB_MAX_USD` | Spending cap for one `claude` run | `2` |
| `AAE_KB_MODEL` | Model for the `claude` runner | `sonnet` |
| `AAE_KB_NOTES` | Your personal notes file | `~/.claude/agent-memory/aae-guide/MEMORY.md` |

The model is started only when the hash check found a change, so a quiet day costs
nothing. The `claude` runner gets file tools only (no shell, no web, no MCP servers),
runs on Sonnet by default, and has a spending cap and a 15-minute limit. It can read and
write only the watcher's state directory and your clone (`acceptEdits`, with every other
access denied because nobody is there to approve it); the skill, a snapshot of your notes
and, without a clone, a copy of the shipped knowledge base are copied into the state
directory first. It never edits your notes itself: it writes `notes-pending.md`, and the
watcher appends that to your notes under a dated line after a successful run, keeping the
pre-run copy in `kb-update-notes-before.md`. The `codex` runner (`codex exec` in its
workspace-write sandbox over the same two directories) is untested.

If the update fails (no runner found, a timeout, the cap reached), the crawl's own result
is unaffected. The error goes to `kb-update-error`, the session-start notice reports it,
and you can retry without crawling: `aae-docs-watch.sh --kb-update-only`. The runner's
full output is in `kb-update-runner.log`.

**The misunderstanding to avoid:** thinking this publishes anything. The edits land in your
clone and your notes; you review, commit and release them.

### Why does the automatic update write my notes through a staging file?

Because an unattended model must not hold unconfined file-edit rights. It reads external
docs text, and text can carry instructions (prompt injection). The narrow grant, "edit
only these folders", can't cover your notes: Claude Code protects `~/.claude/`, where
`MEMORY.md` lives, and a scoped grant can't reach it. So the model writes only inside the
watcher's state folder and your clone, and the shell script, with no AI involved, appends
the staged `notes-pending.md` to `MEMORY.md`.

## How do I type `ae` instead of `agentengine`?

Run the installer once:

```bash
<aae-plugin-dir>/scripts/install-ae-shortcut.sh install
<aae-plugin-dir>/scripts/install-ae-shortcut.sh status
<aae-plugin-dir>/scripts/install-ae-shortcut.sh uninstall
```

`install` creates a symlink named `ae` next to the `agentengine` binary — that
directory is already on your `PATH`, so no shell configuration is touched. After
that, `ae deploy list` and `agentengine deploy list` are the same command.

**If the name `ae` is already taken, the installer stops and asks.** It checks
three places: an existing `ae` anywhere on `PATH`, an existing file at the link
location, and an `alias ae=` or `ae()` function in your shell rc files
(`.zshrc`, `.bashrc`, `.bash_profile`, `.profile`, `.zprofile`, fish config). On
a collision it prints what it found and prompts before doing anything. Answer
`n` — or just press Enter — and nothing is changed.

In a non-interactive shell there is no one to ask, so a collision is a hard
error rather than a silent overwrite. Pass `--force` only if you already know
what you are shadowing.

`uninstall` removes the link **only** if it is still a symlink pointing at
`agentengine`. If something else has taken that path, it refuses rather than
deleting a file it does not own.

## Why a symlink instead of a shell alias?

Because an alias would work when you type it and fail for every agent.

A shell alias is interactive-only. It is defined in a shell rc file and is
**not** inherited by scripts or non-interactive shells:

```bash
$ zsh -c 'alias q="echo hi"; q'
zsh:1: command not found: q
```

Claude Code and Codex both run commands in non-interactive shells. An alias
would therefore give you `ae` at your own prompt while every command the agent
issued on your behalf failed — the most confusing possible split. A symlink on
`PATH` resolves identically in interactive shells, non-interactive shells,
scripts, and both agent tools.

It also avoids editing `~/.zshrc`. Shell rc files accumulate entries from tools
you did not install and cannot see; a tool that rewrites one is a tool that can
silently destroy unrelated configuration.

One caveat the installer warns about: if an `alias ae=` already exists, **the
alias wins** in interactive shells, because alias expansion happens before
`PATH` lookup. That is why rc files are part of the collision check and not an
afterthought.

## How do I know when the AAE docs change?

At the start of a session, a `SessionStart` hook reads the watcher's last result.
If pages changed, you get a one-line notice, and Claude separately receives the
list of changed pages so it knows to re-read them before answering.

Each result is announced **once**. After it is shown, it is marked acknowledged
so it does not repeat in every future session.

You can also ask at any time: *"check the AAE docs"* invokes the `aae-docs-watch`
skill, which runs the watcher and explains the diff.

## How do I check I'm not rebuilding something AAE already does?

Ask **`aae-scout`** before you build: "does AAE already let me X?" or "before we build X…".
It first confirms the docs and CLI are current. Then it searches, in order: the platform
docs, the CLI's `--help`, the SDK and its upcoming-changes notes, the official examples
repo, and your own repo and plugins. It answers with one verdict:

- **CONFIGURE**: AAE does it; here's the setting.
- **REUSE**: it exists; here's where.
- **WAIT**: it's coming; here's the evidence and a minimal stopgap.
- **BUILD**: nothing exists; here's everywhere it looked.

**The misunderstanding to avoid:** treating "I couldn't find it" as "it doesn't exist".
A BUILD verdict always lists the sources searched and the date, so you can judge whether
the absence is real. When the docs later change, the scout rechecks earlier BUILD and WAIT
verdicts, because a workaround the platform has made obsolete is debt you don't know you
have.

It uses the docs watcher in the same plugin for the freshness check, and it never changes anything.
It is a skill in both hosts; its verdict and utility-candidate ledgers live in
`~/.local/state/aae-scout/`, shared by Claude Code and Codex.

## How does change detection actually work?

Three facts about the docs site make this reliable:

1. `https://www.mongodb.com/docs/agentengine/llms.txt` is a machine-readable
   inventory listing every documentation page (~195) as a `.md` URL.
2. Appending `.md` to any docs URL returns clean markdown rather than HTML.
3. Those markdown bodies are **byte-identical across repeated fetches** — verified
   by hashing the same page three times and getting the same SHA-256.

So the watcher fetches the inventory, fetches each page's markdown, and stores a
SHA-256 per page. A hash that moves means the page genuinely changed. Because the
bodies carry no nonce or timestamp, there are no false positives: a full re-crawl
of an unchanged site reports zero changes.

## Why does it crawl every page instead of checking a timestamp?

Because there is nothing to check. The `.md` responses carry **no `Last-Modified`
and no `ETag`**, and the site publishes no `lastmod` in any sitemap covering these
pages. Conditional GETs (`If-Modified-Since` / `If-None-Match`) therefore cannot
work here — the server will return a full 200 every time.

This is the misunderstanding worth heading off: the obvious cheap approach is
unavailable, and content hashing is not an over-engineered choice but the only
dependable one. The cost is modest — a full crawl is about 40 seconds and 2.4 MB
at 8 parallel requests.

If you only want to know about pages being **added, removed, or retitled**, the
`--quick` mode fetches the inventory alone and finishes in about a second.

## How do I schedule the check?

Neither Claude Code nor Codex plugins can declare cron or scheduled work. For checks
that run while your host is closed, the plugin ships a launchd wrapper:

```bash
<aae-plugin-dir>/scripts/install-schedule.sh install              # daily 10:00 local time
<aae-plugin-dir>/scripts/install-schedule.sh install --hour 7     # daily 07:00
<aae-plugin-dir>/scripts/install-schedule.sh install --update-kb  # and update the knowledge base on changes
<aae-plugin-dir>/scripts/install-schedule.sh status
<aae-plugin-dir>/scripts/install-schedule.sh print-plist --update-kb   # show the job, change nothing
<aae-plugin-dir>/scripts/install-schedule.sh uninstall
```

`install` copies the watcher, and the `aae-kb-update` skill beside it, to
`~/.local/share/aae-docs-watch/bin/`, writes
`~/Library/LaunchAgents/com.eladlaor.aae-docs-watch.plist` pointing at that copy, and
loads it. **Re-run `install` after updating the plugin**, with `--update-kb` again if you
use it: `status` says when either copy is out of date. Logs go to `~/Library/Logs/aae-docs-watch/`. The time is the Mac's local time.
If that run fails, the job tries again every hour until one succeeds that day; after a
success the later attempts exit at once without touching the network. If the Mac is
asleep at that time, launchd runs the job when it wakes, and the watcher retries its
first request for a few minutes in case the network isn't up yet.

### Why does the schedule run a copy of the watcher?

The plugin's own files sit in a folder named after its version, and updating the plugin can
delete that folder. A job pointing there would then fail every morning without a sound,
and the session notice would keep showing the last good report, which looks exactly like
docs that stopped changing. The copy in a fixed location keeps working across updates;
`status` tells you when it lags behind the plugin.

### Why didn't my check run again today?

The scheduled job and the skill both pass `--skip-if-ran-today`: once a full crawl has
completed today, another one does nothing (exit `20`) and keeps the morning's report.
Without that, a second run would replace the morning's list of changes with "clean",
because the baseline already moved. To crawl again anyway, run the watcher with `--full`
alone.

If you would rather not use launchd, set `AAE_WATCH_ON_SESSION=quick` and the
session hook will run the ~1s inventory check itself when its state is more than
24 hours old. The full crawl is deliberately never run from the hook, because
`SessionStart` hooks delay Claude's first reply.

## Where does state live?

Under `${XDG_STATE_HOME:-~/.local/state}/aae-docs-watch/` (override with
`AAE_WATCH_STATE_DIR`). It sits outside both hosts' plugin directories, so it survives
plugin updates and is shared by Claude Code, Codex and the launchd job.

| Path | Contents |
|---|---|
| `report.json` | Last result: status, counts, and the changed/added/removed URL lists |
| `diffs/<slug>.diff` | Unified diff for each changed page |
| `pages/<slug>` | Current markdown snapshot of each page |
| `manifest.tsv` | `url <TAB> sha256` baseline |
| `urls.txt` | Page-inventory baseline, used for added/removed detection |
| `acknowledged` | Marker that the current report has been shown |
| `last-full-run` | Local date and time of the last completed full crawl |
| `last-error` | Time and message of the last failed run; removed by the next successful full crawl |
| `health-acknowledged` | Date the "watcher is failing" notice was last shown (once a day) |
| `kb-update.md` | Summary of the last automatic knowledge-base update (`--update-kb`); its first line is one sentence |
| `kb-update-processed` | One line per report applied to the knowledge base, so none is applied twice |
| `kb-update-error` | Time and message of a failed automatic update; removed by the next successful one |
| `kb-update-runner.log` | The runner's full output from the last automatic update |
| `kb-update-notes-before.md` | Copy of your notes taken before the last automatic update, to undo a bad edit |
| `notes-pending.md` | The runner's notes updates; appended to your notes after a successful run, so you see it only if that append failed |
| `kb-update-skill.md`, `kb-baseline/` | Inputs copied in for the runner: the skill, and a read-only copy of the shipped knowledge base when no clone is set |

Override the location with `AAE_WATCH_STATE_DIR` — useful for testing against a
throwaway directory.

## Why am I not getting notified?

Work through these in order:

1. **No baseline yet.** Run the watcher once with `--full`. A first run is
   recorded as `status=baseline` and never reports changes.
2. **Already acknowledged.** Each result is announced once. Check
   `report.json`; delete the `acknowledged` file to re-show it.
3. **Nothing actually changed.** `status=clean` means the crawl succeeded and
   every hash matched.
4. **The watcher is failing.** You'd get a once-a-day notice saying so, also when only
   the automatic knowledge-base update failed. Check `install-schedule.sh status` (it
   prints the last error of each) and `~/Library/Logs/aae-docs-watch/err.log`.
5. **Nothing is scheduled.** Without launchd, state only refreshes when you run
   the watcher or invoke the skill. Check `install-schedule.sh status`.
6. **The hook is not loaded.** Confirm the plugin is installed and run
   `/reload-plugins` (Claude Code). In Codex, check that you trusted the hook; an
   update that changes it asks again.

The watcher refuses to overwrite its baseline if a crawl returns fewer than half
the previously-known pages, so a flaky network degrades to an error rather than
to a flood of false "changed" reports.
