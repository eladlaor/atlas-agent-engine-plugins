> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine dev logs

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Follow logs from agent services.

```bash
agentengine dev logs [service] [flags]
```

## Options

```bash
    --all                Monorepo: target the all-workspaces stack
-f, --follow             Follow log output (default true)
-h, --help               help for logs
    --list-services      Print service names from the compose stack, one per line
    --no-follow          Print current logs and exit
    --since string       Show logs since a timestamp (e.g. 2013-01-02T13:23:37Z) or relative time (e.g. 42m)
-n, --tail string        Lines from the end per service (docker default "all")
-t, --timestamps         Show timestamps
    --until string       Show logs before a timestamp or relative time (implies --no-follow; conflicts with --follow)
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
