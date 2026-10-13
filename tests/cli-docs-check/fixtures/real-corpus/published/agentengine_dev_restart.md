> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine dev restart

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Restart the hot-reload app container.

## Synopsis

Restart the running hot-reload app container.

Restarting reruns the container’s startup environment sync, which is useful after changing host dependencies, for example with uv sync.

The stack is checked for health afterward, with one automatic recovery (docker compose up -d). A stack that still fails is reported as an error with the recovery steps to run.

For an agent that declares artifact\_repositories, registry auth is refreshed first and the app container is recreated when the credentials change; --no-artifact-auth restarts in place.

```bash
agentengine dev restart [flags]
```

## Options

```bash
-h, --help               help for restart
    --no-artifact-auth   Skip refreshing registry auth for declared artifact_repositories
    --workspace string   Monorepo: target a specific agent by name (from root agent.yaml)
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

- [agentengine dev](https://www.mongodb.com/docs/agentengine/cli/agentengine_dev.md#std-label-agentengine_dev) - Local dev environment commands.
