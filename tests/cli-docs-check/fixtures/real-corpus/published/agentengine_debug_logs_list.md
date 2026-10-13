> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine debug logs list

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

List log files, most recent first.

```bash
agentengine debug logs list [flags]
```

## Options

```bash
-h, --help   help for list
    --json   Output log file list as JSON
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

- [agentengine debug logs](https://www.mongodb.com/docs/agentengine/cli/agentengine_debug_logs.md#std-label-agentengine_debug_logs) - View CLI debug logs.
