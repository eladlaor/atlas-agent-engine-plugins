> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine memory status

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Show the project’s memory runtime status.

## Synopsis

Report the project’s memory runtime state without changing anything.

Run it after `agentengine memory apply` to check whether the memory server has finished starting. The `state:` line reads `ready` once it has; re-run to check again. When the runtime is not ready, the output names what it is blocked on. `agentengine memory apply --wait` waits inline for the same condition.

Memory is project-scoped. The target project comes from --context, this directory’s pin, or explicit target flags. No initialized agent directory is required.

Example: agentengine memory status

```bash
agentengine memory status [flags]
```

## Options

```bash
    --base-url string     Platform base URL
    --context string      Named context to target (see 'agentengine context list')
-h, --help                help for status
    --org-id string       Organization ID
    --project-id string   Project ID
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

- [agentengine memory](https://www.mongodb.com/docs/agentengine/cli/agentengine_memory.md#std-label-agentengine_memory) - Memory server configuration commands.
