> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine context delete

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Delete a named platform target from this machine.

## Synopsis

Delete context NAME from ~/.agentengine/contexts.json.

This removes only the local context; its organization, project, workspaces, saved login, directory pins, and registrations are left in place. Directories pinned to the deleted context stop resolving until they are pinned to another context.

Interactive use asks for confirmation; --yes skips the prompt, and --json requires --yes.

```bash
agentengine context delete NAME [flags]
```

## Examples

```bash
agentengine context delete staging
agentengine context delete staging --yes
```

## Options

```bash
-h, --help   help for delete
    --json   Output JSON
-y, --yes    Skip the interactive confirmation prompt
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

- [agentengine context](https://www.mongodb.com/docs/agentengine/cli/agentengine_context.md#std-label-agentengine_context) - Manage named platform targets.
