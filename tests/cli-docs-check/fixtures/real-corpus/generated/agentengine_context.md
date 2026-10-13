## agentengine context

Manage named platform targets.

### Synopsis

A context names one platform target: a base URL, an organization, and a
project. Contexts live in ~/.agentengine/contexts.json and are shared across every
agent directory on this machine; an agent directory binds to one with
'agentengine context pin'.

### Options

```
  -h, --help   help for context
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

* [agentengine](agentengine.md)	 - Agent Engine local development CLI.
* [agentengine context create](agentengine_context_create.md)	 - Create a named platform target.
* [agentengine context current](agentengine_context_current.md)	 - Show the context commands run here will use, and where it came from.
* [agentengine context delete](agentengine_context_delete.md)	 - Delete a named platform target from this machine.
* [agentengine context list](agentengine_context_list.md)	 - List the named platform targets on this machine.
* [agentengine context pin](agentengine_context_pin.md)	 - Bind the current agent directory to a named context.

