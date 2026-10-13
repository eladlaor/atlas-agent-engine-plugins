## agentengine dev mcp

Prepare remote MCP server credentials for agentengine dev.

### Synopsis

Prepare remote MCP server credentials for agentengine dev.

OAuth credentials are cached per project under the CLI user state directory at
~/.agentengine/mcp-oauth/<project-hash>/ and mounted into dev up stacks.

### Options

```
  -h, --help   help for mcp
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

* [agentengine dev](agentengine_dev.md)	 - Local dev environment commands.
* [agentengine dev mcp auth](agentengine_dev_mcp_auth.md)	 - Manage MCP OAuth credentials for agentengine dev.

