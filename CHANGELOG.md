# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- The README explains that the daily docs crawl is a `launchd` job on your own machine (the macOS equivalent of cron), where it's installed, and when it runs.

## [0.5.2] - 2026-10-10

Plugin versions: `aae` 0.4.2, `aae-docs-watch` 0.3.1.

### Changed

- `aae-guide`'s card is re-verified against the live docs, OpenAPI spec and CLI 0.1.118 on 2026-10-10: `agent.yaml` keys and per-sandbox egress, `app.llm(llm_id=)`, the memory SDK package for local mode, role details, trace export and install channels are corrected; claims with no doc source are marked unverified.
- The drift log and doc-contradiction list are updated with the 2026-10-10 findings, including CLI 0.1.119 release notes running ahead of the docs.
- The README summary states the plugins' two aims, lists each plugin's resources in its own table, and drops the "card last checked 2026-10-04" caveat; the "Why the differences exist" design FAQ is removed from the README.
- The plugin and marketplace descriptions mention the guide's bundled knowledge base.
- The README and user guide drop the manual first-baseline crawl; the first scheduled or on-demand check records it.
- The Codex install steps use `codex plugin add`, verified with codex-cli 0.162.1.
- The behaviour spec requires the two-layer knowledge read (FR-23) and dated, organization-neutral knowledge entries (FR-24), and records the 2026-10-10 install checks on both hosts.

### Fixed

- The user guide's Claude Code install steps include the `aae` plugin, and the guide lists `aae-scout` and its shared ledger location.
- The README calls the scheduled docs crawl daily (10:00 by default), not nightly.
- Docs no longer describe the plugin as shipping several agents, or the Codex manifests and `mcp` tag as still pending.

## [0.5.1] - 2026-10-10

Plugin versions: `aae` 0.4.1, `aae-docs-watch` 0.3.1.

### Added

- `aae-knowledge` explains how the plugin complements the skills `agentengine init` installs into each project, and which one answers which question; the README summarizes it.

### Changed

- `aae-guide` reads the CLI's project skills first when the working directory has them, and builds on them instead of restating them.

## [0.5.0] - 2026-10-10

Plugin versions: `aae` 0.4.0, `aae-docs-watch` 0.3.1.

### Added

- `aae-guide` knows how an external client connects to a deployed workspace (service account, OAuth token, `invokeStream`, custom-header forwarding) and knows the `AGENT_DEVELOPER` service-account role.
- `aae-knowledge` skill in the `aae` plugin: the guide's bundled, dated AAE knowledge base (drift log, verified details, doc contradictions, CLI targeting, monorepo and build rules, SDK adapters, identity, cost accounting, capability gaps, runbooks, troubleshooting), available in both Claude Code and Codex.

### Changed

- `aae-guide` reads two layers before answering, the bundled `aae-knowledge` baseline and the user's own memory overlay, lets the newer dated entry win, and says so when either is missing.
- `aae-guide` consults the drift log before trusting its 2026-10-04 snapshot sections.
- The Codex `aae-guide` skill reads the `aae-knowledge` references too, so Codex users get the same baseline.
- README and user guide explain that the baseline ships to both hosts and only the personal overlay is Claude Code-only.

### Removed

- `knowledge/CONTRIBUTION_IDEAS.md` is no longer published; the README no longer links it.
- The `aae-scout` subagent: `aae-scout` is now only a skill, in both hosts. Its instructions moved into the skill, and its ledgers moved from the Claude Code agent-memory directory to `~/.local/state/aae-scout/`, shared by both hosts.

### Fixed

- `aae-guide` now reads its `MEMORY.md` explicitly instead of assuming it is injected.
- `aae-guide` no longer calls the documented egress IPs stale: it distinguishes the Atlas-lane pair from the pair external services must allowlist.
- The `aae-guide` and `aae-add-agent` skill frontmatter is valid YAML again (the `description` is now quoted), so GitHub renders it and strict parsers load it.

## [0.4.1] - 2026-10-09

Plugin versions: `aae` 0.3.1, `aae-docs-watch` 0.3.1.

### Fixed

