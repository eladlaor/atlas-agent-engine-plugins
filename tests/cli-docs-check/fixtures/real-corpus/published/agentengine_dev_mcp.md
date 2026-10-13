> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine dev mcp

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Prepare remote MCP server credentials for agentengine dev.

## Synopsis

Prepare remote MCP server credentials for agentengine dev.

OAuth credentials are cached per project under the CLI user state directory at ~/.agentengine/mcp-oauth/\<project-hash>/ and mounted into dev up stacks.

## Options

```bash
-h, --help   help for mcp
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

- [agentengine dev](https://www.mongodb.com/docs/agentengine/cli/agentengine_dev.md#std-label-agentengine_dev) - Local dev environment commands.

- [agentengine dev mcp auth](https://www.mongodb.com/docs/agentengine/cli/agentengine_dev_mcp_auth.md#std-label-agentengine_dev_mcp_auth) - Manage MCP OAuth credentials for agentengine dev.
