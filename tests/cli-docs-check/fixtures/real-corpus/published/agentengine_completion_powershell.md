> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine completion powershell

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Generate the autocompletion script for powershell

## Synopsis

Generate the autocompletion script for powershell.

To load completions in your current shell session:

```bash
agentengine completion powershell | Out-String | Invoke-Expression
```

To load completions for every new session, add the output of the above command to your powershell profile.

```bash
agentengine completion powershell [flags]
```

## Options

```bash
-h, --help              help for powershell
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
