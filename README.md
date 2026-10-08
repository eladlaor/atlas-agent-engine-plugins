# atlas-agent-engine-plugins

- [Summary](#summary)
- [What's inside](#whats-inside)
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
| **`aae`** | `aae-guide`, the AAE specialist: the runtime model, the agent contract, config, and the known failure modes. It checks the live docs before asserting any API detail. **`aae-scout`**, a cheap first check to run before building anything on AAE: it confirms the docs and CLI are current, then checks whether the platform, CLI, SDK, official examples or your own repo already do what you're about to build. It answers CONFIGURE, REUSE, WAIT or BUILD, with dated evidence, and keeps a list of recurring needs worth turning into plugin utilities. Plus skills: **`aae-add-agent`** adds an agent to an existing AAE monorepo, because `agentengine create` only scaffolds whole new projects. **`aae-delete-agent`** tears one down completely, because `workspace delete` alone leaves secrets, sessions and the database user behind. |
| **`aae-docs-watch`** | Detects AAE documentation changes by hashing every page's markdown, shows per-page diffs, and tells you once at session start when something moved. |

They are separate so you can take the guide and skills without anything running at
session start or on a schedule.

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
| `aae-guide` memory across sessions | Yes: a per-user memory directory it reads and writes | **No** |
| `aae-scout` | A **subagent** (runs on a smaller model, to stay cheap), with memory for its verdict and utility-candidate lists | A **skill**: same instructions; the lists appear in the answer instead of being saved |
| `aae-scout` freshness gate | Reads the `aae-docs-watch` state; needs that plugin installed | Same |
| `aae-add-agent`, `aae-delete-agent`, `aae-docs-watch` skills | Yes | Yes, the same files |
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

**Why does the guide remember things only in Claude Code?** Per-agent memory is a
Claude Code subagent feature. That memory is where the guide records what the docs
can't: your project IDs, runbooks that worked, and observed drift between the docs and
the live platform. Codex has no plugin equivalent, so in Codex the guide starts fresh
every session.

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

- **Version 0.2.0, not yet install-tested end to end on either host.** The Claude Code
  manifests pass `claude plugin validate`. The Codex manifests follow the
  [Codex plugin docs](https://developers.openai.com/codex/plugins/build) but have not
  been loaded by a Codex install yet.
- Atlas Agent Engine is in **Public Preview**: *"intended for evaluation and
  prototyping purposes only"*, with no SLAs. These plugins inherit that.
- `aae-guide` was last checked against the live docs on 2026-10-04, using
  `agentengine` CLI 0.1.118.
- Not affiliated with or endorsed by MongoDB.

Docs: [user guide](knowledge/usage_guides/USER_GUIDE.md) ·
[behaviour spec](knowledge/specs/BEHAVIOR_SPEC.md) ·
[watcher design](knowledge/plans/AAE_WATCH_DESIGN.md) ·
[ideas](knowledge/CONTRIBUTION_IDEAS.md) · [changelog](CHANGELOG.md)

MIT licensed.
