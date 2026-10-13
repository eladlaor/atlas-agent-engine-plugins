## agentengine agent

Inspect and edit agent configuration.

### Synopsis

Inspect and edit agent configuration.

Bump-version and egress use the nearest agent.yaml, resolved the same way as
build and deploy; edits apply on the next agentengine deploy. Validate reads
./agent.yaml by default. Source reads source.yaml from the CLI state directory.

### Options

```
  -h, --help   help for agent
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
* [agentengine agent bump-version](agentengine_agent_bump-version.md)	 - Bump the agent's declared version in agent.yaml (or its delegated manifest).
* [agentengine agent egress](agentengine_agent_egress.md)	 - Edit the egress allow-list in agent.yaml.
* [agentengine agent validate](agentengine_agent_validate.md)	 - [Experimental] Validate agent.yaml locally without running the build pipeline.

