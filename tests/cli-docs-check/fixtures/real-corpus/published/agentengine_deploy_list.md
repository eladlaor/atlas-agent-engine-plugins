> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine deploy list

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

List deployments for a workspace.

## Synopsis

List deployments for a workspace.

Run from an initialized agent directory, or pass --workspace-id to target a workspace with no agent directory. In a monorepo, use --workspace \<name>.

```bash
agentengine deploy list [flags]
```

## Options

```bash
    --base-url string       Platform base URL
    --context string        Named context to target (see 'agentengine context list')
-h, --help                  help for list
    --json                  Output JSON
    --limit int             Maximum number of deployments to return
    --offset int            Number of deployments to skip
    --org-id string         Organization ID
    --project-id string     Project ID
    --status string         Filter by status (e.g., succeeded, failed, in_progress)
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

- [agentengine deploy](https://www.mongodb.com/docs/agentengine/cli/agentengine_deploy.md#std-label-agentengine_deploy) - Deploy the last successful build to the platform.
