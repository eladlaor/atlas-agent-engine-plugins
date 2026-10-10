# atlas-agent-engine-plugins

- [Summary](#summary)
- [What's inside](#whats-inside)
- [How does this relate to the skills the CLI installs?](#how-does-this-relate-to-the-skills-the-cli-installs)
- [Install](#install)
- [Claude Code vs Codex: what each host gets](#claude-code-vs-codex-what-each-host-gets)
- [Optional extras](#optional-extras)
- [Status and caveats](#status-and-caveats)

## Summary

A plugin for working with **MongoDB Atlas Agent Engine** (AAE), MongoDB's managed runtime
for deploying and governing AI agents, from **Claude Code** or **Codex**. One repo is two
marketplaces: the plugin directory carries a Claude Code manifest and a Codex manifest
side by side, and the skills are shared files in the open `SKILL.md` format.

The plugin adds two things:

1. **Value on top of what the `agentengine` CLI already gives you.** The CLI installs a
   few skills into each project. This plugin builds on them with a continually-learning knowledge base,
   utilities the CLI doesn't ship, and a specialist subagent
   ([details](#how-does-this-relate-to-the-skills-the-cli-installs)).
2. **Protection against AI agent knowledge drift.** AAE is in Public Preview: its docs
   change weekly and its CLI ships faster than the docs. The plugin keeps an assistant
   from answering confidently from a picture of the product that is no longer true.

**Token-efficient by design.** Checking the docs costs no AI tokens. A plain script
hashes every docs page and compares the hashes with the last run. Only when that check
finds a change does the AI model see anything, and then only the diffs of the pages that
changed. On a day with no changes the model reads nothing and the session-start notice
stays silent. The same holds with the opt-in `--update-kb` flag: the model that updates
the knowledge base is started only when the hash check finds a change.

## What's inside

One plugin, `aae`:

| Resource | Type | What it does |
|---|---|---|
| `aae-guide` | Subagent (a skill in Codex) | The AAE specialist: runtime model, agent contract, config, and known failure modes. Checks the live docs before asserting any API detail. |
| `aae-kb-read` | Skill | The guide's bundled knowledge base: a dated drift log, verified details the docs omit, runbooks, and troubleshooting. Every entry carries the date and CLI version it was checked on. |
| `aae-kb-update` | Skill | Updates the knowledge from one of two sources. **Notes mode** promotes the generic findings from your personal notes into `aae-kb-read`, in your clone of this repo, after you approve. **Docs mode** applies the docs watcher's latest changes to the entries that rest on the changed pages. |
| `aae-scout` | Skill | A cheap check before building anything: confirms the docs and CLI are current, then whether the platform, CLI, SDK, official examples or your repo already do it. Answers CONFIGURE, REUSE, WAIT or BUILD, with dated evidence. |
| `aae-add-agent` | Skill | Adds one agent to an existing AAE monorepo. `agentengine create` only scaffolds whole new projects. |
| `aae-delete-agent` | Skill | Tears one agent down completely. `workspace delete` alone leaves secrets, sessions and the database user behind. |
| `aae-docs-watch` | Skill | Checks the AAE docs on demand. Change detection is a deterministic hash comparison with no AI involved; the model reads only the per-page diffs, and only when something changed. |
| Session-start notice | Hook | Tells you once, at session start, when the docs changed, and whether the knowledge base was already updated from them. Also warns, once a day, when the watcher or the automatic update is failing. |
| Daily docs crawl | `launchd` job (optional, macOS) | Runs the check every day, at 10:00 by default, retried hourly until it succeeds. With `--update-kb`, it also updates the knowledge base when the docs changed. See [Optional extras](#optional-extras). |
| `ae` | Shell shortcut (optional) | Type `ae` instead of `agentengine`. See [Optional extras](#optional-extras). |

Nothing runs on a schedule unless you install the daily crawl, and the session-start hook
makes no network calls.

## How does this relate to the skills the CLI installs?

`agentengine init` writes a few vendor-maintained skills into each project
(`atlas-agent-engine-docs`, `feature-validations`, `troubleshoot-deploy`). They cover
reading the docs, checking framework code, and walking a failed deploy, and they load
only inside that project. This plugin builds on them rather than replacing them:

- **Knowledge the docs don't have.** `aae-kb-read` is a dated record of what running
  the platform taught: where the CLI and platform drift from the docs, where doc pages
  contradict each other, failures outside the deploy path, and version-pinned runbooks.
- **Utilities the CLI doesn't ship.** Add or fully tear down one agent in a monorepo,
  detect docs changes, and check for prior art before building.
- **A subagent, not only skills.** In Claude Code, `aae-guide` runs in its own context
  and keeps a personal memory overlay. It reads the CLI's skills first when they're present.
- **Available everywhere,** not just inside a project directory.

Details: [`CLI_SKILLS_AND_THIS_PLUGIN.md`](plugins/aae/skills/aae-kb-read/references/CLI_SKILLS_AND_THIS_PLUGIN.md).

## Install

**Claude Code**

```
/plugin marketplace add eladlaor/atlas-agent-engine-plugins
/plugin install aae@atlas-agent-engine-plugins
```

**Codex**

```bash
codex plugin marketplace add eladlaor/atlas-agent-engine-plugins
codex plugin add aae@atlas-agent-engine-plugins
```

Or install it from the Plugins Directory. In Codex, **review and trust the plugin's hook
when asked**. Until you do, Codex skips it and you get no session-start notices.

## Claude Code vs Codex: what each host gets

| Component | Claude Code | Codex |
|---|---|---|
| `aae-guide` | A **subagent**: runs in its own context window, on its own model, and Claude delegates to it | A **skill**: the same instructions, loaded into your main conversation |
| `aae-guide` bundled knowledge (`aae-kb-read` skill: drift log, verified details, runbooks, troubleshooting) | Yes | Yes, the same files |
| `aae-guide` personal memory across sessions (your project IDs, your own drift notes) | Yes: a per-user memory directory it reads and writes | **No** |
| `aae-scout` | A **skill**, with its verdict and utility-candidate ledgers in `~/.local/state/aae-scout/` | Same, sharing the same ledgers |
| `aae-scout` freshness gate | Reads the docs watcher's state | Same |
| `aae-add-agent`, `aae-delete-agent`, `aae-kb-read`, `aae-kb-update`, `aae-docs-watch` skills | Yes | Yes, the same files |
| Session-start notice that the docs changed | Runs automatically | Runs **only after you trust the hook**, and again after each update that changes it |
| Scheduled daily docs crawl | Opt-in, via macOS `launchd` | Same: opt-in, via macOS `launchd` |
| `--update-kb` runner | `claude -p`, tested | `codex exec`, **untested** |

## Optional extras

From a clone of this repo, or from the installed plugin's directory:

```bash
plugins/aae/scripts/install-ae-shortcut.sh install          # type `ae` instead of `agentengine`
plugins/aae/scripts/install-schedule.sh install [--update-kb] # daily docs check on your Mac (launchd)
plugins/aae/scripts/install-schedule.sh status              # installed, current, healthy?
```

Each script has an `uninstall`. How the docs watcher, the daily check and `--update-kb`
work, and their settings: [`HOW_IT_WORKS.md`](plugins/aae/skills/aae-docs-watch/HOW_IT_WORKS.md).

## Status and caveats

- **Tested in Claude Code**, including the `--update-kb` runner. In Codex (codex-cli
  0.162.1) the plugin installs and all skills load; a full conversation, the hook-trust
  flow and the `--update-kb` runner are untested.
- Atlas Agent Engine is in **Public Preview**: *"intended for evaluation and
  prototyping purposes only"*, with no SLAs. This plugin inherits that.
- Knowledge is checked against the live docs with `agentengine` CLI 0.1.118 and SDK
  0.11.8; each `aae-kb-read` entry carries its own date. CLI 0.1.119 is out but untested.
- Not affiliated with or endorsed by MongoDB.

Docs: [user guide](knowledge/usage_guides/USER_GUIDE.md) ·
[behaviour spec](knowledge/specs/BEHAVIOR_SPEC.md) ·
[how the docs watcher works](plugins/aae/skills/aae-docs-watch/HOW_IT_WORKS.md) ·
[watcher design](knowledge/plans/AAE_WATCH_DESIGN.md) · [changelog](CHANGELOG.md)

MIT licensed.
