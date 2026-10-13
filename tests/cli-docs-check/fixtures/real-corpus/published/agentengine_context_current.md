> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine context current

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Show the context commands run here will use, and where it came from.

## Synopsis

Reports the context in effect for the current directory: its base URL, organization, and project, plus the tier that named it, either a --context flag or the directory’s pin.

Fails if nothing names a context, so a script can use it as a check.

```bash
agentengine context current [flags]
```

## Examples

```bash
agentengine context current
agentengine context current --context prod
```

## Options

```bash
    --context string   Report this context instead of the directory's pin
-h, --help             help for current
    --json             Output JSON
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

- [agentengine context](https://www.mongodb.com/docs/agentengine/cli/agentengine_context.md#std-label-agentengine_context) - Manage named platform targets.
