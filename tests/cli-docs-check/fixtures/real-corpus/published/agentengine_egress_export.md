> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine egress export

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Print the live egress policy as an agent.yaml network block.

## Synopsis

Print the deployed egress mode and api-managed destinations as a YAML snippet.

Merge egress\_mode and egress into the existing network: mapping. Adding a second top-level network: key breaks the file, and the snippet does not fit a manifest that declares egress under sandboxes.\*.network. The snippet names egress\_mode, so the next deploy owns the destination list: live API destinations missing from the snippet stop applying.

Hosts that cannot be one agent.yaml rule (already declared in the file or from MCP, or agent and tool use different ports) go to stderr and YAML comments. Pasting the snippet and deploying drops them.

Examples:

```bash
agentengine egress export
```

```bash
agentengine egress export [flags]
```

## Options

```bash
    --base-url string       Platform base URL
    --context string        Named context to target (see 'agentengine context list')
-h, --help                  help for export
    --org-id string         Organization ID
    --project-id string     Project ID
    --workspace string      Monorepo: select a specific workspace by name (from root agent.yaml)
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

- [agentengine egress](https://www.mongodb.com/docs/agentengine/cli/agentengine_egress.md#std-label-agentengine_egress) - Show the deployed egress policy.
