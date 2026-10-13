> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine workspace sessions

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

List and stop runtime sessions for a workspace.

## Synopsis

List and stop sessions that currently hold reserved runtime for a workspace.

A session is active while it holds reserved agent and tool sandbox capacity, and stopping while that capacity is still releasing. It disappears from the list once released. Conversation history remains after the backing runtime is gone.

Testing sessions created from the Playground or `agentengine invoke` may be reclaimed automatically when the workspace is at capacity. Other sessions are user-managed and stay reserved until they go idle or you stop them.

Examples:

```bash
agentengine workspace sessions list
agentengine workspace sessions stop <session-id>
```

## Options

```bash
-h, --help   help for sessions
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

- [agentengine workspace](https://www.mongodb.com/docs/agentengine/cli/agentengine_workspace.md#std-label-agentengine_workspace) - Manage workspaces on Agent Engine.

- [agentengine workspace sessions list](https://www.mongodb.com/docs/agentengine/cli/agentengine_workspace_sessions_list.md#std-label-agentengine_workspace_sessions_list) - List sessions that currently hold runtime capacity.

- [agentengine workspace sessions stop](https://www.mongodb.com/docs/agentengine/cli/agentengine_workspace_sessions_stop.md#std-label-agentengine_workspace_sessions_stop) - Stop a runtime session’s reserved sandbox capacity.
