## agentengine secret list

List secrets.

### Synopsis

List secrets in the project or workspace secret store.

Shows the name, description, version, and last updated timestamp for each
secret.

By default this lists project-scoped secrets (shared across all workspaces in
the project). To list workspace-scoped secrets instead, pass --workspace-scope
or supply --workspace-id. --context names the organization and project only, so
combine it with --project-scope.

```
agentengine secret list [flags]
```

### Options

```
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

### Options inherited from parent commands

```
      --log-file string    override log file path
      --log-level string   file log verbosity (error|warn|info|debug) (default "info")
      --no-log             disable file logging
  -q, --quiet              silence stderr below error
  -v, --verbose count      raise stderr verbosity (-v info, -vv debug)
```

### SEE ALSO

* [agentengine secret](agentengine_secret.md)	 - Secret management commands.

