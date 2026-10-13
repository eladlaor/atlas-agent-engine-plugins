> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine context

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Manage named platform targets.

## Synopsis

A context names one platform target: a base URL, an organization, and a project. Contexts live in ~/.agentengine/contexts.json and are shared across every agent directory on this machine; an agent directory binds to one with `agentengine context pin`.

## Options

```bash
-h, --help   help for context
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

- [agentengine context create](https://www.mongodb.com/docs/agentengine/cli/agentengine_context_create.md#std-label-agentengine_context_create) - Create a named platform target.

- [agentengine context current](https://www.mongodb.com/docs/agentengine/cli/agentengine_context_current.md#std-label-agentengine_context_current) - Show the context commands run here will use, and where it came from.

- [agentengine context delete](https://www.mongodb.com/docs/agentengine/cli/agentengine_context_delete.md#std-label-agentengine_context_delete) - Delete a named platform target from this machine.

- [agentengine context list](https://www.mongodb.com/docs/agentengine/cli/agentengine_context_list.md#std-label-agentengine_context_list) - List the named platform targets on this machine.

- [agentengine context pin](https://www.mongodb.com/docs/agentengine/cli/agentengine_context_pin.md#std-label-agentengine_context_pin) - Bind the current agent directory to a named context.
