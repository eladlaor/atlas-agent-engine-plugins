> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine workspace create

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Create a new workspace on the platform.

## Synopsis

Create a new workspace on the platform.

Run this from an agent directory containing an agent.yaml. The manifest must declare entrypoint; name is optional.

```bash
agentengine workspace create [flags]
```

## Options

```bash
    --base-url string      Platform base URL
    --context string       Named context to target (see 'agentengine context list')
    --description string   Workspace description
    --framework string     Agent framework (e.g. langgraph)
-h, --help                 help for create
    --json                 Output JSON
    --org-id string        Organization ID
    --project-id string    Project ID
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
