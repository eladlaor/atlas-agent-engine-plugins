## agentengine docs generate

Write Markdown reference docs for every command into <dir>.

### Synopsis

Write Markdown reference docs for every command into <dir>.

The docs come from the command tree, so they match the flags and help text of
the binary that produced them. One page is written per available command and
cross-linked to its parent and children; hidden commands get no page.

Commands with a hand-written guide get a "Further reading" link. The guides are
written by hand, so the link resolves only when <dir> already holds them.

Example:
  agentengine docs generate ./cli-reference

```
agentengine docs generate <dir> [flags]
```

### Options

```
  -h, --help   help for generate
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

* [agentengine docs](agentengine_docs.md)	 - Generate documentation for the CLI.

