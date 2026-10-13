> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine agent egress

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Edit the egress allow-list in agent.yaml.

## Synopsis

Add, remove, or set the mode of egress destinations in agent.yaml.

These commands edit the local file only and never call the platform. Changes take effect on the next deploy; agentengine egress shows the deployed policy.

## Options

```bash
-h, --help   help for egress
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

- [agentengine agent](https://www.mongodb.com/docs/agentengine/cli/agentengine_agent.md#std-label-agentengine_agent) - Inspect and edit agent configuration.

- [agentengine agent egress add](https://www.mongodb.com/docs/agentengine/cli/agentengine_agent_egress_add.md#std-label-agentengine_agent_egress_add) - Add destinations to agent.yaml without touching existing ones.

- [agentengine agent egress mode](https://www.mongodb.com/docs/agentengine/cli/agentengine_agent_egress_mode.md#std-label-agentengine_agent_egress_mode) - Set egress\_mode in agent.yaml.

- [agentengine agent egress remove](https://www.mongodb.com/docs/agentengine/cli/agentengine_agent_egress_remove.md#std-label-agentengine_agent_egress_remove) - Remove destinations from agent.yaml without touching the others.
