> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine agent egress add

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Add destinations to agent.yaml without touching existing ones.

## Synopsis

Add one or more egress destinations to agent.yaml.

When the target sandbox has no mode or is deny\_all, add sets it to allow\_list. A sandbox on allow\_all is left alone: destinations do not apply there, so run agentengine agent egress mode allow\_list first. Adding a host already listed with different ports fails; remove it first.

Each argument is FQDN:PORT, FQDN:PORT,PORT,..., or a full URL. Omitting the port or using FQDN:\* allows all ports. For a URL the host is extracted and the scheme’s standard port (https 443, ssh 22) is used when the URL names no explicit port; that inference is reported as a note. URLs carrying credentials and schemes with no known port are rejected.

The change takes effect on the next deploy. agentengine egress still shows the live workspace until then.

Examples:

```bash
agentengine agent egress add api.openai.com:443
# Allow MongoDB for the tool sandbox only
agentengine agent egress add --component tool '*.mongodb.net:443,27017'
```

```bash
agentengine agent egress add FQDN:PORT[,PORT...] [FQDN:PORT...] [flags]
```

## Options

```bash
    --component string   Target a single sandbox: agent or tool. Omit to apply to both.
-h, --help               help for add
    --workspace string   Monorepo: select a specific workspace by name (from root agent.yaml)
```

## Options inherited from parent commands

```bash
    --log-file string    override log file path
    --log-level string   file log verbosity (error|warn|info|debug) (default "info")
    --no-log             disable file logging
-q, --quiet              silence stderr below error
-v, --verbose count      raise stderr verbosity (-v info, -vv debug)
```

## SEE ALSO

- [agentengine agent egress](https://www.mongodb.com/docs/agentengine/cli/agentengine_agent_egress.md#std-label-agentengine_agent_egress) - Edit the egress allow-list in agent.yaml.
