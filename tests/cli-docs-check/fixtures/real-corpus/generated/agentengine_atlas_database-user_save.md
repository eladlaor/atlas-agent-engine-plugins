## agentengine atlas database-user save

Save or create the Atlas database user for this workspace.

```
agentengine atlas database-user save [flags]
```

### Options

```
      --base-url string       Platform base URL
      --context string        Named context to target (see 'agentengine context list')
      --env string            Atlas environment name, such as cloud-dev
  -h, --help                  help for save
      --input string          Database user selection JSON. Prefer --input - for stdin (required on macOS and Windows). On Linux, path files must be temporary, owner-only, untracked, deleted after use, and rotated if exposed
      --json                  Output saved Atlas database user as JSON
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

