> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine context list

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

List the named platform targets on this machine.

## Synopsis

List every context in ~/.agentengine/contexts.json. A ’\*’ marks the context the current agent directory is pinned to, when it is pinned to one.

```bash
agentengine context list [flags]
```

## Examples

```bash
agentengine context list
agentengine context list --json
```

## Options

```bash
-h, --help   help for list
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

- [agentengine context](https://www.mongodb.com/docs/agentengine/cli/agentengine_context.md#std-label-agentengine_context) - Manage named platform targets.
