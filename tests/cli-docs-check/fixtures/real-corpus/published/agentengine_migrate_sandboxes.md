> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine migrate sandboxes

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Migrate agent to named sandboxes (placement + SDK terminology).

## Synopsis

Analyze agent source and agent.yaml and migrate legacy is\_local/isLocal placement to named sandbox profiles. The migration creates or verifies the sandbox policy, moves legacy top-level network policy into the corresponding sandbox profiles, renames legacy sandbox scaling options, removes legacy placement arguments, and updates public SDK symbol references.

Supported SDKs: Python LangGraph and TypeScript LangGraph.

```bash
agentengine migrate sandboxes [flags]
```

## Options

```bash
-h, --help   help for sandboxes
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

- [agentengine migrate](https://www.mongodb.com/docs/agentengine/cli/agentengine_migrate.md#std-label-agentengine_migrate) - Migration tooling for agent configuration and SDK surfaces.
