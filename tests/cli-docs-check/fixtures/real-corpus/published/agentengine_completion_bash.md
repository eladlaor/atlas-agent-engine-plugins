> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine completion bash

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Generate the autocompletion script for bash

## Synopsis

Generate the autocompletion script for the bash shell.

This script depends on the `bash-completion` package. If it is not installed already, you can install it via your OS’s package manager.

To load completions in your current shell session:

```bash
source <(agentengine completion bash)
```

To load completions for every new session, execute once:

### Linux:

```bash
agentengine completion bash > /etc/bash_completion.d/agentengine
```

### macOS:

```bash
agentengine completion bash > $(brew --prefix)/etc/bash_completion.d/agentengine
```

You will need to start a new shell for this setup to take effect.

```bash
agentengine completion bash
```

## Options

```bash
-h, --help              help for bash
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
