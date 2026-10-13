> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine deploy logs

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Show the event log for a deployment.

## Synopsis

Show the structured event timeline for a deployment.

With no deployment ID this shows events for the current deployment. --json cannot combine with --follow, --severity, or --category.

```bash
agentengine deploy logs [deployment-id] [flags]
```

## Options

```bash
    --base-url string       Platform base URL
    --category string       Filter by event category (for example, agent_rollout or tool_rollout)
    --context string        Named context to target (see 'agentengine context list')
-f, --follow                Poll for new events until deployment completes
-h, --help                  help for logs
    --json                  Output JSON
    --limit int             Maximum events to return per page (default 100)
    --org-id string         Organization ID
    --project-id string     Project ID
    --severity string       Filter by severity level (info, success, warn, error)
    --workspace string      Monorepo: select a specific workspace by name
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

- [agentengine deploy](https://www.mongodb.com/docs/agentengine/cli/agentengine_deploy.md#std-label-agentengine_deploy) - Deploy the last successful build to the platform.
