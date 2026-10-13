# Why Watch the Agent Engine Docs?

- [What's the actionable summary?](#whats-the-actionable-summary)
- [How much did the docs actually change last week?](#how-much-did-the-docs-actually-change-last-week)
- [If the docs barely change, why watch them at all?](#if-the-docs-barely-change-why-watch-them-at-all)
- [Don't the docs and the CLI drift apart?](#dont-the-docs-and-the-cli-drift-apart)
- [Can't a reader just check the release notes?](#cant-a-reader-just-check-the-release-notes)
- [Why not post a digest to Slack every day?](#why-not-post-a-digest-to-slack-every-day)
- [Isn't this already solved by watching the repo on GitHub?](#isnt-this-already-solved-by-watching-the-repo-on-github)
- [What is actually worth building?](#what-is-actually-worth-building)
- [Evidence and method](#evidence-and-method)

## What's the actionable summary?

**The case for a docs watcher is not change volume. Volume is low.** In the seven days to
2026-10-13 the Agent Engine docs took **4 commits on 3 days**, touching **8 published pages
and ~22 lines**. The week before took 8 commits. Anyone pitching "your docs change a lot"
will be contradicted by the first person who opens the commit log.

> **Measurement note.** An earlier version of this document reported "3 commits, 4 pages" for
> the seven days to 2026-10-12 and recorded Oct 10–12 as empty. Commit `8d14da28` landed on
> Oct 12 after that measurement and touched 4 pages — more than any commit then in the table.
> The figures above supersede it. **Any number in this document must be re-measured on the day
> it is quoted**; that is precisely the problem the document is about.

The case that survives contact with the data is narrower and stronger:

1. **There is no change-notification surface at all.** No product release-notes page; the
   two SDK changelogs contain a single `[Unreleased]` heading and **zero dated entries**.
   A consumer cannot answer "what changed since I last read this?" from the docs.
2. **Low volume, high blast radius.** 2 of the week's 4 changed pages were a **breaking
   package rename**, including the literal `pip install` line. One small commit invalidated
   every copy-pasted install command in circulation.
3. **Not part of the case: docs-vs-CLI drift.** An earlier draft of this document argued the
   docs and the CLI drift apart on their own schedules. Measured 2026-10-13, that is false,
   and the claim is withdrawn. See
   [Don't the docs and the CLI drift apart?](#dont-the-docs-and-the-cli-drift-apart).

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
| Oct 10–11 | — | nothing | — |
| **Oct 12** | `8d14da28` DOCSP-65098 Remove agentic platform references | `add-features/custom-output`, `memory-mcp`, `memory-only`, `memory-types` | +8/-8 |

Baseline for contrast: **8 commits between Sep 29 and Oct 2.** The docs were considerably
more volatile the fortnight before. Change volume is not the problem.

The whole path has **12 commits in total**, beginning 2026-09-28 with the 254-file seed
`2aba147c`. There is no deeper history to draw on: `content/agentengine/` did not exist in
this repo before that date.

## If the docs barely change, why watch them at all?

Because one of the four commits was this:

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

## Don't the docs and the CLI drift apart?

No — not at the reference level, and the claim that they do is withdrawn.

The `cli/` section is **machine-generated from the binary**. The CLI ships
`agentengine docs generate <dir>`, which walks its own command tree and writes one Markdown
page per command; its help text says so outright ("The docs come from the command tree, so
they match the flags and help text of the binary that produced them"). The docs repo confirms
it from the other side: commit `d57deb6c` changed 37 `cli/` pages at once, the signature of a
regenerate rather than hand-editing.

Measured 2026-10-13 with CLI 0.1.118 against the published pages:

| Check | Result |
|---|---|
| Commands generated from the binary | 117 |
| Published `cli/` pages | 121 |
| Commands in the binary with no published page | **0** |
| Published pages with no command | 4 — all hand-written guides, not command pages |
| Commands showing flag-level divergence | **0 of 117** |

Both sides derive from the same command tree, so this axis is structurally near-closed. It
earns a cheap regression guard that stays silent while they agree, not a justification for
building anything.

**The drift that does exist is a different thing entirely**, and no static comparison reaches
it: the gap between what the docs and CLI *say* and how the deployed platform actually
*behaves* — a deploy that hangs at `Memory: waiting`, a service-account memory identity shared
across users, endpoints that exist only in the OpenAPI schema. Catching that requires running
against a live project and comparing outcomes to claims. Today it is caught by hand and
written into a drift log. That is a real gap, but it is not this document's argument, and a
docs watcher of any design does not close it.

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
| Trigger | **On change, not daily** | 4 of the last 7 days are empty; daily cadence breeds muting |
| Source | **`mongodb/docs` git history**, not page hashing | Exact timestamps, file-level diffs, and *retroactive* history — hashing only knows what it saw since its first crawl |
| Output | **Agent-consumable delta first**, human notice second | The notice is the lesser half |
| Scope | **Docs changes, with CLI releases as context** | 121 of 196 published pages (62%) are CLI reference, so a CLI release drives most doc churn in one burst — ~37 pages at once in `d57deb6c`. Collapse that into a single item rather than 37 alerts |
| CLI comparison | **A silent regression guard, not a feature** | Generated-vs-published measured at 0 drift across 117 commands; build it to notice if that ever stops being true |

The current watcher hashes 195 pages daily to detect what git already records precisely. It
also demonstrates the cost of that choice: its content baseline began Oct 8, so it **missed
the Oct 7 commit entirely** and can never recover it. Switching the source to git fixes the
blind spot and the history problem at once.

## Evidence and method

Figures verified 2026-10-12, and re-verified and corrected 2026-10-13, against primary
sources:

- Docs history: `gh api "repos/mongodb/docs/commits?path=content/agentengine&since=..."`
- CLI releases: `https://api.github.com/repos/mongodb/agent-engine-client-libraries/releases`
  — **one** release in the window (v0.1.119, 2026-10-08), 7 in the preceding 13 days
- Changelog and header claims: direct fetch of the published `.md` pages and `llms.txt`
- CLI comparison (2026-10-13): `agentengine docs generate` from binary 0.1.118, command and
  flag sets diffed against every published `cli/*.md` page
- Source-to-URL mapping (2026-10-13): the `content/agentengine` subtree walked via the git
  trees API, each `source/<path>.txt` mapped to `<path>.md` and checked against `llms.txt`
  — **200 source files, 196 listed URLs, 196 matches, 0 unmatched URLs**; the 4 remainders
  are published LICENSE pages that `llms.txt` omits, so `llms.txt` is not a complete
  inventory and the source tree is the authoritative page set

Known limits, stated so the numbers are not oversold:

- `content/agentengine/` was seeded into `mongodb/docs` on **2026-09-28** (`2aba147c`, 254
  files), so there are only 12 commits of history in total and nothing before that date is
  public. Week-over-week trend claims rest on a very short series.
- The Internet Archive holds **zero** captures of these pages inside the window, so there is
  no independent corroboration of the git record — it is trusted on the assumption that the
  live site publishes from `main`.
- The CLI comparison used binary **0.1.118** while **0.1.119** was the latest release. A
  zero-drift result against a one-version-old binary does not prove the published pages track
  the newest release; it proves they track the one measured.
- Not every published change originates in a source file. A one-line edit to `snooty.toml`
  (a site-wide banner, or a substituted constant) changes up to all 196 pages while touching
  **zero** `source/*.txt` files. Any git-sourced watcher that filters to source pages alone
  will miss the single largest change it could ever encounter.
