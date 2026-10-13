## agentengine build logs

Stream build logs to stdout.

### Synopsis

Stream a build's logs to stdout.

The build ID is printed by 'agentengine build' and listed by 'agentengine build
list'. Run from an agent directory, or pass --workspace-id.

Example:
  agentengine build logs bld-abc123

```
agentengine build logs <build_id> [flags]
```

### Options

```
      --base-url string       Platform base URL
      --context string        Named context to target (see 'agentengine context list')
  -h, --help                  help for logs
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

* [agentengine build](agentengine_build.md)	 - Package and build the agent image on the platform.

