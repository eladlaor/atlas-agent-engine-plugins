> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine dev

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Local dev environment commands.

## Synopsis

Manage the local development environment.

Two modes are available:

Hot reload (default): One app container runs the application processes and file watching restarts them on change. Isolated (--isolated): One container per process, matching the production topology. Changes require a rebuild.

## Options

```bash
-h, --help   help for dev
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

- [agentengine dev clean](https://www.mongodb.com/docs/agentengine/cli/agentengine_dev_clean.md#std-label-agentengine_dev_clean) - Stop containers and remove generated local artifacts.

- [agentengine dev login](https://www.mongodb.com/docs/agentengine/cli/agentengine_dev_login.md#std-label-agentengine_dev_login) - Log the local container tooling in to the platform image registry.

- [agentengine dev logs](https://www.mongodb.com/docs/agentengine/cli/agentengine_dev_logs.md#std-label-agentengine_dev_logs) - Follow logs from agent services.

- [agentengine dev mcp](https://www.mongodb.com/docs/agentengine/cli/agentengine_dev_mcp.md#std-label-agentengine_dev_mcp) - Prepare remote MCP server credentials for agentengine dev.

- [agentengine dev restart](https://www.mongodb.com/docs/agentengine/cli/agentengine_dev_restart.md#std-label-agentengine_dev_restart) - Restart the hot-reload app container.

- [agentengine dev status](https://www.mongodb.com/docs/agentengine/cli/agentengine_dev_status.md#std-label-agentengine_dev_status) - Show the running state of local dev services.

- [agentengine dev stop](https://www.mongodb.com/docs/agentengine/cli/agentengine_dev_stop.md#std-label-agentengine_dev_stop) - Stop running agent services.

- [agentengine dev up](https://www.mongodb.com/docs/agentengine/cli/agentengine_dev_up.md#std-label-agentengine_dev_up) - Start the local dev environment.
