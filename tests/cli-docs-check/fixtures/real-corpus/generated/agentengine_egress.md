## agentengine egress

Show the deployed egress policy.

### Synopsis

Show the egress policy deployed for a workspace.

Every workspace has a platform-managed base policy that allows DNS, in-namespace
platform services, and any Atlas clusters linked with network.atlas_clusters.
All other outbound traffic, including LLM APIs and third-party services, must
be allow-listed explicitly. New workspaces start with both sandboxes in
deny_all.

Modes apply per sandbox:
  deny_all    Only the base policy. User destinations do not apply.
  allow_list  The base policy plus the listed destinations.
  allow_all   Unrestricted external internet for that sandbox. Platform
              isolation (host, Kubernetes API server, instance metadata,
              private address ranges) still applies.

The agent sandbox runs your agent code. The tool sandbox executes tool calls,
including MCP tools. Allow-list a host on each sandbox whose process connects
to it.

Live writes are refused: egress save and egress clear fail locally and never
call the platform. Change destinations with agentengine agent egress add,
remove, or mode, then redeploy.

Examples:
  agentengine egress
  agentengine egress --workspace my-workspace

```
agentengine egress [flags]
```

### Options

```
      --base-url string       Platform base URL
      --context string        Named context to target (see 'agentengine context list')
  -h, --help                  help for egress
      --org-id string         Organization ID
      --project-id string     Project ID
      --workspace string      Monorepo: select a specific workspace by name (from root agent.yaml)
      --workspace-id string   Workspace ID
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

* [agentengine](agentengine.md)	 - Agent Engine local development CLI.
* [agentengine egress clear](agentengine_egress_clear.md)	 - Reset both components to deny_all (unsupported).
* [agentengine egress export](agentengine_egress_export.md)	 - Print the live egress policy as an agent.yaml network block.
* [agentengine egress save](agentengine_egress_save.md)	 - Replace the workspace's egress policy (unsupported).

