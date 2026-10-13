> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine atlas cluster list

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

List Atlas clusters for the saved Atlas project.

```bash
agentengine atlas cluster list [flags]
```

## Options

```bash
    --base-url string       Platform base URL
    --context string        Named context to target (see 'agentengine context list')
    --env string            Atlas environment name, such as cloud-dev
-h, --help                  help for list
    --json                  Output Atlas clusters as JSON
    --org-id string         Organization ID
    --profile string        Atlas service account profile to use
    --project-id string     Project ID
    --workspace string      Monorepo: use Atlas setup for a specific workspace by name
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

- [agentengine atlas cluster](https://www.mongodb.com/docs/agentengine/cli/agentengine_atlas_cluster.md#std-label-agentengine_atlas_cluster) - Manage the Atlas cluster selected for this workspace.
