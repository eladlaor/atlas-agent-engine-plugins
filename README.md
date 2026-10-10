# atlas-agent-engine-plugins

- [Summary](#summary)
- [What's inside](#whats-inside)
- [How does this relate to the skills the CLI installs?](#how-does-this-relate-to-the-skills-the-cli-installs)
- [Install](#install)
- [Claude Code vs Codex: what each host gets](#claude-code-vs-codex-what-each-host-gets)
- [Why the differences exist](#why-the-differences-exist)
- [Optional extras](#optional-extras)
- [Status and caveats](#status-and-caveats)

## Summary

Plugins for working with **MongoDB Atlas Agent Engine** (AAE), MongoDB's managed runtime
for deploying and governing AI agents, from **Claude Code** or **Codex**. One repo is two
marketplaces: each plugin directory carries a Claude Code manifest and a Codex manifest
side by side, and the skills are shared files in the open `SKILL.md` format.

AAE is in Public Preview. Its docs change weekly, and its CLI ships faster than the docs.
The failure these plugins exist to prevent is an AI assistant confidently answering from
a model of the product that was correct last week.

## What's inside

| Plugin | Contents |
|---|---|
| **`aae`** | `aae-guide`, the AAE specialist: the runtime model, the agent contract, config, and the known failure modes. It checks the live docs before asserting any API detail. **`aae-scout`** (a skill), a cheap first check to run before building anything on AAE: it confirms the docs and CLI are current, then checks whether the platform, CLI, SDK, official examples or your own repo already do what you're about to build. It answers CONFIGURE, REUSE, WAIT or BUILD, with dated evidence, and keeps a list of recurring needs worth turning into plugin utilities. Plus skills: **`aae-add-agent`** adds an agent to an existing AAE monorepo, because `agentengine create` only scaffolds whole new projects. **`aae-delete-agent`** tears one down completely, because `workspace delete` alone leaves secrets, sessions and the database user behind. **`aae-knowledge`** is the guide's bundled knowledge base: a dated log of where the live platform has drifted from the docs, verified details the guides omit, runbooks, and troubleshooting. Every entry carries the date and CLI version it was checked on. |
| **`aae-docs-watch`** | Detects AAE documentation changes by hashing every page's markdown, shows per-page diffs, and tells you once at session start when something moved. |

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
- **Agents, not only skills.** In Claude Code, `aae-guide` runs in its own context and
  keeps a personal memory overlay. It reads the CLI's skills first when they're present.
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
```

Then install `aae` and/or `aae-docs-watch` from the Plugins Directory. If you install
`aae-docs-watch`, **review and trust its hook when Codex asks**. Until you do, Codex skips
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
| Scheduled nightly docs crawl | Opt-in, via macOS `launchd` | Same: opt-in, via macOS `launchd` |

## Why the differences exist

**Why is `aae-guide` a subagent in Claude Code but a skill in Codex?** Codex plugins
cannot ship subagents. They can contain skills, MCP servers, app connectors, hooks and
assets, but no agents. So the Codex build ships a thin `aae-guide` skill that tells the
model to read the subagent's instruction file and follow it. The content is identical
and lives in one file, `plugins/aae/agents/aae-guide.md`. What Codex loses is
**isolation**: the guide's long instructions and its doc-fetching land in your main
conversation instead of a separate context that hands back only the answer. In Claude
Code the skill sees that the `aae-guide` subagent exists and delegates to it instead.

**Why does the guide remember some things only in Claude Code?** The guide works from
two layers. The **baseline** is the `aae-knowledge` skill: a dated drift log, verified
details, runbooks and troubleshooting, shipped with the plugin. Skills work in both
hosts, so Codex gets the same baseline. The **personal overlay** is a per-user memory
directory where the guide records what is specific to you: your project IDs, runbooks
that worked for you, and drift you observed. Per-agent memory is a Claude Code subagent
feature with no Codex plugin equivalent, so in Codex only the overlay is missing: the
guide starts each session with the baseline but without your personal notes. When the
two layers disagree, the newer dated entry wins and the guide re-checks the live docs.

**Why is the knowledge a skill rather than part of the agent file?** Skills are the
one component both hosts load, and a loaded skill tells the model where its files live,
so the guide can read the reference files the question touches instead of carrying all
of them in its instructions. Updating the plugin updates the baseline; your overlay is
never touched.

**Why does the Codex hook need my approval?** Codex deliberately skips hooks bundled
in plugins until a user reviews and trusts them. Trust is tied to a hash of the hook
definition, so an update that changes the hook asks again. Claude Code runs plugin
hooks on install. The hook itself is the same file and works in both hosts.

**Why do the skills locate scripts "two directories above this file" instead of using
`$CLAUDE_PLUGIN_ROOT`?** Both hosts set a plugin-root variable for *hook* commands,
not for commands the model runs itself. A path relative to the skill file works in both.

**Why does the watcher keep its state in `~/.local/state/aae-docs-watch`?** Each host
has its own plugin-data folder, and sets it only for hooks. Keeping state outside
either host means the hook, the skill and the launchd job all read the same baseline,
and someone running both Claude Code and Codex sees each change once, not twice.

**Why is scheduling the same in both?** Neither host lets a plugin declare scheduled
work, so the nightly crawl is a `launchd` job you install yourself.

## Optional extras

From a clone of this repo:

```bash
plugins/aae/scripts/install-ae-shortcut.sh install        # type `ae` instead of `agentengine`
plugins/aae-docs-watch/scripts/install-schedule.sh install # nightly docs crawl (macOS)
plugins/aae-docs-watch/scripts/aae-docs-watch.sh --full    # record the first baseline
```

Uninstalling a plugin does not remove these. Each script has an `uninstall`.

The `ae` shortcut is a symlink on `PATH`, not a shell alias. Aliases only exist in
interactive shells, and Claude Code and Codex run their commands in non-interactive
ones.

## Status and caveats

- **Version 0.5.1. Installed and in use in Claude Code**; the manifests pass
  `claude plugin validate`. The Codex manifests follow the
  [Codex plugin docs](https://developers.openai.com/codex/plugins/build) but have not
  been loaded by a Codex install yet.
- Atlas Agent Engine is in **Public Preview**: *"intended for evaluation and
  prototyping purposes only"*, with no SLAs. These plugins inherit that.
- `aae-guide`'s card was last checked against the live docs on 2026-10-04, and its
  `aae-knowledge` baseline through 2026-10-10, using `agentengine` CLI 0.1.118 and SDK
  0.11.8. Each knowledge entry carries its own date.
- Not affiliated with or endorsed by MongoDB.

Docs: [user guide](knowledge/usage_guides/USER_GUIDE.md) ·
[behaviour spec](knowledge/specs/BEHAVIOR_SPEC.md) ·
[watcher design](knowledge/plans/AAE_WATCH_DESIGN.md) · [changelog](CHANGELOG.md)

MIT licensed.
