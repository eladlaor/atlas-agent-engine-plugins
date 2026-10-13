> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine agent bump-version

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Bump the agent’s declared version in agent.yaml (or its delegated manifest).

## Synopsis

Bump the version declared by the agent.yaml in the current directory, or in the nearest parent directory that has one.

With a literal version such as “1.2.0”, the bump edits agent.yaml directly. With “version: auto”, it edits the delegated manifest instead: pyproject.toml \[project].version for Python, package.json “version” for TypeScript. When agent.yaml declares no version, the command errors.

Comments and formatting in the edited file are preserved.

```bash
agentengine agent bump-version <patch|minor|major> [flags]
```

## Options

```bash
-h, --help   help for bump-version
    --json   Output JSON
```

## Options inherited from parent commands

```bash
    --log-file string    override log file path
    --log-level string   file log verbosity (error|warn|info|debug) (default "info")
    --no-log             disable file logging
-q, --quiet              silence stderr below error
-v, --verbose count      raise stderr verbosity (-v info, -vv debug)
```

## SEE ALSO

- [agentengine agent](https://www.mongodb.com/docs/agentengine/cli/agentengine_agent.md#std-label-agentengine_agent) - Inspect and edit agent configuration.
