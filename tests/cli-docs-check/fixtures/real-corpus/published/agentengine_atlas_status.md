> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine atlas status

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Show the platform-recorded Atlas egress link and sync status.

## Synopsis

Report the platform-recorded Atlas egress link and sync status for this workspace’s project.

`agentengine atlas setup` reflects local state. This command reports what the platform has recorded and whether the egress sync is succeeding.

```bash
agentengine atlas status [flags]
```

## Options

```bash
    --base-url string       Platform base URL
    --context string        Named context to target (see 'agentengine context list')
-h, --help                  help for status
    --org-id string         Organization ID
    --project-id string     Project ID
    --workspace string      Monorepo: target a specific workspace by name
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

- [agentengine atlas](https://www.mongodb.com/docs/agentengine/cli/agentengine_atlas.md#std-label-agentengine_atlas) - Atlas workspace setup commands.