- The daily docs check runs a copy of the watcher from `~/.local/share/aae-docs-watch/bin/`
  instead of the versioned plugin folder, so a plugin update can no longer break it
  silently. `install-schedule.sh status` reports when the copy is out of date or missing.
  Re-run `install` once after updating.

## [0.4.0] - 2026-10-09

Plugin versions: `aae` 0.3.1, `aae-docs-watch` 0.3.0.

### Added

- `aae-docs-watch.sh --skip-if-ran-today`: a full check that already completed today is not
  repeated (exit `20`), so a second run can't replace the morning's list of changes. The
  daily schedule and the `aae-docs-watch` skill both use it; `--full` alone still forces a
  crawl.

### Changed

- The daily docs check now defaults to 10:00 local time instead of 09:00.
- AAE Watch design: the deployed watcher shares the detection rules, not the code.
  `aae-docs-watch.sh` stays bash, so the plugin still needs only bash, curl and jq.

### Removed

- User-specific sections from `aae-guide` (personal coding standards, language-register
  guidance, a personal secret-manager command, first-person anecdotes), so it addresses any
  AAE user. The skill's reference to the guide's memory section follows the renumbering.

## [0.3.0] - 2026-10-08

### Added

- `aae-scout` agent in the `aae` plugin (a subagent in Claude Code, a skill in Codex). It
  checks that the AAE docs and CLI are current, then checks whether the platform, CLI,
  SDK, official examples, or the user's own work already provide what is about to be
  built. It returns CONFIGURE, REUSE, WAIT, or BUILD with dated evidence, and keeps a
  list of recurring needs that could become plugin utilities.
- Contribution ideas 2–4: a scheduled-invoke helper, a fleet spec kit (agent spec cards
  plus an A2A message contract), and a golden-set evaluation harness.
- Behaviour spec FR-17 to FR-19 and AC-13 to AC-15 for `aae-scout`.
- AAE Watch design: a section on the deployed watcher that will share its detection logic.

## [0.2.0] - 2026-10-06

First release as a standalone repository. Earlier history lives in the `aae` plugin of
[claudelad](https://github.com/eladlaor/claudelad), where it was 0.1.0.

### Added

- Codex support: every plugin ships a `.codex-plugin/plugin.json` alongside its
  `.claude-plugin/plugin.json`, and the repo carries a Codex marketplace at
  `.agents/plugins/marketplace.json` next to the Claude Code one.
- `aae-guide` skill, so that Codex, which cannot load plugin subagents, gets the guide's
  instructions from the same source file. In Claude Code it defers to the subagent.
- README section listing what each host gets and why the two differ.

### Changed

- Split the former single `aae` plugin into `aae` (guide, add-agent and delete-agent
  skills, `ae` shortcut) and `aae-docs-watch` (watcher, session-start hook, launchd
  schedule), so the guide can be installed without anything running in the background.
- Docs-watch state moved to `${XDG_STATE_HOME:-~/.local/state}/aae-docs-watch`, shared by
  both hosts, the hook and the launchd job. Existing baselines under the Claude Code
  plugin-data directory are not migrated; the first run records a new one.
- Skills locate bundled scripts relative to their own file instead of through
  `$CLAUDE_PLUGIN_ROOT`, which neither host sets for model-run commands.
- Behaviour spec: Codex moves from deferred to supported, and acceptance criterion
  AC-11 now checks the host matrix against the shipped manifests.

### Removed

- Internal hostnames and personal model aliases from `aae-guide` examples.

[Unreleased]: https://github.com/eladlaor/atlas-agent-engine-plugins/compare/v0.5.2...HEAD
[0.5.2]: https://github.com/eladlaor/atlas-agent-engine-plugins/compare/v0.5.1...v0.5.2
[0.5.1]: https://github.com/eladlaor/atlas-agent-engine-plugins/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/eladlaor/atlas-agent-engine-plugins/compare/v0.4.1...v0.5.0
[0.4.1]: https://github.com/eladlaor/atlas-agent-engine-plugins/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/eladlaor/atlas-agent-engine-plugins/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/eladlaor/atlas-agent-engine-plugins/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/eladlaor/atlas-agent-engine-plugins/releases/tag/v0.2.0
