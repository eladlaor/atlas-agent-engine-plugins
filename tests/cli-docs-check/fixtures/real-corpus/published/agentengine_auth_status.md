> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine auth status

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Show the current auth and local workspace context.

```bash
agentengine auth status [flags]
```

## Options

```bash
-h, --help   help for status
    --json   Output auth status as JSON
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

- [agentengine auth](https://www.mongodb.com/docs/agentengine/cli/agentengine_auth.md#std-label-agentengine_auth) - Authentication commands.
