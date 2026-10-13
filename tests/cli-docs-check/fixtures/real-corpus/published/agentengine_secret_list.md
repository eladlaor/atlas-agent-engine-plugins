> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine secret list

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

List secrets.

## Synopsis

List secrets in the project or workspace secret store.

Shows the name, description, version, and last updated timestamp for each secret.

By default this lists project-scoped secrets (shared across all workspaces in the project). To list workspace-scoped secrets instead, pass --workspace-scope or supply --workspace-id. --context names the organization and project only, so combine it with --project-scope.

```bash
agentengine secret list [flags]
```

## Options

```bash
    --base-url string       Platform base URL
    --context string        Named context to target (see 'agentengine context list')
-h, --help                  help for list
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
