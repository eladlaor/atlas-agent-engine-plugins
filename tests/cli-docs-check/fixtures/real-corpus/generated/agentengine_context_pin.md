## agentengine context pin

Bind the current agent directory to a named context.

### Synopsis

Bind the agent directory found by walking up from the current directory to
context NAME. Workspace-scoped commands run from here resolve NAME's base URL,
organization, and project whenever no --context or explicit target flags are
given.

A directory with no pin is pinned without a prompt. Re-pinning a directory to a
different context asks first; --yes skips the prompt, and a non-interactive run
without --yes is refused.

```
agentengine context pin NAME [flags]
```

### Examples

```
  agentengine context pin prod
  agentengine context pin local --yes
```

### Options

```
  -h, --help   help for pin
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

