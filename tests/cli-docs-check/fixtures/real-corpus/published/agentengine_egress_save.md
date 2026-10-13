> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine egress save

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Replace the workspace’s egress policy (unsupported).

## Synopsis

Live outbound-access edits are no longer supported; the command fails locally.

Declare destinations in the agent file with `agentengine agent egress add` or `remove`, then deploy. Inspect with `agentengine egress`.

```bash
agentengine egress save [flags]
```

## Options

```bash
    --base-url string           Platform base URL
    --component string          Target a single sandbox: agent or tool. Omit to update both.
    --confirm-allow-all         Required acknowledgement when --mode=allow_all (waives tenant self-protection for this component).
    --context string            Named context to target (see 'agentengine context list')
    --destination stringArray   FQDN:PORT (or FQDN:PORT,PORT,...; omit the port or use FQDN:* for all ports). Repeatable. Required when --mode=allow_list.
-h, --help                      help for save
    --mode string               Egress mode: deny_all, allow_list, or allow_all
    --org-id string             Organization ID
    --project-id string         Project ID
    --workspace string          Monorepo: select a specific workspace by name (from root agent.yaml)
    --workspace-id string       Workspace ID
-y, --yes                       Skip the overwrite confirmation prompt
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
