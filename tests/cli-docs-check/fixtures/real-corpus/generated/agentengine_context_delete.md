## agentengine context delete

Delete a named platform target from this machine.

### Synopsis

Delete context NAME from ~/.agentengine/contexts.json.

This removes only the local context; its organization, project, workspaces,
saved login, directory pins, and registrations are left in place. Directories
pinned to the deleted context stop resolving until they are pinned to another
context.

Interactive use asks for confirmation; --yes skips the prompt, and --json
requires --yes.

```
agentengine context delete NAME [flags]
```

### Examples

```
  agentengine context delete staging
  agentengine context delete staging --yes
```

### Options

```
  -h, --help   help for delete
      --json   Output JSON
  -y, --yes    Skip the interactive confirmation prompt
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

* [agentengine context](agentengine_context.md)	 - Manage named platform targets.

