> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine egress

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Show the deployed egress policy.

## Synopsis

Show the egress policy deployed for a workspace.

Every workspace has a platform-managed base policy that allows DNS, in-namespace platform services, and any Atlas clusters linked with network.atlas\_clusters. All other outbound traffic, including LLM APIs and third-party services, must be allow-listed explicitly. New workspaces start with both sandboxes in deny\_all.

Modes apply per sandbox:

| Mode | Description |
| --- | --- |
| `deny_all` | Only the base policy. User destinations do not apply. |
| `allow_list` | The base policy plus the listed destinations. |
| `allow_all` | Unrestricted external internet for that sandbox. Platform isolation (host, Kubernetes API server, instance metadata, private address ranges) still applies. |

The agent sandbox runs your agent code. The tool sandbox executes tool calls, including MCP tools. Allow-list a host on each sandbox whose process connects to it.

Live writes are refused: egress save and egress clear fail locally and never call the platform. Change destinations with agentengine agent egress add, remove, or mode, then redeploy.

Examples:

```bash
agentengine egress
agentengine egress --workspace my-workspace
```

```bash
agentengine egress [flags]
```

## Options

```bash
    --base-url string       Platform base URL
    --context string        Named context to target (see 'agentengine context list')
-h, --help                  help for egress
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

- [agentengine](https://www.mongodb.com/docs/agentengine/cli/agentengine.md#std-label-agentengine) - Agent Engine local development CLI.

- [agentengine egress clear](https://www.mongodb.com/docs/agentengine/cli/agentengine_egress_clear.md#std-label-agentengine_egress_clear) - Reset both components to deny\_all (unsupported).

- [agentengine egress export](https://www.mongodb.com/docs/agentengine/cli/agentengine_egress_export.md#std-label-agentengine_egress_export) - Print the live egress policy as an agent.yaml network block.

- [agentengine egress save](https://www.mongodb.com/docs/agentengine/cli/agentengine_egress_save.md#std-label-agentengine_egress_save) - Replace the workspace’s egress policy (unsupported).
