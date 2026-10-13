# Git-Sourced Docs Watch — Implementation Plan

- [Summary](#summary)
- [Decisions this plan implements](#decisions-this-plan-implements)
- [What the measurements established](#what-the-measurements-established)
- [The contract the replacement must honour](#the-contract-the-replacement-must-honour)
- [Phase 0 — Test harness and fixtures](#phase-0--test-harness-and-fixtures)
- [Phase 1 — Git-sourced detector](#phase-1--git-sourced-detector)
- [Phase 2 — CLI regression guard](#phase-2--cli-regression-guard)
- [Phase 3 — The pitch](#phase-3--the-pitch)
- [Parallel tracks and serialization](#parallel-tracks-and-serialization)
- [What still needs a greenlight](#what-still-needs-a-greenlight)
- [Risks](#risks)
- [Open questions](#open-questions)

## Summary

Replace the watcher's **detection source** — page hashing to git history on the public
`mongodb/docs` repository — while holding its **artifact contract** (`report.json`, the state
directory, the exit codes) stable, so the knowledge-base updater, the session-start notice,
the `aae-scout` freshness gate and the launchd schedule keep working untouched. Add a cheap
CLI regression guard. Produce a gap report aimed at the Agent Engine docs owners.

The deliverable is a mechanism that is already built, already tested and already running, so
the only thing left to ask the team for is the thing we cannot build ourselves.

**Order of work:** Phase 0 (tests) blocks Phase 1 (detector). Phase 2 is independent and can
run in parallel. Phase 3 depends on Phase 1 being demonstrable.

## Decisions this plan implements

Decided 2026-10-13. Behaviour decisions belong in
[`BEHAVIOR_SPEC.md`](../specs/BEHAVIOR_SPEC.md); this table records only what scopes the work.

| # | Decision | Consequence for this plan |
|---|---|---|
| D1 | Git history **replaces** page hashing; the two do not coexist | One detector to maintain; the hashing path is removed once Phase 1 passes Phase 0's tests |
| D2 | The artifact contract stays **byte-compatible** | Four downstream consumers are untouched; `report.json` stays compact single-line |
| D3 | The pitch is a **short self-contained message plus a working reference implementation** | The argument ships in the message, not as a document to link; evidence and delivery guidance stay in the untracked ideas file |
| D4 | **TDD**: the test harness and the ported acceptance criteria come first | Phase 0 blocks Phase 1 |
| D5 | Scope is **docs-change detection plus a CLI regression guard**; live-platform conformance probing is out | No live project, no per-run cost, nothing that can affect real resources |

## What the measurements established

All verified 2026-10-13 against primary sources. These are the facts the plan rests on; if
one is later found false, the work item that rests on it is void.

| Finding | Measurement | Consequence |
|---|---|---|
| `mongodb/docs` is public and readable **unauthenticated** | `"private": false`; commits API returns 200 with no token | **No key, no permission, no business greenlight is needed to build or run this.** External plugin users can run it too |
| Source path → published URL maps exactly | 200 source files, 196 `llms.txt` URLs, 196 derived URLs match, 0 unmatched URLs; the 4 extras are published LICENSE pages `llms.txt` omits | The mapping is mechanical; no heuristics needed |
| `llms.txt` is **not** a complete inventory | Omits 4 published pages | The source tree, not `llms.txt`, is the authoritative page set |
| Commit noise is low | 11 non-seed commits, 59 changed files, 57 published pages, 2 non-pages (~3.4%) | A path filter of `source/**/*.txt` minus `source/includes/**` suffices |
| Redirects are trivial | 3 entries, all in a central file outside the content dir | No redirect-resolution layer needed |
| rST diffs are readable without rendering | Hard-wrapped one-sentence-per-line; tighter hunks than the reflowed `.md` | Report the source diff directly, with light markup stripping |
| **CLI reference is auto-generated from the binary** | `agentengine docs generate` → 117 pages; 117/117 commands match published; **0 flag drift** at CLI 0.1.118 | Doc-vs-CLI drift is structurally near-closed. A detector here is a *regression guard*, not a discovery |
| Includes fan out, but tractably | 22 include directives, max fan-out 6 pages, 1 orphan | Resolvable with one grep at the commit's tree |
| The existing watcher has **no tests** | No `*test*` / `*.bats` anywhere in the repo; AC-1..AC-16 are hand-verified prose | Phase 0 exists

### The three drift axes, and which this plan covers

The rationale doc lists "the docs and the CLI drift apart, and nothing announces it" as its
third justification. **That justification is not supported by measurement and the plan does
not rest on it.** The measurement, and the withdrawal of the claim, are recorded in the untracked `knowledge/CONTRIBUTION_IDEAS.md` (idea 6).

| Axis | Detectable how | In scope? |
|---|---|---|
| A published page changed | Git history on `mongodb/docs` | **Yes** — Phase 1 |
| Docs disagree with the CLI surface | Generate from the binary, diff against published | **Yes, as a regression guard** — Phase 2. Measured at zero today |
| Docs/CLI disagree with **live platform behaviour** | Runtime probes against a real project | **No** — out of scope per D5. This is the axis the knowledge base's drift log holds, caught by hand |

## The contract the replacement must honour

Established by reading the shipped code, not the design doc. **The design doc's `CURRENT.md`
and `delta.json` were never built** — the real artifact is `report.json`, and
`AAE_WATCH_DESIGN.md` marks the others as still a plan.

**`report.json`, exactly 10 keys, compact and single-line:**

`checked_at` (UTC ISO-8601, and the *identity* of a report), `mode`, `status`
(`baseline|clean|changes`), `pages_total`, `inventory_changed` (string `true|false|first-run`),
`counts{added,removed,changed}`, `added[]`, `removed[]`, `changed[]` (absolute page URLs),
`fetch_errors[]`.

**It is read textually in two places** — `grep '"status":"changes"'` and a `sed` for
`checked_at`. Pretty-printing it silently breaks `--update-kb` and `--kb-update-only`.
Compactness is part of the contract, not a formatting preference.

**State directory layout**, slug rule (`URL minus DOCS_BASE, / → __`, `.md` suffix retained),
`diffs/<slug>.diff`, `pages/<slug>`, `last-full-run`, `last-error`, `acknowledged`.

**Exit codes:** `0` clean/baseline, `10` changes, `20` skipped, `1` error. The launchd job and
the session hook both branch on these.

**Four consumers break if any of the above moves:** `session-notice.sh` (embedded Python,
tightest coupling), the `aae-kb-update` skill, the `aae-scout` freshness gate, and
`install-schedule.sh` (hard-indexes `["status"]` and `["counts"]`).

### Hashing-specific surface that needs an explicit decision

Each of these exists only because detection was an HTTP crawl. Phase 1 must decide
**emulate / redefine / retire** for each, and record the decision in `BEHAVIOR_SPEC.md`.

| Element | Why it existed | Proposed call |
|---|---|---|
| `--quick` mode | Inventory fetch (~1s) vs full crawl (~40s) | **Redefine**: a git detector has no cheap/expensive split, but `--quick` is published CLI surface and is the `AAE_WATCH_ON_SESSION` path. Keep the flag, make it "check for new commits only, do not resolve diffs" |
| `inventory_changed` | Byte-compare of `llms.txt` | **Redefine**: true when the set of published pages changed in the commit range |
| `fetch_errors[]` | HTTP status per page | **Retire the meaning, keep the key**: always `[]` unless the git fetch itself fails. Key must stay — consumers read it |
| `pages/<slug>` | Shadow copy to diff against | **Keep**: the KB updater reads it for full page context. Populate from the published `.md` for changed pages only |
| Degraded-crawl guards | A partial crawl looks like mass deletion | **Retire**: git either fetches a commit range or fails |
| Network retry around first request | Scheduled wake before network is up | **Keep**: same problem applies to the git fetch |

## Phase 0 — Test harness and fixtures

**Blocks Phase 1.** Nothing in Phase 1 merges until these pass.

| # | Work item | Done when |
|---|---|---|
| 0.1 | Choose and vendor a shell test framework (`bats-core`), wire a `make test` / `scripts/run-tests.sh` entry point | `run-tests.sh` exits non-zero on a deliberately broken assertion |
| 0.2 | Record fixtures: the 12 real `content/agentengine` commits as a local bare git repo, plus the published `.md` bodies they correspond to | Fixtures are offline-replayable; no test touches the network |
| 0.3 | Port AC-1..AC-16 from `BEHAVIOR_SPEC.md` into executable tests **against the current hashing watcher** | All 16 pass against the shipped script, unmodified |
| 0.4 | Add contract tests that assert the 10 `report.json` keys, compactness (single line, no space after colon), and the exit-code table | Mutating the script to pretty-print `report.json` makes a test fail |
| 0.5 | Add consumer-level tests: feed a known `report.json` to `session-notice.sh` and `install-schedule.sh status`, assert their output | Both consumers verified against a fixture report |

**Why 0.3 runs against the *old* script first:** a test suite written against the new detector
proves only that the new detector does what it does. Passing against the shipped script first
is what makes it a *regression* suite.

## Phase 1 — Git-sourced detector

| # | Work item | Done when |
|---|---|---|
| 1.1 | Commit-range resolution: store last-seen SHA in state, fetch commits touching `content/agentengine` since it | A fixture range yields exactly the expected commit list |
| 1.2 | Path filter and classification: published page / include / global (`snooty.toml`) / ignorable | Against the 11 fixture commits, classification matches the hand-labelled expected set (57 pages, 2 non-pages) |
| 1.3 | Source-path → published-URL mapping, lowercased both sides | All 200 fixture source paths map; a deliberately malformed path fails loudly |
| 1.4 | Include fan-out resolution **at the commit's tree**, not HEAD | A changed include reports all 6 consuming pages; the `7cc702e2` case (include added *and* consumers edited in one commit) does not double-count |
| 1.5 | `snooty.toml` global fan-out: constant and banner changes resolved to affected pages | A one-line banner edit reports page-wide impact rather than zero pages |
| 1.6 | CLI-reference collapsing: ~37 simultaneous `cli/` page diffs become one item | The `d57deb6c` fixture produces a single "CLI reference regenerated" entry, not 37 |
| 1.7 | Emit `report.json` to the existing contract; populate `diffs/` and `pages/` | Phase 0's contract tests pass unmodified |
| 1.8 | Retroactive backfill: resolve history from before first run | A fresh state dir can report the `ab74effd` commit the hashing watcher permanently missed |
| 1.9 | Remove the hashing path; update `SKILL.md`, `HOW_IT_WORKS.md`, `README.md`, `BEHAVIOR_SPEC.md`, `AAE_WATCH_DESIGN.md` | No shipped doc still asserts the hashing rationale (see Risks) |

## Phase 2 — CLI regression guard

Independent of Phases 0–1; can run in parallel.

| # | Work item | Done when |
|---|---|---|
| 2.1 | `agentengine docs generate` into a temp dir, normalize, diff command set against the published `cli/` inventory | Reproduces today's measured result: 117/117 commands, 0 flag drift |
| 2.2 | Flag-level comparison per command, with the `---` false positive eliminated | A synthetic fixture with a removed flag is detected; the real corpus reports clean |
| 2.3 | Report shape: silent while in agreement, loud on divergence; record the CLI version on both sides | A run against a deliberately stale generated set reports the exact commands and flags that diverge |
| 2.4 | Decide where the result surfaces: own exit code, or an additive `cli` object in `report.json` (the spec already reserves this: "Tier 2 adds a `cli` object. It MUST be additive") | Decision recorded in `BEHAVIOR_SPEC.md`; consumers unaffected either way |

## Phase 3 — The pitch

Depends on Phase 1 being demonstrable. **The pitch is not an artifact in this repository.**
The argument, its evidence and the guidance on how to deliver it live in the untracked
`knowledge/CONTRIBUTION_IDEAS.md` (idea 6), which is a private working file. What goes to the
team is a short message that *is* the argument, not a link to one.

| # | Work item | Done when |
|---|---|---|
| 3.1 | Re-measure every figure on the day the message is sent | No stale number; the Oct 12 undercount cannot recur |
| 3.2 | Keep the withdrawn drift claim withdrawn | The message states the measured 117/117 result as credit, never as a complaint |
| 3.3 | Write the message so it stands alone | A reader who opens no link still gets the gap, the cost and the ask |
| 3.4 | State the ask precisely: dated changelog entries, or a release-notes page, or a feed | Grantable without adopting anything of ours |
| 3.5 | Point at code only for verification, never for the argument | Links go to the scripts and the test suite, not to prose |

**The message must survive "why not just watch the repo on GitHub?"** Answer it before it is
asked: 418 commits to the monorepo since 2026-09-28 against 12 touching `content/agentengine`
— 2.87%. Repo-watching also reports that a source file moved, not which published page
changed, and tells a human rather than producing a delta an assistant can absorb.

## Parallel tracks and serialization

```
Track A (serial):   Phase 0 ──▶ Phase 1 ──▶ Phase 3
Track B (parallel): Phase 2 ─────────────────┘
```

- Phase 0 and Phase 2 can start at the same time by different agents; they share no files.
- Phase 1 must not start before 0.3 and 0.4 pass against the shipped script.
- Phase 3 drafting can begin once 1.7 passes; 3.1 must be re-run on the day it is sent.

## What still needs a greenlight

The original framing was "build the mechanism so we only need to ask for the key". **There is
no key.** The detection side needs no permission at all: `mongodb/docs` is public and the
commits API answers unauthenticated.

| Thing | Needed for |
|---|---|
| Nothing | Building, testing and running everything in Phases 0–2 |
| Publishing a change feed | The suggestion in Phase 3 — something only the docs owners can do, and which this plugin cannot build for them |

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| **`snooty.toml` is an invisible global fan-out** — a one-line edit changes up to 196 published pages while touching zero source `.txt` files | A naive `source/**/*.txt` filter silently misses the largest possible change | Work item 1.5 treats it as a special case. A test asserts it |
| Shipped docs assert the hashing rationale as settled — `SKILL.md` says "do not propose an If-Modified-Since approach" | The repo contradicts itself for anyone reading both | 1.9 revises them in the same change |
| `report.json` is parsed textually by `grep`/`sed` | A formatting change breaks two code paths silently | 0.4 asserts compactness |
| A future `git mv` of `content/agentengine/` | Path-filtered detection silently returns nothing | Pin on `--follow`, or on the `snooty.toml` `name` field. A zero-commits-ever result must fail loudly, never report "clean" |
| Root tree API response is truncated for this repo | Naive `trees/<HEAD>?recursive=1` returns incomplete data | Walk down to the `agentengine` subtree; never trust an untruncated flag without checking it |
| Invisible-change false positives: `:ref:` target ids and `.. meta:: :description:` edits | Reports a change with no on-page effect | Classify and mark them low-signal rather than suppressing them |
| No live project in scope means the valuable drift axis stays hand-caught | The strongest pitch is not built | Accepted under D5. Revisit once Phases 0–2 ship |

## Open questions

| # | Question | Blocking? |
|---|---|---|
| O1 | Do downstream consumers of the hashing rationale need updating in step with 1.9? | Not blocking Phase 0–2; must be resolved before 1.9 |
| O2 | Where does the CLI guard's result surface — own exit code, or additive `cli` object? | Blocks 2.4 only |
| O3 | Does the gap report go to the docs owners, the product team, or both? Different asks land differently | Blocks 3.3 |
| O4 | Is `agentengine docs generate` output stable across versions, or does formatting churn produce false drift? | Blocks 2.2; test across two CLI versions |
