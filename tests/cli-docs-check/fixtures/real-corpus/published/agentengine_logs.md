> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine logs

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Stream agent runtime logs.

## Synopsis

View agent and tool runtime logs for a workspace.

Interactive queries cover at most 6 hours; query longer ranges in multiple windows of at most 6 hours. --since takes a duration (1h by default) or an RFC3339 timestamp. --tail returns the most recent entries, capped at 5000; use --all for the full window.

Logs exist only after the workspace has been deployed. For the CLI’s own diagnostics, use `agentengine debug logs`.

Examples:

```bash
agentengine logs --follow
agentengine logs --source agent --level error --grep "connection refused"
```

```bash
agentengine logs [flags]
```

## Options

```bash
    --all                   Fetch all logs in the time range (auto-paginates through all pages within the 6-hour interactive window)
    --base-url string       Platform base URL
    --context string        Named context to target (see 'agentengine context list')
    --execution-id string   Filter by execution ID
-f, --follow                Continuously poll for new logs
    --grep string           Search log messages (case-insensitive substring match)
-h, --help                  help for logs
    --json                  Output logs as JSON
    --level string          Log level(s) to match exactly (debug, info, warn, error), comma- or space-separated
    --org-id string         Organization ID
    --project-id string     Project ID
    --session-id string     Filter by session ID
    --since string          Start time as duration (e.g. 30m, 2h) or RFC3339 timestamp (default "1h", maximum "6h")
    --source string         Filter by source sandbox(s) (agent, tool), comma- or space-separated
    --tail int              Number of most-recent entries to return (capped at 5000; use --all for the full window) (default 500)
    --until string          End time as duration (e.g. 5m) or RFC3339 timestamp (default: now)
    --workspace string      Monorepo: select a specific workspace by name (from root agent.yaml)
    --workspace-id string   Workspace ID
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

- [agentengine](https://www.mongodb.com/docs/agentengine/cli/agentengine.md#std-label-agentengine) - Agent Engine local development CLI.

- [agentengine logs export](https://www.mongodb.com/docs/agentengine/cli/agentengine_logs_export.md#std-label-agentengine_logs_export) - Export up to 24 hours of runtime logs.
