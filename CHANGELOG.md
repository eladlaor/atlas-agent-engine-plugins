# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

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

[Unreleased]: https://github.com/eladlaor/atlas-agent-engine-plugins/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/eladlaor/atlas-agent-engine-plugins/releases/tag/v0.2.0
