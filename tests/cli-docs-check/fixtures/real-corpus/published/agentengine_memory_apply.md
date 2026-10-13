> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine memory apply

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Apply the project’s stored memory configuration by rolling the memory server.

## Synopsis

Deliver the project’s pending memory config and roll the memory-server pod so it takes effect.

`agentengine memory configure` stores the config, and the memory server reads it only at startup. This command delivers pending config and then rolls the pod. When the project has no runtime yet, it provisions one first.

By default the runtime keeps the image it is already pinned to. --upgrade moves it to the image this environment currently pins. --upgrade refuses a move it cannot verify as forwards, and --force overrides that refusal.

When the pending config cannot be delivered, nothing is restarted and the stored config stays pending.

\--wait polls until the runtime reports ready, for up to 5 minutes.

Memory is project-scoped. The target project comes from --context, this directory’s pin, or explicit target flags. No initialized agent directory is required.

Examples:

```bash
agentengine memory apply
agentengine memory apply --upgrade --wait
```

```bash
agentengine memory apply [flags]
```

## Options

```bash
    --base-url string     Platform base URL
    --context string      Named context to target (see 'agentengine context list')
    --dry-run             Report what would change without provisioning or restarting
    --force               Allow --upgrade to move the runtime to an older image
-h, --help                help for apply
    --org-id string       Organization ID
    --project-id string   Project ID
    --upgrade             Also move the runtime to the image this environment currently pins
    --wait                Wait until the memory runtime reports ready before returning
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
