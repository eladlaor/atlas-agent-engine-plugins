# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

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

[Unreleased]: https://github.com/eladlaor/atlas-agent-engine-plugins/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/eladlaor/atlas-agent-engine-plugins/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/eladlaor/atlas-agent-engine-plugins/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/eladlaor/atlas-agent-engine-plugins/releases/tag/v0.2.0
