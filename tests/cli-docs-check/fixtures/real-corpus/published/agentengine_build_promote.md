> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine build promote

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Promote a succeeded build into another workspace.

## Synopsis

Promote a succeeded build image into another workspace without rebuilding it.

\<source\_build\_id> names the source build; the platform resolves it within the current organization. --workspace, --context, and the explicit target flags select the destination workspace.

A non-interactive shell fails unless you pass --yes. --force bypasses the successful-deploy proof gate and requires the target project owner role.

Examples:

```bash
agentengine build promote bld_abc123 --workspace prod
agentengine build promote bld_abc123 --context prod
```

```bash
agentengine build promote <source_build_id> [flags]
```

## Options

```bash
    --base-url string       Platform base URL
    --context string        Named context to target (see 'agentengine context list')
    --force                 Bypass the successful-deploy proof gate (target project owner role required)
-h, --help                  help for promote
    --json                  Output promotion result as JSON
    --org-id string         Organization ID
    --project-id string     Project ID
    --workspace string      Monorepo: select a destination workspace by name (from root agent.yaml)
    --workspace-id string   Workspace ID
-y, --yes                   Skip the interactive confirmation prompt
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

- [agentengine build](https://www.mongodb.com/docs/agentengine/cli/agentengine_build.md#std-label-agentengine_build) - Package and build the agent image on the platform.

- [agentengine build promote get](https://www.mongodb.com/docs/agentengine/cli/agentengine_build_promote_get.md#std-label-agentengine_build_promote_get) - Get build promotion status.
