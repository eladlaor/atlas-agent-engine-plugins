> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine debug logs get

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Print a log file.

## Synopsis

Print the contents of a log file.

Pass a filename from `agentengine debug logs list`, or use --last for the most recent log file. Without either, the command fails. --last skips the current invocation’s own log file. Output is raw JSON lines; --pretty indents and colorizes it.

Examples:

```bash
agentengine debug logs get --last --pretty
agentengine debug logs get agentengine-2026-05-13T11-43-57Z-12345.log
```

```bash
agentengine debug logs get [logfile] [flags]
```

## Options

```bash
-h, --help     help for get
    --last     Print the most recent log file
    --pretty   Indent and colorize JSON output
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
