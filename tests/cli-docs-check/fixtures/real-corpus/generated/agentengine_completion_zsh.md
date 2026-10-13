## agentengine completion zsh

Generate the autocompletion script for zsh

### Synopsis

Generate the autocompletion script for the zsh shell.

If shell completion is not already enabled in your environment you will need
to enable it.  You can execute the following once:

	echo "autoload -U compinit; compinit" >> ~/.zshrc

To load completions in your current shell session:

	source <(agentengine completion zsh)

To load completions for every new session, execute once:

#### Linux:

	agentengine completion zsh > "${fpath[1]}/_agentengine"

#### macOS:

	agentengine completion zsh > $(brew --prefix)/share/zsh/site-functions/_agentengine

You will need to start a new shell for this setup to take effect.


```
agentengine completion zsh [flags]
```

### Options

```
  -h, --help              help for zsh
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

