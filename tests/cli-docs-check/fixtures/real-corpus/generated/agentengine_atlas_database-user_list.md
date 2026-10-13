## agentengine atlas database-user list

List Atlas database users for the saved Atlas project.

```
agentengine atlas database-user list [flags]
```

### Options

```
      --base-url string       Platform base URL
      --context string        Named context to target (see 'agentengine context list')
      --env string            Atlas environment name, such as cloud-dev
  -h, --help                  help for list
      --json                  Output Atlas database users as JSON
      --org-id string         Organization ID
      --profile string        Atlas service account profile to use
      --project-id string     Project ID
      --workspace string      Monorepo: use Atlas setup for a specific workspace by name
      --workspace-id string   Workspace ID
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

* [agentengine atlas database-user](agentengine_atlas_database-user.md)	 - Manage the Atlas database user selected for this workspace.

