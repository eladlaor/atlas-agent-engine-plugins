> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine build logs

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Stream build logs to stdout.

## Synopsis

Stream a build’s logs to stdout.

The build ID is printed by `agentengine build` and listed by `agentengine build list`. Run from an agent directory, or pass --workspace-id.

Example: agentengine build logs bld-abc123

```bash
agentengine build logs <build_id> [flags]
```

## Options

```bash
    --base-url string       Platform base URL
    --context string        Named context to target (see 'agentengine context list')
-h, --help                  help for logs
    --org-id string         Organization ID
    --project-id string     Project ID
    --workspace string      Monorepo: select a specific workspace by name (from root agent.yaml)
    --workspace-id string   Workspace ID
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

- [agentengine build](https://www.mongodb.com/docs/agentengine/cli/agentengine_build.md#std-label-agentengine_build) - Package and build the agent image on the platform.
