## agentengine agent egress remove

Remove destinations from agent.yaml without touching the others.

### Synopsis

Remove one or more egress destinations from agent.yaml.

Each argument is a bare FQDN. Removal is keyed by hostname, so FQDN:PORT and
URLs are rejected. Removing a sandbox's last destination sets that sandbox to
deny_all. A hostname that is not listed is an error. To change mode without
removing destinations, use agentengine agent egress mode.

The change takes effect on the next deploy. agentengine egress still shows the
live workspace until then.

Examples:
  agentengine agent egress remove api.openai.com
  agentengine agent egress remove --component tool api.stripe.com

```
agentengine agent egress remove FQDN [FQDN...] [flags]
```

### Options

```
      --component string   Target a single sandbox: agent or tool. Omit to apply to both.
  -h, --help               help for remove
      --workspace string   Monorepo: select a specific workspace by name (from root agent.yaml)
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

* [agentengine agent egress](agentengine_agent_egress.md)	 - Edit the egress allow-list in agent.yaml.

