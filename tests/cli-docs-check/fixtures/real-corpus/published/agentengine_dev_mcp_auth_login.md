> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine dev mcp auth login

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Authorize a configured remote MCP server.

```bash
agentengine dev mcp auth login <server> [flags]
```

## Options

```bash
-h, --help               help for login
    --no-browser         Print the OAuth URL without attempting to open a browser
    --timeout duration   Maximum time to wait for OAuth authentication (default 2m0s)
    --workspace string   Monorepo: target a specific agent by name (from root agent.yaml)
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

- [agentengine dev mcp auth](https://www.mongodb.com/docs/agentengine/cli/agentengine_dev_mcp_auth.md#std-label-agentengine_dev_mcp_auth) - Manage MCP OAuth credentials for agentengine dev.
