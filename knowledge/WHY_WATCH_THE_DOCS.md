# Why Watch the Agent Engine Docs?

- [What's the actionable summary?](#whats-the-actionable-summary)
- [How much did the docs actually change last week?](#how-much-did-the-docs-actually-change-last-week)
- [If the docs barely change, why watch them at all?](#if-the-docs-barely-change-why-watch-them-at-all)
- [Can't a reader just check the release notes?](#cant-a-reader-just-check-the-release-notes)
- [Why not post a digest to Slack every day?](#why-not-post-a-digest-to-slack-every-day)
- [Isn't this already solved by watching the repo on GitHub?](#isnt-this-already-solved-by-watching-the-repo-on-github)
- [What is actually worth building?](#what-is-actually-worth-building)
- [Evidence and method](#evidence-and-method)

## What's the actionable summary?

**The case for a docs watcher is not change volume. Volume is low and falling.** In the
seven days to 2026-10-12 the Agent Engine docs took **3 commits on 2 days**, touching
**4 content pages and ~14 lines**. The week before took 8 commits. Anyone pitching "your
docs change a lot" will be contradicted by the first person who opens the commit log.

The case that survives contact with the data is narrower and stronger:

1. **There is no change-notification surface at all.** No product release-notes page; the
   two SDK changelogs contain a single `[Unreleased]` heading and **zero dated entries**.
   A consumer cannot answer "what changed since I last read this?" from the docs.
2. **Low volume, high blast radius.** 2 of the week's 4 changed pages were a **breaking
   package rename**, including the literal `pip install` line. One small commit invalidated
   every copy-pasted install command in circulation.
3. **The docs and the CLI drift apart on their own schedules**, and nothing announces it.

So: **build the watcher, but event-driven rather than daily, and source it from git rather
than from page hashing.** A daily Slack post would say "nothing changed" five days out of
seven and be muted within a fortnight.

## How much did the docs actually change last week?

Every Agent Engine page is published from the **public** repo `mongodb/docs`, path
`content/agentengine/`. That gives exact, dated, file-level history — no inference required.

| Date (UTC) | Commit | What it did | Size |
|---|---|---|---|
| Oct 5 | — | nothing | — |
| Oct 6 | — | nothing | — |
| **Oct 7** | `ab74effd` Use direct link to API docs | `manage/monitor`, `manage/support-access`, plus a TOC entry | +5/-5 |
| Oct 8 | — | nothing in docs — **but CLI v0.1.119 shipped this day** | — |
| **Oct 9** | `786f1ceb` DOCSP-65094 Correct package name | `add-features/memory-mcp`, `add-features/memory-only` | +7/-7 |
| **Oct 9** | `37fab6c1` seed facets.toml | taxonomy metadata only, no prose | +3/-0 |
| Oct 10–12 | — | nothing | — |

Baseline for contrast: **8 commits between Sep 29 and Oct 2.** The docs were considerably
more volatile the week before. Change volume is not the problem.

## If the docs barely change, why watch them at all?

Because one of the three commits was this:

```diff
-   pip install agentic-platform-memory
+   pip install agent-engine-sdk-memory
```

The memory SDK was renamed from `agentic-platform-memory` to `agent-engine-sdk-memory`
across both memory pages, prose and install command alike. Anyone — human or agent —
working from a copy taken 24 hours earlier now writes an install command that fails.

The same commit also left the anchor IDs behind: the prose says `agent-engine-sdk-memory`
while the link target still reads `agentic-platform-memory-only`. A half-finished migration
is exactly what a diff catches and a human skim does not.

**The misunderstanding worth heading off:** "few changes" and "safe to ignore" are not the
same claim. A docs set that changes rarely is *more* dangerous to skip, not less, because
nobody develops the habit of re-reading it.

## Can't a reader just check the release notes?

No. This is the core of the argument, and it is verifiable in a minute:

- `https://www.mongodb.com/docs/agentengine/release-notes` is an **infinite 301 redirect
  loop** — there is no product release-notes page, and `release-notes` appears zero times
  in the docs' own page inventory (`llms.txt`).
- Both SDK changelog pages follow Keep a Changelog but contain **only `## [Unreleased]`**.
  No dated version blocks have ever been added; the source files are untouched since the
  docs were imported.
- The `.md` pages return **no `Last-Modified` header** (0 of 196 checked). The only date
  they expose is page-render time, which moves on every site rebuild and says nothing about
  content. Demonstrated live: the memory page reported a render date of Oct 9 in the morning
  and Oct 12 in the afternoon of the same investigation, with no commit in between.
- CLI release notes do exist, on GitHub — but v0.1.119's are ~40 bullets of raw internal PR
  titles, not a customer-facing summary.

There is no feed, no date, no diff, and no "since" parameter anywhere in the published
surface. That absence is the gap worth filling.

## Why not post a digest to Slack every day?

Because on last week's data it would have been empty on 5 of 7 days. A channel that says
"no changes" 71% of the time trains its readers to stop looking, and the one morning it
matters, the breaking rename scrolls past unread. Daily cadence manufactures the very
inattention it is meant to cure.

**Post on change, not on schedule.** Check often; speak rarely.

## Isn't this already solved by watching the repo on GitHub?

Partly, and this should be said out loud before anyone builds anything. `mongodb/docs` is
public, so GitHub's own watch, the commits Atom feed, and a path-filtered Action on
`content/agentengine/**` all give free change notification with zero build cost. If the goal
were only "tell a human something moved", that is the honest answer and the project should
stop there.

What those do not give is the second half: **a digest an agent has already absorbed.** A
notice a person reads is awareness; a structured delta that an assistant loads as context is
correctness. The failure mode this addresses is not "I missed an email" — it is *an agent
confidently answering from a model of the product that was correct last week*. That is the
part worth building, and it is the part GitHub will never ship.

## What is actually worth building?

| Decision | Call | Why |
|---|---|---|
| Trigger | **On change, not daily** | 5 of 7 days are empty; daily cadence breeds muting |
| Source | **`mongodb/docs` git history**, not page hashing | Exact timestamps, file-level diffs, and *retroactive* history — hashing only knows what it saw since its first crawl |
| Output | **Agent-consumable delta first**, human notice second | The notice is the lesser half |
| Scope | **Docs + CLI releases together** | 121 of 195 doc pages (62%) are CLI reference, so CLI releases drive most doc churn — and the two drift: v0.1.119 shipped Oct 8 with no doc change that day |

The current watcher hashes 195 pages daily to detect what git already records precisely. It
also demonstrates the cost of that choice: its content baseline began Oct 8, so it **missed
the Oct 7 commit entirely** and can never recover it. Switching the source to git fixes the
blind spot and the history problem at once.

## Evidence and method

All figures verified 2026-10-12 against primary sources:

- Docs history: `gh api "repos/mongodb/docs/commits?path=content/agentengine&since=..."`
- CLI releases: `https://api.github.com/repos/mongodb/agent-engine-client-libraries/releases`
  — **one** release in the window (v0.1.119, 2026-10-08), 7 in the preceding 13 days
- Changelog and header claims: direct fetch of the published `.md` pages and `llms.txt`

Known limits, stated so the numbers are not oversold: `content/agentengine/` was imported
into `mongodb/docs` on 2026-09-29, so history before that date lives elsewhere and is not
public. The Internet Archive holds **zero** captures of these pages inside the window, so
there is no independent corroboration of the git record — it is trusted on the assumption
that the live site publishes from `main`.
