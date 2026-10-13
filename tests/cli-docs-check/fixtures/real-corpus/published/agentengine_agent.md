> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine agent

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Inspect and edit agent configuration.

## Synopsis

Inspect and edit agent configuration.

Bump-version and egress use the nearest agent.yaml, resolved the same way as build and deploy; edits apply on the next agentengine deploy. Validate reads ./agent.yaml by default. Source reads source.yaml from the CLI state directory.

## Options

```bash
-h, --help   help for agent
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

- [agentengine](https://www.mongodb.com/docs/agentengine/cli/agentengine.md#std-label-agentengine) - Agent Engine local development CLI.

- [agentengine agent bump-version](https://www.mongodb.com/docs/agentengine/cli/agentengine_agent_bump-version.md#std-label-agentengine_agent_bump-version) - Bump the agent’s declared version in agent.yaml (or its delegated manifest).

- [agentengine agent egress](https://www.mongodb.com/docs/agentengine/cli/agentengine_agent_egress.md#std-label-agentengine_agent_egress) - Edit the egress allow-list in agent.yaml.

- [agentengine agent validate](https://www.mongodb.com/docs/agentengine/cli/agentengine_agent_validate.md#std-label-agentengine_agent_validate) - \[Experimental] Validate agent.yaml locally without running the build pipeline.
