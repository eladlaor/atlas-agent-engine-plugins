> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine workspace sessions list

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

List sessions that currently hold runtime capacity.

## Synopsis

List sessions that currently hold reserved agent or tool sandbox capacity, or are still releasing it.

Status is active while capacity is held and stopping while release is in progress. Last activity and scheduled release follow the workspace idle timeout. Scheduled release is omitted while a session is still stopping.

```bash
agentengine workspace sessions list [flags]
```

## Examples

```bash
agentengine workspace sessions list
agentengine workspace sessions list --json
```

## Options

```bash
    --base-url string       Platform base URL
    --context string        Named context to target (see 'agentengine context list')
-h, --help                  help for list
    --json                  Output JSON
    --org-id string         Organization ID
    --project-id string     Project ID
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

- [agentengine workspace sessions](https://www.mongodb.com/docs/agentengine/cli/agentengine_workspace_sessions.md#std-label-agentengine_workspace_sessions) - List and stop runtime sessions for a workspace.
