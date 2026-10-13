> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine deploy get

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Get details of a deployment.

## Synopsis

Show the full status of a deployment: conditions, components, and health.

With no deployment ID this shows the current (most recent) deployment for the workspace. Run from an initialized agent directory, or pass --workspace-id.

```bash
agentengine deploy get [deployment-id] [flags]
```

## Options

```bash
    --base-url string       Platform base URL
    --context string        Named context to target (see 'agentengine context list')
-f, --follow                Stream live events until the deployment completes
-h, --help                  help for get
    --json                  Output JSON
    --org-id string         Organization ID
    --project-id string     Project ID
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
