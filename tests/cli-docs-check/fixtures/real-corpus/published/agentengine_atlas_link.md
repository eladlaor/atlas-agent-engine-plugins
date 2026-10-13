> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine atlas link

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Link your Atlas project for egress sync.

## Synopsis

Link the Atlas project selected by `agentengine atlas setup` to this workspace’s platform project for egress sync.

An Atlas project must already be selected. An Atlas-sourced platform project skips the link.

The link applies on the next deploy.

```bash
agentengine atlas link [flags]
```

## Options

```bash
    --base-url string       Platform base URL
    --context string        Named context to target (see 'agentengine context list')
    --env string            Atlas environment name, such as cloud-dev
-h, --help                  help for link
    --org-id string         Organization ID
    --profile string        Atlas service account profile to use
    --project-id string     Project ID
    --workspace string      Monorepo: link a specific workspace by name
    --workspace-id string   Workspace ID
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

- [agentengine atlas](https://www.mongodb.com/docs/agentengine/cli/agentengine_atlas.md#std-label-agentengine_atlas) - Atlas workspace setup commands.
