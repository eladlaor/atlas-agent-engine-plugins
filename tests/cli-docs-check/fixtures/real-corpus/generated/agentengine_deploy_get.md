## agentengine deploy get

Get details of a deployment.

### Synopsis

Show the full status of a deployment: conditions, components, and health.

With no deployment ID this shows the current (most recent) deployment for the
workspace. Run from an initialized agent directory, or pass --workspace-id.

```
agentengine deploy get [deployment-id] [flags]
```

### Options

```
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

### Options inherited from parent commands

```
      --log-file string    override log file path
      --log-level string   file log verbosity (error|warn|info|debug) (default "info")
      --no-log             disable file logging
  -q, --quiet              silence stderr below error
  -v, --verbose count      raise stderr verbosity (-v info, -vv debug)
```

### SEE ALSO

* [agentengine deploy](agentengine_deploy.md)	 - Deploy the last successful build to the platform.

