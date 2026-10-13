> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine debug logs

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

View CLI debug logs.

## Synopsis

View the CLI’s own debug logs.

Each invocation writes a structured JSON log file unless --no-log is set. Log files are at:

- macOS: `~/Library/Logs/agentengine/`

- Linux: `${XDG_STATE_HOME:-~/.local/state}/agentengine/logs/`

- Windows: `%LOCALAPPDATA%\agentengine\Logs\`

Flags and their environment variables:

\--log-level AGENTENGINE\_LOG\_LEVEL (default info) --log-file AGENTENGINE\_LOG\_FILE --no-log AGENTENGINE\_NO\_LOG --verbose -v, -vv raise stderr verbosity --quiet -q silence stderr below error

AGENTENGINE\_LOG\_MAX\_FILES sets the retained file count (default 20). AGENTENGINE\_NO\_LOG\_PRUNE disables automatic pruning.

When a command fails, the final stderr line shows the active log path:

For details: ~/Library/Logs/agentengine/agentengine-2026-05-13T11-43-57Z-12345.log

Examples:

```bash
agentengine debug logs list
agentengine debug logs get --last --pretty
```

## Options

```bash
-h, --help   help for logs
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

- [agentengine debug](https://www.mongodb.com/docs/agentengine/cli/agentengine_debug.md#std-label-agentengine_debug) - CLI debug logs.

- [agentengine debug logs get](https://www.mongodb.com/docs/agentengine/cli/agentengine_debug_logs_get.md#std-label-agentengine_debug_logs_get) - Print a log file.

- [agentengine debug logs list](https://www.mongodb.com/docs/agentengine/cli/agentengine_debug_logs_list.md#std-label-agentengine_debug_logs_list) - List log files, most recent first.
