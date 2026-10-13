## agentengine deploy cancel

Cancel an in-flight deployment.

### Synopsis

Cancel an in-flight deployment.

Run from an initialized agent directory, use --workspace <name> for a monorepo
workspace, or pass --workspace-id.

```
agentengine deploy cancel <deployment_id> [flags]
```

### Options

```
      --base-url string       Platform base URL
      --context string        Named context to target (see 'agentengine context list')
  -h, --help                  help for cancel
      --org-id string         Organization ID
      --project-id string     Project ID
      --workspace string      Monorepo: select a specific workspace by name (from root agent.yaml)
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

