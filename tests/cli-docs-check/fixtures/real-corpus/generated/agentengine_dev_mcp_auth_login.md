## agentengine dev mcp auth login

Authorize a configured remote MCP server.

```
agentengine dev mcp auth login <server> [flags]
```

### Options

```
  -h, --help               help for login
      --no-browser         Print the OAuth URL without attempting to open a browser
      --timeout duration   Maximum time to wait for OAuth authentication (default 2m0s)
      --workspace string   Monorepo: target a specific agent by name (from root agent.yaml)
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

* [agentengine dev mcp auth](agentengine_dev_mcp_auth.md)	 - Manage MCP OAuth credentials for agentengine dev.

