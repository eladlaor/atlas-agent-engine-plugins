## agentengine completion powershell

Generate the autocompletion script for powershell

### Synopsis

Generate the autocompletion script for powershell.

To load completions in your current shell session:

	agentengine completion powershell | Out-String | Invoke-Expression

To load completions for every new session, add the output of the above command
to your powershell profile.


```
agentengine completion powershell [flags]
```

### Options

```
  -h, --help              help for powershell
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

