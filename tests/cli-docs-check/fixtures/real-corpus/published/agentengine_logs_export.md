> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine logs export

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Export up to 24 hours of runtime logs.

## Synopsis

Export customer-visible agent and tool runtime logs as gzip-compressed JSON Lines.

\--service is required. The window is at most 24 hours; --since takes a duration or an RFC3339 timestamp, and --until defaults to now. The download is written atomically, so a failed or interrupted export leaves no partial file at the destination. The output path must not already exist. An export larger than 20 MiB compressed or 100 MiB decoded is rejected.

Examples:

```bash
agentengine logs export --service agent
agentengine logs export --service tool --since 6h --output logs.jsonl.gz
```

```bash
agentengine logs export [flags]
```

## Options

```bash
    --base-url string       Platform base URL
    --context string        Named context to target (see 'agentengine context list')
-h, --help                  help for export
    --org-id string         Organization ID
-o, --output string         Output path (default: agent-logs-<service>-<end-time>.jsonl.gz)
    --project-id string     Project ID
    --service string        Required runtime service to export: agent or tool
    --since string          Start time as a duration (e.g. 6h, 24h) or RFC3339 timestamp (maximum 24h) (default "24h")
    --until string          End time as a duration (e.g. 5m) or RFC3339 timestamp (default: now)
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

- [agentengine logs](https://www.mongodb.com/docs/agentengine/cli/agentengine_logs.md#std-label-agentengine_logs) - Stream agent runtime logs.
