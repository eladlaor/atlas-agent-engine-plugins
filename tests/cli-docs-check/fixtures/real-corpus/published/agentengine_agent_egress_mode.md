> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine agent egress mode

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Set egress\_mode in agent.yaml.

## Synopsis

Set network.egress\_mode in agent.yaml.

MODE is deny\_all, allow\_list, or allow\_all. allow\_all requires --confirm-allow-all and is rejected while that sandbox still lists destinations: remove them first, or use allow\_list. --confirm-allow-all is valid only with allow\_all.

This edits the local file and does not change the running workspace. Redeploy for the new mode to apply.

Examples:

```bash
agentengine agent egress mode allow_all  --confirm-allow-all
agentengine agent egress mode deny_all
```

```bash
agentengine agent egress mode MODE [flags]
```

## Options

```bash
    --component string    Target a single sandbox: agent or tool. Omit to apply to both.
    --confirm-allow-all   Required acknowledgement when MODE is allow_all.
-h, --help                help for mode
    --workspace string    Monorepo: select a specific workspace by name (from root agent.yaml)
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
