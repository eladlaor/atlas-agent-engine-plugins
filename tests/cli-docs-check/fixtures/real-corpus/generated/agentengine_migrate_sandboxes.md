## agentengine migrate sandboxes

Migrate agent to named sandboxes (placement + SDK terminology).

### Synopsis

Analyze agent source and agent.yaml and migrate legacy is_local/isLocal placement
to named sandbox profiles. The migration creates or verifies the sandbox policy,
moves legacy top-level network policy into the corresponding sandbox profiles,
renames legacy sandbox scaling options, removes legacy placement arguments, and
updates public SDK symbol references.

Supported SDKs: Python LangGraph and TypeScript LangGraph.

```
agentengine migrate sandboxes [flags]
```

### Options

```
  -h, --help   help for sandboxes
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

* [agentengine migrate](agentengine_migrate.md)	 - Migration tooling for agent configuration and SDK surfaces.

