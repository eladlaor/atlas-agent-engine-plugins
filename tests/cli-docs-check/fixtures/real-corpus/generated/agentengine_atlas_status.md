## agentengine atlas status

Show the platform-recorded Atlas egress link and sync status.

### Synopsis

Report the platform-recorded Atlas egress link and sync status for this
workspace's project.

'agentengine atlas setup' reflects local state. This command reports what the
platform has recorded and whether the egress sync is succeeding.

```
agentengine atlas status [flags]
```

### Options

```
      --base-url string       Platform base URL
      --context string        Named context to target (see 'agentengine context list')
  -h, --help                  help for status
      --org-id string         Organization ID
      --project-id string     Project ID
      --workspace string      Monorepo: target a specific workspace by name
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

* [agentengine atlas](agentengine_atlas.md)	 - Atlas workspace setup commands.

