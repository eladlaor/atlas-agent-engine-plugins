## agentengine agent egress

Edit the egress allow-list in agent.yaml.

### Synopsis

Add, remove, or set the mode of egress destinations in agent.yaml.

These commands edit the local file only and never call the platform. Changes
take effect on the next deploy; agentengine egress shows the deployed policy.

### Options

```
  -h, --help   help for egress
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

* [agentengine agent](agentengine_agent.md)	 - Inspect and edit agent configuration.
* [agentengine agent egress add](agentengine_agent_egress_add.md)	 - Add destinations to agent.yaml without touching existing ones.
* [agentengine agent egress mode](agentengine_agent_egress_mode.md)	 - Set egress_mode in agent.yaml.
* [agentengine agent egress remove](agentengine_agent_egress_remove.md)	 - Remove destinations from agent.yaml without touching the others.

