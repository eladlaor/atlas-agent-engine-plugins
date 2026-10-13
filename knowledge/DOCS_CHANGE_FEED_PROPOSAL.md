# Proposal: Publish a Change Surface for the Agent Engine Docs

- [What is being asked for?](#what-is-being-asked-for)
- [What is missing today?](#what-is-missing-today)
- [Why does it matter if the docs barely change?](#why-does-it-matter-if-the-docs-barely-change)
- [Why can't a reader just watch the repository on GitHub?](#why-cant-a-reader-just-watch-the-repository-on-github)
- [What have we already built, and what do we need from you?](#what-have-we-already-built-and-what-do-we-need-from-you)
- [What is NOT being claimed](#what-is-not-being-claimed)
- [Before sending this](#before-sending-this)

## What is being asked for

**One thing: a way to answer "what changed in the Agent Engine docs since I last read them?"**

In order of preference, any one of these closes it:

1. **Dated entries in the two SDK changelogs.** They already follow Keep a Changelog and
   already have an `[Unreleased]` heading. Filling in dated version blocks costs nothing new.
2. **A product release-notes page.** The URL already exists as a redirect; it currently
   resolves to nothing.
3. **A machine-readable feed** — an Atom feed, a `lastmod` in a sitemap, or a
   `Last-Modified` header on the published pages.

Any of the three removes the need for every consumer to invent their own detection. We are
not asking for all three, and we are not asking you to adopt any tool of ours.

## What is missing today

Verified 2026-10-13 against the live site. Each is checkable in under a minute.

| Check | Result |
|---|---|
| `/docs/agentengine/release-notes` | Infinite 301 redirect loop. `release-notes` appears **zero** times in the docs' own page inventory (`llms.txt`) |
| The two SDK changelog pages | Contain only `## [Unreleased]`. **No dated version block has ever been added** |
| `Last-Modified` on published `.md` pages | **0 of 196** send one |
| A date on the page itself | Only page-render time, which moves on every site rebuild. Observed changing from Oct 9 to Oct 12 on a page with no commit in between |
| A sitemap with `lastmod` | The Agent Engine sitemap URL returns an HTML error page |
| Conditional GET (`If-None-Match`) | The `.md` pages send no `ETag`; the HTML pages send a weak one and ignore it, returning 200 |

The net effect: **there is no published way to learn that anything changed**, short of
re-reading all 196 pages.

## Why does it matter if the docs barely change?

Because volume is not the risk — blast radius is. In the seven days to 2026-10-13 the docs
took 4 commits touching 8 published pages. One of them was this:

```diff
-   pip install agentic-platform-memory
+   pip install agent-engine-sdk-memory
```

The memory SDK package was renamed, in prose and in the literal install command. Anyone
working from a copy taken a day earlier now writes an install command that fails. The same
commit left the anchor IDs behind, so the prose and the link target disagree — the kind of
half-finished migration a diff catches and a human skim does not.

**The misunderstanding worth heading off:** "changes rarely" and "safe to ignore" are not the
same claim. A docs set that changes rarely is *more* dangerous to skip, because nobody
develops the habit of re-reading it.

This matters more for Agent Engine than for a typical product, for a reason specific to it:
the product launched after the training cutoff of every model currently in use. An assistant
asked about Agent Engine has no prior knowledge to fall back on and must read the docs. When
the docs move and the assistant's copy does not, it answers confidently and wrongly.

## Why can't a reader just watch the repository on GitHub?

They partly can, and this should be said plainly rather than hidden. The publishing
repository is public, so GitHub's watch, the commits feed, and a path-filtered Action all
provide free change notification.

**And it is noisy.** The Agent Engine docs are one path inside a monorepo that serves many
products. Since the Agent Engine content was seeded on 2026-09-28, `mongodb/docs` took **418
commits, of which 12 touched `content/agentengine` — 2.87%.** Watching the repository means
sifting 418 notifications to find 12. A path-filtered Action narrows that, but only for
someone who already knows which path, and it still answers "a file moved", not "this
published page changed".

Three reasons it is not a substitute:

**It asks every consumer to reverse-engineer the publishing pipeline.** To turn a repository
commit into "which published page changed", a consumer has to know the source layout, the
source-path-to-URL mapping, which files are transcluded includes rather than pages, and that
a single line in the site config changes every page while touching no page file. We worked
all of that out; the next team will have to do it again. A published feed states it once,
authoritatively.

**It tells a human, not a system.** A notice a person reads is awareness. What a documentation
consumer needs — above all an AI assistant answering from the docs — is a structured delta it
can absorb. The failure mode is not "I missed an email", it is *an agent confidently answering
from a model of the product that was correct last week*.

## What have we already built, and what do we need from you?

**We need no access, no credentials and no permission.** The publishing repository is public;
we verified the history API answers with no token at all. Nothing in this proposal is blocked
on you granting anything. This section exists so you can see the workaround the gap forces,
and reuse it if it is useful.

Working today, tested, in a public plugin repository:

| Piece | What it does |
|---|---|
| Git-sourced detector | Reads the publishing repository's history for the Agent Engine content path and reports added, removed and changed **published pages**, with commit dates, authors and messages |
| Include fan-out | A changed shared include resolves to every page that transcludes it, resolved at the reported commit rather than at HEAD, so adding an include and editing its consumers in one commit is not double-counted |
| Site-config fan-out | A one-line change to the site config is reported as affecting every published page. This is the single largest change a naive source-path filter would miss entirely |
| Release-burst collapsing | A CLI release regenerates ~37 reference pages at once; the human summary states that as one event rather than 37 |
| CLI reference guard | Compares the CLI's self-generated reference against the published pages; silent while they agree |
| Test suite | 46 tests, no network and no external test framework required |

One finding from building it that is worth your attention, because it is a **credit** rather
than a complaint: the published CLI reference is generated from the binary's own command tree,
and we measured it at **117 of 117 commands matching with zero flag-level divergence**. That
is the pattern we are asking you to extend — the CLI reference already derives from the real
definition; the change surface does not yet derive from anything.

## What is NOT being claimed

Stated so no figure here is oversold.

- **The docs are not churning.** Volume is low, and the case does not rest on volume.
- **The CLI reference is not drifting.** We measured it and it is in sync. An earlier draft of
  our own rationale claimed otherwise and was wrong; the claim was withdrawn.
- **The history is short.** The content path was seeded into the publishing repository on
  2026-09-28, so there are only 12 commits in total. Week-over-week trend claims rest on a
  very short series, and we have not made any.
- **One version behind.** The CLI comparison used binary 0.1.118 while 0.1.119 was current. It
  proves agreement with the version measured, not with the newest release.
- **We are not reporting a bug.** Nothing here is broken. The ask is for a surface that was
  never built, in a product still in preview, where that is entirely reasonable.

## Before sending this

**Re-measure every figure on the day it is sent.** The gaps listed above are exactly the kind
that get quietly closed, and being wrong on the opening table costs the whole argument. The
checks take about a minute:

```sh
curl -sIL https://www.mongodb.com/docs/agentengine/release-notes | grep -c '^HTTP'
curl -sS  https://www.mongodb.com/docs/agentengine/llms.txt | grep -c release-notes
curl -sI  https://www.mongodb.com/docs/agentengine/add-features/memory-only.md | grep -i last-modified

# signal-to-noise, in a clone of mongodb/docs:
git rev-list --count origin/main --since=2026-09-28
git rev-list --count origin/main --since=2026-09-28 -- content/agentengine
```

A non-looping release-notes page, a non-zero inventory hit, or a `Last-Modified` header each
means the corresponding row is stale and must be corrected or dropped.
