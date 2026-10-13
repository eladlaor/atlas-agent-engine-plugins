> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine secret delete

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Delete a secret.

## Synopsis

Delete a secret.

The name must match ^\[A-Z]\[A-Z0-9\_]\{0,127}$. A name that has since become a reserved platform name can still be deleted, so a stale secret can be removed.

Deletion is permanent. The command prints the resolved target, then asks for confirmation. Without --yes, a non-interactive run refuses instead of deleting.

By default this deletes project-scoped secrets (shared across all workspaces in the project). To delete a workspace-scoped secret instead, pass --workspace-scope or supply --workspace-id. --context names the organization and project only, so combine it with --project-scope.

```bash
agentengine secret delete NAME [flags]
```

## Options

```bash
    --base-url string       Platform base URL
    --context string        Named context to target (see 'agentengine context list')
-h, --help                  help for delete
    --org-id string         Organization ID
    --project-id string     Project ID
    --project-scope         Target project-scoped secrets (the default; explicit alternative to --workspace-scope)
    --workspace string      Monorepo: target a specific workspace by name (from root agent.yaml)
    --workspace-id string   Workspace ID
    --workspace-scope       Target workspace-scoped secrets instead of project-scoped secrets (the default)
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

- [agentengine secret](https://www.mongodb.com/docs/agentengine/cli/agentengine_secret.md#std-label-agentengine_secret) - Secret management commands.
