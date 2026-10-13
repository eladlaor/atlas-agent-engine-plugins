> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine completion zsh

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Generate the autocompletion script for zsh

## Synopsis

Generate the autocompletion script for the zsh shell.

If shell completion is not already enabled in your environment you will need to enable it. You can execute the following once:

```bash
echo "autoload -U compinit; compinit" >> ~/.zshrc
```

To load completions in your current shell session:

```bash
source <(agentengine completion zsh)
```

To load completions for every new session, execute once:

### Linux:

```bash
agentengine completion zsh > "${fpath[1]}/_agentengine"
```

### macOS:

```bash
agentengine completion zsh > $(brew --prefix)/share/zsh/site-functions/_agentengine
```

You will need to start a new shell for this setup to take effect.

```bash
agentengine completion zsh [flags]
```

## Options

```bash
-h, --help              help for zsh
    --no-descriptions   disable completion descriptions
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

- [agentengine completion](https://www.mongodb.com/docs/agentengine/cli/agentengine_completion.md#std-label-agentengine_completion) - Generate the autocompletion script for the specified shell
