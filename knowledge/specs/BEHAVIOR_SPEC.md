# aae — Behaviour Spec (v1.0)

- [Summary](#summary)
- [Scope decisions](#scope-decisions)
- [What the plugin is for](#what-the-plugin-is-for)
- [Functional requirements](#functional-requirements)
- [Behavioural contracts](#behavioural-contracts)
- [Failure behaviour](#failure-behaviour)
- [Acceptance criteria](#acceptance-criteria)
- [Explicit non-goals](#explicit-non-goals)
- [Open items](#open-items)

## Summary

**v1.0 is a two-tier change watcher for MongoDB Atlas Agent Engine, plus a specialist
agent with its knowledge base, helper skills and an `ae` CLI shortcut, for Claude Code
and Codex.**

What must be true when v1.0 ships:

| # | Statement | How it is proven |
|---|---|---|
| 1 | Installing the `aae` plugin from the `atlas-agent-engine-plugins` marketplace yields a working agent (Claude Code) or guide skill (Codex), skills and hook | Manual install run per host, recorded under [Acceptance criteria](#acceptance-criteria) |
| 2 | The watcher detects a changed docs page and names it | `AC-1` |
| 3 | The watcher detects a new `agentengine` CLI release and reports its release notes | `AC-5` |
| 4 | A session shows a change notice exactly once, then stays quiet | `AC-7` |
| 5 | Nothing runs in the background unless the user explicitly enabled it | `AC-9` |
| 6 | The README's Claude Code vs Codex matrix matches what each host actually loads | `AC-11` |

Tier 1 (docs) is **built and verified**. Tier 2 (CLI releases) is **the only new code
v1.0 requires**. Everything else is test coverage, install verification, and honesty
in the docs.

## Scope decisions

Decided 2026-10-06. These close previously open questions; do not reopen without cause.

| Decision | Choice | Consequence |
|---|---|---|
| **Scope** | Tiers 1–2: public docs + CLI releases | No credentials, no tokens, usable by any AAE user |
| **Private sources (tier 3)** | Deferred past v1.0 | Design retained in `AAE_WATCH_DESIGN.md`; no code, no config keys |
| **Codex** | Supported from 0.2.0 (2026-10-06) | Same plugin directories, a `.codex-plugin/plugin.json` beside each `.claude-plugin/plugin.json`; the subagent ships to Codex as a skill. Gaps are listed in the repo README, not hidden |
| **Session-start behaviour** | Notify once per change, else silent | No network at session start by default; no startup latency |
| **Scheduling** | Opt-in, prompted after install | Install never registers a background job by itself |
| **Packaging** (2026-10-10) | One plugin, `aae`; the docs watcher, its hook and its skill moved in from the former `aae-docs-watch` plugin | One install gets everything. The state directory, launchd label, scheduled-copy directory and skill name are unchanged, so existing installs keep their baseline. Breaking for anyone who installed `aae-docs-watch` by name |
| **Knowledge-base auto-update** (2026-10-10) | Opt-in only, via `--update-kb`; notify-only stays the default | An unattended AI run edits files only when the user asked for it, and only a clone and the user's notes, never an installed plugin |

## What the plugin is for

**The failure this exists to prevent:** an agent — or a Solutions Architect quoting
one — confidently asserting an Atlas Agent Engine detail that was correct last week
and is wrong today.

This is **not** a notification system. A notice a human reads is awareness; a digest
the agent has already absorbed is correctness. If the plugin only ever produced a
message for a human to read, it would have failed at its actual job.

Atlas Agent Engine is Public Preview, ships deliberate breaking changes, and moved
through five CLI releases in six days. The docs site publishes **no release notes at
all** — `/release-notes/` is a redirect loop, `/changelog/` and `/whats-new/` are 404.
The GitHub release `body` is the only CLI changelog that exists. That absence is the
reason tier 2 is worth building rather than a nice-to-have.

**Audience: any Atlas Agent Engine user.** The plugin ships no organization-specific
source list, project key, or query.

## Functional requirements

### Tier 1 — documentation watch (built)

- **FR-1.** The watcher MUST read the page inventory from
  `https://www.mongodb.com/docs/agentengine/llms.txt` and derive one `.md` URL per page.
- **FR-2.** It MUST detect change by SHA-256 of each page's markdown body. Conditional
  GETs are unavailable — the `.md` responses carry no `Last-Modified` and no `ETag`,
  and no sitemap publishes a `lastmod`. Hashing is therefore the only dependable
  method, not an over-engineered one.
- **FR-3.** It MUST support two modes: `--quick` (inventory only; detects pages added,
  removed or retitled) and `--full` (per-page content hashing; also detects body edits).
- **FR-4.** It MUST write a unified diff per changed page.
- **FR-5.** The first run against empty state MUST record a baseline and report
  `status=baseline`, NOT report every page as added.
- **FR-6.** It MUST refuse to overwrite its baseline when a crawl returns fewer than
  half the previously-known pages, and MUST exit non-zero saying so. A degraded network
  must never be recorded as "the docs shrank."
- **FR-20.** With `--skip-if-ran-today`, a `--full` run MUST do nothing and exit `20` when
  a full crawl already completed on the current local date, leaving that run's report in
  place. The daily schedule and the on-demand skill both use it, so a second run on the
  same day cannot replace the morning's list of changes with "clean". Without the flag a
  `--full` run always crawls.
- **FR-21.** The daily schedule MUST default to 10:00 local time, and MUST retry hourly
  until a run succeeds that day. The watcher MUST retry its first network request before
  failing, so a run started during a brief wake does not lose the day.
- **FR-26.** A failed run MUST record its error in `last-error`, and the SessionStart hook
  MUST announce, at most once a day, a failed last run or no successful full crawl for
  more than 30 hours while the schedule is installed. Silence MUST mean "checked, no
  changes", never "not checked".
- **FR-22.** The scheduled job MUST run a copy of the watcher at a fixed path
  (`${XDG_DATA_HOME:-~/.local/share}/aae-docs-watch/bin/`), never the script inside the
  versioned plugin folder, which a plugin update can delete. `install` MUST also copy the
  `aae-kb-update` `SKILL.md` there as `aae-kb-update.SKILL.md`. `status` MUST report
  whether each copy matches the plugin's version.

### Docs-to-knowledge update (opt-in)

- **FR-27.** With `--update-kb`, a run whose status is `changes` MUST, after writing
  `report.json`, start an AI runner non-interactively to run `aae-kb-update` in docs mode
  with `--auto`. Without the flag the watcher MUST only report. A runner failure, of any
  kind, MUST NOT change the run's exit code (`10`): it MUST be written to
  `kb-update-error` with a timestamp and logged, and a successful update MUST remove that
  file. The runner MUST be time-boxed (default 15 minutes, `AAE_KB_TIMEOUT_SECONDS`),
  and a timeout MUST be reported as such. Success means the runner exited `0` **and**
  recorded the report's `checked_at` in `kb-update-processed` **and** wrote a
  `kb-update.md` newer than `report.json`; anything less is a failure.
  `--kb-update-only` MUST apply the existing report without crawling, so a failed
  update can be retried.
- **FR-28.** Runner selection MUST be `AAE_KB_RUNNER` (`claude` or `codex`) when set,
  else `claude` on `PATH`, else `codex`; none found is a failure under FR-27. The skill
  MUST be located as `AAE_KB_SKILL`, else `aae-kb-update.SKILL.md` beside the watcher,
  else `../skills/aae-kb-update/SKILL.md` relative to it; none found is a failure. The
  prompt MUST name the staged skill, the state directory, the notes snapshot and the
  clone (`AAE_KB_REPO`) when set.
  - **The runner's reach is the state directory and the clone, nothing else.** The
    watcher MUST stage everything else it reads into the state directory before starting
    it: the skill (`kb-update-skill.md`), a snapshot of the notes
    (`kb-update-notes-before.md`, also the backup), and, without a clone, a read-only copy
    of the shipped knowledge base (`kb-baseline/`).
  - **The runner MUST NOT write the notes file.** Rationale: the unattended model reads
    external docs text, so it must not get unconfined edit rights (prompt injection), and
    Claude Code protects `~/.claude/`, where the notes live, from any scoped grant; so the
    model writes only in the state directory and the clone, and plain shell moves its notes
    updates into place. In `--auto` it writes notes updates to
    `notes-pending.md` in the state directory. After a successful run the watcher (plain
    shell) MUST append that file to the notes (`AAE_KB_NOTES`, default
    `~/.claude/agent-memory/aae-guide/MEMORY.md`) under a dated separator line, then
    remove it; a failed append MUST be recorded in `kb-update-error`, keeping the file.
  - The `claude` runner MUST get only the `Read`, `Edit`, `Write`, `Glob` and `Grep`
    tools (`--tools`), `--permission-mode acceptEdits` with `--permission-prompts none`,
    working directories limited to the state directory (its cwd) and the clone
    (`--add-dir`), no MCP servers, a spending cap (`AAE_KB_MAX_USD`, default 2) and a
    model setting (`AAE_KB_MODEL`, default `sonnet`). It MUST NOT use any
    permission-skipping mode or flag. The `codex` runner MUST use `-s workspace-write`
    with `-C` the state directory and `--add-dir` the clone, and no flag that disables the sandbox or approvals.
  - The runner MUST set
  `AAE_WATCH_NO_SESSION_NOTICE=1`, so the plugin's own SessionStart hook inside the runner
  session does not mark the user's notice as shown.
- **FR-29.** `install-schedule.sh install --update-kb` MUST put `--update-kb` in the job's
  arguments and store `AAE_KB_REPO`, `AAE_KB_RUNNER`, `AAE_KB_NOTES`, `AAE_KB_MAX_USD`
  and `AAE_KB_MODEL` in its environment when they are set at install time, and MUST
  refuse to install when the clone is invalid or no runner is on the job's `PATH`. The
  job's `PATH` MUST include `~/.local/bin`. `print-plist` MUST print the job definition
  without changing anything.

### Tier 2 — CLI release watch (to build)

- **FR-7.** The watcher MUST compare the latest release of
  `mongodb/agent-engine-client-libraries` (GitHub releases API, unauthenticated)
  against the locally installed version from `agentengine version --json`.
- **FR-8.** When a newer release exists, it MUST report the release **`body`**, not
  merely the version number. The body is the only published CLI changelog.
- **FR-9.** It MUST NOT upgrade the CLI, ever. MongoDB's own limitations page instructs
  users to pin the CLI and read release notes before upgrading; a tool that
  auto-upgrades contradicts the vendor's guidance for their own preview product.
  Revisit at GA.
- **FR-10.** If the `agentengine` CLI is **not installed**, tier 2 MUST be skipped
  silently and tier 1 MUST still complete. A missing CLI is not an error condition.
- **FR-11.** If the GitHub API is unreachable or rate-limited, tier 2 MUST degrade to a
  warning and tier 1 MUST still complete and still write its report.

### Agent, skill and shortcut

- **FR-12.** The `aae-guide` agent MUST verify API details against live docs before
  asserting them, because the product post-dates the model's training cutoff.
- **FR-23.** Before answering anything substantive, `aae-guide` MUST read the bundled
  `aae-kb-read` skill and then the user's personal overlay
  (`~/.claude/agent-memory/aae-guide/MEMORY.md`, Claude Code only). When they disagree, the
  newer dated entry wins. A missing baseline or overlay MUST be stated, never treated as
  empty. New findings go to the overlay, never into the shipped skill.
- **FR-24.** Every `aae-kb-read` entry that states platform behaviour MUST carry the
  date it was checked, and the CLI or SDK version where it matters. The skill MUST NOT
  contain organization-specific IDs, hostnames, or personal details.
- **FR-25.** `aae-kb-update` MUST have two named modes, MUST NOT edit an installed plugin
  copy, and MUST NOT run git.
  - **Notes mode** promotes generic findings from the personal notes into the reference
    files of a git clone of the plugin repository. It MUST NOT edit anything before the
    user approves its proposal, and MUST run its leak scan before proposing and after
    applying.
  - **Docs mode** applies the watcher's latest changes report: for each changed, added or
    removed page it MUST find the reference-file, guide-card and notes entries that rest on
    it, decide whether each is confirmed, stale or extended by a new fact, and write
    generic facts to the matching reference file and stale card claims to the card in the
    clone, and user-specific consequences to the notes. Without a clone, the shipped-file
    updates MUST go to the notes marked `baseline candidate`, and the skill MUST say so.
    Every entry MUST be dated and cite the docs page URL. It MUST NOT copy anything from
    the notes into the reference files or the card.
  - Docs mode is interactive by default and MUST NOT edit before approval. `--auto`
    applies without asking, is valid **only** in docs mode, and MUST write
    `kb-update.md` whose first line is a one-sentence summary.
  - Both docs variants MUST record the report's `checked_at` and the date in
    `kb-update-processed`, and MUST NOT apply a report already recorded there.
- **FR-13.** The `aae-docs-watch` skill MUST answer "what changed?" on demand, reading
  existing state rather than forcing a crawl. It MUST document `--update-kb` and use it
  only when the user asks for it.
- **FR-14.** `install-ae-shortcut.sh` MUST create `ae` as a **symlink on PATH**, never a
  shell alias. An alias is interactive-only and is not inherited by non-interactive
  shells — which is exactly where Claude Code and Codex run commands. An alias would
  work when typed and fail for every agent-issued command.
- **FR-15.** The installer MUST detect an existing `ae` on PATH, at the link location,
  or declared as an alias/function in a shell rc file, and MUST prompt before shadowing
  it. A collision with no TTY available MUST be a hard error, never a silent overwrite.
- **FR-16.** `uninstall` MUST refuse to remove anything that is not its own symlink.
- **FR-17.** The `aae-scout` skill MUST be read-only. It MUST NOT run any mutating
  `agentengine` command; the only `deploy` forms it may run are `deploy list` and
  `deploy get <id>`.
- **FR-18.** `aae-scout` MUST open every answer with a freshness line built from the
  docs watcher's state and the CLI release check. If the watcher script can't be found, it
  MUST say so and stop the gate, never crawl by hand. A `baseline` report MUST be
  described as "nothing compared", never as "no changes".
- **FR-19.** Every BUILD verdict from `aae-scout` MUST list the sources it searched and
  the date it searched them.

## Behavioural contracts

These are the interfaces other code depends on. Changing one is a breaking change.

### Watcher exit codes

| Code | Meaning |
|---|---|
| `0` | Ran successfully, nothing changed |
| `10` | Ran successfully, changes detected |
| `20` | Skipped: `--skip-if-ran-today` and a full crawl already completed today |
| `1` | Error — network failure, unparseable inventory, or a refused degraded crawl |

`--update-kb` never changes these codes (FR-27). `--kb-update-only` exits `0` when the
report was applied or had already been applied, and `1` when the update failed.
### State layout

Rooted at `${XDG_STATE_HOME:-~/.local/state}/aae-docs-watch`, overridable with
`AAE_WATCH_STATE_DIR`. Host-neutral on purpose: Claude Code and Codex each set their
own plugin-data directory, and only for hook commands, so a host-provided path would
split the hook, the skill and the launchd job across different baselines.

```
inventory.txt     last raw llms.txt
urls.txt          URL baseline, advanced by --quick as well as --full
manifest.tsv      url <TAB> sha256, one line per page
pages/<slug>      last fetched body per page
diffs/<slug>.diff unified diff for each changed page
report.json       machine-readable result of the last run
acknowledged      marker: the current report has been shown
last-full-run     local date and time of the last completed --full crawl
last-error        time <TAB> message of the last failed run
health-acknowledged  date the health notice was last shown
kb-update.md      --update-kb: summary of the last automatic update; line 1 is one sentence
kb-update-processed  <checked_at> <TAB> <processed at> <TAB> <docs-auto|docs-interactive>, one line per applied report
kb-update-error   time <TAB> message of the last failed automatic update
kb-update-runner.log  the runner's full output from the last automatic update
kb-update-notes-before.md  notes snapshot staged for the runner; the backup taken before the last automatic update
notes-pending.md  the runner's notes updates, appended to the notes by the watcher after a successful run
kb-update-skill.md  the aae-kb-update skill, staged for the runner
kb-baseline/      read-only copy of the shipped knowledge base, staged when no clone is set
```

The URL baseline is tracked **separately** from the content manifest so a `--quick`
run advances added/removed state without re-reporting the whole site next time.

### `report.json`

```json
{"checked_at":"...","mode":"quick|full","status":"baseline|clean|changes",
 "pages_total":195,"inventory_changed":"true|false|first-run",
 "counts":{"added":0,"removed":0,"changed":0},
 "added":[],"removed":[],"changed":[],"fetch_errors":[]}
```

Tier 2 adds a `cli` object. It MUST be additive — existing keys keep their meaning.

### SessionStart hook

- MUST emit `systemMessage` (for the user) **and**
  `hookSpecificOutput.additionalContext` (for the model). Both, because the point is
  that the model knows, not only that the human is told.
- MUST perform **no network work** by default. A SessionStart hook delays the first
  reply; the crawl belongs in the scheduled job. `AAE_WATCH_ON_SESSION=quick` opts in
  to a ~1s inventory check when state is stale.
- MUST `touch acknowledged` after emitting, so the same report never appears twice.
- When `kb-update.md` is newer than the current changes report, the notice MUST say the
  knowledge base was updated, with that file's first line, and `additionalContext` MUST
  include the summary. When `kb-update-error` exists, it MUST be part of the once-a-day
  health notice. A health problem and a changes report MUST be able to appear in the same
  notice.
- MUST emit nothing when `AAE_WATCH_NO_SESSION_NOTICE` is set (the `--update-kb` runner).
- MUST **always exit 0.** A watcher problem must never block a session.

## Failure behaviour

Fail-fast with a descriptive message, except where failing would block the user's work.

| Situation | Required behaviour |
|---|---|
| Inventory unreachable or non-200 | Exit 1, name the URL and HTTP code |
| Inventory parses to 0 URLs | Exit 1 — "the format may have changed" |
| Some pages 404 | Record in `fetch_errors`, continue, still write the report |
| Every page fetch fails | Exit 1, refuse to record an empty baseline |
| <50% of known pages fetched | Exit 1, refuse to overwrite the baseline |
| `agentengine` not installed | Skip tier 2 silently, tier 1 proceeds (FR-10) |
| GitHub API unreachable/rate-limited | Warn, tier 1 proceeds (FR-11) |
| Any hook-side failure | Exit 0, emit nothing (hook must never block) |
| `--update-kb`: no runner, skill not found, invalid clone, runner error, cap reached, timeout, or no `kb-update.md` / processed record afterwards | Write `kb-update-error`, log it, keep the crawl's exit code (FR-27) |

## Acceptance criteria

Each is a test to write. "Verified" means already demonstrated on 2026-10-06.

| ID | Criterion | Status |
|---|---|---|
| **AC-1** | Tampering one manifest hash, then `--full`, yields `status=changes`, `rc=10`, the correct URL in `changed[]`, and a `.diff` file | **Verified** |
| **AC-2** | First run on empty state yields `status=baseline`, `added=[]`, `rc=0` | **Verified** |
| **AC-3** | Second run with no upstream change yields `status=clean`, `rc=0` | **Verified** |
| **AC-4** | `--quick` completes in <5s; `--full` completes in <90s and fetches ≥95% of pages | **Verified** (1.9s / 38.3s / 195 of 195) |
| **AC-5** | With a stubbed GitHub response newer than the local CLI, the report contains the new version **and its release body** | To write |
| **AC-6** | With `agentengine` absent from PATH, the run still completes and tier 1 output is unaffected | To write |
| **AC-7** | Hook emits valid JSON with both `systemMessage` and `additionalContext` when the report says `changes`; the **second** invocation emits nothing | **Verified** |
| **AC-8** | Hook exits 0 when state is missing, malformed, or unreadable | To write |
| **AC-9** | A fresh install registers **no** launchd job; `install-schedule.sh status` reports "not installed" | **Verified** (status path) |
| **AC-10** | `install-ae-shortcut.sh` refuses to shadow an existing `ae` without a TTY, and `uninstall` refuses to delete a non-symlink | To write |
| **AC-11** | Every row of the README's host matrix matches the shipped manifests (`.claude-plugin/` vs `.codex-plugin/`) and an install run on each host | To write |
| **AC-12** | A simulated degraded crawl (<50% of pages) exits 1 and leaves `manifest.tsv` unmodified | To write |
| **AC-13** | Asked about a need AAE handles natively (e.g. "limit which agents may call mine"), `aae-scout` answers CONFIGURE and names `allowed_callers` with a docs URL | To write (`claude plugin eval` case) |
| **AC-14** | Asked about a need AAE lacks (e.g. "run my agent on a schedule"), `aae-scout` answers BUILD or WAIT, and lists the sources it searched and the date | To write (`claude plugin eval` case) |
| **AC-15** | With the watcher's state removed and the script missing from PATH and the plugin directories, `aae-scout` reports that `aae-docs-watch` isn't installed and doesn't claim the docs are current | To write |
| **AC-16** | `--full --skip-if-ran-today`: with no marker it crawls and writes `last-full-run`; a second call the same day exits `20` and leaves `report.json` unchanged; with yesterday's date in the marker it crawls; with `--quick` it exits `1` | **Verified** (2026-10-09) |
| **AC-18** | Asked a question answered only in `aae-kb-read`, `aae-guide` (Claude Code) loads the skill from the installed plugin, reads the overlay, reads only the reference files the question touches, and cites them | **Verified** (2026-10-10) |
| **AC-17** | `install` copies the watcher to the fixed path and the plist points at the copy; `status` reports `current`, then `OUT OF DATE` after the copy is edited, then `MISSING` after it is deleted; `uninstall` removes the copy | **Verified** (2026-10-09); the `aae-kb-update` copy's `status` lines verified 2026-10-10 |
| **AC-19** | Without `--update-kb`, a run on a seeded changed page exits `10` and writes no `kb-update*` file | **Verified** (2026-10-10) |
| **AC-20** | With `--update-kb` and neither `claude` nor `codex` on `PATH`, a run with changes exits `10`, writes `kb-update-error`, and the next hook run shows the health notice together with the changes notice | **Verified** (2026-10-10) |
| **AC-21** | A real `claude` run on a seeded diff (a role added to a docs role list) edits the matching reference file in a throwaway clone, writes `kb-update.md` and `kb-update-processed`, and a second run on the same report changes nothing | **Verified** (2026-10-10, Sonnet, USD 0.42; the repeat run, through the watcher and with the runner started directly, changed nothing) |
| **AC-22** | `print-plist --update-kb` output passes `plutil -lint` and holds `--update-kb`, the `AAE_KB_*` variables set at install time, and `~/.local/bin` on `PATH`; without the flag it holds none of them; an invalid `AAE_KB_REPO` or no runner on the job's `PATH` is refused | **Verified** (2026-10-10) |
| **AC-23** | The `codex` runner applies a seeded diff | To write (no signed-in Codex available) |

**Install verification (not automatable, must be done once before delivery):**
add the `eladlaor/atlas-agent-engine-plugins` marketplace in **each** host, install the
plugin on a machine that has never had it, and confirm the agent (Claude Code) or
guide skill (Codex) is listed, the skills are discoverable, and the hook fires — in
Codex only after the user trusts it. **Neither host has executed this path yet.** It is
the highest-risk unknown in the project.

Progress on 2026-10-10:
- **Claude Code:** done. Installed from the marketplace, the subagent and skills are
  listed, and `aae-guide` loads `aae-kb-read` (AC-18).
- **Codex:** partly done. The marketplace adds from GitHub, both plugins install, and all
  six skills reach the model prompt with absolute paths. This was checked with
  `codex-cli` 0.162.1 in an isolated `CODEX_HOME` via `codex debug prompt-input`.
- **After the merge into one plugin (2026-10-10):** a local-path marketplace in an
  isolated `CODEX_HOME` lists only `aae`, it installs with its `hooks/` and `scripts/`,
  and all seven skills, including `aae-docs-watch`, reach the model prompt.
- **Still open:** a real Codex conversation, and the hook firing after trust. Codex sets
  `CLAUDE_PLUGIN_ROOT` for plugin hooks (per its plugin docs), so the hook command should
  resolve.

## Explicit non-goals

Stated so they are not mistaken for omissions:

- **No CLI auto-upgrade** (FR-9). Detect and report only.
- **No private/internal sources in v1.0.** Design retained, no code.
- **No MCP server in v1.0.** The marketplace entries carry no `mcp` tag, so none is
  claimed.
- **No chat/Slack watching, ever.** Product channels are human escalation surfaces,
  not release feeds; watching them yields noise indistinguishable from signal.
- **No evaluation of AAE itself.** This watches the product's surface, not its quality.
- **No automatic publishing of knowledge.** `--update-kb` edits a clone and the user's
  notes; committing and releasing stay with the user.

## Open items

1. Where tier 2's state lives inside `report.json` — additive `cli` object, shape TBD.
2. Whether `--quick` should also run tier 2 (it is one cheap API call; probably yes).
3. No `tests/` directory exists. AC-5 through AC-12 need somewhere to live and a runner.
