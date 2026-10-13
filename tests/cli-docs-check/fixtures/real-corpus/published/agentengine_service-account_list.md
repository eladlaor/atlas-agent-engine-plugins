> For the complete MongoDB documentation index, see www.mongodb.com/docs/llms.txt

# agentengine service-account list

MongoDB Atlas Agent Engine is in Public Preview and intended for evaluation and prototyping purposes only. We do not recommend production deployments during preview and expect to communicate breaking changes with you periodically. To learn more about preview feature considerations, see [Preview Features](https://www.mongodb.com/docs/preview-features/).

List service accounts.

## Synopsis

List the service accounts in an organization or project.

Every page is fetched, so the output is the whole inventory; --limit caps the result.

An organization listing covers only organization-scoped accounts. Accounts scoped to projects inside that organization are listed per project.

```bash
agentengine service-account list [flags]
```

## Options

```bash
    --base-url string     Platform base URL
    --context string      Named context to target (see 'agentengine context list')
-h, --help                help for list
    --json                Output service accounts as JSON
    --limit int           Maximum accounts to return (0 = all)
    --org-id string       Organization scope for the service account
    --project-id string   Project scope for the service account
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

- [agentengine service-account](https://www.mongodb.com/docs/agentengine/cli/agentengine_service-account.md#std-label-agentengine_service-account) - Manage service accounts.
