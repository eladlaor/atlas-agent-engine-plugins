> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine docs generate

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Write Markdown reference docs for every command into `<dir>`.

## Synopsis

Write Markdown reference docs for every command into `<dir>`.

The docs come from the command tree, so they match the flags and help text of the binary that produced them. One page is written per available command and cross-linked to its parent and children; hidden commands get no page.

Commands with a hand-written guide get a “Further reading” link. The guides are written by hand, so the link resolves only when `<dir>` already holds them.

Example: agentengine docs generate ./cli-reference

```bash
agentengine docs generate <dir> [flags]
```

## Options

```bash
-h, --help   help for generate
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

- [agentengine docs](https://www.mongodb.com/docs/agentengine/cli/agentengine_docs.md#std-label-agentengine_docs) - Generate documentation for the CLI.
