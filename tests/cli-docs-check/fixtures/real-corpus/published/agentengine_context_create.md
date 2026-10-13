> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine context create

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

Create a named platform target.

## Synopsis

Create a context named NAME binding a platform base URL, organization, and project. Without --org-id or --project-id this prompts with the organizations and projects visible to your current login. --base-url defaults to the only platform you are logged into, and is required when you are logged into more than one.

Creating a name that already exists fails; a context cannot be rebound yet.

```bash
agentengine context create NAME [flags]
```

## Examples

```bash
agentengine context create prod
agentengine context create local --base-url http://localhost:30050
```

## Options

```bash
    --base-url string     Platform API base URL (default: your current login, if you are logged into only one platform; required otherwise)
-h, --help                help for create
    --json                Output JSON
    --org-id string       Organization ID (default: prompts)
    --project-id string   Project ID (default: prompts)
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

- [agentengine context](https://www.mongodb.com/docs/agentengine/cli/agentengine_context.md#std-label-agentengine_context) - Manage named platform targets.
