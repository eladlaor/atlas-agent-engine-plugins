## agentengine build promote get

Get build promotion status.

```
agentengine build promote get <promotion_id> [flags]
```

### Options

```
      --base-url string       Platform base URL
      --context string        Named context to target (see 'agentengine context list')
  -h, --help                  help for get
      --json                  Output promotion result as JSON
      --org-id string         Organization ID
      --project-id string     Project ID
      --workspace string      Monorepo: select a destination workspace by name (from root agent.yaml)
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

* [agentengine build promote](agentengine_build_promote.md)	 - Promote a succeeded build into another workspace.

