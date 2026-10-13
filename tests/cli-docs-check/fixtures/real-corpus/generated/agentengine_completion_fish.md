## agentengine completion fish

Generate the autocompletion script for fish

### Synopsis

Generate the autocompletion script for the fish shell.

To load completions in your current shell session:

	agentengine completion fish | source

To load completions for every new session, execute once:

	agentengine completion fish > ~/.config/fish/completions/agentengine.fish

You will need to start a new shell for this setup to take effect.


```
agentengine completion fish [flags]
```

### Options

```
  -h, --help              help for fish
      --no-descriptions   disable completion descriptions
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

* [agentengine completion](agentengine_completion.md)	 - Generate the autocompletion script for the specified shell

