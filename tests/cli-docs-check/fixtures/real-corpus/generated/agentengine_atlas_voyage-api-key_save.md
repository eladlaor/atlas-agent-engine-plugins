## agentengine atlas voyage-api-key save

Save or create the Atlas Voyage API key for this workspace.

```
agentengine atlas voyage-api-key save [flags]
```

### Options

```
      --base-url string       Platform base URL
      --context string        Named context to target (see 'agentengine context list')
      --env string            Atlas environment name, such as cloud-dev
  -h, --help                  help for save
      --input string          Voyage API key selection JSON. Prefer --input - for stdin (required on macOS and Windows). On Linux, path files must be temporary, owner-only, untracked, deleted after use, and rotated if exposed
      --json                  Output saved Atlas Voyage API key as JSON
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

* [agentengine atlas voyage-api-key](agentengine_atlas_voyage-api-key.md)	 - Manage the Atlas Voyage API key selected for this workspace.

