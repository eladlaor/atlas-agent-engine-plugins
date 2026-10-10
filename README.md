# atlas-agent-engine-plugins

- [Summary](#summary)
- [What's inside](#whats-inside)
  - [`aae` plugin](#aae-plugin)
  - [`aae-docs-watch` plugin](#aae-docs-watch-plugin)
- [How does this relate to the skills the CLI installs?](#how-does-this-relate-to-the-skills-the-cli-installs)
- [Install](#install)
- [Claude Code vs Codex: what each host gets](#claude-code-vs-codex-what-each-host-gets)
- [Optional extras](#optional-extras)
- [Status and caveats](#status-and-caveats)

## Summary

Plugins for working with **MongoDB Atlas Agent Engine** (AAE), MongoDB's managed runtime
for deploying and governing AI agents, from **Claude Code** or **Codex**. One repo is two
marketplaces: each plugin directory carries a Claude Code manifest and a Codex manifest
side by side, and the skills are shared files in the open `SKILL.md` format.

These plugins add two things:

1. **Value on top of what the `agentengine` CLI already gives you.** The CLI installs a
   few skills into each project. These plugins build on them with a continually-learning knowledge base,
   utilities the CLI doesn't ship, and a specialist subagent
   ([details](#how-does-this-relate-to-the-skills-the-cli-installs)).
2. **Protection against AI agent knowledge drift.** AAE is in Public Preview: its docs
   change weekly and its CLI ships faster than the docs. The plugins keep an assistant
   from answering confidently from a picture of the product that is no longer true.

## What's inside

### `aae` plugin

| Resource | Type | What it does |
|---|---|---|
| `aae-guide` | Subagent (a skill in Codex) | The AAE specialist: runtime model, agent contract, config, and known failure modes. Checks the live docs before asserting any API detail. |
| `aae-knowledge` | Skill | The guide's bundled knowledge base: a dated drift log, verified details the docs omit, runbooks, and troubleshooting. Every entry carries the date and CLI version it was checked on. |
| `aae-scout` | Skill | A cheap check before building anything: confirms the docs and CLI are current, then whether the platform, CLI, SDK, official examples or your repo already do it. Answers CONFIGURE, REUSE, WAIT or BUILD, with dated evidence. |
| `aae-add-agent` | Skill | Adds one agent to an existing AAE monorepo. `agentengine create` only scaffolds whole new projects. |
| `aae-delete-agent` | Skill | Tears one agent down completely. `workspace delete` alone leaves secrets, sessions and the database user behind. |
| `ae` | Shell shortcut (optional) | Type `ae` instead of `agentengine`. See [Optional extras](#optional-extras). |

### `aae-docs-watch` plugin

| Resource | Type | What it does |
|---|---|---|
| `aae-docs-watch` | Skill | Checks the AAE docs on demand by hashing every page's markdown, and shows per-page diffs. |
| Session-start notice | Hook | Tells you once, at session start, when the docs changed. |
| Daily crawl | `launchd` job (optional, macOS) | Runs the check every day, at 10:00 by default. See [Optional extras](#optional-extras). |

They are separate so you can take the guide and skills without anything running at
session start or on a schedule.

## How does this relate to the skills the CLI installs?

`agentengine init` writes a few vendor-maintained skills into each project
(`atlas-agent-engine-docs`, `feature-validations`, `troubleshoot-deploy`). They cover
reading the docs, checking framework code, and walking a failed deploy, and they load
only inside that project. These plugins build on them rather than replacing them:

- **Knowledge the docs don't have.** `aae-knowledge` is a dated record of what running
  the platform taught: where the CLI and platform drift from the docs, where doc pages
  contradict each other, failures outside the deploy path, and version-pinned runbooks.
- **Utilities the CLI doesn't ship.** Add or fully tear down one agent in a monorepo,
  detect docs changes, and check for prior art before building.
- **A subagent, not only skills.** In Claude Code, `aae-guide` runs in its own context
  and keeps a personal memory overlay. It reads the CLI's skills first when they're present.
- **Available everywhere,** not just inside a project directory.

Details: [`CLI_SKILLS_AND_THIS_PLUGIN.md`](plugins/aae/skills/aae-knowledge/references/CLI_SKILLS_AND_THIS_PLUGIN.md).

## Install

**Claude Code**

```
/plugin marketplace add eladlaor/atlas-agent-engine-plugins
/plugin install aae@atlas-agent-engine-plugins
/plugin install aae-docs-watch@atlas-agent-engine-plugins
```

**Codex**

```bash
codex plugin marketplace add eladlaor/atlas-agent-engine-plugins
codex plugin add aae@atlas-agent-engine-plugins
codex plugin add aae-docs-watch@atlas-agent-engine-plugins
```

Or install them from the Plugins Directory. If you install `aae-docs-watch`, **review and trust its hook when Codex asks**. Until you do, Codex skips
it and you get no notices.

## Claude Code vs Codex: what each host gets

| Component | Claude Code | Codex |
|---|---|---|
| `aae-guide` | A **subagent**: runs in its own context window, on its own model, and Claude delegates to it | A **skill**: the same instructions, loaded into your main conversation |
| `aae-guide` bundled knowledge (`aae-knowledge` skill: drift log, verified details, runbooks, troubleshooting) | Yes | Yes, the same files |
| `aae-guide` personal memory across sessions (your project IDs, your own drift notes) | Yes: a per-user memory directory it reads and writes | **No** |
| `aae-scout` | A **skill**, with its verdict and utility-candidate ledgers in `~/.local/state/aae-scout/` | Same, sharing the same ledgers |
| `aae-scout` freshness gate | Reads the `aae-docs-watch` state; needs that plugin installed | Same |
| `aae-add-agent`, `aae-delete-agent`, `aae-knowledge`, `aae-docs-watch` skills | Yes | Yes, the same files |
| Session-start notice that the docs changed | Runs automatically | Runs **only after you trust the hook**, and again after each update that changes it |
| Scheduled daily docs crawl | Opt-in, via macOS `launchd` | Same: opt-in, via macOS `launchd` |

## Optional extras

From a clone of this repo:

```bash
plugins/aae/scripts/install-ae-shortcut.sh install        # type `ae` instead of `agentengine`
plugins/aae-docs-watch/scripts/install-schedule.sh install # daily docs crawl (macOS)
```

Uninstalling a plugin does not remove these. Each script has an `uninstall`.

The daily docs crawl is a scheduled job **on your own machine**, like a cron entry.
On macOS it uses `launchd` (the macOS equivalent of cron): `install` writes
`~/Library/LaunchAgents/com.eladlaor.aae-docs-watch.plist`, which runs the docs check
every day at 10:00 (change it with `--hour` / `--minute`). If the Mac is asleep at that
time, it runs on wake; if it's off, that day is skipped. Nothing runs in the cloud.
Check it with `install-schedule.sh status`. On Linux, add an equivalent cron entry
yourself.

The `ae` shortcut is a symlink on `PATH`, not a shell alias. Aliases only exist in
interactive shells, and Claude Code and Codex run their commands in non-interactive
ones.

## Status and caveats

- **Version 0.5.2.** Installed and in use in Claude Code; the manifests pass
  `claude plugin validate`. In Codex (codex-cli 0.162.1), both plugins install and all
  skills load; a full Codex conversation and the hook-trust flow are not yet tested.
- Atlas Agent Engine is in **Public Preview**: *"intended for evaluation and
  prototyping purposes only"*, with no SLAs. These plugins inherit that.
- Knowledge is checked against the live docs with `agentengine` CLI 0.1.118 and SDK
  0.11.8; each `aae-knowledge` entry carries its own date. CLI 0.1.119 is out but untested.
- Not affiliated with or endorsed by MongoDB.

Docs: [user guide](knowledge/usage_guides/USER_GUIDE.md) ·
[behaviour spec](knowledge/specs/BEHAVIOR_SPEC.md) ·
[watcher design](knowledge/plans/AAE_WATCH_DESIGN.md) · [changelog](CHANGELOG.md)

MIT licensed.
