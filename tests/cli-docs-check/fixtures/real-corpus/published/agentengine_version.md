> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine version

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Print the agentengine CLI version.

## Synopsis

Print the agentengine CLI version.

By default only the version is printed. Pass --full to also print the build commit, artifact source and image registry, and the embedded container image defaults.

```bash
agentengine version [flags]
```

## Options

```bash
    --full   Also print the build commit, artifact source, image registry, and embedded image defaults
-h, --help   help for version
    --json   Output version information as JSON
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
