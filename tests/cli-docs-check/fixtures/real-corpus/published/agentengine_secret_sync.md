> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine secret sync

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Sync secrets to deployments.

## Synopsis

Reload values already stored on the platform into active deployments. This command never imports secret values from local files.

Success is printed only after the project runtime has rolled onto those values, so the next message can use them. The current turn keeps previous values. If no deployments are running, the command still waits for the project runtime.

By default this syncs project-scoped secrets (shared across all workspaces in the project). To sync workspace-scoped secrets instead, pass --workspace-scope or supply --workspace-id.

For Atlas-linked contexts this syncs project-scoped deployments and may warn if a legacy .env.\<context> file is still present (it is never read).

\--context names the organization and project only, so combine it with --project-scope.

```bash
agentengine secret sync [flags]
```

## Options

```bash
    --base-url string       Platform base URL
    --context string        Named context to target (see 'agentengine context list')
-h, --help                  help for sync
    --org-id string         Organization ID
    --project-id string     Project ID
    --project-scope         Target project-scoped secrets (the default; explicit alternative to --workspace-scope)
    --workspace string      Monorepo: target a specific workspace by name (from root agent.yaml)
    --workspace-id string   Workspace ID
    --workspace-scope       Target workspace-scoped secrets instead of project-scoped secrets (the default)
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

- [agentengine secret](https://www.mongodb.com/docs/agentengine/cli/agentengine_secret.md#std-label-agentengine_secret) - Secret management commands.
