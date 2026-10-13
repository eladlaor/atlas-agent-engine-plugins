## agentengine context list

List the named platform targets on this machine.

### Synopsis

List every context in ~/.agentengine/contexts.json. A '*' marks the context
the current agent directory is pinned to, when it is pinned to one.

```
agentengine context list [flags]
```

### Examples

```
  agentengine context list
  agentengine context list --json
```

### Options

```
  -h, --help   help for list
      --json   Output JSON
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

* [agentengine context](agentengine_context.md)	 - Manage named platform targets.

